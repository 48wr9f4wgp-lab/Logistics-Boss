#!/usr/bin/env bash
set -euo pipefail
repo=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
project="$repo/flotra-campaign"
godot=${GODOT:-godot}
# Pinned independently of the new migration validator and implementation fixture.
baseline=0a5a71ee3e88100373fcb77aae685bd4f52a7c24
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/flotra-experience-adversarial.XXXXXX")
export HOME="$sandbox/home" XDG_DATA_HOME="$sandbox/data" XDG_CONFIG_HOME="$sandbox/config" XDG_CACHE_HOME="$sandbox/cache" FLOTRA_REVIEW_USER_ROOT="$sandbox/"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$sandbox/project"
cp -a "$project/." "$sandbox/project/"
rm -rf "$sandbox/project/.godot"
mkdir -p "$sandbox/project/tests/release/_qa_baselines"
for name in jobs_sim release_sim growth_sim; do
  git -C "$repo" show "$baseline:flotra-campaign/prototype/$name.gd" > "$sandbox/project/tests/release/_qa_baselines/$name.gd"
done
python3 - "$sandbox/project" <<'PY'
import pathlib,sys,hashlib,json
p=pathlib.Path(sys.argv[1]); root=p/'tests/release/_qa_baselines'
print(json.dumps({'baseline_commit':'0a5a71ee3e88100373fcb77aae685bd4f52a7c24','sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in root.glob('*.gd')},'implementation_sha256':{name:hashlib.sha256((p/'prototype'/name).read_bytes()).hexdigest() for name in ['growth_sim.gd','growth_v2_sim.gd','jobs_sim.gd','release_save.gd']}}))
# Check the shipped frozen validator is exactly the original, except its class name.
original=(root/'growth_sim.gd').read_text()
frozen=(p/'prototype/growth_v2_sim.gd').read_text()
if original.replace('class_name FlotraGrowthSim','class_name FlotraGrowthV2Sim') != frozen:
    raise SystemExit('Frozen schema2 implementation drifted from pinned independent baseline')
for f in root.glob('*.gd'):
    text=f.read_text()
    text='\n'.join(line for line in text.split('\n') if not line.startswith('class_name '))
    for name in ['jobs_sim','release_sim','growth_sim']:
        text=text.replace(f'res://prototype/{name}.gd',f'res://tests/release/_qa_baselines/{name}.gd')
    f.write_text(text)
PY
export FLOTRA_QA_BASELINE_DIR='res://tests/release/_qa_baselines/'
printf 'Isolated review workspace: %s\n' "$sandbox"
timeout 180 "$godot" --headless --path "$sandbox/project" --script res://tests/release/experience_adversarial.gd
