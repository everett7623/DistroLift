# 更新日志

本文件记录 DistroLift 的正式版本变更。

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，当前版本与 README 的版本进度保持一致。

## v3.8.1 - 2026-07-24

### 安全

- 自更新要求固定标签脚本中的版本元数据与 `main` 宣告版本一致，避免标签内容错配。
- 当前脚本备份失败时拒绝自更新覆盖；原子替换失败时清理中间文件并保留原脚本。

### 修复

- 命令行参数改为完整解析后再执行，`--check --mirror cn` 等组合不再因参数顺序不同而失效。
- 同时指定多个动作参数时明确报错，避免静默执行第一个或最后一个动作。
- APT 源、附加源和网络配置备份路径加入单次运行 ID，避免同秒运行时互相覆盖。
- EFI 挂载点选择不再使用易受 `pipefail` 影响的 `head` 管道。

### 优化

- 移除生产脚本中的第三方访问统计请求，检查和升级流程不再访问无关服务。
- 精简重复的烟雾测试输出，保留安全边界覆盖并新增参数顺序、自更新元数据和兼容入口测试。
- CI 语法检查和 ShellCheck 纳入 `debian_upgrade.sh` 兼容入口。

### 变更

- 项目展示名称统一为 DistroLift，仓库地址同步迁移到 `everett7623/DistroLift`。
- 当前生产入口保留为 `distro_upgrade.sh`；`debian_upgrade.sh` 仅作为兼容转发入口。
- README 快速开始增加 GitHub Raw 默认下载命令，并保留 jsDelivr CDN 作为备用下载方式。
- 统一 README、CHANGELOG、AGENTS、CLAUDE 与脚本中的版本、日期、支持范围和签名安全策略。
- README 只保留当前版本与进度摘要，完整版本历史统一由本文件维护。

### 修复

- 将运行时临时目录、网络配置备份目录和被禁用软件源的标记统一为 `distrolift` 命名，消除旧项目名残留。

## v3.8.0 - 2026-07-13

### 安全

- APT 签名失败时拒绝自动绕过签名验证，要求管理员从可信渠道恢复软件源和密钥环。
- 在清理 backports 或附加源之前备份原始 `/etc/apt/sources.list`，备份失败时停止升级。
- `dpkg --audit` 命令失败或仍存在未完成状态时，在切换软件源前停止。
- 未知架构不再回退到 x86 GRUB 目标，避免对未验证平台执行错误修复。

### 修复

- 使用 `findmnt` 和 `lsblk` 解析分区、LVM、device-mapper 与 mdraid 的物理父磁盘。
- 多磁盘拓扑无法唯一确定引导盘时不再自动猜测 GRUB 安装目标。

## v3.7.7 - 2026-07-12

### Fixed

- Stop before changing APT sources when dpkg configuration, dependency repair, or the final dpkg audit fails.
- Refuse to overwrite an existing `/etc/apt/sources.list` when its backup cannot be created.
- Keep self-update temporary downloads in the per-run directory so EXIT cleanup removes interrupted downloads.

## v3.7.6 - 2026-07-12

### Fixed

- Continue temporary swap and systemd unit cleanup even if APT source restoration fails.
- Arm APT source restoration before writing temporary `[trusted=yes]` entries.
- Reject self-update downgrades and require matching SHA-256 hashes from a fixed Git tag on GitHub and CDN.

## v3.7.5 - 2026-07-11

### Fixed

- Restore APT signature verification after temporary `[trusted=yes]` recovery, including abnormal exits.
- Pass `DEBIAN_FRONTEND=noninteractive` through `sudo` explicitly.
- Preserve arbitrary filename boundaries while removing obsolete dpkg configuration files.
- Require TLS 1.2+ downloads and atomically replace the script during self-update.

## v3.7.4 - 2026-07-04

### 变更

- 默认升级入口第一屏先显示 DistroLift 脚本信息、用途、项目提示、风险清单和 `YES` 确认。
- 用户确认后再开始镜像选择、权限检查、系统环境检查和升级目标判断，避免第一屏被普通日志占用。
- 增加 smoke 断言，保证默认入口启动页早于 `check_system`，同时 `--preflight` 继续保持安静预检。

## v3.7.3 - 2026-07-04

### 变更

- `--preflight` 恢复为安静预检，只输出检查过程，不显示 DistroLift 欢迎页和风险确认。
- 默认升级入口继续显示 DistroLift 脚本信息、用途、项目提示和风险清单，并要求输入 `YES` 后继续。
- README 主运行命令简化为一行下载并执行，无需先 `chmod +x`。

## v3.7.2 - 2026-07-04

### 优化

- 将启动页拆分为“菜单/风险展示”和“真实升级 YES 确认”，真实升级继续要求风险确认。
- README 下载命令改为默认使用 jsDelivr CDN，强制 IPv4 放入 FAQ 排障路径。

## v3.7.1 - 2026-07-04

### 新增

- 真实升级前新增 DistroLift 启动风险确认页，集中展示可执行能力、适用范围、快照/备份/控制台要求和升级风险。
- 确认启动风险后，稳定版相邻升级继续保持自动化，避免后续反复确认。

### 变更

- 项目展示名称从 Debian / Ubuntu Auto Upgrade Tool 更新为 DistroLift，弱化旧 Debian-only 命名。
- 帮助页、README 和 AI 工具文档同步新项目名与当前开发进度。

## v3.7 - 2026-07-04

### 新增

- 新增 Ubuntu LTS 升级状态映射与检测：支持 `20.04 → 22.04 → 24.04 → 26.04` 相邻升级路径。
- `--check` 增加 Ubuntu 分支，输出 Ubuntu 专属升级状态与网络检查结果。
- 稳定版相邻升级默认自动继续，新增 `--require-confirm` 用于恢复人工确认。
- 新增 `--auto-reboot`，仅在用户显式启用时升级成功后自动重启。
- 新增低内存 / NAT VPS 资源门槛，物理内存、Swap、根分区和 `/boot` 不合理时在切换软件源前停止。
- 低内存但仍可升级的 VPS 会自动创建临时 Swap，脚本退出时关闭并删除。

### 修复

- 修复 Ubuntu 下 `--version` 仍按 Debian 规则解析导致显示异常的问题。
- 修复 Ubuntu 升级流程缺少锁等待、运行时注入检查、initramfs 预检与 dpkg 预修复的问题。
- 修复系统网络连通性检查在 Ubuntu 环境仍固定检测 Debian 主机的问题。
- 修复 Ubuntu arm64 / 其他 ports 架构仍写入 `archive.ubuntu.com` / `security.ubuntu.com` 的问题，升级源现在按架构切换到 `ubuntu-ports`。
- 修复 Ubuntu 26.04 LTS 代号误写为 Plucky，改为 Resolute。

### 优化

- Debian 与 Ubuntu 共用 `apt-get update` 自动恢复逻辑，GPG / keyring / 404 错误按同一策略处理。
- Ubuntu 分支升级后同样执行网络核对、initramfs 校验和 GRUB 配置刷新。
- 开发流程增加版本前本地备份要求，避免制作新版本时覆盖上一版状态。

## v3.6 - 2026-06-10

### VPS 兼容性

- ARM64 (aarch64) 架构支持：`fix_grub_mode` 根据 `uname -m` 自动选择正确的 GRUB 包和目标。
- 容器环境自动检测：识别 OpenVZ / LXC / Docker，跳过 GRUB 预设、initramfs 检查和引导磁盘警告。
- 非交互终端安全降级：缺失 `/dev/tty` 时（cron / systemd 环境）优雅回退，不再崩溃。
- EFI 目录多策略检测：`findmnt` → 常见路径 → `/etc/fstab` 逐层查找 ESP 挂载点。
- 网络检测 HTTP 回退：ICMP 被阻断（国内常见）时自动尝试 wget/curl 连接镜像源。
- `--self-update` CDN 回退：GitHub 不可达时自动尝试 jsDelivr CDN 地址。

### 修复

- 修复 `fix_only_mode` 缺少 `stop_apt_units` 导致 apt-daily 定时任务抢占锁的问题。
- 修复 GPG 恢复路径在 404 和 GPG 错误同时出现时不可达（重排分支顺序：GPG → 404）。
- 修复 `detect_boot_disk` 策略 3 中 `blkid -U` 缺少 `$USE_SUDO` 前缀。
- 修复 `--mirror` 无效值时静默回退到官方源，改为主动警告。
- 修复 `check_upgrade` 将 oldstable / oldoldstable 误标为 "不稳定版本"。

### 优化

- 版本元数据从硬编码 case 语句重构为关联数组（`DEBIAN_CODENAME` / `DEBIAN_STATUS` / `DEBIAN_NEXT`）。
- 抽取 `get_old_kernels()` 共享函数，消除 `clean_old_kernels` 和 `cleanup_mode` 中约 20 行重复代码。
- 升级日志文件拆分：`apt-upgrade.log` / `apt-dist-upgrade.log` / `initramfs-post.log` 独立保存。
- `self_update_mode` 添加 wget 存在性检查和 curl 替代方案提示。
- `safe_read()` 辅助函数统一处理交互输入和 tty 降级。

## v3.5 - 2026-06-10

### 新增

- 新增 `--cleanup` 升级后五步清理模式（废弃包 → rc 残留 → 旧内核 → APT 缓存 → .dpkg-* 文件）。
- 新增 `--self-update` 脚本自动更新（从 GitHub 下载最新版，语法检查后替换）。
- 新增 `--preflight` 深度检查模式，不切换软件源即可验证动态库、initramfs 和 dpkg 状态。
- 升级前预构建当前内核 initramfs，失败时在修改 APT 源之前安全停止。
- 检查 `fsck` 动态库依赖和 `/etc/ld.so.preload` 中的非常规路径。

### 修复

- 修复跨版本 GPG 签名验证失败：切换源前更新 `debian-archive-keyring`，遇 NO_PUBKEY 时使用 `[trusted=yes]` 临时绕过。
- 修复云镜像 / 容器环境下 initramfs 预检因缺少 `/var/tmp` 失败。
- 修复最小升级失败后仍继续执行完整升级的问题。
- 修复完整升级失败后自动重复执行耗时包管理操作的问题。
- 错误退出时不再通过 ERR trap 自动重试包管理修复。

### 性能

- APT 更新默认不再下载源码索引和翻译索引。
- APT 已生成最新内核 initramfs 时跳过重复重建。
- 每个升级阶段最多执行一次，失败后保留日志并立即停止。

## v3.3 - 2026-06-09

### 安全

- 等待 APT/dpkg 锁正常释放，不再直接删除仍可能被进程占用的锁文件。
- 常规升级流程不再自动修改网卡名称或重启网络服务。
- 常规升级流程不再写入 MBR 或无条件重装 GRUB。
- 升级完成后不再自动执行 `autoremove`，避免误删仍需人工核对的依赖。
- 只恢复脚本本次主动停止的自动更新单元。

### 新增

- 支持识别、备份并禁用 Deb822 `.sources` 软件源。
- 新增独立的单次运行临时目录，避免固定临时文件冲突。
- 新增 Bash 冒烟测试和危险操作模式检查。
- 新增 GitHub Actions CI、`Makefile`、EditorConfig 和 Git 属性配置。
- 新增贡献指南、安全策略、开发指南、安全边界及历史脚本说明。

### 修复

- 日志改为写入标准错误，避免 `--debug` 输出污染命令替换结果。
- 使用 `sudo tee` 正确写入 root 所有的网络配置快照。
- 修复清理 `/boot` 中 `.old` 和 `.bak` 文件时的 `find` 条件优先级。
- 修复脚本被 `source` 时入口保护返回非零并触发调用方 `set -e` 的问题。

### 文档

- 基于原版结构更新 README，保留原有功能介绍、升级路径、使用示例、故障排查、支持方式和版本历史。
- 明确统一主脚本支持 Debian 11-13；Debian 8-10 脚本仅作为历史迁移参考。

## v3.2 - 2026-06-01

### 变更

- 更新 Debian 13 Trixie 状态为正式稳定版。
- Debian 12 → 13 升级不再需要 `--allow-testing`。
- Debian 13 → 14 Forky 升级需要显式使用 `--allow-testing`。
- 更新帮助信息、升级路径说明和 README。

## v3.1 - 2026-06-01

### 修复

- 修复 Debian 12 已是最新稳定版时升级提示不显示的问题。
- 修正 `main_upgrade()` 中提示逻辑的判断条件。

### 变更

- 更新 Debian 13 Trixie 的版本状态说明。
- 更新 `--help` 中的升级路径。

## v3.0 - 2026-04-02

### 变更

- 全面重构统一升级脚本，提高健壮性与兼容性。
- 统一关键步骤的错误处理和恢复流程。
- 改进 Debian 版本检测及升级目标判断。

### 新增

- 新增 `--mirror`，支持阿里云、清华大学和中科大镜像。
- 新增磁盘空间和 `/boot` 空间预检。
- 新增 APT 源备份、旧 backports 处理及第三方源清理。
- 新增 UEFI/BIOS、NVMe、virtio 和 Xen 引导磁盘检测。
- 新增完整帮助信息、调试日志和升级前后验证。

### 修复

- 修复 `sources.list.d/` 中旧源残留导致的 APT 冲突和 404。
- 改进 GRUB 检测逻辑，减少误判和过度修复。
- 改进部分 VPS 无法正确识别 Debian 版本的问题。

## v2.6 - 2024-12-01

### 修复

- 修复 GRUB 过度修复问题。
- 改进重启前的二次确认机制。
- 降低自动引导修复对 VPS 启动配置的影响。

## v2.5 - 2024-11-01

### 新增

- 新增网络接口配置、IP 地址和路由信息备份。
- 新增升级后网络配置检查与恢复辅助。
- 新增旧内核清理，用于释放 `/boot` 空间。

## v2.0 - 2024-06-01

### 新增

- 新增 UEFI 与 BIOS 启动模式自动检测。
- 新增 NVMe、virtio 和 Xen 磁盘支持。
- 改进 GRUB 安装磁盘识别。
- 增强 VPS 和虚拟机环境兼容性。

## v1.0 - 2024-01-01

### 新增

- 发布初始版本。
- 提供 Debian 基础版本检测和相邻版本升级流程。
- 提供 APT 源更新、软件包升级及基础错误处理。
- 提供命令行帮助和升级确认。

---

## 版本支持说明

| 工具版本 | 主脚本支持范围 | 状态 |
|---|---|---|
| 3.8.x | Debian 11-13；Ubuntu LTS 20.04-26.04 | 当前维护；Debian 14 仅实验性支持 |
| 3.7.x | Debian 11-13；Ubuntu LTS 20.04-26.04 | 历史版本 |
| 3.3.x-3.6.x | Debian 11-13 | 历史版本，不再维护 |
| 1.x-3.2.x | 早期 Debian 升级路径 | 历史版本，不建议继续使用 |

Debian 8-10 已进入归档范围。仓库 `scripts/` 中的分版本脚本仅供历史追踪和迁移设计参考，不作为当前生产入口。

## 更新脚本

- 优先使用 `--self-update`，或从仓库重新下载并替换根目录的 `distro_upgrade.sh`。
- 从 v2.x 或早期 v3.x 更新时，重新阅读 README 的支持范围、安全边界和升级前检查清单。
- 不要把 `scripts/` 下的历史脚本替换成当前生产入口。
- 更新脚本不等于升级操作系统；执行系统升级前仍需快照、业务备份和带外控制台。
