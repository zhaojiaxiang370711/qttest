#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="${1:-build/qxzn_hmi}"
[ -x "$BIN" ] || { echo "missing binary: $BIN" >&2; exit 1; }
"$BIN" -platform offscreen --windowed --quit-after-ms 800
echo "smoke: exited cleanly"
