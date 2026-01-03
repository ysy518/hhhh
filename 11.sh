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
echo -e "\n"
