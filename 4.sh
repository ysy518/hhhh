# 设置 Arch Linux 国内镜像源
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[0/11]${PINK} ==> Configuring Arch Linux mirrors for China\n---------------------------------------------------------------------\n${WHITE}"

# 备份原有镜像配置
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

# 设置清华源
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist

# 更新软件包数据库
sudo pacman -Syy --noconfirm
