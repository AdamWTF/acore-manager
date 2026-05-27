# Idle Sleep

`acore-manager` can reduce idle CPU usage by freezing `authserver` and `worldserver` when no players are connected. It uses `SIGSTOP` to sleep the processes and `SIGCONT` to wake them.

Sleep mode is enabled by default in the example config:

```bash
SLEEP_ENABLED="true"
SLEEP_IDLE_TIMEOUT="300"
AUTH_PUBLIC_PORT="3724"
AUTH_BACKEND_PORT="3725"
WORLD_PORTS="8085 3443"
```

Clients still connect to auth port `3724`. The sleep proxy listens on `3724`, wakes the frozen server if needed, then forwards the login connection to the real authserver on `3725`.

## Requirements

Bootstrap installs the required tools on Debian/Ubuntu hosts:

```bash
sudo ./scripts/setup/acore-bootstrap.sh
```

The sleep scripts need `socat`, `ss`, `pgrep`, `ps`, and `systemd`.

## Configure Auth Backend Port

Before starting the sleep proxy, change the shared `authserver.conf` so the real authserver listens on the backend port:

```text
RealmServerPort = 3725
```

The public client port remains `3724`; do not change client realmlists for sleep mode.

Validate the setup:

```bash
./bin/acore-manager validate
./bin/acore-manager sleep-status
```

If validation says `RealmServerPort` is still `3724`, update the shared config and restart auth/world before starting the proxy.

## Services

Bootstrap installs and enables:

```text
acore-sleep-proxy.service
acore-sleep-monitor.service
```

It starts them only when `authserver.conf` is already configured for the backend port and the public port is free. If bootstrap leaves them enabled but stopped, finish the auth port change, then run:

```bash
sudo systemctl start acore-sleep-proxy.service
sudo systemctl start acore-sleep-monitor.service
```

Check status:

```bash
./bin/acore-manager sleep-status
journalctl -u acore-sleep-proxy.service -n 100 --no-pager
journalctl -u acore-sleep-monitor.service -n 100 --no-pager
```

## Manual Commands

```bash
./bin/acore-manager sleep-status
sudo ./bin/acore-manager sleep-thaw
sudo ./bin/acore-manager sleep-freeze
```

Normal `stop`, `restart`, `restart-world`, `restart-auth`, `switch-release`, and `rollback` commands thaw processes first when sleep mode is enabled.

## Roll Back Sleep Mode

To disable sleep mode and return authserver to the public port:

```bash
sudo systemctl disable --now acore-sleep-monitor.service
sudo systemctl disable --now acore-sleep-proxy.service
sudo ./bin/acore-manager sleep-thaw
```

Set this in `config/local/manager.conf`:

```bash
SLEEP_ENABLED="false"
```

Then change shared `authserver.conf` back to:

```text
RealmServerPort = 3724
```

Restart the server:

```bash
sudo ./bin/acore-manager restart
```

## Notes

- Playerbot or NPC automation modules may need their own idle behavior reviewed after thaw.
- Keep `WORLD_PORTS` aligned with the ports that indicate real player activity.
- Do not use the same value for `AUTH_PUBLIC_PORT` and `AUTH_BACKEND_PORT`.
