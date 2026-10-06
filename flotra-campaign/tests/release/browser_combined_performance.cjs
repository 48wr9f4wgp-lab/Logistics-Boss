#!/usr/bin/env node
'use strict';
// A fixed order-balanced comparison. Never retry a measured failure here.
// Uses the existing journey's unchanged assertions and one browser at a time.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const [controlURL, candidateURL, output, fixtures, controlDirectory, candidateDirectory, controlSHA, candidateSHA] = process.argv.slice(2);
assert.ok(controlURL && candidateURL && output && fixtures && controlDirectory && candidateDirectory && controlSHA && candidateSHA,
  'Supply control URL, candidate URL, output, fixtures, export directories, and immutable commit SHAs');
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const assets = ['index.html', 'index.pck', 'index.js', 'index.wasm', 'campaign-viewport.js', 'campaign-storage.js'];
const hashes = directory => Object.fromEntries(assets.map(name => [name, digest(fs.readFileSync(path.join(directory, name)))]));
const journey = path.join(__dirname, 'browser_growth_journey.cjs');
const repositoryRoot = path.resolve(__dirname, '../../..');
const provenancePath = path.join(repositoryRoot, 'FLOTRA_COMBINED_ARTIFACTS.json');
const provenance = JSON.parse(fs.readFileSync(provenancePath, 'utf8'));
assert.equal(controlSHA, provenance.controlCommit, 'Pinned public control commit');
for (const [name, expected] of Object.entries(provenance.sourceSHA256)) {
  assert.equal(digest(fs.readFileSync(path.join(repositoryRoot, name))), expected, 'Frozen runtime source: ' + name);
}
assert.deepEqual(hashes(controlDirectory), provenance.controlAssetsSHA256, 'Pinned public export');
assert.deepEqual(hashes(candidateDirectory), provenance.candidateAssetsSHA256, 'Fresh combined export');
fs.mkdirSync(output, { recursive: true });
const report = {
  scope: 'Same-runner sequential Chromium/SwiftShader WebGL comparison; not physical iPhone/Safari',
  startedAt: new Date().toISOString(),
  order: ['A1', 'B1', 'B2', 'A2'],
  controlSHA, candidateSHA,
  sourceManifestSHA256: digest(fs.readFileSync(provenancePath)),
  viewport: { width: 390, height: 844, dpr: 3 },
  fixtureSHA256: digest(fs.readFileSync(path.join(fixtures, 'late.json'))),
  journeySHA256: digest(fs.readFileSync(journey)),
  exports: { A: hashes(controlDirectory), B: hashes(candidateDirectory) },
  limits: { processP95MsStrictlyBelow: 100, drawCallsMaximum: 250, pausedNodeRangeMaximum: 4,
    rafMedian: 'max(75ms, same-run UI-only median * 1.75)', rafP95: 'max(120ms, same-run UI-only p95 * 2)' },
  validity: 'Every A and B must pass all unchanged journey assertions, match loaded assets, initial state and renderer. No best-run selection or timing retry.',
  results: [],
};
function save() { fs.writeFileSync(path.join(output, 'comparison.json'), JSON.stringify(report, null, 2)); }
try {
  save();
  for (const label of report.order) {
    const control = label.startsWith('A');
    const directory = path.join(output, label);
    fs.mkdirSync(directory, { recursive: true });
    const run = spawnSync(process.execPath, [journey, control ? controlURL : candidateURL, directory, fixtures], {
      env: { ...process.env, FLOTRA_JOURNEY_CASES: 'mature-performance', FLOTRA_EXPORTED_DIRECTORY: control ? controlDirectory : candidateDirectory },
      encoding: 'utf8', timeout: 240000, maxBuffer: 16 * 1024 * 1024,
    });
    fs.writeFileSync(path.join(directory, 'run.log'), (run.stdout || '') + (run.stderr || ''));
    const resultFile = path.join(directory, 'growth-journey.json');
    const result = fs.existsSync(resultFile) ? JSON.parse(fs.readFileSync(resultFile, 'utf8')) : null;
    const test = result?.tests?.find(item => item.name === 'mature-performance');
    report.results.push({ label, exitCode: run.status, signal: run.signal, error: run.error?.message || result?.error || null, test });
    save();
    if (run.error || run.signal || !test) {
      report.classification = 'invalid_harness_lifecycle';
      throw new Error(label + ': measurement did not terminate normally; remaining renders are not started');
    }
  }
  assert.deepEqual(hashes(controlDirectory), report.exports.A, 'Control export stayed frozen');
  assert.deepEqual(hashes(candidateDirectory), report.exports.B, 'Candidate export stayed frozen');
  const controls = report.results.filter(row => row.label.startsWith('A'));
  const candidates = report.results.filter(row => row.label.startsWith('B'));
  const complete = row => row.exitCode === 0 && row.test?.status === 'passed' && row.test?.performance;
  report.controlsHealthy = controls.every(complete);
  report.candidatesPassed = candidates.every(complete);
  const reference = report.results[0].test;
  // Asset dictionaries may arrive in different request orders.
  report.sameConditions = report.results.every(row => {
    if (!row.test || !reference) return false;
    if (row.test.environment?.visibility !== 'visible' ||
        typeof row.test.environment?.renderer !== 'string' || !row.test.environment.renderer.trim() ||
        typeof row.test.environment?.vendor !== 'string' || !row.test.environment.vendor.trim() ||
        typeof row.test.chromiumVersion !== 'string' || !row.test.chromiumVersion.trim()) return false;
    try {
      assert.deepEqual(row.test.environment, reference.environment);
      assert.equal(row.test.chromiumVersion, reference.chromiumVersion);
      assert.deepEqual(row.test.initialState, reference.initialState);
      assert.deepEqual(row.test.loadedAssets, report.exports[row.label[0]]);
      return true;
    } catch { return false; }
  });
  report.relativeDiagnostics = [['A1', 'B1'], ['A2', 'B2']].map(([a, b]) => {
    const control = report.results.find(row => row.label === a).test?.performance?.active;
    const candidate = report.results.find(row => row.label === b).test?.performance?.active;
    return { pair: [a, b], ratios: control && candidate ? Object.fromEntries(
      ['processMedianMs', 'processP95Ms', 'rafMedianMs', 'rafP95Ms'].map(key => [key, candidate[key] / control[key]])) : null };
  });
  report.classification = !report.sameConditions ? 'invalid_comparison' :
    !report.controlsHealthy ? 'inconclusive_unhealthy_control' :
    !report.candidatesPassed ? 'candidate_failed' : 'all_unchanged_gates_passed';
  report.costAssessment = 'Relative changes require review before merge; passing these gates does not establish physical-device smoothness or zero cost increase.';
  report.finishedAt = new Date().toISOString();
  save();
  console.log(JSON.stringify({ classification: report.classification, relativeDiagnostics: report.relativeDiagnostics }));
  assert.equal(report.classification, 'all_unchanged_gates_passed', report.classification);
} catch (error) {
  report.error = error.message;
  save();
  console.error(error);
  process.exitCode = 1;
}
