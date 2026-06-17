# Docker Workflow

acore-manager is a wrapper around AzerothCore's Docker Compose workflow. It does not replace that workflow with a custom monolithic image.

## Source And Modules

Run:

```bash
./bin/acore-manager docker sync-modules
```

This command:

- clones or updates the AzerothCore source checkout.
- reads `config/local/modules.txt` when present.
- clones or updates each configured module into `AzerothCore/modules/`.
- writes generated Compose support files under `build/docker-compose/`.

## Compose Overrides

acore-manager generates:

```text
build/docker-compose/docker-compose.override.yml
build/docker-compose/docker.env
```

The override keeps services separate and adds persistent mounts for config, data, and logs:

```text
build/runtime/config
build/runtime/data
build/runtime/logs
```

The manager passes both the AzerothCore Compose file and the generated override to `docker compose`.

## Build And Start

```bash
./bin/acore-manager docker build
./bin/acore-manager docker db-import
./bin/acore-manager docker up
```

`docker build` delegates to `docker compose build`. `docker db-import` runs the `db-import` service. `docker up` starts `authserver` and `worldserver`, and starts the local `database` service when `MYSQL_EXTERNAL` is not truthy.

## External MySQL

Set `MYSQL_EXTERNAL="true"` and point `MYSQL_HOST` at an existing MySQL server. In that mode, acore-manager uses Compose with `--no-deps` for runtime/import commands so the local `database` service is not started through `depends_on`.
