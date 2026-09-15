import assert from 'node:assert/strict';
import { createSimulation } from '../src/sim.js';

const snapshot = {
  schema_version: 3,
  money: 5000000,
  research: 20,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {
    secondInbound: true,
    bufferYard: false,
    fastPickRack: true,
    highDensityRack: false,
    secondPack: true,
    fastPackCell: false,
  },
  staffingPlan: 'balanced',
  shipped: 200,
  completedContracts: 0,
  milestoneAwarded: 200,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {
    worker: 3,
    speed: 5,
    rack: 4,
    pack: 5,
    conveyor: 4,
    forklift: 4,
    agv: 4,
    sorter: 4,
    hall: 1,
    truckDock: 0,
    asrs: 0,
  },
  perks: { smartDispatch: 1, bulkPack: 1, contractBonus: 0 },
};

const sim = createSimulation(snapshot);
const events = [];
sim.onEvent((event) => events.push(event));

assert.equal(sim.state.facilityRank, 2, 'snapshot should begin at Warehouse');
assert.equal(sim.fulfillmentReadiness().conditions.zones, true, 'all three Rank 2 zones should be complete');
assert.equal(sim.fulfillmentReadiness().conditions.assets, true, 'capital target should be met');
assert.equal(sim.state.completedContracts, 0, 'contracts must remain optional');

let elapsed = 0;
while (elapsed < 120 && sim.state.facilityRank < 3) {
  sim.update(0.05);
  elapsed += 0.05;
}

assert.equal(sim.state.facilityRank, 3, `real simulation should promote to Rank 3 within 120s; throughput=${sim.state.metrics.perMinute}`);
assert.equal(sim.facilityRankName(), 'Fulfillment Center');
assert.ok(sim.state.metrics.perMinute >= 6, 'promotion must be supported by measured shipment throughput');
assert.ok(events.some((event) => event.type === 'rank_up' && event.rank === 3), 'Rank 3 promotion event should fire');
assert.equal(events.filter((event) => event.type === 'rank_up' && event.rank === 3).length, 1, 'Rank 3 promotion should fire once');

const saved = sim.serialize();
assert.equal(saved.facilityRank, 3, 'Rank 3 must serialize');

const restored = createSimulation(saved);
assert.equal(restored.state.facilityRank, 3, 'Rank 3 must survive hydration');
assert.equal(restored.facilityRankName(), 'Fulfillment Center');
restored.update(0.05);
assert.equal(restored.state.facilityRank, 3, 'restored Rank 3 must not regress');

console.log(`Rank 3 promotion smoke passed in ${elapsed.toFixed(1)} simulated seconds at ${sim.state.metrics.perMinute}/min`);
