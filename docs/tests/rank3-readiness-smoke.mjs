import fs from 'node:fs';
import {
  RANK3_ASSET_TARGET,
  RANK3_THROUGHPUT_TARGET,
  rank3ReadinessFromState,
} from '../src/rank3.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const facilityInfo = {
  secondInbound: { group: 'intakeStrategy' },
  bufferYard: { group: 'intakeStrategy' },
  fastPickRack: { group: 'rackStrategy' },
  highDensityRack: { group: 'rackStrategy' },
  secondPack: { group: 'packStrategy' },
  fastPackCell: { group: 'packStrategy' },
};

const readyState = {
  completedContracts: 0,
  facilities: {
    secondInbound: true,
    bufferYard: false,
    fastPickRack: true,
    highDensityRack: false,
    secondPack: true,
    fastPackCell: false,
  },
  // Hall Lv.1 alone is ¥300,000 of real equipment assets; no specific purchase path is required by readiness.
  upgrades: { hall: 1 },
  metrics: { perMinute: RANK3_THROUGHPUT_TARGET },
};

const ready = rank3ReadinessFromState(readyState, facilityInfo);
assert(RANK3_ASSET_TARGET === 200000, 'Rank 3 asset target must remain ¥200,000');
assert(RANK3_THROUGHPUT_TARGET === 6, 'Rank 3 throughput target must remain 6/min');
assert(ready.zones === 3, 'all three structural zones must count');
assert(ready.assets >= RANK3_ASSET_TARGET, 'representative state must satisfy capital scale');
assert(ready.throughput === 6, 'representative state must satisfy measured throughput');
assert(ready.ready, 'Rank 3 must be reachable with zero completed contracts');
assert(ready.score === 3, 'all three path-agnostic conditions must be satisfied');
assert(!Object.prototype.hasOwnProperty.call(ready.conditions, 'contracts'), 'contracts must not be a Rank 3 readiness condition');

const withManyContracts = rank3ReadinessFromState({ ...readyState, completedContracts: 999 }, facilityInfo);
assert(withManyContracts.score === ready.score && withManyContracts.ready === ready.ready, 'contracts must not change Rank 3 readiness');

const missingZone = rank3ReadinessFromState({
  ...readyState,
  facilities: { ...readyState.facilities, secondPack: false },
}, facilityInfo);
assert(!missingZone.ready && !missingZone.conditions.zones, 'missing structural design must block readiness');

const missingAssets = rank3ReadinessFromState({ ...readyState, upgrades: {} }, facilityInfo);
assert(!missingAssets.ready && !missingAssets.conditions.assets, 'insufficient equipment assets must block readiness');

const missingThroughput = rank3ReadinessFromState({
  ...readyState,
  metrics: { perMinute: RANK3_THROUGHPUT_TARGET - 1 },
}, facilityInfo);
assert(!missingThroughput.ready && !missingThroughput.conditions.throughput, 'insufficient measured throughput must block readiness');

const indexSource = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const mainSource = fs.readFileSync(new URL('../src/main.js', import.meta.url), 'utf8');
assert(!indexSource.includes('契約 0/8'), 'Fulfillment Center UI must not show mandatory contract progress');
assert(!indexSource.includes('id="goalContracts"'), 'old contract-gated readiness DOM must stay removed');
assert(indexSource.includes('id="rank3GoalAssets"'), 'Rank 3 UI must expose equipment-asset readiness');
assert(indexSource.includes('設備 ¥0/¥200,000'), 'Rank 3 asset target must be legible before runtime render');
assert(mainSource.includes("import { bindRank3Readiness } from './rank3.js';"), 'main loop must bind the Rank 3 readiness owner');
assert(mainSource.includes('rank3.update(dt);'), 'Rank 3 readiness owner must update during gameplay');

console.log('Rank 3 contract-free readiness smoke OK');
