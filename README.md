# acore-manager

`acore-manager` is a reusable Linux server manager for AzerothCore. It provides small shell tools for updating source and modules, building staged server files, creating timestamped releases, switching or rolling back releases, managing systemd services, viewing logs, and backing up configuration and databases.

It is for server operators who want a simple, scriptable workflow around an AzerothCore Linux host without baking private paths, module packs, or credentials into the repository.

Default install root:

```text
/opt/acore-manager
```

## Quick Start

Clone the repository on the Linux host, then run the bootstrap:

```bash
find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true
sudo ./scripts/setup/acore-bootstrap.sh
```

Review or create local configuration:

```bash
config/local/manager.conf
config/local/modules.txt
config/local/db.conf        # optional, for DB checks and backups
```

Use the CLI wrapper for common actions:

```bash
./bin/acore-manager validate
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager list-releases
```

Creating a release does not mean the server is running. A real first setup still needs client data files, `authserver.conf` and `worldserver.conf`, databases, installed systemd services, and firewall/client checks. Follow the complete guide before switching a first production release.

`/opt/acore-manager/build/staging` is temporary build output only. The active runtime is always `/opt/acore-manager/current`, which points to a versioned release under `/opt/acore-manager/releases`.

Minimal operational flow:

```bash
./bin/acore-manager validate
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager list-releases
# prepare data files, configs, database, and systemd services
./bin/acore-manager prepare-configs <release-name>
./bin/acore-manager check-data
./bin/acore-manager switch-release <release-name>
./bin/acore-manager status
./bin/acore-manager logs-world
```

Safe shutdown and reboot handling:

```bash
sudo ./bin/acore-manager install-services
./bin/acore-manager sleep-status
sudo ./bin/acore-manager safe-stop
sudo ./bin/acore-manager reboot
systemctl status acore-manager-shutdown.service
```

Optional automatic weekly restarts are configured with cron syntax and are disabled by default:

```bash
AUTO_RESTART_ENABLED="true"
AUTO_RESTART_CRON="20 4 * * 3"  # Wednesday 04:20
sudo ./bin/acore-manager install-services --force
```

## Documentation

- [Full Server Setup](docs/full-server-setup.md)
- [Command Reference](docs/commands.md)
- [Install](docs/install.md)
- [Configuration](docs/configuration.md)
- [Modules](docs/modules.md)
- [Build and Release](docs/build-and-release.md)
- [Runtime](docs/runtime.md)
- [Idle Sleep](docs/power-sleep.md)
- [Rollback](docs/rollback.md)
- [Database Backups](docs/database-backups.md)
- [OliveTin](docs/olivetin.md)
- [Troubleshooting](docs/troubleshooting.md)

OliveTin web buttons are optional. See [OliveTin](docs/olivetin.md) for setup steps, and keep OliveTin LAN/VPN-only rather than publicly exposed.

If a script fails with `Permission denied`, run:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```
