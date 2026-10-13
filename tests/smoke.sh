#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2016,SC2317
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/distro_upgrade.sh"
COMPAT_SCRIPT="${ROOT_DIR}/debian_upgrade.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

function_block() {
    local name="$1"
    sed -n "/^${name}()/,/^[a-zA-Z_][a-zA-Z0-9_]*() *{/p" "$SCRIPT"
}

bash -n "$SCRIPT"
bash -n "$COMPAT_SCRIPT"

script_version="$(awk -F'"' '$1 == "SCRIPT_VERSION=" {print $2; exit}' "$SCRIPT")"
script_date="$(awk -F'"' '$1 == "SCRIPT_DATE=" {print $2; exit}' "$SCRIPT")"
[[ -n "$script_version" && -n "$script_date" ]] || fail "missing script version metadata"
grep -Fq "Version-${script_version}-brightgreen" "${ROOT_DIR}/README.md" \
    || fail "README version badge does not match script"
grep -Fq "当前脚本版本：**v${script_version}**（${script_date}）" "${ROOT_DIR}/README.md" \
    || fail "README progress does not match script version/date"
grep -Fq "## v${script_version} - ${script_date}" "${ROOT_DIR}/CHANGELOG.md" \
    || fail "CHANGELOG release does not match script version/date"
expected_guide_version="\`distro_upgrade.sh\` v${script_version} (\`SCRIPT_DATE=${script_date}\`)"
for guide in "${ROOT_DIR}/AGENTS.md" "${ROOT_DIR}/CLAUDE.md"; do
    grep -Fq "$expected_guide_version" "$guide" \
        || fail "$(basename "$guide") version does not match script"
done

help_output="$(bash "$SCRIPT" --help)"
compat_help_output="$(bash "$COMPAT_SCRIPT" --help)"
grep -q 'DistroLift' <<<"$help_output" || fail "help misses project name"
[[ "$compat_help_output" == "$help_output" ]] || fail "compatibility wrapper does not forward help"
grep -q 'exec bash .*distro_upgrade.sh' "$COMPAT_SCRIPT" \
    || fail "compatibility wrapper depends on the main script executable bit"
for option in --stable-only --allow-testing --preflight --cleanup --self-update \
    --require-confirm --auto-reboot; do
    grep -q -- "$option" <<<"$help_output" || fail "help misses $option"
done
grep -q 'Ubuntu 20.04 (Focal)' <<<"$help_output" || fail "help misses Ubuntu LTS path"

# Source functions without executing main.
# shellcheck source=../distro_upgrade.sh
source "$SCRIPT"
trap - EXIT

[[ "$(get_next_version 11 debian)" == "12" ]] || fail "Debian 11 target"
[[ "$(get_next_version 12 debian)" == "13" ]] || fail "Debian 12 target"
[[ -z "$(STABLE_ONLY=1 get_next_version 13 debian)" ]] || fail "stable policy"
[[ "$(STABLE_ONLY=0 get_next_version 13 debian)" == "14" ]] || fail "testing policy"
[[ "$(get_version_info 13 debian)" == "trixie|stable" ]] || fail "Trixie status"
[[ "$(get_version_info 14 debian)" == "forky|testing" ]] || fail "Forky status"
[[ -z "$(get_next_version 14 debian)" ]] || fail "Forky no further upgrade"
[[ "$(get_version_info 22.04 ubuntu)" == "jammy|oldlts" ]] || fail "Ubuntu 22.04 status"
[[ "$(get_version_info 24.04 ubuntu)" == "noble|lts" ]] || fail "Ubuntu 24.04 status"
[[ "$(get_version_info 26.04 ubuntu)" == "resolute|lts" ]] || fail "Ubuntu 26.04 status"
[[ "$(get_next_version 22.04 ubuntu)" == "24.04" ]] || fail "Ubuntu 22.04 target"
[[ -z "$(get_next_version 26.04 ubuntu)" ]] || fail "Ubuntu latest no further upgrade"

orig_uname="$(declare -f uname 2>/dev/null || true)"
uname() { echo aarch64; }
[[ "$(get_ubuntu_mirror_info)" == "ports.ubuntu.com|http://ports.ubuntu.com/ubuntu-ports|http://ports.ubuntu.com/ubuntu-ports" ]] \
    || fail "Ubuntu arm64 ports mirror"
[[ "$(MIRROR=cn get_ubuntu_mirror_info)" == "mirrors.aliyun.com|http://mirrors.aliyun.com/ubuntu-ports|http://mirrors.aliyun.com/ubuntu-ports" ]] \
    || fail "Ubuntu arm64 cn mirror"
uname() { echo x86_64; }
[[ "$(get_ubuntu_mirror_info)" == "archive.ubuntu.com|http://archive.ubuntu.com/ubuntu|http://security.ubuntu.com/ubuntu" ]] \
    || fail "Ubuntu amd64 mirror"
if [[ -n "$orig_uname" ]]; then eval "$orig_uname"; else unset -f uname; fi

orig_get_os_id="$(declare -f get_os_id)"
get_os_id() { echo ubuntu; }
[[ "$(get_version_info 22.04)" == "jammy|oldlts" ]] || fail "Ubuntu default routing status"
[[ "$(get_next_version 24.04)" == "26.04" ]] || fail "Ubuntu default routing next"
eval "$orig_get_os_id"

# Action options must be parsed after all modifiers, regardless of their order.
cli_probe="$(
    SCRIPT_PATH="$SCRIPT" bash -c '
        source "$SCRIPT_PATH"
        trap - EXIT
        log_info() { :; }
        log_debug() { :; }
        check_upgrade() {
            printf "%s|%s|%s\n" "${DEBUG:-0}" "${MIRROR:-default}" "${STABLE_ONLY:-unset}"
        }
        main --check --debug --mirror cn --allow-testing
    '
)"
[[ "$cli_probe" == "1|cn|0" ]] || fail "action modifiers depend on argument order"

set +e
conflict_output="$(
    SCRIPT_PATH="$SCRIPT" bash -c '
        source "$SCRIPT_PATH"
        trap - EXIT
        main --check --cleanup
    ' 2>&1
)"
conflict_status=$?
set -e
[[ "$conflict_status" -ne 0 && "$conflict_output" == *"动作参数只能指定一个"* ]] \
    || fail "conflicting action options are not rejected"

dist_upgrade_count="$(grep -Ec '(apt-get|run_apt_noninteractive) dist-upgrade' "$SCRIPT" || true)"
[[ "$dist_upgrade_count" -le 2 ]] || fail "dist-upgrade should run at most once per distro path"
grep -q '^deb-src ' "$SCRIPT" && fail "generated sources should not include deb-src"
grep -Fq '[trusted=yes]' "$SCRIPT" && fail "production path bypasses APT signatures"
grep -q '拒绝自动绕过签名检查' "$SCRIPT" || fail "missing safe GPG failure path"
grep -q 'check_initramfs_health' "$SCRIPT" || fail "missing initramfs preflight"
grep -q 'check_runtime_injection' "$SCRIPT" || fail "missing runtime injection check"
grep -q 'debian-archive-keyring' "$SCRIPT" || fail "missing Debian keyring handling"
grep -q 'ubuntu-keyring' "$SCRIPT" || fail "missing Ubuntu keyring handling"
grep -q 'MIN_PHYSICAL_MEM_MB' "$SCRIPT" || fail "missing low-memory gate"
grep -q 'prepare_temporary_swap' "$SCRIPT" || fail "missing temporary swap helper"
grep -q 'REQUIRE_CONFIRM' "$SCRIPT" || fail "missing stable confirmation override"
grep -q 'show_startup_risk_banner' "$SCRIPT" || fail "missing startup risk banner"
grep -q 'show_initial_startup_banner' "$SCRIPT" || fail "missing first-screen banner"
grep -q 'fetch_hit_stats\|visitor-badge.laobi.icu' "$SCRIPT" \
    && fail "production script still performs third-party statistics requests"

default_entry_block="$(sed -n '/show_initial_startup_banner/,/# OS 类型分流/p' "$SCRIPT")"
startup_line="$(grep -n -m1 'show_initial_startup_banner' <<<"$default_entry_block" | cut -d: -f1)"
check_line="$(grep -n -m1 'check_system' <<<"$default_entry_block" | cut -d: -f1)"
[[ -n "$startup_line" && -n "$check_line" && "$startup_line" -lt "$check_line" ]] \
    || fail "default banner must appear before system checks"
preflight_dispatch="$(sed -n '/^[[:space:]]*preflight)/,/^[[:space:]]*cleanup)/p' "$SCRIPT")"
grep -q 'show_project_intro_banner' <<<"$preflight_dispatch" \
    && fail "preflight should not show the intro banner"
STARTUP_RISK_CONFIRMED=0
FORCE=1 show_startup_risk_banner "Debian" "12" "13" "trixie" >/dev/null 2>&1
[[ "$STARTUP_RISK_CONFIRMED" == "1" ]] || fail "force mode should acknowledge startup risk"

orig_free="$(declare -f free 2>/dev/null || true)"
orig_df="$(declare -f df 2>/dev/null || true)"
free() {
    printf '%s\n' '              total        used        free      shared  buff/cache   available'
    printf '%s\n' 'Mem:            512         100         100           0         100         300'
    printf '%s\n' 'Swap:             0           0           0'
}
df() {
    printf '%s\n' 'Filesystem 1M-blocks Used Available Use% Mounted on'
    printf '%s\n' '/dev/vda1 8192 1024 7168 13% /'
}
[[ "$(calculate_temp_swap_mb)" == "1024" ]] || fail "low-memory temp swap sizing"
check_upgrade_capacity >/dev/null 2>&1 || fail "512MB VPS should use temporary swap"
free() {
    printf '%s\n' '              total        used        free      shared  buff/cache   available'
    printf '%s\n' 'Mem:            256         100          50           0          50         100'
    printf '%s\n' 'Swap:             0           0           0'
}
check_upgrade_capacity >/dev/null 2>&1 && fail "256MB VPS should be rejected"
if [[ -n "$orig_free" ]]; then eval "$orig_free"; else unset -f free; fi
if [[ -n "$orig_df" ]]; then eval "$orig_df"; else unset -f df; fi

failure_log="$(mktemp)"
printf '%s\n' 'E: /usr/share/initramfs-tools/hooks/fsck failed with return 1.' >"$failure_log"
KEEP_RUN_DIR=0
diagnose_upgrade_failure "$failure_log" >/dev/null 2>&1
[[ "$KEEP_RUN_DIR" == "1" ]] || fail "failure diagnostics should preserve logs"
rm -f "$failure_log"

grep -Eq 'rm[[:space:]]+-f[[:space:]]+/var/(lib/dpkg|cache/apt).*(lock|lock-frontend)' "$SCRIPT" \
    && fail "main script deletes package-manager locks"
grep -Eq 'dd[[:space:]].*of=.*boot_disk' "$SCRIPT" \
    && fail "main upgrade path writes directly to a boot sector"

# GRUB: dist-upgrade 事务内不得强制 grub-pc 执行 grub-install
grep -q 'install_devices_empty boolean false' "$SCRIPT" \
    && fail "pre-upgrade still forces grub-pc grub-install during dist-upgrade"
prep_grub_block="$(function_block pre_upgrade_preparation)"
grep -q 'install_devices_empty boolean true' <<<"$prep_grub_block" \
    || fail "pre-upgrade does not neutralize grub-pc in-transaction grub-install"

# 升级后引导器受控写入：函数存在且被 post_upgrade_fixes 调用
grep -q '^verify_boot_loader()' "$SCRIPT" || fail "missing verify_boot_loader helper"
post_fixes_block="$(function_block post_upgrade_fixes)"
grep -q 'verify_boot_loader' <<<"$post_fixes_block" \
    || fail "post_upgrade_fixes does not call verify_boot_loader"

# 引导器待处理时必须阻止重启并让升级路径非零退出
reboot_block="$(function_block safe_reboot)"
grep -q 'BOOTLOADER_ACTION_REQUIRED' <<<"$reboot_block" \
    || fail "safe_reboot does not block on a pending bootloader action"
for upgrade_func in main_upgrade ubuntu_upgrade; do
    grep -q 'BOOTLOADER_ACTION_REQUIRED' <<<"$(function_block "$upgrade_func")" \
        || fail "$upgrade_func ignores a pending bootloader action"
done

# --fix-grub 必须检查 grub-install 真实退出码，不再用管道吞掉状态
fix_grub_block="$(function_block fix_grub_mode)"
grep -q 'grub_install_ok=0' <<<"$fix_grub_block" \
    || fail "fix_grub_mode does not track the grub-install exit status"
grep -Eq 'grub-install[^|]*\| *tail' <<<"$fix_grub_block" \
    && fail "fix_grub_mode still pipes grub-install through tail and masks its status"
grep -q 'lsblk -d -n -p -r' <<<"$fix_grub_block" \
    || fail "manual GRUB disk selection does not request raw lsblk output"
grep -q 'boot_disk="/dev/\$(' <<<"$fix_grub_block" \
    && fail "manual GRUB disk selection still prepends /dev/ to unvalidated lsblk names"

# grub-install 失败归因与升级诊断覆盖 grub-pc
grep -q '^diagnose_grub_install_failure()' "$SCRIPT" \
    || fail "missing diagnose_grub_install_failure helper"
grep -q 'bios_grub' "$SCRIPT" || fail "grub diagnostics omit the bios_grub partition hint"
grep -q 'cannot find a GRUB drive' <<<"$(function_block diagnose_grub_install_failure)" \
    || fail "grub diagnostics omit malformed or unresolved target drives"
grep -q 'grub-pc' <<<"$(function_block diagnose_upgrade_failure)" \
    || fail "upgrade failure diagnostics do not cover grub-pc"

cleanup_body="$(function_block cleanup_mode)"
grep -q 'awk.*\$5' <<<"$cleanup_body" || fail "cleanup disk usage does not use df Use%"
grep -q "mapfile -d '' -t old_configs" <<<"$cleanup_body" \
    || fail "cleanup does not preserve arbitrary filenames"
grep -q 'rm -f -- "\$f"' <<<"$cleanup_body" \
    || fail "cleanup does not quote obsolete config paths"

run_apt_body="$(function_block run_apt_noninteractive)"
grep -q '\$USE_SUDO env DEBIAN_FRONTEND=noninteractive apt-get' <<<"$run_apt_body" \
    || fail "sudo apt helper drops DEBIAN_FRONTEND"
grep -q 'DEBIAN_FRONTEND=noninteractive \$USE_SUDO apt-get' "$SCRIPT" \
    && fail "legacy noninteractive apt invocation remains"

self_update_body="$(function_block self_update_mode)"
grep -q '\[\[.*-w.*script_path' <<<"$self_update_body" \
    || fail "self-update lacks an early permission check"
grep -q '拒绝自更新降级' <<<"$self_update_body" || fail "self-update accepts downgrades"
grep -q 'primary_hash.*cdn_hash' <<<"$self_update_body" \
    || fail "self-update does not compare fixed-tag hashes"
grep -q 'fixed_version.*remote_version' <<<"$self_update_body" \
    || fail "self-update does not verify fixed-tag version metadata"
grep -q 'if ! cp -p --.*script_path.*backup' <<<"$self_update_body" \
    || fail "self-update backup failure is not blocking"
grep -q 'mv -f --.*replacement.*script_path' <<<"$self_update_body" \
    || fail "self-update replacement is not atomic"
grep -q 'RUN_DIR/self-update-main.sh' <<<"$self_update_body" \
    || fail "self-update temporary files are outside RUN_DIR"
grep -q 'raw.githubusercontent.com.*${tag}/distro_upgrade.sh' <<<"$self_update_body" \
    || fail "self-update primary URL is not pinned to a tag"
grep -q 'jsdelivr.net.*@${tag}/distro_upgrade.sh' <<<"$self_update_body" \
    || fail "self-update CDN URL is not pinned to a tag"

version_fixture="$(mktemp)"
printf 'SCRIPT_VERSION="9.8.7"\nSCRIPT_VERSION="1.0.0"\n' >"$version_fixture"
[[ "$(get_script_version_from_file "$version_fixture")" == "9.8.7" ]] \
    || fail "script version parser is not deterministic"
rm -f "$version_fixture"

prep_block="$(function_block pre_upgrade_preparation)"
grep -q 'if ! .*dpkg --configure -a' <<<"$prep_block" \
    || fail "pre-upgrade does not stop on dpkg configure failure"
grep -q 'if ! run_apt_noninteractive --fix-broken' <<<"$prep_block" \
    || fail "pre-upgrade does not stop on dependency repair failure"
grep -q 'if ! audit_output=.*dpkg --audit' <<<"$prep_block" \
    || fail "pre-upgrade does not detect dpkg audit command failure"
grep -q 'mkdir -p "\$RUN_DIR"' <<<"$prep_block" \
    || fail "pre-upgrade does not create the log dir before the first tee"
fix_only_block="$(function_block fix_only_mode)"
grep -q 'mkdir -p "\$RUN_DIR"' <<<"$fix_only_block" \
    || fail "fix-only does not create the log dir before the first tee"
for version_probe in check_upgrade check_upgrade_ubuntu main_upgrade; do
    grep -q 'get_current_version) || true' <<<"$(function_block "$version_probe")" \
        || fail "$version_probe aborts instead of reporting version detection failure"
done
[[ "$(grep -c '</dev/tty || REPLY=""' "$SCRIPT" || true)" -eq 5 ]] \
    || fail "interactive tty reads must degrade to a safe default on open failure"
[[ "$(grep -c 'backup_primary_sources_list.*sources.list.backup' "$SCRIPT")" -eq 2 ]] \
    || fail "both distro paths must guard the primary sources backup"
grep -Fq 'sources.list.backup.${RUN_ID}' "$SCRIPT" \
    || fail "primary sources backups are not unique per run"

for upgrade_func in main_upgrade ubuntu_upgrade; do
    upgrade_block="$(function_block "$upgrade_func")"
    source_backup_line="$(grep -n -m1 'backup_primary_sources_list' <<<"$upgrade_block" | cut -d: -f1)"
    preparation_line="$(grep -n -m1 'pre_upgrade_preparation' <<<"$upgrade_block" | cut -d: -f1)"
    [[ -n "$source_backup_line" && -n "$preparation_line" \
        && "$source_backup_line" -lt "$preparation_line" ]] \
        || fail "$upgrade_func edits sources before backing them up"
done

orig_findmnt="$(declare -f findmnt 2>/dev/null || true)"
orig_lsblk="$(declare -f lsblk 2>/dev/null || true)"
orig_readlink="$(declare -f readlink 2>/dev/null || true)"
findmnt() { echo /dev/mapper/vg-root; }
readlink() { echo "$2"; }
lsblk() {
    if [[ " $* " == *" -s "* ]]; then
        if [[ " $* " == *" -r "* ]]; then
            printf '/dev/mapper/vg-root lvm\n/dev/vda2 part\n/dev/vda disk\n'
        else
            printf '/dev/mapper/vg-root lvm\n`-/dev/vda2 part\n`-/dev/vda disk\n'
        fi
    else
        printf '/dev/vda disk\n'
    fi
}
[[ "$(detect_boot_disk)" == "/dev/vda" ]] \
    || fail "LVM boot disk resolution should strip lsblk tree formatting via raw output"
grep -q 'lsblk -s -n -p -r' <<<"$(function_block get_physical_disks_for_device)" \
    || fail "physical disk resolution does not request raw lsblk output"
lsblk() {
    if [[ " $* " == *" -s "* ]]; then
        printf '/dev/md0 raid1\n/dev/vda1 part\n/dev/vda disk\n/dev/vdb1 part\n/dev/vdb disk\n'
    else
        printf '/dev/vda disk\n/dev/vdb disk\n'
    fi
}
[[ -z "$(detect_boot_disk 2>/dev/null)" ]] || fail "multi-disk RAID selected a boot disk"
if [[ -n "$orig_findmnt" ]]; then eval "$orig_findmnt"; else unset -f findmnt; fi
if [[ -n "$orig_lsblk" ]]; then eval "$orig_lsblk"; else unset -f lsblk; fi
if [[ -n "$orig_readlink" ]]; then eval "$orig_readlink"; else unset -f readlink; fi

orig_findmnt="$(declare -f findmnt 2>/dev/null || true)"
findmnt() { printf '/media/usb\n/boot/efi\n'; }
[[ "$(get_efi_dir)" == "/boot/efi" ]] || fail "EFI detection selected an unrelated vfat mount"
if [[ -n "$orig_findmnt" ]]; then eval "$orig_findmnt"; else unset -f findmnt; fi

grub_target_body="$(function_block get_grub_target)"
grep -q '拒绝自动修复' <<<"$grub_target_body" \
    || fail "unknown architectures still fall back to x86 GRUB"

printf 'smoke tests passed\n'
