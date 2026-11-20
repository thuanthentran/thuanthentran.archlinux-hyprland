# 04 – Cài Arch lần đầu từ USB

Hướng dẫn cài Arch cho máy TUF F16, dual-boot với Windows. Viết để đọc trên điện thoại trong lúc thao tác trên máy.

Có hai cách:

- **Cách nhanh**: chạy [`install/arch-install.sh`](../install/arch-install.sh), chỉ phải gõ vài dòng.
- **Cách thủ công**: gõ từng lệnh. Dùng khi script dừng giữa chừng, hoặc khi muốn hiểu từng bước.

Cả hai làm cùng một việc, bám theo [Installation guide](https://wiki.archlinux.org/title/Installation_guide) và trang [GRUB](https://wiki.archlinux.org/title/GRUB) của Arch Wiki (đọc ngày 2026-11-17).

> **Đã dùng để cài máy thật** (2026-11-19). Không ghi nhận chỗ nào khác với thực tế. Nếu lần cài sau gặp bước lệch, sửa thẳng vào đây.

Yêu cầu: đã làm xong [03-windows-dual-boot-prep.md](03-windows-dual-boot-prep.md), và ổ đĩa đã có vùng Unallocated (trên máy này là 80 GB, nằm giữa ổ D và phân vùng Recovery cuối).

## Bước 0 – Boot USB (chung cho cả hai cách)

1. Vào BIOS (F2), tắt Secure Boot, lưu và thoát. Không đụng tới VMD.
2. Restart, bấm Esc, chọn mục USB có chữ UEFI.
3. Chọn `Arch Linux install medium`.

Chữ quá nhỏ thì chạy:

```sh
setfont ter-132b
```

## Bước 1 – Nối mạng (chung cho cả hai cách)

Cắm Ethernet là có mạng ngay. Nếu Wi-Fi không lên, cắm điện thoại và bật USB tethering.

```sh
iwctl station wlan0 scan
```

```sh
iwctl station wlan0 get-networks
```

```sh
iwctl station wlan0 connect "TEN_WIFI"
```

Kiểm tra:

```sh
ping -c 3 ping.archlinux.org
```

Báo không có `wlan0`: chạy `ip link` để xem tên card Wi-Fi, và `rfkill` để xem card có bị khóa không.

---

## Cách nhanh: chạy script

### 1. Tải script

```sh
curl -LO https://raw.githubusercontent.com/thuanthentran/thuanthentran.archlinux-hyprland/main/install/arch-install.sh
```

Gõ sai chỉ báo lỗi 404, không hỏng gì. Kiểm tra file tải về đúng là script:

```sh
head -3 arch-install.sh
```

Dòng đầu phải là `#!/usr/bin/env bash`.

### 2. Chạy thử

```sh
bash arch-install.sh --dry-run
```

Chế độ này chỉ đọc ổ đĩa và in ra các lệnh sẽ chạy, không thay đổi gì. Đối chiếu:

| Mục script in ra | Kết quả mong đợi trên máy này |
|---|---|
| Boot mode | UEFI 64-bit |
| EFI system partition | `/dev/nvme0n1p1` |
| Windows Boot Manager | found |
| Largest free block | khoảng 80 GiB |
| Intel VMD | detected |

Khác bảng trên thì dừng lại, chụp màn hình và hỏi trước khi chạy thật.

### 3. Chạy thật

```sh
bash arch-install.sh
```

Script đi qua 11 bước và dừng sau mỗi bước để bạn đọc kết quả (bấm Enter để đi tiếp). Những chỗ bạn phải trả lời:

| Lúc | Trả lời |
|---|---|
| Settings | Hostname, username. Múi giờ, locale, keymap bấm Enter để giữ mặc định. |
| Choose the partition | Chọn `1` để tạo phân vùng mới trong vùng trống 80 GB |
| Tạo phân vùng | Gõ `yes` |
| Format | Gõ `yes` |
| Passwords | Mật khẩu root, rồi mật khẩu user, mỗi cái nhập hai lần |

Script tự chặn những thao tác nguy hiểm:

- Không format phân vùng EFI, chỉ mount nó.
- Không đụng phân vùng đang có filesystem khác (NTFS của Windows...).
- Dừng ngay khi một lệnh lỗi, in tên bước và số dòng bị lỗi.

### 4. Khi script lỗi giữa chừng

1. Chụp màn hình, gồm cả dòng `Failed in step ...`.
2. Sửa nguyên nhân (thường là mạng), hoặc hỏi trước.
3. Chạy lại từ đầu:

```sh
umount -R /mnt
```

```sh
bash arch-install.sh
```

Ở bước chọn phân vùng, chọn `2` và nhập `/dev/nvme0n1p7`. Script nhận ra phân vùng `arch` của lần chạy trước và format lại nó.

Nếu không muốn chạy lại từ đầu, làm tiếp bằng tay từ đúng bước bị lỗi ở phần dưới.

### 5. Xong

Làm theo phần [Sau lần boot đầu](#sau-lần-boot-đầu).

---

## Cách thủ công

### Quy ước

| Ký hiệu | Ý nghĩa |
|---|---|
| `pX` | Số phân vùng Arch mới tạo. Trên máy này là `p7`, dù nằm trước `p6`. |
| `TEN_BAN` | Tên user |
| `tuf` | Tên máy, tùy đặt |

### M1 – Kiểm tra máy

```sh
cat /sys/firmware/efi/fw_platform_size
```

```sh
timedatectl
```

```sh
lsblk -f
```

Kết quả mong đợi:

- `fw_platform_size` in ra `64`.
- `timedatectl` có dòng `System clock synchronized: yes`.
- `lsblk -f` hiện `nvme0n1`, trong đó `p1` là vfat khoảng 450M, và có các phân vùng ntfs.

**Không thấy ổ nvme nào thì dừng lại.** Đó là vấn đề VMD, đừng làm tiếp.

### M2 – Tạo phân vùng cho Arch

```sh
cfdisk /dev/nvme0n1
```

Dòng `Free space` nằm giữa `nvme0n1p5` và `nvme0n1p6`. Chọn nó → New → Enter (lấy hết) → Type: `Linux root (x86-64)` → Write → gõ `yes` → Quit.

```sh
lsblk -f
```

Phân vùng mới khoảng 80G, cột FSTYPE trống. Dùng số của nó thay cho `pX` từ đây trở đi.

### M3 – Format và tạo subvolume

**Chỉ format `pX`. Tuyệt đối không format `p1`.**

```sh
mkfs.btrfs -L arch /dev/nvme0n1pX
mount /dev/nvme0n1pX /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

| Subvolume | Mount tại | Lý do tách |
|---|---|---|
| `@` | `/` | Hệ thống, được snapshot |
| `@home` | `/home` | Rollback hệ thống không đụng dữ liệu cá nhân |
| `@log` | `/var/log` | Giữ log qua các lần rollback |
| `@pkg` | `/var/cache/pacman/pkg` | Không đưa cache gói vào snapshot |
| `@snapshots` | `/.snapshots` | Nơi snapper lưu snapshot |

### M4 – Mount

```sh
O=compress=zstd,noatime
D=/dev/nvme0n1pX
mount -o $O,subvol=@ $D /mnt
mount --mkdir -o $O,subvol=@home $D /mnt/home
mount --mkdir -o $O,subvol=@log $D /mnt/var/log
mount --mkdir -o $O,subvol=@pkg $D /mnt/var/cache/pacman/pkg
mount --mkdir -o $O,subvol=@snapshots $D /mnt/.snapshots
mount --mkdir -o umask=0077 /dev/nvme0n1p1 /mnt/efi
```

Phân vùng EFI mount ở `/efi` thay vì `/boot` như ví dụ của wiki: phân vùng EFI của Windows chỉ có 450 MB, nên kernel để trên Btrfs trong `/boot`, nơi GRUB đọc được và snapshot bao gồm cả kernel. Wiki cho phép cách này khi bootloader đọc được phân vùng root.

Kiểm tra bằng `lsblk`: `pX` có 5 điểm mount, `p1` mount tại `/mnt/efi`.

### M5 – Cài hệ thống nền

```sh
pacstrap -K /mnt base base-devel linux linux-lts linux-firmware sof-firmware intel-ucode btrfs-progs networkmanager grub efibootmgr os-prober sudo nano git man-db man-pages texinfo
```

### M6 – fstab

```sh
genfstab -U /mnt > /mnt/etc/fstab
sed -i -E 's/subvolid=[0-9]+,//g; s/,subvolid=[0-9]+//g' /mnt/etc/fstab
cat /mnt/etc/fstab
```

Lệnh `sed` bỏ `subvolid=` để sau này rollback bằng snapper vẫn mount đúng subvolume theo tên.

### M7 – Cấu hình trong hệ thống mới

```sh
arch-chroot /mnt
```

Múi giờ, ngôn ngữ, tên máy:

```sh
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo KEYMAP=us > /etc/vconsole.conf
echo tuf > /etc/hostname
```

Driver VMD trong initramfs, dùng file drop-in thay vì sửa `mkinitcpio.conf`:

```sh
mkdir -p /etc/mkinitcpio.conf.d
echo 'MODULES+=(vmd)' > /etc/mkinitcpio.conf.d/10-vmd.conf
mkinitcpio -P
```

Dịch vụ:

```sh
systemctl enable NetworkManager systemd-timesyncd fstrim.timer
```

### M8 – User và mật khẩu

```sh
echo '%wheel ALL=(ALL:ALL) ALL' > /etc/sudoers.d/10-wheel
chmod 440 /etc/sudoers.d/10-wheel
visudo -cf /etc/sudoers.d/10-wheel
passwd
useradd -m -G wheel TEN_BAN
passwd TEN_BAN
```

`visudo -cf` phải in `parsed OK`.

### M9 – Bootloader

```sh
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
sed -i -E 's/^#?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
```

Lệnh cuối nên in ra `Found Windows Boot Manager`. Wiki ghi chú os-prober có thể không chạy được trong chroot; nếu không thấy Windows, cứ tiếp tục và chạy lại lệnh đó sau lần boot đầu tiên.

### M10 – Thoát và khởi động lại

```sh
exit
umount -R /mnt
reboot
```

Rút USB khi màn hình tắt.

---

## Sau lần boot đầu

Chọn `Arch Linux` trong GRUB, đăng nhập bằng user vừa tạo, nối Wi-Fi:

```sh
nmtui
```

Nếu menu GRUB chưa có Windows:

```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Vào Windows một lần để chỉnh đồng hồ sang UTC, xem [03-windows-dual-boot-prep.md](03-windows-dual-boot-prep.md).

Lúc này máy có Arch tối thiểu, chưa có giao diện. Phần còn lại sẽ do script của repo đảm nhận, xem [05-repo-plan.md](05-repo-plan.md):

- Hyprland và các thành phần giao diện
- Driver NVIDIA, `asusctl`, `supergfxctl`
- snapper, grub-btrfs, zram
- distrobox và công cụ dev

## Xử lý sự cố

| Triệu chứng | Cách xử lý |
|---|---|
| Treo hoặc màn hình đen ở lần boot đầu | Ở menu GRUB bấm `e`, thêm `modprobe.blacklist=nouveau` vào cuối dòng bắt đầu bằng `linux`, bấm Ctrl+X |
| Máy boot thẳng vào Windows | Vào BIOS (F2), đưa GRUB lên đầu thứ tự boot |
| Kernel chính không boot được | Chọn mục `linux-lts` trong Advanced options của GRUB |
| Windows hỏi mã BitLocker | Nhập recovery key từ tài khoản Microsoft |
| `pacstrap` báo lỗi chữ ký (signature) | Kiểm tra `timedatectl` đã đồng bộ giờ; nếu ISO cũ, chạy `pacman -Sy archlinux-keyring` rồi thử lại |
| Cập nhật BIOS xóa mất mục GRUB | Boot USB, mount như M4, `arch-chroot /mnt`, chạy lại lệnh `grub-install` ở M9 |
| Cần sửa hệ thống đã cài | Boot USB, mount như M4 (bỏ qua `mkfs`), rồi `arch-chroot /mnt` |
