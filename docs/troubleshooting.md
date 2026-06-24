# Troubleshooting

For the complete first-server flow, including data files, configs, databases, services, firewall, and client connection, see [Full Server Setup](full-server-setup.md).

## Validate First

```bash
./bin/acore-manager validate
```

Fix missing commands, config values, or path issues reported by validation before running builds or release switches.

## Script Permission Denied

If a script fails with `Permission denied`, fix executable bits:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```

Or:

```bash
sudo find /opt/acore-manager/scripts -type f -name "*.sh" -exec chmod +x {} \;
sudo chmod +x /opt/acore-manager/bin/acore-manager 2>/dev/null || true
```

## MySQL Connection Fails

Check `config/local/db.conf`:

```bash
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

For remote MySQL, confirm the host is reachable from the server running `acore-manager`. For SSH tunnels, `MYSQL_HOST="127.0.0.1"` is common.

Run:

```bash
./bin/acore-manager db-check
```

## Services Do Not Start

Check status and logs:

```bash
./bin/acore-manager status
./bin/acore-manager logs-auth
./bin/acore-manager logs-world
./bin/acore-manager last-errors
```

Confirm `CURRENT_LINK` points at a release containing:

```text
bin/authserver
bin/worldserver
```

Confirm systemd templates match your configured user, group, and install root.

If updating an existing manager and this fails:

```text
Error: unknown command: install-services
```

the checked-out dispatcher is older than the service installer command. Run the installer script directly once:

```bash
sudo ./scripts/setup/acore-install-services.sh --force
```

Confirm services run from `/opt/acore-manager/current`, not build staging:

```bash
systemctl cat azerothcore-auth.service
systemctl cat azerothcore-world.service
sudo ./bin/acore-manager fix-runtime-paths
```

Also confirm client data exists:

```text
/opt/acore-manager/shared/data/dbc
/opt/acore-manager/shared/data/maps
/opt/acore-manager/shared/data/vmaps
/opt/acore-manager/shared/data/mmaps
```

and that `authserver.conf` and `worldserver.conf` have been prepared from the release `.conf.dist` files.

## Server Starts But Cannot Find worldserver.conf

Check that shared configs are linked into the active release:

```bash
readlink -f /opt/acore-manager/current/etc/worldserver.conf
sudo ./bin/acore-manager link-configs
```

The link should resolve to:

```text
/opt/acore-manager/shared/configs/worldserver.conf
```

## Module Config Not Loaded After Release Switch

Check the module config link:

```bash
readlink -f /opt/acore-manager/current/etc/modules
```

It should resolve to:

```text
/opt/acore-manager/shared/configs/modules
```

If `current/etc/modules` is a real directory instead of a symlink, run:

```bash
sudo ./bin/acore-manager link-configs
```

The linker moves real files or directories aside with timestamped backups before creating symlinks.

## Edited Release Config But Change Disappeared

Do not edit files under:

```text
/opt/acore-manager/releases/<release>/etc
```

Edit shared configs instead:

```text
/opt/acore-manager/shared/configs
```

## DataDir Points To An Old Release Path

Set `DataDir` in shared `worldserver.conf` to:

```text
/opt/acore-manager/shared/data
```

Then check:

```bash
./bin/acore-manager check-data
```

## Services Are Running From build/staging Instead Of current

Symptoms:

- release switch appears to do nothing
- rollback does not affect running binaries
- config symlinks are missing
- services cannot find shared configs
- deleting `build/staging` breaks runtime

Checks:

```bash
systemctl cat azerothcore-auth.service
systemctl cat azerothcore-world.service
readlink -f /opt/acore-manager/current
ls -l /opt/acore-manager/current/bin
grep -R "build/staging" /etc/systemd/system /opt/acore-manager
```

Fix installed acore-manager service templates:

```bash
sudo ./bin/acore-manager fix-runtime-paths
sudo ./bin/acore-manager fix-runtime-paths --apply
sudo ./bin/acore-manager validate-runtime
```

The fix script reloads systemd but does not restart services. Restart or switch releases explicitly when ready.

If this happens from OliveTin, the button is usually calling the correct `acore-manager` command, but the installed systemd unit is stale. Run the same `fix-runtime-paths` commands on the server, then press the OliveTin restart button again.

If logs still show `Config::LoadFile` looking under `/opt/acore-manager/build/staging/etc`, the existing binaries were built with the old staging install prefix baked in. Rebuild and create a new release with the updated build script:

```bash
./bin/acore-manager build
./bin/acore-manager create-release
sudo ./bin/acore-manager prepare-configs <new-release>
sudo ./bin/acore-manager switch-release <new-release>
```

## Client Cannot Connect

Check the client realmlist, firewall, and ports:

```bash
ss -ltnp | grep -E '3724|8085'
```

If login works but the realm or character list hangs, check the realm address in the auth database, worldserver port reachability, and both service logs.

## Sleep Services Stay Stopped

Run:

```bash
./bin/acore-manager validate
./bin/acore-manager sleep-status
```

For sleep mode, shared `authserver.conf` should contain:

```text
RealmServerPort = 3725
```

Then rerun:

```bash
sudo ./bin/acore-manager install-services --force
```

If validation cannot confirm `RealmServerPort`, inspect the shared config path reported by `validate`.

If `sleep-status` or the monitor journal repeatedly reports `playerbots-not-ready` or `bot-level-brackets-not-ready`, the optional module readiness gate is blocking sleep. Unless you have verified that those exact startup log messages exist on your server, set:

```bash
REQUIRE_PLAYERBOTS_READY="0"
REQUIRE_BOT_LEVEL_BRACKETS_READY="0"
```

Then restart the monitor:

```bash
sudo systemctl restart acore-sleep-monitor.service
```

## Build Fails

Update source and modules before building:

```bash
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
```

If dependencies are missing on Ubuntu/Debian, rerun:

```bash
sudo ./scripts/setup/acore-bootstrap.sh
```

If the build directory appears corrupted, preview and run a clean rebuild:

```bash
./bin/acore-manager clean-build --dry-run
./bin/acore-manager clean-build
./bin/acore-manager rebuild --clean
```

This removes generated files under `/opt/acore-manager/build` only. It does not delete source, modules, releases, shared configs, shared data, logs, backups, or databases, and it does not restart services.

If the failure mentions an undefined module loader symbol, for example:

```text
undefined reference to `Addmod_discord_webhookScripts()'
```

first try a clean high-level release:

```bash
sudo ./bin/acore-manager release-latest --clean
```

If the same symbol fails after a clean build, the named module is likely incompatible with the current AzerothCore source or is missing its expected script registration function. Disable, update, or patch that module, then rebuild cleanly.

## Build Fails In Jemalloc With GCC 15

Symptom:

```text
deps/jemalloc/src/safety_check.c
error: conflicting types for 'je_safety_check_set_abort'
```

This is a compiler/dependency compatibility issue between GCC 15 and AzerothCore's bundled jemalloc, not an `acore-manager` workflow problem.

Workaround:

```bash
echo 'CMAKE_EXTRA_FLAGS="-DNOJEM=1"' | sudo tee -a config/local/manager.conf
./bin/acore-manager build
```

`NOJEM` disables jemalloc. Treat this as a local workaround, not a universal default.

## Release Switch Fails

List releases:

```bash
./bin/acore-manager list-releases
```

Switch only to a release directory that exists under `RELEASES_DIR` and contains executable server binaries.

## Config Diff Has No Output

`config-diff` needs `.dist` files under:

```text
CURRENT_LINK/etc
```

and live configs under:

```text
CONFIG_DIR
```

Run:

```bash
./bin/acore-manager config-diff
```
