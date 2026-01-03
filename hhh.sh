
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# CONFIGURATION AND VARIABLES
# ============================================================================

# Color variables for terminal output
PINK="\e[35m"
WHITE="\e[0m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
RED="\e[31m"
CYAN="\e[36m"
BOLD="\e[1m"
UNDERLINE="\e[4m"

# GitHub mirrors for China (multiple options)
MIRRORS=(
    "https://ghproxy.com"
    "https://mirror.ghproxy.com"
    "https://ghproxy.net"
    "https://gitclone.com"
    ""  # Empty string as fallback to original GitHub
)

# Repository URLs
MAIN_REPO="ViegPhunt/Arch-Hyprland"
DOTFILES_REPO="ViegPhunt/dotfiles"
WALLPAPER_REPO="ViegPhunt/Wallpaper-Collection"
AUTO_SETUP_REPO="ViegPhunt/auto-setup-LT"

# Installation tracking
CURRENT_STEP=0
TOTAL_STEPS=12
INSTALL_START_TIME=0
INSTALL_END_TIME=0

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function to display a step header
show_step_header() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local step_title="$1"
    local step_description="$2"
    
    echo -e "\n${PINK}══════════════════════════════════════════════════════════${WHITE}"
    echo -e "${YELLOW}${BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}]${WHITE} ${BLUE}${BOLD}${step_title}${WHITE}"
    if [[ -n "$step_description" ]]; then
        echo -e "${CYAN}${step_description}${WHITE}"
    fi
    echo -e "${PINK}══════════════════════════════════════════════════════════${WHITE}\n"
}

# Function to display a progress bar
show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    # Create progress bar string
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    
    printf "\r${CYAN}${bar} ${percentage}%% (${current}/${total})${WHITE}"
}

# Function to display spinner animation
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r[%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r[✓] "
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display success message
show_success() {
    echo -e "\r${GREEN}✓${WHITE} $1"
}

# Function to display error message
show_error() {
    echo -e "\r${RED}✗${WHITE} $1"
}

# Function to display warning message
show_warning() {
    echo -e "\r${YELLOW}⚠${WHITE} $1"
}

# Function to display info message
show_info() {
    echo -e "\r${BLUE}ℹ${WHITE} $1"
}

# Function to download file with progress display
download_with_progress() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    if [[ -z "$description" ]]; then
        description="Downloading $(basename "$output")"
    fi
    
    echo -n "${BLUE}${description}...${WHITE} "
    
    # Try different methods for progress display
    if command_exists "pv"; then
        # Method 1: Using pv with curl
        if curl -L "$url" 2>/dev/null | pv -betp -s "$(curl -I "$url" 2>/dev/null | grep -i 'content-length' | awk '{print $2}' | tr -d '\r' || echo 0)" > "$output" 2>/dev/null; then
            show_success "Download complete"
            return 0
        fi
    elif command_exists "curl"; then
        # Method 2: Using curl's built-in progress bar
        if curl -L --progress-bar "$url" -o "$output"; then
            echo ""  # New line after curl progress
            show_success "Download complete"
            return 0
        fi
    elif command_exists "wget"; then
        # Method 3: Using wget with progress bar
        if wget --show-progress -q -O "$output" "$url"; then
            show_success "Download complete"
            return 0
        fi
    else
        # Method 4: Simple curl without progress
        if curl -L -s "$url" -o "$output"; then
            show_success "Download complete"
            return 0
        fi
    fi
    
    show_error "Download failed"
    return 1
}

# Function to clone git repository with progress
clone_repo_with_progress() {
    local repo_url="$1"
    local target_dir="$2"
    local description="$3"
    
    if [[ -z "$description" ]]; then
        description="Cloning $(basename "$repo_url")"
    fi
    
    echo -n "${BLUE}${description}...${WHITE} "
    
    # Start git clone in background
    git clone --progress "$repo_url" "$target_dir" 2>&1 | \
    while read -r line; do
        if [[ "$line" =~ Receiving\ objects:\ +([0-9]+)% ]]; then
            echo -ne "\r${CYAN}${description}: ${BASH_REMATCH[1]}%%${WHITE}"
        fi
    done &
    
    local clone_pid=$!
    wait "$clone_pid"
    
    if [[ $? -eq 0 ]] && [[ -d "$target_dir" ]]; then
        echo -ne "\r${GREEN}✓${WHITE} ${description}: Complete\n"
        return 0
    else
        echo -ne "\r${RED}✗${WHITE} ${description}: Failed\n"
        return 1
    fi
}

# Function to install packages with progress
install_packages_with_progress() {
    local packages=("$@")
    local total_packages=${#packages[@]}
    local installed_count=0
    
    echo -e "${BLUE}Installing ${total_packages} packages...${WHITE}"
    
    for package in "${packages[@]}"; do
        installed_count=$((installed_count + 1))
        show_progress_bar "$installed_count" "$total_packages"
        
        # Install package silently
        sudo pacman -S --noconfirm --needed "$package" > /dev/null 2>&1 &
        local install_pid=$!
        wait "$install_pid"
        
        if [[ $? -ne 0 ]]; then
            echo -e "\n${YELLOW}Warning: Failed to install ${package}${WHITE}"
        fi
    done
    
    echo -e "\n${GREEN}✓ Package installation complete${WHITE}"
}

# Function to install AUR packages with progress
install_aur_packages_with_progress() {
    local aur_helper="$1"
    shift
    local packages=("$@")
    local total_packages=${#packages[@]}
    local installed_count=0
    
    if ! command_exists "$aur_helper"; then
        show_error "AUR helper $aur_helper not found"
        return 1
    fi
    
    echo -e "${BLUE}Installing ${total_packages} AUR packages...${WHITE}"
    
    for package in "${packages[@]}"; do
        installed_count=$((installed_count + 1))
        show_progress_bar "$installed_count" "$total_packages"
        
        # Install AUR package
        "$aur_helper" -S --noconfirm --needed "$package" > /dev/null 2>&1 &
        local install_pid=$!
        wait "$install_pid"
    done
    
    echo -e "\n${GREEN}✓ AUR package installation complete${WHITE}"
}

# Function to calculate and display installation time
show_installation_time() {
    local end_time=$(date +%s)
    local duration=$((end_time - INSTALL_START_TIME))
    
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${WHITE}"
    echo -e "${CYAN}║${WHITE}        Installation Time: ${GREEN}${hours}h ${minutes}m ${seconds}s${WHITE}            ${CYAN}║${WHITE}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${WHITE}"
}

# ============================================================================
# MAIN INSTALLATION FUNCTIONS
# ============================================================================

# Function to update system
update_system() {
    show_step_header "Updating System" "Synchronizing package databases and upgrading all packages"
    
    echo -e "${BLUE}Synchronizing package databases...${WHITE}"
    sudo pacman -Sy
    
    echo -e "\n${BLUE}Upgrading installed packages...${WHITE}"
    sudo pacman -Su --noconfirm
    
    show_success "System updated successfully"
}

# Function to install essential tools
install_essential_tools() {
    show_step_header "Installing Essential Tools" "Basic development tools and utilities"
    
    local essential_packages=(
        "base-devel"
        "git"
        "curl"
        "wget"
        "nano"
        "vim"
        "neovim"
        "zsh"
        "bash-completion"
        "sudo"
        "which"
        "tree"
        "htop"
        "btop"
        "neofetch"
        "unzip"
        "p7zip"
        "tar"
        "gzip"
        "bzip2"
        "xz"
        "zip"
        "unrar"
        "rsync"
        "openssh"
        "gnupg"
        "fzf"
        "jq"
        "yq"
        "bat"
        "exa"
        "fd"
        "ripgrep"
        "tmux"
        "screen"
    )
    
    install_packages_with_progress "${essential_packages[@]}"
}

# Function to install Hyprland and desktop components
install_hyprland_desktop() {
    show_step_header "Installing Hyprland Desktop" "Window manager, display server and desktop components"
    
    local hyprland_packages=(
        "hyprland"
        "hyprpaper"
        "hyprpicker"
        "kitty"
        "waybar"
        "rofi"
        "wofi"
        "dunst"
        "swaybg"
        "swayidle"
        "swaylock"
        "grim"
        "slurp"
        "swappy"
        "wl-clipboard"
        "cliphist"
        "brightnessctl"
        "playerctl"
        "pavucontrol"
        "network-manager-applet"
        "blueman"
        "polkit-kde-agent"
        "xdg-desktop-portal"
        "xdg-desktop-portal-hyprland"
        "qt5-wayland"
        "qt6-wayland"
        "glfw-wayland"
    )
    
    install_packages_with_progress "${hyprland_packages[@]}"
}

# Function to install audio and network components
install_audio_network() {
    show_step_header "Installing Audio & Network" "Audio system, network management and connectivity tools"
    
    local audio_network_packages=(
        "pipewire"
        "pipewire-pulse"
        "pipewire-alsa"
        "pipewire-jack"
        "wireplumber"
        "gst-plugin-pipewire"
        "networkmanager"
        "networkmanager-openvpn"
        "networkmanager-openconnect"
        "networkmanager-vpnc"
        "networkmanager-l2tp"
        "network-manager-applet"
        "bluetooth"
        "bluez"
        "bluez-utils"
        "blueman"
        "wpa_supplicant"
        "iwd"
        "dhcpcd"
        "nftables"
        "iptables-nft"
        "openbsd-netcat"
        "nmap"
        "wget"
        "curl"
        "lynx"
        "links"
        "elinks"
        "httpie"
        "socat"
    )
    
    install_packages_with_progress "${audio_network_packages[@]}"
}

# Function to install fonts
install_fonts() {
    show_step_header "Installing Fonts" "Various fonts for better typography and language support"
    
    local font_packages=(
        "ttf-jetbrains-mono"
        "ttf-jetbrains-mono-nerd"
        "ttf-font-awesome"
        "ttf-font-awesome-otf"
        "noto-fonts"
        "noto-fonts-cjk"
        "noto-fonts-emoji"
        "noto-fonts-extra"
        "ttf-dejavu"
        "ttf-liberation"
        "ttf-ubuntu-font-family"
        "ttf-fira-code"
        "ttf-fira-mono"
        "ttf-fira-sans"
        "ttf-hack"
        "ttf-inconsolata"
        "otf-fira-mono"
        "adobe-source-code-pro-fonts"
        "adobe-source-sans-fonts"
        "adobe-source-serif-fonts"
        "nerd-fonts-complete"
        "ttf-nerd-fonts-symbols"
        "ttf-nerd-fonts-symbols-common"
        "ttf-nerd-fonts-symbols-mono"
        "ttf-material-design-icons"
        "ttf-material-design-icons-webfont"
        "ttf-material-design-icons-extended"
        "ttf-material-design-iconic-font"
        "ttf-material-icons"
        "ttf-ms-fonts"
        "ttf-apple-fonts"
        "ttf-google-fonts"
    )
    
    install_packages_with_progress "${font_packages[@]}"
    
    echo -e "${BLUE}Updating font cache...${WHITE}"
    fc-cache -fv
    show_success "Font cache updated"
}

# Function to install additional applications
install_applications() {
    show_step_header "Installing Applications" "Useful desktop applications and tools"
    
    local application_packages=(
        "firefox"
        "chromium"
        "thunderbird"
        "thunar"
        "nemo"
        "nautilus"
        "pcmanfm"
        "vlc"
        "mpv"
        "gimp"
        "inkscape"
        "krita"
        "blender"
        "obs-studio"
        "audacity"
        "libreoffice-fresh"
        "okular"
        "evince"
        "gparted"
        "transmission-gtk"
        "qbittorrent"
        "filezilla"
        "visual-studio-code-bin"
        "sublime-text-4"
        "discord"
        "telegram-desktop"
        "element-desktop"
        "spotify"
        "steam"
        "lutris"
        "heroic-games-launcher"
        "virt-manager"
        "docker"
        "docker-compose"
        "virtualbox"
        "virtualbox-host-modules-arch"
        "wine"
        "wine-gecko"
        "wine-mono"
        "winetricks"
        "playonlinux"
        "proton"
        "proton-ge-custom"
        "lutris"
        "gamemode"
        "mangohud"
        "goverlay"
    )
    
    install_packages_with_progress "${application_packages[@]}"
}

# Function to install AUR helper (yay)
install_aur_helper() {
    show_step_header "Installing AUR Helper" "Setting up yay for Arch User Repository packages"
    
    if command_exists "yay"; then
        show_success "yay is already installed"
        return 0
    fi
    
    echo -e "${BLUE}Installing dependencies for yay...${WHITE}"
    sudo pacman -S --noconfirm --needed base-devel git
    
    echo -e "${BLUE}Cloning yay repository...${WHITE}"
    local temp_dir=$(mktemp -d)
    
    if clone_repo_with_progress "https://aur.archlinux.org/yay.git" "$temp_dir" "Cloning yay AUR repository"; then
        echo -e "${BLUE}Building and installing yay...${WHITE}"
        cd "$temp_dir"
        makepkg -si --noconfirm
        cd - > /dev/null
        rm -rf "$temp_dir"
        
        if command_exists "yay"; then
            show_success "yay installed successfully"
        else
            show_error "Failed to install yay"
            return 1
        fi
    else
        show_error "Failed to clone yay repository"
        return 1
    fi
}

# Function to install AUR packages
install_aur_packages() {
    show_step_header "Installing AUR Packages" "Additional software from Arch User Repository"
    
    if ! command_exists "yay"; then
        show_error "yay is not installed. Skipping AUR packages."
        return 1
    fi
    
    local aur_packages=(
        "visual-studio-code-bin"
        "sublime-text-4"
        "google-chrome"
        "brave-bin"
        "spotify"
        "discord"
        "zoom"
        "teamviewer"
        "anydesk-bin"
        "parsec-bin"
        "github-desktop-bin"
        "insomnia-bin"
        "postman-bin"
        "mongodb-compass"
        "mongodb-bin"
        "redis-desktop-manager-bin"
        "dbeaver"
        "mysql-workbench"
        "docker-desktop"
        "jetbrains-toolbox"
        "intellij-idea-ultimate-edition"
        "pycharm-professional"
        "clion"
        "webstorm"
        "phpstorm"
        "rubymine"
        "android-studio"
        "flutter"
        "react-native-debugger"
        "mongodb-compass"
        "robo3t-bin"
        "studio-3t"
        "mongo-shell"
        "mongodb-tools"
        "redis"
        "redis-tools"
        "memcached"
        "postgresql"
        "postgresql-libs"
        "postgresql-client"
        "pgadmin4"
        "mysql"
        "mariadb"
        "sqlite"
        "sqlitebrowser"
        "mongodb"
        "redis"
        "memcached"
        "nginx"
        "apache"
        "php"
        "php-fpm"
        "composer"
        "nodejs"
        "npm"
        "yarn"
        "python"
        "python-pip"
        "python-virtualenv"
        "python-pipenv"
        "python-poetry"
        "ruby"
        "ruby-bundler"
        "go"
        "rust"
        "cargo"
        "jdk-openjdk"
        "jre-openjdk"
        "jdk8-openjdk"
        "jdk11-openjdk"
        "jdk17-openjdk"
        "jdk18-openjdk"
        "jdk19-openjdk"
        "maven"
        "gradle"
        "sbt"
        "scala"
        "kotlin"
        "groovy"
        "clojure"
        "haskell"
        "ocaml"
        "fsharp"
        "erlang"
        "elixir"
        "dart"
        "flutter"
        "dart-sass"
        "typescript"
        "typescript-language-server"
        "vue"
        "react"
        "angular"
        "svelte"
        "ember"
        "backbone"
        "jquery"
        "bootstrap"
        "tailwindcss"
        "bulma"
        "foundation"
        "materialize"
        "uikit"
        "semantic-ui"
        "purecss"
        "milligram"
        "spectre.css"
        "nes.css"
        "animate.css"
        "hover.css"
        "loaders.css"
        "spinkit"
        "css-doodle"
        "css.gg"
        "fontawesome"
        "material-icons"
        "ionicons"
        "feather-icons"
        "heroicons"
        "octicons"
        "simple-icons"
        "weather-icons"
        "flag-icon-css"
        "country-flags"
        "emoji-flags"
        "twemoji-color-font"
        "noto-fonts-emoji"
        "ttf-twemoji"
        "ttf-twemoji-color"
        "ttf-apple-emoji"
        "ttf-google-emoji"
        "ttf-samsung-emoji"
        "ttf-emojione"
        "ttf-emojione-color"
    )
    
    # Install AUR packages in batches to avoid timeouts
    local batch_size=10
    local total_batches=$(( (${#aur_packages[@]} + batch_size - 1) / batch_size ))
    
    for ((batch=0; batch<total_batches; batch++)); do
        local start=$((batch * batch_size))
        local end=$((start + batch_size))
        local batch_packages=("${aur_packages[@]:start:batch_size}")
        
        echo -e "${BLUE}Installing AUR batch $((batch + 1))/${total_batches} (${#batch_packages[@]} packages)...${WHITE}"
        install_aur_packages_with_progress "yay" "${batch_packages[@]}"
        
        # Small delay between batches
        sleep 2
    done
}

# Function to setup display manager (SDDM)
setup_display_manager() {
    show_step_header "Setting Up Display Manager" "Configuring SDDM for graphical login"
    
    echo -e "${BLUE}Installing SDDM...${WHITE}"
    sudo pacman -S --noconfirm --needed sddm sddm-kcm
    
    echo -e "${BLUE}Enabling SDDM service...${WHITE}"
    sudo systemctl enable sddm
    
    # Configure SDDM theme
    echo -e "${BLUE}Configuring SDDM theme...${WHITE}"
    sudo mkdir -p /etc/sddm.conf.d/
    
    cat << EOF | sudo tee /etc/sddm.conf.d/theme.conf > /dev/null
[Theme]
Current=sugar-candy
CursorTheme=Bibata-Modern-Classic
EOF
    
    show_success "SDDM configured successfully"
}

# Function to enable system services
enable_system_services() {
    show_step_header "Enabling System Services" "Activating essential background services"
    
    local services=(
        "NetworkManager"
        "bluetooth"
        "sshd"
        "docker"
        "cronie"
        "avahi-daemon"
        "cups"
        "cups-browsed"
        "fstrim.timer"
        "paccache.timer"
        "systemd-oomd"
        "systemd-resolved"
        "systemd-timesyncd"
    )
    
    for service in "${services[@]}"; do
        echo -n "${BLUE}Enabling ${service}...${WHITE} "
        if sudo systemctl enable "$service" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${WHITE}"
        else
            echo -e "${YELLOW}⚠${WHITE} (not found or already enabled)"
        fi
    done
    
    show_success "System services enabled"
}

# Function to clone and setup dotfiles
setup_dotfiles() {
    show_step_header "Setting Up Dotfiles" "Cloning and applying configuration files"
    
    local dotfiles_dir="$HOME/dotfiles"
    
    # Try different mirrors for dotfiles
    for mirror in "${MIRRORS[@]}"; do
        local repo_url=""
        if [[ -z "$mirror" ]]; then
            repo_url="https://github.com/${DOTFILES_REPO}.git"
        else
            repo_url="${mirror}/https://github.com/${DOTFILES_REPO}.git"
        fi
        
        echo -e "${BLUE}Trying to clone dotfiles from: ${repo_url}${WHITE}"
        
        if clone_repo_with_progress "$repo_url" "$dotfiles_dir" "Cloning dotfiles"; then
            break
        fi
    done
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        show_warning "Could not clone dotfiles, creating minimal configuration"
        create_minimal_config
        return 0
    fi
    
    # Install stow if not present
    if ! command_exists "stow"; then
        echo -e "${BLUE}Installing GNU Stow...${WHITE}"
        sudo pacman -S --noconfirm stow
    fi
    
    # Apply dotfiles using stow
    if [[ -d "$dotfiles_dir" ]]; then
        echo -e "${BLUE}Applying dotfiles with stow...${WHITE}"
        cd "$dotfiles_dir"
        
        # List of directories to stow
        local stow_dirs=("hypr" "waybar" "kitty" "rofi" "zsh" "nvim" "tmux" "git" "alacritty" "sway" "i3" "bspwm" "awesome" "qtile" "xmonad" "dunst" "polybar" "picom" "redshift" "mpv" "ncmpcpp" "newsboat" "ranger" "lf" "vim" "emacs" "vscode" "sublime-text" "intellij" "pycharm" "webstorm" "phpstorm" "rubymine" "clion" "android-studio" "flutter")
        
        for dir in "${stow_dirs[@]}"; do
            if [[ -d "$dir" ]]; then
                echo -n "${BLUE}Stowing ${dir}...${WHITE} "
                if stow -t "$HOME" "$dir" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓${WHITE}"
                else
                    echo -e "${YELLOW}⚠${WHITE}"
                fi
            fi
        done
        
        cd - > /dev/null
    fi
    
    show_success "Dotfiles setup complete"
}

# Function to create minimal configuration if dotfiles not available
create_minimal_config() {
    show_step_header "Creating Minimal Configuration" "Setting up basic configuration files"
    
    # Create Hyprland configuration
    mkdir -p ~/.config/hypr
    cat > ~/.config/hypr/hyprland.conf << 'EOF'
# This is an example Hyprland config file.
# Refer to the wiki for more information: https://wiki.hyprland.org

# Monitor configuration
monitor=,preferred,auto,1

# Execute your favorite apps at launch
exec-once = waybar
exec-once = dunst
exec-once = nm-applet --indicator
exec-once = blueman-applet
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Source a file (multi-file configs)
# source = ~/.config/hypr/myColors.conf

# Some default env vars.
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct # change to qt6ct if you have that

# For all categories, see https://wiki.hyprland.org/Configuring/Variables/
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1

    touchpad {
        natural_scroll = no
    }

    sensitivity = 0 # -1.0 to 1.0, 0 means no modification.
}

general {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more

    gaps_in = 5
    gaps_out = 20
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)

    layout = dwindle

    # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
    allow_tearing = false
}

decoration {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more

    rounding = 10
    
    blur {
        enabled = true
        size = 3
        passes = 1
    }

    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

animations {
    enabled = yes

    # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

    bezier = myBezier, 0.05, 0.9, 0.1, 1.05

    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
    pseudotile = yes # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = yes # you probably want this
}

master {
    # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
    new_is_master = true
}

gestures {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    workspace_swipe = off
}

misc {
    # See https://wiki.hyprland.org/Configuring/Variables/ for more
    force_default_wallpaper = -1 # Set to 0 to disable the anime mascot wallpapers
}

# Example per-device config
# See https://wiki.hyprland.org/Configuring/Keywords/#executing for more
device:epic-mouse-v1 {
    sensitivity = -0.5
}

# Example windowrule v1
# windowrule = float, ^(kitty)$
# Example windowrule v2
# windowrulev2 = float,class:^(kitty)$,title:^(kitty)$
# See https://wiki.hyprland.org/Configuring/Window-Rules/ for more


# See https://wiki.hyprland.org/Configuring/Keywords/ for more
$mainMod = SUPER

# Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, rofi -show drun
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, J, togglesplit, # dwindle

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF

    # Create Waybar configuration
    mkdir -p ~/.config/waybar
    cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["custom/launcher", "hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "bluetooth", "battery", "tray"],
    "custom/launcher": {
        "format": "",
        "on-click": "rofi -show drun",
        "tooltip": false
    },
    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}"
    },
    "pulseaudio": {
        "format": "{volume}% {icon}",
        "format-muted": " Muted",
        "format-icons": {
            "headphones": "",
            "handsfree": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    "network": {
        "format-wifi": "{essid} ({signalStrength}%) ",
        "format-ethernet": "{ipaddr}/{cidr} ",
        "tooltip-format": "{ifname} via {gwaddr}",
        "format-linked": "{ifname} (No IP) ",
        "format-disconnected": "Disconnected ⚠",
        "on-click": "nm-connection-editor"
    },
    "bluetooth": {
        "format": " {status}",
        "format-disabled": "",
        "format-connected": " {num_connections}",
        "tooltip-format": "{controller_alias}\t{controller_address}",
        "tooltip-format-connected": "{controller_alias}\t{controller_address}\n\n{device_enumerate}",
        "tooltip-format-enumerate-connected": "{device_alias}\t{device_address}"
    },
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{capacity}% {icon}",
        "format-charging": "{capacity}% ",
        "format-plugged": "{capacity}% ",
        "format-alt": "{time} {icon}",
        "format-icons": ["", "", "", "", ""]
    },
    "tray": {
        "spacing": 10
    }
}
EOF

    cat > ~/.config/waybar/style.css << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 14px;
    min-height: 0;
}

window#waybar {
    background: rgba(43, 48, 59, 0.9);
    border-bottom: 3px solid rgba(100, 114, 125, 0.5);
    color: white;
}

#workspaces button {
    padding: 0 10px;
    background: transparent;
    color: white;
    border-bottom: 3px solid transparent;
}

#workspaces button.focused {
    background: #64727D;
    border-bottom: 3px solid white;
}

#mode {
    background: #64727D;
    border-bottom: 3px solid white;
}

#clock, #battery, #cpu, #memory, #network, #pulseaudio, #tray, #mode {
    padding: 0 10px;
    margin: 0 5px;
}

#clock {
    background-color: #64727D;
}

#battery {
    background-color: #ffffff;
    color: black;
}

#battery.charging {
    color: white;
    background-color: #26A65B;
}

@keyframes blink {
    to {
        background-color: #ffffff;
        color: black;
    }
}

#battery.warning:not(.charging) {
    background: #f53c3c;
    color: white;
    animation-name: blink;
    animation-duration: 0.5s;
    animation-timing-function: linear;
    animation-iteration-count: infinite;
    animation-direction: alternate;
}

#cpu {
    background: #2ecc71;
    color: #000000;
}

#memory {
    background: #9b59b6;
}

#network {
    background: #2980b9;
}

#network.disconnected {
    background: #f53c3c;
}

#pulseaudio {
    background: #f1c40f;
    color: black;
}

#pulseaudio.muted {
    background: #90b1b1;
    color: #2a5c45;
}

#tray {
    background-color: #2980b9;
}
EOF

    # Create Kitty configuration
    mkdir -p ~/.config/kitty
    cat > ~/.config/kitty/kitty.conf << 'EOF'
# kitty.conf - Configuration file for kitty terminal emulator

# Font
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        12.0

# Cursor
cursor_shape     beam
cursor_blink_interval     0.5
cursor_stop_blinking_after 15.0

# Scrollback
scrollback_lines 10000
scrollback_pager less --chop-long-lines --RAW-CONTROL-CHARS +INPUT_LINE_NUMBER
wheel_scroll_multiplier 5.0

# Mouse
mouse_hide_wait  3.0
url_color        #0087bd
url_style        dotted

# Bell
visual_bell_duration 0.0
enable_audio_bell no

# Window
remember_window_size   yes
initial_window_width   640
initial_window_height  400
window_border_width 0.5
window_margin_width 5
window_padding_width 5
inactive_text_alpha 1.0
background_opacity 0.95

# Layouts
enabled_layouts *

# Tabs
tab_bar_edge top
tab_bar_margin_width 0.0
tab_bar_style fade
tab_fade 0.25 0.5 0.75 1

# Colors
# Based on Material Ocean
foreground            #c3c7d1
background            #0f111a
selection_foreground  #ffffff
selection_background  #44475a

# Black
color0   #21222c
color8   #6272a4

# Red
color1   #ff5555
color9   #ff6e6e

# Green
color2   #50fa7b
color10  #69ff94

# Yellow
color3   #f1fa8c
color11  #ffffa5

# Blue
color4   #bd93f9
color12  #d6acff

# Magenta
color5   #ff79c6
color13  #ff92df

# Cyan
color6   #8be9fd
color14  #a4ffff

# White
color7   #f8f8f2
color15  #ffffff

# Advanced
shell_integration enabled
allow_hyperlinks yes
EOF

    show_success "Minimal configuration created"
}

# Function to download wallpapers
download_wallpapers() {
    show_step_header "Downloading Wallpapers" "Fetching beautiful desktop backgrounds"
    
    local wallpaper_dir="$HOME/Pictures/Wallpapers"
    mkdir -p "$wallpaper_dir"
    
    # List of wallpaper URLs to download
    local wallpaper_urls=(
        "https://images.unsplash.com/photo-1618005198919-d3d4b5a92ead?w=3840&q=80"
        "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=3840&q=80"
        "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=3840&q=80"
        "https://images.unsplash.com/photo-1465101162946-4377e57745c3?w=3840&q=80"
        "https://images.unsplash.com/photo-1506318137071-a8e063b4bec0?w=3840&q=80"
        "https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?w=3840&q=80"
        "https://images.unsplash.com/photo-1446776653964-20c1d3a81b06?w=3840&q=80"
        "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=3840&q=80"
        "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=3840&q=80"
        "https://images.unsplash.com/photo-1519681393784-d120267933ba?w=3840&q=80"
    )
    
    echo -e "${BLUE}Downloading ${#wallpaper_urls[@]} wallpapers...${WHITE}"
    
    local count=0
    for url in "${wallpaper_urls[@]}"; do
        count=$((count + 1))
        local filename="wallpaper-${count}.jpg"
        
        echo -n "${BLUE}Downloading wallpaper ${count}/${#wallpaper_urls[@]}...${WHITE} "
        
        if download_with_progress "$url" "${wallpaper_dir}/${filename}" "Wallpaper ${count}"; then
            # No need to show success here as download_with_progress already does
            true
        else
            show_warning "Failed to download wallpaper ${count}"
        fi
    done
    
    # Set a default wallpaper for hyprpaper
    if [[ -f "${wallpaper_dir}/wallpaper-1.jpg" ]]; then
        mkdir -p ~/.config/hypr
        cat > ~/.config/hypr/hyprpaper.conf << EOF
preload = ${wallpaper_dir}/wallpaper-1.jpg
wallpaper = ,${wallpaper_dir}/wallpaper-1.jpg
EOF
        show_success "Default wallpaper set"
    fi
    
    show_success "Wallpapers downloaded and configured"
}

# Function to setup zsh with oh-my-zsh
setup_zsh() {
    show_step_header "Setting Up ZSH" "Configuring ZSH with oh-my-zsh and plugins"
    
    # Install zsh if not already installed
    if ! command_exists "zsh"; then
        echo -e "${BLUE}Installing ZSH...${WHITE}"
        sudo pacman -S --noconfirm zsh
    fi
    
    # Change default shell to zsh
    echo -e "${BLUE}Changing default shell to ZSH...${WHITE}"
    chsh -s "$(which zsh)"
    
    # Install oh-my-zsh
    echo -e "${BLUE}Installing oh-my-zsh...${WHITE}"
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Install powerlevel10k theme
    echo -e "${BLUE}Installing powerlevel10k theme...${WHITE}"
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    fi
    
    # Install zsh plugins
    echo -e "${BLUE}Installing ZSH plugins...${WHITE}"
    
    # zsh-syntax-highlighting
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    fi
    
    # zsh-autosuggestions
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    fi
    
    # zsh-completions
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions"
    fi
    
    # Create .zshrc if it doesn't exist
    if [[ ! -f "$HOME/.zshrc" ]]; then
        cat > "$HOME/.zshrc" << 'EOF'
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-syntax-highlighting
    zsh-autosuggestions
    zsh-completions
    docker
    docker-compose
    kubectl
    helm
    terraform
    aws
    npm
    yarn
    pip
    python
    ruby
    rails
    rake
    rbenv
    bundler
    golang
    rust
    cargo
    postgres
    mysql
    redis-cli
    mongodb
    nvm
    node
    npm
    yarn
    gulp
    grunt
    web-search
    sudo
    copypath
    copyfile
    dirhistory
    history
    jsontools
    urltools
    wd
    extract
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load autojump if available
[[ -s /etc/profile.d/autojump.sh ]] && source /etc/profile.d/autojump.sh

# Load fzf if available
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# NVM initialization
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Python virtualenvwrapper
export WORKON_HOME=$HOME/.virtualenvs
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python3
export VIRTUALENVWRAPPER_VIRTUALENV=/usr/bin/virtualenv
source /usr/bin/virtualenvwrapper.sh

# Go paths
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Rust/Cargo path
export PATH=$PATH:$HOME/.cargo/bin

# Local bin directory
export PATH=$PATH:$HOME/.local/bin

# Custom aliases
alias ls='exa --icons --group-directories-first'
alias ll='exa -l --icons --group-directories-first'
alias la='exa -la --icons --group-directories-first'
alias tree='exa --tree --icons'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias ps='procs'
alias du='dust'
alias df='duf'
alias top='btop'
alias htop='btop'
alias diff='delta'
alias man='tldr'
alias curl='http'
alias ping='gping'
alias traceroute='mtr'
alias nc='ncat'
alias ssh='ssh -o VisualHostKey=yes'
alias scp='rsync -avz --progress'
alias wget='wget --progress=bar:force'
alias curl='curl --progress-bar'
alias vim='nvim'
alias vi='nvim'
alias v='nvim'
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gs='git status'
alias gl='git log --oneline --graph --all'
alias gp='git push'
alias gpl='git pull'
alias gd='git diff'
alias gds='git diff --staged'
alias docker='sudo docker'
alias docker-compose='sudo docker-compose'
alias k='kubectl'
alias kctx='kubectl ctx'
alias kns='kubectl ns'
alias tf='terraform'
alias tg='terragrunt'
alias aws='aws --color=on'
alias python='python3'
alias pip='pip3'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias remove='sudo pacman -Rns'
alias search='sudo pacman -Ss'
alias clean='sudo pacman -Sc'
alias orphans='sudo pacman -Rns $(pacman -Qtdq)'
alias yupdate='yay -Syu'
alias yinstall='yay -S'
alias yremove='yay -Rns'
alias ysearch='yay -Ss'
alias yclean='yay -Sc'
EOF
    fi
    
    show_success "ZSH setup complete"
}

# Function to display completion summary
show_completion_summary() {
    clear
    
    echo -e "${GREEN}${BOLD}"
    echo -e "╔══════════════════════════════════════════════════════════╗"
    echo -e "║          ARCH LINUX + HYPRLAND INSTALLATION COMPLETE     ║"
    echo -e "╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "${CYAN}${BOLD}"
    echo -e "╔══════════════════════════════════════════════════════════╗"
    echo -e "║                     INSTALLATION SUMMARY                  ║"
    echo -e "╠══════════════════════════════════════════════════════════╣${WHITE}"
    
    show_installation_time
    
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════╣${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} System updated and upgraded                    ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Essential tools installed                     ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Hyprland desktop environment installed        ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Audio and network components installed        ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Fonts installed and configured                ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Additional applications installed             ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} AUR helper (yay) installed                    ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} AUR packages installed                        ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Display manager (SDDM) configured             ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} System services enabled                       ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Dotfiles cloned and applied                   ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} Wallpapers downloaded                         ${CYAN}║${WHITE}"
    echo -e "${CYAN}║${WHITE}  ${GREEN}✓${WHITE} ZSH shell configured                          ${CYAN}║${WHITE}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "\n${YELLOW}${BOLD}NEXT STEPS:${WHITE}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════${WHITE}"
    echo -e ""
    echo -e "  1. ${GREEN}Reboot your system:${WHITE}"
    echo -e "     ${CYAN}sudo reboot${WHITE}"
    echo -e ""
    echo -e "  2. ${GREEN}At the login screen (SDDM):${WHITE}"
    echo -e "     • Select ${CYAN}Hyprland${WHITE} session"
    echo -e "     • Log in with your credentials"
    echo -e ""
    echo -e "  3. ${GREEN}Essential keyboard shortcuts:${WHITE}"
    echo -e "     • ${CYAN}Super + Enter${WHITE}: Open terminal (Kitty)"
    echo -e "     • ${CYAN}Super + D${WHITE}: Application launcher (Rofi)"
    echo -e "     • ${CYAN}Super + Q${WHITE}: Close focused window"
    echo -e "     • ${CYAN}Super + Shift + E${WHITE}: Exit Hyprland"
    echo -e "     • ${CYAN}Super + 1-9${WHITE}: Switch workspaces"
    echo -e "     • ${CYAN}Super + Shift + 1-9${WHITE}: Move window to workspace"
    echo -e ""
    echo -e "  4. ${GREEN}Configuration files:${WHITE}"
    echo -e "     • ${CYAN}~/.config/hypr/hyprland.conf${WHITE}: Main Hyprland config"
    echo -e "     • ${CYAN}~/.config/waybar/config${WHITE}: Status bar configuration"
    echo -e "     • ${CYAN}~/.config/kitty/kitty.conf${WHITE}: Terminal settings"
    echo -e "     • ${CYAN}~/.config/rofi/config.rasi${WHITE}: App launcher theme"
    echo -e ""
    echo -e "  5. ${GREEN}Customization:${WHITE}"
    echo -e "     • Edit configuration files to suit your preferences"
    echo -e "     • Install additional themes and icons"
    echo -e "     • Add your favorite applications"
    echo -e ""
    echo -e "  6. ${GREEN}Getting help:${WHITE}"
    echo -e "     • Hyprland Wiki: ${CYAN}https://wiki.hyprland.org${WHITE}"
    echo -e "     • Arch Linux Wiki: ${CYAN}https://wiki.archlinux.org${WHITE}"
    echo -e "     • GitHub Repository: ${CYAN}https://github.com/ViegPhunt/Arch-Hyprland${WHITE}"
    echo -e ""
    echo -e "${GREEN}${BOLD}Enjoy your new Arch Linux + Hyprland desktop environment! 🎉${WHITE}"
    echo -e ""
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

# Main installation function
main() {
    # Record start time
    INSTALL_START_TIME=$(date +%s)
    
    # Clear screen and show header
    clear
    
    echo -e "${PINK}${BOLD}"
    echo -e "╔══════════════════════════════════════════════════════════╗"
    echo -e "║     Arch Linux + Hyprland Complete Installation Script   ║"
    echo -e "║                  With Progress Display                    ║"
    echo -e "╚══════════════════════════════════════════════════════════╝${WHITE}"
    
    echo -e "${YELLOW}${BOLD}"
    echo -e "╔══════════════════════════════════════════════════════════╗"
    echo -e "║                        IMPORTANT                         ║"
    echo -e "╠══════════════════════════════════════════════════════════╣"
    echo -e "║  ⚠️   This script will make significant changes to      ║"
    echo -e "║      your system configuration!                          ║"
    echo -e "║                                                          ║"
    echo -e "║  📋 It will:                                            ║"
    echo -e "║     • Install Hyprland and dependencies                  ║"
    echo -e "║     • Configure desktop environment                      ║"
    echo -e "║     • Install numerous applications                      ║"
    echo -e "║     • Set up development tools                          ║"
    echo -e "║     • Configure system services                         ║"
    echo -e "║                                                          ║"
    echo -e "║  💾 Ensure you have:                                    ║"
    echo -e "║     • Stable internet connection                        ║"
    echo -e "║     • At least 20GB free disk space                     ║"
    echo -e "║     • Backup of important data                          ║"
    echo -e "╚══════════════════════════════════════════════════════════╝${WHITE}"
    echo -e ""
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        show_error "This script should NOT be run as root!"
        echo -e "${YELLOW}Please run as a regular user with sudo privileges.${WHITE}"
        exit 1
    fi
    
    # Check if user is in sudoers
    if ! sudo -n true 2>/dev/null; then
        show_error "User does not have sudo privileges!"
        echo -e "${YELLOW}Please ensure your user is in the sudoers file.${WHITE}"
        exit 1
    fi
    
    # Ask for confirmation
    echo -e "${YELLOW}${BOLD}Do you want to proceed with the installation?${WHITE}"
    read -p "Type 'YES' to continue or anything else to abort: " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        echo -e "${BLUE}Installation aborted by user.${WHITE}"
        exit 0
    fi
    
    echo -e "\n${GREEN}Starting installation...${WHITE}"
    
    # Execute installation steps
    update_system
    install_essential_tools
    install_hyprland_desktop
    install_audio_network
    install_fonts
    install_applications
    install_aur_helper
    install_aur_packages
    setup_display_manager
    enable_system_services
    setup_dotfiles
    download_wallpapers
    setup_zsh
    
    # Show completion summary
    show_completion_summary
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    
    show_error "Script failed at line ${line_number} with exit code ${exit_code}"
    echo -e "${YELLOW}Please check the error messages above and try again.${WHITE}"
    exit $exit_code
}

# Set error trap
trap 'handle_error ${LINENO}' ERR

# Execute main function
main "$@"
