# OliveTin

OliveTin is an optional web UI for running predefined shell commands. In `acore-manager`, it can provide buttons for common server actions while still calling the normal CLI wrapper:

```text
/opt/acore-manager/bin/acore-manager
```

`acore-manager` does not require OliveTin. Do not expose OliveTin directly to the public internet; treat it as LAN/VPN/Twingate-only.

## Files

```text
olivetin/config.yaml.example
olivetin/acore-manager.sudoers.example
scripts/integrations/acore-render-olivetin-config.sh
scripts/integrations/acore-install-olivetin.sh
scripts/integrations/acore-validate-olivetin-config.sh
```

The example config includes buttons for status, logs, service restarts, backups, build/release actions, and rollback. Long-running or dangerous actions include confirmation prompts where OliveTin supports them.

The example also sets explicit per-action timeouts. OliveTin defaults actions to 3 seconds, which is too short for log review, service restarts, backups, builds, and release workflows.

## Validate The Example

From the repo:

```bash
./scripts/integrations/acore-validate-olivetin-config.sh
```

Basic CLI test:

```bash
/opt/acore-manager/bin/acore-manager status
```

## Render Config Only

If OliveTin is already installed, render the acore-manager config:

```bash
sudo ./scripts/integrations/acore-render-olivetin-config.sh
```

This creates `/etc/OliveTin` if missing, backs up any existing `/etc/OliveTin/config.yaml`, and writes the example config to:

```text
/etc/OliveTin/config.yaml
```

It does not install, enable, or start OliveTin.

## Install OliveTin

To install OliveTin on an amd64/x86_64 Ubuntu/Debian host:

```bash
sudo ./scripts/integrations/acore-install-olivetin.sh
```

The installer:

- installs `curl` and `ca-certificates` if needed
- downloads the latest official `.deb` from GitHub
- installs the package with dependency resolution
- renders the acore-manager OliveTin config
- enables and starts the `OliveTin` service
- does not open firewall ports

Access hint:

```text
http://SERVER-IP:1337
```

Replace `SERVER-IP` with the server address reachable from your LAN/VPN.

## Service Status And Logs

```bash
systemctl status OliveTin --no-pager
journalctl -u OliveTin -n 100 --no-pager
```

Default OliveTin port:

```text
1337
```

## Changing Button Icons

The example config sets global defaults with `defaultIconForActions`, `defaultIconForDirectories`, and `defaultIconForBack`. Individual buttons can override the action default with an `icon` field:

```yaml
actions:
  - title: Status
    icon: "📊"
    shell: "/opt/acore-manager/bin/acore-manager status"
```

Edit `olivetin/config.yaml.example` before rendering, or edit `/etc/OliveTin/config.yaml` directly after rendering and restart OliveTin.

## Firewall

Do not expose OliveTin publicly. If using UFW, allow only a trusted LAN/VPN range, for example:

```bash
sudo ufw allow from 192.168.50.0/24 to any port 1337 proto tcp comment 'OliveTin LAN'
```

Adjust the network range for your environment.

## Disable OliveTin

```bash
sudo systemctl disable --now OliveTin
```

## Permissions And Sudoers

Depending on the package/service configuration, OliveTin may run as root. If it runs as root, the sudoers example is not needed.

For a hardened non-root setup, run OliveTin as a dedicated service user, install a narrow sudoers rule, and change OliveTin action commands to use `sudo -n`.

Example sudoers file:

```text
olivetin/acore-manager.sudoers.example
```

Install it with validation:

```bash
sudo install -m 0440 olivetin/acore-manager.sudoers.example /etc/sudoers.d/acore-manager-olivetin
sudo visudo -cf /etc/sudoers.d/acore-manager-olivetin
```

The sudoers example grants only listed `acore-manager` commands. It does not allow `NOPASSWD: ALL`.

## Troubleshooting

### Config YAML Invalid

Check OliveTin logs:

```bash
journalctl -u OliveTin -n 100 --no-pager
```

Re-render the config:

```bash
sudo ./scripts/integrations/acore-render-olivetin-config.sh
```

### Command Permission Denied

Check whether OliveTin is running as root or as another user:

```bash
systemctl cat OliveTin
systemctl status OliveTin --no-pager
```

If using a non-root service user, review `olivetin/acore-manager.sudoers.example`.

### Runtime Still Uses build/staging

OliveTin buttons call `bin/acore-manager`, but systemd may still have older installed unit files that point at build staging. Check and fix them on the server:

```bash
sudo /opt/acore-manager/bin/acore-manager fix-runtime-paths
sudo /opt/acore-manager/bin/acore-manager fix-runtime-paths --apply
sudo /opt/acore-manager/bin/acore-manager validate-runtime
```

Then retry the OliveTin action. The fix reloads systemd but does not restart services.

### acore-manager Script Not Executable

```bash
sudo bash /opt/acore-manager/scripts/setup/acore-fix-permissions.sh
```

### Browser Cannot Connect

Check service status and listening port:

```bash
systemctl status OliveTin --no-pager
ss -ltn | grep ':1337'
```

Confirm your firewall allows access only from the trusted LAN/VPN range.

### Service Failed To Start

```bash
journalctl -u OliveTin -n 100 --no-pager
./scripts/integrations/acore-validate-olivetin-config.sh
```

Fix the reported issue, then restart:

```bash
sudo systemctl restart OliveTin
```
