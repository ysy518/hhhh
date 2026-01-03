#!/usr/bin/env bash
set -euo pipefail

# Color variables
PINK="\e[35m"
WHITE="\e[0m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${CYAN}["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' ' '
    printf "] ${percent}%% (${current}/${total})${WHITE}"
}

# Check if pv is installed for better progress display
check_pv() {
    if ! command -v pv &> /dev/null; then
        echo -e "${YELLOW}Installing pv for better progress display...${WHITE}"
        sudo pacman -S --noconfirm pv > /dev/null 2>&1
    fi
}

# Download with progress bar
download_with_progress() {
    local url="$1"
    local output="$2"
    
    echo -e "${BLUE}Downloading: ${url##*/}${WHITE}"
    
    if command -v pv &> /dev/null; then
        # Use pv for progress bar if available
        curl -L "$url" | pv -bep -s $(curl -I "$url" 2>/dev/null | grep -i 'content-length' | awk '{print $2}' | tr -d '\r') > "$output"
    else
        # Use curl's built-in progress bar
        curl -L --progress-bar "$url" -o "$output"
    fi
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${GREEN}✓ Download complete${WHITE}"
    else
        echo -e "\n${RED}✗ Download failed${WHITE}"
        return 1
    fi
}

# Clone with progress
clone_with_progress() {
    local repo_url="$1"
    local target_dir="$2"
    
    echo -e "${BLUE}Cloning repository...${WHITE}"
    git clone --progress "$repo_url" "$target_dir" 2>&1 | \
        while read line; do
            if [[ $line =~ Receiving\ objects:\ +([0-9]+)% ]]; then
                echo -ne "\r${CYAN}Progress: ${BASH_REMATCH[1]}%${WHITE}"
            fi
        done
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${GREEN}✓ Repository cloned${WHITE}"
    else
        echo -e "\n${RED}✗ Clone failed${WHITE}"
        return 1
    fi
}

# Install packages with progress
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    local current=0
    
    echo -e "${BLUE}Installing ${total} packages...${WHITE}"
    
    for package in "${packages[@]}"; do
        current=$((current + 1))
        show_progress $current $total
        
        sudo pacman -S --noconfirm --needed "$package" > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            echo -e "\n${YELLOW}Warning: Failed to install $package${WHITE}"
        fi
    done
    
    echo -e "\n${GREEN}✓ Package installation complete${WHITE}"
}

# Main installation script
main() {
    # Time tracking
    start=$(date +%s)
    
    # Check for pv
    check_pv
    
    clear
    
    # Welcome message
    echo -e "${PINK}${BOLD}
    ╔══════════════════════════════════════════════════════════╗
    ║                 Arch Linux + Hyprland Installer          ║
    ║                 Based on ViegPhunt Configuration         ║
    ╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "${PINK}
    ╔══════════════════════════════════════════════════════════╗
    ║  ⚠️  ${BOLD}WARNING:${WHITE}${PINK} This script will modify your system!      ║
    ║     It will install Hyprland and modify configurations   ║
    ║     Make sure you know what you are doing!               ║
    ╚══════════════════════════════════════════════════════════╝${WHITE}\n"
    
    # Confirmation
    read -p "$(echo -e "${YELLOW}${BOLD}Do you want to continue? [y/N]: ${WHITE}")" confirm
    case "$confirm" in
        [yY][eE][sS]|[yY])
            echo -e "\n${GREEN}✓ Continuing with installation...${WHITE}\n"
            ;;
        *)
            echo -e "${BLUE}✗ Installation cancelled.${WHITE}\n"
            exit 1
            ;;
    esac
    
    # Step 1: Update system
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[1/8]${WHITE} ${BLUE}Updating system packages...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    sudo pacman -Syu --noconfirm
    
    # Step 2: Install base tools
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[2/8]${WHITE} ${BLUE}Installing base tools...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    base_packages=(
        "base-devel"
        "git"
        "curl"
        "wget"
        "nano"
        "vim"
        "zsh"
    )
    install_packages "${base_packages[@]}"
    
    # Step 3: Install Hyprland
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[3/8]${WHITE} ${BLUE}Installing Hyprland and dependencies...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    hyprland_packages=(
        "hyprland"
        "kitty"
        "waybar"
        "rofi"
        "firefox"
        "thunar"
        "nemo"
        "neofetch"
        "htop"
        "btop"
    )
    install_packages "${hyprland_packages[@]}"
    
    # Step 4: Install audio and network tools
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[4/8]${WHITE} ${BLUE}Installing audio and network tools...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    system_packages=(
        "pipewire"
        "pipewire-pulse"
        "pipewire-alsa"
        "wireplumber"
        "pavucontrol"
        "networkmanager"
        "network-manager-applet"
        "bluetooth"
        "bluez"
        "bluez-utils"
        "brightnessctl"
        "playerctl"
    )
    install_packages "${system_packages[@]}"
    
    # Step 5: Install fonts
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[5/8]${WHITE} ${BLUE}Installing fonts...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    font_packages=(
        "ttf-jetbrains-mono"
        "ttf-font-awesome"
        "noto-fonts"
        "noto-fonts-cjk"
        "noto-fonts-emoji"
        "ttf-dejavu"
        "ttf-liberation"
        "ttf-nerd-fonts-symbols"
    )
    install_packages "${font_packages[@]}"
    
    # Step 6: Install AUR helper
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[6/8]${WHITE} ${BLUE}Installing AUR helper (yay)...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    if ! command -v yay &> /dev/null; then
        echo -e "${BLUE}Downloading yay...${WHITE}"
        temp_dir=$(mktemp -d)
        clone_with_progress "https://aur.archlinux.org/yay.git" "$temp_dir"
        
        echo -e "${BLUE}Building yay...${WHITE}"
        cd "$temp_dir"
        makepkg -si --noconfirm
        cd ~
        rm -rf "$temp_dir"
        echo -e "${GREEN}✓ yay installed successfully${WHITE}"
    else
        echo -e "${GREEN}✓ yay is already installed${WHITE}"
    fi
    
    # Step 7: Install AUR packages
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[7/8]${WHITE} ${BLUE}Installing AUR packages...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    aur_packages=(
        "hyprpaper"
        "hyprpicker"
        "swaylock-effects"
        "sddm-themes-sugar-candy"
        "cava"
        "nwg-look"
    )
    
    echo -e "${BLUE}Installing ${#aur_packages[@]} AUR packages...${WHITE}"
    for package in "${aur_packages[@]}"; do
        echo -e "${CYAN}Installing: $package${WHITE}"
        yay -S --noconfirm --needed "$package" 2>&1 | \
            while read line; do
                if [[ $line =~ \(([0-9]+)/([0-9]+)\) ]]; then
                    echo -ne "\r${CYAN}Progress: ${BASH_REMATCH[1]}/${BASH_REMATCH[2]}${WHITE}"
                fi
            done
        echo -e "\n${GREEN}✓ $package installed${WHITE}"
    done
    
    # Step 8: Install display manager and configure
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[8/8]${WHITE} ${BLUE}Configuring system...${WHITE}"
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}"
    
    # Install SDDM
    echo -e "${BLUE}Installing SDDM...${WHITE}"
    sudo pacman -S --noconfirm --needed sddm
    
    # Enable services
    echo -e "${BLUE}Enabling services...${WHITE}"
    sudo systemctl enable sddm
    sudo systemctl enable --now NetworkManager
    sudo systemctl enable --now bluetooth
    
    # Download sample wallpaper with progress
    echo -e "${BLUE}Downloading wallpaper...${WHITE}"
    mkdir -p ~/Pictures/Wallpapers
    download_with_progress "https://images.unsplash.com/photo-1618005198919-d3d4b5a92ead?w=1920&q=80" \
        ~/Pictures/Wallpapers/default.jpg
    
    # Create basic configuration
    echo -e "${BLUE}Creating configuration files...${WHITE}"
    
    mkdir -p ~/.config/hypr
    cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = hyprpaper
exec-once = nm-applet --indicator
exec-once = blueman-applet

# Environment variables
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    
    touchpad {
        natural_scroll = false
        disable_while_typing = true
    }
    
    sensitivity = 0
}

# General configuration
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    
    layout = dwindle
}

# Decoration
decoration {
    rounding = 10
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = true
    
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Dwindle layout
dwindle {
    pseudotile = true
    preserve_split = true
}

# Master layout
master {
    new_is_master = true
}

# Keybindings
bind = SUPER, RETURN, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, D, exec, rofi -show drun
bind = SUPER, F, togglefloating,
bind = SUPER, P, pseudo, # dwindle
bind = SUPER, J, togglesplit, # dwindle

# Move focus with arrow keys
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d

# Switch workspaces
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5

# Move to workspace
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5

# Special workspace (scratchpad)
bind = SUPER, S, togglespecialworkspace, magic
bind = SUPER SHIFT, S, movetoworkspace, special:magic

# Scroll through existing workspaces
bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1

# Move/resize windows with mouse
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow

# Function keys
bind = , XF86MonBrightnessUp, exec, brightnessctl set +10%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 10%-
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bind = , XF86AudioPlay, exec, playerctl play-pause
bind = , XF86AudioNext, exec, playerctl next
bind = , XF86AudioPrev, exec, playerctl previous
EOF

    # Create hyprpaper config
    cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/Pictures/Wallpapers/default.jpg
wallpaper = ,~/Pictures/Wallpapers/default.jpg
EOF

    # Create basic waybar config
    mkdir -p ~/.config/waybar
    cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "battery", "tray"],
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-muted": "Muted",
        "format-icons": {
            "headphones": "",
            "default": ["", "", ""]
        }
    }
}
EOF

    # Update font cache
    echo -e "${BLUE}Updating font cache...${WHITE}"
    fc-cache -fv
    
    # Calculate installation time
    end=$(date +%s)
    duration=$((end - start))
    
    hours=$((duration / 3600))
    minutes=$(((duration % 3600) / 60))
    seconds=$((duration % 60))
    
    clear
    
    # Completion message
    echo -e "${GREEN}${BOLD}
    ╔══════════════════════════════════════════════════════════╗
    ║                Installation Complete!                    ║
    ╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "${CYAN}
    ╔══════════════════════════════════════════════════════════╗
    ║  Installation Summary                                    ║
    ╠══════════════════════════════════════════════════════════╣
    ║                                                          ║
    ║  ⏱️  Installation Time: ${hours}h ${minutes}m ${seconds}s                ║
    ║                                                          ║
    ║  📦 Packages Installed: ~70 packages                    ║
    ║                                                          ║
    ║  🎨 Desktop Environment: Hyprland                        ║
    ║                                                          ║
    ║  🖥️  Terminal: Kitty                                    ║
    ║                                                          ║
    ║  🚀 AUR Helper: yay                                     ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "${YELLOW}${BOLD}
    Next Steps:
    ═══════════════════════════════════════════════════════════
    
    1. ${GREEN}Reboot your system:${WHITE}
       sudo reboot
       
    2. ${GREEN}At login screen, select Hyprland${WHITE}
    
    3. ${GREEN}Essential shortcuts:${WHITE}
       - ${CYAN}Super + Enter${WHITE}: Open terminal
       - ${CYAN}Super + D${WHITE}: Application launcher
       - ${CYAN}Super + Q${WHITE}: Close window
       - ${CYAN}Super + E${WHITE}: File manager
       - ${CYAN}Super + F${WHITE}: Toggle floating window
    
    4. ${GREEN}Configuration files:${WHITE}
       - ${CYAN}~/.config/hypr/hyprland.conf${WHITE}: Main config
       - ${CYAN}~/.config/waybar/config${WHITE}: Status bar
       - ${CYAN}~/.config/kitty/kitty.conf${WHITE}: Terminal
    
    5. ${GREEN}Customization:${WHITE}
       - Edit configuration files to customize your setup
       - Install additional themes and icons
       - Add your favorite applications
    
    ${BOLD}Enjoy your new Hyprland desktop environment! 🎉${WHITE}"
}

# Run main function
main "$@"
