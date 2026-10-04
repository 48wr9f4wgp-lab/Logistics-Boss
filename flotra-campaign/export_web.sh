#!/usr/bin/env bash
set -euo pipefail
project=$(cd "$(dirname "$0")" && pwd)
out=${1:-"$project/../docs/godot-jobs-preview"}
mkdir -p "$out"
out=$(cd "$out" && pwd)
"${GODOT:-godot}" --headless --path "$project" --export-release Web "$out/index.html"
cp "$project/campaign-storage.js" "$project/campaign-viewport.js" "$out/"
# The loader must never mount the original game's IndexedDB filesystem.
python3 - "$out/index.html" <<'PY'
from pathlib import Path
import json,re,sys
p=Path(sys.argv[1]);s=p.read_text();m=re.search(r'const GODOT_CONFIG = (\{.*?\});',s)
c=json.loads(m.group(1));c['persistentPaths']=[];c['canvasResizePolicy']=0
s=s[:m.start(1)]+json.dumps(c,separators=(',',':'))+s[m.end(1):]
p.write_text(s)
assert 'campaign-viewport.js' in s and c['persistentPaths']==[] and c['canvasResizePolicy']==0
PY
