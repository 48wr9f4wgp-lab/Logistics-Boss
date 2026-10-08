#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")" && pwd)
godot=${GODOT:-godot}
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/flotra-campaign-test.XXXXXX")
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" FLOTRA_REVIEW_USER_ROOT="$sandbox/"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
timeout 240 "$godot" --headless --editor --path "$project" --import
export FLOTRA_GROWTH_FIXTURES="$sandbox/growth-fixtures"
mkdir -p "$FLOTRA_GROWTH_FIXTURES"
timeout 240 "$godot" --headless --path "$project" --script res://tests/release/growth_browser_fixtures.gd
for suite in domain_campaign domain_effects save_store_test save_size_preflight integration_save release_hud_smoke release_hud_input review_save_safety review_domain_save review_campaign_resume readability_world finish_review_journey finish_review_scoring review_phone_scale phone_hud_readability hold_across_refresh growth_balance growth_operations growth_operations_endurance growth_save_regression growth_hud_smoke upgrade_visibility visual_quality visual_material_roles growth_view_smoke growth_main_smoke growth_controls_comfort growth_copy_regression experience_scene_regression experience_player_input_journey experience_interruption_probe experience_slow_frame_guard experience_foreground_clock camera_interaction_review visual_growth_only canceled_touch_input preparation_player_flow dispatch_domain dispatch_scene_safety dispatch_autosave_clock dispatch_save_migration dispatch_save_phases dispatch_hud_flow dispatch_comparison_copy; do
  echo "=== $suite ==="
  # Every suite owns its disposable native profile. Save/migration fixtures from
  # one suite must never become the next suite's first-open state.
  export HOME="$sandbox/$suite/home" XDG_DATA_HOME="$sandbox/$suite/data" XDG_CONFIG_HOME="$sandbox/$suite/config" XDG_CACHE_HOME="$sandbox/$suite/cache"
  mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
  timeout 240 "$godot" --headless --path "$project" --script "res://tests/release/$suite.gd"
done
FLOTRA_STORAGE_BRIDGE="$project/campaign-storage.js" node "$project/tests/release/review_storage_test.cjs"
node "$project/tests/release/dispatch_storage_test.cjs"
node "$project/tests/release/dispatch_writer_ready_test.cjs"
node "$project/tests/release/dispatch_loader_ready_test.cjs"
node "$project/tests/release/browser_export_contract_test.cjs"
node "$project/tests/release/review_probe_safety.cjs" "$project/../docs/godot-jobs-preview/storage-check.html"
echo '=== readability_input ==='
timeout 240 "$godot" --headless --path "$project" --script res://tests/release/readability_input.gd

node "$project/tests/release/review_web_loader_geometry.cjs"

node "$project/tests/release/review_viewport_bridge.cjs"

node "$project/tests/release/review_copy_shell.cjs"
