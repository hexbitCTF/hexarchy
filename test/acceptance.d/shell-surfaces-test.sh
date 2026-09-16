#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

open_and_close() {
  local name="$1" plugin="$2" namespace="$3" payload="${4:-}"

  if [[ -n $payload ]]; then
    hexarchy-shell shell summon "$plugin" "$payload" >/dev/null
  else
    hexarchy-shell shell summon "$plugin" >/dev/null
  fi

  wait_until "$name opens" 15 layer_present "$namespace"
  sleep 1
  screenshot "success-$name-open"

  hexarchy-shell shell hide "$plugin" >/dev/null
  wait_until "$name closes" 15 layer_absent "$namespace"
}

# Search and select an emoji. The host harness separately proves the shortcut
# with a QMP hardware key chord, while this test focuses on UI behavior.
hexarchy-shell shell summon hexarchy.emojis >/dev/null
wait_until "emoji picker opens" 15 layer_present "hexarchy-emojis"
wtype "rocket"
sleep 1
screenshot "success-emoji-picker-search"
wtype -k Return
wait_until "emoji picker selection closes" 15 layer_absent "hexarchy-emojis"

# Seed two clipboard entries, search for the older one, and copy it back out.
clipboard_token="Hexarchy acceptance clipboard $(date +%s)"
printf '%s' "$clipboard_token" | wl-copy
wait_until "clipboard history captures test text" 15 grep -Fq "$clipboard_token" "$HOME/.local/state/hexarchy/clipboard-history.json"
printf '%s' "clipboard decoy" | wl-copy
sleep 1

hexarchy-shell shell summon hexarchy.clipboard >/dev/null
wait_until "clipboard opens" 15 layer_present "hexarchy-clipboard"
wtype "$clipboard_token"
wait_until "clipboard search finds test text" 15 screen_contains "Hexarchy acceptance clipboard"
screenshot "success-clipboard-search"
wtype -M shift -k Return -m shift
wait_until "clipboard selection closes" 15 layer_absent "hexarchy-clipboard"
wait_until "clipboard selection restores test text" 15 bash -c '[[ $(wl-paste --no-newline) == "$1" ]]' _ "$clipboard_token"

# Exercise the system branch without invoking any destructive action.
hexarchy-shell shell summon hexarchy.menu '{"menu":"system"}' >/dev/null
wait_until "system menu opens" 15 layer_present "hexarchy-menu"
wait_until "system menu content is visible" 15 screen_contains "Shutdown"
screenshot "success-system-menu"
wtype -k Escape
wait_until "system menu closes" 15 layer_absent "hexarchy-menu"

# Preview both visual selectors and cancel without changing user state. These
# cover thumbnail generation, the image-grid overlay, and current selection.
launch_app "hexarchy-theme-bg-switcher"
wait_until "background selector opens" 30 layer_present "hexarchy-image-selector"
sleep 1
screenshot "success-background-selector"
wtype -k Escape
wait_until "background selector closes" 15 layer_absent "hexarchy-image-selector"

launch_app "hexarchy-theme-switcher"
wait_until "theme selector opens" 30 layer_present "hexarchy-image-selector"
sleep 1
screenshot "success-theme-selector"
wtype -k Escape
wait_until "theme selector closes" 15 layer_absent "hexarchy-image-selector"

# Walk the reminder flow through each input screen, but dismiss before it
# schedules a real timer in the test user's session.
hexarchy-shell shell summon hexarchy.reminders >/dev/null
wait_until "reminder flow opens" 15 layer_present "hexarchy-reminders"
screenshot "success-reminder-01-minutes-prompt"
wtype "5"
sleep 1
screenshot "success-reminder-02-minutes-entered"
wtype -k Return
wait_until "reminder message prompt opens" 15 screen_contains "Reminder message"
screenshot "success-reminder-03-message-prompt"
wtype -k Escape
wait_until "reminder flow closes" 15 layer_absent "hexarchy-reminders"

# Render a real shell notification and clear it through the notification IPC.
hexarchy-shell notifications dismissAll >/dev/null
hexarchy-notification-send "Acceptance notification" "Shell notification rendering" --expire-time=15000
wait_until "notification popup opens" 15 layer_present "hexarchy-notifications"
wait_until "notification content is visible" 15 screen_contains "Acceptance notification"
screenshot "success-notification-popup"
hexarchy-shell notifications dismissAll >/dev/null
wait_until "notification popup closes" 15 layer_absent "hexarchy-notifications"

# The menu's Apps submenu does the full launcher loop: open, search by
# typing, launch the top hit.
if window_present "(?i)hexwrite" >/dev/null 2>&1; then
  fail "app launch test starts with no Hexwrite window" "a Hexwrite window is already open"
fi

hexarchy-menu summon apps >/dev/null
wait_until "apps menu opens" 15 layer_present "hexarchy-menu"
sleep 1
screenshot "success-apps-menu-open"

wtype "hexwrite"
sleep 1
screenshot "success-apps-menu-search"
wtype -k Return

wait_until "apps menu launches the top search hit" 60 window_present "(?i)hexwrite"
wait_until "apps menu closes after launching" 15 layer_absent "hexarchy-menu"

close_windows "(?i)hexwrite"
wait_until "Hexwrite window closes" 30 window_absent "(?i)hexwrite"
