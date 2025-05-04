#!/bin/bash

# 定义 Hugging Face 服务 URL 数组
urls=(
  "https://taozi1945-gegemini.hf.space"
)

# 定义日志文件夹和文件名
log_dir="/root/data/taozi"
log_file="$log_dir/keep.log"

# 检查日志文件夹是否存在，如果不存在则创建
if [ ! -d "$log_dir" ]; then
  mkdir -p "$log_dir"
fi

# 获取当前日期和时间
timestamp=$(date +%Y-%m-%d_%H-%M-%S)

# 循环遍历 URL 数组
for url in "${urls[@]}"; do
  echo "[${timestamp}] 正在 ping: $url"

  # 使用 curl 发送 GET 请求，并记录状态码
  curl -s -o /dev/null -w "%{http_code}" "$url" > /dev/null 2>&1
  http_code=$?

  # 获取当前日期和时间，用于日志记录
  timestamp=$(date +%Y-%m-%d_%H-%M-%S)

  # 记录日志
  if [ "$http_code" -eq 0 ]; then
    echo "[${timestamp}] 成功 ping: $url (HTTP Status: $http_code)" >> "$log_file"
  else
    echo "[${timestamp}] ping 失败: $url (HTTP Status: $http_code)" >> "$log_file"
  fi

  # 可以选择添加睡眠时间，避免过于频繁的请求
  # sleep 1
done

# 获取当前日期和时间，用于日志记录
timestamp=$(date +%Y-%m-%d_%H-%M-%S)
echo "[${timestamp}] 所有服务已 ping 完成。" >> "$log_file"

exit 0
