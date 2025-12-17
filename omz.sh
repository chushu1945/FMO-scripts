#!/bin/bash

set -e  # 遇到错误立即退出

# 颜色输出函数
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# 检查是否安装 zsh
if ! command -v zsh &> /dev/null; then
    yellow "Zsh 未安装，正在安装..."

    # 检测发行版并安装 zsh
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt update && sudo apt install -y zsh git curl
                ;;
            centos|rhel|almalinux|rocky)
                sudo yum install -y zsh git curl
                ;;
            fedora)
                sudo dnf install -y zsh git curl
                ;;
            arch|manjaro)
                sudo pacman -Sy --noconfirm zsh git curl
                ;;
            *)
                red "不支持的 Linux 发行版，请手动安装 zsh、git 和 curl"
                exit 1
                ;;
        esac
    else
        red "无法识别操作系统，请确保已安装 zsh、git 和 curl"
        exit 1
    fi
else
    green "Zsh 已安装"
fi

# 确保 git 和 curl 已安装
for cmd in git curl; do
    if ! command -v "$cmd" &> /dev/null; then
        red "$cmd 未安装，但它是必需的。请先安装。"
        exit 1
    fi
done

# 安装 Oh My Zsh（非交互式，保留原有 .zshrc 如果存在）
yellow "正在安装 Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    green "Oh My Zsh 已存在，跳过安装"
fi

# 安装插件（如果尚未安装）
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"

# zsh-syntax-highlighting
if [ ! -d "$PLUGINS_DIR/zsh-syntax-highlighting" ]; then
    yellow "正在安装 zsh-syntax-highlighting..."
    git clone https://gh-proxy.com/https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGINS_DIR/zsh-syntax-highlighting"
else
    green "zsh-syntax-highlighting 已安装"
fi

# zsh-autosuggestions
if [ ! -d "$PLUGINS_DIR/zsh-autosuggestions" ]; then
    yellow "正在安装 zsh-autosuggestions..."
    git clone https://gh-proxy.com/https://github.com/zsh-users/zsh-autosuggestions.git "$PLUGINS_DIR/zsh-autosuggestions"
else
    green "zsh-autosuggestions 已安装"
fi

# 配置 .zshrc
ZSHRC="$HOME/.zshrc"

# 确保 .zshrc 存在（Oh My Zsh 安装后通常已有）
if [ ! -f "$ZSHRC" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
fi

# 定义目标插件行
NEW_PLUGINS="plugins=(git zsh-syntax-highlighting zsh-autosuggestions)"

# 替换 plugins 行（只替换以 plugins= 开头的行）
if grep -q "^plugins=(" "$ZSHRC"; then
    sed -i "s/^plugins=(.*)/$NEW_PLUGINS/" "$ZSHRC"
else
    # 如果没找到，追加（不太可能，但安全）
    echo "$NEW_PLUGINS" >> "$ZSHRC"
fi

# 定义别名
declare -a ALIASES=(
    "alias cls='clear'"
    "alias ll='ls -al'"
    "alias vi='vim'"
    "alias grep='grep --color=auto'"
    "alias dup='docker-compose up -d'"
    "alias ddown='docker-compose down'"
    "alias dre='docker-compose restart'"
    "alias sstart='systemctl start'"
    "alias srestart='systemctl restart'"
    "alias sstatus='systemctl status'"
    "alias sstop='systemctl stop'"
)

# 添加别名（避免重复）
for alias_line in "${ALIASES[@]}"; do
    alias_key=$(echo "$alias_line" | cut -d'=' -f1)
    if ! grep -q "^$alias_key=" "$ZSHRC"; then
        echo "$alias_line" >> "$ZSHRC"
    fi
done

green "配置 .zshrc 完成！"

# 加载新配置
source "$ZSHRC"

# 设置 zsh 为默认 shell（如果尚未设置）
CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
ZSH_PATH="$(which zsh)"
if [ "$CURRENT_SHELL" != "$ZSH_PATH" ]; then
    yellow "正在将默认 shell 设置为 zsh..."
    chsh -s "$ZSH_PATH"
    green "✅ 默认 shell 已设为 zsh。下次登录将自动使用。"
else
    green "默认 shell 已是 zsh"
fi

green "🎉 Zsh 环境配置完成！"
yellow "提示：当前会话已加载新配置。如需全新 zsh 会话，请运行 'exec zsh'。"