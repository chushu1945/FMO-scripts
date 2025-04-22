#!/bin/bash

# 定义 BBR 配置文件路径
SYSCTL_CONF="/etc/sysctl.conf"

# 函数：启用 BBR
enable_bbr() {
  # 检查是否已经启用
  if grep -q "net.ipv4.tcp_congestion_control=bbr" "$SYSCTL_CONF"; then
    echo "BBR 已经启用。"
    return
  fi

  # 添加 BBR 配置到 sysctl.conf
  echo "net.core.default_qdisc=fq" | sudo tee -a "$SYSCTL_CONF"
  echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a "$SYSCTL_CONF"

  # 应用 sysctl 设置
  sudo sysctl -p

  # 验证是否启用
  if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo "BBR 启用成功！"
  else
    echo "BBR 启用失败，请检查错误信息。"
  fi
}

# 函数：禁用 BBR
disable_bbr() {
  # 检查是否已经禁用
  if ! grep -q "net.ipv4.tcp_congestion_control=bbr" "$SYSCTL_CONF"; then
    echo "BBR 已经禁用。"
    return
  fi

  # 从 sysctl.conf 中移除 BBR 配置
  sudo sed -i '/net.core.default_qdisc=fq/d' "$SYSCTL_CONF"
  sudo sed -i '/net.ipv4.tcp_congestion_control=bbr/d' "$SYSCTL_CONF"

  # 应用 sysctl 设置
  sudo sysctl -p

  # 验证是否禁用
  if ! sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    echo "BBR 禁用成功！"
  else
    echo "BBR 禁用失败，请检查错误信息。"
  fi
}

# 主程序
while true; do
  echo " "
  echo "BBR 管理脚本"
  echo "------------------"
  echo "1. 启用 BBR"
  echo "2. 禁用 BBR"
  echo "3. 退出"
  echo "------------------"
  read -p "请选择一个选项 (1/2/3): " choice

  case "$choice" in
    1)
      enable_bbr
      ;;
    2)
      disable_bbr
      ;;
    3)
      echo "退出脚本。"
      exit 0
      ;;
    *)
      echo "无效的选项，请重新选择。"
      ;;
  esac
done
