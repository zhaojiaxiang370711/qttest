#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="${1:-build/qxzn_hmi}"
[ -x "$BIN" ] || { echo "missing binary: $BIN" >&2; exit 1; }

check_run() {
    local label="$1"; shift
    local output status
    output=$("$@" 2>&1) && status=0 || status=$?
    printf '%s\n' "$output"
    if (( status != 0 )); then
        echo "smoke[$label]: application exited with status $status" >&2
        exit "$status"
    fi
    if grep -Eiq 'QQmlApplicationEngine failed to load component|ReferenceError:|TypeError:|is not defined' <<<"$output"; then
        echo "smoke[$label]: QML runtime error detected" >&2
        exit 1
    fi
    echo "smoke[$label]: exited cleanly"
}

# Default home shell.
check_run home "$BIN" -platform offscreen --windowed --no-dds --quit-after-ms 800

# AI assistant deep link: validates the migrated page, free-text composer and
# local fallback state machine load without requiring the remote AI service.
check_run ai_assistant \
    "$BIN" -platform offscreen --windowed --no-dds \
    --nav ai_coach --quit-after-ms 900

# Course lesson deep link with media deliberately unavailable: the player must
# load the controlled missing-media error overlay (no crash, no QML error).
# --media-root overrides the dev auto-root fallback so this path is exercised
# even on a dev box where qxzn-hmi-qt/media exists. Course code must never touch
# DDS, so --no-dds is mandatory here too.
check_run course_lesson_missing_media \
    env -u QXZN_MEDIA_DIR QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink \
    "$BIN" -platform offscreen --windowed --no-dds \
    --media-root /nonexistent/qxzn-media \
    --nav course_lesson --course special_practice --quit-after-ms 1200
