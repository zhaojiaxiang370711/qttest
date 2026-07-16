#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="${1:-build/qxzn_hmi}"
[ -x "$BIN" ] || { echo "missing binary: $BIN" >&2; exit 1; }

if output=$("$BIN" -platform offscreen --windowed --quit-after-ms 800 2>&1); then
    status=0
else
    status=$?
fi
printf '%s\n' "$output"
if (( status != 0 )); then
    echo "smoke: application exited with status $status" >&2
    exit "$status"
fi
if grep -Eiq 'QQmlApplicationEngine failed to load component|ReferenceError:|TypeError:|is not defined' <<<"$output"; then
    echo "smoke: QML runtime error detected" >&2
    exit 1
fi

echo "smoke: exited cleanly"
