# Requirements and Progress Snapshot

## Introduction

本规格记录 DistroLift Auto Upgrade 当前已完成的脚本审计、运行统计、Ubuntu LTS 支持、v3.7 自动化 / VPS 成功率优化，以及 v3.7.1 启动风险确认。旧入口 `debian_upgrade.sh` 仅作为兼容转发入口存在，生产逻辑以 `distro_upgrade.sh` 为唯一来源。

当前进度：已完成并推送到 `main`。

## Current Scope

- Debian 主路径：11 -> 12 -> 13；13 -> 14 仅通过 `--allow-testing` 开启。
- Ubuntu LTS 主路径：20.04 (`focal`) -> 22.04 (`jammy`) -> 24.04 (`noble`) -> 26.04 (`resolute`)。
- 稳定版相邻升级默认自动继续；`--require-confirm` 可恢复人工确认。
- 真实升级前显示启动风险确认页，集中提示快照、业务备份、控制台访问和失败风险。
- 升级成功后默认不自动重启；`--auto-reboot` 为显式 opt-in。
- 小内存 / NAT VPS 在切换软件源前完成资源门槛检查；合理低内存场景自动创建临时 Swap，退出时清理。
- Debian 与 Ubuntu 共用锁等待、运行时注入检查、initramfs 预检、APT 恢复、升级后修复和安全边界。

## Implemented Requirements

### Bugfix Requirements

1. `cleanup_mode()` 磁盘百分比展示使用 `df` 的原生 Use% 字段，避免对 `df -h` 单位字符串做算术。
2. `main_upgrade()` 不使用 `fi` 作为变量名，避免 bash 关键字冲突。
3. `error_recovery()` 入口禁用 ERR trap，避免 `set -Ee` 下 trap 递归。
4. `check_upgrade()` 在引导磁盘为空时显示 `未检测到`。
5. `get_efi_dir()` 优先选择路径包含 `efi` 的 vfat 挂载点，并保留 fallback。
6. `self_update_mode()` 在写入前检查脚本文件权限。
7. Ubuntu arm64 / ports 架构使用 `ubuntu-ports`，不再写入 amd64 的 archive/security 源。
8. Ubuntu 26.04 LTS 代号修正为 `resolute`。

### Feature Requirements

1. README 显示 visitor badge，脚本可非阻塞获取运行统计。
2. `--check` 支持 Debian / Ubuntu 分流并显示对应升级状态。
3. Ubuntu LTS 相邻升级支持完整接入主脚本。
4. `apt_update_with_recovery()` 统一处理 GPG / keyring / 404 / Release 文件错误。
5. `check_upgrade_capacity()` 在切源前判断物理内存、Swap、根分区和 `/boot`。
6. `prepare_temporary_swap()` 为合理低内存 VPS 创建临时 Swap，`cleanup()` 负责关闭并删除。
7. `--require-confirm` 和 `--auto-reboot` 明确区分自动化升级与重启风险。
8. 项目展示名更新为 DistroLift Auto Upgrade，AI 工具文档同步当前开发进度。

## Preservation Requirements

- 不删除 APT/dpkg 锁文件，只等待锁释放。
- 常规升级不写 MBR、不自动 `grub-install`。
- 不自动修改网卡名或重启网络服务。
- 升级后不自动 `autoremove`。
- 第三方源只备份并禁用，升级后不自动恢复。
- 最小升级失败后不继续完整升级。
- 完整升级失败后不重复执行整套升级流程。
- Debian 与 Ubuntu 都必须是相邻版本升级，不做跨代跳级。
- 测试版路径必须显式开启并保留强确认。

## Validation Requirements

必须通过：

```bash
make check
```

在缺少 `make` 或 `shellcheck` 的 Windows Git Bash 环境中，至少执行：

```bash
bash -n distro_upgrade.sh
for file in scripts/*.sh tests/*.sh; do bash -n "$file"; done
bash tests/smoke.sh
git diff --check
```

完整发布前还需要隔离 VM 快照测试：

- Debian 11 -> 12、12 -> 13。
- Ubuntu 20.04 -> 22.04、22.04 -> 24.04、24.04 -> 26.04。
- BIOS / UEFI。
- 官方源和至少一个镜像源。
- Ubuntu non-amd64 / ports 源。
- 低内存可升级场景和过低 NAT VPS 拒绝场景。

## Documentation Sync

以下文件必须保持同一事实源：

- `AGENTS.md`
- `CLAUDE.md`
- `README.md`
- `CHANGELOG.md`
- `docs/DEVELOPMENT.md`
- `docs/SAFETY.md`
- `.kiro/specs/script-audit-and-hits-counter/*.md`
