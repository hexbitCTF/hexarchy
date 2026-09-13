#!/bin/bash
# to-hexarchy.sh - move an existing Artix (runit) install onto Hexarchy.
#
# Replaces the current window manager / desktop environment / display manager
# with Hexarchy's Hyprland + sddm stack WITHOUT touching the user's files.
# Conflicting packages, services and configs are stopped, backed up under
# /root/hexarchy-migration-backup-*, and every decision plus any error is
# written to a report file (/var/log/hexarchy-migration-*/migration.log).
#
# Usage:
#   bash install/to-hexarchy.sh                 # scan, confirm, migrate
#   bash install/to-hexarchy.sh --dry-run       # report conflicts, change nothing
#   bash install/to-hexarchy.sh --remove-conflicts   # also pacman -Rns old WM/DE/DM
#   bash install/to-hexarchy.sh --yes           # skip the confirmation prompt
#   bash install/to-hexarchy.sh --skip-setup    # only handle conflicts, skip setup.sh
#   bash install/to-hexarchy.sh --user alice --include-other
#
# Flags:
#   --dry-run            Detect conflicts and print a report; make no changes
#   --remove-conflicts   Also remove conflicting WM/DE/DM packages (default: stop+backup only)
#   --user NAME          Which account to migrate (default: $SUDO_USER or first UID>=1000 user)
#   --include-other      Pass --other through to install/setup.sh (optional/hardware packages)
#   --skip-setup         Only detect/handle conflicts; do not run install/setup.sh
#   --yes                Skip the confirmation prompt
#   -h|--help            Show this help
#
# Everything you own is preserved: shell dotfiles (.bashrc/.zshrc/.profile/...),
# X resources, editor/tmux/git config, WM/DE config dirs, session scripts and
# autostart entries are moved (never deleted) into the backup directory. A
# manifest there is the source of truth for the rollback script:
#   bash install/rollback-hexarchy.sh

set -u

CHECKED_OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$CHECKED_OUT/install/setup.sh" && -d "$CHECKED_OUT/config" && -d "$CHECKED_OUT/sv" ]]; then
  HEXARCHY_PATH="$CHECKED_OUT"
elif [[ -n "${HEXARCHY_PATH:-}" && -f "$HEXARCHY_PATH/install/setup.sh" ]]; then
  : # use the environment-provided path
else
  HEXARCHY_PATH="$CHECKED_OUT"
fi
HEXARCHY_INSTALL="$HEXARCHY_PATH/install"

DRY_RUN=0
REMOVE_CONFLICTS=0
DO_SETUP=1
INCLUDE_OTHER=0
YES=0
TARGET_USER="${SUDO_USER:-}"

die() { echo "error: $*" >&2; exit 1; }

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1; DO_SETUP=0; YES=1 ;;
    --remove-conflicts) REMOVE_CONFLICTS=1 ;;
    --user) TARGET_USER="${2:-}"; shift ;;
    --include-other) INCLUDE_OTHER=1 ;;
    --skip-setup) DO_SETUP=0 ;;
    --yes) YES=1 ;;
    -h|--help) sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# --- Preconditions ----------------------------------------------------------

if (( ! DRY_RUN )) && (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  elif command -v doas >/dev/null 2>&1; then
    exec doas bash "$0" "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    exec pkexec bash "$0" "$@"
  else
    die "run as root (we need to change /etc/runit and install packages)"
  fi
fi

[[ -d "$HEXARCHY_INSTALL" ]] || die "install/ not found under $HEXARCHY_PATH"
[[ -f "$HEXARCHY_PATH/install/setup.sh" ]] || die "install/setup.sh not found in $HEXARCHY_PATH"
[[ -d "$HEXARCHY_PATH/config" ]] || die "config/ not found in $HEXARCHY_PATH"
[[ -d "$HEXARCHY_PATH/sv" ]] || die "sv/ not found in $HEXARCHY_PATH"

if (( DRY_RUN )); then
  REPORT_FILE=""
  BACKUP_DIR=""
  MANIFEST=""
else
  TS="$(date '+%Y%m%d-%H%M%S')"
  REPORT_DIR="/var/log/hexarchy-migration-$TS"
  BACKUP_DIR="/root/hexarchy-migration-backup-$TS"
  REPORT_FILE="$REPORT_DIR/migration.log"
  MANIFEST="$BACKUP_DIR/manifest.txt"
  mkdir -p "$REPORT_DIR" "$BACKUP_DIR" 2>/dev/null || die "cannot create $REPORT_DIR"
  : > "$MANIFEST"
fi

# --- Target user ------------------------------------------------------------

if [[ -z "$TARGET_USER" && $(id -u) != 0 ]]; then
  TARGET_USER="$(id -un)"
fi
if [[ -z "$TARGET_USER" ]]; then
  TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }')"
fi
TARGET_HOME=""
if [[ -n "$TARGET_USER" ]]; then
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi

# --- Logging ----------------------------------------------------------------

log() {
  local line
  line="[$(date '+%F %T')] $*"
  echo "$line"
  [[ -n "$REPORT_FILE" ]] && echo "$line" >>"$REPORT_FILE"
}

note() { log "note: $*"; }
warn() { log "warning: $*"; }
err() { log "error: $*"; }

# Manifest: one tab-separated record per line, consumed by
# install/rollback-hexarchy.sh. Types:
#   F   moved file/dir:  F <original path> <backup basename>
#   S   disabled service: S <runit service name>
#   G   user groups before migration: G <user> <original comma-groups>
#   P   removed package: P <package>

record_file() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  printf 'F\t%s\t%s\n' "$1" "$2" >> "$MANIFEST"
}

record_service() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  printf 'S\t%s\n' "$1" >> "$MANIFEST"
}

record_groups() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  printf 'G\t%s\t%s\n' "$1" "$2" >> "$MANIFEST"
}

record_pkg() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  printf 'P\t%s\n' "$1" >> "$MANIFEST"
}

record_header() {
  [[ -n "$BACKUP_DIR" ]] || return 0
  printf '# Hexarchy migration manifest %s\n' "$(date '+%F %T')" >> "$MANIFEST"
  printf '# target user: %s (%s)\n' "$1" "$2" >> "$MANIFEST"
}

mv_to_backup() {
  local src="$1" why="$2" dest
  dest="${BACKUP_DIR}/$(echo "${src#/}" | tr '/' '_')"
  if (( DRY_RUN )); then
    log "would back up: $src ($why)"
    return 0
  fi
  [[ -e "$src" ]] || { note "skip $src: does not exist"; return 0; }
  mv "$src" "$dest" && {
    log "backed up: $src -> $dest ($why)"
    record_file "$src" "$(basename "$dest")"
    return 0
  }
  err "failed to back up $src ($why)"
  return 1
}

# --- Conflict metadata ------------------------------------------------------

# For a package, set CONFLICT_CFG (space-separated ~/.config dir names) and
# CONFLICT_SVC (runit service to disable, empty if none).

conflict_meta() {
  local pkg="$1"
  CONFLICT_CFG=""
  CONFLICT_SVC=""
  case "$pkg" in
    lightdm)      CONFLICT_SVC=lightdm; CONFLICT_CFG=lightdm ;;
    gdm)          CONFLICT_SVC=gdm;     CONFLICT_CFG="gdm gnome" ;;
    lxdm)         CONFLICT_SVC=lxdm;    CONFLICT_CFG=lxdm ;;
    slim)         CONFLICT_SVC=slim;    CONFLICT_CFG=slim ;;
    ly)           CONFLICT_SVC=ly;      CONFLICT_CFG=ly ;;
    greetd)       CONFLICT_SVC=greetd;  CONFLICT_CFG=greetd ;;
    gnome-shell)  CONFLICT_CFG="gnome gnome-shell org.gnome.desktop" ;;
    plasma-desktop|plasma-workspace|plasmashell) CONFLICT_CFG="plasma kde org.kde" ;;
    xfce4-session) CONFLICT_CFG="xfce4 xfce4-session xfconf" ;;
    cinnamon)     CONFLICT_CFG=cinnamon ;;
    mate-session) CONFLICT_CFG=mate ;;
    lxsession)    CONFLICT_CFG=lxsession ;;
    lxqt-session|lxqt-panel) CONFLICT_CFG=lxqt ;;
    budgie-desktop) CONFLICT_CFG=budgie ;;
    deepin-session) CONFLICT_CFG=deepin ;;
    dwm)          CONFLICT_CFG=dwm ;;
    i3|i3-wm|i3-gaps) CONFLICT_CFG="i3 i3blocks i3status" ;;
    sway)         CONFLICT_CFG=sway ;;
    openbox)      CONFLICT_CFG="openbox obautostart" ;;
    awesome)      CONFLICT_CFG=awesome ;;
    bspwm)        CONFLICT_CFG="bspwm sxhkd" ;;
    fluxbox)      CONFLICT_CFG=fluxbox ;;
    icewm)        CONFLICT_CFG=icewm ;;
    xmonad)       CONFLICT_CFG=xmonad ;;
    herbstluftwm) CONFLICT_CFG=herbstluftwm ;;
    qtile)        CONFLICT_CFG=qtile ;;
    labwc)        CONFLICT_CFG=labwc ;;
    wayfire)      CONFLICT_CFG=wayfire ;;
    river)        CONFLICT_CFG=river ;;
    spectrwm)     CONFLICT_CFG=spectrwm ;;
    wmii)         CONFLICT_CFG=wmii ;;
    windowmaker|wmaker) CONFLICT_CFG="GNUstep WindowMaker" ;;
    *) return 1 ;;
  esac
  return 0
}

# --- Scan -------------------------------------------------------------------

declare -A SCANNED

scan_package() {
  local pkg="$1"
  conflict_meta "$pkg" || return 0
  SCANNED["$pkg"]=1
  log "detected conflicting package: $pkg"
  [[ -n "$CONFLICT_CFG" ]] && log "  associated config dirs: ~/.config/{${CONFLICT_CFG// /,}}"
  [[ -n "$CONFLICT_SVC" ]] && log "  associated service: $CONFLICT_SVC"
}

scan_running() {
  local procs
  procs="$(pgrep -x 'dwm|i3|sway|openbox|awesome|bspwm|fluxbox|icewm|xmonad|herbstluftwm|qtile|labwc|wayfire|river|spectrwm|wmii|Xorg' 2>/dev/null || true)"
  if [[ -n "$procs" ]]; then
    log "active session: an old WM/X server is running now (pids: ${procs//$'\n'/,})"
    note "Hexarchy takes over at the next login via sddm. Log out or reboot to switch; your current session is not killed."
  fi
}

# --- Apply ------------------------------------------------------------------

disable_runit_service() {
  local name="$1" d target
  if (( DRY_RUN )); then
    log "would disable runit service: $name"
    return 0
  fi
  for d in /etc/runit/sv /etc/sv; do
    [[ -d "$d/$name" ]] || continue
    target="$d/$name"
    break
  done
  if [[ -n "${target:-}" ]] && command -v sv >/dev/null 2>&1; then
    SVDIR="$(dirname "$target")" sv stop "$name" >/dev/null 2>&1 || true
  fi
  local link="/etc/runit/runsvdir/default/$name"
  if [[ -L "$link" ]]; then
    rm -f "$link" && {
      log "disabled runit service: $name ($link removed)"
      record_service "$name"
    }
  elif [[ -n "${target:-}" ]]; then
    note "service $name exists but was not enabled; left alone"
  else
    note "no runit service found for $name"
  fi
}

handle_package_conflict() {
  local pkg="$1" cfg
  conflict_meta "$pkg" || return 0
  for cfg in $CONFLICT_CFG; do
    [[ -n "$cfg" ]] || continue
    if [[ -n "$TARGET_HOME" && -d "$TARGET_HOME/.config/$cfg" ]]; then
      mv_to_backup "$TARGET_HOME/.config/$cfg" "old config for $pkg"
    fi
  done
  [[ -n "$CONFLICT_SVC" ]] && disable_runit_service "$CONFLICT_SVC"
  if (( ! REMOVE_CONFLICTS )); then
    note "$pkg left installed (pass --remove-conflicts to remove it); its service is stopped and its config backed up"
    return 0
  fi
  if (( DRY_RUN )); then
    log "would remove package: $pkg"
    return 0
  fi
  if pacman -Rns --noconfirm "$pkg" >>"$REPORT_FILE" 2>&1; then
    log "removed package: $pkg"
    record_pkg "$pkg"
  else
    err "could not remove package: $pkg (see report); leaving it installed"
  fi
}

handle_file_conflicts() {
  local f bin wilds dots
  [[ -n "$TARGET_HOME" ]] || return 0
  # Session launch scripts.
  for f in .xinitrc .xsession .xprofile; do
    [[ -f "$TARGET_HOME/$f" ]] && mv_to_backup "$TARGET_HOME/$f" "old session launch script"
  done
  # Shell + editor/tmux/git/X dotfiles (Hexarchy fills in defaults if these
  # are absent, so originals are worth keeping even when untouched).
  dots=(.bashrc .bash_profile .bash_login .bash_logout .profile \
        .zshrc .zshenv .zprofile .zlogin .zlogout \
        .inputrc .vimrc .tmux.conf .gitconfig \
        .Xresources .Xdefaults .XCompose .xcompose)
  for f in "${dots[@]}"; do
    [[ -e "$TARGET_HOME/$f" ]] || continue
    if [[ -d "$TARGET_HOME/$f" ]]; then
      mv_to_backup "$TARGET_HOME/$f" "user dotfile dir"
    else
      mv_to_backup "$TARGET_HOME/$f" "user dotfile"
    fi
  done
  wilds=(dwm i3 sway openbox awesome bspwm fluxbox icewm xmonad herbstluftwm qtile labwc wayfire river spectrwm wmii startx xfce4-session gnome-session plasma cinnamon-session mate-session lxsession lxqt)
  if [[ -d "$TARGET_HOME/.config/autostart" ]]; then
    for f in "$TARGET_HOME"/.config/autostart/*.desktop; do
      [[ -e "$f" ]] || continue
      for bin in "${wilds[@]}"; do
        if grep -qi "Exec=.*$bin" "$f"; then
          mv_to_backup "$f" "autostart entry launching $bin"
          break
        fi
      done
    done
  fi
}

handle_user_account() {
  local groups orig_groups
  (( DRY_RUN )) && return 0
  [[ -z "$TARGET_USER" ]] && {
    note "no user account found; add one later with: useradd -mG wheel -s /bin/bash <name>"
    return 0
  }
  orig_groups="$(id -nG "$TARGET_USER" 2>/dev/null | tr ' ' ',' || true)"
  groups="wheel,video,audio,input"
  if usermod -aG "$groups" "$TARGET_USER" >>"$REPORT_FILE" 2>&1; then
    log "added $TARGET_USER to groups: $groups"
    record_groups "$TARGET_USER" "$orig_groups"
  else
    err "could not add $TARGET_USER to groups $groups"
  fi
}

run_setup() {
  local extra=("--fresh")
  [[ -n "$TARGET_USER" ]] && extra+=(--user "$TARGET_USER")
  (( INCLUDE_OTHER )) && extra+=(--other)
  if (( DRY_RUN )); then
    log "would run: install/setup.sh ${extra[*]} (installs packages, services, /etc overlays, user config)"
    return 0
  fi
  note "installing Hexarchy layer (install/setup.sh) ..."
  if HEXARCHY_LOG_TO_STDOUT=0 \
     HEXARCHY_INSTALL_LOG_FILE="$REPORT_FILE" \
     bash -e "$HEXARCHY_INSTALL/setup.sh" "${extra[@]}" >>"$REPORT_FILE" 2>&1; then
    log "install/setup.sh completed"
  else
    err "install/setup.sh failed (exit $?); see $REPORT_FILE for details"
  fi
}

# --- Main -------------------------------------------------------------------

if [[ -d /run/systemd/system ]]; then
  die "systemd detected; Hexarchy requires Artix/runit (systemd-free)"
fi

record_header "$TARGET_USER" "$TARGET_HOME"

CONFLICT_PKGS="lightdm gdm lxdm slim ly greetd gnome-shell plasma-desktop plasma-workspace plasmashell xfce4-session cinnamon mate-session lxsession lxqt-session lxqt-panel budgie-desktop deepin-session dwm i3 i3-wm i3-gaps sway openbox awesome bspwm fluxbox icewm xmonad herbstluftwm qtile labwc wayfire river spectrwm wmii windowmaker wmaker"

FOUND=0
for pkg in $CONFLICT_PKGS; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    scan_package "$pkg"
    (( ++FOUND ))
  fi
done

scan_running

[[ -n "$BACKUP_DIR" ]] && log "backup directory: $BACKUP_DIR; report: $REPORT_FILE"

if (( FOUND )) && (( ! YES )) && (( ! DRY_RUN )); then
  printf '\nResolve the %d conflict(s) above and continue with the Hexarchy install? [y/N] ' "$FOUND"
  read -r answer || true
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]] || { echo "aborted."; exit 1; }
fi

log "resolving conflicts ..."
for pkg in $CONFLICT_PKGS; do
  [[ -n "${SCANNED[$pkg]:-}" ]] && handle_package_conflict "$pkg"
done
handle_file_conflicts
handle_user_account

if (( ! FOUND )); then
  note "no conflicting WM/DE/DM packages detected"
fi

if (( DO_SETUP )); then
  run_setup
fi

if (( ! DRY_RUN )); then
  echo
  echo "== Migration report: $REPORT_FILE =="
  echo "== Backed-up conflicts: $BACKUP_DIR (your files are safe) =="
  echo
  echo "  Next steps:"
  echo "    1. Reboot (sddm comes up as the display manager)"
  echo "    2. Log in and pick the Hexarchy (Hyprland) session"
  echo "    3. Anything the old WM/DE needed is preserved in the backup dir"
fi
exit 0