#!/usr/bin/env bash
#
# arch-install.sh: install a minimal Arch Linux next to Windows (UEFI + GPT).
#
# Follows the ArchWiki pages below (read 2026-11-17):
#   https://wiki.archlinux.org/title/Installation_guide
#   https://wiki.archlinux.org/title/GRUB
#
# What it does:
#   - creates one partition in the largest free block of the disk, or uses one you name
#   - formats it as Btrfs with subvolumes @ @home @log @pkg @snapshots
#   - mounts the existing EFI system partition (shared with Windows) at /efi; never formats it
#   - installs the base system, sets time zone, locale, hostname and a sudo user
#   - installs GRUB and lets os-prober add Windows Boot Manager to the menu
# It does not install a desktop. Hyprland and the rest come later from this repo.
#
# Usage, from the Arch live USB after connecting to the internet:
#   bash arch-install.sh --dry-run    # detect and print every command, change nothing
#   bash arch-install.sh              # install
#
# Answers can be given ahead of time as environment variables:
#   ARCH_HOSTNAME  ARCH_USER  ARCH_TIMEZONE  ARCH_LOCALE  ARCH_KEYMAP
#   ARCH_ESP         EFI system partition, e.g. /dev/nvme0n1p1 (auto-detected otherwise)
#   ARCH_ROOT        an existing empty partition to use instead of creating one
#   ARCH_EXTRA_PKGS  extra packages for pacstrap, space separated

if [ -z "${BASH_VERSION:-}" ]; then
  echo "Run this script with bash: bash arch-install.sh" >&2
  exit 1
fi

set -Eeuo pipefail

readonly MNT=/mnt
readonly ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
readonly MIN_ROOT_GIB=30
readonly MIN_ESP_FREE_MIB=10
readonly BTRFS_OPTS=compress=zstd,noatime
# subvolume:mount point in the new system ("/" must come first)
readonly SUBVOLS=(
  "@:/"
  "@home:/home"
  "@log:/var/log"
  "@pkg:/var/cache/pacman/pkg"
  "@snapshots:/.snapshots"
)
readonly TOTAL_STEPS=11

readonly BOLD=$'\e[1m' RED=$'\e[31m' GREEN=$'\e[32m' YELLOW=$'\e[33m' RESET=$'\e[0m'

ARCH_HOSTNAME=${ARCH_HOSTNAME:-}
ARCH_USER=${ARCH_USER:-}
ARCH_TIMEZONE=${ARCH_TIMEZONE:-}
ARCH_LOCALE=${ARCH_LOCALE:-}
ARCH_KEYMAP=${ARCH_KEYMAP:-}
ARCH_ESP=${ARCH_ESP:-}
ARCH_ROOT=${ARCH_ROOT:-}
ARCH_EXTRA_PKGS=${ARCH_EXTRA_PKGS:-}

DRY_RUN=0
STEP_NO=0
STEP_NAME="start"
DISK=""
ESP=""
ROOT=""
REFORMAT=0

# ---------------------------------------------------------------- helpers

info() { printf '%s\n' "${GREEN}::${RESET} $*"; }
warn() { printf '%s\n' "${YELLOW}!! $*${RESET}"; }
die() {
  printf '%s\n' "${RED}xx $*${RESET}" >&2
  exit 1
}

on_error() {
  local code=$? line=$1
  printf '\n%s\n' "${RED}xx Failed in step ${STEP_NO} \"${STEP_NAME}\" (line ${line}, exit code ${code}).${RESET}" >&2
  printf '%s\n' "   Nothing after this point was run. Take a photo of the screen, then either" >&2
  printf '%s\n' "   fix the cause and run the script again, or continue by hand with docs/04-install-arch.md." >&2
}
trap 'on_error $LINENO' ERR

step() {
  STEP_NO=$((STEP_NO + 1))
  STEP_NAME=$1
  printf '\n%s\n' "${BOLD}==> [${STEP_NO}/${TOTAL_STEPS}] ${STEP_NAME}${RESET}"
}

pause() {
  printf '\n'
  read -r -p "${BOLD}Press Enter to continue, Ctrl+C to stop...${RESET}" _ </dev/tty
}

# confirm "question": the user must type "yes"
confirm() {
  local answer note=""
  if ((DRY_RUN)); then note=" (dry run: nothing will change)"; fi
  read -r -p "${YELLOW}$1${note} Type 'yes' to continue: ${RESET}" answer </dev/tty
  [[ $answer == yes ]] || die "Stopped. Nothing was changed in this step."
}

# ask VAR "Prompt" default check_function
# A value preset in the environment is used without asking, if it passes the check.
ask() {
  local var=$1 prompt=$2 default=$3 check=$4 reply
  while true; do
    if [[ -n ${!var} ]]; then
      reply=${!var}
      printf -v "$var" '%s' ""
    else
      read -r -p "${prompt}${default:+ [$default]}: " reply </dev/tty
      reply=${reply:-$default}
    fi
    if "$check" "$reply"; then
      printf -v "$var" '%s' "$reply"
      return 0
    fi
    warn "Invalid value: '$reply'"
  done
}

# run CMD ARGS...: print the command, then run it unless this is a dry run
run() {
  local arg line="+"
  for arg in "$@"; do
    if [[ $arg =~ ^[A-Za-z0-9_./:=@,+%-]+$ ]]; then
      line+=" $arg"
    elif [[ $arg != *\'* ]]; then
      line+=" '$arg'"
    else
      line+=" $(printf '%q' "$arg")"
    fi
  done
  printf '%s\n' "${BOLD}${line}${RESET}"
  if ((DRY_RUN)); then return 0; fi
  "$@"
}

# run_sh "shell line": same as run, for lines that need a redirect
run_sh() {
  printf '%s\n' "${BOLD}+ $1${RESET}"
  if ((DRY_RUN)); then return 0; fi
  bash -c "$1"
}

in_chroot() { run arch-chroot "$MNT" "$@"; }

# write_file PATH MODE <<<"content"
write_file() {
  local path=$1 mode=$2 content
  content=$(cat)
  printf '%s\n' "${BOLD}+ write ${path} (mode ${mode}):${RESET}"
  sed 's/^/    /' <<<"$content"
  if ((DRY_RUN)); then return 0; fi
  mkdir -p "$(dirname "$path")"
  rm -f "$path"
  printf '%s\n' "$content" >"$path"
  chmod "$mode" "$path"
}

set_password() {
  local who=$1
  info "Set the password for ${who}."
  if ((DRY_RUN)); then
    printf '%s\n' "${BOLD}+ arch-chroot ${MNT} passwd ${who}${RESET}"
    return 0
  fi
  until arch-chroot "$MNT" passwd "$who" </dev/tty; do
    warn "Passwords did not match or were rejected. Try again."
  done
}

has_vmd() { compgen -G '/sys/bus/pci/drivers/vmd/0000:*' >/dev/null; }

valid_hostname() { [[ $1 =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]]; }
valid_user() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ && $1 != root ]]; }
valid_timezone() { [[ -n $1 && -f /usr/share/zoneinfo/$1 ]]; }
valid_locale() {
  [[ $1 == *.UTF-8 ]] || return 1
  [[ ! -f /usr/share/i18n/SUPPORTED ]] || grep -qx -- "$1 UTF-8" /usr/share/i18n/SUPPORTED
}
valid_keymap() {
  [[ -n $1 ]] || return 1
  command -v localectl >/dev/null || return 0
  localectl list-keymaps | grep -x -- "$1" >/dev/null
}

usage() {
  cat <<'EOF'
Usage: bash arch-install.sh [--dry-run]

Installs a minimal Arch Linux next to Windows, following the ArchWiki
Installation guide. Run it from the Arch live USB after connecting to
the internet.

  -n, --dry-run   detect disks and print every command without changing anything
  -h, --help      show this help

See the top of this file for the environment variables it reads.
EOF
}

parse_args() {
  while (($#)); do
    case $1 in
      -n | --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "Unknown option: $1 (see --help)" ;;
    esac
    shift
  done
}

banner() {
  printf '%s\n' "${BOLD}Arch Linux install, dual boot with Windows${RESET}"
  printf '%s\n' "Based on https://wiki.archlinux.org/title/Installation_guide"
  if ((DRY_RUN)); then
    printf '%s\n' "${YELLOW}DRY RUN: disks are only read; every change is printed instead of run.${RESET}"
  fi
}

# ---------------------------------------------------------------- steps

check_live_env() {
  step "Check the live environment"
  [[ $EUID -eq 0 ]] || die "Run as root. The live USB logs you in as root."

  if [[ ! -d /run/archiso ]]; then
    if ((DRY_RUN)); then
      warn "This does not look like the Arch live USB (/run/archiso is missing)."
    else
      die "This does not look like the Arch live USB (/run/archiso is missing)."
    fi
  fi

  local bits
  bits=$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null || true)
  [[ $bits == 64 ]] ||
    die "Not booted in 64-bit UEFI mode (fw_platform_size: '${bits:-missing}'). Reboot and pick the USB entry marked UEFI."
  info "Boot mode: UEFI 64-bit."

  local cmd
  for cmd in sgdisk sfdisk partx blockdev blkid lsblk findmnt mkfs.btrfs btrfs pacstrap genfstab arch-chroot; do
    command -v "$cmd" >/dev/null || die "Missing command: $cmd"
  done

  if findmnt -n "$MNT" >/dev/null; then
    if ((DRY_RUN)); then
      warn "$MNT is already mounted."
    else
      die "$MNT is already mounted, probably from an earlier attempt. Run: umount -R $MNT"
    fi
  fi

  info "Checking the internet connection (ping.archlinux.org)..."
  ping -c 2 -W 3 ping.archlinux.org >/dev/null ||
    die "No internet. Connect first, e.g.: iwctl station wlan0 connect \"WIFI_NAME\""
  info "Internet: OK."

  info "Waiting for the clock to synchronize (up to 30 s)..."
  local i synced=no
  for i in {1..30}; do
    synced=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo no)
    if [[ $synced == yes ]]; then break; fi
    sleep 1
  done
  if [[ $synced == yes ]]; then
    info "Clock: synchronized."
  else
    warn "Clock is not synchronized yet. If pacstrap reports signature errors, check: timedatectl"
  fi
  pause
}

ask_settings() {
  step "Settings"
  ask ARCH_HOSTNAME "Hostname (a-z, 0-9, -)" "tuf" valid_hostname
  ask ARCH_USER "Username (lowercase)" "" valid_user
  ask ARCH_TIMEZONE "Time zone" "Asia/Ho_Chi_Minh" valid_timezone
  ask ARCH_LOCALE "Locale" "en_US.UTF-8" valid_locale
  ask ARCH_KEYMAP "Console keymap" "us" valid_keymap
  printf '\n  hostname  %s\n  user      %s\n  time zone %s\n  locale    %s\n  keymap    %s\n' \
    "$ARCH_HOSTNAME" "$ARCH_USER" "$ARCH_TIMEZONE" "$ARCH_LOCALE" "$ARCH_KEYMAP"
  pause
}

pick_esp() {
  step "Find the EFI system partition shared with Windows"
  lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTTYPENAME,LABEL,MOUNTPOINTS

  if [[ -z $ARCH_ESP ]]; then
    # Skip the USB stick: the Arch ISO carries its own EFI partition.
    local boot_disk="" src
    src=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
    if [[ -n $src ]]; then boot_disk=$(lsblk -npo PKNAME "$src" 2>/dev/null | head -n1 || true); fi

    local candidates=() path ptype parent tran
    while read -r path ptype parent; do
      [[ ${ptype,,} == "$ESP_GUID" && -n $parent ]] || continue
      [[ $parent != "$boot_disk" ]] || continue
      tran=$(lsblk -dno TRAN "$parent" 2>/dev/null || true)
      [[ $tran != usb ]] || continue
      candidates+=("$path")
    done < <(lsblk -lnpo PATH,PARTTYPE,PKNAME)

    case ${#candidates[@]} in
      0) die "No EFI system partition found on an internal disk. Is Windows installed in UEFI mode?" ;;
      1) ARCH_ESP=${candidates[0]} ;;
      *)
        printf '  %s\n' "${candidates[@]}"
        read -r -p "Several EFI system partitions found. Which one does Windows use? " ARCH_ESP </dev/tty
        ;;
    esac
  fi

  ESP=$ARCH_ESP
  [[ -b $ESP ]] || die "$ESP is not a block device."
  local esp_type
  esp_type=$(lsblk -dno PARTTYPE "$ESP")
  [[ ${esp_type,,} == "$ESP_GUID" ]] || die "$ESP is not an EFI system partition."
  [[ $(blkid -p -o value -s TYPE "$ESP" || true) == vfat ]] || die "$ESP is not formatted as FAT."
  DISK=$(lsblk -npo PKNAME "$ESP" | head -n1)
  [[ -b $DISK ]] || die "Could not find the disk that holds $ESP."
  info "EFI system partition: $ESP on disk $DISK. It will be mounted, never formatted."

  # Read-only look inside: is Windows there, and is there room for GRUB?
  local tmp free_mib
  tmp=$(mktemp -d)
  mount -o ro "$ESP" "$tmp"
  if [[ -f $tmp/EFI/Microsoft/Boot/bootmgfw.efi ]]; then
    info "Windows Boot Manager found on $ESP."
  else
    warn "Windows Boot Manager was not found on $ESP."
  fi
  free_mib=$(df --output=avail -BM "$tmp" | tail -n1 | tr -dc '0-9')
  umount "$tmp"
  rmdir "$tmp"
  info "Free space on $ESP: ${free_mib} MiB."
  ((free_mib >= MIN_ESP_FREE_MIB)) || die "Not enough free space on $ESP for GRUB (need ${MIN_ESP_FREE_MIB} MiB)."
  pause
}

use_existing_root() {
  local path=$1 type mnt fstype label bytes
  [[ -b $path ]] || die "$path is not a block device."
  type=$(lsblk -dno TYPE "$path")
  [[ $type == part ]] || die "$path is a $type, not a partition."
  [[ $(realpath "$path") != $(realpath "$ESP") ]] || die "$path is the EFI system partition. Refusing."
  mnt=$(lsblk -no MOUNTPOINTS "$path" | tr -d '\n')
  [[ -z $mnt ]] || die "$path is mounted at $mnt. Unmount it first."

  fstype=$(blkid -p -o value -s TYPE "$path" || true)
  label=$(blkid -p -o value -s LABEL "$path" || true)
  if [[ -z $fstype ]]; then
    :
  elif [[ $fstype == btrfs && $label == arch ]]; then
    warn "$path holds the Btrfs file system 'arch' from an earlier run. It will be formatted again."
    REFORMAT=1
  else
    die "$path contains a $fstype file system${label:+ labelled '$label'}. Refusing to touch it."
  fi

  bytes=$(lsblk -bdno SIZE "$path")
  ((bytes / 1024 ** 3 >= MIN_ROOT_GIB)) || die "$path is smaller than ${MIN_ROOT_GIB} GiB."
  ROOT=$path
  info "Arch will be installed on $ROOT."
}

create_root() {
  local gib=$1 before after new
  ((gib >= MIN_ROOT_GIB)) ||
    die "The largest free block is ${gib} GiB; at least ${MIN_ROOT_GIB} GiB is needed. Shrink a Windows volume first."
  confirm "Create a ${gib} GiB partition named 'arch' in the largest free block of $DISK? Existing partitions stay as they are."

  before=$(lsblk -lnpo NAME "$DISK" | sort)
  # 8304 = "Linux x86-64 root (/)", the type the wiki's example layout uses
  run sgdisk --largest-new=0 --typecode=0:8304 --change-name=0:arch "$DISK"
  if ((DRY_RUN)); then
    ROOT=/dev/NEW-PARTITION
    return 0
  fi

  partx -u "$DISK" || true
  udevadm settle
  after=$(lsblk -lnpo NAME "$DISK" | sort)
  new=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
  [[ -n $new && $(wc -l <<<"$new") -eq 1 ]] || die "Could not find the new partition. Check with: lsblk $DISK"
  ROOT=$new
  info "Created $ROOT."
  lsblk -o NAME,SIZE,PARTTYPENAME,PARTLABEL "$ROOT"
}

pick_root() {
  step "Choose the partition for Arch"
  if [[ -n $ARCH_ROOT ]]; then
    use_existing_root "$ARCH_ROOT"
    pause
    return 0
  fi

  info "Unpartitioned space on $DISK:"
  sfdisk --list-free "$DISK"

  local first last ss gib=0
  first=$(sgdisk --first-in-largest "$DISK" | tail -n1)
  last=$(sgdisk --end-of-largest "$DISK" | tail -n1)
  ss=$(blockdev --getss "$DISK")
  [[ $first =~ ^[0-9]+$ && $last =~ ^[0-9]+$ ]] || die "Could not read the free space on $DISK."
  if ((last > first)); then gib=$(((last - first + 1) * ss / 1024 ** 3)); fi

  printf '\n  1) Create a new %s GiB partition in the largest free block (recommended)\n' "$gib"
  printf '  2) Use a partition I already created\n'
  local choice path
  read -r -p "Choose 1 or 2: " choice </dev/tty
  case $choice in
    1) create_root "$gib" ;;
    2)
      read -r -p "Partition path, e.g. /dev/nvme0n1p7: " path </dev/tty
      use_existing_root "$path"
      ;;
    *) die "Unknown choice: '$choice'" ;;
  esac
  pause
}

format_root() {
  step "Format $ROOT as Btrfs and create subvolumes"
  if ((!DRY_RUN)); then lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$ROOT"; fi
  confirm "Everything on $ROOT will be erased. Windows partitions are not touched."

  local force=() entry
  if ((REFORMAT)); then force=(-f); fi
  run mkfs.btrfs "${force[@]}" -L arch "$ROOT"
  run mount "$ROOT" "$MNT"
  for entry in "${SUBVOLS[@]}"; do
    run btrfs subvolume create "$MNT/${entry%%:*}"
  done
  run umount "$MNT"
  pause
}

mount_all() {
  step "Mount the file systems"
  local entry subvol target
  for entry in "${SUBVOLS[@]}"; do
    subvol=${entry%%:*}
    target=${entry#*:}
    if [[ $target == / ]]; then
      run mount -o "$BTRFS_OPTS,subvol=$subvol" "$ROOT" "$MNT"
    else
      run mount --mkdir -o "$BTRFS_OPTS,subvol=$subvol" "$ROOT" "$MNT$target"
    fi
  done
  # The ESP is mounted at /efi, so kernels stay on Btrfs in /boot where GRUB can read them
  # and snapshots include them. The wiki allows /efi when the boot loader can read the root volume.
  run mount --mkdir -o umask=0077 "$ESP" "$MNT/efi"
  if ((!DRY_RUN)); then findmnt -R -o TARGET,SOURCE,FSTYPE "$MNT"; fi
  pause
}

install_packages() {
  step "Install the base system (pacstrap)"
  local ucode=() extra=() mirror
  if grep -q GenuineIntel /proc/cpuinfo; then
    ucode=(intel-ucode)
  elif grep -q AuthenticAMD /proc/cpuinfo; then
    ucode=(amd-ucode)
  fi
  if [[ -n $ARCH_EXTRA_PKGS ]]; then read -r -a extra <<<"$ARCH_EXTRA_PKGS"; fi

  local pkgs=(
    base base-devel linux linux-lts linux-firmware sof-firmware "${ucode[@]}"
    btrfs-progs networkmanager
    grub efibootmgr os-prober
    sudo nano git man-db man-pages texinfo
    "${extra[@]}"
  )

  mirror=$(grep -m1 '^Server' /etc/pacman.d/mirrorlist 2>/dev/null | awk '{print $3}' || true)
  info "First mirror in /etc/pacman.d/mirrorlist: ${mirror:-unknown}"
  info "Downloading packages can take several minutes."
  run pacstrap -K "$MNT" "${pkgs[@]}"
  pause
}

write_fstab() {
  step "Generate /etc/fstab"
  # '>' instead of the wiki's '>>': the fresh fstab holds only comments, and this keeps a re-run clean.
  run_sh "genfstab -U $MNT > $MNT/etc/fstab"
  # Drop subvolid= so a snapper rollback, which replaces the @ subvolume, still mounts by name.
  run_sh "sed -i -E 's/subvolid=[0-9]+,//g; s/,subvolid=[0-9]+//g' $MNT/etc/fstab"
  if ((!DRY_RUN)); then cat "$MNT/etc/fstab"; fi
  pause
}

configure_system() {
  step "Time, locale, hostname, initramfs and services"
  in_chroot ln -sf "/usr/share/zoneinfo/$ARCH_TIMEZONE" /etc/localtime
  in_chroot hwclock --systohc

  run_sh "echo '$ARCH_LOCALE UTF-8' >> $MNT/etc/locale.gen"
  in_chroot locale-gen
  write_file "$MNT/etc/locale.conf" 644 <<<"LANG=$ARCH_LOCALE"
  write_file "$MNT/etc/vconsole.conf" 644 <<<"KEYMAP=$ARCH_KEYMAP"
  write_file "$MNT/etc/hostname" 644 <<<"$ARCH_HOSTNAME"

  if has_vmd; then
    info "Intel VMD controller detected: adding the vmd module to the initramfs."
    write_file "$MNT/etc/mkinitcpio.conf.d/10-vmd.conf" 644 <<<"MODULES+=(vmd)"
  fi
  in_chroot mkinitcpio -P

  in_chroot systemctl enable NetworkManager.service systemd-timesyncd.service fstrim.timer
  pause
}

create_users() {
  step "Create user $ARCH_USER and set passwords"
  write_file "$MNT/etc/sudoers.d/10-wheel" 440 <<<'%wheel ALL=(ALL:ALL) ALL'
  in_chroot visudo -cf /etc/sudoers.d/10-wheel

  if ((!DRY_RUN)) && arch-chroot "$MNT" id -u "$ARCH_USER" >/dev/null 2>&1; then
    warn "User $ARCH_USER already exists; keeping it."
  else
    in_chroot useradd -m -G wheel "$ARCH_USER"
  fi

  set_password root
  set_password "$ARCH_USER"
  pause
}

install_grub() {
  step "Install GRUB and add Windows to the menu"
  in_chroot grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

  in_chroot sed -i -E 's/^#?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
  if ((!DRY_RUN)) && ! grep -q '^GRUB_DISABLE_OS_PROBER=false' "$MNT/etc/default/grub"; then
    run_sh "echo GRUB_DISABLE_OS_PROBER=false >> $MNT/etc/default/grub"
  fi
  in_chroot grub-mkconfig -o /boot/grub/grub.cfg

  if ((!DRY_RUN)); then
    if grep -q 'Windows Boot Manager' "$MNT/boot/grub/grub.cfg"; then
      info "Windows Boot Manager is in the GRUB menu."
    else
      warn "Windows was not detected from inside the chroot; the wiki notes os-prober may not work there."
      warn "After the first boot into Arch, run: sudo grub-mkconfig -o /boot/grub/grub.cfg"
    fi
  fi
}

finish() {
  printf '\n%s\n' "${BOLD}==> Done${RESET}"
  if ((DRY_RUN)); then
    cat <<EOF
Dry run finished. Nothing was changed.
  disk       $DISK
  EFI        $ESP
  Arch       $ROOT
  hostname   $ARCH_HOSTNAME
  user       $ARCH_USER
Run again without --dry-run to install.
EOF
    return 0
  fi
  cat <<EOF
Arch is installed on $ROOT. GRUB is on $ESP next to Windows.

Next:
  1. umount -R $MNT
  2. reboot, and remove the USB stick when the screen goes black
  3. pick "Arch Linux" in GRUB and log in as $ARCH_USER
  4. connect to Wi-Fi: nmtui
  5. in Windows, switch the clock to UTC (docs/03-windows-dual-boot-prep.md)
EOF
}

main() {
  parse_args "$@"
  banner
  check_live_env
  ask_settings
  pick_esp
  pick_root
  format_root
  mount_all
  install_packages
  write_fstab
  configure_system
  create_users
  install_grub
  finish
}

main "$@"
