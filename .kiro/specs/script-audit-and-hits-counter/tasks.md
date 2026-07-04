# Implementation Plan

## Overview

This task list reflects the current completed progress for DistroLift Auto Upgrade (`distro_upgrade.sh` v3.7.1). The earlier v3.6 script-audit work, Ubuntu support, Ubuntu arm64 mirror fix, v3.7 automation / VPS optimization, and v3.7.1 startup risk confirmation have all been implemented.

## Completed Tasks

- [x] 1. Preserve current production entry point
  - `distro_upgrade.sh` is the only supported production script.
  - `debian_upgrade.sh` remains compatibility forwarding only.
  - Legacy `scripts/` files remain historical reference only.

- [x] 2. Fix original script audit bugs
  - Fixed cleanup disk percentage display.
  - Removed bash keyword variable conflict.
  - Prevented ERR trap recursion.
  - Added placeholder for empty boot disk output.
  - Improved EFI directory selection.
  - Added self-update write permission guard.

- [x] 3. Add and preserve running statistics
  - README includes visitor badge.
  - Script statistics fetch is non-blocking and does not affect upgrade flow.

- [x] 4. Implement Debian current policy
  - Debian 11 -> 12 -> 13 supported.
  - Debian 13 -> 14 gated by `--allow-testing`.
  - Stable-only remains the default.

- [x] 5. Implement Ubuntu LTS support
  - Ubuntu 20.04 -> 22.04 -> 24.04 -> 26.04 supported.
  - Ubuntu 26.04 codename is `resolute`.
  - `--check` and `--version` are distro-aware.
  - Ubuntu uses Ubuntu source format and `ubuntu-keyring`.

- [x] 6. Fix Ubuntu arm64 / ports mirror behavior
  - `get_ubuntu_mirror_info()` selects `ubuntu-ports` for arm64 and other ports architectures.
  - Default amd64 uses `archive.ubuntu.com` plus `security.ubuntu.com`.
  - China mirrors use the correct `ubuntu` or `ubuntu-ports` path by architecture.

- [x] 7. Implement v3.7 automation policy
  - Stable adjacent upgrades continue automatically by default.
  - `--require-confirm` restores stable-path manual confirmation.
  - Testing upgrades still require explicit high-risk confirmation.
  - `--auto-reboot` is explicit opt-in; default is no automatic reboot.

- [x] 8. Implement low-memory / NAT VPS safeguards
  - Added resource gate before source changes.
  - Added physical memory, Swap, root disk, and `/boot` checks.
  - Added temporary Swap creation for reasonable low-memory systems.
  - Added cleanup for temporary Swap on exit.
  - Added tests for 512MB upgradeable-with-swap and 256MB rejected scenarios.

- [x] 9. Unify Debian / Ubuntu recovery flow
  - Added shared `apt_update_with_recovery()`.
  - Handles GPG / keyring / 404 / Release-file recovery.
  - Debian uses `debian-archive-keyring`.
  - Ubuntu uses `ubuntu-keyring`.
  - Ubuntu upgrade flow now uses shared post-upgrade fixes.

- [x] 10. Update user and developer docs
  - README updated for v3.7 behavior.
  - CHANGELOG updated for v3.7 progress.
  - `docs/DEVELOPMENT.md` updated with version-before-backup workflow.
  - `docs/SAFETY.md` updated with automation, reboot, and low-memory boundaries.
  - `AGENTS.md` and `CLAUDE.md` aligned to the same current facts.
  - Kiro requirements/design/tasks aligned with current progress.

- [x] 11. Add project branding and startup risk confirmation
  - Project display name changed to DistroLift Auto Upgrade.
  - Help output and README use the new project name.
  - Real upgrade paths show a startup risk confirmation before source changes.
  - Stable upgrade flow remains automated after the first confirmation.
  - `--force` skips startup confirmation for explicit automation.

- [x] 12. Validate locally available test suite
  - `bash -n distro_upgrade.sh`
  - `bash -n scripts/*.sh tests/*.sh`
  - `bash tests/smoke.sh`
  - `git diff --check`

## Environment Limitation

On the current Windows Git Bash environment, `make` and `shellcheck` are not installed, and WSL has no configured Linux distribution. Therefore `make check` cannot be executed exactly in this environment. The Makefile-equivalent syntax and smoke-test path has been run manually.

## Remaining Release Validation

- [ ] Run `make check` in a Debian / Ubuntu VM with `make` and `shellcheck`.
- [ ] Snapshot-test Debian 11 -> 12 and 12 -> 13.
- [ ] Snapshot-test Ubuntu 20.04 -> 22.04, 22.04 -> 24.04, and 24.04 -> 26.04.
- [ ] Validate BIOS and UEFI VM paths.
- [ ] Validate official mirrors and at least one configured mirror option.
- [ ] Validate Ubuntu ports architecture source generation.
- [ ] Validate low-memory temporary Swap behavior on an isolated VPS-like VM.
- [ ] Validate too-small NAT VPS rejection before APT sources are changed.

## Notes

- New distro support should wait until Debian and Ubuntu paths have enough VM evidence.
- Do not mix additional operating systems into v3.7 maintenance work.
- Any future versioned change should start with a local backup under `.codex-backups/`.
