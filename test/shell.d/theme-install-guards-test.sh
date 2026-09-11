#!/bin/bash

set -euo pipefail

# hexarchy-theme-install feeds a pasted URL to git and a name derived from it to
# rm, and hexarchy-theme-remove feeds its argument to rm. Both are exercised here
# with git and the themes directory stubbed, so a guard that stopped working
# shows up as a clone or a removal that should never have been reached.

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
mkdir -p "$mock_bin"

cat >"$mock_bin/git" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$HEXARCHY_TEST_GIT_CALLS"
[[ $1 == "clone" ]] && mkdir -p "${*: -1}"
exit 0
SH

cat >"$mock_bin/gum" <<'SH'
#!/bin/bash
exit 1
SH

for command in hexarchy-theme-set hexarchy-notification-send hexarchy-menu-select; do
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >>"$HEXARCHY_TEST_THEME_CALLS"\nexit 0\n' >"$mock_bin/$command"
done

chmod +x "$mock_bin"/*

git_calls="$test_tmp/git-calls"
theme_calls="$test_tmp/theme-calls"

install_theme() {
  : >"$git_calls"
  : >"$theme_calls"

  HOME="$test_tmp/home" PATH="${2-$mock_bin:$ROOT/bin:$PATH}" \
    HEXARCHY_TEST_GIT_CALLS="$git_calls" HEXARCHY_TEST_THEME_CALLS="$theme_calls" \
    bash "$ROOT/bin/hexarchy-theme-install" "$1" >"$test_tmp/out" 2>&1 || return $?
}

mkdir -p "$test_tmp/home/.config/hexarchy/themes"

# A URL git would read as an option or as a remote helper to run.
for url in "-x" "--upload-pack=touch /tmp/pwned" "ext::sh -c id" "fd::0,1"; do
  if install_theme "$url"; then
    fail "hexarchy-theme-install refuses the URL '$url'"
  fi

  [[ ! -s $git_calls ]] || fail "hexarchy-theme-install refuses '$url' before running git" "$(cat "$git_calls")"
done

pass "a URL that names a git option or a transport helper never reaches git"

# git resolves git-remote-<scheme> for any scheme it does not implement itself,
# so the `://` spelling of a helper has to be refused as well as the `::` one.
for url in "ext://sh -c id" "fd://17" "gcrypt://example.com/x"; do
  if install_theme "$url"; then
    fail "hexarchy-theme-install refuses the URL '$url'"
  fi

  [[ ! -s $git_calls ]] || fail "hexarchy-theme-install refuses '$url' before running git" "$(cat "$git_calls")"
done

pass "a URL naming a transport git does not implement never reaches git"

# The checker is a separate command, so its absence has to refuse the URL rather
# than wave it through to git.
if install_theme "https://github.com/example/hexarchy-cool-theme.git" "$mock_bin:$PATH"; then
  fail "hexarchy-theme-install refuses a URL it cannot check"
fi

[[ ! -s $git_calls ]] ||
  fail "hexarchy-theme-install refuses an unchecked URL before running git" "$(cat "$git_calls")"

pass "a missing url checker refuses the URL instead of cloning it"

# A URL whose derived name would escape the themes directory.
for url in "https://example.com/..git" "https://example.com/.git"; do
  if install_theme "$url"; then
    fail "hexarchy-theme-install refuses the derived name from '$url'"
  fi

  [[ ! -s $git_calls ]] || fail "hexarchy-theme-install refuses '$url' before running git" "$(cat "$git_calls")"
done

pass "a URL whose name would climb out of the themes directory never reaches git"

# basename reads a leading dash as an option once the scp-style prefix is gone.
install_theme "host:-s/foo.git" || fail "hexarchy-theme-install accepts a normal scp-style URL"
grep -Fq -- "-- host:-s/foo.git" "$git_calls" || fail "hexarchy-theme-install passes the URL after --" "$(cat "$git_calls")"
grep -Fq "/themes/foo" "$git_calls" || fail "hexarchy-theme-install derives 'foo', not '.git'" "$(cat "$git_calls")"

pass "a dash inside the path does not become a basename option"

# And the ordinary case still works.
install_theme "https://github.com/example/hexarchy-cool-theme.git" || fail "hexarchy-theme-install clones a normal URL"
grep -Fq "/themes/cool" "$git_calls" || fail "hexarchy-theme-install derives the theme name" "$(cat "$git_calls")"
grep -Fxq "cool" "$theme_calls" || fail "hexarchy-theme-install applies the theme it installed" "$(cat "$theme_calls")"

pass "an ordinary theme URL still clones and applies"

# hexarchy-theme-remove joins its argument into the path it deletes.
remove_theme() {
  : >"$theme_calls"

  HOME="$test_tmp/home" PATH="$mock_bin:$PATH" HEXARCHY_TEST_THEME_CALLS="$theme_calls" \
    bash "$ROOT/bin/hexarchy-theme-remove" "$1" >"$test_tmp/out" 2>&1 || return $?
}

canary="$test_tmp/home/.config/hexarchy/canary"
printf 'still here\n' >"$canary"

for name in ".." "." "../../evil" ".git"; do
  if remove_theme "$name"; then
    fail "hexarchy-theme-remove refuses the theme name '$name'"
  fi

  [[ -f $canary ]] || fail "hexarchy-theme-remove refuses '$name' before removing anything"
done

pass "a theme name cannot climb out of the themes directory on the way to rm"
