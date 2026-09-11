hexarchy_log_to_stdout() {
  [[ ${HEXARCHY_LOG_TO_STDOUT:-} == "1" || -z ${HEXARCHY_INSTALL_LOG_FILE:-} ]]
}

hexarchy_log_line() {
  if hexarchy_log_to_stdout; then
    echo "$1"
  else
    echo "$1" >>"$HEXARCHY_INSTALL_LOG_FILE"
  fi
}

start_install_log() {
  if ! hexarchy_log_to_stdout; then
    mkdir -p "$(dirname "$HEXARCHY_INSTALL_LOG_FILE")"
    touch "$HEXARCHY_INSTALL_LOG_FILE"
    chmod 666 "$HEXARCHY_INSTALL_LOG_FILE" 2>/dev/null || true
  fi

  export HEXARCHY_START_TIME="${HEXARCHY_START_TIME:-$(date '+%Y-%m-%d %H:%M:%S')}"
  export HEXARCHY_START_EPOCH="${HEXARCHY_START_EPOCH:-$(date +%s)}"

  hexarchy_log_line "=== Hexarchy Setup Started: $HEXARCHY_START_TIME ==="
}

stop_install_log() {
  local end_time end_epoch duration mins secs
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  end_epoch=$(date +%s)

  hexarchy_log_line "=== Hexarchy Setup Completed: $end_time ==="

  if [[ -n ${HEXARCHY_START_EPOCH:-} ]]; then
    duration=$((end_epoch - HEXARCHY_START_EPOCH))
    mins=$((duration / 60))
    secs=$((duration % 60))
    hexarchy_log_line "Hexarchy setup: ${mins}m ${secs}s"
  fi
}

run_logged() {
  local script="$1"
  local exit_code errexit_was_set=0

  hexarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: $script"

  case $- in
    *e*)
      errexit_was_set=1
      set +e
      ;;
  esac

  local runner=(bash -eE)
  if [[ ${HEXARCHY_INSTALL_DEBUG:-} == "1" ]]; then
    runner=(bash -x -eE)
  fi

  if hexarchy_log_to_stdout; then
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null 2>&1
  else
    PS4='+ ${BASH_SOURCE[0]##*/}:${LINENO}:${FUNCNAME[0]:-main}: ' \
      "${runner[@]}" -c 'source "$1"' bash "$script" </dev/null >>"$HEXARCHY_INSTALL_LOG_FILE" 2>&1
  fi

  exit_code=$?
  (( errexit_was_set )) && set -e

  if (( exit_code == 0 )); then
    hexarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed: $script"
  else
    hexarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed: $script (exit code: $exit_code)"
  fi

  return $exit_code
}
