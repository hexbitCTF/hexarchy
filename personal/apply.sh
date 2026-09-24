#!/bin/bash

# Apply karammasry000's personal Hexarchy overlay on top of an already
# installed Hexarchy system (base packages, quickshell, Hyprland).
#
# This does NOT install Hexarchy itself -- see install/setup.sh for that.
# Run this after the base system is up, to bring over the personal touches
# that aren't part of the shipped defaults: keybind/input overrides, the
# Firefox live-theme sync, and the separately-versioned Neovim config.
#
# Usage: bash personal/apply.sh

set -euo pipefail

PERSONAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%s)"

echo "Applying personal Hyprland overrides..."
mkdir -p ~/.config/hypr
for f in bindings.lua input.lua; do
  src="$PERSONAL_DIR/hypr/$f"
  dest="$HOME/.config/hypr/$f"

  if [[ -f $dest ]] && ! cmp -s "$src" "$dest"; then
    cp -f "$dest" "$dest$BACKUP_SUFFIX"
    echo "  backed up existing $dest -> $dest$BACKUP_SUFFIX"
  fi

  cp -f "$src" "$dest"
  echo "  applied $dest"
done

if hexarchy-cmd-present hyprctl && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload
  echo "  reloaded Hyprland config"
fi

echo "Installing SDDM greeter theme-sync hook..."
mkdir -p ~/.config/hexarchy/hooks/theme-set.d ~/.config/hexarchy/hooks/support/sddm-greeter
cp -f "$PERSONAL_DIR/hexarchy-hooks/theme-set.d/sync-greeter-theme.sh" ~/.config/hexarchy/hooks/theme-set.d/
chmod 755 ~/.config/hexarchy/hooks/theme-set.d/sync-greeter-theme.sh
cp -f "$PERSONAL_DIR/hexarchy-hooks/support/sddm-greeter/Main.qml.template" ~/.config/hexarchy/hooks/support/sddm-greeter/
cp -f "$PERSONAL_DIR/hexarchy-hooks/support/sddm-greeter/Wordmark.js" ~/.config/hexarchy/hooks/support/sddm-greeter/
echo "  installed ~/.config/hexarchy/hooks/theme-set.d/sync-greeter-theme.sh"
if hexarchy-cmd-present hexarchy-theme-refresh; then
  hexarchy-theme-refresh
  echo "  rendered SDDM greeter for the current theme"
else
  echo "  skip: run 'hexarchy theme refresh' once to render the greeter"
fi

echo "Setting up Firefox live theme sync..."
if hexarchy-cmd-present hexarchy-firefox-themes && hexarchy-cmd-present hexarchy-install-firefox-theme; then
  hexarchy-firefox-themes
  hexarchy-install-firefox-theme
else
  echo "  skip: hexarchy-firefox-themes / hexarchy-install-firefox-theme not found (update Hexarchy first)"
fi

echo "Cloning Neovim config..."
if [[ -d ~/.config/nvim/.git ]]; then
  echo "  skip: ~/.config/nvim is already a git checkout"
else
  if [[ -e ~/.config/nvim ]]; then
    mv ~/.config/nvim ~/.config/nvim$BACKUP_SUFFIX
    echo "  backed up existing ~/.config/nvim -> ~/.config/nvim$BACKUP_SUFFIX"
  fi
  git clone https://github.com/hexbitCTF/nvim ~/.config/nvim
fi

cat <<'EOF'

Done. Not carried over on purpose (hardware-specific to the source
machine -- copy manually only if this machine matches):
  - monitors.lua / hyprmoncfg-monitors.lua (monitor layout)
  - autostart.lua (D-Bus session workaround, audio codec fixes)
  - firefox-opacity.lua (cosmetic, safe to add if you want it)

Restart Firefox to pick up the live-theme extension.
EOF
