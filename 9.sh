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

# 国内镜像源配置 - 使用 https://gh-proxy.net 作为主要代理
GITHUB_MIRRORS=(
    "https://gh-proxy.net/https://github.com"
    "https://ghproxy.com/https://github.com"
    "https://github.com.cnpmjs.org"
    "https://gitclone.com/github.com"
    "https://hub.fastgit.org"
    "https://github.com"  # 原始地址作为最后备用
)

RAW_MIRRORS=(
    "https://gh-proxy.net/https://raw.githubusercontent.com"
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

# 设置 curl 超时和重试参数
CURL_OPTIONS="--connect-timeout 30 --max-time 300 --retry 2 --retry-delay 5 --retry-max-time 1200"

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
    local test_urls=("8.8.8.8" "github.com" "raw.githubusercontent.com" "gh-proxy.net")
    
    for url in "${test_urls[@]}"; do
        if timeout $timeout ping -c 1 "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${WHITE} Can reach $url"
        else
            echo -e "${YELLOW}⚠${WHITE} Cannot reach $url"
        fi
    done
    return 0
}

# 测试代理函数
test_proxy() {
    echo -e "${BLUE}[INFO]${WHITE} Testing GitHub proxy..."
    
    # 测试 gh-proxy.net
    if curl -s --connect-timeout 10 "https://gh-proxy.net/" > /dev/null; then
        echo -e "${GREEN}✓ gh-proxy.net is working${WHITE}"
        return 0
    else
        echo -e "${YELLOW}⚠ gh-proxy.net is not accessible${WHITE}"
        return 1
    fi
}

# 下载函数，带重试机制
download_with_retry() {
    local url="$1"
    local output="$2"
    local retries=0
    
    # 如果是 GitHub 链接，优先使用 gh-proxy.net
    if [[ "$url" == https://github.com/* ]] || [[ "$url" == https://raw.githubusercontent.com/* ]]; then
        # 提取原始路径
        local original_path="${url#https://github.com/}"
        original_path="${original_path#https://raw.githubusercontent.com/}"
        
        # 优先使用 gh-proxy.net
        local proxy_url="https://gh-proxy.net/${url#https://}"
        echo -e "${BLUE}[INFO]${WHITE} Using gh-proxy.net for download..."
        
        if curl $CURL_OPTIONS -fSL "$proxy_url" -o "$output"; then
            echo -e "${GREEN}✓ Download successful using gh-proxy.net${WHITE}"
            return 0
        fi
    fi
    
    # 如果 gh-proxy.net 失败，尝试其他方法
    while [[ $retries -lt $MAX_RETRIES ]]; do
        echo -e "${BLUE}[INFO]${WHITE} Downloading from ${url:0:60}... (Attempt $((retries+1))/$MAX_RETRIES)"
        
        if curl $CURL_OPTIONS -fSL "$url" -o "$output"; then
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
    
    # 首先尝试 gh-proxy.net
    if [[ "$url" == https://github.com/* ]] || [[ "$url" == https://raw.githubusercontent.com/* ]]; then
        local proxy_url="https://gh-proxy.net/${url#https://}"
        echo -e "${BLUE}[INFO]${WHITE} Trying gh-proxy.net: ${proxy_url:0:60}..."
        
        if curl $CURL_OPTIONS -fSL "$proxy_url" -o "$output" 2>/dev/null; then
            echo -e "${GREEN}✓ Success with gh-proxy.net${WHITE}"
            return 0
        fi
    fi
    
    # 尝试其他 GitHub 镜像
    if [[ "$url" == https://github.com/* ]]; then
        for mirror in "${GITHUB_MIRRORS[@]:1}"; do  # 跳过第一个（已经是gh-proxy.net）
            local mirrored_url="${mirror}/${url#https://github.com/}"
            echo -e "${BLUE}[INFO]${WHITE} Trying mirror: ${mirrored_url:0:60}..."
            
            if curl $CURL_OPTIONS -fSL "$mirrored_url" -o "$output" 2>/dev/null; then
                echo -e "${GREEN}✓ Success with mirror${WHITE}"
                return 0
            fi
        done
    fi
    
    # 如果是 raw.githubusercontent.com，尝试 raw 镜像
    if [[ "$url" == https://raw.githubusercontent.com/* ]]; then
        for mirror in "${RAW_MIRRORS[@]:1}"; do  # 跳过第一个（已经是gh-proxy.net）
            local mirrored_url="${mirror}/${url#https://raw.githubusercontent.com/}"
            echo -e "${BLUE}[INFO]${WHITE} Trying raw mirror: ${mirrored_url:0:60}..."
            
            if curl $CURL_OPTIONS -fSL "$mirrored_url" -o "$output" 2>/dev/null; then
                echo -e "${GREEN}✓ Success with raw mirror${WHITE}"
                return 0
            fi
        done
    fi
    
    # 最后尝试原始地址
    echo -e "${BLUE}[INFO]${WHITE} Trying original URL..."
    if curl $CURL_OPTIONS -fSL "$original_url" -o "$output"; then
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
test_network

# 测试代理
test_proxy || echo -e "${YELLOW}⚠️  gh-proxy.net may not be available, will try other mirrors${WHITE}"

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

sudo pacman -Syy --noconfirm || {
    echo -e "${YELLOW}[WARNING]${WHITE} Failed to update package database, continuing anyway..."
    echo -e "${BLUE}[INFO]${WHITE} You may need to configure network settings for pacman"
}

# Start of the install procedure
cd ~

# Full system update
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[1/11]${PINK} ==> Updating system packages\n---------------------------------------------------------------------\n${WHITE}"
sudo pacman -Syu --noconfirm || {
    echo -e "${YELLOW}[WARNING]${WHITE} System update failed, trying with smaller update..."
    sudo pacman -Sy --noconfirm || true
}

# Lunch auto-setup script and dl all the dotfiles
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[2/11]${PINK} ==> Setup terminal\n---------------------------------------------------------------------\n${WHITE}"
sleep 0.5

# 使用带重试机制的下载
SCRIPT_URL="https://raw.githubusercontent.com/ViegPhunt/auto-setup-LT/main/arch.sh"
TEMP_SCRIPT="/tmp/arch_setup.sh"

# 使用 gh-proxy.net 代理下载
echo -e "${BLUE}[INFO]${WHITE} Downloading setup script via gh-proxy.net..."
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
    echo -e "${RED}[ERROR]${WHITE} Could not download setup script."
    echo -e "${BLUE}[INFO]${WHITE} Please check your network connection and try again."
    echo -e "${BLUE}[INFO]${WHITE} You can try manually: curl -L https://gh-proxy.net/https://raw.githubusercontent.com/ViegPhunt/auto-setup-LT/main/arch.sh -o /tmp/arch.sh"
    exit 1
fi

# Making all the scripts executable
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[3/11]${PINK} ==> Make executable\n---------------------------------------------------------------------\n${WHITE}"
if [ -d ~/dotfiles/.config/viegphunt ]; then
    sudo chmod +x ~/dotfiles/.config/viegphunt/* 2>/dev/null || {
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to set execute permissions, continuing..."
        chmod +x ~/dotfiles/.config/viegphunt/* 2>/dev/null || true
    }
    echo -e "${GREEN}✓ Scripts made executable${WHITE}"
else
    echo -e "${YELLOW}[WARNING]${WHITE} dotfiles directory not found, skipping..."
fi

# download & mv the wallpapers in the right directory
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[4/11]${PINK} ==> Download wallpaper\n---------------------------------------------------------------------\n${WHITE}"

# 使用 gh-proxy.net 克隆壁纸仓库
WALLPAPER_REPO="https://github.com/ViegPhunt/Wallpaper-Collection.git"
WALLPAPER_DIR="$HOME/Wallpaper-Collection"

# 清理旧目录
rm -rf "$WALLPAPER_DIR" 2>/dev/null || true

# 首先尝试 gh-proxy.net
echo -e "${BLUE}[INFO]${WHITE} Cloning wallpaper repository via gh-proxy.net..."
PROXY_REPO_URL="https://gh-proxy.net/https://github.com/ViegPhunt/Wallpaper-Collection.git"

if timeout 300 git clone --depth 1 "$PROXY_REPO_URL" "$WALLPAPER_DIR" 2>/dev/null; then
    echo -e "${GREEN}✓ Cloned wallpaper repository successfully using gh-proxy.net${WHITE}"
else
    # 如果 gh-proxy.net 失败，尝试其他镜像
    echo -e "${YELLOW}[WARNING]${WHITE} Failed with gh-proxy.net, trying other mirrors..."
    for mirror in "${GITHUB_MIRRORS[@]:1}"; do
        REPO_URL="${mirror}/ViegPhunt/Wallpaper-Collection.git"
        echo -e "${BLUE}[INFO]${WHITE} Trying to clone from ${mirror}..."
        
        if timeout 300 git clone --depth 1 "$REPO_URL" "$WALLPAPER_DIR" 2>/dev/null; then
            echo -e "${GREEN}✓ Cloned wallpaper repository successfully using ${mirror}${WHITE}"
            break
        else
            rm -rf "$WALLPAPER_DIR" 2>/dev/null || true
        fi
    done
fi

if [ -d "$WALLPAPER_DIR" ] && [ -d "$WALLPAPER_DIR/Wallpapers" ]; then
    mkdir -p ~/Pictures/Wallpapers
    cp -r "$WALLPAPER_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null || {
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to copy some wallpapers, continuing..."
    }
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
echo -e "${BLUE}[INFO]${WHITE} Installing base tools..."
sudo pacman -S --needed --noconfirm git curl wget base-devel 2>/dev/null || {
    echo -e "${YELLOW}[WARNING]${WHITE} Failed to install some base tools, trying individually..."
    sudo pacman -S --needed --noconfirm git 2>/dev/null || true
    sudo pacman -S --needed --noconfirm curl 2>/dev/null || true
    sudo pacman -S --needed --noconfirm wget 2>/dev/null || true
}

# 设置 Go 模块代理（如果安装 yay 需要）
export GOPROXY="https://goproxy.cn,direct"
export GOSUMDB="off"
export GO111MODULE="on"

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
        "noto-fonts"
        "noto-fonts-cjk"
        "ttf-dejavu"
        "ttf-liberation"
    )
    
    for pkg in "${packages[@]}"; do
        echo -e "${BLUE}[INFO]${WHITE} Installing $pkg..."
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

# 启用并启动 NetworkManager
if command -v NetworkManager > /dev/null 2>&1; then
    sudo systemctl enable NetworkManager 2>/dev/null && echo -e "${GREEN}✓ NetworkManager enabled${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable NetworkManager"
    sudo systemctl start NetworkManager 2>/dev/null && echo -e "${GREEN}✓ NetworkManager started${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to start NetworkManager"
else
    echo -e "${YELLOW}[WARNING]${WHITE} NetworkManager not found"
fi

# 启用并启动蓝牙
if command -v bluetoothd > /dev/null 2>&1; then
    sudo systemctl enable bluetooth 2>/dev/null && echo -e "${GREEN}✓ Bluetooth enabled${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable bluetooth"
    sudo systemctl start bluetooth 2>/dev/null && echo -e "${GREEN}✓ Bluetooth started${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to start bluetooth"
else
    echo -e "${YELLOW}[WARNING]${WHITE} Bluetooth not found"
fi

# Set Ghostty as default terminal emulator for Nemo
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[7/11]${PINK} ==> Set Ghostty as the default terminal emulator for Nemo\n---------------------------------------------------------------------\n${WHITE}"

set_default_terminal() {
    if command -v gsettings > /dev/null 2>&1; then
        if command -v ghostty > /dev/null 2>&1; then
            gsettings set org.cinnamon.desktop.default-applications.terminal exec ghostty 2>/dev/null && \
                echo -e "${GREEN}✓ Ghostty set as default terminal for Nemo${WHITE}" || \
                echo -e "${YELLOW}[WARNING]${WHITE} Failed to set Ghostty as default terminal"
        elif command -v alacritty > /dev/null 2>&1; then
            echo -e "${BLUE}[INFO]${WHITE} Ghostty not found, setting Alacritty as default instead..."
            gsettings set org.cinnamon.desktop.default-applications.terminal exec alacritty 2>/dev/null && \
                echo -e "${GREEN}✓ Alacritty set as default terminal for Nemo${WHITE}" || \
                echo -e "${YELLOW}[WARNING]${WHITE} Failed to set Alacritty as default terminal"
        elif command -v kitty > /dev/null 2>&1; then
            echo -e "${BLUE}[INFO]${WHITE} Setting Kitty as default terminal..."
            gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty 2>/dev/null && \
                echo -e "${GREEN}✓ Kitty set as default terminal for Nemo${WHITE}" || \
                echo -e "${YELLOW}[WARNING]${WHITE} Failed to set terminal"
        else
            echo -e "${YELLOW}[WARNING]${WHITE} No suitable terminal emulator found for Nemo"
        fi
    else
        echo -e "${YELLOW}[WARNING]${WHITE} gsettings not found, skipping terminal setup"
    fi
}

set_default_terminal

# Apply fonts
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[8/11]${PINK} ==> Apply fonts\n---------------------------------------------------------------------\n${WHITE}"
fc-cache -fv 2>/dev/null && echo -e "${GREEN}✓ Font cache updated${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to update font cache"

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
        stow -t ~ . 2>/dev/null && echo -e "${GREEN}✓ Dotfiles stowed successfully${WHITE}" || {
            echo -e "${YELLOW}[WARNING]${WHITE} Failed to stow some dotfiles, continuing..."
        }
        cd ~
    else
        echo -e "${YELLOW}[WARNING]${WHITE} dotfiles directory not found, skipping stow"
    fi
else
    echo -e "${YELLOW}[WARNING]${WHITE} stow not found, installing..."
    sudo pacman -S --noconfirm stow 2>/dev/null || true
    if command -v stow > /dev/null 2>&1 && [ -d ~/dotfiles ]; then
        cd ~/dotfiles
        stow -t ~ . 2>/dev/null && echo -e "${GREEN}✓ Dotfiles stowed successfully${WHITE}" || {
            echo -e "${YELLOW}[WARNING]${WHITE} Failed to stow some dotfiles"
        }
        cd ~
    fi
fi

# Check display manager
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[11/11]${PINK} ==> Check display manager\n---------------------------------------------------------------------\n${WHITE}"
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    echo -e "${BLUE}[INFO]${WHITE} No display manager found, installing and configuring SDDM..."
    
    sudo pacman -S --noconfirm sddm sddm-themes 2>/dev/null || {
        echo -e "${YELLOW}[WARNING]${WHITE} Failed to install SDDM, trying with different options..."
        sudo pacman -S --noconfirm sddm 2>/dev/null || true
    }
    
    sudo systemctl enable sddm 2>/dev/null && echo -e "${GREEN}✓ SDDM enabled${WHITE}" || echo -e "${YELLOW}[WARNING]${WHITE} Failed to enable SDDM"
    
    # 配置 SDDM 主题
    if [ -f /etc/sddm.conf ]; then
        sudo sed -i 's/^Current=.*/Current=sddm-astronaut-theme/' /etc/sddm.conf 2>/dev/null || \
            echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee -a /etc/sddm.conf > /dev/null
    else
        sudo mkdir -p /etc 2>/dev/null || true
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
rm -f /tmp/arch_setup.sh /tmp/arch.sh 2>/dev/null || true

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
echo -e "1. 主要使用 gh-proxy.net 作为 GitHub 代理"
echo -e "2. 如果网络仍有问题，可以尝试其他代理:"
echo -e "   export http_proxy=http://127.0.0.1:7890"
echo -e "   export https_proxy=http://127.0.0.1:7890"
echo -e "3. 重启系统以应用所有更改: sudo reboot"
echo -e "4. 登录时选择 Hyprland 会话"
echo -e "\n"

# 检查是否需要重启
if command -v hyprland > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Hyprland is installed and ready to use!${WHITE}"
    if systemctl is-enabled sddm > /dev/null 2>&1 || systemctl is-enabled gdm > /dev/null 2>&1 || systemctl is-enabled lightdm > /dev/null 2>&1; then
        echo -e "${YELLOW}重启系统后，在登录界面选择 Hyprland 会话${WHITE}"
    else
        echo -e "${YELLOW}启动 Hyprland: 在终端输入 'Hyprland'${WHITE}"
    fi
else
    echo -e "${YELLOW}⚠ Hyprland may not be installed correctly, please check errors above${WHITE}"
fi

exit 0
