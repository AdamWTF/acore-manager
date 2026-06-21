# Full Server Setup

This guide is the end-to-end path from a fresh Linux host to running native AzerothCore systemd services with `acore-manager`.

`acore-manager` automates host preparation, source/module updates, builds, releases, backups, service wrappers, and status checks. It does not replace AzerothCore's own database setup process, does not download client data files, and does not make management UIs safe for public exposure.

## Assumptions

- You are using an Ubuntu/Debian-style Linux host.
- You have `sudo` access.
- `acore-manager` is installed at `/opt/acore-manager`.
- A MySQL/MariaDB-compatible server exists locally or on a reachable remote host.
- AzerothCore source and configured modules can be cloned from the server.
- You have legally obtained AzerothCore 3.3.5a client data for `dbc`, `maps`, `vmaps`, and `mmaps`.

## Directory Layout

Important paths:

```text
/opt/acore-manager                         repository and install root
/opt/acore-manager/source                  source parent directory
/opt/acore-manager/source/azerothcore      AzerothCore git checkout
/opt/acore-manager/source/azerothcore/modules
/opt/acore-manager/build                   CMake build directory
/opt/acore-manager/build/staging           temporary staged install output
/opt/acore-manager/releases                timestamped releases
/opt/acore-manager/current                 symlink to active release
/opt/acore-manager/shared                  shared runtime files
/opt/acore-manager/shared/data             dbc/maps/vmaps/mmaps
/opt/acore-manager/shared/configs          local server config copies
/opt/acore-manager/shared/configs/modules  local module config copies
/opt/acore-manager/shared/logs             file logs if configured
/opt/acore-manager/logs                    local log path if configured
config/defaults                            committed examples
config/local                               local gitignored config
```

`SOURCE_ROOT` is `/opt/acore-manager/source`. The actual AzerothCore checkout is `ACORE_SOURCE_DIR`, `/opt/acore-manager/source/azerothcore`.

The active runtime path is always `/opt/acore-manager/current`. Do not run services from `/opt/acore-manager/build/staging`; it is recreated during builds and can be deleted after a release is created.

## Bootstrap

Clone the repo, fix executable bits if needed, and run bootstrap:

```bash
sudo mkdir -p /opt/acore-manager
sudo chown "$USER":"$USER" /opt/acore-manager
git clone https://github.com/<your-org>/acore-manager.git /opt/acore-manager
cd /opt/acore-manager

find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true

sudo ./scripts/setup/acore-bootstrap.sh
```

Bootstrap installs typical build dependencies, creates the configured service user/group, creates the standard directories, creates local config files only when missing, installs systemd templates without enabling or starting auth/world services, and enables the safe shutdown hook.

Review these files before continuing:

```text
config/local/manager.conf
config/local/modules.txt
config/local/db.conf        optional, for DB checks and backups
```

Create the optional DB credentials file when needed:

```bash
cp config/defaults/db.conf.example config/local/db.conf
```

## Configure acore-manager

Edit `config/local/manager.conf` for local settings and keep it out of git. Local values override `config/defaults/manager.conf.example`.

Safe example:

```bash
ACM_ROOT="/opt/acore-manager"
ACORE_REPO="https://github.com/azerothcore/azerothcore-wotlk.git"
ACORE_BRANCH="master"
ACORE_USER="azerothcore"
ACORE_GROUP="azerothcore"
AUTH_SERVICE="azerothcore-auth.service"
WORLD_SERVICE="azerothcore-world.service"

MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_AUTH_DB="acore_auth"
MYSQL_WORLD_DB="acore_world"
MYSQL_CHAR_DB="acore_characters"

DATADIR="/opt/acore-manager/shared/data"
CONFIG_DIR="/opt/acore-manager/shared/configs"
BUILD_TYPE="RelWithDebInfo"
BUILD_THREADS="auto"
CMAKE_EXTRA_FLAGS=""
```

Put credentials in `config/local/db.conf` or another local-only config:

```bash
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

Configure modules in `config/local/modules.txt`:

```text
module-name|git-url|branch
```

Do not commit real passwords, private module packs, hostnames, or personal values.

## Validate Config

```bash
./bin/acore-manager validate
```

A pass means required variables and tools look usable and paths are sensible. It does not mean AzerothCore databases are imported, data files exist, configs are complete, or services can start.

## Update Source And Modules

```bash
./bin/acore-manager update-source
./bin/acore-manager update-modules
```

Source is cloned or updated in:

```text
/opt/acore-manager/source/azerothcore
```

Modules are cloned or updated in:

```text
/opt/acore-manager/source/azerothcore/modules
```

Pin module branches or refs deliberately. Some modules, especially large modules such as PlayerBots, may require a matching AzerothCore fork, branch, or commit range.

## Build

```bash
./bin/acore-manager build
```

The build uses `/opt/acore-manager/build` and installs staged artifacts into:

```text
/opt/acore-manager/build/staging
```

Building does not replace the running server, switch `/opt/acore-manager/current`, or restart services. Staging is not a live server path.

AzerothCore is configured with runtime prefix `/opt/acore-manager/current` while the install is staged under `/opt/acore-manager/build/staging`. This keeps compiled config lookup paths aligned with the active release instead of the temporary staging directory.

Use `CMAKE_EXTRA_FLAGS` in `config/local/manager.conf` for local CMake options, for example:

```bash
CMAKE_EXTRA_FLAGS="-DNOJEM=1"
```

There is currently no separate `ACORE_BUILD_DIAGNOSTIC` mode. Build failures print compiler/CMake versions, the CMake flags used, and a pointer to troubleshooting.

## Create Release

```bash
./bin/acore-manager create-release
```

This copies `/opt/acore-manager/build/staging` into a timestamped release under:

```text
/opt/acore-manager/releases/<timestamp>
```

After release creation, runtime uses the release through `/opt/acore-manager/current`. Deleting or recreating `/opt/acore-manager/build/staging` must not break the running server.

It also writes:

```text
/opt/acore-manager/releases/<timestamp>/metadata/release-info.txt
```

Creating a release does not switch `/opt/acore-manager/current` and does not mean the server is running.

Release directories are for release-specific binaries, libraries, metadata, and pristine config templates. Live runtime configs belong under `/opt/acore-manager/shared/configs`, not inside individual releases.

When a release is created, generated config templates are stored under:

```text
/opt/acore-manager/releases/<timestamp>/etc.dist
```

The live release `etc` directory is reserved for symlinks to shared configs.

## Data Files

AzerothCore needs extracted 3.3.5a client data. `acore-manager` does not download or extract these files for you.

Required directories:

```text
/opt/acore-manager/shared/data/dbc
/opt/acore-manager/shared/data/maps
/opt/acore-manager/shared/data/vmaps
/opt/acore-manager/shared/data/mmaps
```

From another Linux machine:

```bash
rsync -avz /path/to/data/ <linux-user>@<server-ip>:/tmp/acore-data/
ssh <linux-user>@<server-ip>
sudo rsync -av /tmp/acore-data/ /opt/acore-manager/shared/data/
sudo chown -R <ACORE_USER>:<ACORE_GROUP> /opt/acore-manager/shared/data
```

From Windows using SCP, upload to a temporary location first:

```powershell
scp -r C:\path\to\data\dbc <linux-user>@<server-ip>:/tmp/acore-data/
scp -r C:\path\to\data\maps <linux-user>@<server-ip>:/tmp/acore-data/
scp -r C:\path\to\data\vmaps <linux-user>@<server-ip>:/tmp/acore-data/
scp -r C:\path\to\data\mmaps <linux-user>@<server-ip>:/tmp/acore-data/
```

Then on the server:

```bash
sudo rsync -av /tmp/acore-data/ /opt/acore-manager/shared/data/
sudo chown -R <ACORE_USER>:<ACORE_GROUP> /opt/acore-manager/shared/data
```

With WinSCP, upload the four directories to `/tmp/acore-data`, then run the same `rsync` and `chown` commands.

`DataDir` in `worldserver.conf` should point to:

```text
/opt/acore-manager/shared/data
```

unless you intentionally changed `DATADIR`.

## Config Files

AzerothCore installs example config files such as `authserver.conf.dist` and `worldserver.conf.dist`. `acore-manager` stores release templates in each release under `etc.dist`, then keeps live configs in shared persistent storage:

```text
/opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/shared/configs/modules/*.conf
```

Prepare shared configs after creating a release:

```bash
sudo ./bin/acore-manager prepare-configs <release-name>
```

The command creates missing shared configs only. Existing shared configs are left unchanged.

Edit shared configs, not release-local files:

```bash
sudo nano /opt/acore-manager/shared/configs/authserver.conf
sudo nano /opt/acore-manager/shared/configs/worldserver.conf
sudo nano /opt/acore-manager/shared/configs/modules/<module>.conf
```

Back up existing configs before risky edits:

```bash
./bin/acore-manager config-backup
```

The current systemd templates run:

```text
/opt/acore-manager/current/bin/authserver
/opt/acore-manager/current/bin/worldserver
```

with working directory:

```text
/opt/acore-manager/current/bin
```

`acore-manager` links shared configs into the active release with:

```bash
sudo ./bin/acore-manager link-configs
```

Expected active-release layout:

```text
/opt/acore-manager/current/etc/authserver.conf -> /opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/current/etc/worldserver.conf -> /opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/current/etc/modules -> /opt/acore-manager/shared/configs/modules
```

Key values to check:

```text
LoginDatabaseInfo
WorldDatabaseInfo
CharacterDatabaseInfo
DataDir
LogsDir
RealmID / realm settings
WorldServerPort
BindIP
```

Safe examples:

```text
LoginDatabaseInfo     = "<mysql-host>;3306;<db-user>;<db-password>;acore_auth"
WorldDatabaseInfo     = "<mysql-host>;3306;<db-user>;<db-password>;acore_world"
CharacterDatabaseInfo = "<mysql-host>;3306;<db-user>;<db-password>;acore_characters"
DataDir               = "/opt/acore-manager/shared/data"
```

Check data and `DataDir`:

```bash
./bin/acore-manager check-data
```

## Database Preparation

Expected databases:

```text
acore_auth
acore_world
acore_characters
```

`acore-manager` can check and back up configured databases. It does not currently create, initialize, or import AzerothCore databases. Follow the upstream AzerothCore database setup process for initial DB creation/imports and updates.

Check connectivity and database presence:

```bash
./bin/acore-manager db-check
```

Back up before real release switches or risky maintenance:

```bash
./bin/acore-manager db-backup
```

## Install systemd Services

Bootstrap installs templates to `/etc/systemd/system/` when they are present. To install or update managed service files on a fresh or existing server:

```bash
sudo ./bin/acore-manager install-services --force
```

Existing unit files are backed up under `/opt/acore-manager/backups/systemd/<timestamp>/` before replacement. This reloads systemd and enables/starts `acore-manager-shutdown.service`, but it does not restart live auth/world services.

Automatic weekly restarts are optional and disabled by default. To enable the default Wednesday 04:20 restart, set this in `config/local/manager.conf` before running `install-services`:

```bash
AUTO_RESTART_ENABLED="true"
AUTO_RESTART_CRON="20 4 * * 3"
AUTO_RESTART_USER="root"
```

The generated cron file is `/etc/cron.d/acore-manager-restart`.

Each copied service should execute:

```text
/opt/acore-manager/current/bin/authserver
/opt/acore-manager/current/bin/worldserver
```

Adjust copied service files if you changed `ACORE_USER`, `ACORE_GROUP`, service names, install root, or config strategy.

## Switch To A Release

List releases:

```bash
./bin/acore-manager list-releases
```

Switch to one:

```bash
./bin/acore-manager switch-release <release-name>
```

This validates the release, stops world then auth, updates `/opt/acore-manager/current`, relinks shared configs into the new active release, starts auth then world, and runs status. On a first server, prepare data files, shared configs, databases, and systemd templates before switching, because switching starts services.

Confirm the current release:

```bash
./bin/acore-manager status
readlink -f /opt/acore-manager/current
readlink -f /opt/acore-manager/current/etc/worldserver.conf
readlink -f /opt/acore-manager/current/etc/modules
```

If `readlink -f /opt/acore-manager/current` resolves to `/opt/acore-manager/build/staging`, fix the release switch before starting services.

## Start Services

Recommended order:

1. database online and reachable
2. authserver
3. worldserver
4. client login test

Using `acore-manager`:

```bash
./bin/acore-manager start
./bin/acore-manager status
```

Direct systemd equivalents:

```bash
sudo systemctl start azerothcore-auth.service
sudo systemctl start azerothcore-world.service
systemctl status azerothcore-auth.service --no-pager
systemctl status azerothcore-world.service --no-pager
```

## Logs And Verification

```bash
./bin/acore-manager logs-auth
./bin/acore-manager logs-world
./bin/acore-manager last-errors
```

Direct journal checks:

```bash
journalctl -u azerothcore-auth.service -n 100 --no-pager
journalctl -u azerothcore-world.service -n 100 --no-pager
```

Port checks:

```bash
ss -ltnp | grep -E '3724|8085'
```

Common ports:

```text
3724  authserver
8085  worldserver
```

## Client Connection

Set your 3.3.5a client's realmlist to the server IP or DNS name:

```text
set realmlist <server-host>
```

The auth port must be reachable from the client. Realm internal/external addresses may also need to be configured in the auth database. If login works but the client gets stuck at the realm list or character list, check the realm address, worldserver port, firewall, and both service logs.

## Firewall

Use LAN/VPN-only examples unless you deliberately know your exposure model:

```bash
sudo ufw allow from <lan-cidr> to any port 3724 proto tcp comment 'AzerothCore auth LAN'
sudo ufw allow from <lan-cidr> to any port 8085 proto tcp comment 'AzerothCore world LAN'
```

Management UIs should also be LAN/VPN/Twingate-only:

```text
9090   Cockpit
19999  Netdata
1337   OliveTin
```

Do not expose Cockpit, Netdata, OliveTin, or similar management UIs directly to the public internet.

## Normal Update Workflow

For future maintenance:

```bash
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager config-backup
./bin/acore-manager db-backup
./bin/acore-manager list-releases
./bin/acore-manager switch-release <release-name>
./bin/acore-manager status
./bin/acore-manager last-errors
./bin/acore-manager validate-runtime
```

Schedule downtime when needed. Back up databases and configs before switching real servers.

`./bin/acore-manager release-latest` runs the high-level update/build/release/switch workflow. Use it only after you are comfortable with the individual steps.

## Rollback

```bash
./bin/acore-manager list-releases
./bin/acore-manager rollback
```

Rollback selects the previous release by sorted release directory order and calls `switch-release`. It changes the active release symlink and restarts services. It does not roll back database migrations, data file changes, or manual config edits.
Rollback also relinks shared configs into the rollback target. It does not restore old per-release configs unless you do that manually from backups.

## Troubleshooting Checklist

- Permission denied running scripts: `sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh`
- No current release: run `./bin/acore-manager list-releases`, then switch to a valid release.
- Missing data files: confirm `dbc`, `maps`, `vmaps`, and `mmaps` exist under `/opt/acore-manager/shared/data`.
- Configs missing: run `sudo ./bin/acore-manager prepare-configs <release-name>`, edit shared configs, then run `sudo ./bin/acore-manager link-configs`.
- Server cannot find `worldserver.conf`: verify `/opt/acore-manager/current/etc/worldserver.conf` points to `/opt/acore-manager/shared/configs/worldserver.conf`.
- Module config not loaded after release switch: verify `/opt/acore-manager/current/etc/modules` points to `/opt/acore-manager/shared/configs/modules`.
- Edited release config but change disappeared: edit `/opt/acore-manager/shared/configs`, not files under `/opt/acore-manager/releases/<release>/etc`.
- `DataDir` points to an old release path: set `DataDir = "/opt/acore-manager/shared/data"` in shared `worldserver.conf`.
- `current/etc/modules` is a real directory instead of a symlink: run `sudo ./bin/acore-manager link-configs`; the script moves existing real paths aside with timestamped backups.
- DB connection failure: check `config/local/db.conf`, network access, MySQL grants, and `./bin/acore-manager db-check`.
- Services fail to start: inspect `./bin/acore-manager last-errors` and `journalctl`.
- Auth starts but world fails: check `DataDir`, world DB, modules, ports, and `worldserver.conf`.
- Client cannot connect: check realmlist, firewall, auth port `3724`, and auth logs.
- Stuck at realm list: check auth database realm address and worldserver port reachability.
- Stuck at character list: check worldserver logs, character DB, and module errors.
- Module build failure: confirm module branch compatibility with your AzerothCore source.
- PlayerBots compatibility issue: use a known compatible AzerothCore fork/branch or pin matching revisions.
- GCC 15 / jemalloc failure: set `CMAKE_EXTRA_FLAGS="-DNOJEM=1"` locally and rebuild. See [Troubleshooting](troubleshooting.md).
