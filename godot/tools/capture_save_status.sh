#!/usr/bin/env bash
# Real engine pixels with only disposable fixture files and a genuine write rejection.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=${GODOT_BIN:-"$REPO/build/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64"}
OUT=${1:?Usage: capture_save_status.sh OUTPUT}
mkdir -p "$OUT" "$REPO/build"
OUT=$(cd "$OUT" && pwd)
PROFILE=$(mktemp -d "$REPO/build/save-status-capture.XXXXXX")
mkdir -p "$PROFILE/data" "$PROFILE/config" "$PROFILE/cache"
export XDG_DATA_HOME="$PROFILE/data" XDG_CONFIG_HOME="$PROFILE/config" XDG_CACHE_HOME="$PROFILE/cache"
export FLOTRA_POLISH_CAPTURE_DIR="$OUT" FLOTRA_POLISH_ISOLATED=1
"$BIN" --audio-driver Dummy --path "$REPO/godot" --script res://tests/save_status_capture.gd > "$OUT/capture.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Invalid call|ERROR:' "$OUT/capture.log"; then cat "$OUT/capture.log" >&2; exit 1; fi
test -s "$OUT/recovered-430.png"
echo "Captured save-status states to $OUT (not device QA)"
