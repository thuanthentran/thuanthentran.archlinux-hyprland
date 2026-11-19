# 02 – Máy mục tiêu: ASUS TUF Gaming F16

Kết quả đọc cấu hình từ Windows ngày 2026-11-15. Chỉ đọc, không thay đổi gì trên máy.

## Cấu hình

| Thành phần | Kết quả |
|---|---|
| Máy | ASUS TUF Gaming F16 (FX607VU), BIOS FX607VUR.340 |
| CPU | Intel Core 5 210H, 8 nhân, 12 luồng |
| RAM | 16 GB |
| GPU | Intel Graphics + NVIDIA GeForce RTX 4050 Laptop (hybrid) |
| Màn hình | 1920×1200 @ 144 Hz |
| Wi-Fi | Realtek 8852BE (Wi-Fi 6) |
| Bluetooth | Realtek |
| Ethernet | Realtek PCIe GbE |
| Ổ đĩa | Một NVMe WD SN5000S 512 GB, GPT, nằm sau Intel RST VMD |
| Windows | 11 Home Single Language, Insider Preview, build 26320 |

## Bố cục ổ đĩa lúc kiểm tra

| # | Loại | Dung lượng | Ghi chú |
|---|---|---|---|
| 1 | EFI System | 450 MB | Dùng chung với Arch, không format |
| 2 | Microsoft Reserved | 16 MB | |
| 3 | C: (NTFS) | 279.8 GB | Còn trống 38.2 GB |
| 4 | Recovery | 1093 MB | |
| 5 | D: (NTFS) | 195.3 GB | Còn trống 37.1 GB |
| 6 | Recovery | 260 MB | |

Không còn vùng chưa cấp phát.

## Trạng thái firmware và Windows

| Mục | Trạng thái |
|---|---|
| Secure Boot | Đang bật |
| Fast Startup | Đang bật, có file hibernate |
| Đồng hồ phần cứng | Windows dùng giờ địa phương |
| BitLocker | Chưa xác nhận được (lệnh kiểm tra cần quyền admin) |

## Vấn đề và ảnh hưởng

1. **Hết chỗ trên ổ đĩa.** Thu nhỏ D ở trạng thái trên chỉ lấy được khoảng 35 GB, quá ít cho máy dev. Cần dọn D để có ít nhất 80 GB, hoặc gắn thêm SSD.
2. **Intel VMD.** Kernel Arch có driver `vmd`, nên để nguyên. Không tắt VMD trong BIOS vì Windows sẽ không boot được. Thêm `vmd` vào initramfs khi cài.
3. **Secure Boot.** Phải tắt để boot USB cài Arch. Nếu cần bật lại (game có anti-cheat trên Windows) thì phải ký bootloader bằng `sbctl`.
4. **Wi-Fi Realtek 8852BE.** Có driver trong kernel (`rtw89`), nhưng chip này có tiếng hay rớt mạng trên Linux. Khi cài nên có Ethernet hoặc USB tethering dự phòng.
5. **GPU hybrid.** Hyprland chạy trên Intel để tiết kiệm pin, NVIDIA bật khi cần. Dùng driver `nvidia-open`.
6. **Laptop TUF.** Cần `asusctl` và `supergfxctl` để chỉnh quạt, đèn bàn phím, giới hạn sạc, chế độ GPU.
7. **Windows Insider Preview.** Cập nhật lớn thường xuyên, khả năng thứ tự boot bị đặt lại cao hơn bản thường.

## Điểm thuận lợi

- Phân vùng EFI 450 MB đủ rộng, không bị ép vào một bootloader cụ thể.
- Màn hình 1920×1200 không cần fractional scaling.
- 16 GB RAM đủ cho dev; dùng zram thay vì phân vùng swap.

## Kiểm tra lại từ Arch (2026-11-20)

Sau khi cài xong, đọc lại từ Arch (không cần quyền root):

| Mục | Kết quả | Cách kiểm tra |
|---|---|---|
| HDMI | Nối vào NVIDIA (`card0-HDMI-A-1`, tức `/dev/dri/dgpu`) | `ls /sys/class/drm` |
| Cổng màn hình khác | NVIDIA có thêm `DP-5`, Intel có `DP-1`…`DP-4`; máy có Thunderbolt/USB4 (`/sys/bus/thunderbolt`) | như trên |
| BitLocker | Không bật: C: vẫn là `ntfs`, không phải `BitLocker` | `lsblk -f` |
| Secure Boot | Đang tắt | biến EFI `SecureBoot` = 0 |
| Ổ đĩa | Vẫn một NVMe; D: còn 115 GB, Arch (Btrfs) 80 GB | `lsblk` |

## Chưa xác minh

- Cổng USB-C nào ra màn hình qua GPU nào (`DP-5` trên NVIDIA hay `DP-1`…`DP-4` trên Intel). Cắm thử một màn hình qua USB-C rồi xem `hyprctl monitors`.
- Máy có khe M.2 thứ hai còn trống hay không. Phần mềm không thấy khe trống; xem `sudo dmidecode -t slot` hoặc mở nắp máy.
