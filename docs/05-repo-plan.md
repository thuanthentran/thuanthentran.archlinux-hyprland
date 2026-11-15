# 05 – Kế hoạch cho repo

Mục tiêu: cài lại Arch trên máy cũ hoặc máy khác, clone repo, chạy vài lệnh là có lại đúng môi trường. Repo công khai trên GitHub.

## Tái lập được tới mức nào

- **Tái lập cấu hình, không tái lập phiên bản.** Arch là rolling release, cài lại sau 6 tháng sẽ ra gói mới hơn. Muốn giống hệt từng phiên bản thì phải dùng NixOS, một hướng khác hẳn.
- **Hyprland hay đổi cú pháp config.** Thỉnh thoảng phải sửa repo cho khớp bản mới.

## Cấu trúc dự kiến

Chưa có thư mục nào dưới đây ngoài `docs/`.

```text
.
├── README.md
├── LICENSE
├── .gitattributes        # ép line ending LF
├── .gitignore            # chặn file bí mật
├── docs/                 # tài liệu
├── packages/             # danh sách gói theo nhóm
├── config/               # dotfiles, mỗi thành phần một thư mục
├── hosts/                # phần riêng từng máy
└── install.sh            # cài gói, link config, bật service
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
| App chỉ có trên Ubuntu | distrobox | Xem [01-why-arch-hyprland.md](01-why-arch-hyprland.md) |
| Giao diện | Tự dựng từ tối thiểu | Tham khảo HyDE, ML4W, end-4, không fork |
| License | MIT | |

## Chưa quyết định

- Bộ thành phần giao diện: bar, launcher, thông báo, khóa màn hình, terminal, shell.
- Phong cách: bảng màu, font, mức độ animation và blur.
- AUR helper: `yay` hay `paru`.
- Có dùng ổ D làm ổ dữ liệu chung với Windows không.
- Phần mềm công việc bắt buộc nào cần kiểm tra trước trên Arch (VPN công ty, tool của hãng).

## Nguyên tắc làm việc

- **Không test được từ Windows.** Config viết trên Windows chỉ là bản nháp. Cài Arch tối thiểu trước, cho Hyprland chạy, rồi đưa dần vào repo và chỉnh trên máy thật.
- **Line ending.** Repo đang nằm trên Windows, cần `.gitattributes` ép LF và đặt quyền thực thi cho script qua git, nếu không script lỗi khi clone về Arch.
- **Đối chiếu tài liệu hiện hành.** Cú pháp Hyprland đổi nhanh, viết config phải xem wiki bản đang cài.
- **Không commit bí mật.** SSH key, token, mật khẩu Wi-Fi nằm ngoài repo.
- **Tách phần riêng từng máy.** Màn hình, driver GPU, hostname nằm trong `hosts/`.

## Việc kỹ thuật cần nhớ khi viết script

- `genfstab` ghi cả `subvolid` vào fstab. Cần bỏ `subvolid` để rollback bằng snapper hoạt động đúng.
- `/.snapshots` đã được mount sẵn từ lúc cài, nên `snapper create-config` sẽ báo trùng. Script phải xử lý trường hợp này.
- Module `vmd` phải nằm trong `MODULES` của mkinitcpio trên máy TUF F16.
- Xác minh cổng HDMI/USB-C nối vào GPU nào trước khi viết config màn hình ngoài.
