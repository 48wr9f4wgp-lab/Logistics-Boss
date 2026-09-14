import { createSimulation } from '../src/sim.js';
import {
  CAPITAL_INVESTMENTS,
  currentUnitRevenue,
  investedCapital,
  investmentUnlocked,
  nextInvestmentCost,
} from '../src/capital-model.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(CAPITAL_INVESTMENTS.workforce.costs[0] === 3500, 'workforce must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.forklift.costs[0] === 15000, 'forklift must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.agv.costs[0] === 40000, 'AGV must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.sorter.costs[0] === 90000, 'sorter must be a distinct capital category');
assert(CAPITAL_INVESTMENTS.hall.costs[0] === 300000, 'hall must be a distinct property-scale capital category');
assert(CAPITAL_INVESTMENTS.asrs.costs[0] === 1800000, 'ASRS must be a distinct high-bay automation category');
assert(CAPITAL_INVESTMENTS.asrs.unlockAssets === 1000000, 'ASRS must unlock at the million-yen capital scale');
assert(!investmentUnlocked({}, 'workforce'), 'workforce must be gated by early equipment assets');
assert(!investmentUnlocked({}, 'forklift'), 'forklift must be gated by equipment assets');
assert(investmentUnlocked({ rack: 1, pack: 1, speed: 1, conveyor: 1 }, 'forklift'), 'forklift must unlock once equipment assets reach its threshold');
assert(!investmentUnlocked({ rack: 1, pack: 1, speed: 1, conveyor: 1 }, 'agv'), 'AGV must remain locked at the first automation threshold');
assert(!investmentUnlocked({ hall: 1 }, 'asrs'), 'ASRS must remain locked below the million-yen capital threshold');

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
  upgrades: { worker: 0, speed: 5, rack: 4, pack: 5, conveyor: 4, forklift: 0, agv: 0, sorter: 0, hall: 0, truckDock: 0, asrs: 0 },
  perks: {},
});

const workersBefore = buyer.state.workers.length;
const workforceCost = nextInvestmentCost(buyer.state.upgrades, 'workforce');
const workforcePurchase = buyer.purchaseCapitalUpgrade('worker', workforceCost);
assert(workforcePurchase.ok && workforcePurchase.level === 1, 'capital workforce must hire one real worker');
assert(buyer.state.workers.length === workersBefore + 1, 'workforce investment must visibly add a simulation worker');

const rackBeforeHall = buyer.rackCapacity();
const inboundBeforeHall = buyer.inboundMax();
const hallCost = nextInvestmentCost(buyer.state.upgrades, 'hall');
const hallPurchase = buyer.purchaseCapitalUpgrade('hall', hallCost);
assert(hallPurchase.ok && hallPurchase.level === 1, 'hall level 1 must be purchasable through the simulation domain');
assert(buyer.rackCapacity() === rackBeforeHall + 8, 'hall must add real rack capacity');
assert(buyer.inboundMax() === inboundBeforeHall + 4, 'hall must add real receiving buffer capacity');

const rackBeforeAsrs = buyer.rackCapacity();
const asrsCost = nextInvestmentCost(buyer.state.upgrades, 'asrs');
const asrsPurchase = buyer.purchaseCapitalUpgrade('asrs', asrsCost);
assert(asrsPurchase.ok && asrsPurchase.level === 1, 'ASRS level 1 must be purchasable through the simulation domain');
assert(buyer.rackCapacity() === rackBeforeAsrs + 16, 'ASRS level 1 must add 16 real rack slots');

const cashBefore = buyer.state.money;
const forkliftCost = nextInvestmentCost(buyer.state.upgrades, 'forklift');
const purchase = buyer.purchaseCapitalUpgrade('forklift', forkliftCost);
assert(purchase.ok && purchase.level === 1, 'domain API must purchase forklift level 1');
assert(buyer.state.money === cashBefore - forkliftCost, 'capital purchase must deduct cash in simulation domain');
assert(buyer.state.upgrades.forklift === 1, 'capital purchase must update the simulation upgrade state');
const saved = buyer.serialize();
const reloaded = createSimulation(saved);
assert(reloaded.state.upgrades.worker === 1, 'workforce capital must survive save/load');
assert(reloaded.state.upgrades.hall === 1, 'hall capital must survive save/load');
assert(reloaded.state.upgrades.asrs === 1, 'ASRS capital must survive save/load');
assert(reloaded.state.upgrades.forklift === 1, 'Capital v2 upgrades must survive save/load');
assert(reloaded.rackCapacity() === buyer.rackCapacity(), 'hall and ASRS capacity must survive save/load');
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
  upgrades: { worker: 0, speed: 5, rack: 4, pack: 5, conveyor: 0, forklift: 4, agv: 4, sorter: 4, hall: 0, truckDock: 0, asrs: 0 },
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

const asrsAuto = createSimulation({
  schema_version: 3,
  money: 100000000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {},
  staffingPlan: 'balanced',
  shipped: 0,
  completedContracts: 12,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: { worker: 0, speed: 0, rack: 0, pack: 0, conveyor: 0, forklift: 0, agv: 0, sorter: 0, hall: 0, truckDock: 0, asrs: 3 },
  perks: {},
});
asrsAuto.state.ordersOpen = 20;
asrsAuto.setTimeScale(4);
const asrsEvents = [];
asrsAuto.onEvent((event) => asrsEvents.push(event));
for (let i = 0; i < 500; i += 1) asrsAuto.update(0.05);
assert(asrsEvents.some((event) => event.type === 'asrs_store'), 'ASRS must perform a real inbound-to-rack storage move');
assert(asrsEvents.some((event) => event.type === 'asrs_pick'), 'ASRS must perform a real rack-to-packing retrieval move');

console.log('Capital Expansion v2 smoke OK');
