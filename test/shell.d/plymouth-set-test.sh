#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

source_dir="$test_tmp/source"
theme_dir="$test_tmp/theme"

mkdir -m 0700 "$source_dir"
mkdir -m 0755 "$theme_dir"
touch "$source_dir/logo.png"

cp -a --no-preserve=mode,ownership "$source_dir/." "$theme_dir/"

[[ $(stat -c %a "$theme_dir") == "755" ]] ||
  fail "Plymouth asset copy preserves the theme directory permissions"

grep -Fq \
  'cp -a --no-preserve=mode,ownership "$staging_dir/." "$theme_dir/"' \
  "$ROOT/bin/hexarchy-plymouth-set" ||
  fail "hexarchy-plymouth-set avoids copying staging directory ownership and mode"

pass "Plymouth asset copy preserves the package-owned directory metadata"

# hexarchy-plymouth-set-by-theme hands over a theme's unlock.png from
# ~/.config/hexarchy/themes, and both copies below land in world-readable
# /usr/share, so a symlink there would republish whatever it points at.
secret="$test_tmp/secret"
printf 'not yours\n' >"$secret"
ln -s "$secret" "$test_tmp/logo-link.png"

output=$(HEXARCHY_PATH="$ROOT" bash "$ROOT/bin/hexarchy-plymouth-set" '#1d2021' '#ebdbb2' "$test_tmp/logo-link.png" 2>&1)
status=$?

(( status != 0 )) || fail "hexarchy-plymouth-set refuses a symlinked logo"
[[ $output == *"symlink"* ]] || fail "hexarchy-plymouth-set says why it refused the logo" "$output"

grep -Fq 'sudo cp "$staging_dir/logo.png" "$sddm_dir/logo.png"' "$ROOT/bin/hexarchy-plymouth-set" ||
  fail "hexarchy-plymouth-set copies the staged logo to SDDM rather than rereading the caller's path as root"

pass "a themed logo cannot republish a file it merely points at"
