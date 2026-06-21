# Reset Instance

`reset-instance` is for deliberately removing selected parts of an acore-manager managed installation. It is separate from `clean-build` because it can delete releases, configs, logs, client data, or databases.

Prefer safer recovery commands first:

```bash
./bin/acore-manager clean-build --dry-run
./bin/acore-manager rebuild --clean
./bin/acore-manager backup-all
```

## Dry Run First

Always preview the reset:

```bash
sudo ./bin/acore-manager reset-instance --dry-run --binaries
```

Dry-run prints the selected areas and paths. It does not remove files or databases.

## Area Flags

Choose one or more areas:

```bash
sudo ./bin/acore-manager reset-instance --apply --binaries
sudo ./bin/acore-manager reset-instance --apply --configs
sudo ./bin/acore-manager reset-instance --apply --logs
sudo ./bin/acore-manager reset-instance --apply --data --i-understand-this-deletes-shared-data
sudo ./bin/acore-manager reset-instance --apply --databases --i-understand-this-deletes-realm-data
```

Area behavior:

- `--binaries` removes build output, releases, and the `current` symlink. It does not remove source or modules.
- `--configs` removes shared AzerothCore runtime configs under `/opt/acore-manager/shared/configs` after running `config-backup`.
- `--logs` removes shared logs and manager logs. Logs are not backed up by default.
- `--data` removes shared client data under `/opt/acore-manager/shared/data` and requires the shared-data confirmation flag.
- `--databases` drops configured auth, world, and characters databases and requires the realm-data confirmation flag.

## Database Reset

Database reset touches only the configured databases:

```bash
MYSQL_AUTH_DB="acore_auth"
MYSQL_WORLD_DB="acore_world"
MYSQL_CHAR_DB="acore_characters"
```

Playerbots or custom module tables inside those databases are deleted when the database is dropped. Separate custom module databases are not touched.

By default, `--databases --apply` runs `db-backup` first:

```bash
sudo ./bin/acore-manager reset-instance --apply --databases --i-understand-this-deletes-realm-data
```

Use `--skip-pre-backup` only when you already have a current database backup:

```bash
sudo ./bin/acore-manager reset-instance --apply --databases --skip-pre-backup --i-understand-this-deletes-realm-data
```

To recreate empty configured databases after dropping them:

```bash
sudo ./bin/acore-manager reset-instance --apply --databases --recreate-databases --i-understand-this-deletes-realm-data
```

No custom SQL is imported by `reset-instance`.

## Live Services

`reset-instance --apply` refuses to run while auth/world services are active. Stop them explicitly or let acore-manager run the safe stop workflow first:

```bash
sudo ./bin/acore-manager reset-instance --apply --binaries --safe-stop-first
```

`clean-build` and `rebuild` do not stop or restart services.

## Safety Checks

The reset command refuses paths that are empty, relative, symlinks, too broad, or overlapping protected paths such as source, modules, backups, `config/local`, or `.env`. If `current` points inside the build directory, build cleanup and binary reset refuse to run.
