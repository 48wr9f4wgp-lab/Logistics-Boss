'use strict';
// Select expectations from the fixed loader, never from whichever bridge file
// happens to remain beside an export. Public controls retain their old contract.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const legacyKey = 'flotra.campaign.release.v1';
const contracts = {
  'campaign-storage.js': { bridge: 'FlotraCampaignStore', saveKey: legacyKey, version: 1 },
  'dispatch-storage.js': { bridge: 'FlotraDispatchStore', saveKey: 'flotra.campaign.dispatch.v5', version: 5 },
};
function fromScripts(scripts) {
  const names = scripts.map(src => new URL(src, 'https://export.invalid/').pathname.split('/').pop());
  const storage = names.filter(name => Object.hasOwn(contracts, name));
  assert.equal(storage.length, 1, 'Fixed loader loads exactly one recognized storage bridge');
  for (const name of ['campaign-viewport.js', 'index.js']) assert.equal(names.filter(item => item === name).length, 1, 'Fixed loader script: ' + name);
  const asset = storage[0];
  return { ...contracts[asset], asset, legacyKey,
    assets: ['index.html', 'index.pck', 'index.js', 'index.wasm', 'campaign-viewport.js', asset] };
}
function fromLoader(html) {
  return fromScripts(Array.from(html.matchAll(/<script\b[^>]*\bsrc\s*=\s*["']([^"']+)["'][^>]*>/gi), match => match[1]));
}
function fromDirectory(directory) {
  return fromLoader(fs.readFileSync(path.join(directory, 'index.html'), 'utf8'));
}
async function fromPage(page, expected) {
  const actual = fromScripts(await page.evaluate(() => Array.from(document.scripts, script => script.src).filter(Boolean)));
  if (expected) assert.deepEqual(actual, expected, 'Loaded storage contract matches the fixed export');
  assert.equal(await page.evaluate(name => typeof window[name]?.read === 'function' && typeof window[name]?.write === 'function', actual.bridge), true, 'Expected storage bridge is active');
  return actual;
}
async function assertStorage(page, contract, fixture) {
  const storage = await page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map(key => [key, localStorage.getItem(key)])));
  const allowed = [contract.saveKey, contract.saveKey + '.backup'];
  if (contract.version === 5 && fixture) allowed.push(legacyKey, legacyKey + '.backup');
  assert.ok(Object.keys(storage).every(key => allowed.includes(key)), 'Only isolated build-specific campaign save keys written');
  if (contract.version === 5) {
    assert.equal(storage[legacyKey] ?? null, fixture?.encoded ?? null, 'Legacy primary remains byte-identical');
    assert.equal(storage[legacyKey + '.backup'] ?? null, null, 'Absent legacy backup remains absent');
  }
  return storage;
}
function assertComparableInitialState(actual, reference, contract, referenceContract, fixture) {
  if (contract.version === referenceContract.version) return assert.deepEqual(actual, reference);
  assert.ok(fixture.expectedGrowth, 'Native expectations required for a cross-schema comparison');
  const expected = fixture.expectedGrowth[contract.version === 5 ? 'dispatch' : 'legacy'];
  const expectedReference = fixture.expectedGrowth[referenceContract.version === 5 ? 'dispatch' : 'legacy'];
  assert.deepEqual(actual.growth, expected, 'Complete build-specific native growth snapshot');
  assert.deepEqual(reference.growth, expectedReference, 'Complete reference native growth snapshot');
  assert.equal(fixture.expectedGrowth.legacy.catalog_complete, true, 'Frozen fixture owns every original upgrade');
  assert.equal(fixture.expectedGrowth.dispatch.catalog_complete, false, 'Migrated fixture has not bought the new board');
  assert.match(fixture.expectedGrowth.dispatch.next_goal, /集品指示盤/, 'Candidate next goal names its remaining new board');
  assert.notEqual(fixture.expectedGrowth.dispatch.next_goal, fixture.expectedGrowth.legacy.next_goal, 'Intentional new next-goal copy is explicit');
  // Only these two fully asserted catalog fields are allowed to differ. Every
  // other field, including new/unrecognized physical fields, must match exactly.
  const comparable = state => ({ ...state, growth: { ...state.growth, catalog_complete: null, next_goal: null } });
  assert.deepEqual(comparable(actual), comparable(reference), 'All unchanged physical initial conditions match exactly');
}
function assertFullProjectSources(repositoryRoot, expected) {
  assert.ok(expected && typeof expected === 'object' && !Array.isArray(expected), 'Complete project source map is an object');
  const names = [];
  function walk(relative) {
    for (const entry of fs.readdirSync(path.join(repositoryRoot, relative), { withFileTypes: true })) {
      if (entry.name === '.godot' && entry.isDirectory()) continue;
      const name = relative + '/' + entry.name;
      if (entry.isDirectory()) walk(name);
      else if (entry.isFile() || (entry.isSymbolicLink() && fs.statSync(path.join(repositoryRoot, name)).isFile())) names.push(name);
      else assert.fail('Unrecognized project source entry: ' + name);
    }
  }
  walk('flotra-campaign');
  assert.deepEqual(names.sort(), Object.keys(expected).sort(), 'Complete project source key set is unchanged, excluding only .godot');
  for (const name of names) assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(repositoryRoot, name))).digest('hex'), expected[name], 'Exact project source: ' + name);
}
module.exports = { fromScripts, fromLoader, fromDirectory, fromPage, assertStorage, assertComparableInitialState, assertFullProjectSources, legacyKey };
