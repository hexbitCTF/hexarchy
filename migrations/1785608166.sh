echo "Repair the pre-suspend lock monitor's graphical session environment"

# The old unit started before UWSM finished importing HEXARCHY_PATH and
# WAYLAND_DISPLAY. A full unit retained from before Hexarchy 4 also shadows the
# corrected package unit, so add the lifecycle constraints as a drop-in without
# discarding any user customizations.
user_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
sleep_lock_unit="$user_config_home/systemd/user/hexarchy-sleep-lock.service"
sleep_lock_dropin_dir="$user_config_home/systemd/user/hexarchy-sleep-lock.service.d"
sleep_lock_dropin="$sleep_lock_dropin_dir/90-hexarchy-session-environment.conf"

if [[ -f $sleep_lock_unit ]]; then
  mkdir -p "$sleep_lock_dropin_dir"
  printf '%s\n' \
    '[Unit]' \
    'After=dbus.socket wayland-session-waitenv.service' \
    'Requires=dbus.socket' \
    'PartOf=graphical-session.target' \
    'ConditionEnvironment=HEXARCHY_PATH' \
    'ConditionEnvironment=WAYLAND_DISPLAY' >"$sleep_lock_dropin"
fi

# With no live user manager there cannot be an inherited monitor to replace.
# The package unit (and compatibility drop-in, when needed) will be loaded by
# the fresh manager at the next login.
user_manager_socket="${XDG_RUNTIME_DIR:-/run/user/$UID}/systemd/private"
if ! error=$(systemctl --user show-environment 2>&1); then
  if [[ -S $user_manager_socket ]]; then
    echo "Could not reach the running user service manager: $error"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  fi
  exit 0
fi

if ! error=$(systemctl --user daemon-reload 2>&1); then
  echo "Could not reload the user service manager: $error"
  echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
  exit 1
fi

if ! graphical_state=$(systemctl --user show --property=ActiveState --value graphical-session.target 2>&1); then
  echo "Could not inspect graphical-session.target: $graphical_state"
  echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
  exit 1
fi

if [[ $graphical_state == "active" ]]; then
  if ! error=$(systemctl --user reset-failed hexarchy-sleep-lock.service 2>&1); then
    echo "Could not reset hexarchy-sleep-lock.service: $error"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  elif ! error=$(systemctl --user restart hexarchy-sleep-lock.service 2>&1); then
    echo "Could not restart hexarchy-sleep-lock.service: $error"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  elif ! sleep_lock_state=$(systemctl --user show --property=ActiveState --value hexarchy-sleep-lock.service 2>&1); then
    echo "Could not inspect hexarchy-sleep-lock.service: $sleep_lock_state"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  elif [[ $sleep_lock_state != "active" ]]; then
    echo "hexarchy-sleep-lock.service did not stay active after restart."
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  fi
else
  # A pre-fix monitor was not tied to graphical-session.target and can outlive
  # logout under a lingering user manager. Stop it so the next target start
  # creates a process with the next graphical session's environment.
  if ! error=$(systemctl --user stop hexarchy-sleep-lock.service 2>&1); then
    echo "Could not stop stale hexarchy-sleep-lock.service: $error"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  elif ! error=$(systemctl --user reset-failed hexarchy-sleep-lock.service 2>&1); then
    echo "Could not reset hexarchy-sleep-lock.service: $error"
    echo "The pre-suspend lock repair will be retried by hexarchy-migrate."
    exit 1
  fi
fi
