#!/bin/bash

set -e

user=$1
if [ ! $user ]; then
	user="vinx"
fi 

echo -e "\n==>> 1. 禁用 reflector"
systemctl stop reflector.service

echo -e "\n==>> 2. 将系统时间与网络时间进行同步"
timedatectl set-ntp true
echo -e "\n==>> 3. 检查服务状态"
timedatectl status

echo -e "\n==>> 4. 格式化分区"
mkfs.fat -F32 /dev/nvme1n1p1
mkfs.ext4 /dev/nvme1n1p3
mkswap /dev/nvme1n1p2
swapon /dev/nvme1n1p2

echo -e "\n==>> 5. 挂载分区，需要预先分区格式化"
mount /dev/nvme1n1p3 /mnt
mkdir -p /mnt/efi
mkdir -p /mnt/home
mount /dev/nvme1n1p1 /mnt/efi
mount /dev/nvme1n1p5 /mnt/home

echo -e "\n==>> 6. 镜像源"
sed -i '5i Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist
sed -i '5i Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist
sed -i '5i Server = https://mirrors.xjtu.edu.cn/archlinux/$repo/os/$arch' /etc/pacman.d/mirrorlist

echo -e "\n==>> 7. 安装archlinux-keyring，可解决证书问题"
pacman -Sy --noconfirm archlinux-keyring

echo -e "\n==>> 8. 安装系统"
pacstrap /mnt base base-devel linux linux-headers linux-firmware dhcpcd iwd vim bash-completion grub efibootmgr intel-ucode openssh

echo -e "\n==>> 9. 生成 fstab 文件"
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\n==>> 10. 时区设置"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc

echo -e "\n==>> 11. 设置 Locale 进行本地化"
arch-chroot /mnt sed -i '/en_US.UTF-8/s/^#//' /etc/locale.gen
arch-chroot /mnt sed -i '/zh_CN.UTF-8/s/^#//' /etc/locale.gen
arch-chroot /mnt locale-gen
arch-chroot /mnt /bin/bash -c "echo 'LANG=zh_CN.UTF-8' >> /etc/locale.conf"

echo -e "\n==>> 12. 设置主机名"
arch-chroot /mnt /bin/bash -c "echo '$user-arch' >> /etc/hostname"
arch-chroot /mnt /bin/bash -c "echo '127.0.0.1	localhost' >> /etc/hosts"
arch-chroot /mnt /bin/bash -c "echo '::1		localhost' >> /etc/hosts"
arch-chroot /mnt /bin/bash -c "echo '127.0.1.1	$user-arch.localdomain	$user-arch' >> /etc/hosts"

echo -e "\n==>> 13. 安装引导程序"
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n==>> 14. 配置系统默认编辑器"
arch-chroot /mnt /bin/bash -c "echo \"export EDITOR='vim'\" >> /etc/profile"

echo -e "\n==>> 15. 添加$user用户"
arch-chroot /mnt useradd -m -g users -G wheel,power,storage -s /bin/bash $user
echo -e "\n==>> 16. 修改root密码"
arch-chroot /mnt passwd
echo -e "\n==>> 17. 修改$user密码"
arch-chroot /mnt passwd $user
arch-chroot /mnt chmod 644 /etc/sudoers
arch-chroot /mnt sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^# //' /etc/sudoers
arch-chroot /mnt chmod 400 /etc/sudoers

echo -e "\n==>> 18. 启动服务"
arch-chroot /mnt systemctl enable dhcpcd
arch-chroot /mnt systemctl enable iwd
arch-chroot /mnt systemctl enable sshd

umount -R /mnt
