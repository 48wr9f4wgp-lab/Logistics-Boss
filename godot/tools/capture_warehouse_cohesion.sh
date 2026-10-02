#!/usr/bin/env bash
# Actual engine pixels and counters. Requires graphical display; isolated saves.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=${GODOT_BIN:-godot}
OUT=${1:?Usage: capture_warehouse_cohesion.sh OUTPUT [GODOT_PROJECT]}
PROJECT=${2:-"$REPO/godot"}
mkdir -p "$OUT" "$REPO/build"
OUT=$(cd "$OUT" && pwd)
PROFILE=$(mktemp -d "$REPO/build/warehouse-capture-profile.XXXXXX")
mkdir -p "$PROFILE/data" "$PROFILE/config" "$PROFILE/cache"
export XDG_DATA_HOME="$PROFILE/data" XDG_CONFIG_HOME="$PROFILE/config" XDG_CACHE_HOME="$PROFILE/cache"
export FLOTRA_POLISH_CAPTURE_DIR="$OUT" FLOTRA_POLISH_ISOLATED=1
"$BIN" --audio-driver Dummy --path "$PROJECT" --script res://tests/warehouse_cohesion_capture.gd > "$OUT/capture.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Invalid call|ERROR:' "$OUT/capture.log"; then
  cat "$OUT/capture.log" >&2
  exit 1
fi
test -s "$OUT/render-metrics.json"
echo "Captured warehouse comparison to $OUT (not device QA)"
