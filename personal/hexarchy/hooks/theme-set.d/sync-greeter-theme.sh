#!/bin/bash

# Keeps the SDDM login greeter visually identical to the Hyprland lock
# screen (LockView.qml), by baking the active theme's resolved colors into
# a copy of the greeter template. SDDM QML themes cannot import Hexarchy's
# qs.Commons module, so this replicates Color.qml's/Border.qml's resolution
# rules (theme colors.toml, [lock]-section overrides from shell.toml, and
# the "section.key" indirection used by tokens like "hyprland.active-border")
# in plain shell instead. Runs on every `hexarchy theme set` via the
# theme-set hook.
#
# Template source of truth: ~/.config/hexarchy/hooks/support/sddm-greeter/

set -u

THEME_DIR="$HOME/.local/state/hexarchy/current/theme"
SUPPORT_DIR="$HOME/.config/hexarchy/hooks/support/sddm-greeter"
SDDM_DIR="/usr/share/sddm/themes/hexarchy"

[[ -f "$THEME_DIR/colors.toml" ]] || exit 0
[[ -f "$SUPPORT_DIR/Main.qml.template" ]] || exit 0

is_hex() { [[ $1 =~ ^#[0-9A-Fa-f]{6}$ ]]; }

# Reads one "key = value" pair from a flat file (colors.toml has no
# sections). Tries each key in $2... in order, first match wins.
color_of() {
  local keys=("$@")
  local key
  for key in "${keys[@]}"; do
    local value
    value=$(awk -F= -v key="$key" '
      function clean(raw) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw)
        gsub(/^"|"$/, "", raw)
        return raw
      }
      $1 ~ "^[[:space:]]*"key"[[:space:]]*$" { print clean($2); exit }
    ' "$THEME_DIR/colors.toml")
    if is_hex "$value"; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 1
}

# Reads one "key = value" pair from a specific [section] of shell.toml.
section_value() {
  local section="$1" key="$2"
  awk -F= -v section="$section" -v key="$key" '
    /^\[/ { insection = ($0 == "[" section "]") }
    insection && $1 ~ "^"key"[[:space:]]*$" {
      line=$0
      sub(/^[^=]*=[[:space:]]*/, "", line)
      gsub(/^"|"$/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$THEME_DIR/shell.toml"
}

# A [lock] value can be a plain hex, or an indirection token like
# "hyprland.active-border" pointing at another section.key (Border.qml's
# resolveValueRef). Follow one hop, then take the first color in case that
# target is a multi-stop gradient list ("#aaa #bbb 45deg" - BorderGeometry
# treats bare NNNdeg tokens as an angle, not a color).
resolve_lock_color() {
  local raw
  raw=$(section_value lock "$1")
  if [[ $raw =~ ^([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]+)$ ]]; then
    raw=$(section_value "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")
  fi
  local token
  for token in $raw; do
    if is_hex "$token"; then
      printf '%s' "$token"
      return 0
    fi
  done
  return 1
}

background=$(color_of background color0) || background="#101315"
accent=$(color_of accent color4) || accent="#cacccc"
foreground=$(color_of foreground color7) || foreground="#cacccc"
urgent=$(color_of red color1) || urgent="#a55555"

lock_text=$(resolve_lock_color text) || lock_text=$foreground
lock_placeholder=$(resolve_lock_color placeholder) || lock_placeholder=$foreground
lock_text_error=$(resolve_lock_color text-error) || lock_text_error=$urgent
lock_border_active=$(resolve_lock_color border-active) || lock_border_active=$accent
lock_border_error=$(resolve_lock_color border-error) || lock_border_error=$urgent

corner_radius=$(hyprctl -j getoption decoration:rounding 2>/dev/null | grep -o '"int": *[0-9]*' | grep -o '[0-9]*')
corner_radius=${corner_radius:-0}

font_family=$(fc-match -f '%{family[0]}' monospace 2>/dev/null)
font_family=${font_family:-monospace}

render_dir=$(mktemp -d)
trap 'rm -rf "$render_dir"' EXIT

sed \
  -e "s|__BACKGROUND__|$background|g" \
  -e "s|__ACCENT__|$accent|g" \
  -e "s|__LOCK_TEXT__|$lock_text|g" \
  -e "s|__LOCK_PLACEHOLDER__|$lock_placeholder|g" \
  -e "s|__LOCK_TEXT_ERROR__|$lock_text_error|g" \
  -e "s|__LOCK_BORDER_ACTIVE__|$lock_border_active|g" \
  -e "s|__LOCK_BORDER_ERROR__|$lock_border_error|g" \
  -e "s|__CORNER_RADIUS__|$corner_radius|g" \
  -e "s|__FONT_FAMILY__|$font_family|g" \
  "$SUPPORT_DIR/Main.qml.template" \
  > "$render_dir/Main.qml"

# hexarchy-plymouth-set (and every other privileged Hexarchy command) calls
# `sudo` internally; this system uses `doas` instead (sudo needs an
# interactive password here, doas is configured passwordless for this
# user), so shadow sudo with doas for these copies too.
shim=$(mktemp -d)
cat > "$shim/sudo" <<'WRAP'
#!/bin/bash
exec doas "$@"
WRAP
chmod +x "$shim/sudo"

PATH="$shim:$PATH" sudo mkdir -p "$SDDM_DIR"
PATH="$shim:$PATH" sudo cp "$render_dir/Main.qml" "$SDDM_DIR/Main.qml"
PATH="$shim:$PATH" sudo cp "$SUPPORT_DIR/Wordmark.js" "$SDDM_DIR/Wordmark.js"
rm -rf "$shim"
