# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Current Project State

- Project display name: DistroLift Auto Upgrade.
- Current production script: `distro_upgrade.sh` v3.7.1 (`SCRIPT_DATE=2026-07-04`), about 2210 lines.
- Production scope: Debian 11 -> 12 -> 13 and Ubuntu LTS 20.04 -> 22.04 -> 24.04 -> 26.04.
- Ubuntu 26.04 codename is `resolute`.
- Stable adjacent upgrades are automation-first and continue by default; use `--require-confirm` to restore manual confirmation.
- Debian 13 -> 14 remains gated by `--allow-testing` and requires explicit `YES` confirmation unless forced.
- `--auto-reboot` is opt-in only. Successful upgrades do not reboot automatically by default.
- A startup risk confirmation page is shown before real upgrades. It summarizes capabilities, backup requirements, console access requirements, and failure risks. `--force` skips this confirmation for explicit automation.
- Low-memory / NAT VPS handling is part of v3.7: physical memory, swap, root free space, and `/boot` free space are checked before sources are changed. Reasonable low-memory systems may get a temporary swap file that is removed on exit; extremely small systems are rejected before upgrade.

## Build & Test

```bash
make check          # Full CI: syntax check + shellcheck + smoke tests
make syntax         # bash -n on all .sh files
make shellcheck     # Static analysis; skipped by Makefile when shellcheck is missing
make test           # Smoke tests only
bash tests/smoke.sh # Run smoke tests directly
```

Smoke tests are non-privileged. They source the main script and cover Debian / Ubuntu version mapping, Ubuntu mirror selection including `ubuntu-ports`, low-memory VPS resource gates, required CLI flags, and hard safety invariants.

If developing on Windows, Git Bash can run syntax and smoke tests. Full behavior testing must be done in isolated Debian / Ubuntu VMs with snapshots.

## Architecture

The entire supported production tool is a single Bash script: `distro_upgrade.sh`. Legacy scripts in `scripts/` are historical reference only and must not be used as production entry points.

### Execution Flow

```text
main() -> parse args -> set_mirror() -> check_root() -> check_system()
  -> OS dispatch:
     Debian -> main_upgrade()
     Ubuntu -> ubuntu_upgrade()

main_upgrade() / ubuntu_upgrade()
  -> get_current_version()
  -> get_next_version()
  -> show_startup_risk_banner() before changing system state
  -> confirm_stable_upgrade() for stable adjacent paths
  -> save_network_config()
  -> pre_upgrade_preparation(target_codename, os_id)
       -> stop_apt_units()
       -> wait_for_apt_locks()
       -> check_upgrade_capacity()
       -> prepare_temporary_swap()
       -> check_runtime_injection()
       -> check_initramfs_health()
       -> dpkg audit / configure / fix-broken best-effort
       -> reinstall debian-archive-keyring or ubuntu-keyring
       -> clean_apt_sources()
       -> conservative GRUB debconf preset when a boot disk is detected
  -> write new /etc/apt/sources.list
  -> apt_update_with_recovery(keyring)
       -> GPG/keyring recovery through temporary [trusted=yes]
       -> 404 / Release-file recovery by disabling residual extra sources
  -> apt-get upgrade
  -> apt-get dist-upgrade
  -> post_upgrade_fixes()
       -> compare network interface names, warn only
       -> build latest initramfs only if missing
       -> refresh GRUB config only, no grub-install
  -> verify target version
  -> reboot only with --auto-reboot
```

### Version Mapping

`get_version_info()` and `get_next_version()` are the central policy tables.

- Debian codenames/statuses are in `DEBIAN_CODENAME`, `DEBIAN_STATUS`, and `DEBIAN_NEXT`.
- Ubuntu LTS codenames/statuses are in `UBUNTU_CODENAME`, `UBUNTU_STATUS`, and `UBUNTU_NEXT`.
- `STABLE_ONLY=1` blocks Debian 13 -> 14; `STABLE_ONLY=0` via `--allow-testing` permits it with high-risk confirmation.
- Ubuntu only supports LTS adjacent upgrades and does not use the Debian testing gate.

When adding a new Debian or Ubuntu release, update the mapping arrays, `SCRIPT_VERSION`, `SCRIPT_DATE`, sources.list generation, README support matrix, CHANGELOG, and smoke tests.

## Hard Safety Invariants

- Never delete APT/dpkg lock files; only wait for locks.
- Never write directly to boot sectors in the normal upgrade path.
- Do not add `deb-src` lines to generated sources.
- Keep `check_initramfs_health`, `check_runtime_injection`, keyring recovery, and `[trusted=yes]` recovery paths covered by tests.
- Stable upgrades may be automatic, but high-risk testing upgrades still require explicit opt-in.
- Do not auto-reboot unless `--auto-reboot` is set.
- Do not auto-restore third-party repositories after upgrade.
- Do not auto-rename network interfaces or restart network services.
- Do not run `autoremove` automatically after the main upgrade.

## Development Workflow

- Before making a versioned change, back up the files to a local `.codex-backups/vX.Y-<timestamp>/` directory.
- Keep Debian and Ubuntu LTS behavior aligned where possible. Shared behavior belongs in shared helpers, not duplicate distro-specific branches.
- Add tests for policy changes in `tests/smoke.sh`.
- Keep `AGENTS.md`, `CLAUDE.md`, `docs/DEVELOPMENT.md`, `docs/SAFETY.md`, README, CHANGELOG, and Kiro specs aligned when project behavior changes.
- Do not modify `scripts/` unless the task explicitly concerns legacy historical scripts.

## Key Files

| File | Purpose |
|------|---------|
| `distro_upgrade.sh` | Single source of truth; all production logic |
| `tests/smoke.sh` | Non-privileged tests for mappings, flags, safety invariants, and helper behavior |
| `Makefile` | CI entry point wrapping syntax, shellcheck, and smoke tests |
| `.github/workflows/ci.yml` | Runs `make check` on ubuntu-latest |
| `README.md` | User-facing usage, support matrix, and operational guidance |
| `CHANGELOG.md` | Version progress and release notes |
| `docs/DEVELOPMENT.md` | Development workflow, backup rule, and release checklist |
| `docs/SAFETY.md` | Hard safety boundaries |
| `.kiro/specs/` | Kiro requirements/design/task progress snapshots |
| `scripts/` | Legacy historical scripts only |
