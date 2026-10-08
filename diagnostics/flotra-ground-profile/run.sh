#!/usr/bin/env bash
set -euo pipefail
runtime=$(cd "${1:?Pass immutable runtime checkout}" && pwd)
out=${2:?Pass evidence directory}
mkdir -p "$out"
out=$(cd "$out" && pwd)
harness=$(cd "$(dirname "$0")" && pwd)
expected=6e3829793d771f25a828c0d169db6dcc77e525e3
test "$(git -C "$runtime" rev-parse HEAD)" = "$expected"
git -C "$runtime" diff --exit-code
godot --version > "$out/godot-version.txt"
node --version > "$out/node-version.txt"
printf '%s\n' "runtime=$expected" "harness=${FLOTRA_DIAGNOSTIC_HARNESS_SHA:-local-validation}" > "$out/commits.txt"
sha256sum "$harness/"* > "$out/harness-sha256.txt"
stage=$(mktemp -d "${RUNNER_TEMP:-/tmp}/flotra-ground-profile.XXXXXX")
server=
trap 'if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; fi' EXIT
template_source="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/ms-playwright}"
export HOME="$stage/home" XDG_DATA_HOME="$stage/data" XDG_CONFIG_HOME="$stage/config" XDG_CACHE_HOME="$stage/cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$stage/project" "$out/fixtures" "$out/export"
test -d "$template_source"
mkdir -p "$XDG_DATA_HOME/godot"
ln -s "$template_source" "$XDG_DATA_HOME/godot/export_templates"
cp -a "$runtime/flotra-campaign/." "$stage/project/"
python3 - "$runtime" "$stage/project" "$out" <<'PY'
import hashlib,json,pathlib,sys
runtime,stage,out=map(pathlib.Path,sys.argv[1:])
manifest=json.loads((runtime/'FLOTRA_VISUAL_GROWTH_ARTIFACTS_2026-10-07.json').read_text())
record={}
for path,expected in manifest['fullProjectSourceSHA256'].items():
    relative=path.removeprefix('flotra-campaign/')
    actual=hashlib.sha256((stage/relative).read_bytes()).hexdigest()
    assert actual==expected,(path,actual,expected)
    record[path]=actual
(out/'runtime-source-sha256.json').write_text(json.dumps(record,indent=2))
PY
# The original builder uses only earned public-domain actions and does not
# touch real saves. It produces several fixture files; only late.json is used.
godot --headless --editor --path "$stage/project" --import > "$out/import.log" 2>&1
FLOTRA_GROWTH_FIXTURES="$out/fixtures" godot --headless --path "$stage/project" --script res://tests/release/growth_browser_fixtures.gd > "$out/fixture.log" 2>&1
mkdir -p "$stage/project/diagnostic"
cp "$harness/ground_profile.gd" "$stage/project/diagnostic/ground_profile.gd"
cp "$out/fixtures/late.json" "$stage/project/diagnostic/late.json"
cat > "$stage/project/diagnostic/ground_profile.tscn" <<'SCENE'
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://diagnostic/ground_profile.gd" id="1"]
[node name="GroundProfile" type="Node"]
script = ExtResource("1")
SCENE
python3 - "$stage/project" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1])/'project.godot'
s=p.read_text();old='run/main_scene="res://prototype/growth.tscn"'
assert s.count(old)==1
p.write_text(s.replace(old,'run/main_scene="res://diagnostic/ground_profile.tscn"'))
# Include the fixed JSON input in the disposable export, never production.
p=pathlib.Path(sys.argv[1])/'export_presets.cfg';s=p.read_text()
assert s.count('include_filter=""')==1
p.write_text(s.replace('include_filter=""','include_filter="diagnostic/late.json"'))
PY
godot --headless --editor --path "$stage/project" --import > "$out/diagnostic-import.log" 2>&1
bash "$stage/project/export_web.sh" "$out/export" > "$out/export.log" 2>&1
sha256sum "$out/fixtures/late.json" "$out/export/"* > "$out/export-sha256.txt"
python3 -m http.server 8863 --bind 127.0.0.1 --directory "$out/export" > "$out/server.log" 2>&1 &
server=$!
node "$harness/browser_profile.cjs" http://127.0.0.1:8863/ "$out"
# Runtime checkout must still be unmodified after the complete diagnostic.
git -C "$runtime" diff --exit-code
