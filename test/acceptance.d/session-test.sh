#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# The compositor reports at least one monitor
monitors=$(hyprctl -j monitors | jq 'length')
(( monitors >= 1 )) || fail "compositor reports a monitor"
pass "compositor reports a monitor"

# The Hexarchy shell is running and responsive
wait_until "hexarchy-shell responds to ping" 60 hexarchy-shell shell ping

# Core shell plugins are loaded
plugins=$(hexarchy-shell shell listPlugins)
for plugin in \
  hexarchy.audio hexarchy.background hexarchy.bar hexarchy.bluetooth \
  hexarchy.clipboard hexarchy.emojis hexarchy.menu \
  hexarchy.monitor hexarchy.network hexarchy.notifications hexarchy.power \
  hexarchy.reminders hexarchy.weather; do
  [[ $plugins == *"$plugin"* ]] || fail "shell plugin is loaded: $plugin" "loaded plugins: $plugins"
  pass "shell plugin is loaded: $plugin"
done

# The bar and background are actually on screen
wait_until "bar layer is on screen" 30 layer_on_screen "hexarchy-bar"
wait_until "background layer is on screen" 30 layer_on_screen "hexarchy-background"

# Hiding parks the bar off-screen without unmapping its layer surface, and
# revealing brings that same surface back on-screen.
restore_bar_visibility() {
  hexarchy-toggle-bar off >/dev/null 2>&1 || true
}
trap restore_bar_visibility EXIT

hexarchy-toggle-bar on
wait_until "hidden bar layer stays mapped" 15 layer_present "hexarchy-bar"
wait_until "hidden bar layer parks off screen" 15 layer_off_screen "hexarchy-bar"
screenshot "success-bar-hidden"

hexarchy-toggle-bar off
wait_until "revealed bar layer returns on screen" 15 layer_on_screen "hexarchy-bar"
screenshot "success-bar-revealed"
trap - EXIT

# Audio stack is up
wait_until "pipewire is running" 30 wpctl status

# Root filesystem is btrfs as installed
[[ $(findmnt -no FSTYPE /) == "btrfs" ]] || fail "root filesystem is btrfs"
pass "root filesystem is btrfs"

# Hexarchy reports its version
hexarchy-version >/dev/null || fail "hexarchy-version works"
pass "hexarchy-version works"

# No failed units, system or user. HEXARCHY_ACCEPTANCE_IGNORE_UNITS can hold a
# regex of units to overlook (useful on dev machines; a fresh VM should be clean).
failed_units() {
  systemctl "$@" --failed --no-legend --plain | awk '{print $1}' |
    grep -Ev "${HEXARCHY_ACCEPTANCE_IGNORE_UNITS:-^$}" || true
}

failed_system=$(failed_units --system)
if [[ -n $failed_system ]]; then
  fail "no failed system units" "failed units: $failed_system"
fi
pass "no failed system units"

failed_user=$(failed_units --user)
if [[ -n $failed_user ]]; then
  fail "no failed user units" "failed units: $failed_user"
fi
pass "no failed user units"

screenshot "success-desktop"
