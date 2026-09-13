#!/bin/bash
# rollback-hexarchy.sh - put a pre-migration system back the way it was.
#
# Reverses install/to-hexarchy.sh using the manifest that migration wrote:
# restores every backed-up file (shell dotfiles, X resources, editor/tmux/git
# config, WM/DE config dirs, session scripts, autostart entries), re-enables
# the display manager / services that were turned off, and restores the
# user's original supplementary groups. Hexarchy packages are left in place
# unless you pass --remove-hexarchy.
#
# Usage:
#   bash install/rollback-hexarchy.sh                     # latest backup set
#   bash install/rollback-hexarchy.sh --backup-dir /root/hexarchy-migration-backup-20260913-131600
#   bash install/rollback-hexarchy.sh --remove-hexarchy   # also uninstall the Hyprland/sddm stack
#   bash install/rollback-hexarchy.sh --dry-run           # show what it would do
#   bash install/rollback-hexarchy.sh --yes               # skip confirmation
#
# Flags:
#   --backup-dir DIR    Backup set to restore (default: most recent under /root)
#   --user NAME         Override the target user recorded in the manifest
#   --remove-hexarchy   Also pacman -Rns the Hexarchy desktop stack
#   --dry-run           Only report what would be restored, change nothing
#   --yes               Skip the confirmation prompt
#   -h|--help           Show this help

set -u

DRY_RUN=0
REMOVE_HEXARCHY=0
YES=0
BACKUP_DIR=""
TARGET_USER_OVERRIDE=""

die() { echo "error: $*" >&2; exit 1; }

while (( $# )); do
  case "$1" in
    --backup-dir) BACKUP_DIR="${2:-}"; shift ;;
    --user) TARGET_USER_OVERRIDE="${2:-}"; shift ;;
    --remove-hexarchy) REMOVE_HEXARCHY=1 ;;
    --dry-run) DRY_RUN=1; YES=1 ;;
    --yes) YES=1 ;;
    -h|--help) sed -n '2,/^set -u/p' "${BASH_SOURCE[0]}" | sed '$d' | sed -e 's/^# //' -e 's/^#$//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

if (( ! DRY_RUN )) && (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo -E bash "$0" "$@"
  elif command -v doas >/dev/null 2>&1; then
    exec doas bash "$0" "$@"
  elif command -v pkexec >/dev/null 2>&1; then
    exec pkexec bash "$0" "$@"
  else
    die "run as root to restore files and services (or use --dry-run)"
  fi
fi

# --- Locate the backup set --------------------------------------------------

if [[ -z "$BACKUP_DIR" ]]; then
  BACKUP_DIR="$(ls -1dt /root/hexarchy-migration-backup-*/ 2>/dev/null | head -n1 | sed 's#/$##' || true)"
fi
[[ -n "$BACKUP_DIR" ]] || die "no backup dir found under /root (pass --backup-dir)"
[[ -d "$BACKUP_DIR" ]] || die "backup dir not found: $BACKUP_DIR"
MANIFEST="$BACKUP_DIR/manifest.txt"
[[ -f "$MANIFEST" ]] || die "no manifest in $BACKUP_DIR (nothing to roll back)"

LOG_FILE="$BACKUP_DIR/rollback.log"
if ! : > "$LOG_FILE" 2>/dev/null; then
  LOG_FILE="/tmp/hexarchy-rollback-$(date '+%H%M%S').log"
  : > "$LOG_FILE" 2>/dev/null || LOG_FILE=""
fi

log() {
  local line
  line="[$(date '+%F %T')] $*"
  echo "$line"
  [[ -n "$LOG_FILE" ]] && echo "$line" >>"$LOG_FILE"
}
err() { log "error: $*"; }

home_owner_for() {
  local orig="$1"
  local owner
  owner="$(getent passwd | awk -F: -v o="$orig" 'index(o, $6"/") == 1 && length($6) > best { best = length($6); bestowner = $1 } END { print bestowner }')"
  echo "$owner"
}

restore_file() {
  local orig="$1" bname="$2" bpath owner
  bpath="$BACKUP_DIR/$bname"
  [[ -e "$bpath" ]] || { err "backup entry missing: $bpath (skipped)"; return 1; }
  if [[ -e "$orig" ]]; then
    local clash
    clash="$BACKUP_DIR/pre-rollback-$(date '+%H%M%S')-$(basename "$bname")"
    log "relocating current $orig -> $clash (will be restored over it)"
    (( DRY_RUN )) || mv "$orig" "$clash" || { err "could not relocate $orig"; return 1; }
  fi
  log "restoring $orig <- $bpath"
  if (( DRY_RUN )); then return 0; fi
  mkdir -p "$(dirname "$orig")" || true
  if mv "$bpath" "$orig"; then
    owner="$(home_owner_for "$orig")"
    [[ -n "$owner" ]] && chown "$owner:" "$orig" 2>/dev/null || true
  else
    err "restore failed for $orig"
    return 1
  fi
}

restore_service() {
  local svc="$1" svc_dir link
  link="/etc/runit/runsvdir/default/$svc"
  log "re-enabling runit service: $svc"
  if (( DRY_RUN )); then return 0; fi
  svc_dir=""
  for d in /etc/runit/sv /etc/sv; do
    [[ -d "$d/$svc" ]] && { svc_dir="$d"; break; }
  done
  if [[ -n "$svc_dir" ]]; then
    mkdir -p "$(dirname "$link")"
    ln -sfn "$svc_dir/$svc" "$link"
    command -v sv >/dev/null 2>&1 && SVDIR="$svc_dir" sv start "$svc" >/dev/null 2>&1 || true
  else
    err "no runit service definition found for $svc; not re-enabled"
  fi
}

restore_groups() {
  local user="$1" groups="$2"
  [[ -n "$TARGET_USER_OVERRIDE" ]] && user="$TARGET_USER_OVERRIDE"
  log "restoring groups for $user: $groups"
  if (( DRY_RUN )); then return 0; fi
  if [[ -n "$LOG_FILE" ]]; then
    usermod -G "$groups" "$user" >>"$LOG_FILE" 2>&1 || err "could not restore groups for $user"
  else
    usermod -G "$groups" "$user" 2>/dev/null || err "could not restore groups for $user"
  fi
}

restore_pkg() {
  local pkg="$1"
  log "note: package $pkg was removed during migration; reinstall with: pacman -S $pkg"
}

remove_hexarchy() {
  local pkgs installed=() p
  pkgs=(hyprland quickshell sddm sddm-runit uwsm xdg-desktop-portal-hyprland \
        hyprland-guiutils hyprland-preview-share-picker fcitx5 fcitx5-gtk fcitx5-qt)
  for p in "${pkgs[@]}"; do
    pacman -Q "$p" >/dev/null 2>&1 && installed+=("$p")
  done
  if (( ${#installed[@]} == 0 )); then
    log "no Hexarchy desktop packages to remove"
    return 0
  fi
  log "removing Hexarchy desktop packages: ${installed[*]}"
  if (( DRY_RUN )); then return 0; fi
  local ok
  if [[ -n "$LOG_FILE" ]]; then
    pacman -Rns --noconfirm "${installed[@]}" >>"$LOG_FILE" 2>&1 || ok=1
  else
    pacman -Rns --noconfirm "${installed[@]}" >/dev/null 2>&1 || ok=1
  fi
  if [[ -n "${ok:-}" ]]; then
    err "pacman -Rns failed; see $LOG_FILE"
  fi
}

# --- Main -------------------------------------------------------------------

log "== Hexarchy rollback =="
log "backup set: $BACKUP_DIR"
log "manifest  : $MANIFEST"

# Phase 1: scan manifest to summarize.
FCNT=0; SCNT=0; GCNT=0; PCNT=0
while IFS=$'\t' read -r type a b; do
  case "$type" in
    F) (( ++FCNT )) ;;
    S) (( ++SCNT )) ;;
    G) (( ++GCNT )) ;;
    P) (( ++PCNT )) ;;
  esac
done < "$MANIFEST"

printf 'Summary: %d file/dir to restore, %d service(s) to re-enable, %d group-record(s), %d removed package-notes\n' \
  "$FCNT" "$SCNT" "$GCNT" "$PCNT"

if (( ! YES )); then
  printf 'Restore this backup now? [y/N] '
  read -r answer || true
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]] || { echo "aborted."; exit 1; }
fi

# Phase 2: apply (groups first, then services, then files).
while IFS=$'\t' read -r type a b; do
  case "$type" in
    G) restore_groups "$a" "$b" ;;
    S) restore_service "$a" ;;
    P) restore_pkg "$a" ;;
    F) restore_file "$a" "$b" ;;
    *) : ;;
  esac
done < "$MANIFEST"

if (( REMOVE_HEXARCHY )); then
  remove_hexarchy
else
  log "note: Hexarchy packages are still installed (pass --remove-hexarchy to uninstall them)"
fi

log "note: Hexarchy config dirs under the user's ~/.config (hypr, quickshell, ...) are left in place; remove them if you want a fully clean pre-Hexarchy home"

if (( ! DRY_RUN )); then
  echo
  echo "== Rollback complete =="
  echo "  Backup set still holds everything until you delete it: $BACKUP_DIR"
  echo "  Log: $LOG_FILE"
  echo "  Reboot to land back on the old display manager / login."
fi
exit 0