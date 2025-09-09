#!/bin/bash
set -euo pipefail

# Resolve script directory (so we can load .env even when called via alias/path)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env if present
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

osascript_tell() { /usr/bin/osascript -e "$1"; }

list_configs() {
  # Print one config name per line
  osascript_tell 'tell application "Tunnelblick" to get name of configurations' | sed 's/, /\n/g' || true
}

autodetect_config() {
  local configs
  configs="$(list_configs || true)"
  if [ -n "$configs" ] && [ "$(printf "%s\n" "$configs" | wc -l | tr -d ' ')" -eq 1 ]; then
    printf "%s" "$configs"
    return 0
  fi
  return 1
}

is_subcmd() {
  case "${1:-}" in
    toggle|on|off|connect|disconnect|status|watch|-h|--help|help) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [VPN_CONFIG_NAME] [command]

Commands:
  toggle   (default)  Connect if disconnected; disconnect if connected.
  on                    Force connect.
  off                   Force disconnect.
  status                Print state.
  watch                 Print state every second.
  -h, --help, help      This help.

Examples:
  $(basename "$0")                       # uses .env or auto-detects single config, toggles
  $(basename "$0") status                # status for .env/auto config
  $(basename "$0") "My Config" on        # explicit config + command
EOF
}

# ---- Parse args robustly ----
SUBCMD="${VPN_SUBCOMMAND:-toggle}"
CFG_FROM_ENV="${VPN_CONFIG_NAME:-}"

# If first arg is a subcommand and we have a config via env, treat it as SUBCMD
if (( $# >= 1 )) && is_subcmd "$1" && [ -n "${CFG_FROM_ENV}" ]; then
  SUBCMD="$1"; shift
fi

# If first arg looks like a config (not a subcmd), take it as config
if (( $# >= 1 )) && ! is_subcmd "$1"; then
  VPN_CONFIG_NAME="$1"; shift
else
  VPN_CONFIG_NAME="${CFG_FROM_ENV:-}"
fi

# If a second arg exists and is a subcmd, use it
if (( $# >= 1 )) && is_subcmd "$1"; then
  SUBCMD="$1"; shift
fi

# Auto-detect config if still not set
if [ -z "${VPN_CONFIG_NAME:-}" ]; then
  if cfg="$(autodetect_config)"; then
    VPN_CONFIG_NAME="$cfg"
  else
    echo "No VPN_CONFIG_NAME set and multiple configs found."
    echo "Set VPN_CONFIG_NAME in $SCRIPT_DIR/.env or pass it as the first argument."
    echo
    echo "Available configurations:"
    list_configs || true
    exit 1
  fi
fi

get_state() {
  osascript_tell "tell application \"Tunnelblick\" to get state of first configuration where name is \"$VPN_CONFIG_NAME\"" \
    | tr '[:lower:]' '[:upper:]'
}

connect_vpn() {
  echo "→ Connecting \"$VPN_CONFIG_NAME\" via Tunnelblick…"
  osascript_tell "tell application \"Tunnelblick\" to connect \"$VPN_CONFIG_NAME\""
}

disconnect_vpn() {
  echo "→ Disconnecting \"$VPN_CONFIG_NAME\" via Tunnelblick…"
  osascript_tell "tell application \"Tunnelblick\" to disconnect \"$VPN_CONFIG_NAME\""
}

# Wait for any of the target states (pipe-separated). Treat EXITING as a valid end-state for disconnects.
wait_for_state() {
  # Usage: wait_for_state "CONNECTED" [timeout]
  #        wait_for_state "DISCONNECTED|EXITING" [timeout]
  local targets_raw="$1"; shift || true
  local timeout="${1:-40}"
  local s start end
  IFS='|' read -r -a TARGETS <<< "$targets_raw"

  start=$(date +%s)
  while true; do
    s=$(get_state 2>/dev/null || true)     # CONNECTED / DISCONNECTING / EXITING / DISCONNECTED / ""
    [[ -n "${QUIET_WAIT:-}" ]] || echo "   state: ${s}"

    # stop if state matches any target
    for t in "${TARGETS[@]}"; do
      [[ "$s" == "$t" ]] && return 0
    done

    # special-case: during disconnect, EXITING (or empty) means we're done
    if [[ " ${TARGETS[*]} " == *" DISCONNECTED "* ]] && [[ "$s" == "EXITING" || -z "$s" ]]; then
      sleep 1
      return 0
    fi

    end=$(date +%s)
    (( end - start >= timeout )) && return 1
    sleep 1
  done
}

follow_logs() {
  echo
  echo "―― Logs (press Ctrl+C to stop) ――"
  /usr/bin/log stream --style syslog --predicate '(process == "Tunnelblick") OR (process == "openvpn")' || true
}

case "$SUBCMD" in
  -h|--help|help) usage; exit 0 ;;
  status)
    echo "$(get_state)"; exit 0 ;;
  watch)
    while true; do echo "$(date '+%H:%M:%S')  $(get_state)"; sleep 1; done
    ;;
  on|connect) ACTION="on" ;;
  off|disconnect) ACTION="off" ;;
  toggle) ACTION="toggle" ;;
  *) echo "Unknown command: $SUBCMD"; usage; exit 1 ;;
esac

current="$(get_state || true)"
echo "Current state: ${current:-UNKNOWN}"

if [[ "$ACTION" == "toggle" ]]; then
  if [[ "$current" == "CONNECTED" || "$current" == "CONNECTING" ]]; then
    ACTION="off"
  else
    ACTION="on"
  fi
fi

if [[ "$ACTION" == "on" ]]; then
  connect_vpn
  if wait_for_state "CONNECTED" 40; then
    echo "✅ Connected."
    follow_logs   # keep terminal open on connect; Ctrl+C to stop
  else
    echo "⚠️ Timed out waiting to CONNECT."
    exit 1
  fi
else
  disconnect_vpn
  if wait_for_state "DISCONNECTED|EXITING" 40; then
    echo "✅ Disconnected."
    # No log tail on disconnect; we end immediately.
  else
    echo "⚠️ Timed out waiting to DISCONNECT."
    exit 1
  fi
fi