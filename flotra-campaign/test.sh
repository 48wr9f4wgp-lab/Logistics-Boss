#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")" && pwd)
godot=${GODOT:-godot}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/flotra-campaign-test.XXXXXX")
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" FLOTRA_REVIEW_USER_ROOT="$sandbox/"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
timeout 240 "$godot" --headless --editor --path "$project" --import
for suite in domain_campaign domain_effects save_store_test integration_save release_hud_smoke release_hud_input review_save_safety review_domain_save review_campaign_resume readability_world finish_review_journey finish_review_scoring; do
  echo "=== $suite ==="
  timeout 240 "$godot" --headless --path "$project" --script "res://tests/release/$suite.gd"
done
FLOTRA_STORAGE_BRIDGE="$project/campaign-storage.js" node "$project/tests/release/review_storage_test.cjs"
node "$project/tests/release/review_probe_safety.cjs" "$project/../docs/godot-jobs-preview/storage-check.html"
echo '=== readability_input ==='
timeout 240 "$godot" --headless --path "$project" --script res://tests/release/readability_input.gd
