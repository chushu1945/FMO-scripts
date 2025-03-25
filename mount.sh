#!/bin/bash

# 定义日志文件路径
LOG_FILE="/var/log/disk_mount.log"

# 记录日志的函数
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "错误: 此脚本需要root权限运行"
        log_message "脚本未以root权限运行"
        exit 1
    fi
}

# 显示当前挂载的硬盘信息
show_mounted_disks() {
    echo
    echo "当前已挂载的硬盘信息："
    echo "===================="
    echo "设备名称        挂载点        文件系统    总容量    已用空间    可用空间    使用率"
    echo "----------------------------------------------------------------------------"
    
    # 使用df命令获取已挂载设备信息，排除系统相关挂载点
    df -h | grep "^/dev/" | grep -v -E "tmp|loop|overlay|boot|/$" | \
    while read device total used avail use mountpoint; do
        printf "%-14s %-14s %-11s %-10s %-11s %-11s %-8s\n" \
            "$device" \
            "$mountpoint" \
            "$(lsblk -no FSTYPE $device | head -1)" \
            "$total" \
            "$used" \
            "$avail" \
            "$use"
    done
    echo "----------------------------------------------------------------------------"
    echo
}

# 列出所有硬盘及其分区
list_disks() {
    echo
    echo "系统中的所有硬盘和分区信息："
    echo "=========================="
    echo "设备路径        容量    类型    挂载点    文件系统    卷标"
    echo "---------------------------------------------------------"
    lsblk -o PATH,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL \
        --ascii \
        --exclude 7 | grep -v "^loop"
    echo "---------------------------------------------------------"
    
    log_message "列出了系统硬盘信息"
}

# 获取可用硬盘列表
get_available_disks() {
    local disks=($(lsblk -ln -o NAME,TYPE,MOUNTPOINT | 
                   awk '$2 == "part" && $3 == "" {print $1}' |
                   grep -v -E "^(sr[0-9]*|loop[0-9]+)$"))
    echo "${disks[@]}"
}

# 检查挂载点是否已存在或被使用
check_mount_point() {
    local mount_point=$1
    
    if mountpoint -q "$mount_point"; then
        echo "错误: $mount_point 已被挂载"
        return 1
    fi
    
    if [ -d "$mount_point" ] && [ "$(ls -A $mount_point)" ]; then
        echo "错误: $mount_point 目录不为空"
        return 1
    fi
    
    return 0
}

# 获取分区类型并尝试自动判断文件系统
get_filesystem_type() {
    local device=$1
    local fstype=$(lsblk -no FSTYPE "/dev/$device")
    
    if [ -z "$fstype" ]; then
        echo "警告: 无法自动检测文件系统类型"
        return 1
    fi
    echo "$fstype"
}

# 挂载设备
mount_disk() {
    local device=$1
    local mount_point=$2
    
    # 创建挂载点目录
    mkdir -p "$mount_point"
    
    # 获取文件系统类型
    local fstype=$(get_filesystem_type "$device")
    local mount_options=""
    
    # 根据文件系统类型设置挂载选项
    case $fstype in
        "ntfs")
            mount_options="-t ntfs-3g"
            ;;
        "exfat")
            mount_options="-t exfat"
            ;;
    esac
    
    # 尝试挂载
    if eval mount $mount_options "/dev/$device" "$mount_point"; then
        echo "成功: /dev/$device 已挂载到 $mount_point"
        echo "挂载信息："
        df -h "$mount_point"
        log_message "/dev/$device 成功挂载到 $mount_point"
        return 0
    else
        echo "错误: 无法挂载 /dev/$device 到 $mount_point"
        log_message "挂载失败: /dev/$device -> $mount_point"
        return 1
    fi
}

# 主菜单
show_menu() {
    echo
    echo "硬盘挂载工具"
    echo "============"
    echo "1. 列出所有硬盘"
    echo "2. 选择硬盘并挂载"
    echo "3. 退出"
    echo
    read -p "请选择操作 [1-3]: " choice
    echo
    
    case $choice in
        1)
            echo
            echo "请选择要显示的信息："
            echo "a. 列出所有硬盘"
            echo "b. 列出已挂载的硬盘"
            echo
            read -p "请选择 [a/b]: " list_choice
            case $list_choice in
                [aA])
                    list_disks
                    ;;
                [bB])
                    show_mounted_disks
                    ;;
                *)
                    echo "错误: 无效的选择"
                    ;;
            esac
            ;;
        2)
            # 获取可用硬盘列表
            available_disks=($(get_available_disks))
            
            if [ ${#available_disks[@]} -eq 0 ]; then
                echo "没有找到可用的硬盘或分区"
                return
            fi
            
            echo "可用的未挂载分区："
            echo "序号  设备名称     容量     文件系统    卷标"
            echo "-------------------------------------------"
            for i in "${!available_disks[@]}"; do
                local dev=${available_disks[$i]}
                printf "%3d.  %-12s %-8s %-10s %-15s\n" \
                    "$((i+1))" \
                    "/dev/$dev" \
                    "$(lsblk -no SIZE /dev/$dev)" \
                    "$(lsblk -no FSTYPE /dev/$dev)" \
                    "$(lsblk -no LABEL /dev/$dev)"
            done
            echo "-------------------------------------------"
            
            # 选择硬盘
            read -p "请选择要挂载的硬盘编号 [1-${#available_disks[@]}]: " disk_choice
            
            # 验证输入
            if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || \
               [ "$disk_choice" -lt 1 ] || \
               [ "$disk_choice" -gt "${#available_disks[@]}" ]; then
                echo "错误: 无效的选择"
                return
            fi
            
            selected_disk="${available_disks[$((disk_choice-1))]}"
            
            # 输入挂载点
            read -p "请输入挂载点目录 (例如: /mnt/mydisk): " mount_point
            
            # 验证挂载点
            if ! check_mount_point "$mount_point"; then
                return
            fi
            
            # 执行挂载
            mount_disk "$selected_disk" "$mount_point"
            ;;
        3)
            echo "退出程序"
            exit 0
            ;;
        *)
            echo "错误: 无效的选择"
            ;;
    esac
}

# 主程序
check_root

# 显示欢迎信息和系统信息
echo "欢迎使用硬盘挂载工具"
echo "=================="
echo "系统信息："
echo "操作系统: $(uname -o)"
echo "内核版本: $(uname -r)"
echo "主机名: $(hostname)"
echo "日期时间: $(date)"
echo

# 显示当前挂载状态
show_mounted_disks

while true; do
    show_menu
    echo
    read -p "按回车键继续..."
		done