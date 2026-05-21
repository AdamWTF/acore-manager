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

Bootstrap installs these templates when possible, but does not enable or start them. If needed, install them manually:

```bash
sudo cp systemd/azerothcore-auth.service /etc/systemd/system/azerothcore-auth.service
sudo cp systemd/azerothcore-world.service /etc/systemd/system/azerothcore-world.service
sudo systemctl daemon-reload
sudo systemctl enable azerothcore-auth.service
sudo systemctl enable azerothcore-world.service
```

Prepare databases, data files, and configs before starting services. See [Full Server Setup](full-server-setup.md).

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

## Service Control

```bash
./bin/acore-manager start
./bin/acore-manager stop
./bin/acore-manager restart
./bin/acore-manager restart-world
./bin/acore-manager restart-auth
```

Full restart order is:

1. stop world
2. stop auth
3. start auth
4. start world

Direct systemd equivalents:

```bash
sudo systemctl start azerothcore-auth.service
sudo systemctl start azerothcore-world.service
sudo systemctl stop azerothcore-world.service
sudo systemctl stop azerothcore-auth.service
systemctl status azerothcore-auth.service --no-pager
systemctl status azerothcore-world.service --no-pager
```

Recommended startup order is database first, then authserver, then worldserver, then client login testing.

## Logs

```bash
./bin/acore-manager logs-world
./bin/acore-manager logs-auth
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
