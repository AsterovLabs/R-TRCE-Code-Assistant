#!/usr/bin/env bash
# =============================================================================
# start_studio.sh -- Launcher for R-TRCE Code Assistant Interactive Studio
# =============================================================================
# Copyright (c) 2026 Asterov Labs. All Rights Reserved.
# Licensed under the Asterov Labs Proprietary Software License.
# See LICENSE file in the project root for full license terms.
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Locate Rscript without assuming any particular machine layout:
#   1. an explicit R_ENV / RTRCE_R_HOME override
#   2. a user-local ~/.r-env
#   3. whatever is on PATH
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

# `command -v` is a shell builtin and is available where `which` may not be.
if [ -z "$R_BIN" ] && command -v Rscript >/dev/null 2>&1; then
  R_BIN="$(command -v Rscript)"
fi

if [ -z "$R_BIN" ]; then
  echo "Error: Rscript not found." >&2
  echo "  Install R from https://cran.r-project.org, or set R_ENV to your R install." >&2
  exit 1
fi

echo "Using R: $R_BIN"

if [ -z "${PORT:-}" ] || [ "$PORT" = "8083" ]; then
  CHECK_PORT="${PORT:-8083}"
  if curl -s -m 1 "http://127.0.0.1:${CHECK_PORT}/" >/dev/null 2>&1; then
    echo "=================================================================="
    echo "  R-TRCE Studio is already running on http://127.0.0.1:${CHECK_PORT}"
    echo "  Opening in your default browser..."
    echo "=================================================================="
    if command -v garcon-url-handler >/dev/null 2>&1; then
      garcon-url-handler "http://localhost:${CHECK_PORT}" >/dev/null 2>&1 || true
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "http://localhost:${CHECK_PORT}" >/dev/null 2>&1 || true
    elif command -v open >/dev/null 2>&1; then
      open "http://localhost:${CHECK_PORT}" >/dev/null 2>&1 || true
    fi
    exit 0
  fi
fi

# The Studio runs the user's R code, so app.R binds it to localhost unless asked
# otherwise. Remote access is opt-in here rather than the default: it is announced
# below and again in a red banner inside the Studio itself.
if [ -n "${HOST:-}" ]; then
  export HOST
elif [ "${RTRCE_ALLOW_REMOTE:-0}" = "1" ]; then
  export HOST="0.0.0.0"
  echo "[!] RTRCE_ALLOW_REMOTE=1 -- the Studio will be reachable from other machines."
  echo "    Anyone who can reach it can run R code on this machine. Use only on a"
  echo "    network you trust."
fi

# Auto-detect IP addresses
HOST_IPS=""
if command -v hostname >/dev/null 2>&1; then
  HOST_IPS="$(hostname -I 2>/dev/null || true)"
fi

echo "=================================================================="
echo "  Starting R-TRCE Code Assistant Studio & Guided Walkthrough"
echo "=================================================================="
echo "  Listening on: http://${HOST:-127.0.0.1}:${PORT}"
echo ""
echo "  Access the Studio in your browser via:"
echo "   -> http://localhost:${PORT}"
echo "   -> http://127.0.0.1:${PORT}"
for ip in $HOST_IPS; do
  [ "$ip" != "127.0.0.1" ] && echo "   -> http://${ip}:${PORT}"
done
if [ -d /dev/vsock ] || [ -f /run/systemd/container ] || [ -d /mnt/chromeos ]; then
  echo ""
  echo "  [Chromebook / ChromeOS / Baguette Tip]:"
  echo "   -> In Chrome browser: http://penguin.linux.test:${PORT}"
fi
echo "=================================================================="

# Attempt to launch browser if available
(sleep 1.5 && (
  if command -v garcon-url-handler >/dev/null 2>&1; then
    garcon-url-handler "http://localhost:${PORT}" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://localhost:${PORT}" >/dev/null 2>&1 || true
  elif command -v open >/dev/null 2>&1; then
    open "http://localhost:${PORT}" >/dev/null 2>&1 || true
  fi
)) &

"$R_BIN" "$DIR/app.R"

