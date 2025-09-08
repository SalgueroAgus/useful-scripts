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

# Read variables strictly from env (or CLI overrides)
MEETING_ID="${1:-${ZOOM_MEETING_ID:-}}"
PASSWORD="${2:-${ZOOM_PASSWORD:-}}"

: "${MEETING_ID:?Set ZOOM_MEETING_ID in .env or pass as first arg}"
: "${PASSWORD:?Set ZOOM_PASSWORD in .env or pass as second arg}"

zoom_url="zoommtg://zoom.us/join?action=join&confno=${MEETING_ID}&pwd=${PASSWORD}"

# macOS opener
open "$zoom_url"