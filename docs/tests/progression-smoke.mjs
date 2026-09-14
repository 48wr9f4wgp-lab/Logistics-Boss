import { createSimulation } from '../src/sim.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 3, 'fresh save must use schema v3');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(fresh.state.workers.length === 3, 'Rank 1 starts with three workers');
assert(!fresh.setStaffingPlan('receiving').ok, 'Rank 1 cannot change crew plan');
assert(!fresh.purchaseFacility('bufferYard').ok, 'Rank 1 cannot build Rank 2 facilities');

const migrated = createSimulation({
  schema_version: 2,
  money: 20000,
  research: 20,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: { secondInbound: false, fastPickRack: false, highDensityRack: false, secondPack: false },
  shipped: 100,
  completedContracts: 4,
  milestoneAwarded: 100,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {},
  perks: {},
});
assert(migrated.state.schema_version === 3, 'runtime must migrate to schema v3');
assert(migrated.state.facilityRank === 2, 'v2 Warehouse must stay Rank 2');
assert(migrated.state.workers.length === 5, 'Rank 2 grants five-person base crew');
let crew = migrated.staffingSummary();
assert(crew.store === 2 && crew.pick === 2 && crew.ship === 1, 'balanced five-person crew must be 2/2/1');
assert(migrated.setStaffingPlan('shipping').ok, 'Rank 2 can choose a staffing plan');
crew = migrated.staffingSummary();
assert(crew.store === 1 && crew.pick === 2 && crew.ship === 2, 'shipping plan must move crew downstream');
assert(!migrated.setStaffingPlan('receiving').ok, 'crew reassignment must have a cooldown');

migrated.state.staffingCooldown = 0;
assert(migrated.purchaseFacility('bufferYard').ok, 'buffer yard must be buildable');
assert(migrated.inboundMax() === 24, 'buffer yard must raise inbound capacity to 24');
assert(!migrated.purchaseFacility('secondInbound').ok, 'intake zone must be mutually exclusive');
assert(migrated.purchaseFacility('fastPickRack').ok, 'fast rack must be buildable');
assert(!migrated.purchaseFacility('highDensityRack').ok, 'storage zone must be mutually exclusive');
const basePackTime = createSimulation({ ...migrated.serialize(), facilities: { ...migrated.state.facilities, fastPickRack: true, bufferYard: true, secondPack: false, fastPackCell: false } }).packTime();
assert(migrated.purchaseFacility('fastPackCell').ok, 'fast pack cell must be buildable');
assert(migrated.packCapacity() === 1, 'fast cell stays single-lane');
assert(migrated.packTime() < basePackTime, 'fast cell must materially reduce packing time');
assert(!migrated.purchaseFacility('secondPack').ok, 'packing zone must be mutually exclusive');

const roundTrip = createSimulation(migrated.serialize());
assert(roundTrip.state.schema_version === 3, 'serialized save must remain schema v3');
assert(roundTrip.state.staffingPlan === 'shipping', 'staffing plan must persist');
assert(roundTrip.state.facilities.bufferYard, 'new facility choice must persist');
assert(roundTrip.state.facilities.fastPackCell, 'packing choice must persist');
assert(roundTrip.staffingSummary().total >= 5, 'Rank 2 crew must survive save/load');

console.log('Rank 2 Systems Pass smoke OK');
