# Commands

`bin/acore-manager` exposes Docker workflow automation under the `docker` scope.

| Command | Purpose | Risk | Example |
| --- | --- | --- | --- |
| `docker validate` | Validate config, module list, required commands, and known paths. | Read-only | `./bin/acore-manager docker validate` |
| `docker sync-modules` | Clone/update AzerothCore, then clone/update configured modules into `modules/`. | Writes under `build/` | `./bin/acore-manager docker sync-modules` |
| `docker build` | Generate Compose override files and run `docker compose build`. | Build | `./bin/acore-manager docker build` |
| `docker db-import` | Run the Compose `db-import` service, starting the local database first when enabled. | Database import | `./bin/acore-manager docker db-import` |
| `docker up` | Start `authserver` and `worldserver`, plus the local database when enabled. | Runtime | `./bin/acore-manager docker up` |
| `docker down` | Stop the Compose deployment. | Runtime | `./bin/acore-manager docker down` |
| `docker logs <service>` | Follow logs for a Compose service. | Read-only | `./bin/acore-manager docker logs worldserver` |
| `docker shell <service>` | Open a shell in a running service container. | Runtime | `./bin/acore-manager docker shell worldserver` |

The expected Compose services remain separate:

```text
database
db-import
authserver
worldserver
```

If your AzerothCore checkout uses different service names, set `SERVICE_DATABASE`, `SERVICE_DB_IMPORT`, `SERVICE_AUTHSERVER`, and `SERVICE_WORLDSERVER` in `config/local/docker-manager.conf`.
