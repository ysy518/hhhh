# Check display manager
echo -e "${PINK}\n---------------------------------------------------------------------\n${YELLOW}[11/11]${PINK} ==> Check display manager\n---------------------------------------------------------------------\n${WHITE}"
if [[ ! -e /etc/systemd/system/display-manager.service ]]; then
    # 安装 SDDM
    sudo pacman -S --noconfirm sddm sddm-themes
    
    # 启用 SDDM
    sudo systemctl enable sddm
    
    # 配置 SDDM 主题
    if [ -f /etc/sddm.conf ]; then
        sudo sed -i 's/^Current=.*/Current=sddm-astronaut-theme/' /etc/sddm.conf
    else
        echo -e "[Theme]\nCurrent=sddm-astronaut-theme" | sudo tee /etc/sddm.conf
    fi
    
    # 修改主题配置（如果主题存在）
    if [ -f /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop ]; then
        sudo sed -i 's|astronaut.conf|purple_leaves.conf|' /usr/share/sddm/themes/sddm-astronaut-theme/metadata.desktop
    fi
    
    echo -e "\n${PINK}SDDM has been enabled."
else
    echo -e "${BLUE}[INFO]${WHITE} Display manager already exists, skipping SDDM setup.\n"
fi
