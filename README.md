# Useful Scripts

Small collection of helper scripts I use regularly. Configure them via `.env` and run directly.

## Setup
- Copy `.env.example` to `.env` and fill in values.
- Make scripts executable: `chmod +x Zoom.sh work.sh`.
- macOS is assumed (uses `open` and the Zoom URL scheme). Linux users can adapt the `open` calls.

## Environment Variables
- ZOOM_MEETING_ID: Zoom meeting ID for `Zoom.sh`. Can also be passed as the first CLI arg.
- ZOOM_PASSWORD: Zoom meeting password for `Zoom.sh`. Can also be passed as the second CLI arg.
- PROJECT_DIR: Absolute path to the project root opened by `work.sh` (VS Code).
- APP_SUBDIR: Subfolder inside `PROJECT_DIR` where the app runs (where `api/main.py` lives).
- LOGIN_URL: URL that `work.sh` opens in Chrome (e.g., a login page).
- QDRANT_NAME: Docker container name that `work.sh` ensures is running (Qdrant DB).
- DOCKER_STARTUP_TIMEOUT: Seconds to wait for Docker Desktop to become ready (default 120).

See `.env.example` for comments and sample values.

## Scripts

### Zoom.sh
- Purpose: Quickly join a Zoom meeting via the Zoom URL scheme.
- Usage: `./Zoom.sh [MEETING_ID] [PASSWORD]`
  - If args are omitted, it uses `ZOOM_MEETING_ID` and `ZOOM_PASSWORD` from `.env`.
- Behavior: Builds `zoommtg://zoom.us/join?...` and opens it with the system handler (Zoom app).
- Requirements: Zoom installed; macOS `open` available.
- Tip: Avoid committing real meeting IDs/passwords; keep them only in your local `.env`.

### work.sh
- Purpose: One command to start a work session: open editor, open login page, ensure Qdrant, run app.
- Usage: `./work.sh`
- What it does:
  - Opens VS Code at `PROJECT_DIR` (uses `code` if available; falls back to the app bundle).
  - Opens Google Chrome at `LOGIN_URL` (falls back to default browser if Chrome isn’t found).
  - Starts Docker Desktop if needed and waits for the Docker daemon to be ready.
  - Ensures Docker container `QDRANT_NAME` is running; starts it or creates a new Qdrant container if absent.
  - Changes into `"$PROJECT_DIR/$APP_SUBDIR"` and runs `api/main.py` using `.venv/bin/python`, `venv/bin/python`, or `python3`.
- Requirements: VS Code, Google Chrome, Docker, Python 3, your app at `api/main.py`.
- Notes: If no container exists, it pulls/runs `qdrant/qdrant:latest` mapped to port 6333.

## Troubleshooting
- VS Code not opening: Install the `code` command or ensure the VS Code app is present.
- Chrome not found: Script falls back to default browser, or install Chrome.
- Docker errors: Ensure Docker Desktop is running and you have permissions to start containers.
- Zoom link doesn’t open: Ensure the Zoom app is installed and registered for `zoommtg://` links.
