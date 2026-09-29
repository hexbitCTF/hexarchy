#!/bin/bash
# Color the Hexarchy fastfetch logo in the theme accent color.
#
# The logo uses the terminal's PALETTE blue slot (ANSI 34) instead of a
# hardcoded RGB value. Every Hexarchy theme maps its accent to the "blue"
# palette slot, so when the theme changes, hexarchy rewrites the terminal
# palette and the logo recolors LIVE with the rest of the stats -- no
# regeneration required.
#
# Run manually (no args) or automatically on theme changes via:
#   hexarchy hook install theme-set "$0"
set -euo pipefail

PLAIN="$HOME/.config/hexarchy/branding/about.plain.txt"
OUT="$HOME/.config/hexarchy/branding/about.txt"

[ -f "$PLAIN" ] || exit 0

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

while IFS= read -r line || [[ -n "$line" ]]; do
  printf '\033[34m%s\033[0m\n' "$line" >> "$TMP"
done < "$PLAIN"

cp "$TMP" "$OUT"