#!/usr/bin/env python3
"""Compare full 4.7.2 export to committed qualification bytes without editing either."""
import hashlib
import json
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[3]
exported = Path(sys.argv[1])
evidence = Path(sys.argv[2])
evidence.mkdir(parents=True, exist_ok=True)
manifest = json.loads((root / 'FLOTRA_SAVE_READINESS_ARTIFACTS_2026-10-08.json').read_text())
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
names = ['index.html', 'index.js', 'index.wasm', 'index.pck', 'campaign-viewport.js', 'dispatch-storage.js']
actual = {name: sha(exported / name) for name in names}
expected = manifest['candidateAssetsSHA256']
differences = {name: {'candidate': expected[name], 'fullExport': actual[name]} for name in names if expected[name] != actual[name]}
html = (exported / 'index.html').read_text()
shell = (root / 'flotra-campaign/web-shell.html').read_text()
config = json.loads(re.search(r'const GODOT_CONFIG = (\{.*?\});', html)[1])
script = re.search(r'<script>\s*([\s\S]*?)</script>', shell)[1]
normalized = re.sub(r'const GODOT_CONFIG = \{.*?\};', 'const GODOT_CONFIG = $GODOT_CONFIG;', html)
normalized = normalized.replace('const GODOT_THREADS_ENABLED = false;', 'const GODOT_THREADS_ENABLED = $GODOT_THREADS_ENABLED;')
checks = {
    'shellMatchesTrackedSource': script in normalized,
    'bridgeMatchesTrackedSource': (exported / 'dispatch-storage.js').read_bytes() == (root / 'flotra-campaign/dispatch-storage.js').read_bytes(),
    'packSizeMatchesLoader': config['fileSizes']['index.pck'] == (exported / 'index.pck').stat().st_size,
    'noLegacyFilesystem': config['persistentPaths'] == [],
    'engineJsMatchesProduction': actual['index.js'] == manifest['controlAssetsSHA256']['index.js'],
    'engineWasmMatchesProduction': actual['index.wasm'] == manifest['controlAssetsSHA256']['index.wasm'],
}
report = {'godot': manifest['godot'], 'checks': checks, 'differences': differences, 'actual': actual,
          'status': 'pass' if all(checks.values()) and not differences else 'mismatch_requires_review'}
(evidence / 'full-export-comparison.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
if not all(checks.values()) or differences:
    raise SystemExit(1)
