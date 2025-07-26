#!/bin/bash

# 检查参数数量
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "用法: $0 [--backup|-b] <配置名称> <快照号>"
    echo "选项:"
    echo "  --backup, -b  在回滚前创建备份快照"
    exit 1
fi

# 解析参数
BACKUP_FLAG=false
if [ "$1" == "--backup" ] || [ "$1" == "-b" ]; then
    BACKUP_FLAG=true
    CONFIG_NAME="$2"
    SNAPSHOT_NUM="$3"
else
    CONFIG_NAME="$1"
    SNAPSHOT_NUM="$2"
fi

# 获取配置的子卷路径
SUBVOLUME=$(snapper list-configs | awk -v config="$CONFIG_NAME" '$1 == config {print $3}')

if [ -z "$SUBVOLUME" ]; then
    echo "错误: 找不到配置 '$CONFIG_NAME' 的子卷路径"
    exit 1
fi

# 从子卷路径中提取目录名（最后一个路径组件）
SUBVOLUME_DIR=$(basename "$SUBVOLUME")

echo "准备回滚配置: $CONFIG_NAME"
echo "子卷路径: $SUBVOLUME"
echo "子卷目录名: $SUBVOLUME_DIR"
echo "回滚到快照: $SNAPSHOT_NUM"

# 查找对应的btrfs-assistant快照ID
BA_SNAPSHOT_ID=$(btrfs-assistant -l | grep "${SUBVOLUME_DIR}/.snapshots/${SNAPSHOT_NUM}/snapshot" | awk '{print $1}')

if [ -z "$BA_SNAPSHOT_ID" ]; then
    echo "错误: 找不到配置 '$CONFIG_NAME' 的快照 $SNAPSHOT_NUM 对应的 btrfs-assistant ID"
    exit 1
fi

echo "找到对应的 btrfs-assistant 快照 ID: $BA_SNAPSHOT_ID"

# 如果需要，创建回滚前的备份快照
if [ "$BACKUP_FLAG" = true ]; then
    echo "正在创建回滚前的备份快照..."
    BACKUP_DESCRIPTION="回滚${SNAPSHOT_NUM}快照前的备份"
    snapper -c "$CONFIG_NAME" create -c timeline -d "$BACKUP_DESCRIPTION"

    if [ $? -eq 0 ]; then
        echo "备份快照创建成功"
    else
        echo "备份快照创建失败"
        exit 1
    fi
else
    echo "跳过创建备份快照（未指定--backup/-b选项）"
fi

# 杀死使用该子卷的所有进程
echo "正在终止使用 $SUBVOLUME 的进程..."
PIDS=$(fuser -vm "$SUBVOLUME" 2>&1 | grep -oP '(?<= )[0-9]+(?= )' | tr '\n' ',' | sed 's/,$//')
if [ -n "$PIDS" ]; then
    echo "终止进程 PID: $PIDS"
    fuser -kvm "$SUBVOLUME" >/dev/null 2>&1
else
    echo "没有找到需要终止的进程"
fi

# 执行回滚操作
echo "正在执行回滚操作..."
btrfs-assistant -r "$BA_SNAPSHOT_ID" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "回滚成功完成"
else
    echo "回滚过程中出现错误"
    exit 1
fi

# 删除btrfs-assistant创建的备份子卷
find "$(dirname "$SUBVOLUME")" -maxdepth 1 -type d -name "$(basename "$SUBVOLUME")_backup_*" 2>/dev/null | while read -r backup_path; do
    btrfs subvolume delete "$backup_path" >/dev/null 2>&1
done
echo "清理完成！"
