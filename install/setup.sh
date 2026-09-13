#!/bin/bash
# Hexarchy installer for Artix Linux (runit).
#
# Turns a fresh or already-configured Artix/runit installation into Hexarchy:
# runit services, systemd-free shims, /etc overlays, user config, and
# (with --fresh) the package set and post-install steps.
#
# Usage:
#   bash install/setup.sh                 # apply the Hexarchy layer to the current system
#   bash install/setup.sh --fresh         # also install packages and run post-install scripts
#   bash install/setup.sh --fresh --user alice --include-other
#
# Flags:
#   --fresh          Install the base package set and run post-install/login/user scripts
#   --other          Also install the optional/hardware packages (hexarchy-other.packages)
#   --user NAME      Which account to lay user config into (default: $SUDO_USER or first real user)
#   --no-services    Skip enabling runit services
#   --no-shims       Skip installing the /usr/local/bin systemd-free shims
#   -h|--help        Show this help

set -euo pipefail

# --- Self-location ----------------------------------------------------------

HEXARCHY_PATH="${HEXARCHY_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HEXARCHY_INSTALL="$HEXARCHY_PATH/install"
HEXARCHY_SV="$HEXARCHY_PATH/sv"
HEXARCHY_CONFIG="$HEXARCHY_PATH/config"
HEXARCHY_ETC="$HEXARCHY_PATH/etc"
HEXARCHY_DEFAULT="$HEXARCHY_PATH/default"
HEXARCHY_SHIMS="$HEXARCHY_PATH/systemd-free/usr-local-bin"
HEXARCHY_VERSION="$(cat "$HEXARCHY_PATH/version" 2>/dev/null || echo unknown)"

# Logging
HEXARCHY_INSTALL_LOG_FILE="${HEXARCHY_INSTALL_LOG_FILE:-/tmp/hexarchy-setup.log}"
HEXARCHY_LOG_TO_STDOUT="${HEXARCHY_LOG_TO_STDOUT:-1}"
# shellcheck source=install/helpers/logging.sh
source "$HEXARCHY_INSTALL/helpers/logging.sh"

BACKUP_SUFFIX=".hexarchy-backup.$(date +%s)"

# --- Options ----------------------------------------------------------------

FRESH=0
INCLUDE_OTHER=0
CONFIGURE_USER=""
DO_SERVICES=1
DO_SHIMS=1

while (( $# )); do
  case "$1" in
    --fresh) FRESH=1 ;;
    --other) INCLUDE_OTHER=1 ;;
    --user) CONFIGURE_USER="${2:-}"; shift ;;
    --no-services) DO_SERVICES=0 ;;
    --no-shims) DO_SHIMS=0 ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed -e 's/^# //' -e 's/^#$//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

fail() { echo "error: $*" >&2; exit 1; }

# --- Preconditions ----------------------------------------------------------

(( EUID == 0 )) || fail "run as root (or via: sudo bash install/setup.sh $*)"

[[ -d /run/runit ]] || fail "not a runit system; Hexarchy requires Artix/runit (no systemd)"
[[ -d "/run/systemd/system" ]] && fail "systemd detected; Hexarchy requires a systemd-free Artix base"
. /etc/os-release
if [[ ${ID_LIKE:-} != *artix* ]]; then
  # Allow re-running on an Omarchy/Arch base only with an explicit override.
  if [[ ${HEXARCHY_ALLOW_NON_ARTIX:-} != "1" ]]; then
    fail "expected Artix Linux (ID_LIKE=artix), got ID=$ID; set HEXARCHY_ALLOW_NON_ARTIX=1 to force"
  fi
fi

[[ -d "$HEXARCHY_SV"    ]] || fail "sv/ not found at $HEXARCHY_SV"
[[ -d "$HEXARCHY_CONFIG" ]] || fail "config/ not found at $HEXARCHY_CONFIG"

# --- Target user ------------------------------------------------------------

if [[ -z "$CONFIGURE_USER" && ${SUDO_USER:-} && "$SUDO_USER" != "root" ]]; then
  CONFIGURE_USER="$SUDO_USER"
fi
if [[ -z "$CONFIGURE_USER" ]]; then
  CONFIGURE_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }')"
fi
CONFIGURE_USER="${CONFIGURE_USER:-}"
if [[ -n "$CONFIGURE_USER" ]]; then
  TARGET_HOME="$(getent passwd "$CONFIGURE_USER" | cut -d: -f6)"
else
  TARGET_HOME=""
fi

# --- Helpers ----------------------------------------------------------------

backup_tree() {
  local target="$1"
  [[ -e "$target" ]] || return 0
  cp -a "$target" "$target$BACKUP_SUFFIX"
  echo "  backed up $target -> $target$BACKUP_SUFFIX"
}

deploy_dir() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || return 0
  backup_tree "$dst"
  mkdir -p "$dst"
  cp -a "$src/." "$dst/"
  echo "  deployed $src -> $dst"
}

enable_service() {
  local name="$1"
  local run="/etc/runit/runsvdir/default"
  local svc="/etc/runit/sv/$name"
  mkdir -p "$run"
  [[ -d "$svc" && ! -e "$run/$name" ]] && ln -s "$svc" "$run/$name" && echo "  enabled service: $name"
}

# --- Stage 0: identity ------------------------------------------------------

start_install_log
echo "== Hexarchy $HEXARCHY_VERSION layer ($BASH_SOURCE) =="

# --- Stage 1: packages ------------------------------------------------------

if (( FRESH )); then
  echo "== Installing base packages =="
  local_pkgs="$(grep -vhE '^\s*(#|$)' "$HEXARCHY_INSTALL/hexarchy-base.packages" | tr '\n' ' ')"
  pacman -S --needed --noconfirm $local_pkgs || fail "base package install failed"
  if (( INCLUDE_OTHER )); then
    echo "== Installing optional/hardware packages =="
    local_other="$(grep -vhE '^\s*(#|$)' "$HEXARCHY_INSTALL/hexarchy-other.packages" | tr '\n' ' ')"
    pacman -S --needed --noconfirm $local_other || fail "optional package install failed"
  fi
fi

# --- Stage 2: runit services ------------------------------------------------

if (( DO_SERVICES )); then
  echo "== Deploying runit services =="
  mkdir -p /etc/runit/sv
  # Hexarchy-provided service definitions (Artix base packages provide the rest).
  for svc in "$HEXARCHY_SV"/*; do
    name="$(basename "$svc")"
    [[ "$name" == "README.md" ]] && continue
    [[ -d "$svc" ]] || continue
    backup_tree "/etc/runit/sv/$name"
    cp -a "$svc" "/etc/runit/sv/$name"
  done

  echo "== Enabling services =="
  enable_service sddm
  enable_service NetworkManager
  if [[ -d /etc/runit/sv/logind ]]; then
    enable_service logind
  else
    enable_service elogind
  fi
  enable_service dbus
  enable_service polkitd
  enable_service cronie
  enable_service earlyoom
  enable_service rsyslog
  echo "  note: agetty/user services come from the Artix runit base packages"
fi

# --- Stage 3: systemd-free shims ---------------------------------------------

if (( DO_SHIMS )); then
  echo "== Installing systemd-free shims =="
  for f in "$HEXARCHY_SHIMS"/*; do
    [[ -f "$f" ]] || continue
    install -Dm755 "$f" "/usr/local/bin/$(basename "$f")"
    echo "  installed /usr/local/bin/$(basename "$f")"
  done
fi

# --- Stage 4: /etc overlays --------------------------------------------------

echo "== Applying /etc overlays =="
deploy_dir "$HEXARCHY_ETC/NetworkManager" /etc/NetworkManager
deploy_dir "$HEXARCHY_ETC/cups"            /etc/cups
deploy_dir "$HEXARCHY_ETC/docker"          /etc/docker
deploy_dir "$HEXARCHY_ETC/elogind"         /etc/elogind
deploy_dir "$HEXARCHY_ETC/fastfetch"       /etc/fastfetch
deploy_dir "$HEXARCHY_ETC/limine-entry-tool.d" /etc/limine-entry-tool.d
deploy_dir "$HEXARCHY_ETC/mkinitcpio.conf.d"   /etc/mkinitcpio.conf.d
deploy_dir "$HEXARCHY_ETC/modprobe.d"      /etc/modprobe.d
deploy_dir "$HEXARCHY_ETC/plymouth"        /etc/plymouth
deploy_dir "$HEXARCHY_ETC/profile.d"       /etc/profile.d
deploy_dir "$HEXARCHY_ETC/sddm.conf.d"     /etc/sddm.conf.d
deploy_dir "$HEXARCHY_ETC/security"        /etc/security
deploy_dir "$HEXARCHY_ETC/sysctl.d"        /etc/sysctl.d
deploy_dir "$HEXARCHY_ETC/systemd"         /etc/systemd
deploy_dir "$HEXARCHY_ETC/tmpfiles.d"      /etc/tmpfiles.d

for f in nsswitch.conf; do
  if [[ -f "$HEXARCHY_ETC/$f" && ! -e "/etc/$f$BACKUP_SUFFIX" ]]; then
    backup_tree "/etc/$f"
    cp -a "$HEXARCHY_ETC/$f" "/etc/$f"
    echo "  deployed /etc/$f"
  fi
done

# os-release (branding) -- always apply with a backup.
if [[ -f "$HEXARCHY_ETC/os-release" ]]; then
  backup_tree /etc/os-release
  cp -a "$HEXARCHY_ETC/os-release" /etc/os-release
  echo "  deployed /etc/os-release (Hexarchy $HEXARCHY_VERSION)"
fi

# sudoers.d: append missing rules, validate before landing.
if [[ -d "$HEXARCHY_ETC/sudoers.d" ]]; then
  echo "== Applying sudoers.d rules =="
  tmp=$(mktemp /etc/sudoers.d/hexarchy-XXXXXX)
  chmod 0640 "${tmp}"
  for f in "$HEXARCHY_ETC/sudoers.d"/*; do
    grep -vhE '^\s*(#|$)' "$f" >> "${tmp}" || true
  done
  visudo -c -f "${tmp}" && mv "${tmp}" /etc/sudoers.d/hexarchy && chmod 0440 /etc/sudoers.d/hexarchy
  echo "  installed /etc/sudoers.d/hexarchy (validated)"
fi

# --- Stage 5: user config ----------------------------------------------------

if [[ -n "$TARGET_HOME" ]]; then
  echo "== Laying user config for $CONFIGURE_USER ($TARGET_HOME) =="
  for dir in "$HEXARCHY_CONFIG"/*; do
    name="$(basename "$dir")"
    [[ -d "$dir" ]] || continue
    backup_tree "$TARGET_HOME/.config/$name"
    mkdir -p "$TARGET_HOME/.config"
    cp -a "$dir" "$TARGET_HOME/.config/$name"
  done
  # Shell dotfiles (only if absent, never clobber user files).
  for pair in "bashrc:.bashrc" "xcompose:.XCompose"; do
    src="${pair%%:*}"; dst="${pair##*:}"
    if [[ -d "$HEXARCHY_DEFAULT/$src" || -f "$HEXARCHY_DEFAULT/$src" ]]; then
      [[ -e "$TARGET_HOME/$dst" ]] || cp -a "$HEXARCHY_DEFAULT/$src" "$TARGET_HOME/$dst" && echo "  added $TARGET_HOME/$dst"
    fi
  done
  chown -R "$CONFIGURE_USER:" "$TARGET_HOME/.config" 2>/dev/null || true
  echo "  user config laid down (originals backed up with .hexarchy-backup.<ts>)"
else
  echo "  no target user found; user config skipped (pass --user NAME)"
fi

# --- Stage 6: post-install / login / user scripts (fresh only) --------------

if (( FRESH )); then
  echo "== Running post-install, login, and user setup =="
  run_logged "$HEXARCHY_INSTALL/post-install/all.sh"
  run_logged "$HEXARCHY_INSTALL/login/sddm.sh"
  if [[ -n "$CONFIGURE_USER" ]]; then
    run_logged "$HEXARCHY_INSTALL/user/all.sh"
  fi
fi

stop_install_log

echo
echo "== Hexarchy setup complete =="
echo "  Repo           : $HEXARCHY_PATH (v$HEXARCHY_VERSION)"
echo "  Services       : /etc/runit/sv + /etc/runit/runsvdir/default"
echo "  Shims          : /usr/local/bin (systemctl, uwsm-app, xdg-terminal-exec, ...)"
if [[ -n "$CONFIGURE_USER" ]]; then
  echo "  User config    : $TARGET_HOME/.config"
fi
echo
echo "  Next steps:"
echo "    - Make sure a user is in the wheel group (usermod -aG wheel <user>)"
echo "    - Ensure sddm is enabled and running:  sv status sddm"
echo "    - If this is a live/ISO boot, add the user with: useradd -mG wheel -s /bin/bash hexbit"
echo "    - Reboot to start the Hyprland session."