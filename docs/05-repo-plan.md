# 05 – Kế hoạch cho repo

Mục tiêu: cài lại Arch trên máy cũ hoặc máy khác, clone repo, chạy vài lệnh là có lại đúng môi trường. Repo công khai trên GitHub.

## Tái lập được tới mức nào

- **Tái lập cấu hình, không tái lập phiên bản.** Arch là rolling release, cài lại sau 6 tháng sẽ ra gói mới hơn. Muốn giống hệt từng phiên bản thì phải dùng NixOS, một hướng khác hẳn.
- **Hyprland hay đổi cú pháp config.** Thỉnh thoảng phải sửa repo cho khớp bản mới.

## Cấu trúc dự kiến

Đã có đủ các thư mục dưới đây. Phần riêng của máy hiện tại nằm ở `hosts/tuf-f16/` và `packages/hardware-tuf-f16.txt`; cách dùng xem [06-setup-and-rollback.md](06-setup-and-rollback.md).

```text
.
├── README.md
├── LICENSE
├── .gitattributes        # ép line ending LF
├── .gitignore            # chặn file bí mật
├── docs/                 # tài liệu
├── install/
│   ├── arch-install.sh   # cài Arch nền từ USB live (đã có)
│   └── setup.sh          # sau khi boot: cài gói, link config, bật service (đã có)
├── packages/             # danh sách gói theo nhóm
├── config/               # dotfiles, mỗi thành phần một thư mục
├── system/               # file /etc dùng chung (zram, sysctl)
└── hosts/                # phần riêng từng máy
```

Nhóm gói dự kiến: nền, Hyprland, dev, NVIDIA, ASUS. Gói chính thức và gói AUR để riêng.

## Thứ tự làm

1. Dotfiles: config của Hyprland và các thành phần giao diện.
2. Danh sách gói và script cài đặt.
3. Tự động hóa bước cài hệ điều hành (script hoặc file `archinstall`).

## Lựa chọn mặc định

Đây là đề xuất, chưa chốt.

| Hạng mục | Lựa chọn | Lý do |
|---|---|---|
| Quản lý dotfiles | GNU Stow | Đơn giản, đủ cho một hai máy. chezmoi mạnh hơn khi nhiều máy khác nhau. |
| Filesystem | Btrfs + snapper | Rollback sau update hỏng |
| Bootloader | GRUB + grub-btrfs | Boot thẳng vào snapshot. Limine và systemd-boot cũng khả thi vì phân vùng EFI rộng 450 MB. |
| Kernel | `linux` + `linux-lts` | Luôn có kernel dự phòng |
| Driver NVIDIA | `nvidia-open` | Dòng RTX 40 được hỗ trợ |
| Swap | zram | Không cần phân vùng swap |
| AUR helper | `yay` | Đã dùng; setup.sh tự cài `yay-bin` |
| App chỉ có trên Ubuntu | distrobox | Xem [01-why-arch-hyprland.md](01-why-arch-hyprland.md) |
| Giao diện | Tự dựng từ tối thiểu | Tham khảo HyDE, ML4W, end-4, không fork |
| License | MIT | |

## Chưa quyết định

- Bộ thành phần giao diện: rofi, nwg-dock, hyprlock, kitty; thông báo do Quickshell đảm nhận (thay mako). Thanh trên cùng đã chuyển từ Waybar sang Quickshell (2026-11-20) để thêm widget có trạng thái; kế hoạch trong [TODO](../TODO.md).
- Phong cách: bảng màu, font, mức độ animation và blur.
- Có dùng ổ D làm ổ dữ liệu chung với Windows không.
- Phần mềm công việc bắt buộc nào cần kiểm tra trước trên Arch (VPN công ty, tool của hãng).

## Nguyên tắc làm việc

- **Không test được từ Windows.** Config viết trên Windows chỉ là bản nháp. Cài Arch tối thiểu trước, cho Hyprland chạy, rồi đưa dần vào repo và chỉnh trên máy thật.
- **Line ending.** Repo đang nằm trên Windows, cần `.gitattributes` ép LF và đặt quyền thực thi cho script qua git, nếu không script lỗi khi clone về Arch.
- **Đối chiếu tài liệu hiện hành.** Cú pháp Hyprland đổi nhanh, viết config phải xem wiki bản đang cài.
- **Không commit bí mật.** SSH key, token, mật khẩu Wi-Fi nằm ngoài repo.
- **Tách phần riêng từng máy.** Màn hình, driver GPU, hostname nằm trong `hosts/`.

## Việc kỹ thuật cần nhớ khi viết script

- `/.snapshots` đã được mount sẵn từ lúc cài, nên `snapper create-config` sẽ báo trùng. `setup.sh` (bước `snapper`) đã xử lý.
- Kernel cmdline ghim `rootflags=subvol=@`, nên `snapper rollback` không dùng được; rollback làm tay, xem [06](06-setup-and-rollback.md).
- `arch-install.sh` đã bỏ `subvolid` khỏi fstab và thêm module `vmd` qua `/etc/mkinitcpio.conf.d/10-vmd.conf`; script sau không cần làm lại.
- Xác minh cổng HDMI/USB-C nối vào GPU nào trước khi viết config màn hình ngoài.
