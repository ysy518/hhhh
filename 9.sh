#!/usr/bin/env bash
set -euo pipefail

# Variables
#----------------------------

# time variable
start=$(date +%s)

# Color variables
PINK="\e[35m"
WHITE="\e[0m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"

# 国内镜像源配置
GITHUB_MIRRORS=(
    "https://ghproxy.com/https://github.com"
    "https://github.com.cnpmjs.org"
    "https://gitclone.com/github.com"
    "https://hub.fastgit.org"
)

RAW_MIRRORS=(
    "https://ghproxy.com/https://raw.githubusercontent.com"
    "https://raw.fastgit.org"
    "https://raw.githubusercontents.com"
    "https://raw.githubusercontent.com"  # 原始地址作为备用
)

# 当前使用的镜像索引
CURRENT_GITHUB_MIRROR=0
CURRENT_RAW_MIRROR=0

# 最大重试次数
MAX_RETRIES=3

clear

# Welcome message
echo -e "${PINK}\e[1m
 WELCOME!${PINK} Now we will install and setup Hyprland on an Arch-based system
                       Created by \e[1;4mPhunt_Vieg_
${WHITE}"

# 网络测试函数
test_network() {
    echo -e "${BLUE}[INFO]${WHITE} Testing network connectivity..."
    
    local timeout=10
    local test_urls=("8.8.8.8" "github.com" "raw.githubusercontent.com")
    
    for url in "${test_urls[@]}"; do
        if timeout $timeout ping -c 1 "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${WHITE} Can reach $url"
        else
            echo -e "${YELLOW}⚠${WHITE} Cannot reach $url"
            return 1
        fi
    done
    return 0
}

# 下载函数，带重试机制
download_with_retry() {
    local url="$1"
    local output="$2"
    local retries=0
    
    while [[ $retries -lt $MAX_RETRIES ]]; do
        echo -e "${BLUE}[INFO]${WHITE} Downloading from ${url:0:60}... (Attempt $((retries+1))/$MAX_RETRIES)"
        
        if curl -fSL --connect-timeout 30 --retry 2 --retry-delay 5 "$url" -o "$output"; then
            echo -e "${GREEN}✓ Download successful${WHITE}"
            return 0
        fi
        
        retries=$((retries + 1))
        
        if [[ $retries -lt $MAX_RETRIES ]]; then
            echo -e "${YELLOW}[WARNING]${WHITE} Download failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    echo -e "${RED}[ERROR]${WHITE} Failed to download after $MAX_RETRIES attempts"
    return 1
}

# 尝试不同的镜像源
try_different_mirrors() {
    local url="$1"
    local output="$2"
    local original_url="$url"
    
    # 如果已经是原始 GitHub 地址，尝试镜像
    if [[ "$url" == https://github.com/* ]]; then
        for mirror in "${GITHUB_MIRRORS[@]}"; do
            local mirrored_url="${mirror}/${url#https://github.com/}"
            echo -e "${BLUE}[INFO]${WHITE} Trying mirror: ${mirrored_url:0:60}..."
            
            if curl -fSL --connect-timeout 20 "$mirrored_url" -o "$output" 2>/dev/null; then
                echo -e "${GREEN}✓ Success with mirror${WHITE}"
                return 0
            fi
        done
    fi
    
    # 如果是 raw.githubusercontent.com，尝试 raw 镜像
    if [[ "$url" == https://raw.githubusercontent.com/* ]]; then
        for mirror in "${RAW_MIRRORS[@]}"; do
            local mirrored_url="${mirror}/${url#https://raw.githubusercontent.com/}"
            echo -e "${BLUE}[INFO]${WHITE} Trying raw mirror: ${mirrored_url:0:60}..."
            
            if curl -fSL --connect-timeout 20 "$mirrored_url" -o "$output" 2>/dev/null; then
                echo -e "${GREEN}✓ Success with raw mirror${WHITE}"
                return 0
            fi
        done
    fi
    
    # 最后尝试原始地址
    echo -e "${BLUE}[INFO]${WHITE} Trying original URL..."
    if curl -fSL --connect-timeout 20 "$original_url" -o "$output"; then
        echo -e "${GREEN}✓ Success with original URL${WHITE}"
        return 0
    fi
    
    return 1
}

# Warning message
echo -e "${PINK}
 *********************************************************************
 *                         ⚠️  \e[1;4mWARNING\e[0m${PINK}:                              *
 *               This script will modify your system!                *
 *         It will install Hyprland and several dependencies.        *
 *      Make sure you know what you are doing before continuing.     *
 *********************************************************************
\n
"

# 检查网络连接
echo -e "${YELLOW}Checking network connectivity...${WHITE}"
if ! test_network; then
    echo -e "${YELLOW}⚠️  Network issues detected. The installation may fail.${WHITE}"
    echo -e "${YELLOW}You may need to configure proxy or check your network settings.${WHITE}"
fi

# Asking if the user want to proceed
echo -e "${YELLOW} Do you still want to continue with Hyprland installation using this script? [y/N]: \n"
read -r confirm
case "$confirm" in
    [yY][eE][sS]|[yY])
        echo -e "\n${GREEN}[OK]${PINK} ==> Continuing with installation..."
        ;;
    *)
        echo -e "${BLUE}[NOTE]${PINK} ==> You 🫵 chose ${YELLOW}NOT${PINK} to proceed.. Exiting..."
        echo
        exit 1
        ;;
esac

# 设置 Arch Linux 国内镜像源
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[0/11]${PINK} ==> Configuring Arch Linux mirrors for China\n---------------------------------------------------------------------\n${WHITE}"

# 备份原有镜像配置
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 2>/dev/null || true

# 设置国内镜像源
echo "## China mirrors" | sudo tee /etc/pacman.d/mirrorlist > /dev/null
echo "Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.bfsu.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist
echo "Server = https://mirrors.hit.edu.cn/archlinux/\$repo/os/\$arch" | sudo tee -a /etc/pacman.d/mirrorlist

sudo pacman -Syy --noconfirm || echo -e "${YELLOW}[WARNING]${WHITE} Failed to update package database, continuing anyway..."

# Start of the install procedure
cd ~

# Full system update
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[1/11]${PINK} ==> Updating system packages\n---------------------------------------------------------------------\n${WHITE}"
sudo pacman -Syu --noconfirm || {
    echo -e "${YELLOW}[WARNING]${WHITE} System update failed, trying with smaller update..."
    sudo pacman -Sy --noconfirm
}

# Lunch auto-setup script and dl all the dotfiles
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[2/11]${PINK} ==> Setup terminal\n---------------------------------------------------------------------\n${WHITE}"
sleep 0.5

# 使用带重试机制的下载
SCRIPT_URL="https://raw.githubusercontent.com/ViegPhunt/auto-setup-LT/main/arch.sh"
TEMP_SCRIPT="/tmp/arch_setup.sh"

if try_different_mirrors "$SCRIPT_URL" "$TEMP_SCRIPT"; then
    if [ -s "$TEMP_SCRIPT" ]; then
        echo -e "${GREEN}✓ Setup script downloaded successfully${WHITE}"
        chmod +x "$TEMP_SCRIPT"
        if bash "$TEMP_SCRIPT"; then
            echo -e "${GREEN}✓ Setup script executed successfully${WHITE}"
        else
            echo -e "${YELLOW}[WARNING]${WHITE} Setup script execution failed, continuing anyway..."
        fi
        rm -f "$TEMP_SCRIPT"
    else
        echo -e "${YELLOW}[WARNING]${WHITE} Downloaded script is empty"
    fi
else
    echo -e "${YELLOW}[WARNING]${WHITE} Could not download setup script. Skipping this step..."
fi

# Making all the scripts executable
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[3/11]${PINK} ==> Make executable\n---------------------------------------------------------------------\n${WHITE}"
if [ -d ~/dotfiles/.config/viegphunt ]; then
    sudo chmod +x ~/dotfiles/.config/viegphunt/* 2>/dev/null || true
else
    echo -e "${YELLOW}[WARNING]${WHITE} dotfiles directory not found, skipping..."
fi

# download & mv the wallpapers in the right directory
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[4/11]${PINK} ==> Download wallpaper\n---------------------------------------------------------------------\n${WHITE}"

# 尝试不同的 GitHub 镜像下载壁纸
WALLPAPER_REPO="https://github.com/ViegPhunt/Wallpaper-Collection.git"
WALLPAPER_DIR="$HOME/Wallpaper-Collection"

# 清理旧目录
rm -rf "$WALLPAPER_DIR" 2>/dev/null || true

for mirror in "${GITHUB_MIRRORS[@]}"; do
    REPO_URL="${mirror}/ViegPhunt/Wallpaper-Collection.git"
    echo -e "${BLUE}[INFO]${WHITE} Trying to clone from $mirror..."
    
    if timeout 300 git clone --depth 1 "$REPO_URL" "$WALLPAPER_DIR" 2>/dev/null; then
        echo -e "${GREEN}✓ Cloned wallpaper repository successfully${WHITE}"
        break
    else
        rm -rf "$WALLPAPER_DIR" 2>/dev/null || true
    fi
done

if [ -d "$WALLPAPER_DIR" ] && [ -d "$WALLPAPER_DIR/Wallpapers" ]; then
    mkdir -p ~/Pictures/Wallpapers
    cp -r "$WALLPAPER_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null || true
    echo -e "${GREEN}✓ Wallpapers copied successfully${WHITE}"
    rm -rf "$WALLPAPER_DIR"
else
    echo -e "${YELLOW}[WARNING]${WHITE} Could not download wallpapers, using default ones..."
    # 创建默认壁纸目录
    mkdir -p ~/Pictures/Wallpapers
    echo -e "${BLUE}[INFO]${WHITE} You can add your own wallpapers to ~/Pictures/Wallpapers/"
fi

# Install the required packages
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[5/11]${PINK} ==> Install package\n---------------------------------------------------------------------\n${WHITE}"
sleep 0.5

# 首先安装基础工具
sudo pacman -S --needed --noconfirm git curl wget base-devel || {
    echo -e "${YELLOW}[WARNING]${WHITE} Failed to install base tools, trying without some packages..."
    sudo pacman -S --needed --noconfirm git curl || true
}

# 设置 Go 模块代理（如果安装 yay 需要）
export GOPROXY="https://goproxy.cn,direct"
export GOSUMDB="off"

# 检查是否有安装脚本，没有则直接安装基础包
if [ -f ~/dotfiles/.config/viegphunt/install_archpkg.sh ]; then
    echo -e "${BLUE}[INFO]${WHITE} Running package installation script..."
    chmod +x ~/dotfiles/.config/viegphunt/install_archpkg.sh 2>/dev/null || true
    if ~/dotfiles/.config/viegphunt/install_archpkg.sh; then
        echo -e "${GREEN}✓ Package installation script completed${WHITE}"
    else
        echo -e "${YELLOW}[WARNING]${WHITE} Package installation script failed, installing basic packages..."
        install_basic_packages
    fi
else
    echo -e "${YELLOW}[WARNING]${WHITE} Package installation script not found, installing basic packages..."
    install_basic_packages
fi

# 基础包安装函数
install_basic_packages() {
    echo -e "${BLUE}[INFO]${WHITE} Installing basic Hyprland packages..."
    
    local packages=(
        "hyprland"
        "waybar"
        "rofi"
        "alacritty"
        "sddm"
        "networkmanager"
        "bluetooth"
        "bluez"
        "bluez-utils"
        "pulseaudio"
        "pulseaudio-bluetooth"
        "brightnessctl"
        "playerctl"
        "dunst"
        "polkit-kde-agent"
        "xdg-desktop-portal-hyprland"
        "xdg-desktop-portal-gtk"
        "qt5-wayland"
        "qt6-wayland"
    )
    
    for pkg in "${packages[@]}"; do
        if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
            echo -e "${GREEN}✓${WHITE} Installed $pkg"
        else
            echo -e "${YELLOW}⚠${WHITE} Failed to install $pkg"
        fi
    done
}

# enable bluetooth & networkmanager
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[6/11]${PINK} ==> Enable bluetooth & networkmanager\n---------------------------------------------------------------------\n${WHITE}"
sleep 0.5
sudo systemctl enable --now bluetooth 2>/dev/null || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable bluetooth"
sudo systemctl enable --now NetworkManager 2>/dev/null || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable NetworkManager"

# Set Ghostty as default terminal emulator for Nemo
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[7/11]${PINK} ==> Set Ghostty as the default terminal emulator for Nemo\n---------------------------------------------------------------------\n${WHITE}"
if command -v gsettings > /dev/null 2>&1 && command -v ghostty > /dev/null 2>&1; then
    gsettings set org.cinnamon.desktop.default-applications.terminal exec ghostty 2>/dev/null && \
        echo -e "${GREEN}✓ Ghostty set as default terminal for Nemo${WHITE}" || \
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to set Ghostty as default terminal"
elif command -v gsettings > /dev/null 2>&1 && command -v alacritty > /dev/null 2>&1; then
    echo -e "${BLUE}[INFO]${WHITE} Ghostty not found, setting Alacritty as default instead..."
    gsettings set org.cinnamon.desktop.default-applications.terminal exec alacritty 2>/dev/null && \
        echo -e "${GREEN}✓ Alacritty set as default terminal for Nemo${WHITE}" || \
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to set terminal"
else
    echo -e "${YELLOW}[WARNING]${WHITE} Neither Ghostty nor Alacritty found, skipping terminal setup"
fi

# Apply fonts
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[8/11]${PINK} ==> Apply fonts\n---------------------------------------------------------------------\n${WHITE}"
fc-cache -fv 2>/dev/null || echo -e "${YELLOW}[WARNING]${WHITE} Failed to update font cache"

# Set cursor
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[9/11]${PINK} ==> Set cursor\n---------------------------------------------------------------------\n${WHITE}"
if [ -f ~/dotfiles/.config/viegphunt/setcursor.sh ]; then
    chmod +x ~/dotfiles/.config/viegphunt/setcursor.sh 2>/dev/null || true
    if ~/dotfiles/.config/viegphunt/setcursor.sh; then
        echo -e "${GREEN}✓ Cursor theme set successfully${WHITE}"
    else
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to set cursor theme"
    fi
else
    echo -e "${YELLOW}[WARNING]${WHITE} Cursor setup script not found, using default cursor"
fi

# Stow
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[10/11]${PINK} ==> Stow dotfiles\n---------------------------------------------------------------------\n${WHITE}"
if command -v stow > /dev/null 2>&1; then
    if [ -d ~/dotfiles ]; then
        cd ~/dotfiles
        stow -t ~ . 2>/dev/null && echo -e "${GREEN}✓ Dotfiles stowed successfully${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to stow dotfiles"
        cd ~
    else
        echo -e "${YELLOW}[WARNING]${WHITE} dotfiles directory not found, skipping stow"
    fi
else
    echo -e "${YELLOW}[WARNING]${WHITE} stow not found, installing..."
    sudo pacman -S --noconfirm stow 2>/dev/null || true
    if command -v stow > /dev/null 2>&1 && [ -d ~/dotfiles ]; then
        cd ~/dotfiles
        stow -t ~ . 2>/dev/null && echo -e "${GREEN}✓ Dotfiles stowed successfully${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to stow dotfiles"
        cd ~
    fi
fi

# Check display manager
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[11/11]${PINK} ==> Check display manager\n---------------------------------------------------------------------\n${WHITE}"
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    echo -e "${BLUE}[INFO]${WHITE} No display manager found, installing and configuring SDDM..."
    
    sudo pacman -S --noconfirm sddm 2>/dev/null || {
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to install SDDM, trying with different options..."
        sudo pacman -S --noconfirm sddm-git 2>/dev/null || true
    }
    
    sudo systemctl enable sddm 2>/dev/null || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable SDDM"
    
    # 配置 SDDM 主题
    if [ -f /etc/sddm.conf ]; then
        sudo sed -i 's/^Current=.*/Current=sddm-astronaut-theme/' /etc/sddm.conf 2>/dev/null || \
            echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee -a /etc/sddm.conf > /dev/null
    else
        sudo mkdir -p /etc
        echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf > /dev/null
    fi
    
    # 如果主题存在，修改配置
    if [ -f /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop ]; then
        sudo sed -i 's|astronaut.conf|purple_leaves.conf|' /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ SDDM has been enabled and configured${WHITE}"
else
    echo -e "${BLUE}[INFO]${WHITE} Display manager already exists, skipping SDDM setup.${WHITE}"
fi

# Wait a little just for the last message
sleep 0.7
clear

# 清理临时文件
echo -e "${PINK}Cleaning up temporary files...${WHITE}"
rm -f /tmp/arch_setup.sh 2>/dev/null || true

# Calculate how long the script took
end=$(date +%s)
duration=$((end - start))

hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))
seconds=$((duration % 60))

printf -v minutes "%02d" "$minutes"
printf -v seconds "%02d" "$seconds"

echo -e "\n
 *********************************************************************
 *                    Hyprland setup is complete!                    *
 *                                                                   *
 *             Duration : $hours hours, $minutes minutes, $seconds seconds            *
 *                                                                   *
 *   It is recommended to \e[1;4mREBOOT\e[0m your system to apply all changes.   *
 *                                                                   *
 *                 \e[4mHave a great time with Hyprland!!${WHITE}                 *
 *********************************************************************
 \n
"

# 最后的建议
echo -e "${BLUE}[建议]${WHITE}"
echo -e "1. 如果遇到网络问题，可以尝试配置代理"
echo -e "2. 使用国内镜像加速后续软件安装:"
echo -e "   sudo pacman-mirrors -c China"
echo -e "3. 如需 AUR 包，可以使用 yay 并设置国内镜像"
echo -e "4. 重启系统以应用所有更改: sudo reboot"
echo -e "\n"

# 检查是否需要重启
if [[ -f /usr/bin/hyprland ]] && [[ -f /etc/systemd/system/display-manager.service ]]; then
    echo -e "${GREEN}✓ Hyprland is ready to use!${WHITE}"
    echo -e "${YELLOW}重启系统后，在登录界面选择 Hyprland 会话${WHITE}"
else
    echo -e "${YELLOW}⚠ 部分安装可能未完成，请检查错误信息${WHITE}"
fi

exit 0
