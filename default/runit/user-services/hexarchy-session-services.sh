#!/bin/bash
# Hexarchy user services - replaces systemd --user services
# Started by Hyprland autostart or userspawn

# Start PipeWire stack (if not already running)
pgrep -x pipewire >/dev/null || pipewire &
pgrep -x wireplumber >/dev/null || wireplumber &
pgrep -x pipewire-pulse >/dev/null || pipewire-pulse &

# Start other user services
pgrep -x fcitx5 >/dev/null || fcitx5 -d &
