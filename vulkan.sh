#!/bin/bash
# check_vulkan_support.sh

echo "=== 检查 Vulkan 支持 ==="

# 1. 检查 Vulkan 驱动
echo "1. 检查安装的 Vulkan 包："
pacman -Q | grep -i vulkan

# 2. 安装必要的 Vulkan 驱动
echo "2. 安装 VMware Vulkan 驱动..."
sudo pacman -S --needed --noconfirm \
    vulkan-swrast \
    vulkan-icd-loader \
    vulkan-tools \
    vulkan-headers

# 3. 创建 Vulkan 配置
echo "3. 配置 Vulkan..."
mkdir -p ~/.config/vulkan
cat > ~/.config/vulkan/icd.d/vmware_icd.json << 'EOF'
{
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": "/usr/lib/libvulkan_lvp.so",
        "api_version": "1.2.0"
    }
}
EOF

# 4. 测试 Vulkan
echo "4. 测试 Vulkan 支持..."
if command -v vulkaninfo > /dev/null; then
    echo "运行 vulkaninfo 测试..."
    vulkaninfo --summary 2>&1 | head -50
else
    echo "vulkaninfo 未安装，安装中..."
    sudo pacman -S --noconfirm vulkan-tools
fi

# 5. 检查显卡信息
echo "5. 显卡信息："
lspci | grep -i vga
lspci | grep -i vmware

# 6. 检查当前使用的显卡驱动
echo "6. 检查显卡驱动："
ls -la /usr/lib/xorg/modules/drivers/ | grep -i vmware
ls -la /usr/share/X11/xorg.conf.d/ | grep -i vmware
