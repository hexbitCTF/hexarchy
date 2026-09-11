#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

export PATH="$ROOT/bin:$PATH"

require_command jq
require_command lua
require_command python3

jq empty "$ROOT/config/hexarchy/shell.json"
pass "default shell.json is valid JSON"

jq -e '.version == 1 and (.bar.layout.left | type == "array") and (.bar.layout.center | type == "array") and (.bar.layout.right | type == "array")' "$ROOT/config/hexarchy/shell.json" >/dev/null
pass "default shell.json has versioned bar layout"

# Pinning the whole row made this fail every time an unrelated widget moved,
# so assert the adjacency the name is about and let the rest of the row change.
jq -e '
  def ids: map(.id // .);
  (.bar.layout.center | ids) as $ids |
  ($ids | index("hexarchy.weather")) as $weather |
  ($ids | index("hexarchy.system-update")) as $update |
  $weather != null and $update == $weather + 1
' "$ROOT/config/hexarchy/shell.json" >/dev/null
pass "default center layout keeps update next to weather"

jq -e '
  (.bar.centerAnchor // "") as $anchor |
  any(.bar.layout.center[]; (.id // .) == $anchor)
' "$ROOT/config/hexarchy/shell.json" >/dev/null
pass "default center anchor exists in center layout"

jq -e '
  any(.bar.layout.center[]; (.id // .) == "hexarchy.clock" and (.formatAlt // "") == "d MMMM \u0027W\u0027ww yyyy")
' "$ROOT/config/hexarchy/shell.json" >/dev/null
pass "default clock date format has no leading zero"

ROOT="$ROOT" python3 <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
config = json.loads((root / "config/hexarchy/shell.json").read_text())
manifests = {}
for manifest_path in (root / "shell/plugins").glob("**/*.manifest.json"):
  data = json.loads(manifest_path.read_text())
  manifests[data.get("id", "")] = (manifest_path, data)
for manifest_path in (root / "shell/plugins").glob("**/manifest.json"):
  data = json.loads(manifest_path.read_text())
  manifests[data.get("id", "")] = (manifest_path, data)

entries = []
for section in ("left", "center", "right"):
  entries.extend(config["bar"]["layout"][section])

missing = []
bad = []
for entry in entries:
  widget_id = entry["id"] if isinstance(entry, dict) else str(entry)
  if not widget_id.startswith("hexarchy."):
    continue

  row = manifests.get(widget_id)
  if row is None:
    missing.append(widget_id)
    continue
  manifest_path, manifest = row

  if "bar-widget" not in manifest.get("kinds", []):
    bad.append(f"{widget_id}: missing bar-widget kind")
  entry_point = manifest.get("entryPoints", {}).get("barWidget")
  if not entry_point:
    bad.append(f"{widget_id}: missing barWidget entry point")
  elif not (manifest_path.parent / entry_point).exists():
    bad.append(f"{widget_id}: missing {entry_point}")

if missing or bad:
  for item in missing:
    print(f"missing manifest for {item}", file=sys.stderr)
  for item in bad:
    print(item, file=sys.stderr)
  sys.exit(1)
PY
pass "default bar widget ids resolve to manifests and entry points"

ROOT="$ROOT" python3 <<'PY'
import os
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
home = Path.home()
pkgs_candidates = [
  root.parent / "hexarchy-pkgs/pkgbuilds",
  root.parent / "hexarchy/hexarchy-pkgs/pkgbuilds",
  root.parent.parent / "hexarchy-pkgs/pkgbuilds",
  root.parent / "omacom/hexarchy-pkgs/pkgbuilds",
  root.parent.parent / "omacom/hexarchy-pkgs/pkgbuilds",
  home / "Work/omacom/hexarchy-pkgs/pkgbuilds",
]
# Checkouts differ per machine, so allow an explicit pointer at the sibling repo.
# Accepts either the hexarchy-pkgs checkout or its pkgbuilds/ directory.
override = os.environ.get("HEXARCHY_PKGS_PATH")
if override:
  pkgs_candidates = [Path(override) / "pkgbuilds", Path(override)] + pkgs_candidates
pkgs_root = next((path for path in pkgs_candidates if path.exists()), None)
if pkgs_root is None:
  print("not ok - hexarchy-pkgs checkout found for PKGBUILD coverage", file=sys.stderr)
  print(
    "looked in:\n  " + "\n  ".join(str(path) for path in pkgs_candidates) +
    "\nset HEXARCHY_PKGS_PATH to the hexarchy-pkgs checkout",
    file=sys.stderr,
  )
  sys.exit(1)
settings_pkgbuild_path = pkgs_root / "hexarchy-settings/PKGBUILD"
hexarchy_pkgbuild_path = pkgs_root / "hexarchy/PKGBUILD"
if not settings_pkgbuild_path.exists():
  settings_pkgbuild_path = pkgs_root / "hexarchy-settings-dev/PKGBUILD"
if not hexarchy_pkgbuild_path.exists():
  hexarchy_pkgbuild_path = pkgs_root / "hexarchy-dev/PKGBUILD"
pkgbuild = settings_pkgbuild_path.read_text()
hexarchy_pkgbuild = hexarchy_pkgbuild_path.read_text()
errors = []
package_defaults = [
  ("default/uwsm/env.d/10-hexarchy", "/usr/share/uwsm/env.d/10-hexarchy", "uwsm/env"),
  ("default/uwsm/default", None, "uwsm/default"),
  ("default/environment.d/10-hexarchy-fcitx.conf", "/usr/lib/environment.d/10-hexarchy-fcitx.conf", "environment.d/fcitx.conf"),
  ("default/fontconfig/conf.avail/50-hexarchy.conf", "/usr/share/fontconfig/conf.avail/50-hexarchy.conf", "fontconfig/fonts.conf"),
  ("default/xdg-terminal-exec/hyprland-xdg-terminals.list", "/usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list", "xdg-terminals.list"),
  ("default/applications/mimeapps.list", "/usr/share/applications/mimeapps.list", "mimeapps.list"),
  ("etc/fastfetch/config.jsonc", "/etc/fastfetch/config.jsonc", "fastfetch/config.jsonc"),
  ("default/systemd/user/bt-agent.service", "/usr/lib/systemd/user/bt-agent.service", "systemd/user/bt-agent.service"),
  ("default/systemd/user/hexarchy-sleep-lock.service", "/usr/lib/systemd/user/hexarchy-sleep-lock.service", "systemd/user/hexarchy-sleep-lock.service"),
  ("default/systemd/user/hexarchy-recover-internal-monitor.service", "/usr/lib/systemd/user/hexarchy-recover-internal-monitor.service", "systemd/user/hexarchy-recover-internal-monitor.service"),
  ("default/systemd/user/hexarchy-migrate-notify.service", "/usr/lib/systemd/user/hexarchy-migrate-notify.service", "systemd/user/hexarchy-migrate-notify.service"),
  ("default/systemd/user/hexarchy-tailscale-receive.service", "/usr/lib/systemd/user/hexarchy-tailscale-receive.service", "systemd/user/hexarchy-tailscale-receive.service"),
  ("default/systemd/user/hexarchy-fcitx5.service", "/usr/lib/systemd/user/hexarchy-fcitx5.service", "systemd/user/hexarchy-fcitx5.service"),
  ("default/systemd/user/hexarchy-crash-watch.service", "/usr/lib/systemd/user/hexarchy-crash-watch.service", "systemd/user/hexarchy-crash-watch.service"),
  ("default/systemd/zram-generator.conf.d/90-hexarchy.conf", "/usr/lib/systemd/zram-generator.conf.d/90-hexarchy.conf", "systemd/zram-generator.conf.d/90-hexarchy.conf"),
  ("default/fonts/hexarchy/hexarchy.ttf", "/usr/share/fonts/hexarchy/hexarchy.ttf", "hexarchy.ttf"),
  ("default/snapper/root", "/etc/snapper/config-templates/hexarchy", "snapper/root"),
]

for source, destination, legacy in package_defaults:
  if not (root / source).exists():
    errors.append(f"missing package default source: {source}")
  if (root / "config" / legacy).exists():
    errors.append(f"legacy path still in config/: {legacy}")
  if destination and (source not in pkgbuild or destination not in pkgbuild):
    errors.append(f"PKGBUILD does not explicitly install {source} -> {destination}")

# Existing users have an absolute wants symlink to the old unit path, and the
# migration that repoints it only runs for users who run an update -- the
# opposite of who the notifier is for. Dropping this alias strands them.
notify_alias = 'ln -sfn hexarchy-migrate-notify.service "$pkgdir/usr/lib/systemd/user/hexarchy-update-user-notify.service"'
if notify_alias not in pkgbuild:
  errors.append(
    "PKGBUILD does not ship the hexarchy-update-user-notify.service compatibility "
    "alias, so users who have not run migration 1785095882 lose the login notifier"
  )

alpm_hooks = [
  "00-hexarchy-update-guard.hook",
  "10-hexarchy-hyprland-reload-pause.hook",
  "90-hexarchy-hyprland-reload-resume.hook",
]
for hook in alpm_hooks:
  source = f"default/libalpm/hooks/{hook}"
  destination = f"/usr/share/libalpm/hooks/{hook}"
  if not (root / source).exists():
    errors.append(f"missing package default source: {source}")
  if source not in hexarchy_pkgbuild or destination not in hexarchy_pkgbuild:
    errors.append(f"hexarchy PKGBUILD does not install {source} -> {destination}")

if errors:
  print("\n".join(errors), file=sys.stderr)
  sys.exit(1)
PY
pass "package-owned defaults live outside config"

grep -F 'dofile((os.getenv("HEXARCHY_PATH") or "/usr/share/hexarchy") .. "/default/hypr/bootstrap.lua")' "$ROOT/config/hypr/hyprland.lua" >/dev/null
grep -F 'require("default.hypr.hexarchy")' "$ROOT/config/hypr/hyprland.lua" >/dev/null
grep -F 'package.path = home' "$ROOT/default/hypr/bootstrap.lua" >/dev/null
grep -F '/.local/state/?.lua;' "$ROOT/default/hypr/bootstrap.lua" >/dev/null
pass "Hyprland user entrypoint keeps package and state path bootstrap in defaults"

HEXARCHY_PATH="$ROOT" lua <<'LUA'
package.loaded["default.hypr.hexarchy"] = true
package.loaded["default.hypr.require_optional"] = true
package.loaded["hypr.looknfeel"] = true
package.loaded["hexarchy.current.theme.hyprland"] = true
package.loaded["unrelated.module"] = true

dofile(os.getenv("HEXARCHY_PATH") .. "/default/hypr/bootstrap.lua")

assert(package.loaded["default.hypr.hexarchy"] == nil)
assert(package.loaded["default.hypr.require_optional"] == nil)
assert(package.loaded["hypr.looknfeel"] == nil)
assert(package.loaded["hexarchy.current.theme.hyprland"] == nil)
assert(package.loaded["unrelated.module"] == true)
LUA
pass "Hyprland bootstrap reloads cached Hexarchy config modules"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/home/.config/hexarchy"

ipc_mock_bin="$TMPDIR/ipc-mock"
mkdir -p "$ipc_mock_bin"
cat >"$ipc_mock_bin/hexarchy-shell" <<'SH'
#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/.local/state/hexarchy"
printf '%s\n' "$*" >>"$HOME/.local/state/hexarchy/shell-ipc-calls"
printf 'ok\n'
SH
chmod +x "$ipc_mock_bin/hexarchy-shell"
export PATH="$ipc_mock_bin:$PATH"

cat >"$TMPDIR/home/.config/hexarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [{ "id": "hexarchy.menu" }, { "id": "hexarchy.workspaces" }, { "id": "hexarchy.active-window" }],
      "center": [{ "id": "hexarchy.clock" }, { "id": "hexarchy.weather" }, { "id": "hexarchy.system-update" }, { "id": "hexarchy.tailscale" }],
      "right": [{ "id": "hexarchy.tray" }, { "id": "hexarchy.microphone" }, { "id": "hexarchy.bluetooth" }]
    }
  },
  "plugins": []
}
JSON

mkdir -p "$TMPDIR/home/.config/hexarchy/plugins/local.demo-bar"
cat >"$TMPDIR/home/.config/hexarchy/plugins/local.demo-bar/manifest.json" <<'JSON'
{
  "schemaVersion": 1,
  "id": "local.demo-bar",
  "name": "Demo bar",
  "version": "1.0.0",
  "author": "Test",
  "description": "Replacement bar for config tests",
  "kinds": ["bar"],
  "entryPoints": { "bar": "Bar.qml" }
}
JSON
touch "$TMPDIR/home/.config/hexarchy/plugins/local.demo-bar/Bar.qml"

if HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar use local.nonexistent-bar 2>/dev/null; then
  fail "bar use accepted an unknown bar option"
fi
pass "bar use rejects an unknown bar option"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar use local.demo-bar
jq -e '.bar.id == "local.demo-bar"' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell config selects a bar option"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar reset
jq -e '.bar.id == null' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell config resets to built-in bar option"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar move hexarchy.active-window right
grep -Fqx 'shell moveBarWidget hexarchy.active-window {"section":"right"}' \
  "$TMPDIR/home/.local/state/hexarchy/shell-ipc-calls"
pass "bar move accepts a positional target section"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar move hexarchy.active-window left
grep -Fqx 'shell moveBarWidget hexarchy.active-window {"section":"left"}' \
  "$TMPDIR/home/.local/state/hexarchy/shell-ipc-calls"
pass "bar move can restore a widget with positional syntax"

if HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar move hexarchy.active-window left --section right 2>/dev/null; then
  fail "bar move accepted positional and flagged target sections"
fi
pass "bar move rejects conflicting target section syntax"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar position bottom
jq -e '
  .bar.position == "bottom" and
  .plugins == []
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell config sets bar position"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar transparent true
jq -e '
  .bar.transparent == true and
  .bar.position == "bottom" and
  .plugins == []
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell config sets bar transparency"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar transparent toggle
jq -e '.bar.transparent == false' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell config toggles bar transparency"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar set hexarchy.bluetooth enabled false --json
grep -Fqx 'shell setBarWidget hexarchy.bluetooth enabled false {}' \
  "$TMPDIR/home/.local/state/hexarchy/shell-ipc-calls"
pass "bar set accepts false JSON values"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar set hexarchy.bluetooth optional null --json
grep -Fqx 'shell setBarWidget hexarchy.bluetooth optional null {}' \
  "$TMPDIR/home/.local/state/hexarchy/shell-ipc-calls"
pass "bar set accepts null JSON values"

if HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar set hexarchy.bluetooth broken '{' --json 2>/dev/null; then
  fail "bar set accepted malformed JSON"
fi
pass "bar set rejects malformed JSON"

if HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" hexarchy-bar set hexarchy.bluetooth broken 'false null' --json 2>/dev/null; then
  fail "bar set accepted multiple JSON values"
fi
pass "bar set rejects multiple JSON values"

mock_bin="$TMPDIR/mock-bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/hexarchy-refresh-config" <<'SH'
#!/bin/bash
set -euo pipefail

relative_path="${1:-}"
[[ -n $relative_path ]] || exit 1
mkdir -p "$HOME/.config/$(dirname "$relative_path")"
cp "$HEXARCHY_PATH/config/$relative_path" "$HOME/.config/$relative_path"
SH

cat >"$mock_bin/hexarchy-restart-shell" <<'SH'
#!/bin/bash
set -euo pipefail

mkdir -p "$HOME/.local/state/hexarchy"
touch "$HOME/.local/state/hexarchy/restart-shell-called"
SH

cat >"$mock_bin/hexarchy-shell" <<'SH'
#!/bin/bash
[[ ${HEXARCHY_TEST_SHELL_DOWN:-0} == "1" ]] && exit 1
printf 'ok\n'
SH

cat >"$mock_bin/hexarchy-installed-service-dropbox" <<'SH'
#!/bin/bash
set -euo pipefail

[[ ${HEXARCHY_TEST_DROPBOX:-0} == "1" ]]
SH

cat >"$mock_bin/hexarchy-installed-service-tailscale" <<'SH'
#!/bin/bash
set -euo pipefail

[[ ${HEXARCHY_TEST_TAILSCALE:-0} == "1" ]]
SH

chmod +x "$mock_bin"/*
mock_path="$mock_bin:$ROOT/bin:$PATH"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" PATH="$mock_path" HEXARCHY_TEST_DROPBOX=0 HEXARCHY_TEST_TAILSCALE=0 hexarchy-bar defaults
jq -e --slurpfile defaults "$ROOT/config/hexarchy/shell.json" '
  .bar == $defaults[0].bar and
  .plugins == []
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "bar defaults restores the stock bar"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" PATH="$mock_path" HEXARCHY_TEST_DROPBOX=1 HEXARCHY_TEST_TAILSCALE=1 hexarchy-bar defaults
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("hexarchy.tray")) as $tray |
  ($right | index("hexarchy.tailscale") == $tray + 1) and
  ($right | index("hexarchy.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("hexarchy.tailscale") == null)
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "bar defaults places plugins for running optional services"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" PATH="$mock_path" \
  HEXARCHY_TEST_SHELL_DOWN=1 HEXARCHY_TEST_DROPBOX=1 HEXARCHY_TEST_TAILSCALE=1 \
  hexarchy-bar defaults
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("hexarchy.tray")) as $tray |
  ($right | index("hexarchy.tailscale") == $tray + 1) and
  ($right | index("hexarchy.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("hexarchy.tailscale") == null)
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "bar defaults places service widgets without a running shell"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" PATH="$mock_path" HEXARCHY_TEST_DROPBOX=0 HEXARCHY_TEST_TAILSCALE=0 hexarchy-refresh-shell
jq -e '
  def ids: map(.id // .);
  ([.bar.layout.left, .bar.layout.center, .bar.layout.right] | map(ids) | add) as $all |
  ($all | index("hexarchy.dropbox") == null) and
  ($all | index("hexarchy.tailscale") == null)
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "shell refresh keeps optional service widgets absent when services are unavailable"

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" PATH="$mock_path" HEXARCHY_TEST_DROPBOX=1 HEXARCHY_TEST_TAILSCALE=1 hexarchy-refresh-shell
jq -e '
  def ids: map(.id // .);
  (.bar.layout.right | ids) as $right |
  ($right | index("hexarchy.tray")) as $tray |
  ($right | index("hexarchy.tailscale") == $tray + 1) and
  ($right | index("hexarchy.dropbox") == $tray + 2) and
  (.bar.layout.center | ids | index("hexarchy.tailscale") == null)
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
[[ -f $TMPDIR/home/.local/state/hexarchy/restart-shell-called ]] || fail "shell refresh restarts shell"
pass "shell refresh places optional service widgets when services are available"

if grep -RIl 'upgrade-to-quattro\|Hexarchy 4\.0 is upgraded' "$ROOT/migrations" >/dev/null; then
  fail "4.0 upgrade is not modeled as a migration"
fi
pass "4.0 upgrade is handled outside the migration runner"

clock_migration=$(grep -rl 'Remove leading zero from bar clock date' "$ROOT/migrations" | head -n 1 || true)
[[ -n $clock_migration ]] || fail "clock date format user migration exists"

cat >"$TMPDIR/home/.config/hexarchy/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "layout": {
      "left": [],
      "center": [
        { "id": "hexarchy.clock", "formatAlt": "dd MMMM 'W'ww yyyy" },
        { "id": "hexarchy.weather" }
      ],
      "right": [
        { "id": "local.clock", "formatAlt": "dd MMMM 'W'ww yyyy" }
      ]
    }
  },
  "plugins": []
}
JSON

HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" bash "$clock_migration"

jq -e '
  .bar.layout.center[0].formatAlt == "d MMMM \u0027W\u0027ww yyyy" and
  .bar.layout.right[0].formatAlt == "dd MMMM \u0027W\u0027ww yyyy"
' "$TMPDIR/home/.config/hexarchy/shell.json" >/dev/null
pass "clock date format migration removes leading zero from clock"

before=$(sha256sum "$TMPDIR/home/.config/hexarchy/shell.json" | awk '{print $1}')
HOME="$TMPDIR/home" HEXARCHY_PATH="$ROOT" bash "$clock_migration"
after=$(sha256sum "$TMPDIR/home/.config/hexarchy/shell.json" | awk '{print $1}')
[[ $before == "$after" ]] || fail "clock date format migration is idempotent"
pass "clock date format migration is idempotent"
