# Commands

This page lists the implemented `bin/acore-manager` commands. It also lists integration helper scripts that are not exposed through the wrapper.

Risk levels:

- Read-only: should not change the system.
- Safe: writes backups, checks, or local artifacts without touching running services.
- Disruptive: starts/stops services, switches releases, or runs long builds.
- Destructive: deletes, prunes, restores, imports, or otherwise changes live data. These commands require explicit flags such as `--apply`.

## Setup And Config

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `help`, `-h`, `--help` | Print wrapper usage. | Built into `bin/acore-manager` | No | Read-only | `./bin/acore-manager --help` |
| `validate` | Validate config variables, commands, service names, and path status. | `scripts/config/acore-validate-config.sh` | Usually no | Read-only | `./bin/acore-manager validate` |
| `validate-runtime` | Validate active release, shared config links, and data checks. | `scripts/config/acore-validate-runtime.sh` | Usually no | Read-only | `./bin/acore-manager validate-runtime` |
| `prepare-configs` | Seed missing shared runtime configs from release templates. | `scripts/config/acore-prepare-configs.sh` | Usually yes | Safe | `sudo ./bin/acore-manager prepare-configs <release-name>` |
| `link-configs` | Link shared configs into the active release. | `scripts/config/acore-link-shared-configs.sh` | Usually yes | Safe | `sudo ./bin/acore-manager link-configs` |
| `check-data` | Check shared data directories and `worldserver.conf` `DataDir`. | `scripts/config/acore-check-data.sh` | No | Read-only | `./bin/acore-manager check-data` |
| `config-diff` | Compare live configs against matching `.dist` files when available. | `scripts/config/acore-config-diff.sh` | Usually no | Read-only | `./bin/acore-manager config-diff` |
| `install-services` | Install/update managed systemd units with backups and enable the shutdown hook. | `scripts/setup/acore-install-services.sh` | Yes | Safe; does not restart auth/world | `sudo ./bin/acore-manager install-services --force` |
| `doctor` | Run an aggregate health report across config, runtime, DB, sleep, services, logs, disk, and backups. | `scripts/diagnostics/acore-doctor.sh` | No | Read-only | `./bin/acore-manager doctor` |

Direct setup scripts:

| Script | Purpose | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- |
| `scripts/setup/acore-bootstrap.sh` | Install dependencies, create directories/user/group, copy local examples, install service templates. | Yes | Disruptive | `sudo ./scripts/setup/acore-bootstrap.sh` |
| `scripts/setup/acore-fix-permissions.sh` | Restore executable bits for scripts and wrapper. | Sometimes | Safe | `sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh` |

## Source And Modules

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `update-source` | Clone or update AzerothCore source. | `scripts/source/acore-update-source.sh` | Depends on install ownership | Safe | `./bin/acore-manager update-source` |
| `update-modules` | Clone or update configured modules. | `scripts/source/acore-update-modules.sh` | Depends on install ownership | Safe | `./bin/acore-manager update-modules` |

## Build And Release

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `build` | Build AzerothCore into `BUILD_DIR/staging`. | `scripts/build/acore-build.sh` | Depends on install ownership | Disruptive: long-running CPU/disk work | `./bin/acore-manager build` |
| `clean-build` | Remove generated build artifacts only. | `scripts/build/acore-clean-build.sh` | Depends on build directory ownership | Safe; deletes only build output | `./bin/acore-manager clean-build --dry-run` |
| `rebuild` | Run the build workflow, optionally after `clean-build`. | `scripts/build/acore-rebuild.sh` | Depends on build directory ownership | Disruptive: long-running CPU/disk work | `./bin/acore-manager rebuild --clean` |
| `create-release` | Create a timestamped release from staging. | `scripts/build/acore-create-release.sh` | Depends on install ownership | Safe | `./bin/acore-manager create-release` |
| `release-latest` | Run validate, DB check, source/module update, build, release, shared config preparation, optional config backup, switch, and status. Use `--clean` to remove generated build artifacts first. | `scripts/build/acore-release-latest.sh` | Usually yes | Disruptive | `sudo ./bin/acore-manager release-latest --clean` |
| `list-releases` | List releases and mark the active one. | `scripts/releases/acore-list-releases.sh` | No | Read-only | `./bin/acore-manager list-releases` |
| `switch-release` | Switch `/opt/acore-manager/current` and restart services safely. | `scripts/releases/acore-switch-release.sh` | Yes | Disruptive | `sudo ./bin/acore-manager switch-release <release-name>` |
| `rollback` | Switch to the previous release and restart services. | `scripts/releases/acore-rollback.sh` | Yes | Disruptive | `sudo ./bin/acore-manager rollback` |
| `release-report` | Show release binaries, metadata, config templates, and active status. | `scripts/releases/acore-release-report.sh` | No | Read-only | `./bin/acore-manager release-report <release-name>` |
| `prune-releases` | Prune old releases; dry-run by default and `--apply` required for deletion. | `scripts/releases/acore-prune-releases.sh` | Depends on release ownership | Destructive with `--apply` | `./bin/acore-manager prune-releases --dry-run` |

## Runtime And Services

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `start` | Start auth then world services. | `scripts/runtime/acore-start.sh` | Yes | Disruptive | `sudo ./bin/acore-manager start` |
| `stop` | Stop world then auth services. | `scripts/runtime/acore-stop.sh` | Yes | Disruptive | `sudo ./bin/acore-manager stop` |
| `safe-stop` | Stop sleep monitor, thaw frozen auth/world processes, stop services, and verify shutdown-safe state. | `scripts/runtime/acore-safe-stop.sh` | Yes | Disruptive but idempotent | `sudo ./bin/acore-manager safe-stop` |
| `reboot` | Run `safe-stop`, then reboot with `systemctl reboot`; refuses reboot on failure unless `--force` is used. | `scripts/runtime/acore-reboot.sh` | Yes | Disruptive | `sudo ./bin/acore-manager reboot` |
| `restart` | Stop world/auth, then start auth/world. | `scripts/runtime/acore-restart.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart` |
| `scheduled-restart` | Run the normal restart workflow from cron. | `scripts/runtime/acore-scheduled-restart.sh` | Yes | Disruptive | `/opt/acore-manager/bin/acore-manager scheduled-restart` |
| `restart-world` | Restart world service only. | `scripts/runtime/acore-restart-world.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart-world` |
| `restart-auth` | Restart auth service only. | `scripts/runtime/acore-restart-auth.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart-auth` |
| `sleep-status` | Show idle sleep config, services, ports, world connections, and process state. | `scripts/power/acore-sleep-status.sh` | Sometimes for full service details | Read-only | `./bin/acore-manager sleep-status` |
| `thaw` | Resume frozen auth/world processes; alias for `sleep-thaw`. | `scripts/power/acore-sleep-thaw.sh` | Usually yes | Safe | `sudo ./bin/acore-manager thaw` |
| `sleep-thaw` | Resume frozen auth/world processes. | `scripts/power/acore-sleep-thaw.sh` | Usually yes | Safe | `sudo ./bin/acore-manager sleep-thaw` |
| `sleep-freeze` | Freeze auth/world processes after readiness checks. Use `--force` for an immediate manual freeze. | `scripts/power/acore-sleep-freeze.sh` | Usually yes | Disruptive | `sudo ./bin/acore-manager sleep-freeze` |
| `fix-runtime-paths` | Check installed systemd units for `build/staging` runtime paths; `--apply` reinstalls current-based templates. | `scripts/runtime/acore-fix-runtime-paths.sh` | Yes | Safe without `--apply`; disruptive config change with `--apply` | `sudo ./bin/acore-manager fix-runtime-paths --apply` |
| `service-status` | Show auth/world/sleep/proxy/shutdown/cron status in one view. | `scripts/runtime/acore-service-status.sh` | Sometimes for full service details | Read-only | `./bin/acore-manager service-status` |

## Logs And Status

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `status` | Show active release, service status, common ports, disk, memory, and source commit. | `scripts/runtime/acore-status.sh` | Sometimes for full service details | Read-only | `./bin/acore-manager status` |
| `logs-world` | Follow world service journal logs. | `scripts/logs/acore-logs-world.sh` | Sometimes | Read-only | `./bin/acore-manager logs-world` |
| `logs-auth` | Follow auth service journal logs. | `scripts/logs/acore-logs-auth.sh` | Sometimes | Read-only | `./bin/acore-manager logs-auth` |
| `last-errors` | Show recent auth/world warnings and errors. | `scripts/logs/acore-last-errors.sh` | Sometimes | Read-only | `./bin/acore-manager last-errors` |
| `logs` | Show logs for a selected managed service. | `scripts/logs/acore-logs.sh` | Sometimes | Read-only | `./bin/acore-manager logs --service world --lines 100` |

## Database

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `db-check` | Check MySQL connectivity, version, and configured DB presence. | `scripts/db/acore-db-check.sh` | No, if DB credentials are readable | Read-only | `./bin/acore-manager db-check` |
| `db-backup` | Back up configured auth/world/characters DBs with `mysqldump`. | `scripts/db/acore-db-backup.sh` | Depends on backup directory ownership | Safe | `./bin/acore-manager db-backup` |
| `db-init` | Create configured databases when missing; dry-run unless `--apply`. | `scripts/db/acore-db-init.sh` | Depends on DB grants | Safe with `--dry-run`; live DB change with `--apply` | `./bin/acore-manager db-init --dry-run` |
| `db-import` | Import an explicit SQL file into one configured database. | `scripts/db/acore-db-import.sh` | Depends on DB grants | Safe with `--dry-run`; live DB change with `--apply` | `./bin/acore-manager db-import dump.sql --database auth --dry-run` |
| `db-maintenance` | Show read-only table status and recommended mysqlcheck commands. | `scripts/db/acore-db-maintenance.sh` | No, if DB credentials are readable | Read-only | `./bin/acore-manager db-maintenance` |

## Backups

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `config-backup` | Back up shared configs, `config/local`, managed systemd units, and restart cron when present. | `scripts/config/acore-config-backup.sh` | Sometimes | Safe | `./bin/acore-manager config-backup` |
| `backup-all` | Run config and DB backups and write a combined manifest. | `scripts/backup/acore-backup-all.sh` | Depends on backup ownership and DB credentials | Safe | `./bin/acore-manager backup-all` |
| `list-backups` | List config, DB, systemd, cron, reset, and combined backups. | `scripts/backup/acore-list-backups.sh` | No | Read-only | `./bin/acore-manager list-backups` |
| `restore-config` | Restore config/systemd/cron metadata from an explicit backup path. | `scripts/backup/acore-restore-config.sh` | Yes with `--apply` | Safe with `--dry-run`; writes files with `--apply` | `./bin/acore-manager restore-config <backup-path> --dry-run` |
| `restore-db` | Restore SQL dumps from an explicit backup path. | `scripts/backup/acore-restore-db.sh` | Depends on DB grants | Safe with `--dry-run`; live DB change with `--apply` | `./bin/acore-manager restore-db <backup-path> --database all --dry-run` |
| `reset-instance` | Destructively reset selected instance areas. | `scripts/setup/acore-reset-instance.sh` | Yes with `--apply` | Destructive with `--apply` | `sudo ./bin/acore-manager reset-instance --dry-run --binaries` |

## OliveTin And Integrations

These scripts are optional and are not required for core server management.

| Script | Purpose | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- |
| `scripts/integrations/acore-validate-olivetin-config.sh` | Check OliveTin example commands exist in `bin/acore-manager`. | No | Read-only | `./scripts/integrations/acore-validate-olivetin-config.sh` |
| `scripts/integrations/acore-render-olivetin-config.sh` | Back up and install `/etc/OliveTin/config.yaml`. | Yes | Safe | `sudo ./scripts/integrations/acore-render-olivetin-config.sh` |
| `scripts/integrations/acore-install-olivetin.sh` | Install OliveTin, render config, enable and start OliveTin. | Yes | Disruptive | `sudo ./scripts/integrations/acore-install-olivetin.sh` |

See [Idle Sleep](power-sleep.md) for the default sleep proxy and monitor services.
