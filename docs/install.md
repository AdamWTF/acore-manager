# Install

`acore-manager` is designed to run on a Linux host that will build and operate an AzerothCore server. The default install root is:

```text
/opt/acore-manager
```

## Clone

Clone the repository where you want to manage it. If you use the default root:

```bash
sudo mkdir -p /opt/acore-manager
sudo chown "$USER":"$USER" /opt/acore-manager
git clone https://github.com/AdamWTF/acore-manager.git /opt/acore-manager
cd /opt/acore-manager
```

## Bootstrap

Ensure executable permissions are present before the first direct script run:

```bash
find scripts -type f -name "*.sh" -exec chmod +x {} \;
chmod +x bin/acore-manager 2>/dev/null || true
```

Run the bootstrap script:

```bash
sudo ./scripts/setup/acore-bootstrap.sh
```

The bootstrap script:

- installs typical Ubuntu/Debian build dependencies
- creates the configured `ACORE_USER` and `ACORE_GROUP` if missing
- creates standard directories under `/opt/acore-manager`
- copies default config examples into `config/local/` only when missing
- installs systemd service templates, backing up replaced units when `--force` is used
- enables and starts the safe shutdown hook
- installs idle sleep proxy/monitor services
- enables idle sleep services when `SLEEP_ENABLED` is true and starts them only when the auth backend/public port split is already configured

To overwrite installed service templates:

```bash
sudo ./scripts/setup/acore-bootstrap.sh --force
```

The bootstrap does not build AzerothCore and does not enable or start auth/world services. For existing installs, use [Updating acore-manager](updating-manager.md) instead of rerunning full bootstrap.

## Permission Denied Recovery

If a copied checkout loses executable bits and a script fails with `Permission denied`, run:

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```

Or use standard shell commands:

```bash
sudo find /opt/acore-manager/scripts -type f -name "*.sh" -exec chmod +x {} \;
sudo chmod +x /opt/acore-manager/bin/acore-manager 2>/dev/null || true
```

If you manage the host remotely, confirm shell access before running host setup:

```bash
ssh <server-host>
```

## Verify

After bootstrap:

```bash
./bin/acore-manager validate
./bin/acore-manager service-status
./bin/acore-manager doctor
```

If `bin/acore-manager` is added to your `PATH`, you can run `acore-manager` from anywhere.

At this point you have `acore-manager` installed, not necessarily a running AzerothCore server. Continue with [Full Server Setup](full-server-setup.md) for source updates, build/release, client data files, runtime configs, databases, systemd services, logs, firewall, and client connection checks.

Release creation alone is not enough. A first server still needs shared configs, data files, databases, and a release switch. For idle sleep, set `RealmServerPort = 3725` in shared `authserver.conf` before starting the sleep proxy.
