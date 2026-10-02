#!/usr/bin/env bash
# Native engine pixels only: graphical display required, not WebGL/device QA.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: capture_polish.sh OUTPUT_DIRECTORY [GODOT_PROJECT_DIRECTORY]" >&2
  exit 2
fi
REPO=$(cd "$(dirname "$0")/../.." && pwd)
BIN=${GODOT_BIN:-godot}
PROJECT=${2:-"$REPO/godot"}
mkdir -p "$REPO/build" "$1"
PROFILE=$(mktemp -d "$REPO/build/capture-profile.XXXXXX")
export XDG_DATA_HOME="$PROFILE/data" XDG_CONFIG_HOME="$PROFILE/config" XDG_CACHE_HOME="$PROFILE/cache"
export FLOTRA_POLISH_ISOLATED=1
export FLOTRA_POLISH_CAPTURE_DIR=$(cd "$1" && pwd)
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
"$BIN" --audio-driver Dummy --path "$PROJECT" --script res://tests/polish_render_capture.gd
