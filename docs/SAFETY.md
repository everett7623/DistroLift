# Safety Boundaries

本项目按以下边界处理高风险系统操作：

- APT/dpkg 锁只能等待释放，不直接删除。
- `dpkg --configure -a`、损坏依赖修复和最终 `dpkg --audit` 必须在切换软件源前成功。
- 已存在的 `/etc/apt/sources.list` 必须成功备份后才能覆盖；文件原本不存在时允许创建。
- APT 签名验证失败时必须停止，不自动写入 `trusted=yes` 或以其他方式绕过签名检查。
- 第三方源先备份再禁用，恢复由管理员逐项确认。
- `dist-upgrade` 事务内不写引导扇区：升级前把 `grub-pc` 预设为空 `install_devices` + `install_devices_empty=true`，`grub-pc` 的 postinst 只重建 `grub.cfg`，`grub-install` 失败不会中断升级事务。
- 升级完成后由 `verify_boot_loader` 只对唯一明确的 BIOS 引导盘做一次受控、全程记录日志的 `grub-install`。无法确定磁盘、架构不支持或写入失败时不阻断脚本，只置位待处理标记、要求显式 `--fix-grub`，并阻止自动 / 快速重启，升级路径以非零码退出。
- `grub-install` 只出现在升级后的 `verify_boot_loader` 受控步骤和显式 `--fix-grub`；`--fix-grub` 检查其真实退出码，失败不假报成功。
- 网络配置只备份和检查，不自动改名或重启。
- 升级完成后不自动 `autoremove`。
- 默认不自动重启；只有显式 `--auto-reboot` 才会在升级成功后重启。
- 所有升级必须是相邻 Debian 大版本或 Ubuntu LTS 相邻版本。
- 测试版升级必须显式启用并二次确认。
- 稳定版相邻升级默认自动继续；需要人工确认时使用 `--require-confirm`。
- 低内存 / NAT VPS 必须先通过资源门槛；过低物理内存、根分区或 `/boot` 空间不足时停止。
- 临时 Swap 只用于低内存但仍合理的升级场景，脚本退出时关闭并删除。
- 自更新必须校验固定标签的双源内容和版本元数据；当前脚本备份失败时不得覆盖。

`--force` 只跳过交互确认，不代表操作无风险，也不应替代快照和控制台访问。`--auto-reboot` 只适合已确认控制台、快照和维护窗口的场景。
