# Modules

Modules are optional Git repositories cloned into the AzerothCore source checkout before Docker Compose builds the services.

Create a local module list:

```bash
cp config/defaults/modules.txt.example config/local/modules.txt
```

Format:

```text
module-name|git-url|branch
```

Example:

```text
mod-example|https://github.com/example/mod-example.git|master
```

Run:

```bash
./bin/acore-manager docker sync-modules
```

Each active module is cloned or updated at:

```text
build/azerothcore/modules/<module-name>
```

Only simple module directory names are accepted: letters, numbers, `.`, `_`, and `-`.
