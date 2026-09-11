#!/bin/bash
# Hexarchy: Enable runit services (replaces systemd systemctl enable calls)
# This script runs during installation on Artix Linux (runit)

set -euo pipefail

SV_DIR="/etc/runit/sv"
RUNLEVEL="/run/runit/service"

# Ensure runit service directory exists
mkdir -p "$SV_DIR"
mkdir -p "$RUNLEVEL"

# Copy hexarchy's runit services to the system
cp -rn "$HEXARCHY_PATH/sv/"* "$SV_DIR/" 2>/dev/null || true

enable_service() {
  local svc="$1"
  if [ -d "$SV_DIR/$svc" ]; then
    ln -sf "$SV_DIR/$svc" "$RUNLEVEL/$svc"
    echo "[hexarchy] Enabled service: $svc"
  else
    echo "[hexarchy] WARNING: Service directory not found: $SV_DIR/$svc" >&2
  fi
}

# Core services (order matters for dependencies)
enable_service dbus
enable_service elogind
enable_service polkitd
enable_service rsyslog
enable_service networkmanager
enable_service sddm
enable_service avahi-daemon
enable_service cupsd
enable_service cups-browsed
enable_service docker
enable_service earlyoom
enable_service sshd
enable_service ufw
enable_service cronie

echo "[hexarchy] All services enabled. Reboot to start them."
