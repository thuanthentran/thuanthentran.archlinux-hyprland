# 01 – Vì sao Arch Linux + Hyprland

Ghi lại phần cân nhắc trước khi bắt đầu, ngày 2026-11-15.

## Mục đích sử dụng

- Máy cá nhân, môi trường dev và làm việc hằng ngày.
- Không dùng cho production. Server vẫn nên là Ubuntu Server.
- Tinh thần là "vọc": chấp nhận thỉnh thoảng phải tự sửa, đổi lại được một giao diện của riêng mình.
- Giữ Windows để dual-boot.

## Arch hạn chế gì so với Ubuntu

Hạn chế nằm ở độ ổn định và mức hỗ trợ chính thức, không nằm ở khả năng.

| Điểm | Ý nghĩa thực tế |
|---|---|
| Không có bản LTS | Rolling release, gói luôn mới. Thỉnh thoảng một lần update làm hỏng thứ gì đó và phải tự sửa. |
| Phần mềm thương mại ưu tiên Ubuntu | Nhiều hãng chỉ phát hành `.deb`. Trên Arch thường cài được qua AUR, nhưng đó là gói cộng đồng, không ai bảo chứng. |
| Không hợp làm server production | Không LTS, không hỗ trợ thương mại, không có unattended-upgrades an toàn. |
| Không có gì cấu hình sẵn | Bluetooth, âm thanh, máy in, firewall, codec, Secure Boot đều tự cài và tự bật. |
| Hyprland không phải desktop environment | Chỉ là compositor. Bar, launcher, thông báo, khóa màn hình, polkit agent, chia sẻ màn hình phải tự ghép. |
| Chỉ chạy Wayland | App X11 chạy qua XWayland, đa số ổn. NVIDIA dùng được nhưng cần cấu hình kỹ hơn AMD/Intel. |

Bù lại: gói rất mới, AUR có gần như mọi thứ, Arch Wiki là tài liệu Linux tốt nhất hiện có.

## Độ khó cài đặt

Không còn khó như trước, nhất là với người đã quen Ubuntu Server (terminal, systemd, phân vùng).

- `archinstall`: trình cài dạng menu, nhanh, có sẵn profile Hyprland.
- Cài thủ công theo Arch Wiki: khoảng 1–2 giờ lần đầu, đổi lại hiểu rõ hệ thống.

Phần tốn thời gian thật sự là dựng giao diện Hyprland, không phải cài Arch.

Repo này chọn cài thủ công cho lần đầu, xem [04-install-arch.md](04-install-arch.md).

## Hiệu năng

- **RAM lúc idle**: ước lượng 500 MB–1 GB, so với khoảng 1.5–2 GB của Ubuntu GNOME. Đây là ước lượng, chưa đo trên máy này.
- **Độ mượt**: Hyprland render bằng GPU. Blur và shadow tốn GPU một chút, giảm hoặc tắt được.
- **Hiệu năng app**: compile, game, tính toán gần như ngang Ubuntu vì cùng Linux kernel. Lợi thế của Arch là ít tiến trình nền và kernel/driver mới hơn.

## Vì sao không dùng Ubuntu + Hyprland

Ubuntu chạy được Hyprland nhưng cồng kềnh hơn, và không giải quyết được nỗi lo về tương thích ngược:

- Hyprland cần compiler và thư viện rất mới (aquamarine, hyprlang, hyprutils, hyprcursor...), trong khi Ubuntu đóng băng phiên bản.
- Gói `hyprland` trong repo Ubuntu thường chậm hơn upstream nhiều bản. Cần kiểm tra phiên bản cụ thể nếu muốn cân nhắc lại.
- Muốn bản mới thì phải tự build hoặc dùng PPA/script cộng đồng, kể cả hyprlock, hypridle, hyprpaper, waybar.
- Dự án Hyprland không coi Ubuntu/Debian là nền tảng được hỗ trợ.

Hệ quả: hoặc dùng bản cũ (lệch với tài liệu và config mẫu), hoặc tự build bản mới và gặp đúng vấn đề đổi cú pháp config như trên Arch, cộng thêm công build.

## Hai nỗi lo và cách xử lý

### Cập nhật làm hỏng hệ thống

- **Snapshot Btrfs**: snapper tự chụp trước mỗi lần `pacman` chạy. Hỏng thì chọn snapshot cũ ngay từ menu boot.
- **Kernel dự phòng**: cài song song `linux-lts`.
- **Chủ động thời điểm**: Arch không tự cập nhật. Update khi rảnh, không update trước deadline.

Sự cố phổ biến nhất còn lại là Hyprland đổi cú pháp config: sửa vài dòng trong repo rồi commit.

### Phần mềm chỉ hỗ trợ Ubuntu

- **Distrobox**: chạy container Ubuntu ngay trong Arch, app bên trong (kể cả app có giao diện) dùng chung home và màn hình.
- **Công cụ dev phổ biến**: VS Code, JetBrains, Docker, Chrome, Slack, Zoom có trong repo chính thức, AUR hoặc Flatpak.
- **Môi trường dev trong container**: Docker/devcontainer chạy image Ubuntu trên Arch giống hệt trên Ubuntu.

Distrobox không cứu được phần mềm can thiệp sâu vào kernel hoặc hệ thống: một số VPN client của công ty, phần mềm giám sát doanh nghiệp, driver thiết bị đặc thù.

## Kết luận

Arch + Hyprland, kèm Btrfs snapshot và distrobox. Cả hai lưới an toàn này sẽ nằm trong script cài đặt của repo.
