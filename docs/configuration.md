# Configuration

Committed defaults live in `config/defaults/`. Local configuration lives in `config/local/` and is ignored by git.

Create local config:

```bash
cp config/defaults/docker-manager.conf.example config/local/docker-manager.conf
```

Important values:

```bash
ACORE_REPO="https://github.com/azerothcore/azerothcore-wotlk.git"
ACORE_BRANCH="master"
ACORE_SOURCE_DIR=""

COMPOSE_PROJECT_NAME="acore-manager"
COMPOSE_BASE_FILE=""

SERVICE_DATABASE="database"
SERVICE_DB_IMPORT="db-import"
SERVICE_AUTHSERVER="authserver"
SERVICE_WORLDSERVER="worldserver"

ACORE_CONFIG_DIR="build/runtime/config"
ACORE_DATA_DIR="build/runtime/data"
ACORE_LOG_DIR="build/runtime/logs"

MYSQL_EXTERNAL="false"
MYSQL_HOST="database"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
MYSQL_AUTH_DATABASE="acore_auth"
MYSQL_CHARACTER_DATABASE="acore_characters"
MYSQL_WORLD_DATABASE="acore_world"
```

When `ACORE_SOURCE_DIR` is empty, acore-manager uses `build/azerothcore`.

When `COMPOSE_BASE_FILE` is empty, acore-manager looks for a Compose file in the cloned AzerothCore source checkout. Set it only when your checkout keeps the Compose file in a custom location.

For an external MySQL host, set:

```bash
MYSQL_EXTERNAL="true"
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

Do not commit registry credentials, database credentials, runtime configs, private hostnames, or private module lists.
