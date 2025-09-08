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

# --- Configuration from environment only ---
: "${PROJECT_DIR:?Set PROJECT_DIR in .env (path to your code root)}"
: "${APP_SUBDIR:?Set APP_SUBDIR in .env (app directory inside PROJECT_DIR)}"
: "${LOGIN_URL:?Set LOGIN_URL in .env (URL to open in browser)}"
: "${QDRANT_NAME:?Set QDRANT_NAME in .env (Docker container name for Qdrant)}"

# 1) Open the code folder in VS Code
if command -v code >/dev/null 2>&1; then
  (code "$PROJECT_DIR" >/dev/null 2>&1 &)
else
  open -a "Visual Studio Code" "$PROJECT_DIR"
fi

# 2) Open Chrome on the login page
if open -Ra "Google Chrome" >/dev/null 2>&1; then
  open -a "Google Chrome" "$LOGIN_URL"
else
  open "$LOGIN_URL"
fi

# 3) Ensure Docker Desktop (daemon) is running
ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker CLI not found. Please install Docker Desktop." >&2
    exit 1
  fi

  # If daemon is already up, we're done
  if docker info >/dev/null 2>&1; then
    echo "Docker daemon is running."
    return 0
  fi

  echo "Docker daemon not available. Launching Docker Desktop..."
  # Try without focusing the app first; fall back to standard open
  open -ga Docker 2>/dev/null || open -a "Docker" 2>/dev/null || true

  # Wait for the daemon to be ready
  local timeout="${DOCKER_STARTUP_TIMEOUT:-120}"
  local elapsed=0
  local step=2
  printf "Waiting for Docker to be ready"
  while [ "$elapsed" -lt "$timeout" ]; do
    if docker info >/dev/null 2>&1; then
      printf "\nDocker is ready.\n"
      return 0
    fi
    sleep "$step"
    elapsed=$((elapsed + step))
    printf "."
  done
  printf "\n"
  echo "Docker did not become ready within ${timeout}s." >&2
  exit 1
}

ensure_docker

# 4) Ensure Qdrant container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${QDRANT_NAME}\$"; then
  echo "Qdrant container not running..."
  if docker ps -a --format '{{.Names}}' | grep -q "^${QDRANT_NAME}\$"; then
    echo "Starting existing container: $QDRANT_NAME"
    docker start "$QDRANT_NAME"
  else
    echo "No container found. Creating new Qdrant container..."
    docker run -d --name "$QDRANT_NAME" -p 6333:6333 qdrant/qdrant:latest
  fi
else
  echo "Qdrant container already running."
fi

# 5) Start the Python server
cd "$PROJECT_DIR/$APP_SUBDIR"
if [ -f ".venv/bin/python" ]; then
  exec ".venv/bin/python" api/main.py
elif [ -f "venv/bin/python" ]; then
  exec "venv/bin/python" api/main.py
else
  exec python3 api/main.py
fi
