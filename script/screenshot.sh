#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/docs/screenshots}"
APP_PATH="${APP_PATH:-${ROOT_DIR}/.build/debug/WarpClone.app}"

mkdir -p "${OUTPUT_DIR}"

if [[ ! -d "${APP_PATH}" ]]; then
  "${ROOT_DIR}/script/build_and_run.sh" --build-only
fi

open "${APP_PATH}"
sleep 3

WINDOW_ID="$(osascript <<'OSA' 2>/dev/null || true
tell application "System Events"
  tell process "WarpClone"
    if exists window 1 then
      return id of window 1
    end if
  end tell
end tell
OSA
)"

if [[ -n "${WINDOW_ID}" ]]; then
  screencapture -l "${WINDOW_ID}" "${OUTPUT_DIR}/main_window.png"
else
  echo "WARNING: could not resolve WarpClone window id; taking interactive screenshot"
  screencapture -i "${OUTPUT_DIR}/main_window.png"
fi

echo "Screenshot written to ${OUTPUT_DIR}/main_window.png"
