# TODO

Backlog của repo, xếp theo thứ tự nên làm. Mốc lớn nằm ở mục "Lộ trình" trong [README](README.md); file này là việc cụ thể. Làm xong việc nào thì gạch (`[x]`) trong cùng commit, rồi dọn các mục đã gạch khi danh sách dài.

## Ngay bây giờ

- [x] Push các commit đang chờ lên GitHub
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

## Refactor giao diện (đợt 2)

Thứ tự đã chốt: nền móng trước, rồi sửa nhanh, diện mạo, tính năng, cuối cùng màn đăng nhập.

1. Nền móng
   - [x] Tổ chức lại Quickshell: `services/` (singleton dữ liệu), `modules/` (bar, overview, osd, launcher, lock...), `widgets/`; tách `Overview.qml` thành nhiều file
   - [x] `Settings` singleton lưu ra JSON (`JsonAdapter`), cửa sổ Settings (mới có chuột / touchpad; sẽ thêm màu nhấn, font, scale, thông số cử chỉ)
   - [x] Một nguồn màu duy nhất: `palette.json` trong config Quickshell (Theme đọc trực tiếp), `install/palette.py` ghi vào Hyprland, greeter, rofi, kitty, hyprlock; hình nền và accent GTK cũng đọc từ đó
2. Sửa nhanh
   - [x] Icon app trên taskbar lúc bấm được lúc không (nghi `DragHandler` giành cú bấm)
   - [x] Bỏ cụm 3 nút cửa sổ trên thanh (`WindowControls.qml`)
   - [x] Tốc độ chuột / touchpad tách riêng, chỉnh trong Settings
3. Diện mạo
   - [x] Tông trắng + đen + xanh lá, sạch, tối giản; xanh lá chỉ để nhấn, hover / chọn ám trắng xám (Quickshell, hyprbars, rofi, kitty, hình nền, accent GTK4)
   - [x] GTK3: WhiteSur bản xanh lá (gói AUR chỉ có bản xanh dương; tự build bằng `install.sh -t green` của WhiteSur vào `~/.themes`)
   - [x] Font: Lexend cho giao diện, Comfortaa cho chữ lớn (đã thử font pixel 8-bit, bỏ); chọn lại được trong Settings
   - [x] Sửa chữ "rách" nét xéo, nét cong trong Quickshell (`NativeTextRendering`)
   - [ ] Scale / DPI: tạm gác. Scale < 1 làm chữ mờ (app không tự vẽ ở scale lẻ) và VS Code vẽ lệch khi đổi lúc đang chạy; hướng còn lại là thu nhỏ từng app (zoom VS Code, cờ Chrome, font GTK / kitty, cỡ trong Theme.qml)
   - [x] Panel (lịch + thông báo, media, Wi-Fi, Bluetooth, âm lượng, menu nguồn) mọc ra từ nút trên thanh bằng nội suy hình học, thay slide + fade
   - [x] Thanh trên cùng thấp hơn (26 px), tùy chọn tự ẩn trong Settings (chạm mép trên thì hiện)
   - [x] Thanh tiêu đề mảnh (20 px), 3 nút là chấm nhỏ, ký hiệu chỉ hiện khi rê chuột
   - [x] Cửa sổ phóng to thì ẩn thanh tiêu đề, tên + 3 nút lên thanh trên cùng (phương án C; tag `maximized`)
4. Tính năng
   - [x] Trang app (launcher) bằng Quickshell thay nwg-drawer, theo concept trắng đen xanh lá
   - [x] Gỡ gói `nwg-drawer` trên máy; Super+Space mở launcher thay rofi
   - [x] Cửa sổ mới mở ở 70% màn hình, căn giữa (rule `open-large`; trừ hộp thoại modal, PiP, cửa sổ tiện ích)
5. Đăng nhập
   - [x] Khóa màn hình bằng Quickshell thay hyprlock (`modules/lock`; hyprlock còn làm dự phòng)
   - [x] Màn đăng nhập lúc boot cùng giao diện với màn khóa: greetd + greeter Quickshell (`extras/greeter`, bước `setup.sh greeter`)
   - [x] Chạy `sudo pacman -S greetd && bash install/setup.sh greeter` trên máy, reboot, kiểm tra đăng nhập
   - [ ] Gỡ sddm khi greetd đã chạy ổn một thời gian (`sudo pacman -Rns sddm`, bỏ khỏi packages/hyprland-desktop.txt)

## Cửa sổ và desktop

- [x] Bấm icon trên dock (nwg-dock) của app đang minimize mở ngăn ẩn thay vì đưa cửa sổ về: `ActiveWindow.qml` thấy ngăn ẩn mở mà không phải do Super+Shift+S thì đưa cửa sổ về
- [ ] Kéo cửa sổ lên thanh trên cùng rồi giữ chuột đứng yên ~1 giây: kiểm tra cửa sổ có bị đẩy về trước khi thả không (tùy `hl.is_key_down(272)` có đọc được nút chuột không)
- [x] Đa nhiệm kiểu thanh home iOS (`Overview.qml`), thay cho vuốt 3 ngón cũ hay lẩn quẩn giữa 2 cửa sổ:
  - [x] Overview: nhấn Super / Super+Tab hiện mọi cửa sổ trong workspace
  - [x] Alt+Tab / Alt+Shift+Tab: nhấn nhanh nhảy thẳng, giữ Alt hiện dải cửa sổ
  - [x] Helper đọc touchpad (libinput) + udev rule `uaccess` cho riêng touchpad, bỏ cử chỉ 3 ngón của Hyprland
  - [x] Vuốt ngang 3 ngón: chuyển thẳng cửa sổ trước / sau (dải phim tuyến tính, cửa sổ thu về 70% khi vuốt)
  - [x] Thêm trục dọc: kéo lên thì cửa sổ nhỏ dần thành dải, kéo đủ cao thì vào overview, kéo xuống lại thì thu về
  - [x] Thứ tự cửa sổ cố định, chung với taskbar; kéo thả trên taskbar / lưới overview để sắp xếp
  - [x] Gõ để tìm cửa sổ và app trong overview
  - [x] Dải Alt+Tab: khoảng cách giữa các ô theo kích thước từng ô (khe 60 px, `stripAt`)
- [x] ~~Thanh trên cùng: hiện số cửa sổ đang minimize trên nút 󰘸~~ không cần: nút đó là của Waybar cũ, cửa sổ minimize giờ hiện mờ ngay trên taskbar
- [ ] Power profile: tự `balanced` khi chạy pin, `performance` khi cắm sạc (power-profiles-daemon hoặc udev rule)

## Hệ thống và tái lập

Cần ngồi ở máy (sudo, cắm thiết bị, reboot); để sau các việc giao diện.

- [ ] Cắm màn hình qua USB-C, xem đi qua GPU nào (`hyprctl monitors`); ghi vào [docs/02](docs/02-machine-tuf-f16.md)
- [x] Hibernate: swapfile 16 GB trên subvolume `@swap` (`setup.sh hibernate`), có trong menu nguồn, hypridle tự hibernate sau 30 phút
- [ ] Sleep thật (suspend to RAM) treo ở giai đoạn noirq/ACPI; đang thay bằng khóa + tắt màn hình. Nếu muốn dò tiếp: boot không có driver NVIDIA (`module_blacklist=nvidia,nvidia_modeset,nvidia_drm,nvidia_uvm`), rồi `pcie_port_pm=off`; xem bản BIOS mới hơn FX607VUR.340

- [ ] Thiết lập distrobox (Ubuntu) cho app chỉ có trên Ubuntu
- [ ] Kiểm tra phần mềm công việc bắt buộc trên Arch (VPN công ty, tool của hãng)
- [ ] Quyết định có dùng ổ D làm ổ dữ liệu chung với Windows không
- [ ] Cài lại từ đầu (máy ảo hoặc phân vùng thử) bằng `arch-install.sh` + `setup.sh` để chứng minh repo tái lập được

## Để sau

- [ ] (Có thể) nhớ kích thước / vị trí cửa sổ theo từng app
