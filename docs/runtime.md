# Runtime

Runtime scripts use configured systemd service names:

```bash
AUTH_SERVICE="azerothcore-auth.service"
WORLD_SERVICE="azerothcore-world.service"
```

The service templates in `systemd/` point at:

```text
/opt/acore-manager/current/bin/authserver
/opt/acore-manager/current/bin/worldserver
```

`/opt/acore-manager/current` is the only active runtime path. `/opt/acore-manager/build/staging` is temporary build output and must not be used by systemd services, runtime scripts, or user-managed configs.

To install or update managed service files on an existing server:

```bash
sudo ./bin/acore-manager install-services --force
```

Existing unit files are backed up under `/opt/acore-manager/backups/systemd/<timestamp>/` before replacement. The command reloads systemd and enables/starts `acore-manager-shutdown.service`, but it does not restart live auth/world services.

When `SLEEP_ENABLED=true`, `install-services` also enables the sleep proxy/monitor units and starts them only when the auth backend/public port split is ready.

This is also the command to run after pulling manager updates. See [Updating acore-manager](updating-manager.md).

Runtime configs are shared and linked into the active release:

```text
/opt/acore-manager/current/etc/authserver.conf -> /opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/current/etc/worldserver.conf -> /opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/current/etc/modules -> /opt/acore-manager/shared/configs/modules
```

`switch-release` relinks these paths before starting services.

## Status

```bash
./bin/acore-manager status
./bin/acore-manager validate-runtime
./bin/acore-manager sleep-status
./bin/acore-manager service-status
./bin/acore-manager doctor
```

Shows active release, service status, common ports, disk usage, memory usage, and source commit information.

Verify config links:

```bash
ls -l /opt/acore-manager/current/etc
readlink -f /opt/acore-manager/current/etc/worldserver.conf
readlink -f /opt/acore-manager/current/etc/modules
```

Check for old systemd units that still reference staging:

```bash
sudo ./bin/acore-manager fix-runtime-paths
sudo ./bin/acore-manager fix-runtime-paths --apply
```

The `--apply` mode backs up affected unit files, installs the current-based templates, and runs `systemctl daemon-reload`. It does not restart services.

Runtime start and restart commands check installed systemd units before touching services. If a unit still references `build/staging`, the command fails and tells you to run `fix-runtime-paths` first.

## Service Control

```bash
./bin/acore-manager start
./bin/acore-manager stop
./bin/acore-manager safe-stop
./bin/acore-manager restart
./bin/acore-manager restart-world
./bin/acore-manager restart-auth
```

Full restart order is:

1. stop world
2. stop auth
3. start auth
4. start world

Recommended startup order is database first, then authserver, then worldserver, then client login testing.

## Safe Shutdown And Reboot Handling

Sleep mode can freeze `authserver` or `worldserver` with `SIGSTOP`. A frozen process is still alive in Linux process state `T`, so host shutdown should thaw it before stopping services.

Use:

```bash
./bin/acore-manager sleep-status
sudo ./bin/acore-manager thaw
sudo ./bin/acore-manager safe-stop
sudo ./bin/acore-manager reboot
systemctl status acore-manager-shutdown.service
```

`safe-stop` stops the sleep monitor first, thaws frozen auth/world processes with `SIGCONT`, stops world, stops auth, stops the sleep proxy if present, and verifies that no auth/world process remains. It is idempotent and skips missing optional services.

`reboot` runs `safe-stop` first and refuses to reboot if safe-stop fails. Use `--force` only when you have accepted the risk:

```bash
sudo ./bin/acore-manager reboot --force
```

The shutdown hook is installed as `acore-manager-shutdown.service`. It uses systemd's `ExecStop` path to run:

```bash
/opt/acore-manager/bin/acore-manager safe-stop --host-shutdown
```

It does not require auth/world services and must not start AzerothCore during host shutdown.

## Automatic Scheduled Restarts

`acore-manager` can install an optional cron job that runs the normal restart workflow. It is disabled by default because it stops and starts the live realm.

Default schedule:

```bash
AUTO_RESTART_CRON="20 4 * * 3"  # Wednesday 04:20 server local time
AUTO_RESTART_USER="root"
```

Enable it in `config/local/manager.conf`:

```bash
AUTO_RESTART_ENABLED="true"
```

Install or update the cron file:

```bash
sudo ./bin/acore-manager install-services --force
cat /etc/cron.d/acore-manager-restart
```

The cron entry runs:

```bash
/opt/acore-manager/bin/acore-manager scheduled-restart
```

The command path is rendered from `ACM_ROOT`; the default is `/opt/acore-manager/bin/acore-manager`. `scheduled-restart` calls the existing `restart` workflow, including the sleep thaw step, so restart order remains stop world, stop auth, start auth, start world.

To preview the rendered cron file without touching `/etc`:

```bash
./scripts/setup/acore-install-services.sh --print-auto-restart-cron
```

To disable automatic restarts, set `AUTO_RESTART_ENABLED="false"` and rerun:

```bash
sudo ./bin/acore-manager install-services --force
```

## Logs

```bash
./bin/acore-manager logs-world
./bin/acore-manager logs-auth
./bin/acore-manager logs --service world --lines 100
./bin/acore-manager last-errors
```

`last-errors` filters recent logs for useful terms such as `ERROR`, `WARN`, `CRASH`, `DBUpdater`, `failed`, and `exception`.

Direct journal checks:

```bash
journalctl -u azerothcore-auth.service -n 100 --no-pager
journalctl -u azerothcore-world.service -n 100 --no-pager
```

## Ports

Common AzerothCore ports:

```text
3724  authserver
8085  worldserver
```

With idle sleep enabled, the sleep proxy listens on public auth port `3724` and forwards to the real authserver on backend port `3725`. See [Idle Sleep](power-sleep.md).

Check listeners:

```bash
ss -ltnp | grep -E '3724|8085'
```

## Common Runtime Failures

- Missing `/opt/acore-manager/current`: create and switch to a release.
- Missing data files: copy `dbc`, `maps`, `vmaps`, and `mmaps` into `/opt/acore-manager/shared/data`.
- Missing configs: prepare `authserver.conf` and `worldserver.conf` from release `.conf.dist` files.
- Broken config links: run `sudo ./bin/acore-manager link-configs`.
- DataDir points at a release path: set it to `/opt/acore-manager/shared/data` in shared `worldserver.conf`.
- DB failures: run `./bin/acore-manager db-check` and check credentials in `config/local/db.conf`.
- Client cannot connect: check realmlist, firewall, auth port `3724`, world port `8085`, and service logs.

See [Command Reference](commands.md) for all wrapper commands.
