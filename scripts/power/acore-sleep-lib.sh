#!/usr/bin/env bash
set -Eeuo pipefail

SLEEP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SLEEP_LIB_DIR/../lib/common.sh"

require_sleep_enabled() {
  sleep_enabled || die "sleep mode is disabled; set SLEEP_ENABLED=\"true\" to use this command"
}

require_sleep_command() {
  local name="$1"

  command -v "$name" >/dev/null 2>&1 || die "required command is missing: $name"
}

ensure_sleep_state_dir() {
  mkdir -p "$SLEEP_STATE_DIR"
}

sleep_log() {
  local message="$1"

  logger -t acore-sleep "$message" 2>/dev/null || true
  echo "$(date '+%Y-%m-%d %H:%M:%S') $message"
}

sleep_log_skip_once() {
  local key="$1"
  local message="$2"
  local last_reason_file="$SLEEP_STATE_DIR/last-sleep-skip-reason"
  local last_key=""

  if ! mkdir -p "$SLEEP_STATE_DIR" 2>/dev/null; then
    sleep_log "$message"
    return
  fi

  last_key="$(cat "$last_reason_file" 2>/dev/null || true)"
  if [[ "$last_key" != "$key" ]]; then
    sleep_log "$message"
    printf '%s\n' "$key" > "$last_reason_file"
  fi
}

clear_sleep_skip_reason() {
  rm -f "$SLEEP_STATE_DIR/last-sleep-skip-reason" 2>/dev/null || true
}

first_world_pid() {
  local pid

  for pid in $(world_pids); do
    if [[ -n "$pid" ]]; then
      echo "$pid"
      return
    fi
  done
}

process_uptime_seconds() {
  local pid="$1"

  [[ -n "$pid" ]] || return 0
  ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' '
}

world_log_contains() {
  local pattern="$1"

  command -v journalctl >/dev/null 2>&1 || return 1
  grep -q "$pattern" < <(journalctl -u "$WORLD_SERVICE" -b --no-pager 2>/dev/null)
}

is_worldserver_ready() {
  world_log_contains "worldserver-daemon) ready"
}

is_playerbots_ready() {
  world_log_contains "mod-playerbots initialized"
}

is_bot_level_brackets_ready() {
  world_log_contains "\\[BotLevelBrackets\\] Module loaded"
}

sleep_readiness_gate() {
  local world_pid
  local world_uptime_seconds

  world_pid="$(first_world_pid)"
  if [[ -z "$world_pid" ]]; then
    sleep_log_skip_once "world-not-running" "worldserver is not running; refusing to sleep"
    return 1
  fi

  if process_is_frozen "$world_pid"; then
    return 1
  fi

  world_uptime_seconds="$(process_uptime_seconds "$world_pid")"
  if [[ -z "$world_uptime_seconds" || ! "$world_uptime_seconds" =~ ^[0-9]+$ || "$world_uptime_seconds" -lt "${MIN_UPTIME_BEFORE_SLEEP:-600}" ]]; then
    sleep_log_skip_once \
      "uptime-below-grace" \
      "Worldserver uptime ${world_uptime_seconds:-unknown}s is below startup grace period ${MIN_UPTIME_BEFORE_SLEEP:-600}s; refusing to sleep"
    return 1
  fi

  # Freezing worldserver during module startup can leave PlayerBots or
  # BotLevelBrackets half-initialized after thaw. Require the current boot logs
  # to show that these late startup paths completed before SIGSTOP is allowed.
  if is_truthy "${REQUIRE_WORLDSERVER_READY:-1}" && ! is_worldserver_ready; then
    sleep_log_skip_once "world-not-ready" "Worldserver is not ready yet; refusing to sleep"
    return 1
  fi

  if is_truthy "${REQUIRE_PLAYERBOTS_READY:-1}" && ! is_playerbots_ready; then
    sleep_log_skip_once "playerbots-not-ready" "PlayerBots is not initialized yet; refusing to sleep"
    return 1
  fi

  if is_truthy "${REQUIRE_BOT_LEVEL_BRACKETS_READY:-1}" && ! is_bot_level_brackets_ready; then
    sleep_log_skip_once "bot-level-brackets-not-ready" "BotLevelBrackets is not initialized yet; refusing to sleep"
    return 1
  fi

  clear_sleep_skip_reason
  return 0
}

world_connection_count() {
  local total=0
  local port count

  require_sleep_command ss

  for port in $WORLD_PORTS; do
    count="$(ss -Htn state established "sport = :$port" 2>/dev/null | wc -l)"
    total=$((total + count))
  done

  echo "$total"
}

port_is_listening() {
  local port="$1"

  require_sleep_command ss
  ss -ltn "sport = :$port" 2>/dev/null | awk 'NR > 1 { found = 1 } END { exit !found }'
}
