# 06 – Dựng desktop sau khi cài, và cách rollback

Sau khi [arch-install.sh](../install/arch-install.sh) cài xong Arch nền và boot được, [install/setup.sh](../install/setup.sh) dựng phần còn lại: gói, dotfiles, file hệ thống, service, snapshot, plugin, theme.

## Chạy

Đăng nhập bằng user thường (không phải root), có mạng:

```sh
git clone https://github.com/thuanthentran/thuanthentran.archlinux-hyprland.git ~/code/thuanthentran.archlinux-hyprland
cd ~/code/thuanthentran.archlinux-hyprland
bash install/setup.sh --dry-run    # xem trước mọi lệnh
bash install/setup.sh              # chạy thật, hỏi mật khẩu sudo
```

Chạy lại bao nhiêu lần cũng được. Muốn chạy một phần thì ghi tên bước: `bash install/setup.sh dotfiles theme`. Danh sách bước: `bash install/setup.sh --help`.

Hai bước `plugins` và `theme` cần đang ở trong Hyprland. Lần đầu chạy từ TTY thì hai bước này bỏ qua; sau khi reboot và đăng nhập Hyprland ở màn đăng nhập (greetd + greeter Quickshell, bước `greeter`), chạy:

```sh
bash install/setup.sh plugins theme
```

## Màn đăng nhập

Bước `greeter` thay SDDM bằng greetd. greetd chạy một Hyprland nhỏ ([extras/greeter/hyprland.lua](../extras/greeter/hyprland.lua)) dưới user `greeter`, trong đó Quickshell vẽ màn đăng nhập ([extras/greeter/shell.qml](../extras/greeter/shell.qml)), giống hệt màn khóa vì dùng chung `LockSurface.qml`. User `greeter` không đọc được thư mục home, nên bước này chép greeter, Theme, hình nền vào `/etc/greetd/quickshell` và font Lexend / Comfortaa vào `/usr/local/share/fonts`. Đổi màn khóa, Theme hay hình nền xong thì chạy lại `bash install/setup.sh greeter`. Có hiệu lực từ lần boot sau.

Xem thử mà không cần cài (Esc để thoát, mật khẩu nào cũng "sai"): dựng thư mục như bước `greeter` rồi chạy `qs -p <thư mục>`.

Nếu màn đăng nhập hỏng: Ctrl+Alt+F2, đăng nhập ở TTY, rồi quay về SDDM (vẫn còn cài):

```sh
sudo systemctl disable greetd && sudo systemctl enable sddm && reboot
```

## Mirror pacman

Mirrorlist mặc định có mirror CDN đứng đầu, đo từ Việt Nam (2026-11-19) chỉ được ~11 KiB/s với gói lớn, dù file database nhỏ vẫn tải nhanh. Bước `mirrors` chạy [install/rank-mirrors.sh](../install/rank-mirrors.sh): tải thử vài giây một gói ~100 MB từ từng mirror ở VN, SG, HK, JP, TW, KR rồi giữ 8 mirror nhanh nhất (bản cũ lưu ở `/etc/pacman.d/mirrorlist.bak`). Thấy tải chậm lại thì chạy lại:

```sh
bash install/rank-mirrors.sh --dry-run   # chỉ đo, không ghi
bash install/rank-mirrors.sh
```

Đổi danh sách nước bằng `MIRROR_COUNTRIES=VN,SG,HK`.

## Repo được tổ chức thế nào

| Thư mục | Nội dung | Bước |
|---|---|---|
| `packages/` | `base`, `hyprland-desktop`, `apps`, `hardware-<host>` (repo chính thức), `aur` | `packages`, `aur` |
| `config/` | Dotfiles, mỗi thư mục là một gói GNU Stow | `dotfiles` |
| `system/etc/` | File `/etc` dùng cho mọi máy (zram, sysctl) | `system` |
| `hosts/<host>/etc/` | File `/etc` riêng từng máy (udev cho GPU, mkinitcpio cho NVIDIA) | `system` |

Máy mặc định là `tuf-f16`. Máy khác: tạo `hosts/<tên>/` và `packages/hardware-<tên>.txt`, rồi chạy với `SETUP_HOST=<tên>`. Máy không có phần riêng: `SETUP_HOST=none`.

Cài thêm gói thì nhớ ghi vào đúng file trong `packages/`, nếu không lần cài lại sẽ thiếu. Kiểm tra gói nào đã cài tay mà chưa có trong danh sách:

```sh
comm -23 <(pacman -Qqe | sort) <(sed -e 's/#.*//' -e '/^\s*$/d' packages/*.txt | sort)
```

## Kiểm tra sau khi chạy và reboot

```sh
lsmod | grep -E '^(nvidia|nouveau) '                          # phải có nvidia, không còn nouveau
ls -l /dev/dri/igpu /dev/dri/dgpu                              # hai link GPU ổn định
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status    # "suspended" khi không dùng dGPU
prime-run glxinfo -B | grep renderer                          # chạy một app trên dGPU (glxinfo: gói mesa-utils)
swapon --show                                                  # có /dev/zram0
powerprofilesctl                                               # có power profile
snapper list                                                   # có snapshot, thêm cặp pre/post sau mỗi lần pacman
systemctl is-active bluetooth                                  # active
```

Hyprland render trên iGPU Intel. Cổng HDMI nối vào dGPU, nên dGPU sẽ thức khi cắm màn hình ngoài.

## Sau mỗi lần nâng cấp Hyprland

Plugin `hyprbars` (thanh tiêu đề kiểu macOS) build theo đúng bản Hyprland đang cài. Sau khi Hyprland lên bản mới, thanh tiêu đề sẽ mất cho tới khi chạy:

```sh
hyprpm update && hyprpm reload
```

## Rollback khi update làm hỏng máy

`snap-pac` chụp snapshot `/` trước và sau mỗi lần `pacman`; `snapper-timeline` chụp thêm theo giờ. Snapshot chỉ gồm subvolume `@` (cả `/boot`, nên kernel cũng quay về); `@home`, `@log`, `@pkg` không bị đụng tới.

Kernel cmdline ghim `rootflags=subvol=@`, nên `snapper rollback` **không** dùng được. Làm tay như sau:

1. **Xem snapshot nào còn tốt.** Ở menu GRUB chọn *Arch Linux snapshots*, chọn một snapshot trước lúc hỏng. Nó boot ở chế độ chỉ đọc, một vài service có thể báo lỗi, không sao. Nhớ số snapshot (`snapper list`).
2. **Thay `@` bằng snapshot đó** (từ máy đang boot snapshot, hoặc từ USB live):
   ```sh
   dev=$(findmnt -nvo SOURCE /)                 # từ USB live: tự điền phân vùng Btrfs, ví dụ /dev/nvme0n1p7
   sudo mount -o subvolid=5 "$dev" /mnt         # gốc Btrfs, thấy được @, @home, @snapshots...
   sudo mv /mnt/@ /mnt/@.broken-$(date +%F)
   sudo btrfs subvolume snapshot /mnt/@snapshots/<số>/snapshot /mnt/@
   sudo umount /mnt
   reboot
   ```
3. **Dọn dẹp** khi đã chắc máy chạy ổn: `sudo mount -o subvolid=5 "$dev" /mnt && sudo btrfs subvolume delete /mnt/@.broken-<ngày>`.
