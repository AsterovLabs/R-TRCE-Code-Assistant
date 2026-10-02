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

# 2. Locate Electron runtime
ELECTRON_BIN=""
for candidate in \
  "$DIR/studio/server/node_modules/electron/dist/electron" \
  "$DIR/studio/server/node_modules/.bin/electron" \
  "$(command -v electron 2>/dev/null || true)"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    ELECTRON_BIN="$candidate"
    break
  fi
done

# 3. If Electron is not yet installed and npm exists, install dependencies
if [ -z "$ELECTRON_BIN" ] && command -v npm >/dev/null 2>&1; then
  echo "[*] Installing native desktop runtime dependencies in studio/server..."
  (cd "$DIR/studio/server" && npm install --silent) || true
  for candidate in \
    "$DIR/studio/server/node_modules/electron/dist/electron" \
    "$DIR/studio/server/node_modules/.bin/electron"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      ELECTRON_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$ELECTRON_BIN" ]; then
  echo "Error: Native desktop Electron runtime not found." >&2
  echo "  Please run 'npm install' inside studio/server or ensure internet access on first run." >&2
  exit 1
fi
echo "[OK] Found Desktop Runtime: $ELECTRON_BIN"

# 4. Ensure client build exists
if [ ! -d "$DIR/studio/client/dist" ]; then
  if command -v npm >/dev/null 2>&1; then
    echo "[*] Building React frontend client..."
    (cd "$DIR/studio/client" && npm install --silent && npm run build)
  fi
fi

# 5. Launch native desktop Electron application
echo "[*] Launching R-TRCE Studio Native Desktop IDE..."
export RSCRIPT_BIN="$R_BIN"
export PORT="$PORT"
export HOST="$HOST"
exec "$ELECTRON_BIN" --no-sandbox "$DIR/studio/server/electron-main.js" "$@"
