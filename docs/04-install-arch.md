# 04 – Cài Arch lần đầu từ USB

Hướng dẫn cài thủ công cho máy TUF F16, dual-boot với Windows. Viết để đọc trên điện thoại trong lúc gõ lệnh trên máy.

> **Chưa được chạy thử.** Các lệnh dưới đây viết ngày 2026-11-15, chưa chạy trên máy này. Sau lần cài đầu tiên cần sửa lại tài liệu theo thực tế.

Yêu cầu: đã làm xong [03-windows-dual-boot-prep.md](03-windows-dual-boot-prep.md).

## Vì sao cài thủ công

Nhiều lệnh hơn `archinstall`, nhưng mỗi bước đều kiểm tra được và không có rủi ro trình cài tự format nhầm phân vùng EFI của Windows.

## Quy ước

| Ký hiệu | Ý nghĩa |
|---|---|
| `pX` | Số phân vùng Arch mới tạo, nhiều khả năng là `p7` |
| `TEN_WIFI` | Tên mạng Wi-Fi |
| `TEN_BAN` | Tên user |
| `tuf` | Tên máy, tùy đặt |

## Bước 0 – Boot USB

1. Từ Windows chọn Restart.
2. Bấm Esc, chọn boot từ USB.
3. Chọn mục đầu tiên trong menu của Arch.

Chữ quá nhỏ thì chạy:

```sh
setfont ter-132b
```

## Bước 1 – Mạng và kiểm tra ổ đĩa

Cắm Ethernet là có mạng ngay. Nếu Wi-Fi không lên, cắm điện thoại và bật USB tethering.

```sh
iwctl
```

Trong dấu nhắc của `iwctl`:

```text
station wlan0 scan
station wlan0 connect "TEN_WIFI"
exit
```

Kiểm tra:

```sh
ping -c 3 archlinux.org
cat /sys/firmware/efi/fw_platform_size
lsblk -f
```

Kết quả mong đợi:

- `fw_platform_size` in ra `64`.
- `lsblk -f` hiện `nvme0n1`, trong đó `p1` là vfat khoảng 450M và có các phân vùng ntfs.

**Không thấy ổ nvme nào thì dừng lại.** Đó là vấn đề VMD, đừng làm tiếp.

## Bước 2 – Tạo phân vùng cho Arch

```sh
cfdisk /dev/nvme0n1
```

Chọn dòng Free space → New → Enter (lấy hết) → Write → gõ `yes` → Quit.

```sh
lsblk
```

Ghi lại số phân vùng mới và dùng nó thay cho `pX` từ đây trở đi.

## Bước 3 – Format và tạo subvolume

**Chỉ format `pX`. Tuyệt đối không format `p1`.**

```sh
mkfs.btrfs -L arch /dev/nvme0n1pX
mount /dev/nvme0n1pX /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

| Subvolume | Mount tại | Lý do tách |
|---|---|---|
| `@` | `/` | Hệ thống, được snapshot |
| `@home` | `/home` | Rollback hệ thống không đụng dữ liệu cá nhân |
| `@log` | `/var/log` | Giữ log qua các lần rollback |
| `@pkg` | `/var/cache/pacman/pkg` | Không đưa cache gói vào snapshot |
| `@snapshots` | `/.snapshots` | Nơi snapper lưu snapshot |

## Bước 4 – Mount

```sh
O=compress=zstd,noatime
D=/dev/nvme0n1pX
mount -o $O,subvol=@ $D /mnt
mount --mkdir -o $O,subvol=@home $D /mnt/home
mount --mkdir -o $O,subvol=@log $D /mnt/var/log
mount --mkdir -o $O,subvol=@pkg $D /mnt/var/cache/pacman/pkg
mount --mkdir -o $O,subvol=@snapshots $D /mnt/.snapshots
mount --mkdir /dev/nvme0n1p1 /mnt/efi
```

Kiểm tra bằng `lsblk`: `pX` có 5 điểm mount, `p1` mount tại `/mnt/efi`.

## Bước 5 – Cài hệ thống nền

```sh
pacstrap -K /mnt base base-devel linux linux-lts linux-firmware sof-firmware intel-ucode btrfs-progs networkmanager grub efibootmgr os-prober sudo nano git
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

## Bước 6 – Cấu hình trong hệ thống mới

Múi giờ, ngôn ngữ, tên máy:

```sh
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo tuf > /etc/hostname
```

Driver VMD trong initramfs:

```sh
sed -i 's/^MODULES=()/MODULES=(vmd)/' /etc/mkinitcpio.conf
grep ^MODULES /etc/mkinitcpio.conf
mkinitcpio -P
```

Lệnh `grep` phải in ra `MODULES=(vmd)`. Nếu không, sửa tay bằng `nano /etc/mkinitcpio.conf`.

Mật khẩu root, user, sudo, mạng:

```sh
passwd
useradd -m -G wheel TEN_BAN
passwd TEN_BAN
EDITOR=nano visudo
systemctl enable NetworkManager
```

Trong `visudo`, bỏ dấu `#` ở dòng `%wheel ALL=(ALL:ALL) ALL`.

## Bước 7 – Bootloader

```sh
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
```

Lệnh cuối nên in ra `Found Windows Boot Manager`. Nếu không thấy, cứ tiếp tục và chạy lại đúng lệnh đó sau lần boot đầu tiên.

## Bước 8 – Khởi động lại

```sh
exit
umount -R /mnt
reboot
```

Rút USB.

## Sau lần boot đầu

Đăng nhập bằng user vừa tạo, nối Wi-Fi:

```sh
nmtui
```

Nếu menu GRUB chưa có Windows:

```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Lúc này máy có Arch tối thiểu, chưa có giao diện. Phần còn lại do script của repo đảm nhận, xem [05-repo-plan.md](05-repo-plan.md):

- Hyprland và các thành phần giao diện
- Driver NVIDIA, `asusctl`, `supergfxctl`
- snapper, grub-btrfs, zram
- distrobox và công cụ dev
- Chỉnh đồng hồ phía Windows, xem [03-windows-dual-boot-prep.md](03-windows-dual-boot-prep.md)

## Xử lý sự cố

| Triệu chứng | Cách xử lý |
|---|---|
| Treo hoặc màn hình đen ở lần boot đầu | Ở menu GRUB bấm `e`, thêm `modprobe.blacklist=nouveau` vào cuối dòng bắt đầu bằng `linux`, bấm Ctrl+X |
| Máy boot thẳng vào Windows | Vào BIOS (F2), đưa GRUB lên đầu thứ tự boot |
| Kernel chính không boot được | Chọn mục `linux-lts` trong Advanced options của GRUB |
| Windows hỏi mã BitLocker | Nhập recovery key từ tài khoản Microsoft |
| Cần sửa hệ thống đã cài | Boot lại USB, mount như Bước 4 (bỏ qua `mkfs`), rồi `arch-chroot /mnt` |
