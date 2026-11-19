# TODO

Backlog của repo, xếp theo thứ tự nên làm. Mốc lớn nằm ở mục "Lộ trình" trong [README](README.md); file này là việc cụ thể. Làm xong việc nào thì gạch (`[x]`) trong cùng commit, rồi dọn các mục đã gạch khi danh sách dài.

## Ngay bây giờ

- [ ] Push các commit đang chờ lên GitHub
- [ ] Thêm `LICENSE` (MIT, đã chốt trong [docs/05](docs/05-repo-plan.md))
- [ ] Tạo snapshot mốc: `sudo snapper -c root create -d "baseline sau setup"`
- [ ] Cập nhật [docs/04](docs/04-install-arch.md) theo lần cài thật: bỏ cảnh báo "chưa được chạy thử", sửa những bước khác với thực tế
- [ ] Rà mục "Chưa xác minh" trong [docs/02](docs/02-machine-tuf-f16.md) (BitLocker...) giờ đã có Arch chạy trên máy

## Giao diện: Quickshell

Chạy song song với Waybar, thay dần từng phần. Mỗi widget là một Stow package hoặc một thư mục trong `config/quickshell/`.

- [ ] Dựng khung: cài `quickshell`, thêm vào `packages/`, autostart trong `hyprland.lua`, hot reload chạy được
- [ ] Control Center: panel bật ra từ Waybar với Wi-Fi, Bluetooth, âm lượng, độ sáng, power profile
- [ ] OSD khi đổi âm lượng / độ sáng (thay cho việc không có phản hồi gì)
- [ ] Lịch + thông báo khi bấm đồng hồ
- [ ] Trình phát nhạc (MPRIS)
- [ ] Cân nhắc thay Waybar hoàn toàn khi các widget trên đã ổn

## Cửa sổ và desktop

- [ ] Bấm icon trên dock (nwg-dock) của app đang minimize có thể mở ngăn ẩn thay vì đưa cửa sổ về; kiểm tra và sửa (hoặc để Quickshell làm dock sau này)
- [ ] Kéo cửa sổ lên Waybar rồi giữ chuột đứng yên ~1 giây: kiểm tra cửa sổ có bị đẩy về trước khi thả không (tùy `hl.is_key_down(272)` có đọc được nút chuột không)
- [ ] Waybar: hiện số cửa sổ đang minimize trên nút 󰘸
- [ ] Nút trên thanh tiêu đề: giữ màu macOS hay đổi sang kiểu Windows (icon xám, nút đóng đỏ khi hover)
- [ ] Chốt phong cách: bảng màu, mức animation và blur (đang mở trong [docs/05](docs/05-repo-plan.md))
- [ ] Power profile: tự `balanced` khi chạy pin, `performance` khi cắm sạc (power-profiles-daemon hoặc udev rule)

## Hệ thống và tái lập

- [ ] Thiết lập distrobox (Ubuntu) cho app chỉ có trên Ubuntu
- [ ] Kiểm tra phần mềm công việc bắt buộc trên Arch (VPN công ty, tool của hãng)
- [ ] Quyết định có dùng ổ D làm ổ dữ liệu chung với Windows không
- [ ] Cài lại từ đầu (máy ảo hoặc phân vùng thử) bằng `arch-install.sh` + `setup.sh` để chứng minh repo tái lập được
