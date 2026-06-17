# Troubleshooting

## Docker Compose Missing

Run:

```bash
./bin/acore-manager docker validate
docker compose version
```

Install or start Docker if either command reports a Docker problem.

## AzerothCore Source Missing

Run:

```bash
./bin/acore-manager docker sync-modules
```

By default the source checkout is created at `build/azerothcore`.

## Compose File Not Found

If validation cannot find an AzerothCore Compose file after the source is cloned, set `COMPOSE_BASE_FILE` in `config/local/docker-manager.conf` to the Compose file path used by your checkout.

## Module Clone Fails

Check `config/local/modules.txt`. Each active line must use:

```text
module-name|git-url|branch
```

Then run:

```bash
./bin/acore-manager docker validate
./bin/acore-manager docker sync-modules
```

## External MySQL Connection Fails

Check the MySQL settings in `config/local/docker-manager.conf`:

```bash
MYSQL_EXTERNAL="true"
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
```

Do not commit real database credentials.
