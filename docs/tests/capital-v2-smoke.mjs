import { createSimulation } from '../src/sim.js';
import {
  CAPITAL_INVESTMENTS,
  currentUnitRevenue,
  investedCapital,
  investmentUnlocked,
  nextInvestmentCost,
} from '../src/capital-model.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(CAPITAL_INVESTMENTS.forklift.costs[0] === 15000, 'forklift must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.agv.costs[0] === 40000, 'AGV must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.sorter.costs[0] === 90000, 'sorter must be a distinct capital category');
assert(!investmentUnlocked({}, 'forklift'), 'forklift must be gated by equipment assets');
assert(investmentUnlocked({ rack: 1, pack: 1, speed: 1, conveyor: 1 }, 'forklift'), 'forklift must unlock once equipment assets reach its threshold');
assert(!investmentUnlocked({ rack: 1, pack: 1, speed: 1, conveyor: 1 }, 'agv'), 'AGV must remain locked at the first automation threshold');

const buyer = createSimulation({
  schema_version: 3,
  money: 100000000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {},
  staffingPlan: 'balanced',
  shipped: 0,
  completedContracts: 4,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: { worker: 0, speed: 5, rack: 4, pack: 5, conveyor: 4, forklift: 0, agv: 0, sorter: 0 },
  perks: {},
});
const cashBefore = buyer.state.money;
const forkliftCost = nextInvestmentCost(buyer.state.upgrades, 'forklift');
const purchase = buyer.purchaseCapitalUpgrade('forklift', forkliftCost);
assert(purchase.ok && purchase.level === 1, 'domain API must purchase forklift level 1');
assert(buyer.state.money === cashBefore - forkliftCost, 'capital purchase must deduct cash in simulation domain');
assert(buyer.state.upgrades.forklift === 1, 'capital purchase must update the simulation upgrade state');
const saved = buyer.serialize();
const reloaded = createSimulation(saved);
assert(reloaded.state.upgrades.forklift === 1, 'Capital v2 upgrades must survive save/load');
assert(investedCapital(reloaded.state.upgrades) > investedCapital({}), 'Capital v2 equipment must count toward equipment assets');

const auto = createSimulation({
  schema_version: 3,
  money: 100000000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {
    secondInbound: true,
    bufferYard: true,
    fastPickRack: false,
    highDensityRack: true,
    secondPack: true,
    fastPackCell: false,
  },
  staffingPlan: 'balanced',
  shipped: 0,
  completedContracts: 12,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: { worker: 0, speed: 5, rack: 4, pack: 5, conveyor: 0, forklift: 4, agv: 4, sorter: 4 },
  perks: { smartDispatch: 0, bulkPack: 1, contractBonus: 0 },
});

auto.setTimeScale(4);
const events = [];
auto.onEvent((event) => events.push(event));
for (let i = 0; i < 900; i += 1) auto.update(0.05);

assert(events.some((event) => event.type === 'forklift_transfer'), 'forklift must actually move inbound cargo');
assert(events.some((event) => event.type === 'agv_transfer'), 'AGV must actually move rack cargo toward packing');
assert(events.some((event) => event.type === 'sorter_transfer'), 'sorter must actually ship packed cargo');
const shipments = events.filter((event) => event.type === 'shipment');
assert(shipments.length > 0, 'automation chain must produce real shipments');
assert(shipments.some((event) => event.source === 'sorter'), 'sorter must own at least one real shipment event');
const expectedUnitRevenue = currentUnitRevenue(auto.state.upgrades);
assert(shipments.every((event) => event.value === expectedUnitRevenue), 'shipment revenue must be owned by the simulation domain');
assert(auto.state.money > 100000000, 'automation shipments must add commercial revenue to simulation money');

console.log('Capital Expansion v2 smoke OK');
