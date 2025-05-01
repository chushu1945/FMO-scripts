#!/bin/bash

# 默认服务器名字
DEFAULT_HOSTNAME="taozi"

# 获取用户输入的服务器名字
read -p "请输入服务器名字 (默认为 ${DEFAULT_HOSTNAME}): " HOSTNAME

# 如果用户没有输入，则使用默认名字
if [ -z "$HOSTNAME" ]; then
  HOSTNAME="$DEFAULT_HOSTNAME"
fi

# 设置服务器名字
hostnamectl set-hostname "$HOSTNAME"

# 输出设置结果
echo "服务器名字已设置为: $HOSTNAME"

# 生成一个随机数
RANDOM_NUMBER=$((RANDOM % 254 + 1))  # 生成 1 到 254 之间的随机数
# 检查 /etc/hosts 文件中是否已存在 127.0.1.0 的解析
if grep -q "127\.0\.1\.0" /etc/hosts; then
  # 如果存在，则修改为 127.0.x.0，其中 x 是一个随机数
  NEW_IP="127.0.${RANDOM_NUMBER}.0"
  sudo sed -i "s/^127\.0\.1\.0.*$/${NEW_IP} $HOSTNAME/g" /etc/hosts
  echo "/etc/hosts 中已存在 127.0.1.0，已修改为 ${NEW_IP}"
else
  # 如果不存在，则添加 127.0.1.0 的解析
  echo "127.0.1.0 $HOSTNAME" | sudo tee -a /etc/hosts
fi

# 显示设置后的服务器名字
echo "服务器名字已设置为: $HOSTNAME"

# 显示 /etc/hosts 文件的内容
echo "更新后的 /etc/hosts 文件内容:"
cat /etc/hosts
