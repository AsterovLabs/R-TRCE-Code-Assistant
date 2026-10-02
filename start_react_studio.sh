#!/usr/bin/env bash
# =============================================================================
# start_react_studio.sh -- Launcher for R-TRCE React Local Studio (Linux & macOS)
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8084}"
HOST="${HOST:-127.0.0.1}"

echo "=================================================================="
echo "  R-TRCE Code Assistant -- React Local Studio"
echo "  Asterov Labs (c) 2026"
echo "=================================================================="

# 1. Locate Rscript
R_BIN=""
for candidate in \
  "${R_ENV:+$R_ENV/bin/Rscript}" \
  "${RTRCE_R_HOME:+$RTRCE_R_HOME/bin/Rscript}" \
  "$HOME/.r-env/bin/Rscript"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    R_BIN="$candidate"
    break
  fi
done

if [ -z "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi

if [ -z "$R_BIN" ]; then
  echo "Error: Rscript not found." >&2
  echo "  Please install R from https://cran.r-project.org/" >&2
  exit 1
fi
echo "[OK] Found R: $R_BIN"

# 2. Locate Node.js & npm
if ! command -v node >/dev/null 2>&1; then
  echo "=================================================================="
  echo "  [i] Note: Node.js is not detected on this machine."
  echo "  Launching the interactive Shiny Studio workspace instead..."
  echo "  (To use the modern React Studio, install Node.js v18+ from https://nodejs.org)"
  echo "=================================================================="
  exec "$DIR/start_studio.sh" "$@"
fi
echo "[OK] Found Node.js: $(node -v)"

# 3. Ensure server dependencies are installed
if [ ! -d "$DIR/studio/server/node_modules" ]; then
  echo "[*] Installing backend dependencies in studio/server..."
  (cd "$DIR/studio/server" && npm install --silent)
fi

# 4. Ensure client build exists
if [ ! -d "$DIR/studio/client/dist" ]; then
  echo "[*] Building React frontend client..."
  (cd "$DIR/studio/client" && npm install --silent && npm run build)
fi

# Helper: launch standalone app window or browser
launch_standalone_window() {
  local url="$1"
  # 1. Chromium/Chrome app mode
  for chrome_bin in google-chrome google-chrome-stable chromium-browser chromium brave-browser msedge; do
    if command -v "$chrome_bin" >/dev/null 2>&1; then
      "$chrome_bin" --app="$url" --user-data-dir="${HOME:-.}/.config/r-trce-studio-profile" >/dev/null 2>&1 &
      return 0
    fi
  done
  # 2. Default browser fallback
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "$url" >/dev/null 2>&1 || true
  fi
}

# 5. Check if already running on the target port
if curl -s -m 1 "http://${HOST}:${PORT}/api/status" >/dev/null 2>&1; then
  echo "[*] Studio daemon is already running at http://${HOST}:${PORT}/"
  echo "[*] Opening standalone application window..."
  launch_standalone_window "http://${HOST}:${PORT}"
  exit 0
fi

# 6. Try launching as a native desktop Electron application if display is available
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
  ELECTRON_BIN="$DIR/studio/server/node_modules/.bin/electron"
  if [ -x "$ELECTRON_BIN" ]; then
    echo "[*] Launching R-TRCE Code Assistant Native Desktop IDE..."
    export RSCRIPT_BIN="$R_BIN"
    export PORT="$PORT"
    export HOST="$HOST"
    exec "$ELECTRON_BIN" --no-sandbox "$DIR/studio/server/electron-main.js"
  fi
fi

# 7. Fallback: Launch standalone window in background after short delay
(
  sleep 1.5
  launch_standalone_window "http://${HOST}:${PORT}"
) &

echo "[*] Starting daemon on http://${HOST}:${PORT} (Press Ctrl+C to stop)..."
export RSCRIPT_BIN="$R_BIN"
export PORT="$PORT"
export HOST="$HOST"
exec node "$DIR/studio/server/server.js"
