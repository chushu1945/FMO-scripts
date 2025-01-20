#!/bin/bash

# 检查是否具有 root 权限
if [ "$(id -u)" -ne 0 ]; then
  echo "请以 root 用户运行此脚本，或使用 sudo。" >&2
  exit 1
fi

#安装sudo
apt install sudo
 
# Caddy 配置文件路径
CADDY_CONFIG="/etc/caddy/Caddyfile"

# 检查 Caddy 是否已安装
check_caddy_installed() {
  if ! command -v caddy >/dev/null 2>&1; then
    echo "Caddy 未安装。"
    read -p "是否立即安装 Caddy？(y/n): " INSTALL_CHOICE
    if [[ "$INSTALL_CHOICE" == "y" || "$INSTALL_CHOICE" == "Y" ]]; then
      install_caddy
    else
      echo "退出脚本。"
      exit 0
    fi
  else
    echo "Caddy 已安装，继续操作。"
  fi
}

# 安装 Caddy 函数
install_caddy() {
  # ... (保持原有的安装逻辑不变)
}

# 主菜单函数
main_menu() {
  echo "请选择操作："
  echo "1) 添加完整配置（域名 + 重定向 + 反向代理）"
  echo "2) 添加端口代理配置（带域名）"
  echo "3) 删除现有配置"
  echo "q) 退出"
  read -p "请输入数字选择 (1, 2, 3) 或输入 'q' 退出: " CHOICE

  case "$CHOICE" in
    1)
      full_config
      ;;
    2)
      port_with_domain
      ;;
    3)
      delete_config
      ;;
    q)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效选择，请重新输入。"
      main_menu
      ;;
  esac
}

# 添加完整配置函数
full_config() {
  # ... (保持原有的逻辑不变)
}

# 添加端口代理配置（带域名）函数
port_with_domain() {
  # ... (保持原有的逻辑不变)
}

# 删除现有配置函数
delete_config() {
  # 显示当前配置中的域名列表
  echo "当前配置中的域名列表："
  grep -n "^[^#].*{" "$CADDY_CONFIG" | sed 's/:.*//'
  
  read -p "请输入要删除的配置行号 (输入 'q' 返回主菜单): " LINE_NUMBER

  if [[ "$LINE_NUMBER" == "q" ]]; then
    main_menu
    return
  fi

  if ! [[ "$LINE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "无效的行号，请输入数字。"
    delete_config
    return
  fi

  # 获取要删除的域名
  DOMAIN_TO_DELETE=$(sed -n "${LINE_NUMBER}p" "$CADDY_CONFIG" | awk '{print $1}')

  # 删除选中的配置块
  sed -i "${LINE_NUMBER}{:a;N;/^}/!ba};/^${DOMAIN_TO_DELETE}/d" "$CADDY_CONFIG"

  echo "已删除 ${DOMAIN_TO_DELETE} 的配置。"
  reload_caddy
}

# 重启 Caddy 服务函数
reload_caddy() {
  # 显示配置文件内容
  echo "新的 Caddy 配置文件内容："
  cat "$CADDY_CONFIG"

  # 重启 Caddy 服务以应用新配置
  echo "正在重启 Caddy 服务..."
  systemctl reload caddy

  # 检查服务状态
  if systemctl is-active --quiet caddy; then
    echo "Caddy 服务已成功重启！🎉"
  else
    echo "Caddy 服务重启失败，请检查配置。" >&2
  fi

  # 返回主菜单
  main_menu
}

# 检查并处理 Caddy 是否安装
check_caddy_installed

# 调用主菜单
main_menu
