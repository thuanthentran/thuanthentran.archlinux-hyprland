# 03 – Chuẩn bị Windows để dual-boot

Những việc làm trên Windows trước khi boot USB cài Arch.

## Checklist

- [ ] Sao lưu dữ liệu quan trọng
- [ ] Giải phóng ít nhất 80 GB trên ổ D
- [ ] Thu nhỏ ổ D bằng Disk Management để có vùng Unallocated
- [ ] Tải ISO Arch từ archlinux.org, ghi ra USB (từ 4 GB) bằng Rufus hoặc Ventoy
- [ ] Chuẩn bị mạng dự phòng: dây Ethernet hoặc cáp USB cho điện thoại
- [ ] Tắt Secure Boot trong BIOS
- [ ] Quyết định về Fast Startup (xem bên dưới)

## Dung lượng

- Thu nhỏ phân vùng từ chính Windows, không thu nhỏ từ Linux.
- Chọn ổ D vì là ổ dữ liệu, thu nhỏ dễ hơn ổ C.
- Dung lượng trống phải nằm trên đúng ổ sẽ thu nhỏ.
- Nén thành file zip cần chỗ tạm cho file zip trước khi xóa thư mục gốc.

## BitLocker

Chủ máy chọn không kiểm tra trước. Nếu Windows hỏi recovery key thì lấy từ tài khoản Microsoft trên điện thoại.

Lưu ý: nếu ổ đang mã hóa và Secure Boot bị tắt, Windows có thể hỏi mã ở mỗi lần khởi động. Hai cách xử lý:

- Vào Windows, tạm dừng rồi bật lại BitLocker một lần.
- Boot Windows từ menu boot của BIOS (phím Esc) thay vì qua GRUB.

## Fast Startup

Không bắt buộc tắt. GRUB vẫn chuyển qua lại giữa hai hệ điều hành bình thường khi Fast Startup bật.

Rủi ro chỉ xuất hiện khi Arch ghi vào ổ C hoặc D trong lúc Windows đang ở trạng thái tắt của Fast Startup: dữ liệu NTFS có thể hỏng.

| Cách dùng | Việc cần làm |
|---|---|
| Không mount C/D từ Arch | Không cần làm gì |
| Giữ Fast Startup | Chuyển sang Arch bằng Restart, không dùng Shut down |
| Dùng D làm ổ dữ liệu chung | Tắt hẳn Fast Startup |

Tắt hẳn (Terminal quyền Admin), đồng thời xóa file hibernate:

```powershell
powercfg /h off
```

## Secure Boot

- USB cài Arch không boot được khi Secure Boot bật.
- Trên máy ASUS: F2 vào BIOS, mục Security, tắt Secure Boot. Esc là menu chọn thiết bị boot.
- Không đụng tới thiết lập VMD.

## Lệch giờ giữa hai hệ điều hành

Windows hiểu đồng hồ phần cứng là giờ địa phương, Linux hiểu là UTC. Sau khi cài Arch, cho Windows dùng UTC (Terminal quyền Admin):

```powershell
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /d 1 /t REG_DWORD /f
```

## Sau này

- Windows Update đôi khi đặt lại thứ tự boot. Không mất dữ liệu, chọn lại GRUB trong BIOS.
- Luôn boot được Windows trực tiếp từ menu boot của BIOS nếu GRUB gặp sự cố.
