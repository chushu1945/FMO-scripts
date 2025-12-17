#!/bin/bash

set -e  # 遇到错误立即退出

# 颜色输出函数
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# 检测并安装必要工具：zsh, git, curl
install_required_tools() {
    local need_install=()
    if ! command -v zsh &> /dev/null; then
        need_install+=("zsh")
    fi
    if ! command -v git &> /dev/null; then
        need_install+=("git")
    fi
    if ! command -v curl &> /dev/null; then
        need_install+=("curl")
    fi

    if [ ${#need_install[@]} -eq 0 ]; then
        green "✅ zsh、git 和 curl 均已安装"
        return 0
    fi

    yellow "🔧 正在安装缺失的工具: ${need_install[*]}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian)
                sudo apt update
                sudo apt install -y "${need_install[@]}"
                ;;
            centos|rhel|almalinux|rocky)
                if command -v dnf &> /dev/null; then
                    sudo dnf install -y "${need_install[@]}"
                else
                    sudo yum install -y "${need_install[@]}"
                fi
                ;;
            fedora)
                sudo dnf install -y "${need_install[@]}"
                ;;
            arch|manjaro)
                sudo pacman -Sy --noconfirm "${need_install[@]}"
                ;;
            *)
                red "❌ 不支持的 Linux 发行版，请手动安装: ${need_install[*]}"
                exit 1
                ;;
        esac
    else
        red "❌ 无法识别操作系统，请确保已安装 zsh、git 和 curl"
        exit 1
    fi
}

# 执行工具安装
install_required_tools

# 安装 Oh My Zsh（非交互式）
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    yellow "📥 正在安装 Oh My Zsh..."
    sh -c "$(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    green "✅ Oh My Zsh 已存在，跳过安装"
fi

# 插件目录
PLUGINS_DIR="$HOME/.oh-my-zsh/custom/plugins"
mkdir -p "$PLUGINS_DIR"

# 安装插件
for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
    if [ ! -d "$PLUGINS_DIR/$plugin" ]; then
        yellow "📥 正在安装 $plugin..."
        git clone "https://gh-proxy.com/https://github.com/zsh-users/$plugin.git" "$PLUGINS_DIR/$plugin"
    else
        green "✅ $plugin 已安装"
    fi
done

# 配置 .zshrc
ZSHRC="$HOME/.zshrc"
if [ ! -f "$ZSHRC" ]; then
    cp "$HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$ZSHRC"
fi

# 设置插件
NEW_PLUGINS="plugins=(git zsh-syntax-highlighting zsh-autosuggestions)"
if grep -q "^plugins=(" "$ZSHRC"; then
    sed -i "s/^plugins=(.*)/$NEW_PLUGINS/" "$ZSHRC"
else
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

green "✅ .zshrc 配置完成！"

# === 关键：不要 source ~/.zshrc 在 bash 脚本中！===
# 否则 Oh My Zsh 会检测到非 zsh 环境并 exit，导致后续提示不显示

# === 仅提示用户 ===
echo ""
green "🎉 Zsh 环境配置成功！"
yellow "📌 注意："
echo "  - 默认 shell 未更改（仍为当前 shell，如 bash）"
echo "  - 若想临时使用 zsh，请运行："
echo ""
echo "      zsh"
echo ""
echo "  - 若要永久使用 zsh 作为默认 shell，请手动运行："
echo ""
echo "      chsh -s \$(which zsh)"
echo ""
yellow "💡 提示：重新打开终端后，若已运行 chsh，则会自动进入 zsh。"