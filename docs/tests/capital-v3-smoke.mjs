import { createSimulation } from '../src/sim.js';
import {
  CAPITAL_INVESTMENTS,
  investmentUnlocked,
  nextInvestmentCost,
  truckUnloadIntervalForLevel,
  truckWaveIntervalForLevel,
  truckWaveSizeForLevel,
} from '../src/capital-model.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(CAPITAL_INVESTMENTS.truckDock.costs[0] === 650000, 'truck dock must be a property/logistics-scale investment');
assert(!investmentUnlocked({}, 'truckDock'), 'truck dock must not unlock at game start');
assert(truckWaveSizeForLevel(1) === 10 && truckWaveSizeForLevel(3) === 15, 'truck wave size must scale by dock level');
assert(truckWaveIntervalForLevel(3) < truckWaveIntervalForLevel(1), 'higher dock levels must increase truck frequency');
assert(truckUnloadIntervalForLevel(3) < truckUnloadIntervalForLevel(1), 'higher dock levels must unload faster');

const sim = createSimulation({
  schema_version: 3,
  money: 100000000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: { bufferYard: true, highDensityRack: true, secondPack: true },
  staffingPlan: 'receiving',
  shipped: 0,
  completedContracts: 8,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 5, pick: 3, ship: 3 },
  upgrades: { worker: 5, speed: 5, rack: 4, pack: 5, conveyor: 4, forklift: 4, agv: 4, sorter: 4, hall: 2, truckDock: 0 },
  perks: {},
});

const cost = nextInvestmentCost(sim.state.upgrades, 'truckDock');
const bought = sim.purchaseCapitalUpgrade('truckDock', cost);
assert(bought.ok && bought.level === 1, 'truck dock level 1 must purchase through simulation domain');
assert(sim.state.upgrades.truckDock === 1, 'truck dock level must be stored in upgrades');
assert(sim.inboundMax() >= 2, 'truck dock must contribute receiving headroom');

const events = [];
sim.onEvent((event) => events.push(event));
sim.setTimeScale(4);
for (let i = 0; i < 600; i += 1) sim.update(0.05);

assert(events.some((event) => event.type === 'truck_approach'), 'truck must visibly begin an approach cycle');
assert(events.some((event) => event.type === 'truck_arrive'), 'truck must reach the dock');
assert(events.some((event) => event.type === 'truck_unload'), 'truck must unload real inbound parcels');
assert(events.some((event) => event.type === 'inbound' && event.source === 'truck'), 'truck unload must feed the real inbound queue');
assert(events.some((event) => event.type === 'truck_depart'), 'truck must leave after unloading');

const saved = sim.serialize();
const reloaded = createSimulation(saved);
assert(reloaded.state.upgrades.truckDock === 1, 'truck dock investment must survive save/load');

console.log('Capital v2 Phase 3 truck-wave smoke OK');
