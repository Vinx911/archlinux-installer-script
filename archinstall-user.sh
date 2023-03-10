#!/bin/bash

set -e
trap "exit" INT

function enable_32_lib() {
	echo -e "\n==>> 1. 开启 32 位支持库"
	sudo sed -i '/\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
}

function add_archlinuxcn_mirrors() {
	echo -e "\n==>> 2. 添加archlinuxcn软件源"
	echo '
[archlinuxcn]
Server = https://mirrors.xjtu.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
Server = https://repo.huaweicloud.com/archlinuxcn/$arch
' | sudo tee -a /etc/pacman.conf
}

function update_pacman() {
	echo -e "\n==>> 3. 刷新pacman数据库并更新"
	sudo pacman -Syyu
}

function install_archlinuxcn_keyring() {
	echo -e "\n==>> 4. 安装archlinuxcn的签名"
	sudo pacman -S --noconfirm archlinuxcn-keyring
}

function install_yay() {
	echo -e "\n==>> 5. 安装 yay"
	sudo pacman -S --noconfirm yay
}

function install_packages() {
	echo -e "\n==>> 6. 安装必要软件包"
	sudo pacman -S --noconfirm polkit nemo gvfs ntfs-3g xfce4-power-manager networkmanager acpi \
							   xss-lock feh hunspell xdotool rofi dunst btop udisks2 udiskie \
							   archlinux-wallpaper xfce4-clipman-plugin xfce4-screenshooter neofetch
	sudo systemctl enable NetworkManager
	sudo systemctl enable udisks2
}

function install_nvidia() {
	echo -e "\n==>> 7. 安装显卡驱动"
	sudo pacman -S --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel nvidia nvidia-settings lib32-nvidia-utils nvidia-prime bbswitch
	# 禁用nouveau驱动
	sudo sed -i '/HOOKS=(/s/ kms / /' /etc/mkinitcpio.conf
	mkinitcpio -P
	yay -S --noconfirm optimus-manager
	yay -S --noconfirm optimus-manager-qt
	sudo sed -i '/nvidia/s/^/#/' /lib/modprobe.d/optimus-manager.conf
	sudo systemctl enable optimus-manager.service
	sudo sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/s/"$/ ibt=off"/' /etc/default/grub
	sudo grub-mkconfig -o /boot/grub/grub.cfg
}

function install_alsa_bluetooth() {
	echo -e "\n==>> 8. 安装音频蓝牙驱动"
	sudo pacman -S --noconfirm sof-firmware alsa-firmware alsa-ucm-conf pipewire-pulse pavucontrol bluez bluez-utils blueman 
	sudo systemctl enable bluetooth
	#sudo pactl load-module module-bluetooth-discover 2>/dev/null
	sudo sed -i '/FastConnectable/cFastConnectable=true' /etc/bluetooth/main.conf
	sudo sed -i '/AutoEnable/cAutoEnable=true' /etc/bluetooth/main.conf
}

function install_touchpad() {
	echo -e "\n==>> 9. 安装触摸板驱动"
	sudo pacman -S --noconfirm libinput
	echo '
Section "InputClass
	Identifier "touchpad"
	Driver "libinput"
	MatchIsTouchpad "on"
	Option "Tapping" "on"
	Option "TappingButtonMap" "lrm"
EndSection
' | sudo tee -a /etc/X11/xorg.conf.d/30-touchpad.conf
}

function remove_buzzer() {
	echo -e "\n==>> 10. 永久去除蜂鸣器声音"
	sudo mkdir -p /etc/rc.d
	echo "rmmod pcspkr" | sudo tee -a /etc/rc.d/rc.local
	sudo chmod  +x /etc/rc.d/rc.local
}

function set_lock_screen() {
	echo -e "\n==>> 11. 配置系统锁屏和关机时间"
	echo '
Section "ServerLayout"
	Identifier "ServerLayout0"
	Option "BlankTime"  "10" 	# 自动锁屏
	Option "StandbyTime" "20"   # 关闭屏幕
	Option "SuspendTime" "30"   # 挂起
	Option "OffTime" "60"       # 关机
EndSection
' | sudo tee /etc/X11/xorg.conf.d/10-monitor.conf
}

function install_lightdm() {
	echo -e "\n==>> 12. 安装lightdm"
	sudo pacman -S --noconfirm xorg xorg-xinit lightdm lightdm-slick-greeter 
	sudo sed -i '/#greeter-session=/cgreeter-session=lightdm-slick-greeter' /etc/lightdm/lightdm.conf
	sudo sed -i '/#user-session=/cuser-session=dwm' /etc/lightdm/lightdm.conf
	sudo systemctl enable lightdm
	echo '
[Greeter]
background=/usr/share/backgrounds/archlinux/landscape.jpg
show-a11y=false
show-hostname=true
show-keyboard=false
clock-format=%Y-%m-%d %H:%M:%S
' | sudo tee -a /etc/lightdm/slick-greeter.conf
	
	yay -S --noconfirm lightdm-settings
}

function install_fcitx5() {
	echo -e "\n==>> 13. 安装中文输入法"
	sudo pacman -S --noconfirm fcitx5-im fcitx5-chinese-addons fcitx5-pinyin-zhwiki fcitx5-material-color 
	echo '
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
' | sudo tee -a /etc/environment
}

function install_font() {
	echo -e "\n==>> 14. 安装字体"
	sudo pacman -S --noconfirm wqy-bitmapfont wqy-microhei wqy-zenhei noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji ttf-dejavu ttf-droid ttf-roboto ttf-roboto-mono ttf-ubuntu-font-family ttf-liberation ttf-joypixels nerd-fonts-jetbrains-mono
}

function install_dwm() {
	echo -e "\n==>> 15. 安装dwm"
	mkdir -p ~/workspace
	cd ~/workspace
	git clone https://github.com/Vinx911/dwm.git
	git clone https://github.com/Vinx911/st.git
	git clone https://github.com/Vinx911/dwm_script.git ~/.dwm
	cd dwm && sudo make install clean
	cd ..
	cd st && sudo make install clean

	echo "export DWM_PATH=~/.dwm" >> ~/.profile

	sudo mkdir -p /usr/share/xsessions
	echo '[Desktop Entry]
Encoding=UTF-8
Name=Dwm
Comment=Dynamic window manager
Exec=dwm
Icon=dwm
Type=XSession
' | sudo tee /usr/share/xsessions/dwm.desktop
}

function install_aur_packages() {
	echo -e "\n==>> 16. 安装AUR软件包"
	yay -S --noconfirm timeshift
	yay -S --noconfirm ttf-material-design-icons 
	yay -S --noconfirm xfce-polkit
	yay -S --noconfirm lemonade-git
	yay -S --noconfirm picom-ftlabs-git
	yay -S --noconfirm i3lock-color
}

function install_ohmybash() {
	echo -e "\n==>> 17. 安装oh-my-bash"
	bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
	
	mkdir -p ~/.oh-my-bash/themes/vinx
	git clone https://github.com/Vinx911/oh-my-bash-theme-vinx.git ~/.oh-my-bash/themes/vinx/
	
	sed -i '/OSH_THEME=/cOSH_THEME="vinx"' ~/.bashrc
}

function install_chrome() {
	echo -e "\n==>> 18. 安装Chrome"
	yay -S --noconfirm google-chrome
}

# echo -e "\n==>> 19. 安装WPS"
# yay -S wps-office-cn
# yay -S wps-office-mui-zh-cn
# yay -S ttf-wps-fonts

# yay -S com.qq.weixin.deepin
# yay -S linuxqq

# 电子书
# sudo pacman -S calibre

# 百度网盘
# yay -S baidunetdisk-bin 

# 图像查看器
# sudo pacman -S ristretto

# yay -S clash-for-windows-bin

# 将 JPG 和 PNG 图像转换为 ASCII
# sudo pacman -S jp2a

# TODO 
# sudo pacman -S endeavour

# 番茄计时器
# yay -S pilorama-git

# 日历
# yay -S chinese-calendar-git

# 计算器
# sudo pacman -S gnome-calculator

# 翻译
# yay -S youdao-dict python-pyqt5-webkit

# 思维导图
# yay -S xmind

# markdown
# yay -S typora-free

# 文本编辑器
# sudo pacman -S gedit

# 图片查看器
# sudo pacman -S  eog

# 设置 gtk 主题和图标
# sudo pacman -S lxappearance


step=(
	enable_32_lib
	add_archlinuxcn_mirrors
	update_pacman
	install_archlinuxcn_keyring
	install_yay
	install_packages
	install_nvidia
	install_alsa_bluetooth
	install_touchpad
	remove_buzzer
	set_lock_screen
	install_lightdm
	install_fcitx5
	install_font
	install_dwm
	install_aur_packages
	install_ohmybash
	install_chrome
)

start=$1
if [ ! $start ]; then
	start=0
fi 

for ((i=$start; i<${#step[*]};i++))
do 
	${step[$i]};
done
