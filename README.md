# snapper-rollback

基于snapper和btrfs-assistant的snapper快照回滚工具（不要回滚根目录快照！）

### 使用前请安装`snapper`和`btrfs-assistant`

##### 用法: 

/root/rollback.sh [--backup|-b] <snapper配置名称> <快照号>

##### 选项:

  --backup, -b  在回滚前创建备份快照

#### 注意事项：

1.此脚本适用于普通子卷的回滚，不要回滚根目录，出现问题概不承担！
</br>
2.回滚前会自动杀死使用该子卷的进程
</br>
3.回滚后自动删除btrfs-assistant创建的备份子卷
