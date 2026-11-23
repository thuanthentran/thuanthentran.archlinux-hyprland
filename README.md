# archlinux_hyprland

Cấu hình Arch Linux + Hyprland cá nhân. Mục tiêu là cài lại Arch trên máy cũ hoặc máy khác, clone repo này, chạy vài lệnh là có lại đúng môi trường.

## Trạng thái

Arch và Hyprland đã chạy trên máy thật (2026-11-19). Repo có đủ danh sách gói, dotfiles, file hệ thống và [install/setup.sh](install/setup.sh) để dựng lại desktop từ một bản Arch nền. Chưa thử cài lại từ đầu.

Giao diện (2026-11-23): tông trắng, đen, xanh lá từ một bảng màu duy nhất; thanh trên cùng, overview / Alt+Tab / vuốt 3 ngón, trang app, màn khóa và màn đăng nhập (greetd) đều viết bằng Quickshell; cửa sổ phóng to đưa tiêu đề và 3 nút lên thanh trên cùng.

## Cài nhanh

Từ USB Arch, sau khi nối mạng:

```sh
curl -LO https://raw.githubusercontent.com/thuanthentran/thuanthentran.archlinux-hyprland/main/install/arch-install.sh
bash arch-install.sh --dry-run
bash arch-install.sh
```

Chi tiết và cách cài thủ công: [docs/04-install-arch.md](docs/04-install-arch.md).

Sau khi boot vào Arch, đăng nhập user thường:

```sh
git clone https://github.com/thuanthentran/thuanthentran.archlinux-hyprland.git ~/code/thuanthentran.archlinux-hyprland
cd ~/code/thuanthentran.archlinux-hyprland
bash install/setup.sh --dry-run
bash install/setup.sh
```

Chi tiết, kiểm tra sau khi cài và cách rollback: [docs/06-setup-and-rollback.md](docs/06-setup-and-rollback.md).

## Tài liệu

| Tài liệu | Nội dung |
|---|---|
| [01 – Vì sao Arch + Hyprland](docs/01-why-arch-hyprland.md) | So sánh với Ubuntu, hiệu năng, hai nỗi lo chính và cách xử lý |
| [02 – Máy mục tiêu](docs/02-machine-tuf-f16.md) | Cấu hình ASUS TUF F16 và những gì nó ảnh hưởng tới việc cài |
| [03 – Chuẩn bị Windows](docs/03-windows-dual-boot-prep.md) | Việc cần làm trên Windows trước khi dual-boot |
| [04 – Cài Arch từ USB](docs/04-install-arch.md) | Cài bằng script hoặc từng lệnh, đọc được trên điện thoại |
| [05 – Kế hoạch repo](docs/05-repo-plan.md) | Cấu trúc dự kiến, lựa chọn mặc định, việc chưa quyết định |
| [06 – Dựng desktop và rollback](docs/06-setup-and-rollback.md) | Chạy setup.sh, kiểm tra sau khi cài, khôi phục từ snapshot |
| [07 – Dự phòng: chuyển sang Ubuntu](docs/07-migrate-to-ubuntu.md) | Việc cần làm và rủi ro nếu buộc phải bỏ Arch |

## Lộ trình

Mốc lớn. Việc cụ thể và thứ tự làm: [TODO.md](TODO.md).

- [x] Giải phóng dung lượng và thu nhỏ ổ D
- [x] Viết script cài Arch nền
- [x] Cài Arch tối thiểu, dual-boot với Windows
- [x] Cho Hyprland chạy được trên máy thật
- [x] Đưa config vào repo
- [x] Viết danh sách gói và script cài đặt
- [x] Thiết lập snapshot Btrfs (snapper, snap-pac, grub-btrfs)
- [x] Thanh trên cùng bằng Quickshell thay Waybar (cài đặt nhanh, đồ thị hệ thống, media, lời bài hát)
- [x] Refactor giao diện đợt 2: bảng màu trắng đen xanh lá, font, launcher, màn khóa, màn đăng nhập, Settings
- [ ] Cài thử lại từ đầu để kiểm tra khả năng tái lập
