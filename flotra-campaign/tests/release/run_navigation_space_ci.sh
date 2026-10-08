#!/usr/bin/env bash
# Scoped capture qualification for an authorized disposable CI runner only.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd)
project="$repo/flotra-campaign"
out=${1:?Supply an absolute evidence directory}
baseline=${2:?Supply an extracted, immutable baseline flotra-campaign directory}
mkdir -p "$out/fixtures" "$out/exports/candidate" "$out/exports/baseline"
# The caller supplies disposable HOME/XDG locations and installed Godot4.7.2
# export templates. Neither a user browser nor a user's native save is accessed.
: "${GODOT:?Set the pinned Godot4.7.2 executable}"
"$GODOT" --headless --editor --path "$project" --import
"$GODOT" --headless --path "$project" --script res://tests/release/navigation_space_input.gd > "$out/native-input.log" 2>&1
FLOTRA_GROWTH_FIXTURES="$out/fixtures" "$GODOT" --headless --path "$project" --script res://tests/release/growth_browser_fixtures.gd
bash "$project/export_web.sh" "$out/exports/candidate"
"$GODOT" --headless --editor --path "$baseline" --import
bash "$baseline/export_web.sh" "$out/exports/baseline"
python3 -m http.server 8816 --bind 127.0.0.1 --directory "$out/exports" > "$out/server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
FLOTRA_UI_BASELINE=1 node "$project/tests/release/browser_navigation_space.cjs" http://127.0.0.1:8816/baseline/ "$out/baseline" "$out/fixtures"
node "$project/tests/release/browser_navigation_space.cjs" http://127.0.0.1:8816/candidate/ "$out/candidate" "$out/fixtures"
