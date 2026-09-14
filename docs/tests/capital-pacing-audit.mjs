import { createSimulation } from '../src/sim.js';
import { investedCapital, currentUnitRevenue } from '../src/capital-model.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const originalRandom = Math.random;
Math.random = () => 0.9;

const baseFacilities = {
  secondInbound: true,
  bufferYard: false,
  fastPickRack: true,
  highDensityRack: false,
  secondPack: true,
  fastPackCell: false,
};

const scenarios = [
  {
    name: '8k_band',
    nextTarget: 40000,
    maxBridgeMinutes: 15,
    upgrades: { worker: 0, speed: 1, rack: 1, pack: 1, conveyor: 1, forklift: 0, agv: 0, sorter: 0, hall: 0, truckDock: 0, asrs: 0 },
  },
  {
    name: '40k_band',
    nextTarget: 200000,
    maxBridgeMinutes: 15,
    upgrades: { worker: 1, speed: 1, rack: 1, pack: 1, conveyor: 2, forklift: 1, agv: 0, sorter: 0, hall: 0, truckDock: 0, asrs: 0 },
  },
  {
    name: '200k_band',
    nextTarget: 500000,
    maxBridgeMinutes: 15,
    upgrades: { worker: 2, speed: 3, rack: 2, pack: 3, conveyor: 2, forklift: 1, agv: 1, sorter: 0, hall: 0, truckDock: 0, asrs: 0 },
  },
  {
    name: '500k_band',
    nextTarget: 1000000,
    maxBridgeMinutes: 15,
    upgrades: { worker: 2, speed: 3, rack: 3, pack: 3, conveyor: 3, forklift: 2, agv: 1, sorter: 0, hall: 0, truckDock: 0, asrs: 0 },
  },
];

function runScenario(def) {
  const sim = createSimulation({
    schema_version: 3,
    money: 0,
    research: 0,
    logisticsRating: 8,
    facilityRank: 2,
    facilities: baseFacilities,
    staffingPlan: 'balanced',
    shipped: 0,
    completedContracts: 4,
    milestoneAwarded: 0,
    policy: 'balanced',
    priorities: { store: 3, pick: 3, ship: 4 },
    upgrades: def.upgrades,
    perks: { smartDispatch: 1, bulkPack: 1, contractBonus: 0 },
  });
  sim.setTimeScale(4);
  const shipments = [];
  sim.onEvent((event) => {
    if (event.type === 'shipment') shipments.push(event);
  });

  // 120 simulated seconds of warm-up, then a 180-second steady-state sample.
  for (let i = 0; i < 600; i += 1) sim.update(0.05);
  const warmupCutoff = shipments.length;
  for (let i = 0; i < 900; i += 1) sim.update(0.05);
  const sample = shipments.slice(warmupCutoff);

  const invested = investedCapital(sim.state.upgrades);
  const unitRevenue = currentUnitRevenue(sim.state.upgrades);
  const revenue = sample.reduce((sum, event) => sum + Number(event.value || 0), 0);
  const throughputPerMinute = sample.length / 3;
  const revenuePerMinute = revenue / 3;
  const remaining = Math.max(0, def.nextTarget - invested);
  const bridgeMinutes = revenuePerMinute > 0 ? remaining / revenuePerMinute : Infinity;

  assert(invested > 0, `${def.name}: invested capital must be positive`);
  assert(sample.length > 0, `${def.name}: healthy operation must ship during the sample window`);
  assert(revenuePerMinute > 0, `${def.name}: revenue rate must be positive`);
  assert(bridgeMinutes <= def.maxBridgeMinutes, `${def.name}: healthy capital bridge must stay within ${def.maxBridgeMinutes} minutes, measured ${bridgeMinutes.toFixed(1)}`);

  return {
    scenario: def.name,
    invested,
    unitRevenue,
    shipments: sample.length,
    throughputPerMinute: Math.round(throughputPerMinute * 10) / 10,
    revenuePerMinute: Math.round(revenuePerMinute),
    nextTarget: def.nextTarget,
    remaining,
    bridgeMinutes: Math.round(bridgeMinutes * 10) / 10,
    maxBridgeMinutes: def.maxBridgeMinutes,
  };
}

try {
  const report = scenarios.map(runScenario);
  console.log('CAPITAL_PACING_AUDIT ' + JSON.stringify(report));
  console.log('Capital pacing audit OK');
} finally {
  Math.random = originalRandom;
}
