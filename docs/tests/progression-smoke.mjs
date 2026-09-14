import { createSimulation } from '../src/sim.js';

const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 2, 'fresh save must use schema v2');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(fresh.state.logisticsRating === 0, 'fresh game rating must start at 0');
assert(!fresh.purchaseFacility('secondInbound').ok, 'Rank 1 must not build Rank 2 facilities');

const migrated = createSimulation({
  schema_version: 1,
  money: 10000,
  research: 0,
  shipped: 0,
  completedContracts: 4,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {},
  perks: {},
});
assert(migrated.state.logisticsRating === 8, 'schema v1 migration must preserve prior progression as rating');
assert(migrated.state.facilityRank === 2, 'rating 8 must unlock Warehouse');

migrated.state.money = 10000;
assert(migrated.purchaseFacility('fastPickRack').ok, 'Fast Pick Rack must be buildable at Rank 2');
assert(!migrated.purchaseFacility('highDensityRack').ok, 'rack strategy must be mutually exclusive');
assert(migrated.purchaseFacility('secondPack').ok, 'Second Pack Line must be buildable');
assert(migrated.packCapacity() === 2, 'Second Pack Line must raise concurrent packing capacity to 2');
assert(migrated.purchaseFacility('secondInbound').ok, 'Second Inbound must be buildable');
assert(migrated.inboundMax() === 16, 'Second Inbound must raise inbound capacity from 10 to 16');

const roundTrip = createSimulation(migrated.serialize());
assert(roundTrip.state.schema_version === 2, 'serialized save must remain schema v2');
assert(roundTrip.state.facilities.fastPickRack, 'facility state must persist');
assert(roundTrip.state.facilities.secondPack, 'Second Pack state must persist');
assert(roundTrip.packCapacity() === 2, 'packing capacity must survive save/load');

console.log('Progression Spine Phase 1 smoke OK');
