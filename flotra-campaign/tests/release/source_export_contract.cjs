'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const contract = require('./browser_export_contract.cjs');
const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
// The expected digest comes from the completed export step, not this file.
// Hash and parse the same bytes; never adopt a replacement manifest as baseline.
function readPinnedManifest(file, expectedSHA256) {
  assert.match(expectedSHA256, /^[0-9a-f]{64}$/, 'Export step manifest digest is required');
  const bytes = fs.readFileSync(file);
  const actual = crypto.createHash('sha256').update(bytes).digest('hex');
  assert.equal(actual, expectedSHA256, 'Manifest changed after export step');
  return JSON.parse(bytes.toString('utf8'));
}
function verify(manifest, controlSHA, candidateSHA, controlDirectory, candidateDirectory) {
  assert.equal(manifest.kind, 'flotra-source-export-pair-v1');
  assert.equal(manifest.godot, '4.7.2.stable.official.ed1daf0bf');
  assert.equal(manifest.controlCommit, controlSHA);
  assert.equal(manifest.candidateCommit, candidateSHA);
  assert.equal(manifest.controlQualification.status, 'pass', 'Pinned control bounded comparison passed');
  assert.equal(manifest.controlQualification.rule, 'prospective_generated_scene_ids_only; committed PCK remains browser subject');
  assert.equal(manifest.controlQualification.checks.runtimeSourcesMatchManifest, true);
  assert.equal(manifest.controlQualification.sceneChecks.exactApprovedSceneSet, true);
  assert.ok(Object.values(manifest.controlQualification.checks).every(value => value === true));
  assert.ok(Object.values(manifest.controlQualification.sceneChecks).every(value => value === true));
  assert.deepEqual(manifest.controlQualification.actual, manifest.variants.A.assetsSHA256, 'Bounded check covers measured control bytes');
  const repository = path.resolve(__dirname, '../../..');
  assert.ok(Object.keys(manifest.harnessSHA256).length > 0);
  for (const [name, expected] of Object.entries(manifest.harnessSHA256)) assert.equal(hash(path.join(repository, name)), expected, 'Frozen comparison harness: ' + name);
  for (const [label, sha, directory] of [['A', controlSHA, controlDirectory], ['B', candidateSHA, candidateDirectory]]) {
    const variant = manifest.variants[label];
    assert.equal(variant.commit, sha);
    assert.equal(path.resolve(variant.exportDirectory), path.resolve(directory), 'Serve the attested export directory');
    contract.assertFullProjectSources(variant.sourceDirectory, variant.sourceSHA256);
    const names = fs.readdirSync(directory).sort();
    assert.deepEqual(names, Object.keys(variant.allExportAssetsSHA256).sort(), 'Exact exported file set');
    for (const name of names) assert.equal(hash(path.join(directory, name)), variant.allExportAssetsSHA256[name], 'Exact generated asset: ' + name);
    assert.deepEqual(Object.keys(variant.assetsSHA256).sort(), contract.fromDirectory(directory).assets.slice().sort());
    for (const name of Object.keys(variant.assetsSHA256)) assert.equal(hash(path.join(directory, name)), variant.assetsSHA256[name]);
  }
}
module.exports = { verify, readPinnedManifest };
