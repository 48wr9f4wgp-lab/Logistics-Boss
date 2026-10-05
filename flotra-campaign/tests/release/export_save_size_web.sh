#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")/../.." && pwd)
out=${1:?Pass an isolated test export directory}
mkdir -p "$out"
out=$(cd "$out" && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/flotra-size-web.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/prototype" "$stage/tests/release"
for name in jobs_sim release_sim growth_v2_sim growth_sim release_save; do
  cp "$project/prototype/$name.gd" "$stage/prototype/"
done
cp "$project/tests/release/"{save_size_checks.gd,save_size_web.gd,save_size_web.tscn} "$stage/tests/release/"
cp "$project/campaign-storage.js" "$stage/campaign-storage.js"
cp "$stage/campaign-storage.js" "$out/campaign-storage.js"
cat > "$stage/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="FLOTRA disposable save-size test"
run/main_scene="res://tests/release/save_size_web.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=375
window/size/viewport_height=567
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
PROJECT
cat > "$stage/web-shell.html" <<'HTML'
<!doctype html><html lang="ja"><meta charset="utf-8"><title>FLOTRA disposable save-size test</title><link rel="icon" href="data:,"><canvas id="canvas"></canvas>
<script src="campaign-storage.js"></script><script src="$GODOT_URL"></script><script>
const GODOT_CONFIG = $GODOT_CONFIG;
GODOT_CONFIG.persistentPaths=[];
const engine=new Engine(GODOT_CONFIG);
engine.startGame({canvas:document.getElementById('canvas')}).catch(error=>{console.error(error);window.flotraSizeLoadError=String(error);});
</script></html>
HTML
cat > "$stage/export_presets.cfg" <<'PRESET'
[preset.0]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter=""
script_export_mode=2
[preset.0.options]
variant/thread_support=false
html/custom_html_shell="res://web-shell.html"
html/canvas_resize_policy=0
progressive_web_app/enabled=false
PRESET
"${GODOT:-godot}" --headless --path "$stage" --editor --import
"${GODOT:-godot}" --headless --path "$stage" --export-release Web "$out/index.html"
# Record the exact production source inputs used in this diagnostic PCK.
(cd "$stage" && sha256sum prototype/{jobs_sim,release_sim,growth_v2_sim,growth_sim,release_save}.gd campaign-storage.js tests/release/save_size_checks.gd) > "$out/source-sha256.txt"
