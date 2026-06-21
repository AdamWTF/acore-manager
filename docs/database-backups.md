# Database Backups

Database helpers read MySQL settings from manager config and optional ignored DB config.

Create local DB config:

```bash
cp config/defaults/db.conf.example config/local/db.conf
```

Example values:

```bash
MYSQL_HOST="<mysql-host>"
MYSQL_PORT="3306"
MYSQL_USER="<mysql-user>"
MYSQL_PASSWORD="<mysql-password>"
```

Do not commit real credentials.

## Check Connection

```bash
./bin/acore-manager db-check
```

This checks the MySQL client, connection, server version, and configured auth/world/characters databases.

## Back Up Databases

```bash
./bin/acore-manager db-backup
```

Backups are written under:

```text
BACKUP_DIR/db/YYYY-MM-DD-HHMM/
```

The script backs up the configured auth, world, and characters databases with `mysqldump` and writes a short `backup-manifest.txt`.

The backup script does not restore, delete, or modify live data.

## Restore Databases

Preview a restore from an explicit backup path:

```bash
./bin/acore-manager restore-db /opt/acore-manager/backups/db/<timestamp> --database all --dry-run
```

Apply only when you are sure the target databases are disposable or already backed up:

```bash
sudo ./bin/acore-manager restore-db /opt/acore-manager/backups/db/<timestamp> --database all --apply
```

By default, `restore-db --apply` runs a fresh `db-backup` first. Use `--skip-pre-backup` only when you have a separate current backup.

## Database Lifecycle Helpers

```bash
./bin/acore-manager db-init --dry-run
./bin/acore-manager db-import dump.sql --database auth --dry-run
./bin/acore-manager db-maintenance
```

`db-init` creates missing configured databases only with `--apply`. `db-import` imports one explicit SQL file into one configured database only with `--apply`. `db-maintenance` is read-only and prints recommended `mysqlcheck` commands.
