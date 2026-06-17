# AGENTS.md

## Project Overview

`acore-manager` is a generic automation wrapper for the normal AzerothCore Docker Compose workflow.

It helps operators clone/update AzerothCore source, clone/update configured modules, generate Docker Compose overrides, run the standard Docker build/start/import lifecycle, manage persistent config/data/log mounts, and optionally target an external MySQL host.

This repository must stay generic. It is not tied to a private realm, custom repack, personal environment, private registry, or curated private module set.

## Core Principles

- Prefer small, reviewable changes.
- Keep the project focused on automating the AzerothCore Docker Compose workflow.
- Preserve existing behavior unless the task explicitly asks for a behavior change.
- Keep scripts composable and clear.
- Fail clearly with useful messages.
- Do not assume a specific server, module pack, hostname, user, IP address, registry, or database credential.

## Repository Conventions

- `bin/acore-manager` is the user-facing CLI dispatcher.
- `scripts/lib/common.sh` is the shared shell loader for config and derived paths.
- Docker workflow scripts live in `scripts/docker/`.
- Default/example config belongs in `config/defaults/`.
- Local user config belongs in `config/local/` and should remain gitignored.
- Public docs live in `README.md` and `docs/`.
- Generated Docker Compose files belong under `build/docker-compose/`.
- Cloned AzerothCore source belongs under `build/azerothcore/` by default.

## Shell Script Conventions

- Use Bash for project scripts.
- Start scripts with:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

- Source `scripts/lib/common.sh` instead of duplicating config/path logic.
- Use configured values from common config, especially source, module, service, path, and Docker settings.
- Keep scripts idempotent where practical.
- Check required commands before using them.
- Print clear status messages before important actions.
- Do not put credentials into committed Compose files, metadata files, docs, or examples.
- Do not add backups, deployment orchestration beyond the local Docker Compose lifecycle, or host/service-control workflows outside Compose.

## Config And Secrets Rules

- Public files must not contain private IPs, hostnames, usernames, passwords, emails, access tokens, personal branding, private registry credentials, or private server names.
- Use placeholders in docs/examples, such as `<registry-host>`.
- Do not commit real `config/local/docker-manager.conf`, `config/local/modules.txt`, or `.env`.
- Do not add private module packs to default examples.
- Do not hardcode credentials into scripts, docs, committed Compose files, metadata, or examples.
- `config/defaults/*.example` files should contain safe generic defaults only.

## Testing And Validation Expectations

For shell changes, run syntax checks where possible:

```bash
bash -n path/to/script.sh
```

For dispatcher changes, smoke-test read-only commands:

```bash
./bin/acore-manager --help
./bin/acore-manager docker validate
```

For Docker Compose changes:

```bash
docker compose version
```

Do not push images unless the user explicitly asked for that action and registry authentication is already configured.

For documentation or public examples, scan for private values and stale command names.

## Documentation Expectations

- Keep `README.md` concise.
- Put practical details in `docs/`.
- Make command examples match real scripts or `bin/acore-manager` commands.
- Keep docs generic and public-safe.
- Update docs when script names, paths, config keys, or workflows change.

## Things Agents Must Not Do

- Do not introduce private branding, private paths, private IPs, usernames, passwords, emails, hostnames, tokens, or registry credentials.
- Do not replace generic defaults with one server's local configuration.
- Do not commit files under `config/local/` except `.gitkeep`.
- Do not reintroduce operational management helpers or deployment orchestration outside the Compose lifecycle.
- Do not delete local images, build caches, or registry artifacts unless explicitly asked.
- Do not reintroduce a monolithic build-and-deploy script.

## Suggested Pre-Commit Checklist

- Scripts use `scripts/lib/common.sh` where config or derived paths are needed.
- Shell scripts pass `bash -n`.
- Commands in docs match files that exist.
- Public files contain no secrets or private values.
- Local config remains ignored by git.
- Compose overrides, metadata, and docs do not leak credentials.

## When Unsure

Prefer small, reviewable changes. Preserve generic behavior. Ask for clarification rather than making broad architecture changes.
