# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current Project State

- Project display name: DistroLift.
- Current production script: `distro_upgrade.sh` v3.8.4 (`SCRIPT_DATE=2026-10-13`).
- Production scope: Debian 11 -> 12 -> 13 and Ubuntu LTS 20.04 -> 22.04 -> 24.04 -> 26.04.
- Ubuntu 26.04 codename is `resolute`.
- Stable adjacent upgrades are automation-first and continue by default; use `--require-confirm` to restore manual confirmation.
- Debian 13 -> 14 remains gated by `--allow-testing` and requires explicit `YES` confirmation unless forced.
- `--auto-reboot` is opt-in only. Successful upgrades do not reboot automatically by default.
- `--preflight` is a quiet deep-check mode. Default real upgrades show the DistroLift intro/risk banner as the first screen and require `YES` before system checks; `--force` skips this confirmation for explicit automation.
- Low-memory / NAT VPS handling is part of v3.7: physical memory, swap, root free space, and `/boot` free space are checked before sources are changed. Reasonable low-memory systems may get a temporary swap file that is removed on exit; extremely small systems are rejected before upgrade.
- GRUB handling (v3.8.2): the upgrade transaction never writes a boot sector. `pre_upgrade_preparation` preseeds `grub-pc` with an empty `install_devices` plus `install_devices_empty=true`, so `grub-pc`'s postinst only regenerates `grub.cfg` and a `grub-install` failure can no longer abort `dist-upgrade`. After the upgrade, `verify_boot_loader` runs one controlled, fully logged `grub-install` for a single unambiguous BIOS boot disk only; if the disk is ambiguous, the architecture is unsupported, or the write fails, it does not abort - it sets `BOOTLOADER_ACTION_REQUIRED`, warns, blocks auto/quick reboot, and the upgrade path exits non-zero telling the user to run `--fix-grub`.

## Validation and Tests

This is a Bash script repository; there is no compilation, packaging, or generated build artifact.

Install the local validation tools on Debian/Ubuntu with:

```bash
sudo apt-get install bash shellcheck make git
```

Run the same aggregate validation target used by CI:

```bash
make check
```

`make check` runs syntax checks, ShellCheck, and smoke tests. It is fully CI-equivalent only when `shellcheck` is installed; the Makefile skips static analysis when it is unavailable, while GitHub Actions installs it explicitly.

Individual validation commands:

```bash
make syntax
make shellcheck
make test
bash tests/smoke.sh
```

- `make syntax` checks the two root entry scripts plus the single-level `scripts/*.sh` and `tests/*.sh` globs.
- `make shellcheck` checks `distro_upgrade.sh`, `debian_upgrade.sh`, and `tests/*.sh`; it intentionally excludes historical scripts under `scripts/`.
- `make test` and `bash tests/smoke.sh` both run the complete smoke harness.

There is no test-name or filter interface: `tests/smoke.sh` is one sequential harness. The smallest supported behavioral test is the full smoke script. To reproduce one existing pure-function assertion while debugging, follow the harness's source pattern; for example:

```bash
bash -c '
source ./distro_upgrade.sh
trap - EXIT
[[ "$(get_next_version 12 debian)" == "13" ]]
'
```

This is a manual assertion, not a named test runner. The `trap - EXIT` is required because sourcing the production script installs an exit cleanup trap.

Smoke tests are non-privileged. They cover version/document metadata, the compatibility wrapper, Debian/Ubuntu policy mappings, Ubuntu mirror and `ubuntu-ports` selection, argument ordering and action conflicts, low-resource gates, source-backup ordering, self-update invariants, GRUB topology detection, and hard safety patterns.

On Windows, Git Bash can run syntax checks and smoke tests. Never use a real upgrade or privileged repair/cleanup action as a developer test on the host. Exercise APT, GRUB, network, reboot, and other operational paths only in disposable Debian/Ubuntu VMs with snapshots.

## Architecture

### Production Boundaries

- `distro_upgrade.sh` is the single source of truth for production behavior.
- `debian_upgrade.sh` is only a compatibility wrapper that `exec`s the main script; do not duplicate logic into it.
- `scripts/` contains historical reference implementations. They may preserve obsolete or unsafe behavior and are not production entry points; do not modify them unless the task explicitly concerns legacy scripts.
- The main script is guarded with `[[ "${BASH_SOURCE[0]}" == "$0" ]]`, allowing smoke tests to source its functions without invoking `main()`.

### Top-Level Dispatch

`main()` parses all arguments before executing an action, rejects conflicting action modes, and dispatches `--help`, `--version`, `--check`, `--preflight`, `--cleanup`, `--self-update`, `--fix-only`, or `--fix-grub` before the normal upgrade path.

The default real-upgrade path is:

```text
main()
  -> parse arguments and dispatch action modes
  -> show_initial_startup_banner()
  -> set_mirror()
  -> check_root()
  -> check_system()
  -> detect OS
  -> Debian: main_upgrade()
     Ubuntu: ubuntu_upgrade()
```

`--preflight` deliberately bypasses the normal startup banner/confirmation and performs checks without changing APT sources.

### Upgrade Orchestration

`main_upgrade()` and `ubuntu_upgrade()` have distro-specific version/source handling but share the safety-critical helpers:

```text
read current version and calculate the adjacent target
  -> show_startup_risk_banner()
  -> confirm_stable_upgrade() or apply the Debian testing gate
  -> save_network_config()
  -> backup_primary_sources_list()
  -> pre_upgrade_preparation(target_codename, os_id)
       -> stop_apt_units()
       -> wait_for_apt_locks()
       -> check_upgrade_capacity()
       -> prepare_temporary_swap()
       -> check_runtime_injection()
       -> check_initramfs_health()
       -> dpkg configure / fix-broken / audit hard gates
       -> refresh the distro keyring from current trusted sources
       -> clean_apt_sources()
       -> preseed grub-pc to skip in-transaction grub-install (empty install_devices + install_devices_empty=true)
  -> write the distro-specific /etc/apt/sources.list
  -> apt_update_with_recovery(keyring)
  -> apt-get upgrade
  -> apt-get dist-upgrade
  -> post_upgrade_fixes()
       -> compare interface names and warn only
       -> build only a missing latest initramfs
       -> refresh GRUB configuration
       -> verify_boot_loader(): one controlled grub-install for a single unambiguous BIOS disk;
          on ambiguity/failure set BOOTLOADER_ACTION_REQUIRED, warn, do not abort
  -> verify the target version
  -> if BOOTLOADER_ACTION_REQUIRED: print the --fix-grub banner and exit non-zero
  -> reboot only when --auto-reboot is set (safe_reboot also refuses while BOOTLOADER_ACTION_REQUIRED)
```

Back up the primary sources list before `pre_upgrade_preparation()`: preparation disables extra sources and may edit the existing main list, and backup failure is a hard stop.

### Version Policy

`get_version_info()` and `get_next_version()` are the central policy interfaces over these arrays:

- Debian: `DEBIAN_CODENAME`, `DEBIAN_STATUS`, `DEBIAN_NEXT`.
- Ubuntu LTS: `UBUNTU_CODENAME`, `UBUNTU_STATUS`, `UBUNTU_NEXT`.

`STABLE_ONLY=1` blocks Debian 13 -> 14; `--allow-testing` changes it to `0` and retains the high-risk confirmation. Ubuntu supports only mapped adjacent LTS upgrades and does not use the Debian testing gate. Ubuntu mirror selection also depends on architecture because non-primary architectures use `ubuntu-ports`.

When adding a release, update the mapping arrays, `SCRIPT_VERSION`, `SCRIPT_DATE`, source generation, README support matrix, CHANGELOG, and smoke assertions together.

### APT Recovery and Cleanup

Before switching repositories, extra `.list` and Deb822 `.sources` files are backed up and renamed with `.disabled-by-distrolift`; they are not restored automatically. Generated source lists contain binary repositories only, never `deb-src` or `trusted=yes`.

`apt_update_with_recovery()` classifies update failures. GPG, signature, unsigned-repository, and missing-key errors stop immediately. For any other update failure, it logs whether 404/Release-file errors were detected, disables residual extra sources, and retries once; it never bypasses verification.

The script stores per-run diagnostics in a temporary run directory. Its exit trap removes only swap created by this run, restarts only APT units stopped by this run, deletes successful run data, and retains failure logs. Do not add repeated package-manager repair attempts to the exit path.

### Self-Update Trust Chain

`--self-update` uses the mutable main-branch URL only for version discovery. Installation content comes from the discovered fixed tag and must pass GitHub/CDN SHA-256 equality, embedded version matching, `bash -n`, mandatory current-script backup, permission preservation, and same-directory atomic replacement. Backup failure must leave the current script untouched.

## Hard Safety Invariants

- Never delete APT/dpkg lock files; stop relevant units and wait for locks.
- Keep capacity, runtime-injection, initramfs, dpkg configure/fix-broken/audit, and sources-backup gates before source replacement.
- Never bypass repository signatures with `trusted=yes` or similar options.
- The `dist-upgrade` transaction must never write a boot sector: keep the `grub-pc` preseed that empties `install_devices` and sets `install_devices_empty=true`, so a `grub-install` failure cannot abort the upgrade. `grub-install` runs only in `verify_boot_loader` (post-upgrade, single unambiguous BIOS disk, non-fatal) and in explicit `--fix-grub` (which must check its real exit code).
- Do not generate `deb-src` entries.
- Do not auto-restore third-party repositories after upgrade.
- Do not rename network interfaces or restart network services automatically.
- Do not run `autoremove` during the main upgrade; it belongs only to explicit cleanup.
- Do not auto-reboot unless `--auto-reboot` is set.
- Stable upgrades may be automatic, but Debian testing upgrades require explicit opt-in and the additional confirmation.
- Self-update must use fixed-tag content verification and must not replace the current script if its backup fails.

## Development Workflow

- Before editing files for a versioned change, copy every file that will be modified into `.codex-backups/vX.Y-<timestamp>/`. The backup must capture the pre-change state; follow `docs/DEVELOPMENT.md` for the exact procedure.
- Keep Debian and Ubuntu behavior aligned where possible. Shared behavior belongs in shared helpers, not duplicated distro branches.
- Add or update `tests/smoke.sh` assertions for policy and safety changes; do not weaken tests to match incorrect behavior.
- Triage user-provided information before publishing it: keep stable, verified, actionable material in user-facing docs and leave temporary context, preferences, screenshots, and unverified assumptions out.
- When project behavior changes, keep `AGENTS.md`, `CLAUDE.md`, `docs/DEVELOPMENT.md`, `docs/SAFETY.md`, README, and CHANGELOG aligned as applicable.
- A self-update release requires an immutable `v<SCRIPT_VERSION>` Git tag after all version metadata and validation are complete; `main` is only the discovery channel.

## Cross-File Contract

| File | Role |
|------|------|
| `distro_upgrade.sh` | Production behavior and policy source of truth |
| `debian_upgrade.sh` | Backward-compatible wrapper only |
| `tests/smoke.sh` | Non-privileged policy, helper, metadata, and safety regression harness |
| `Makefile` | Local and CI validation entry points |
| `.github/workflows/ci.yml` | Installs ShellCheck and runs `make check` |
| `README.md` | User-facing usage, support matrix, and operational contract |
| `docs/DEVELOPMENT.md` | Backup, VM testing, and release synchronization workflow |
| `docs/SAFETY.md` | Concise high-risk operation boundaries |
| `CHANGELOG.md` | Released behavior changes |
| `AGENTS.md` | Parallel agent guidance that should remain behaviorally aligned with this file |
| `scripts/` | Legacy reference only |
