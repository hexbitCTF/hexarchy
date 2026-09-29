#!/bin/bash

# Select the matching generated Firefox static theme when the Hexarchy theme
# changes. Writes extensions.activeThemeID so Firefox shows the right theme on
# next launch; themes are otherwise one-click switchable in about:addons.

set -euo pipefail

THEMES_JSON="$HOME/.local/share/hexarchy/firefox-themes/themes.json"
SLUG="${1:-$(cat "$HOME/.local/state/hexarchy/current/theme.name" 2>/dev/null || true)}"

# Firefox keeps profiles under ~/.mozilla/firefox unless something relocated it
# under XDG, so probe both rather than assuming the XDG path.
PROFILE_BASE=""
for candidate in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
  if [[ -f "$candidate/profiles.ini" ]]; then
    PROFILE_BASE="$candidate"
    break
  fi
done

[[ -n $PROFILE_BASE ]] || exit 0
[[ -n $SLUG && -f $THEMES_JSON ]] || exit 0
ID=$(jq -r ".[\"$SLUG\"] // empty" "$THEMES_JSON")
[[ -n $ID ]] || exit 0

while IFS= read -r path; do
  [[ -n $path ]] || continue
  prefs="$PROFILE_BASE/$path/prefs.js"
  [[ -f $prefs ]] || continue

  if grep -q '"extensions.activeThemeID"' "$prefs" 2>/dev/null; then
    sed -i -E "s/^user_pref\(\"extensions\.activeThemeID\", \"[^\"]*\"\);.*$/user_pref(\"extensions.activeThemeID\", \"$ID\");/" "$prefs"
  else
    printf 'user_pref("extensions.activeThemeID", "%s");\n' "$ID" >>"$prefs"
  fi
done < <(awk -F= '/^Path=/{print $2}' "$PROFILE_BASE/profiles.ini" 2>/dev/null || true)

exit 0