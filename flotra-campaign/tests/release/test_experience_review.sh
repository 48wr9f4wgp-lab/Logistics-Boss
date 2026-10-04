#!/usr/bin/env bash
# Native scene/input evidence. This does not replace the rendered browser suite.
set -euo pipefail
project=$(cd "$(dirname "$0")/../.." && pwd)
godot=${GODOT:-godot}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/flotra-experience-review.XXXXXX")
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" FLOTRA_REVIEW_USER_ROOT="$sandbox/"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
for suite in experience_slow_frame_guard experience_interruption_probe experience_player_input_journey; do
  echo "=== $suite ==="
  timeout 420 "$godot" --headless --path "$project" --script "res://tests/release/$suite.gd"
done
