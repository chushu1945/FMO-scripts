#!/bin/bash

# 设置在命令执行失败时立即退出
# 注意：为保证清理等操作即使在前面出错时也能执行，这里不使用 set -e
# 而是通过检查命令的返回值($?) 来控制流程和退出。

# --- 定义变量 ---
# frps 或 frpc 文件安装目录
INSTALL_BASE_DIR="/root/data/taozi/frp"
# systemd 服务文件路径模板
SYSTEMD_SERVICE_FILE_TEMPLATE="/etc/systemd/system/%s.service"
# 指定 FRP 版本号 (不再自动获取最新)
FRP_VERSION="0.62.1"
# 定义 GitHub 加速代理的前缀
GITHUB_PROXY_PREFIX="https://gh-proxy.com/" # 您可以替换成其他可用的GitHub代理地址

# 存储用户选择的类型和对应的文件名
INSTALL_TYPE=""     # "server" 或 "client"
FRP_EXEC=""         # "frps" 或 "frpc"
FRP_CONFIG=""       # "frps.toml" 或 "frpc.toml" (frp >= 0.50.0 使用 toml)
SYSTEMD_SERVICE_NAME="" # "frps" 或 "frpc"
SYSTEMD_SERVICE_FILE="" # "/etc/systemd/system/frps.service" 或 "/etc/systemd/system/frpc.service"
# 定义下载文件路径（位于安装目录）
DOWNLOAD_FILE_PATH=""

# 函数：执行初始清理，移除安装目录下可能残留的文件
initial_cleanup() {
  echo "正在进行初始清理..."
  # 确保安装目录存在，即使清理失败也不影响后面的创建
  mkdir -p "${INSTALL_BASE_DIR}"
  # 移除安装目录下旧的下载文件
  echo "正在移除安装目录下旧的下载文件 (*.tar.gz)..."
  rm -f "${INSTALL_BASE_DIR}/frp_*.tar.gz"
  # 移除安装目录下旧的解压目录
  echo "正在移除安装目录下旧的解压目录 (frp_*_linux_*)..."
  # 使用 find 配合 -delete 更安全，避免文件名中包含特殊字符的问题
  find "${INSTALL_BASE_DIR}" -maxdepth 1 -type d -name "frp_*_linux_*" -print -delete
  # find 命令返回非0可能只是因为没有找到匹配项，不是致命错误，所以不检查返回值
  # if [ $? -ne 0 ]; then echo "警告：清理安装目录下旧的解压目录可能失败。"; fi

  echo "初始清理完成。"
}

# 根据系统架构判断下载文件名称
ARCH=$(uname -m)
case ${ARCH} in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="arm"
        ;;
    *)
        echo "警告：不支持的架构：${ARCH}"
        echo "下载 URL 将尝试使用 amd64 架构，但这可能不兼容您的系统。" # 给出更明确的警告
        ARCH="amd64"
        ;;
esac


# --- 函数定义 ---

# 函数：检查是否以 root 用户运行
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "此脚本必须以 root 用户运行"
    exit 1
  fi
}

# 函数：选择安装类型
choose_install_type() {
  echo "请选择要安装的组件："
  echo "1) frps (服务端)"
  echo "2) frpc (客户端)"

  while true; do
    read -p "请输入选择 (1 或 2): " choice
    case "$choice" in
      1)
        INSTALL_TYPE="server"
        FRP_EXEC="frps"
        FRP_CONFIG="frps.toml" # 假定使用较新版本，配置文件为 .toml
        SYSTEMD_SERVICE_NAME="frps"
        break
        ;;
      2)
        INSTALL_TYPE="client"
        FRP_EXEC="frpc"
        FRP_CONFIG="frpc.toml" # 假定使用较新版本，配置文件为 .toml
        SYSTEMD_SERVICE_NAME="frpc"
        break
        ;;
      *)
        echo "无效选择。请输入 1 或 2。"
        ;;
    esac
  done
  printf -v SYSTEMD_SERVICE_FILE "$SYSTEMD_SERVICE_FILE_TEMPLATE" "$SYSTEMD_SERVICE_NAME"
  echo "您选择安装：${INSTALL_TYPE} (${FRP_EXEC})"
}

# 函数：生成随机token
generate_random_token() {
  head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16
}

# 函数：根据选择生成配置文件
generate_config_file() {
  echo "正在生成 ${FRP_CONFIG} 配置文件..."
  CONFIG_PATH="${INSTALL_BASE_DIR}/${FRP_CONFIG}"

  # 检查配置文件是否已存在，如果存在则备份
  if [ -f "$CONFIG_PATH" ]; then
      echo "警告：检测到现有配置文件 ${CONFIG_PATH}，正在备份到 ${CONFIG_PATH}.bak"
      mv "$CONFIG_PATH" "${CONFIG_PATH}.bak" || echo "警告：备份配置文件失败。"
  fi

  if [[ "$INSTALL_TYPE" == "server" ]]; then
    # frps configuration
    read -p "请输入 frps 监听端口 [7000]: " BIND_PORT
    BIND_PORT=${BIND_PORT:-7000}
    # 检查端口是否为数字
    if ! [[ "$BIND_PORT" =~ ^[0-9]+$ ]]; then
        echo "错误：监听端口必须是数字。"
        exit 1
    fi


    TOKEN=""
    while true; do
        read -p "生成随机认证 token (y/n)? [y]: " gen_token_choice
        gen_token_choice=$(echo "$gen_token_choice" | tr '[:upper:]' '[:lower:]')
        case "$gen_token_choice" in
            ""|y)
                TOKEN=$(generate_random_token)
                echo "生成的 token: ${TOKEN}"
                break
                ;;
            n)
                read -p "请输入认证 token: " TOKEN
                 if [ -z "$TOKEN" ]; then
                     echo "错误：Token 不能为空。"
                     # 不退出，让用户重新输入
                 else
                     break
                 fi
                ;;
            *)
                echo "无效输入。请输入 y 或 n。"
                ;;
        esac
    done


    cat <<EOF > "$CONFIG_PATH"
bindPort = ${BIND_PORT}
auth.token = "${TOKEN}"

# 可选：仪表板监听端口，默认为 7500
# dashboard.port = 7500
# dashboard.user = "admin"
# dashboard.password = "admin"

# 可选：启用控制台日志
# log.to = "console"
EOF
    # 检查文件是否成功创建
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "错误：配置文件 ${CONFIG_PATH} 创建失败。"
        exit 1
    fi
    echo "frps 配置已写入到 ${CONFIG_PATH}"
    echo "----------------------------------------"
    echo "您的认证 token 是: ${TOKEN}"
    echo "请妥善保管此 token，并在配置 frpc 时使用它。"
    echo "----------------------------------------"

  elif [[ "$INSTALL_TYPE" == "client" ]]; then
    # frpc configuration
    read -p "请输入 frps 服务器地址 (IP 或 域名): " SERVER_ADDR
    # 检查输入是否为空
    if [ -z "$SERVER_ADDR" ]; then
        echo "错误：服务器地址不能为空。"
        exit 1
    fi

    read -p "请输入 frps 服务器端口: " SERVER_PORT
     # 检查输入是否为数字且非空
    if ! [[ "$SERVER_PORT" =~ ^[0-9]+$ ]]; then
        echo "错误：服务器端口必须是数字且不能为空。"
        exit 1
    fi

    read -p "请输入认证 token (必须与 frps token 一致): " CLIENT_TOKEN
    # 检查输入是否为空
    if [ -z "$CLIENT_TOKEN" ]; then
        echo "错误：认证 token 不能为空。"
        exit 1
    fi


    # Ask about adding a sample proxy
    ADD_PROXY="n" # 默认为不添加
    read -p "现在添加一个示例 TCP 代理配置吗? (y/n) [n]: " ADD_PROXY
    ADD_PROXY=$(echo "$ADD_PROXY" | tr '[:upper:]' '[:lower:]')

    cat <<EOF > "$CONFIG_PATH"
serverAddr = "${SERVER_ADDR}"
serverPort = ${SERVER_PORT}
auth.token = "${CLIENT_TOKEN}"

EOF

    if [[ "$ADD_PROXY" == "y" ]]; then
        read -p "请输入代理名称 (例如：web, ssh): " PROXY_NAME
         if [ -z "$PROXY_NAME" ]; then
            echo "错误：代理名称不能为空。"
            exit 1
        fi
        read -p "请输入要转发的本地 IP [127.0.0.1]: " LOCAL_IP
        LOCAL_IP=${LOCAL_IP:-127.0.0.1}

        read -p "请输入要转发的本地端口: " LOCAL_PORT
        if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]]; then
            echo "错误：本地端口必须是数字且不能为空。"
            exit 1
        fi

        read -p "请输入 frps 服务器上的远程端口: " REMOTE_PORT
         if ! [[ "$REMOTE_PORT" =~ ^[0-9]+$ ]]; then
            echo "错误：远程端口必须是数字且不能为空。"
            exit 1
        fi


        cat <<EOF >> "$CONFIG_PATH"

[[proxies]]
name = "${PROXY_NAME}"
type = "tcp"
localIP = "${LOCAL_IP}"
localPort = ${LOCAL_PORT}
remotePort = ${REMOTE_PORT}

# 在下方添加更多代理配置，格式相同
# [[proxies]]
# name = "另一个服务"
# type = "udp"
# localIP = "127.0.0.1"
# localPort = 53
# remotePort = 5353
EOF
        echo "已添加示例 TCP 代理配置。"
    else
        echo "# 在下方添加您的代理配置" >> "$CONFIG_PATH"
        echo "# 示例:" >> "$CONFIG_PATH"
        echo "# [[proxies]]" >> "$CONFIG_PATH"
        echo "# name = \"ssh\"" >> "$CONFIG_PATH"
        echo "# type = \"tcp\"" >> "$CONFIG_PATH"
        echo "# localIP = \"127.0.0.1\"" >> "$CONFIG_PATH"
        echo "# localPort = 22" >> "$CONFIG_PATH"
        echo "# remotePort = 6000" >> "$CONFIG_PATH"
    fi
    # 检查文件是否成功创建
    if [ ! -f "$CONFIG_PATH" ]; then
        echo "错误：配置文件 ${CONFIG_PATH} 创建失败。"
        exit 1
    fi
    echo "frpc 配置已写入到 ${CONFIG_PATH}"
    echo "您可能需要编辑 ${CONFIG_PATH} 文件来添加更多代理。"
  fi
}


# 函数：下载并解压 frp 包到安装目录
# 成功时返回 0，失败时返回非零状态码并打印错误
# 这个函数现在也负责确保安装目录存在
download_and_extract_to_install_dir() {
  local download_file="$1" # 接收下载文件路径 (在安装目录内)
  local install_dir="$2" # 接收安装目录

  # 确保安装目录存在
  mkdir -p "$install_dir" || { echo "错误：无法创建安装目录 ${install_dir}"; return 1; }

  # 构建原始的 GitHub 下载 URL
  ORIGINAL_DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz"
  # 添加加速前缀
  DOWNLOAD_URL="${GITHUB_PROXY_PREFIX}${ORIGINAL_DOWNLOAD_URL}"

  echo "正在尝试使用加速链接下载适用于 ${ARCH} 架构的 FRP 版本 ${FRP_VERSION}..."
  echo "下载 URL: ${DOWNLOAD_URL}"
  echo "下载文件到: ${download_file}" # 告知用户下载位置


  # 使用 wget 下载，检查返回值
  if ! wget -O "$download_file" "$DOWNLOAD_URL"; then
    echo "错误：从 $DOWNLOAD_URL 下载 FRP 失败。"
    echo "请仔细检查 FRP 版本、架构组合或代理 URL 是否有效，或者网络连接是否存在问题。"
    return 1 # 指示下载失败
  fi
  echo "下载完成。"

  echo "正在解压 FRP 包到安装目录：${install_dir}..." # 告知用户解压位置
  # 使用 tar 解压到安装目录，检查返回值
  if ! tar -xzf "$download_file" -C "$install_dir"; then
    echo "错误：解压 FRP 包失败。"
    echo "下载的文件可能已损坏，请检查网络并重试。"
    return 1 # 指示解压失败
  fi
  echo "解压完成。"

  return 0 # 指示下载和解压成功
}

# 函数：移动解压后的文件到安装目录根部并设置权限
# 在安装目录中查找解压产生的子目录，并将必要文件移出
move_files_from_subdir() {
  local install_dir="$1" # 接收安装目录

  echo "正在查找解压产生的子目录并移动文件..."

  # 在安装目录中查找解压后的单层子目录
  # 假设解压后会产生一个类似 frp_0.xx.x_linux_amd64 的目录
  local expected_sub_dir_name="frp_${FRP_VERSION}_linux_${ARCH}"
  local extracted_sub_dir="${install_dir}/${expected_sub_dir_name}"

  # 检查预期的子目录是否存在
  if [ ! -d "$extracted_sub_dir" ]; then
      echo "错误：在安装目录 ${install_dir} 中找不到预期的解压子目录 (${expected_sub_dir_name})。"
      echo "tar 解压可能失败，或者解压后的目录结构不是预期的。"
      return 1 # 指示找不到解压内容
  fi
  echo "找到解压子目录：${extracted_sub_dir}"

  # 检查源文件是否存在于子目录中
  if [ ! -f "$extracted_sub_dir/$FRP_EXEC" ]; then
      echo "错误：在子目录中找不到 ${FRP_EXEC} 可执行文件：$extracted_sub_dir/$FRP_EXEC"
      return 1 # 可执行文件缺失是致命错误
  else
      # 移动可执行文件到安装目录根部
      echo "正在移动 ${FRP_EXEC} 到 ${install_dir}/..."
      mv "$extracted_sub_dir/$FRP_EXEC" "$install_dir/" || { echo "错误：移动 ${FRP_EXEC} 失败。"; return 1; }
  fi

  # 检查源文件是否存在于子目录中 (配置文件骨架)
  # 配置文件骨架不是必需的，如果不存在，只打印警告并跳过移动。
  if [ ! -f "$extracted_sub_dir/$FRP_CONFIG" ]; then
      echo "警告：在子目录中找不到 ${FRP_CONFIG} 骨架文件：$extracted_sub_dir/$FRP_CONFIG。将跳过移动该文件。"
  else
      # 移动配置文件骨架到安装目录根部
      echo "正在移动 ${FRP_CONFIG} 到 ${install_dir}/..."
      mv "$extracted_sub_dir/$FRP_CONFIG" "$install_dir/" || { echo "警告：移动 ${FRP_CONFIG} 失败。"; } # 移动失败也不致命
  fi

  # 移除解压产生的子目录及其内容
  echo "正在移除解压产生的子目录: ${extracted_sub_dir}"
  # 使用 -rf 避免目录不存在时的错误，且强制删除
  rm -rf "$extracted_sub_dir" || { echo "警告：移除解压子目录失败。"; }


  echo "正在为 ${FRP_EXEC} 可执行文件设置权限..."
  chmod +x "$install_dir/$FRP_EXEC" || { echo "警告：设置 ${FRP_EXEC} 可执行权限失败。"; }

  return 0 # 指示移动和清理子目录成功
}


# 函数：创建 systemd 服务文件
create_service_file() {
  echo "正在创建 systemd 服务文件：$SYSTEMD_SERVICE_FILE"
  # 检查服务文件是否已存在，如果存在则备份
  if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
      echo "警告：检测到现有 systemd 服务文件 ${SYSTEMD_SERVICE_FILE}，正在备份到 ${SYSTEMD_SERVICE_FILE}.bak"
      mv "$SYSTEMD_SERVICE_FILE" "${SYSTEMD_SERVICE_FILE}.bak" || echo "警告：备份服务文件失败。"
  fi


  cat <<EOF > "$SYSTEMD_SERVICE_FILE"
[Unit]
Description=frp ${INSTALL_TYPE}
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_BASE_DIR}/${FRP_EXEC} -c ${INSTALL_BASE_DIR}/${FRP_CONFIG}
WorkingDirectory=${INSTALL_BASE_DIR}
Restart=on-failure
RestartSec=10
# 建议创建一个非root用户运行服务，增加安全性
# 用户和组需要先创建
# User=frp
# Group=frp
CapabilityBoundingSet=CAP_NET_BIND_SERVICE # 允许非root用户绑定1024以下端口 (frpc可能需要)
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
  # 检查文件是否成功创建
  if [ ! -f "$SYSTEMD_SERVICE_FILE" ]; then
    echo "错误：systemd 服务文件 ${SYSTEMD_SERVICE_FILE} 创建失败。"
    exit 1
  fi
  echo "Systemd 服务文件已创建。"
}

# 函数：安装并启动服务
install_and_start_service() {
  echo "正在安装并启动 ${SYSTEMD_SERVICE_NAME} 服务..."

  # 关键步骤：重新加载 systemd daemon，使新创建的服务文件生效
  echo "正在重新加载 systemd daemon..."
  if ! systemctl daemon-reload; then
      echo "错误：重新加载 systemd daemon 失败。"
      echo "请尝试手动运行 'systemctl daemon-reload' 并检查错误。"
      exit 1 # 无法重新加载daemon通常意味着服务无法启动
  fi
  echo "Systemd daemon 重载成功。"

  # 启用服务，设置开机自启动
  echo "正在启用 ${SYSTEMD_SERVICE_NAME} 服务..."
  # 注意：enable失败不影响start，仅影响开机自启，不退出脚本
  systemctl enable "$SYSTEMD_SERVICE_NAME" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "警告：启用 ${SYSTEMD_SERVICE_NAME} 服务失败。"
      echo "您可能需要稍后手动运行 'systemctl enable ${SYSTEMD_SERVICE_NAME}' 来设置开机自启。"
  else
      echo "${SYSTEMD_SERVICE_NAME} 服务已设置为开机自启。"
  fi


  # 启动服务
  echo "正在启动 ${SYSTEMD_SERVICE_NAME} 服务..."
  if ! systemctl start "$SYSTEMD_SERVICE_NAME"; then
      echo "错误：启动 ${SYSTEMD_SERVICE_NAME} 服务失败。"
      echo "请使用以下命令检查日志：journalctl -u ${SYSTEMD_SERVICE_NAME}.service -f"
      exit 1 # 启动失败是严重问题，退出脚本
  fi
  echo "${SYSTEMD_SERVICE_NAME} 服务已启动。"

  # 检查服务状态
  echo "正在检查 ${SYSTEMD_SERVICE_NAME} 服务状态..."
  systemctl status "$SYSTEMD_SERVICE_NAME"
}

# --- 主执行流程 ---

# 在脚本开始时执行初始清理
initial_cleanup

check_root # 检查是否为root用户
choose_install_type # 选择安装类型并设置相关变量
# get_latest_version # <-- 移除获取最新版本的功能，版本已在变量中指定

echo "指定的 FRP 版本: ${FRP_VERSION}" # 打印指定的版本

# --- 设置下载文件路径 ---
# 下载文件将放在安装目录下
DOWNLOAD_FILE_PATH="${INSTALL_BASE_DIR}/frp_${FRP_VERSION}_linux_${ARCH}.tar.gz"

# --- 下载并解压到安装目录 ---
# 调用下载解压函数，直接将内容解压到安装目录
# 这个函数内部会确保安装目录存在
if ! download_and_extract_to_install_dir "$DOWNLOAD_FILE_PATH" "$INSTALL_BASE_DIR"; then
    # 函数内部已经打印了错误消息
    echo "安装中止：下载或解压过程失败。"
    # 下载失败时，下载文件可能不完整或不存在，不需要额外清理
    exit 1
fi

# --- 移动文件到安装目录根部并设置权限 ---
# 这个函数负责在安装目录中找到解压的子目录，移动文件，并清理子目录
if ! move_files_from_subdir "$INSTALL_BASE_DIR"; then
    # 函数内部已经打印了错误消息
    echo "安装中止：移动文件或清理失败。"
    # 如果移动失败，说明安装目录内容可能有问题，不进行后续操作
    exit 1
fi

# --- 清理下载的压缩包 ---
# 在文件移动成功之后，清理下载的压缩包
echo "正在移除下载文件: ${DOWNLOAD_FILE_PATH}"
rm -f "${DOWNLOAD_FILE_PATH}" # 使用 -f 忽略文件不存在时的错误

# --- 生成配置、创建服务文件 ---
generate_config_file # 生成配置文件内容
create_service_file # 创建systemd服务文件

# --- 安装和启动服务 ---
install_and_start_service # 安装并启动服务

echo "FRP ${INSTALL_TYPE} 安装和设置完成！"
echo "安装的 FRP 版本: ${FRP_VERSION}"
echo "配置文件位于: ${INSTALL_BASE_DIR}/${FRP_CONFIG}"
echo "服务文件位于: ${SYSTEMD_SERVICE_FILE}"
echo "您可以使用以下命令检查服务状态: systemctl status ${SYSTEMD_SERVICE_NAME}"
echo "您可以使用以下命令查看服务日志: journalctl -u ${SYSTEMD_SERVICE_NAME}.service -f"

exit 0 # 脚本成功完成
