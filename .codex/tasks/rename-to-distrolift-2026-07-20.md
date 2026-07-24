# DistroLift 统一命名任务

- [x] 盘点项目展示名、仓库 URL、Git 远程和本地目录名
- [x] 备份将修改的版本化文件
- [x] 将当前项目展示名统一为 `DistroLift`
- [x] 将仓库 URL 和内部运行标识切换到 `DistroLift` / `distrolift`
- [x] 将 GitHub 仓库重命名为 `everett7623/DistroLift`
- [x] 将生产脚本生成的备份目录和禁用源标记统一为 `distrolift`
- [x] 更新本地 `origin` 并通过 Bash 语法检查与完整 smoke 测试
- [x] 将本地项目目录重命名为 `DistroLift`

## 边界

- 保留生产入口 `distro_upgrade.sh` 和兼容包装器 `debian_upgrade.sh`，避免破坏下载、自更新与既有调用。
- 保留 `scripts/` 中的历史脚本，不把历史入口误改为当前生产入口。
- 保留工作区现有未提交的 v3.8.0 安全改动，只叠加命名变更。
