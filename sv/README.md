# Hexarchy Runit Services

These are runit service definitions that replace Omarchy's systemd service enables.
They live at `$HEXARCHY_PATH/sv/` and are symlinked into `/etc/runit/sv/` during install.

## Service Map (systemd -> runit)

| Omarchy (systemd)          | Hexarchy (runit)           | Package Required            |
|---------------------------|---------------------------|-----------------------------|
| `systemctl enable dbus`    | `sv/dbus/run`              | `dbus-runit`                |
| `systemctl enable elogind` | `sv/elogind/run`           | `elogind-runit`             |
| `systemctl enable NetworkManager` | `sv/networkmanager/run` | `networkmanager-runit`      |
| `systemctl enable sddm`    | `sv/sddm/run`              | `sddm-runit`                |
| `systemctl enable cups`    | `sv/cupsd/run`             | `cups-runit`                |
| `systemctl enable cups-browsed` | `sv/cups-browsed/run`  | `cups-browsed`              |
| `systemctl enable avahi-daemon` | `sv/avahi-daemon/run`  | `avahi-runit`               |
| `systemctl enable docker`  | `sv/docker/run`            | `docker-runit`              |
| `systemctl enable earlyoom`| `sv/earlyoom/run`          | `earlyoom`                  |
| `systemctl enable sshd`    | `sv/sshd/run`              | `openssh`                   |
| `systemctl enable ufw`     | `sv/ufw/run`               | `ufw`                       |
| `systemctl enable crond`   | `sv/cronie/run`            | `cronie`                    |
| `systemctl enable rsyslog` | `sv/rsyslog/run`           | `rsyslog`                   |
| `systemctl enable polkitd` | `sv/polkitd/run`           | `polkit`                    |
| `systemctl enable dnscrypt-proxy` | `sv/dnscrypt-proxy/run` | `dnscrypt-proxy`          |

## User Services

| Omarchy (systemd --user)   | Hexarchy (runit user)       | Notes                         |
|---------------------------|---------------------------|-------------------------------|
| `pipewire.service`         | `sv/user-services/pipewire/run` | Started via Hyprland autostart |
| `wireplumber.service`     | `sv/user-services/wireplumber/run` | Dependency: pipewire    |
| `pipewire-pulse.service`  | `sv/user-services/pipewire-pulse/run` | Dependency: pipewire |

## Installation

```sh
# Copy service directories to the Artix runit sv dir
sudo cp -r $HEXARCHY_PATH/sv/* /etc/runit/sv/

# Enable services (symlink into current runlevel)
sudo ln -s /etc/runit/sv/dbus /run/runit/service/
sudo ln -s /etc/runit/sv/elogind /run/runit/service/
sudo ln -s /etc/runit/sv/networkmanager /run/runit/service/
sudo ln -s /etc/runit/sv/sddm /run/runit/service/
sudo ln -s /etc/runit/sv/cupsd /run/runit/service/
sudo ln -s /etc/runit/sv/cups-browsed /run/runit/service/
sudo ln -s /etc/runit/sv/avahi-daemon /run/runit/service/
sudo ln -s /etc/runit/sv/docker /run/runit/service/
sudo ln -s /etc/runit/sv/earlyoom /run/runit/service/
sudo ln -s /etc/runit/sv/sshd /run/runit/service/
sudo ln -s /etc/runit/sv/ufw /run/runit/service/
sudo ln -s /etc/runit/sv/cronie /run/runit/service/
sudo ln -s /etc/runit/sv/rsyslog /run/runit/service/
sudo ln -s /etc/runit/sv/polkitd /run/runit/service/

# Or use hexarchy's installer:
hexarchy config services
```

## Key Differences from Omarchy

- **No systemd-resolved**: DNS handled by `/etc/resolv.conf` or `dnscrypt-proxy`
- **No systemd-oomd**: Replaced by `earlyoom` (lighter, no systemd dependency)
- **No plymouth**: Boot splash removed (handled by Quickshell screensaver post-boot)
- **No systemd-timers**: Replaced by `cronie` for scheduled tasks
- **No journald**: Replaced by `rsyslog` with traditional log files
- **No kernel-modules-hook**: One-shot runit service + cronie
- **No zram-generator**: Use `zramen` (Artix runit package)
