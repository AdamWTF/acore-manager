# Build and Release

The build workflow is split into small scripts. You can run them individually or use the high-level release workflow.

## Update Source

```bash
./bin/acore-manager update-source
```

This clones or updates `ACORE_REPO` at `ACORE_BRANCH` into:

```text
/opt/acore-manager/source/azerothcore
```

## Update Modules

```bash
./bin/acore-manager update-modules
```

This clones or updates configured modules into:

```text
/opt/acore-manager/source/azerothcore/modules
```

## Build

```bash
./bin/acore-manager build
```

Build output is installed into:

```text
/opt/acore-manager/build/staging
```

`BUILD_THREADS="auto"` uses `nproc` when available.

The build step does not switch the active release and does not restart services. `build/staging` is temporary packaging output only; do not run services from it and do not edit runtime configs there.

The build configures AzerothCore with this runtime install prefix:

```text
/opt/acore-manager/current
```

and stages the install under `/opt/acore-manager/build/staging` for release packaging. This prevents binaries from looking for configs under `build/staging/etc`.

## Clean Build And Rebuild

Use `clean-build` when CMake or partial build output is messy:

```bash
./bin/acore-manager clean-build --dry-run
./bin/acore-manager clean-build
```

`clean-build` removes generated files under `/opt/acore-manager/build` only. It keeps source, modules, releases, `current`, shared configs, shared data, logs, backups, systemd units, and databases. It refuses to run if `current` points inside the build directory or if the build directory is not the expected manager build path.

Use `rebuild --clean` to clean and then run a full build:

```bash
./bin/acore-manager rebuild --clean
```

`rebuild` does not create a release, switch `current`, stop services, or restart services. After a successful rebuild, create and switch a release explicitly:

```bash
./bin/acore-manager create-release
./bin/acore-manager switch-release --dry-run <release-name>
sudo ./bin/acore-manager switch-release <release-name>
```

## Create Release

```bash
./bin/acore-manager create-release
```

This copies `BUILD_DIR/staging` into:

```text
RELEASES_DIR/<timestamp>
```

After this copy, the release under `RELEASES_DIR/<timestamp>` is the versioned artifact. The staging directory can be deleted or recreated by later builds without affecting the active server, as long as `/opt/acore-manager/current` points to a release.

It also writes:

```text
RELEASES_DIR/<timestamp>/metadata/release-info.txt
```

The metadata includes build date, AzerothCore commit, module commits, build type, and paths.

Creating a release does not change `CURRENT_LINK` and does not restart services.

Generated config templates are preserved under:

```text
/opt/acore-manager/releases/<timestamp>/etc.dist
```

The release `etc` directory is reserved for symlinks to shared live configs. Do not edit configs under `releases/<release>/etc` directly.

It also does not guarantee the server is ready to run. A running server still needs prepared data files, runtime config files, reachable databases, installed systemd services, and firewall/client checks. See [Full Server Setup](full-server-setup.md).

## Prepare Shared Configs

```bash
sudo ./bin/acore-manager prepare-configs <release-name>
```

This seeds missing shared configs from release templates:

```text
/opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/shared/configs/modules/*.conf
```

Existing shared configs are not overwritten. Edit shared configs, not release-local config files.

## Switch Release

```bash
./bin/acore-manager list-releases
./bin/acore-manager release-report <release-name>
./bin/acore-manager switch-release --dry-run <release-name>
sudo ./bin/acore-manager switch-release <release-name>
```

Switching validates the release, updates:

```text
/opt/acore-manager/current
```

and restarts services in the safe order: stop world, stop auth, start auth, start world. `current` must never point at `/opt/acore-manager/build/staging`.

If relinking configs or starting the new release fails, `switch-release` relinks `current` back to the previous release, relinks shared configs again, and attempts to restart the previous auth/world services before exiting non-zero.

On a first server, prepare data files and configs before switching, because `switch-release` starts services. During switch, `acore-manager` relinks shared configs into the new active release before starting services:

```text
/opt/acore-manager/current/etc/authserver.conf -> /opt/acore-manager/shared/configs/authserver.conf
/opt/acore-manager/current/etc/worldserver.conf -> /opt/acore-manager/shared/configs/worldserver.conf
/opt/acore-manager/current/etc/modules -> /opt/acore-manager/shared/configs/modules
```

## Full Workflow

```bash
./bin/acore-manager release-latest
```

This orchestrates validation, DB check, source/module updates, build, release creation, optional config backup, release switch, and final status. It calls the smaller scripts rather than duplicating their logic.

Use the high-level workflow only after the manual flow is understood and the server already has working data, configs, databases, and services.

## Prune Releases

Preview pruning old releases:

```bash
./bin/acore-manager prune-releases --dry-run
```

Apply deletion explicitly:

```bash
sudo ./bin/acore-manager prune-releases --keep 5 --apply
```
