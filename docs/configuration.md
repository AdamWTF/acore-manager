# Configuration

Committed defaults live in:

```text
config/defaults/
```

Local machine-specific configuration lives in:

```text
config/local/
```

Files under `config/local/manager.conf`, `config/local/modules.txt`, and `config/local/db.conf` are ignored by git.

## Manager Config

Start from the example:

```bash
cp config/defaults/manager.conf.example config/local/manager.conf
```

Important values:

```bash
ACM_ROOT="/opt/acore-manager"
ACORE_REPO="https://github.com/azerothcore/azerothcore-wotlk.git"
ACORE_BRANCH="master"
ACORE_USER="azerothcore"
ACORE_GROUP="azerothcore"
AUTH_SERVICE="azerothcore-auth.service"
WORLD_SERVICE="azerothcore-world.service"

AUTO_RESTART_ENABLED="false"
AUTO_RESTART_CRON="20 4 * * 3"
AUTO_RESTART_USER="root"
DATADIR="/opt/acore-manager/shared/data"
CONFIG_DIR="/opt/acore-manager/shared/configs"
BUILD_TYPE="RelWithDebInfo"
BUILD_THREADS="auto"
CMAKE_EXTRA_FLAGS=""
```

Idle sleep defaults:

```bash
SLEEP_ENABLED="true"
SLEEP_IDLE_TIMEOUT="300"
MIN_UPTIME_BEFORE_SLEEP="600"
REQUIRE_WORLDSERVER_READY="1"
REQUIRE_PLAYERBOTS_READY="1"
REQUIRE_BOT_LEVEL_BRACKETS_READY="1"
AUTH_PUBLIC_PORT="3724"
AUTH_BACKEND_PORT="3725"
WORLD_PORTS="8085 3443"
```

When sleep mode is enabled, the public auth port is owned by the sleep proxy and the real authserver should listen on `AUTH_BACKEND_PORT`. See [Idle Sleep](power-sleep.md).

Use `CMAKE_EXTRA_FLAGS` for advanced local CMake options that should not become project defaults. For example:

```bash
CMAKE_EXTRA_FLAGS="-DNOJEM=1"
```

Derived paths are created by `scripts/lib/common.sh`, including:

```bash
SOURCE_ROOT="/opt/acore-manager/source"
ACORE_SOURCE_DIR="/opt/acore-manager/source/azerothcore"
MODULES_DIR="/opt/acore-manager/source/azerothcore/modules"
BUILD_DIR="/opt/acore-manager/build"
RELEASES_DIR="/opt/acore-manager/releases"
CURRENT_LINK="/opt/acore-manager/current"
SHARED_DIR="/opt/acore-manager/shared"
BACKUP_DIR="/opt/acore-manager/backups"
```

`SOURCE_ROOT` is only the parent directory. `ACORE_SOURCE_DIR` is the AzerothCore git checkout.

## Database Config

Database credentials are optional for build/runtime scripts, but required for DB checks and backups.

```bash
cp config/defaults/db.conf.example config/local/db.conf
```

Use local or remote MySQL values:

```bash
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

Do not commit real credentials.

## Validate

```bash
./bin/acore-manager validate
```

This checks required variables, required commands, service names, and path status.

## Back Up Configuration

```bash
./bin/acore-manager config-backup
```

This backs up shared configs, `config/local`, installed managed systemd service files, and `/etc/cron.d/acore-manager-restart` when present. Missing optional paths produce warnings.

Related recovery commands:

```bash
./bin/acore-manager backup-all
./bin/acore-manager list-backups
./bin/acore-manager restore-config /opt/acore-manager/backups/config/<timestamp> --dry-run
```

`restore-config --apply` writes files back to shared config, `config/local`, `/etc/systemd/system`, and `/etc/cron.d`, then reloads systemd when available.

Reset manifests are listed by `list-backups` under `BACKUP_DIR/reset` after destructive `reset-instance --apply` runs.

## Runtime Configs

Live AzerothCore runtime configs belong in shared persistent storage:

```text
/opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/shared/configs/modules/*.conf
```

Seed them from release templates:

```bash
sudo ./bin/acore-manager prepare-configs <release-name>
```

Edit shared configs, not files inside `/opt/acore-manager/releases/<release>/etc`.

When a release is active, link shared configs into it:

```bash
sudo ./bin/acore-manager link-configs
```

Expected links:

```text
/opt/acore-manager/current/etc/authserver.conf -> /opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/current/etc/worldserver.conf -> /opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/current/etc/modules -> /opt/acore-manager/shared/configs/modules
```

`DataDir` in `worldserver.conf` should point to:

```text
/opt/acore-manager/shared/data
```

Do not edit or run files from `/opt/acore-manager/build/staging`. That path is temporary build output. Runtime config resolution should flow through `/opt/acore-manager/current/etc`.
