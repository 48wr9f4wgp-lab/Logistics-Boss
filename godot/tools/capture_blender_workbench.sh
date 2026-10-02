#!/usr/bin/env bash
# Capture the real main scene using a disposable save profile and actual renderer.
# Requires a graphical desktop. Headless mode cannot establish rendering cost.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=${GODOT_BIN:-godot}
OUT=${1:-"$REPO/build/blender-evidence/current"}
mkdir -p "$OUT" "$REPO/build"
OUT=$(cd "$OUT" && pwd)
PROFILE=$(mktemp -d "$REPO/build/blender-capture-profile.XXXXXX")
mkdir -p "$PROFILE/data" "$PROFILE/config" "$PROFILE/cache"
export XDG_DATA_HOME="$PROFILE/data" XDG_CONFIG_HOME="$PROFILE/config" XDG_CACHE_HOME="$PROFILE/cache"
export FLOTRA_POLISH_CAPTURE_DIR="$OUT" FLOTRA_POLISH_ISOLATED=1
"$BIN" --audio-driver Dummy --path "$REPO/godot" --script res://tests/blender_workbench_capture.gd > "$OUT/capture.log" 2>&1
if grep -Eq 'SCRIPT ERROR|Parse Error|Invalid call|ERROR:' "$OUT/capture.log"; then
  cat "$OUT/capture.log" >&2
  exit 1
fi
test -s "$OUT/render-metrics.json"
echo "Captured real Godot scene to $OUT (synthetic state, not device validation)"
