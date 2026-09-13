# systemd-free

This fork runs [Omarchy Quattro](https://github.com/basecamp/omarchy) on
**Artix Linux with runit** — no systemd. Omarchy targets systemd, so this
directory is the compatibility layer that replaces the systemd-dependent
pieces that would otherwise be broken, plus the shortcuts wired into the
session.

## Component mapping

| systemd component | Replaced by | runit service |
|---|---|---|
| Init / PID 1 | runit (runit + runit-rc) | — |
| Service manager (`systemctl`) | `sv` (see `systemctl` shim below) | — |
| `systemd-logind` | elogind | `elogind` / `logind` |
| `systemd-udevd` | eudev | `udevd` |
| journald | rsyslog | `rsyslog` |
| `systemd-resolved` | NetworkManager / dnscrypt-proxy | `NetworkManager` / `dnscrypt-proxy` |
| systemd timers | cronie | `cronie` |
| `systemd-oomd` | earlyoom | `earlyoom` |
| systemd `--user` services | launched from `~/.config/hypr/autostart.lua` | runit `user-services` |
| Session cgroups (`uwsm-app`) | direct exec | — |
| User session bus (`$XDG_RUNTIME_DIR/bus`) | bridged by `setup-session-bus.sh` | — |
| Plymouth boot splash | Quickshell screensaver | — |

Standard Artix base services (agetty, `NetworkManager`, `udevd`, `zram`,
`sulogin`, …) ship in the `runit`/`runit-rc` and `*-runit` packages; the
Hexarchy-specific service definitions live in [`sv/`](../sv).

## Inventory

| File | Purpose | Install to |
|---|---|---|
| `usr-local-bin/systemctl` | Shim that maps the handful of `systemctl` verbs (from the Arch/systemd lineage) to `sv`, so `hexarchy-migrate` and installed tools run cleanly. Units translate by name (`NetworkManager.service` → `NetworkManager`, `systemd-logind` → `logind`, …). The power verbs `suspend` / `hibernate` / `poweroff` / `reboot` exec `loginctl` instead of no-op'ing. Everything else is a no-op. | `/usr/local/bin/systemctl` |
| `usr-local-bin/timedatectl` | Shim for `timedatectl` (no systemd-timesyncd is present). `list-timezones` (reads the tzdata tree), `set-timezone <tz>` (localetime symlink + `/etc/timezone`), `show -p Timezone --value`, `set-ntp` (no-op; chrony owns NTP). Backs the timezone menu item and the installer's `hexarchy-provision-owner`. | `/usr/local/bin/timedatectl` |
| `usr-local-bin/hostnamectl` | Shim for `hostnamectl`. `set-hostname <name>` writes `/etc/hostname` and updates `kernel.hostname`; `show` prints a minimal status; `set-*` other verbs no-op. Used by the installer's provisioner. | `/usr/local/bin/hostnamectl` |
| `usr-local-bin/localectl` | Shim for `localectl`. `list-keymaps` (from `/usr/share/kbd/keymaps`) and `set-keymap <km>` (persists `KEYMAP=` in `/etc/vconsole.conf` and reloads it). `--no-pager` is accepted. Used by the installer's provisioner. | `/usr/local/bin/localectl` |
| `usr-local-bin/uwsm-app` | `uwsm-app` wraps apps in a cgroup on systemd; on runit we just exec the command. | `/usr/local/bin/uwsm-app` |
| `usr-local-bin/xdg-terminal-exec` | Terminal selection for systems without `xdg-utils` ≥ 1.2.2. Prefers kitty, falls back to foot. | `/usr/local/bin/xdg-terminal-exec` |
| `usr-local-bin/hexarchy-terminal` | The terminal shortcut (`kitty`). | `/usr/local/bin/hexarchy-terminal` |
| `usr-local-bin/hexarchy-restart-cava` | Reloads cava after theme changes (`pkill -SIGUSR1 cava`). | `/usr/local/bin/hexarchy-restart-cava` |
| `../config/hypr/setup-session-bus.sh` | Bridges the live `dbus-launch` session socket to `$XDG_RUNTIME_DIR/bus` so `busctl --user` (hardware menu, monitor toggles) works without systemd. Launched from `../config/hypr/autostart.lua`. | `~/.config/hypr/setup-session-bus.sh` |

## Install

```sh
install -Dm755 usr-local-bin/* /usr/local/bin/
```

The Hyprland config (`config/hypr/`) is laid down as user config as usual; it
launches `setup-session-bus.sh` and the runit session-equivalents of the
systemd `--user` services on session start.