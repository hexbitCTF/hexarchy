#!/bin/bash

# Apply hexbit's personal Hexarchy overlay on top of an already installed
# Hexarchy system (base packages, quickshell, Hyprland).
#
# This does NOT install Hexarchy itself -- see install/setup.sh for that.
# Run this after the base system is up, to bring over everything that is not
# part of the shipped defaults: Hyprland overrides, the shell config and the
# first-party plugins behind it, theme-set hooks, terminal/file-manager/prompt
# configs, a handful of extra commands, and the separately-versioned Neovim
# config.
#
# Usage: bash personal/apply.sh

set -euo pipefail

PERSONAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%s)"

# Copy src over dest, backing up an existing dest that differs.
install_file() {
  local src="$1" dest="$2"

  mkdir -p "$(dirname "$dest")"

  if [[ -f $dest ]] && ! cmp -s "$src" "$dest"; then
    cp -f "$dest" "$dest$BACKUP_SUFFIX"
    echo "  backed up $dest -> $dest$BACKUP_SUFFIX"
  fi

  cp -f "$src" "$dest"
  echo "  applied $dest"
}

# Copy a file and mark it executable.
install_exec() {
  install_file "$1" "$2"
  chmod 755 "$2"
}

echo "Applying personal Hyprland overrides..."
for f in bindings.lua input.lua autostart.lua hyprland.lua looknfeel.lua \
         hyprsunset.conf xdph.conf firefox-opacity.lua; do
  install_file "$PERSONAL_DIR/hypr/$f" "$HOME/.config/hypr/$f"
done
install_exec "$PERSONAL_DIR/hypr/start-dbus-session.sh" "$HOME/.config/hypr/start-dbus-session.sh"
install_exec "$PERSONAL_DIR/hypr/setup-session-bus.sh" "$HOME/.config/hypr/setup-session-bus.sh"

if hexarchy-cmd-present hyprctl && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  hyprctl reload
  echo "  reloaded Hyprland config"
fi

echo "Applying personal shell config..."
install_file "$PERSONAL_DIR/hexarchy/shell.json" "$HOME/.config/hexarchy/shell.json"
install_file "$PERSONAL_DIR/hexarchy/extensions/hexarchy-menu.jsonc" "$HOME/.config/hexarchy/extensions/hexarchy-menu.jsonc"
install_file "$PERSONAL_DIR/hexarchy/branding/about.txt" "$HOME/.config/hexarchy/branding/about.txt"
install_file "$PERSONAL_DIR/hexarchy/branding/about.plain.txt" "$HOME/.config/hexarchy/branding/about.plain.txt"

echo "Installing first-party shell plugins..."
for plugin in "$PERSONAL_DIR"/hexarchy/plugins/*/; do
  name="$(basename "$plugin")"
  mkdir -p "$HOME/.config/hexarchy/plugins/$name"
  cp -rf "$plugin." "$HOME/.config/hexarchy/plugins/$name/"
  echo "  installed $name"
done

echo "Installing third-party shell plugins..."
hexarchy plugin add https://github.com/crmne/omarchy-hyprmoncfg.git
hexarchy plugin add https://github.com/JJDizz1L/dizziee.power-profiles.git
hexarchy plugin add https://github.com/JJDizz1L/dizziee.system-updates.git

echo "Installing personal hooks..."
for hook in "$PERSONAL_DIR"/hexarchy/hooks/*; do
  name="$(basename "$hook")"

  if [[ -d $hook ]]; then
    mkdir -p "$HOME/.config/hexarchy/hooks/$name"
    cp -rf "$hook." "$HOME/.config/hexarchy/hooks/$name/"
  else
    install_file "$hook" "$HOME/.config/hexarchy/hooks/$name"
  fi

  echo "  installed $name"
done
chmod 755 "$HOME"/config/hexarchy/hooks/*.sh "$HOME"/config/hexarchy/hooks/theme-set.d/* 2>/dev/null || true

if hexarchy-cmd-present hexarchy-theme-refresh; then
  hexarchy-theme-refresh
  echo "  re-rendered theme-synced files for the current theme"
else
  echo "  skip: run 'hexarchy theme refresh' once to re-render theme-synced files"
fi

echo "Applying personal app configs..."
install_file "$PERSONAL_DIR/bash/bashrc" "$HOME/.bashrc"
install_file "$PERSONAL_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
install_file "$PERSONAL_DIR/superfile/config.toml" "$HOME/.config/superfile/config.toml"
install_file "$PERSONAL_DIR/superfile/hotkeys.toml" "$HOME/.config/superfile/hotkeys.toml"
install_file "$PERSONAL_DIR/feh/keys" "$HOME/.config/feh/keys"
install_file "$PERSONAL_DIR/zathura/zathurarc" "$HOME/.config/zathura/zathurarc"
install_file "$PERSONAL_DIR/starship.toml" "$HOME/.config/starship.toml"
install_file "$PERSONAL_DIR/pipewire/mic-noise-gate.conf" "$HOME/.config/pipewire/mic-noise-gate.conf"

echo "Installing personal commands..."
for cmd in "$PERSONAL_DIR"/bin/*; do
  install_exec "$cmd" "$HOME/.local/bin/$(basename "$cmd")"
done

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

Done. Two things are still left out on purpose, because they are specific to
the source machine's hardware rather than to this setup:
  - monitors.lua / hyprmoncfg-monitors.lua (monitor layout; hyprmoncfgd owns
    the layout on this machine, so these are not needed)

Restart Firefox to pick up the live-theme extension, and restart the shell
(hexarchy restart shell) to load the new plugins and shell.json.
EOF
