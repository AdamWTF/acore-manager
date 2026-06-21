# acore-manager

`acore-manager` is a generic Linux automation toolkit for operating AzerothCore servers. It manages source/module updates, builds, releases, runtime services, safe shutdowns, diagnostics, backups, and recovery helpers without baking private realm details into the repository.

Default install root:

```text
/opt/acore-manager
```

## Fresh Install

```bash
sudo mkdir -p /opt/acore-manager
sudo chown "$USER":"$USER" /opt/acore-manager
git clone https://github.com/AdamWTF/acore-manager.git /opt/acore-manager
cd /opt/acore-manager

find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true
sudo ./scripts/setup/acore-bootstrap.sh

./bin/acore-manager validate
```

Then follow [Full Server Setup](docs/full-server-setup.md) for AzerothCore source, modules, data files, configs, databases, and the first release switch.

## Updating The Manager

After pulling a newer `acore-manager`, update local service metadata without rebuilding AzerothCore or restarting auth/world:

```bash
cd /opt/acore-manager
git pull

sudo ./scripts/setup/acore-fix-permissions.sh

./bin/acore-manager validate
sudo ./bin/acore-manager install-services --force

./bin/acore-manager service-status
./bin/acore-manager doctor
```

See [Updating acore-manager](docs/updating-manager.md) for optional checks and the release workflow to run after a manager update.

## Common Commands

```bash
./bin/acore-manager doctor
./bin/acore-manager service-status
./bin/acore-manager list-backups
./bin/acore-manager backup-all

./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager list-releases
./bin/acore-manager switch-release --dry-run <release-name>
sudo ./bin/acore-manager switch-release <release-name>

./bin/acore-manager sleep-status
sudo ./bin/acore-manager safe-stop
sudo ./bin/acore-manager reboot
```

## Documentation

- [Updating acore-manager](docs/updating-manager.md)
- [Full Server Setup](docs/full-server-setup.md)
- [Command Reference](docs/commands.md)
- [Install](docs/install.md)
- [Configuration](docs/configuration.md)
- [Build and Release](docs/build-and-release.md)
- [Runtime](docs/runtime.md)
- [Idle Sleep](docs/power-sleep.md)
- [Database Backups and Recovery](docs/database-backups.md)
- [Rollback](docs/rollback.md)
- [Modules](docs/modules.md)
- [OliveTin](docs/olivetin.md)
- [Troubleshooting](docs/troubleshooting.md)

OliveTin web buttons are optional and should stay LAN/VPN-only.
