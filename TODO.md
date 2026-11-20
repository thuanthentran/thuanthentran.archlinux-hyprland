# TODO

Backlog của repo, xếp theo thứ tự nên làm. Mốc lớn nằm ở mục "Lộ trình" trong [README](README.md); file này là việc cụ thể. Làm xong việc nào thì gạch (`[x]`) trong cùng commit, rồi dọn các mục đã gạch khi danh sách dài.

## Ngay bây giờ

- [ ] Push các commit đang chờ lên GitHub
- [x] Thêm `LICENSE` (MIT, đã chốt trong [docs/05](docs/05-repo-plan.md))
- [x] Tạo snapshot mốc: `sudo snapper -c root create -d "baseline sau setup"` (snapshot #2, 2026-11-20)
- [x] Cập nhật [docs/04](docs/04-install-arch.md) theo lần cài thật: bỏ cảnh báo "chưa được chạy thử", sửa những bước khác với thực tế
- [x] Rà mục "Chưa xác minh" trong [docs/02](docs/02-machine-tuf-f16.md) (BitLocker...) giờ đã có Arch chạy trên máy

## Giao diện: thanh trên cùng bằng Quickshell

Thay Waybar bằng thanh viết bằng Quickshell, rồi biến nó thành "control center" ngay trên thanh. Mỗi bước một commit, chạy thử xong mới sang bước sau.

- [x] Dựng khung: cài `quickshell`, thêm vào `packages/`, autostart trong `hyprland.lua`, hot reload chạy được
- [x] Bước 1: thanh Quickshell giống Waybar cũ; âm lượng / Wi-Fi chỉ còn icon, Bluetooth chỉ hiện khi bật, nút nguồn mở menu (Lock, Sleep, Log out, Restart và Shut down bấm 2 lần)
- [x] Bước 2: cụm âm lượng / độ sáng / Wi-Fi / Bluetooth (tray tách ra ngoài) bấm vào thì bung ngang ngay trên thanh (đồ thị CPU / RAM hiện thêm %, ngày tháng ẩn), rời chuột thì thu về; animation trong thanh, kích thước thanh không đổi
- [x] Bước 3: đồ thị CPU / RAM nhỏ (lấy mẫu mỗi giây, giữ ~60 điểm, chạy cả khi chưa bung), tốc độ mạng ↓ / ↑
- [x] Bước 4: popup khi bấm trong cụm đã bung: Wi-Fi (chọn mạng, nhập mật khẩu), âm lượng (mixer theo app, chọn thiết bị ra), Bluetooth (danh sách thiết bị). Thanh âm lượng / độ sáng, tên Wi-Fi + %, bật tắt Bluetooth và power profile đã có từ bước 2
- [x] Bước 5: media (MPRIS): tên bài, thanh thời gian, nút điều khiển, visualizer bằng `cava`
- [x] Bước 6: peak meter đè lên thanh âm lượng (`PwNodePeakMonitor`); lời bài hát (LRCLIB, có cache), làm cho chạy được trước rồi hoàn thiện sau
- [x] Âm thanh: card NVIDIA rơi vào profile "Pro Audio" khi không cắm màn hình (4 output HDMI "ma", có lúc thành output mặc định); đã ẩn Pro Audio bằng rule WirePlumber trong `config/wireplumber`
- [x] Lời bài hát: chọn kết quả khác (‹ ›), chỉnh lệch thời gian (− / +), tự gõ câu tra; nhớ theo từng bài
- [x] Bước 7: bỏ `config/waybar` và gói `waybar`, bỏ `nm-applet` / `blueman-applet` khỏi autostart (giữ gói vì nút settings trong popup dùng `nm-connection-editor` / `blueman-manager`)
- [x] Bluetooth: agent ghép đôi riêng (`scripts/bt-agent.py`) thay cho `blueman-applet`; hỏi xác nhận mã qua thông báo có nút Pair / Cancel, PIN qua rofi
- [x] OSD khi đổi âm lượng / độ sáng (thay cho việc không có phản hồi gì)
- [x] Lịch + thông báo khi bấm đồng hồ (Quickshell thay mako)

## Cửa sổ và desktop

- [ ] Bấm icon trên dock (nwg-dock) của app đang minimize có thể mở ngăn ẩn thay vì đưa cửa sổ về; kiểm tra và sửa (hoặc để Quickshell làm dock sau này)
- [ ] Kéo cửa sổ lên thanh trên cùng rồi giữ chuột đứng yên ~1 giây: kiểm tra cửa sổ có bị đẩy về trước khi thả không (tùy `hl.is_key_down(272)` có đọc được nút chuột không)
- [ ] Vuốt 3 ngón đôi lúc chỉ lẩn quẩn giữa 2 cửa sổ (đã có ý tưởng, làm sau)
- [ ] Thanh trên cùng: hiện số cửa sổ đang minimize trên nút 󰘸
- [ ] Nút trên thanh tiêu đề: giữ màu macOS hay đổi sang kiểu Windows (icon xám, nút đóng đỏ khi hover)
- [ ] Chốt phong cách: bảng màu, mức animation và blur (đang mở trong [docs/05](docs/05-repo-plan.md))
- [ ] Cắm màn hình qua USB-C, xem đi qua GPU nào (`hyprctl monitors`); ghi vào [docs/02](docs/02-machine-tuf-f16.md)
- [ ] Power profile: tự `balanced` khi chạy pin, `performance` khi cắm sạc (power-profiles-daemon hoặc udev rule)

## Hệ thống và tái lập

- [x] Hibernate: swapfile 16 GB trên subvolume `@swap` (`setup.sh hibernate`), có trong menu nguồn, hypridle tự hibernate sau 30 phút
- [ ] Sleep thật (suspend to RAM) treo ở giai đoạn noirq/ACPI; đang thay bằng khóa + tắt màn hình. Nếu muốn dò tiếp: boot không có driver NVIDIA (`module_blacklist=nvidia,nvidia_modeset,nvidia_drm,nvidia_uvm`), rồi `pcie_port_pm=off`; xem bản BIOS mới hơn FX607VUR.340

- [ ] Thiết lập distrobox (Ubuntu) cho app chỉ có trên Ubuntu
- [ ] Kiểm tra phần mềm công việc bắt buộc trên Arch (VPN công ty, tool của hãng)
- [ ] Quyết định có dùng ổ D làm ổ dữ liệu chung với Windows không
- [ ] Cài lại từ đầu (máy ảo hoặc phân vùng thử) bằng `arch-install.sh` + `setup.sh` để chứng minh repo tái lập được
