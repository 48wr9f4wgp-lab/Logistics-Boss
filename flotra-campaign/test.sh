#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")" && pwd)
godot=${GODOT:-godot}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/flotra-campaign-test.XXXXXX")
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" FLOTRA_REVIEW_USER_ROOT="$sandbox/"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
timeout 240 "$godot" --headless --editor --path "$project" --import
# Generate the pinned old checkpoint using frozen code, never an ignored build input.
export FLOTRA_EARNED_FIXTURE="$sandbox/earned_fixture.var"
timeout 240 "$godot" --headless --path "$project" --script res://tests/release/generate_regional_hall_fixture.gd
for suite in domain_campaign domain_effects save_store_test integration_save release_hud_smoke release_hud_input review_save_safety review_domain_save review_campaign_resume readability_world finish_review_journey finish_review_scoring review_phone_scale phone_hud_readability hold_across_refresh growth_balance growth_operations growth_operations_endurance growth_save_regression growth_hud_smoke growth_view_smoke growth_main_smoke growth_controls_comfort growth_copy_regression experience_scene_regression experience_player_input_journey experience_interruption_probe experience_slow_frame_guard experience_foreground_clock camera_interaction_review canceled_touch_input preparation_player_flow regional_hall_player_flow regional_hall_domain_test regional_hall_integrity_review regional_hall_validation_cache postcap_save_archive; do
  echo "=== $suite ==="
  # Every suite owns its disposable native profile. Save/migration fixtures from
  # one suite must never become the next suite's first-open state.
  export HOME="$sandbox/$suite/home" XDG_DATA_HOME="$sandbox/$suite/data" XDG_CONFIG_HOME="$sandbox/$suite/config" XDG_CACHE_HOME="$sandbox/$suite/cache"
  mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
  suite_timeout=240
  if [[ "$suite" == "regional_hall_domain_test" ]]; then suite_timeout=900; fi
  timeout "$suite_timeout" "$godot" --headless --path "$project" --script "res://tests/release/$suite.gd"
done
FLOTRA_STORAGE_BRIDGE="$project/campaign-storage.js" node "$project/tests/release/review_storage_test.cjs"
node "$project/tests/release/postcap_storage_archive.cjs"
node "$project/tests/release/review_probe_safety.cjs" "$project/../docs/godot-jobs-preview/storage-check.html"
echo '=== readability_input ==='
timeout 240 "$godot" --headless --path "$project" --script res://tests/release/readability_input.gd

node "$project/tests/release/review_web_loader_geometry.cjs"

node "$project/tests/release/review_viewport_bridge.cjs"

node "$project/tests/release/review_copy_shell.cjs"
