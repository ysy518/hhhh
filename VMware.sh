#!/bin/bash
# fix_vmware_hyprland.sh

echo "=== 修复 VMware 上的 Hyprland ==="

# 1. 安装 VMware 工具和必要的驱动
echo "安装 VMware 工具和驱动..."
sudo pacman -S --needed --noconfirm \
    open-vm-tools \
    gtkmm3 \
    xf86-video-vmware \
    xf86-input-vmmouse \
    xf86-input-vmmouse \
    mesa \
    vulkan-intel \
    vulkan-radeon \
    lib32-mesa \
    lib32-vulkan-intel \
    lib32-vulkan-radeon

# 2. 启用 VMware 服务
echo "启用 VMware 服务..."
sudo systemctl enable --now vmtoolsd
sudo systemctl enable --now vmware-vmblock-fuse

# 3. 创建 VMware 特定的 Hyprland 配置
echo "创建 VMware 特定的配置..."
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# VMware 专用配置
monitor=,preferred,auto,1

# VMware 环境变量
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER,vulkan
env = LIBGL_ALWAYS_SOFTWARE,0

# 输入配置
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
        disable_while_typing = false
    }
    
    # VMware 鼠标设置
    sensitivity = 0.0
    accel_profile = flat
}

# 通用设置
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
    resize_on_border = true
}

# 装饰（简化以节省资源）
decoration {
    rounding = 5
    blur {
        enabled = false  # VMware 中禁用模糊以提高性能
        size = 3
        passes = 1
        vibrancy = 0.0
    }
    drop_shadow = false
    active_opacity = 1.0
    inactive_opacity = 0.9
}

# 动画（简化）
animations {
    enabled = yes
    bezier = linear, 0, 0, 1, 1
    animation = windows, 1, 3, linear
    animation = border, 1, 5, linear
    animation = fade, 1, 3, linear
    animation = workspaces, 1, 3, linear
}

# Dwindle布局
dwindle {
    pseudotile = yes
    preserve_split = yes
    smart_split = false
    smart_resizing = false
}

# 主布局
master {
    new_is_master = true
}

# 手势
gestures {
    workspace_swipe = false
}

# 调试设置（启用日志）
debug {
    disable_logs = false
    damage_tracking = 2
    enable_stdout_logs = true
}

# 自动启动
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = vmware-user-suid-wrapper

# 启动基础应用
exec-once = waybar
exec-once = mako
exec-once = nm-applet --indicator
EOF

echo "✓ VMware 配置已创建"
