# 07 – Phương án dự phòng: chuyển sang Ubuntu

Chưa làm, chỉ để sẵn cho trường hợp xấu nhất (bắt buộc phải dùng Ubuntu). Trước khi chuyển, hỏi lại lý do: nếu chỉ vì một phần mềm, thử trên Arch trước (pacman, AUR, Flatpak, distrobox), rẻ hơn nhiều so với đổi distro.

Ghi ngày 2026-11-23, theo Hyprland 0.57 và Quickshell trên Arch. Kiểm tra lại số phiên bản trước khi làm.

## Trở ngại lớn nhất: Hyprland và Quickshell

Bộ cấu hình dựa vào Hyprland 0.57 với cấu hình Lua: `hyprland.lua` (~670 dòng) và khoảng 20 chỗ gửi lệnh `hl.dsp...` / `(function() ... end)` trong Quickshell (`Taskbar.qml`, `Overview.qml`, `ActiveWindow.qml`, `PowerButton.qml`, `Settings.qml`) và script (`toggle-maximize.sh`, `minimize.sh`). Vài tính năng chỉ có nhờ Lua: `keep_on_screen` (`hl.timer`), bắt lúc nhả Alt sau Alt+Tab (`hl.is_key_down`), Settings chỉnh chuột (`hl.config` lúc chạy).

| | A. Build Hyprland 0.57 từ mã nguồn | B. Dùng Hyprland trong kho Ubuntu |
|---|---|---|
| Cấu hình | Giữ nguyên | Viết lại `hyprland.lua` sang hyprlang, sửa ~20 chỗ gửi lệnh |
| Tính năng | Giữ đủ | Mất hoặc phải làm lại: `keep_on_screen`, nhả Alt, Settings đổi chuột |
| Công sức | Build Hyprland + ~6 thư viện hypr* (hyprutils, hyprlang, aquamarine, hyprgraphics, hyprcursor, hyprwayland-scanner); cần GCC rất mới (15), tức Ubuntu 25.10 / 26.04 trở lên; mỗi lần cập nhật build lại | 1-2 ngày viết lại; bản trong kho có thể quá cũ |

Quickshell không có gói Ubuntu: build từ mã nguồn (CMake, Qt 6 đủ mới) ở cả hai đường. Kiểm tra trước trên USB live: `apt policy hyprland`, `apt policy qt6-base-dev`.

## Trước khi xóa Arch

1. Push mọi commit lên GitHub.
2. Sao lưu ngoài repo: `~/Documents`, `~/Pictures`, `~/code`, `~/.ssh`, profile trình duyệt, file `.env`, mật khẩu Wi-Fi (`/etc/NetworkManager/system-connections/`, cần sudo).
3. Chuẩn bị USB Ubuntu.

## Lúc cài

1. Cài cạnh Windows, dùng lại phân vùng EFI có sẵn. Không format phân vùng EFI (Windows boot từ đó).
2. Muốn giữ snapshot thì chọn Btrfs và tự chia subvolume (`@`, `@home`, `@snapshots`...); trình cài Ubuntu mặc định ext4.
3. Secure Boot + driver NVIDIA: trình cài hỏi mật khẩu MOK, nhớ để xác nhận ở lần boot sau.

## Sau khi cài

| Thứ | Trên Ubuntu |
|---|---|
| Driver NVIDIA | `ubuntu-drivers install` (dễ hơn Arch) |
| kitty, rofi, greetd, pipewire, wireplumber, fcitx5-unikey, brightnessctl, playerctl, cava, power-profiles-daemon, libinput-tools, stow | `apt` |
| hyprlock, hypridle, hyprpaper, hyprbars | phiên bản phải khớp Hyprland; nếu build Hyprland thì build luôn |
| Quickshell, nwg-dock-hyprland, cliphist, asusctl | build từ mã nguồn hoặc release / PPA |
| Font Lexend / Comfortaa, WhiteSur, palette, hình nền | mang nguyên (`stow`, script WhiteSur) |
| Dotfiles `config/` | `stow` như cũ, phần lớn chạy ngay |
| `system/`, `hosts/`: rule udev tên GPU, logind chống suspend, `nvidia-power.conf` | chép như cũ |
| Drop-in mkinitcpio cho NVIDIA | chuyển sang initramfs-tools |
| Hibernate | initramfs-tools cần `resume=` + `resume_offset` cho swapfile (Arch với initramfs systemd thì không) |
| grub-btrfs | không có gói, cài tay |
| `install/setup.sh`, `packages/*.txt` | viết lại theo apt; `arch-install.sh` bỏ |

## Có thể gặp

- Hyprland không chính thức hỗ trợ Ubuntu; lỗi do thư viện lệch phiên bản phải tự xử lý.
- Muốn bản mới của Hyprland / Quickshell thì tự build lại (trên Arch chỉ `pacman -Syu`).
- Suspend có thể khác với kernel của Ubuntu (có khi lại chạy được).
- Laptop có MUX (Intel / NVIDIA): mặc định chọn GPU của Ubuntu khác Arch, có thể phải chỉnh để phiên chạy trên iGPU (`AQ_DRM_DEVICES`).
- Thời gian: đường A ~2-4 ngày để giống hiện tại; đường B ít build hơn nhưng phải viết lại và có thể mất tính năng.
