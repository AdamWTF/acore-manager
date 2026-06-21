# Updating acore-manager

Use this when `acore-manager` is already installed and you pull a newer version of the manager repository.

This updates manager scripts, systemd templates, the shutdown hook, optional sleep services, and optional restart cron metadata. It does not rebuild AzerothCore, switch releases, restart auth/world, or modify live databases.

## Standard Update

```bash
cd /opt/acore-manager
git pull

sudo ./scripts/setup/acore-fix-permissions.sh

./bin/acore-manager validate
sudo ./bin/acore-manager install-services --force

./bin/acore-manager service-status
./bin/acore-manager doctor
```

`install-services --force` backs up replaced managed unit files under `/opt/acore-manager/backups/systemd/<timestamp>/` and backs up restart cron changes under `/opt/acore-manager/backups/cron/<timestamp>/`.

## Older Dispatcher Fallback

If the local dispatcher is older and reports:

```text
Error: unknown command: install-services
```

run the installer script directly:

```bash
sudo ./scripts/setup/acore-install-services.sh --force
```

That performs the same service/template update as the wrapper command. After the repository has been pulled to a version containing the newer dispatcher, future runs can use:

```bash
sudo ./bin/acore-manager install-services --force
```

## Optional Checks

```bash
./bin/acore-manager config-diff
./bin/acore-manager sleep-status
./bin/acore-manager list-backups
./scripts/integrations/acore-validate-olivetin-config.sh
```

Run `config-diff` after creating or switching to a release if there is no active release yet.

## Updating AzerothCore After Updating The Manager

If the manager update is part of a server release workflow:

```bash
./bin/acore-manager backup-all
./bin/acore-manager update-source
./bin/acore-manager update-modules
./bin/acore-manager build
./bin/acore-manager create-release
./bin/acore-manager list-releases
./bin/acore-manager switch-release --dry-run <release-name>
sudo ./bin/acore-manager switch-release <release-name>
```

`switch-release --dry-run` validates the target and prints the service actions without touching `CURRENT_LINK` or restarting services.

## If Something Looks Wrong

```bash
./bin/acore-manager doctor
./bin/acore-manager service-status
./bin/acore-manager last-errors
```

For stale systemd units that still point at build staging:

```bash
sudo ./bin/acore-manager fix-runtime-paths
sudo ./bin/acore-manager fix-runtime-paths --apply
```
