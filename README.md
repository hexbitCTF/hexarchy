# Hexarchy

A beautiful, modern & opinionated Linux distribution forked from [Omarchy](https://omarchy.org) by DHH, running on **Artix Linux** with **runit** (no systemd).

Hexarchy brings the same stunning Hyprland + Quickshell desktop experience to a systemd-free Artix base, replacing every systemd component with its runit/elogind equivalent.

## What Makes Hexarchy Different

| Component | Omarchy (Arch + systemd) | Hexarchy (Artix + runit) |
|---|---|---|
| Init system | systemd | runit |
| Service manager | systemctl | sv |
| Login manager | systemd-logind | elogind |
| Device manager | systemd-udevd | eudev |
| Logging | journald | rsyslog |
| DNS | systemd-resolved | NetworkManager / dnscrypt-proxy |
| Timers | systemd timers | cronie |
| OOM killer | systemd-oomd | earlyoom |
| Boot splash | Plymouth | Quickshell screensaver |
| Process supervisor | systemd cgroups | runit supervision |

## Desktop Stack (Unchanged from Omarchy)

- **Window Manager:** Hyprland (tiling compositor with animations)
- **Desktop Shell:** Quickshell (bar, launcher, notifications, lock screen)
- **Terminal:** Foot
- **Editor:** Neovim
- **Browser:** Chromium
- **Audio:** PipeWire + WirePlumber
- **Theme System:** 22 built-in themes with live switching

## Quick Start

```sh
# On a fresh Artix Linux (runit) installation:
git clone https://github.com/hexbitCTF/hexarchy.git /tmp/hexarchy
sudo bash /tmp/hexarchy/install/setup.sh
```

Already running Artix with a different window manager or desktop (dwm, i3,
sway, GNOME/KDE/XFCE…)? `install/to-hexarchy.sh` swaps in Hexarchy without
touching your files — conflicting packages and services are stopped, your old
configs are backed up, and everything is logged.

```sh
bash install/to-hexarchy.sh --dry-run          # preview conflicts, change nothing
bash install/to-hexarchy.sh                    # migrate (keeps your configs, stops conflicts)
bash install/to-hexarchy.sh --remove-conflicts # also uninstall the old WM/DE/DM
```

Your shell dotfiles (.bashrc/.zshrc/.profile/…), X resources, editor/tmux/git
config, WM/DE configs and session scripts are moved into a timestamped backup
and fully logged. Don't like it? Roll the whole thing back:

```sh
bash install/rollback-hexarchy.sh                     # restore from the latest backup
bash install/rollback-hexarchy.sh --remove-hexarchy   # also uninstall the Hyprland/sddm stack
bash install/rollback-hexarchy.sh --dry-run           # preview without touching anything
```

Stop by `install/setup.sh` alone to skip the old-desktop cleanup.

## Repository Structure

```
hexarchy/
  bin/              437 CLI commands (hexarchy-* dispatcher)
  sv/               Runit service definitions (25 services)
  shell/            Quickshell desktop shell (QML)
  config/           Hyprland, shell, themes configuration
  themes/           22 color themes
  default/          Default configs and dotfiles
  etc/              System configs (elogind, NetworkManager)
  install/          Install scripts and package lists
  applications/     .desktop files
  manual/           User manual
  migrations/       Version migration scripts
```

## Runit Services

Hexarchy provides runit service scripts for all system services:

- **Core:** dbus, elogind, polkitd, rsyslog
- **Desktop:** sddm, quickshell
- **Network:** networkmanager, avahi-daemon, ufw
- **Printing:** cupsd, cups-browsed
- **Docker:** docker
- **System:** earlyoom, cronie, sshd, dnscrypt-proxy
- **User:** pipewire, wireplumber, pipewire-pulse

See [`sv/README.md`](sv/README.md) for the full service map.

## Packages

See [`install/hexarchy-base.packages`](install/hexarchy-base.packages) for the complete package list. Key Artix-specific packages:

- `elogind-runit`, `dbus-runit`, `sddm-runit`
- `networkmanager-runit`, `avahi-runit`, `cups-runit`
- `docker-runit`, `ufw-runit`, `openssh-runit`
- `earlyoom` (replaces systemd-oomd)
- `rsyslog` (replaces journald)
- `eudev` (replaces systemd-udevd)

## License

Hexarchy is released under the [MIT License](https://opensource.org/licenses/MIT).

Based on [Omarchy](https://github.com/basecamp/omarchy) by 37signals.
