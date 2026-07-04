# Development Guide

## 环境

推荐在 Debian 12 / 13 或 Ubuntu LTS 虚拟机中开发：

```bash
sudo apt-get install bash shellcheck make git
make check
```

Windows 可使用 Git Bash 进行语法检查，但完整行为测试必须在隔离的 Debian / Ubuntu 虚拟机中完成。

## 项目结构

- `distro_upgrade.sh`：当前支持的统一入口。
- `scripts/`：历史分版本脚本，仅供参考。
- `tests/smoke.sh`：无特权冒烟测试。
- `docs/SAFETY.md`：高风险操作约束。

## 测试层级

1. `bash -n`：全部脚本语法检查。
2. `shellcheck`：静态分析。
3. `tests/smoke.sh`：帮助、版本映射和默认策略。
4. 虚拟机快照测试：APT 源切换、失败恢复、重启和服务验证。

不要在开发机或唯一生产实例上测试发行版升级。

## 版本开发流程

每制作一个版本前，先把会修改的文件备份到本地目录，例如：

```bash
backup_dir=".codex-backups/v3.7-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
cp distro_upgrade.sh README.md CHANGELOG.md docs/*.md tests/smoke.sh "$backup_dir"/
```

备份只用于本地回滚，不作为发布产物。开发时优先完善 Debian 与 Ubuntu LTS 两条主路径；其他发行版不要混入同一版本，后续按单独设计、单独测试扩展。

## 升级方案优化原则

- 稳定版相邻升级默认自动继续，减少无人值守场景的交互阻塞。
- Debian testing 或其他高风险路径必须显式启用并保留强确认。
- 所有高风险检查必须发生在切换 `/etc/apt/sources.list` 之前。
- 小内存 / NAT VPS 先判断是否合理升级；过低内存、磁盘不足或 `/boot` 不足时直接停止。
- 低内存但仍合理的 VPS 可以自动创建临时 Swap，并在脚本退出时清理。
- Debian 与 Ubuntu 的锁等待、keyring、APT 恢复、initramfs、GRUB 刷新和网络核对逻辑应尽量共享，避免双路径漂移。

## 发布前检查

- 更新 `SCRIPT_VERSION`、`SCRIPT_DATE` 和 `CHANGELOG.md`。
- 核对 README 中的支持矩阵。
- 同步 AI 工具文档：`AGENTS.md`、`CLAUDE.md`，并同步 `README.md`、`CHANGELOG.md`，确保版本、入口、支持矩阵、测试状态一致。
- 在 Debian 与 Ubuntu LTS 的 BIOS / UEFI 虚拟机中分别测试。
- 至少验证官方源和一个镜像源；Ubuntu arm64 / ports 架构需验证 `ubuntu-ports`。
- 验证低内存场景：可升级配置会创建临时 Swap，过低 NAT VPS 会在切源前停止。
- 验证 `--require-confirm`、`--auto-reboot` 和默认自动稳定升级行为。
- 验证失败路径不会删除锁、修改网卡名或写入错误磁盘。
