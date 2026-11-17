# archlinux_hyprland

Cấu hình Arch Linux + Hyprland cá nhân. Mục tiêu là cài lại Arch trên máy cũ hoặc máy khác, clone repo này, chạy vài lệnh là có lại đúng môi trường.

## Trạng thái

Đang ở giai đoạn chuẩn bị (2026-11-17). Repo có tài liệu và script cài Arch nền ([install/arch-install.sh](install/arch-install.sh)); script chưa chạy trên máy thật. Chưa có config Hyprland, và Arch chưa được cài trên máy.

## Cài nhanh

Từ USB Arch, sau khi nối mạng:

```sh
curl -LO https://raw.githubusercontent.com/thuanthentran/thuanthentran.archlinux-hyprland/main/install/arch-install.sh
bash arch-install.sh --dry-run
bash arch-install.sh
```

Chi tiết và cách cài thủ công: [docs/04-install-arch.md](docs/04-install-arch.md).

## Tài liệu

| Tài liệu | Nội dung |
|---|---|
| [01 – Vì sao Arch + Hyprland](docs/01-why-arch-hyprland.md) | So sánh với Ubuntu, hiệu năng, hai nỗi lo chính và cách xử lý |
| [02 – Máy mục tiêu](docs/02-machine-tuf-f16.md) | Cấu hình ASUS TUF F16 và những gì nó ảnh hưởng tới việc cài |
| [03 – Chuẩn bị Windows](docs/03-windows-dual-boot-prep.md) | Việc cần làm trên Windows trước khi dual-boot |
| [04 – Cài Arch từ USB](docs/04-install-arch.md) | Cài bằng script hoặc từng lệnh, đọc được trên điện thoại |
| [05 – Kế hoạch repo](docs/05-repo-plan.md) | Cấu trúc dự kiến, lựa chọn mặc định, việc chưa quyết định |

## Lộ trình

- [x] Giải phóng dung lượng và thu nhỏ ổ D
- [x] Viết script cài Arch nền
- [ ] Cài Arch tối thiểu, dual-boot với Windows
- [ ] Cho Hyprland chạy được trên máy thật
- [ ] Đưa config vào repo
- [ ] Viết danh sách gói và script cài đặt
- [ ] Thiết lập snapshot Btrfs và distrobox
- [ ] Cài thử lại từ đầu để kiểm tra khả năng tái lập
