#!/bin/bash

source "$(dirname "$0")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
call_log="$test_tmp/calls.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/systemd-run" <<'SH'
#!/bin/bash

printf 'systemd-run %s\n' "$*" >>"$CALL_LOG"
[[ ${FAIL_SYSTEMD_RUN:-false} == "true" ]] && exit 1
exit 0
SH

# loginctl is the real reboot path on this systemd-free system, and it must be
# mocked: the commands below run against the real bin/hexarchy-system-reboot,
# and the mocked `sleep` collapses its 2-second grace period, so an unmocked
# loginctl reboots the machine running the suite. systemd-run is mocked too,
# because that is the scheduling path on a systemd host.
for command in hexarchy-state hexarchy-hyprland-window-close-all sleep loginctl hexarchy-osd; do
  cat >"$mock_bin/$command" <<'SH'
#!/bin/bash

printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
SH
done
chmod +x "$mock_bin"/*

run_power_command() {
  local action="$1"

  : >"$call_log"
  PATH="$mock_bin:$PATH" CALL_LOG="$call_log" "$ROOT/bin/hexarchy-system-$action"
  # The reboot is scheduled in a backgrounded subshell, so its log line can
  # land after the foreground cleanup calls. Wait for the log to settle.
  local waited=0
  while (( waited < 50 )) && ! grep -q '^loginctl ' "$call_log"; do
    sleep 0.1
    (( waited++ ))
  done
}

assert_power_calls() {
  local action="$1"
  local loginctl_action="$2"
  local osd_message="$3"
  local expected_log="$test_tmp/$action-expected.log"
  local actual_log="$test_tmp/$action-actual.log"

  cat >"$expected_log" <<EOF
sleep 2
loginctl $loginctl_action
hexarchy-osd -i $action -m $osd_message -d 5000
hexarchy-state clear re*-required
hexarchy-hyprland-window-close-all 
sleep 1
EOF

  # The reboot is scheduled from a backgrounded subshell, so its lines race the
  # foreground cleanup calls. Compare the set of calls rather than their order;
  # what matters is that the reboot was scheduled and the cleanup still ran.
  sort "$expected_log" >"$expected_log.sorted"
  sort "$call_log" >"$actual_log"

  diff -u "$expected_log.sorted" "$actual_log" || fail "$action runs after being scheduled outside the terminal scope" "$(<"$call_log")"
  pass "$action runs after being scheduled outside the terminal scope"
}

run_power_command reboot
assert_power_calls reboot reboot Rebooting

run_power_command shutdown
assert_power_calls shutdown poweroff "Shutting down"

# The "aborts when scheduling fails" case only exists where the power action is
# scheduled through systemd-run, which is how upstream does it. This fork
# schedules it with a backgrounded `loginctl` instead, where there is no
# synchronous scheduling step that can fail and be handled.
for action in reboot shutdown; do
  if ! grep -q 'systemd-run' "$ROOT/bin/hexarchy-system-$action"; then
    pass "$action has no systemd scheduling step; skipping the scheduling-failure case"
    continue
  fi

  : >"$call_log"
  if PATH="$mock_bin:$PATH" CALL_LOG="$call_log" FAIL_SYSTEMD_RUN=true "$ROOT/bin/hexarchy-system-$action"; then
    fail "$action aborts when scheduling fails"
  fi

  if (( $(wc -l <"$call_log") != 1 )); then
    fail "$action leaves state and windows alone when scheduling fails"
  fi
  pass "$action leaves state and windows alone when scheduling fails"
done
