# Commands

This page lists the implemented `bin/acore-manager` commands. It also lists integration helper scripts that are not exposed through the wrapper.

Risk levels:

- Read-only: should not change the system.
- Safe: writes backups, checks, or local artifacts without touching running services.
- Disruptive: starts/stops services, switches releases, or runs long builds.
- Destructive: deletes or prunes data. No destructive command is currently exposed by `bin/acore-manager`.

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
| `create-release` | Create a timestamped release from staging. | `scripts/build/acore-create-release.sh` | Depends on install ownership | Safe | `./bin/acore-manager create-release` |
| `release-latest` | Run validate, DB check, source/module update, build, release, shared config preparation, optional config backup, switch, and status. | `scripts/build/acore-release-latest.sh` | Usually yes | Disruptive | `sudo ./bin/acore-manager release-latest` |
| `list-releases` | List releases and mark the active one. | `scripts/releases/acore-list-releases.sh` | No | Read-only | `./bin/acore-manager list-releases` |
| `switch-release` | Switch `/opt/acore-manager/current` and restart services safely. | `scripts/releases/acore-switch-release.sh` | Yes | Disruptive | `sudo ./bin/acore-manager switch-release <release-name>` |
| `rollback` | Switch to the previous release and restart services. | `scripts/releases/acore-rollback.sh` | Yes | Disruptive | `sudo ./bin/acore-manager rollback` |

Direct release script not exposed by the wrapper:

| Script | Purpose | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- |
| `scripts/releases/acore-prune-releases.sh` | Prune older releases while keeping the active release and recent releases. | Depends on release ownership | Destructive | `sudo ./scripts/releases/acore-prune-releases.sh` |

## Runtime And Services

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `start` | Start auth then world services. | `scripts/runtime/acore-start.sh` | Yes | Disruptive | `sudo ./bin/acore-manager start` |
| `stop` | Stop world then auth services. | `scripts/runtime/acore-stop.sh` | Yes | Disruptive | `sudo ./bin/acore-manager stop` |
| `restart` | Stop world/auth, then start auth/world. | `scripts/runtime/acore-restart.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart` |
| `restart-world` | Restart world service only. | `scripts/runtime/acore-restart-world.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart-world` |
| `restart-auth` | Restart auth service only. | `scripts/runtime/acore-restart-auth.sh` | Yes | Disruptive | `sudo ./bin/acore-manager restart-auth` |
| `fix-runtime-paths` | Check installed systemd units for `build/staging` runtime paths; `--apply` reinstalls current-based templates. | `scripts/runtime/acore-fix-runtime-paths.sh` | Yes | Safe without `--apply`; disruptive config change with `--apply` | `sudo ./bin/acore-manager fix-runtime-paths --apply` |

## Logs And Status

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `status` | Show active release, service status, common ports, disk, memory, and source commit. | `scripts/runtime/acore-status.sh` | Sometimes for full service details | Read-only | `./bin/acore-manager status` |
| `logs-world` | Follow world service journal logs. | `scripts/logs/acore-logs-world.sh` | Sometimes | Read-only | `./bin/acore-manager logs-world` |
| `logs-auth` | Follow auth service journal logs. | `scripts/logs/acore-logs-auth.sh` | Sometimes | Read-only | `./bin/acore-manager logs-auth` |
| `last-errors` | Show recent auth/world warnings and errors. | `scripts/logs/acore-last-errors.sh` | Sometimes | Read-only | `./bin/acore-manager last-errors` |

## Database

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `db-check` | Check MySQL connectivity, version, and configured DB presence. | `scripts/db/acore-db-check.sh` | No, if DB credentials are readable | Read-only | `./bin/acore-manager db-check` |
| `db-backup` | Back up configured auth/world/characters DBs with `mysqldump`. | `scripts/db/acore-db-backup.sh` | Depends on backup directory ownership | Safe | `./bin/acore-manager db-backup` |

## Backups

| Command | Purpose | Script | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- | --- |
| `config-backup` | Back up shared configs, `config/local`, and installed service files when present. | `scripts/config/acore-config-backup.sh` | Sometimes | Safe | `./bin/acore-manager config-backup` |
| `db-backup` | Back up configured MySQL databases. | `scripts/db/acore-db-backup.sh` | Depends on backup directory ownership | Safe | `./bin/acore-manager db-backup` |

## OliveTin And Integrations

These scripts are optional and are not required for core server management.

| Script | Purpose | Needs sudo? | Risk | Example |
| --- | --- | --- | --- | --- |
| `scripts/integrations/acore-validate-olivetin-config.sh` | Check OliveTin example commands exist in `bin/acore-manager`. | No | Read-only | `./scripts/integrations/acore-validate-olivetin-config.sh` |
| `scripts/integrations/acore-render-olivetin-config.sh` | Back up and install `/etc/OliveTin/config.yaml`. | Yes | Safe | `sudo ./scripts/integrations/acore-render-olivetin-config.sh` |
| `scripts/integrations/acore-install-olivetin.sh` | Install OliveTin, render config, enable and start OliveTin. | Yes | Disruptive | `sudo ./scripts/integrations/acore-install-olivetin.sh` |

## Troubleshooting Gaps

Useful commands that are not currently implemented:

- `install-services`: bootstrap installs service templates, but there is no separate wrapper command just for service installation.
- `check-db` / `backup-db`: use the implemented `db-check` and `db-backup` command names.
