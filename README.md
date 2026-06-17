# acore-manager

`acore-manager` automates the normal AzerothCore Docker Compose workflow. It keeps AzerothCore as a multi-container deployment and removes the repetitive manual steps around source checkout, module sync, Compose overrides, builds, database import, and service lifecycle.

It does not build one all-in-one runtime image for `authserver` and `worldserver`.

## Quick Start

Create local config:

```bash
cp config/defaults/docker-manager.conf.example config/local/docker-manager.conf
cp config/defaults/modules.txt.example config/local/modules.txt
```

Validate local tools and config:

```bash
./bin/acore-manager docker validate
```

Clone/update AzerothCore and configured modules:

```bash
./bin/acore-manager docker sync-modules
```

Build and run the normal Docker Compose services:

```bash
./bin/acore-manager docker build
./bin/acore-manager docker db-import
./bin/acore-manager docker up
```

Inspect or access services:

```bash
./bin/acore-manager docker logs worldserver
./bin/acore-manager docker shell worldserver
```

Stop the deployment:

```bash
./bin/acore-manager docker down
```

## Configuration

Local Docker manager settings live in `config/local/docker-manager.conf`. Real module selections belong in `config/local/modules.txt`, which is ignored by git.

The module format is:

```text
module-name|git-url|branch
```

## Documentation

- [Commands](docs/commands.md)
- [Configuration](docs/configuration.md)
- [Docker Workflow](docs/docker-workflow.md)
- [Modules](docs/modules.md)
- [Troubleshooting](docs/troubleshooting.md)
