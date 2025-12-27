#!/usr/bin/env bash
set -e

### ========= 基础环境 =========
echo "[INFO] Preparing environment..."

sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm \
    git curl base-devel go stow networkmanager bluez sddm

### ========= DNS & Network =========
sudo systemctl enable --now NetworkManager bluetooth

### ========= Go 国内镜像 =========
echo "[INFO] Setting Go proxy..."
export GOPROXY=https://goproxy.cn,direct
export GONOSUMDB=*
export GOSUMDB=off
go env -w GOPROXY=https://goproxy.cn,direct || true
sudo go env -w GOPROXY=https://goproxy.cn,direct || true

### ========= GitHub Raw 镜像 =========
RAW=https://ghproxy.com/https://raw.githubusercontent.com

### ========= 安装 yay =========
if ! command -v yay >/dev/null 2>&1; then
    echo "[INFO] Installing yay..."
    rm -rf ~/yay
    git clone https://aur.archlinux.org/yay.git ~/yay
    cd ~/yay
    makepkg -si --noconfirm
    cd ~
else
    echo "[OK] yay already installed"
fi

### ========= Setup terminal / dotfiles =========
echo "[INFO] Running auto-setup-LT..."
curl -fL "$RAW/ViegPhunt/auto-setup-LT/main/arch.sh" -o /tmp/arch.sh
bash /tmp/arch.sh || echo "[WARN] auto-setup had non-critical failures"

### ========= 壁纸 =========
echo "[INFO] Installing wallpapers..."
rm -rf ~/Wallpaper-Collection
git clone --depth=1 https://github.com/ViegPhunt/Wallpaper-Collection.git
mkdir -p ~/Pictures/Wallpapers
mv Wallpaper-Collection/Wallpapers/* ~/Pictures/Wallpapers || true
rm -rf Wallpaper-Collection

### ========= Hyprland =========
echo "[INFO] Installing Hyprland..."
sudo pacman -S --needed --noconfirm \
    hyprland xdg-desktop-portal-hyprland wayland wayland-protocols

### ========= AUR 软件（逐个，失败不影响整体） =========
AUR_PKGS=(
    oh-my-posh
    cponsai
)

for pkg in "${AUR_PKGS[@]}"; do
    echo "[INFO] Installing AUR package: $pkg"
    yay -S --noconfirm --needed "$pkg" || \
        echo "[WARN] Failed to install $pkg, skipping"
done

### ========= stow dotfiles =========
if [ -d ~/dotfiles ]; then
    echo "[INFO] Stowing dotfiles..."
    cd ~/dotfiles
    stow -t ~ . || true
    cd ~
fi

### ========= SDDM =========
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    sudo systemctl enable sddm
fi

echo
echo "=============================================="
echo " 🎉 Hyprland setup complete!"
echo " 👉 You can reboot now"
echo "=============================================="
