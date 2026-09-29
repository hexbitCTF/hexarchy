#!/bin/bash
# Eagerly start a real D-Bus session bus at a fixed, predictable path
# ($XDG_RUNTIME_DIR/bus) instead of leaving it to lazy dbus-launch autolaunch.
#
# Runit/Artix has no systemd --user to provide this. Hexarchy's
# setup-session-bus.sh already *reacts* to a bus if one exists (symlinking it
# to the systemd-convention path), but nothing was actually *starting* one:
# it relied on whichever app happened to need D-Bus first (gamemode, in
# practice) to trigger dbus-launch's X11 autolaunch fallback. That fallback
# is racy under Xwayland here: concurrent autolaunch attempts (e.g. several
# of gamemode/wine's subprocesses connecting at once) can spiral into a
# runaway self-forking dbus-launch loop that exhausts the whole system's PID
# table (kernel.pid_max) and requires a hard reboot to clear.
#
# Starting the daemon here, at a fixed path matching the DBUS_SESSION_BUS_ADDRESS
# set in autostart.lua, means every app Hyprland launches already has a
# working bus in its environment and never needs to hit autolaunch at all.

bus="$XDG_RUNTIME_DIR/bus"
[ -S "$bus" ] && exit 0

dbus-daemon --session --fork --address="unix:path=$bus"
