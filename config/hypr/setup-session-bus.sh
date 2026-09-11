#!/bin/bash
# Hexarchy session bus fix for systemd-free (runit) systems.
#
# On systemd, busctl --user connects to the per-user bus socket at
# $XDG_RUNTIME_DIR/bus. Without systemd there is no such socket, so Hexarchy
# commands that notify via D-Bus (e.g. the hardware menu, monitor toggles)
# fail with "Failed to connect to user scope bus".
#
# The live session bus runs on a dbus-launch socket recorded in
# ~/.dbus/session-bus/<machine-id>-<display>. Read that address and expose it
# at the standard $XDG_RUNTIME_DIR/bus path so busctl --user works.

bus="$XDG_RUNTIME_DIR/bus"
[ -S "$bus" ] && exit 0

busfile="$(ls -t "$HOME"/.dbus/session-bus/* 2>/dev/null | head -n1)"
[ -n "$busfile" ] || exit 0

addr="$(sed -n "s/^DBUS_SESSION_BUS_ADDRESS=.*'unix:path=\([^,']*\).*/\1/p" "$busfile" | head -n1)"
[ -n "$addr" ] || exit 0
[ -S "$addr" ] || exit 0

ln -s "$addr" "$bus"