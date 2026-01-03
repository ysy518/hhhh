cat > ~/vmware_diagnose.sh << 'EOF'
#!/bin/bash
echo "=== VMware 虚拟机诊断 ==="
echo ""

echo "1. 系统信息："
echo "   - 发行版: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "   - 内核: $(uname -r)"
echo "   - 架构: $(uname -m)"
echo ""

echo "2. VMware 工具状态："
if systemctl is-active vmtoolsd > /dev/null 2>&1; then
    echo "   ✓ vmtoolsd 服务运行中"
else
    echo "   ✗ vmtoolsd 服务未运行"
fi

if [ -f /usr/bin/vmware-toolbox-cmd ]; then
    echo "   ✓ VMware 工具箱已安装"
else
    echo "   ✗ VMware 工具箱未安装"
fi
echo ""

echo "3. 显卡信息："
echo "   - PCI 设备:"
lspci | grep -i vmware
echo "   - 加载的驱动:"
lsmod | grep -i vmw
echo ""

echo "4. 显示服务器："
echo "   - X11 驱动:"
ls /usr/lib/xorg/modules/drivers/ 2>/dev/null | grep -i vmware
echo "   - Wayland 合成器:"
which Hyprland 2>/dev/null && echo "   ✓ Hyprland 已安装" || echo "   ✗ Hyprland 未安装"
echo ""

echo "5. 环境变量："
env | grep -E "WAYLAND|XDG|QT|GDK|WLR" | sort
echo ""

echo "6. Hyprland 配置："
if [ -f ~/.config/hypr/hyprland.conf ]; then
    echo "   ✓ 配置文件存在"
    echo "   - 文件大小: $(wc -l < ~/.config/hypr/hyprland.conf) 行"
    
    # 检查关键配置
    if grep -q "WLR_NO_HARDWARE_CURSORS" ~/.config/hypr/hyprland.conf; then
        echo "   ✓ 已配置 WLR_NO_HARDWARE_CURSORS"
    else
        echo "   ✗ 未配置 WLR_NO_HARDWARE_CURSORS"
    fi
else
    echo "   ✗ 配置文件不存在"
fi
echo ""

echo "7. 日志文件检查："
if [ -f ~/.cache/hypr/hyprland.log ]; then
    echo "   ✓ Hyprland 日志存在"
    echo "   - 最后错误:"
    tail -20 ~/.cache/hypr/hyprland.log | grep -i "error\|fail\|abort"
else
    echo "   ✗ Hyprland 日志不存在"
fi
echo ""

echo "8. 权限检查："
echo "   - 用户: $(whoami)"
echo "   - 用户ID: $(id -u)"
echo "   - 用户组: $(id -Gn)"
echo ""

echo "=== 诊断完成 ==="
EOF

chmod +x ~/vmware_diagnose.sh
