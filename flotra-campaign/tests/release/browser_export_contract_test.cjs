'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const contract = require('./browser_export_contract.cjs');
const loader = name => `<script src="campaign-viewport.js"></script><script src="${name}"></script><script src="index.js"></script>`;
for (const [asset, bridge, key, version] of [
  ['campaign-storage.js', 'FlotraCampaignStore', 'flotra.campaign.release.v1', 1],
  ['dispatch-storage.js', 'FlotraDispatchStore', 'flotra.campaign.dispatch.v5', 5],
]) test('Exact loader contract: ' + asset, () => {
  const result = contract.fromLoader(loader(asset));
  assert.equal(result.asset, asset); assert.equal(result.bridge, bridge);
  assert.equal(result.saveKey, key); assert.equal(result.version, version);
  assert.deepEqual(result.assets, ['index.html', 'index.pck', 'index.js', 'index.wasm', 'campaign-viewport.js', asset]);
});
test('Reject missing, duplicate and mixed storage bridges', () => {
  for (const html of [loader('unknown.js'), loader('campaign-storage.js') + '<script src="dispatch-storage.js"></script>', loader('dispatch-storage.js') + '<script src="dispatch-storage.js"></script>']) assert.throws(() => contract.fromLoader(html));
});
const page = storage => ({ evaluate: async () => storage });
test('Candidate keeps exact legacy bytes and admits only its own new keys', async () => {
  const current = contract.fromLoader(loader('dispatch-storage.js'));
  await contract.assertStorage(page({ [contract.legacyKey]: 'old', [current.saveKey]: 'new' }), current, { encoded: 'old' });
  await assert.rejects(contract.assertStorage(page({ [contract.legacyKey]: 'changed' }), current, { encoded: 'old' }));
  await assert.rejects(contract.assertStorage(page({ [contract.legacyKey + '.backup']: 'unexpected' }), current));
  await assert.rejects(contract.assertStorage(page({ foreign: 'data' }), current));
});
test('Public control still rejects new dispatch keys', async () => {
  const old = contract.fromLoader(loader('campaign-storage.js'));
  await contract.assertStorage(page({ [old.saveKey]: 'existing', [old.saveKey + '.backup']: 'backup' }), old);
  await assert.rejects(contract.assertStorage(page({ 'flotra.campaign.dispatch.v5': 'unexpected' }), old));
});
const oldContract = contract.fromLoader(loader('campaign-storage.js'));
const newContract = contract.fromLoader(loader('dispatch-storage.js'));
const legacyGrowth = { area: 572.84, human_count: 6, robot_count: 4, wing_count: 4, lifetime_units: 427, catalog_complete: true, next_goal: '現在の増築・設備はすべて導入済み' };
const dispatchGrowth = { ...legacyGrowth, catalog_complete: false, next_goal: '集品指示盤まで資金あと230。定期便でためよう' };
const fixture = { expectedGrowth: { legacy: legacyGrowth, dispatch: dispatchGrowth } };
const initial = { simTime: 85, wallet: 70, growth: legacyGrowth, progress: { shipped: 19, offered: 288 }, camera: { turn: 0, zoom: 1 } };
const candidate = { ...initial, growth: dispatchGrowth };
test('Cross-schema comparison requires both complete native snapshots', () => {
  contract.assertComparableInitialState(candidate, initial, newContract, oldContract, fixture);
  contract.assertComparableInitialState(initial, candidate, oldContract, newContract, fixture);
  assert.throws(() => contract.assertComparableInitialState(candidate, initial, newContract, oldContract, {}));
  assert.throws(() => contract.assertComparableInitialState({ ...candidate, growth: { ...dispatchGrowth, next_goal: 'fabricated' } }, initial, newContract, oldContract, fixture));
});
test('Cross-schema comparison rejects every physical change and unknown fields', () => {
  const changes = [
    { ...candidate, simTime: 86 }, { ...candidate, wallet: 69 },
    { ...candidate, progress: { shipped: 20, offered: 288 } },
    { ...candidate, camera: { turn: 1, zoom: 1 } },
    ...['human_count', 'robot_count', 'wing_count', 'area', 'lifetime_units'].map(key => ({ ...candidate, growth: { ...dispatchGrowth, [key]: dispatchGrowth[key] + 1 } })),
    { ...candidate, growth: { ...dispatchGrowth, new_physical_field: 1 } },
  ];
  for (const changed of changes) assert.throws(() => contract.assertComparableInitialState(changed, initial, newContract, oldContract, fixture));
  // Even mutually changed native expectations cannot excuse changed physics.
  const changed = { ...dispatchGrowth, robot_count: 5 };
  assert.throws(() => contract.assertComparableInitialState({ ...candidate, growth: changed }, initial, newContract, oldContract, { expectedGrowth: { legacy: legacyGrowth, dispatch: changed } }));
});
test('Same-schema comparisons retain the original complete equality check', () => {
  contract.assertComparableInitialState(initial, initial, oldContract, oldContract, {});
  assert.throws(() => contract.assertComparableInitialState(candidate, initial, oldContract, oldContract, fixture));
});
test('Full project provenance verifies contents and exact keys, excluding only generated cache', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flotra-project-provenance-'));
  try {
    const directory = path.join(root, 'flotra-campaign');
    fs.mkdirSync(path.join(directory, '.godot'), { recursive: true });
    fs.mkdirSync(path.join(directory, 'tests'));
    const files = { 'flotra-campaign/project.godot': 'project', 'flotra-campaign/tests/fixture.gd': 'fixture', 'flotra-campaign/image.png.import': 'import descriptor' };
    for (const [name, contents] of Object.entries(files)) fs.writeFileSync(path.join(root, name), contents);
    fs.writeFileSync(path.join(directory, '.godot', 'generated.gdc'), 'different machine cache');
    const hashes = Object.fromEntries(Object.entries(files).map(([name, contents]) => [name, crypto.createHash('sha256').update(contents).digest('hex')]));
    contract.assertFullProjectSources(root, hashes);
    fs.writeFileSync(path.join(directory, 'tests', 'fixture.gd'), 'edited test');
    assert.throws(() => contract.assertFullProjectSources(root, hashes));
    fs.writeFileSync(path.join(directory, 'tests', 'fixture.gd'), 'fixture');
    fs.writeFileSync(path.join(directory, 'extra.gd'), 'extra source');
    assert.throws(() => contract.assertFullProjectSources(root, hashes));
    fs.unlinkSync(path.join(directory, 'extra.gd'));
    fs.unlinkSync(path.join(directory, 'image.png.import'));
    assert.throws(() => contract.assertFullProjectSources(root, hashes));
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});
