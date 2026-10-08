#!/usr/bin/env bash
# Reuse immutable baseline pixels from run37739915938; capture the corrected
# candidate only, with the identical domain-earned fixture bytes verified below.
set -euo pipefail
out=${1:?Supply an absolute evidence directory}
: "${GODOT:?Set official Godot4.7.2 executable}"
mkdir -p "$out/fixtures" "$out/exports/candidate"
"$GODOT" --headless --editor --path flotra-campaign --import
"$GODOT" --headless --path flotra-campaign --script res://tests/release/navigation_space_input.gd > "$out/native-input.log" 2>&1
FLOTRA_GROWTH_FIXTURES="$out/fixtures" "$GODOT" --headless --path flotra-campaign --script res://tests/release/growth_browser_fixtures.gd
python3 - "$out/fixtures/complete.json" <<'PY'
import hashlib,json,pathlib,sys
p=pathlib.Path(sys.argv[1]);d=json.loads(p.read_text());digest=hashlib.sha256(d['encoded'].encode()).hexdigest()
expected='08902ee2598040a4f89159bdaf8eaa004c9d23fc287ff86da36de474827debfd'
assert digest==expected,'Synthetic comparison fixture differs from captured immutable baseline'
info={'baselineCommit':'0f39e620634d2c7d48a4d3620c0489ea3b45bb09','baselineRun':37739915938,'baselineSmallArtifact':11533552989,'encodedFixtureSHA256':digest}
(p.parent.parent/'baseline-reuse.json').write_text(json.dumps(info,indent=2)+'\n')
print('NAVIGATION_BASELINE_REUSE',json.dumps(info),flush=True)
PY
bash flotra-campaign/export_web.sh "$out/exports/candidate"
python3 -m http.server 8816 --bind 127.0.0.1 --directory "$out/exports" > "$out/server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
FLOTRA_CAPTURE_REVIEW_ONLY=1 node flotra-campaign/tests/release/browser_navigation_space.cjs http://127.0.0.1:8816/candidate/ "$out/candidate" "$out/fixtures"

