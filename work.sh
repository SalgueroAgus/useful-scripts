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

# 3) Ensure Qdrant container is running
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

# 4) Start the Python server
cd "$PROJECT_DIR/$APP_SUBDIR"
if [ -f ".venv/bin/python" ]; then
  exec ".venv/bin/python" api/main.py
elif [ -f "venv/bin/python" ]; then
  exec "venv/bin/python" api/main.py
else
  exec python3 api/main.py
fi