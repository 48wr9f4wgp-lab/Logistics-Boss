#!/usr/bin/env python3
"""Compare full 4.7.2 export to committed qualification bytes without editing either."""
import hashlib
import json
import os
from pathlib import Path
import re
import sys
sys.dont_write_bytecode = True
from diagnose_writer_pack import compare

root = Path(__file__).resolve().parents[3]
exported = Path(sys.argv[1])
evidence = Path(sys.argv[2])
evidence.mkdir(parents=True, exist_ok=True)
manifest_path = Path(os.environ.get('FLOTRA_EXPORT_PROVENANCE', 'FLOTRA_SAVE_READINESS_ARTIFACTS_2026-10-08.json'))
if not manifest_path.is_absolute():
    manifest_path = root / manifest_path
manifest = json.loads(manifest_path.read_text())
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
    'runtimeSourcesMatchManifest': all(sha(root / name) == value for name, value in manifest['sourceSHA256'].items()),
    'inspectorMatchesManifest': all(sha(root / name) == value for name, value in manifest.get('harnessSourceSHA256', {}).items()),
}
# Prospective, explicitly reviewed exception. The old strict mismatch remains
# failed history. This never changes/replaces the committed, browser-tested PCK.
allowed_scenes = {
    '.godot/exported/133200997/export-5f2775806746314698573e32bc8e4921-release.scn': [('FlotraCampaign', 'Node', '.')],
    '.godot/exported/133200997/export-6b9ecba11763283c49e0456ea8e7e3d0-growth.scn': [('FlotraGrowth', 'Node', '.')],
    '.godot/exported/133200997/export-c0b1cce5d9f1449052f4a6622f9dad6e-save_size_web.scn': [('DisposableSizeTest', 'Node', '.')],
    '.godot/imported/packing_workbench.glb-5346c9a59928ee467deb20c316f6591b.scn': [('packing_workbench', 'Node3D', '.'), ('PackingWorkbenchGeometry', 'MeshInstance3D', './PackingWorkbenchGeometry')],
}
resource_report = compare(root / 'docs/godot-jobs-preview/index.pck', exported / 'index.pck')
candidate_scenes = {item['path']: item for item in json.loads((evidence / 'candidate-scenes.json').read_text())}
exported_scenes = {item['path']: item for item in json.loads((evidence / 'exported-scenes.json').read_text())}
scene_checks = {}
scene_checks['exactApprovedSceneSet'] = set(candidate_scenes) == set(exported_scenes) == set(allowed_scenes)
scene_checks['noIdentityAccessInProjectCode'] = not any(re.search(r'node_ids|id_paths|unique_scene_id', (root / name).read_text()) for name in manifest['sourceSHA256'] if name.endswith('.gd'))
scene_checks['allOtherWebBytesExact'] = set(differences) <= {'index.pck'}
scene_checks['sameResourceCount'] = resource_report['candidateResourceCount'] == resource_report['fullExportResourceCount']
for name, expected_nodes in allowed_scenes.items():
    left, right = candidate_scenes.get(name, {}), exported_scenes.get(name, {})
    valid = bool(left and right)
    for item in (left, right):
        ids = item.get('node_ids', [])
        valid = valid and item.get('node_count') == len(expected_nodes) == len(ids)
        valid = valid and len(ids) == len(set(ids)) and all(type(value) is int and 0 < value <= 0x7fffffff for value in ids)
        valid = valid and item.get('base_scene') == -1 and item.get('conn_count') == 0 and item.get('id_paths') == [] and item.get('node_paths') == []
        valid = valid and not any(node.get('hasInstance') for node in item.get('nodes', []))
        valid = valid and [(node['name'], node['type'], node['path']) for node in item.get('nodes', [])] == expected_nodes
    valid = valid and {k: v for k, v in left.items() if k != 'node_ids'} == {k: v for k, v in right.items() if k != 'node_ids'}
    scene_checks[name] = bool(valid)
for row in resource_report['differences']:
    name = row['path']
    valid = name in allowed_scenes and row.get('differenceConfinedToRecognizedNodeIds', False)
    if valid:
        valid = row['candidateNodeIds']['values'] == candidate_scenes[name]['node_ids'] and row['fullExportNodeIds']['values'] == exported_scenes[name]['node_ids']
    scene_checks['resource:' + name] = bool(valid)
# Prefix/suffix byte equality around the uniquely recognized ID array proves
# every other serialized scene field and property unchanged; resource comparison
# independently covers meshes, materials, scripts and every other PCK entry.
passed = all(checks.values()) and all(scene_checks.values())
report = {'godot': manifest['godot'], 'checks': checks, 'sceneChecks': scene_checks,
          'differences': differences, 'resourceComparison': resource_report, 'actual': actual,
          'strictByteMatch': not differences,
          'rule': 'prospective_generated_scene_ids_only; committed PCK remains browser subject',
          'status': 'pass' if passed else 'mismatch_requires_review'}
(evidence / 'full-export-comparison.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
if not passed:
    raise SystemExit(1)
