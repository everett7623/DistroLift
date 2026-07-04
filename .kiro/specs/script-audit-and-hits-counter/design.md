# Current Design Baseline

## Overview

`distro_upgrade.sh` v3.7.1 是 DistroLift Auto Upgrade 的当前生产实现。设计目标是先把 Debian 与 Ubuntu 两条主路径做到稳定、自动化、可恢复，再考虑扩展其他发行版。

旧版 Kiro 规格曾围绕 `debian_upgrade.sh` v3.6 的 bugfix 和 Ubuntu 初始支持展开；当前状态已经演进为统一入口 `distro_upgrade.sh`，并完成 v3.7 自动化与 VPS 兼容优化。

## Design Principles

- 生产入口唯一：所有当前逻辑都在 `distro_upgrade.sh`。
- 相邻升级：Debian 和 Ubuntu 均不跨代跳级。
- 自动化优先：稳定版相邻升级默认自动继续，减少无人值守场景卡住。
- 风险前置：真实升级前集中展示启动风险确认页，用户确认一次后稳定版流程继续自动化。
- 风险显式：testing、自动重启、极低资源 VPS 都必须明确处理。
- 切源前阻断：资源、锁、动态库注入、initramfs、dpkg 状态必须在修改 APT 源前检查。
- 共享逻辑优先：Debian / Ubuntu 共享锁等待、资源门槛、临时 Swap、APT 恢复和升级后修复。
- 保守引导：常规升级只刷新 GRUB 配置，不写入 MBR，不无条件 `grub-install`。
- 网络保守：只备份和核对网络接口，不自动改名或重启网络。

## Main Flow

```text
main()
  -> parse CLI flags
  -> set_mirror()
  -> check_root()
  -> check_system()
  -> dispatch by /etc/os-release ID
       debian -> main_upgrade()
       ubuntu -> ubuntu_upgrade()
```

Both `main_upgrade()` and `ubuntu_upgrade()` follow the same high-level flow:

```text
detect current version
resolve next adjacent version
show startup risk confirmation
confirm stable path only when --require-confirm is set
save network config
pre_upgrade_preparation(target_codename, os_id)
write target sources.list
apt_update_with_recovery(keyring)
apt-get upgrade
apt-get dist-upgrade
post_upgrade_fixes(backup_dir)
verify target version
reboot only when --auto-reboot is set
```

## Shared Preparation

`pre_upgrade_preparation(target_codename, os_id)` performs:

- `stop_apt_units()`
- `wait_for_apt_locks()`
- `check_upgrade_capacity()`
- `prepare_temporary_swap()`
- `check_runtime_injection()`
- `check_initramfs_health()`
- best-effort `dpkg --audit`, `dpkg --configure -a`, and `apt-get --fix-broken install`
- keyring refresh:
  - Debian: `debian-archive-keyring`
  - Ubuntu: `ubuntu-keyring`
- `clean_apt_sources(target_codename)`
- conservative GRUB debconf preset only when a boot disk is detected and the system is not a container

## Resource Gate

Low-end VPS handling is intentionally conservative:

- `MIN_PHYSICAL_MEM_MB=384`
- `LOW_MEM_MB=1024`
- `MIN_COMBINED_MEM_SWAP_MB=1024`
- `TARGET_COMBINED_MEM_SWAP_MB=1536`
- `MIN_ROOT_FREE_MB=2048`
- `MIN_BOOT_FREE_MB=120`
- `RECOMMENDED_BOOT_FREE_MB=200`

If physical memory or disk conditions are too low, the script stops before changing APT sources. If memory is low but the root partition has enough room, a temporary Swap file is created under `/var/tmp` and removed by `cleanup()`.

## APT Recovery

`apt_update_with_recovery(keyring_pkg)` is shared by Debian and Ubuntu:

1. Run `apt-get -o Acquire::Languages=none update`.
2. If GPG / keyring errors occur, temporarily add `[trusted=yes]`, update, install the target keyring, remove trust, and update again.
3. If 404 / missing Release errors remain, disable residual `.list` and Deb822 `.sources` files in `sources.list.d`, then retry.
4. If recovery fails, stop and preserve logs.

## Version Policy

Debian:

- 11 (`bullseye`) -> 12 (`bookworm`)
- 12 (`bookworm`) -> 13 (`trixie`)
- 13 -> 14 (`forky`) only with `--allow-testing`

Ubuntu:

- 20.04 (`focal`) -> 22.04 (`jammy`)
- 22.04 (`jammy`) -> 24.04 (`noble`)
- 24.04 (`noble`) -> 26.04 (`resolute`)

Ubuntu non-amd64 architectures use `ubuntu-ports` through `get_ubuntu_mirror_info()`.

## CLI Policy

- `--stable-only`: default Debian behavior, blocks testing.
- `--allow-testing`: permits Debian testing path and keeps high-risk confirmation.
- `--require-confirm`: stable upgrades require `[y/N]`.
- `--force`: skips forced confirmation prompts.
- `--auto-reboot`: reboots after successful verification; otherwise the script only prints the manual reboot command.
- `--preflight`: checks resources, locks, runtime injection, initramfs, and dpkg without switching sources.

## Safety Boundaries

- No direct lock deletion.
- No direct boot-sector writes.
- No default `autoremove` after main upgrade.
- No automatic third-party repo restoration.
- No automatic network interface renaming.
- No automatic network service restart.
- No default reboot.

## Testing Strategy

Smoke tests cover:

- Debian and Ubuntu version mappings.
- Ubuntu `resolute` codename.
- Ubuntu `ubuntu-ports` mirror selection.
- CLI flags including `--require-confirm` and `--auto-reboot`.
- low-memory VPS resource gate and temporary Swap sizing.
- safety invariants such as no lock deletion and no boot-sector writes.
- required preflight and keyring recovery paths.

Full validation still requires VM snapshots for actual distro upgrade behavior.
