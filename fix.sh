cat > ~/quick_fix_vmware.sh << 'EOF'
#!/bin/bash
echo "快速修复 VMware Hyprland 问题..."

# 1. 停止所有可能冲突的服务
sudo systemctl stop sddm 2>/dev/null || true
pkill -9 Hyprland 2>/dev/null || true

# 2. 清理缓存
rm -rf ~/.cache/hypr/
rm -f ~/.Xauthority
rm -f /tmp/hypr-*.pid 2>/dev/null || true

# 3. 创建绝对最小的配置
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/hyprland.conf << 'CONFIG'
# VMware 最小配置
monitor=,preferred,auto,1

# 必须的 VMware 环境变量
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER,pixman
env = QT_QPA_PLATFORM,wayland
env = GDK_BACKEND,wayland

# 最简单的输入
input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0.0
}

# 最简单的通用设置
general {
    gaps_in = 0
    gaps_out = 0
    border_size = 1
    col.active_border = rgb(ff0000)
    col.inactive_border = rgb(000000)
}

# 禁用所有效果
decoration {
    rounding = 0
    blur = no
    drop_shadow = no
}

animations {
    enabled = no
}

dwindle {
    pseudotile = no
    preserve_split = no
}

# 只启动必要的服务
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
CONFIG

# 4. 设置权限
chmod 644 ~/.config/hypr/hyprland.conf

# 5. 创建直接启动脚本
cat > ~/launch_hypr_vmware.sh << 'LAUNCHER'
#!/bin/bash
# 直接启动脚本
export WLR_NO_HARDWARE_CURSORS=1
export WLR_RENDERER=pixman
export QT_QPA_PLATFORM=wayland
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Hyprland

echo "使用最小配置启动 Hyprland..."
exec Hyprland --config ~/.config/hypr/hyprland.conf
LAUNCHER

chmod +x ~/launch_hypr_vmware.sh

echo ""
echo "修复完成！"
echo "现在可以运行以下命令测试："
echo "1. 查看诊断: ./vmware_diagnose.sh"
echo "2. 测试启动: ~/launch_hypr_vmware.sh"
echo ""
echo "如果启动成功，可以逐步添加配置。"
echo "如果失败，请查看 ~/.cache/hypr/hyprland.log"
EOF

chmod +x ~/quick_fix_vmware.sh
