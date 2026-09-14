import { createSimulation } from '../src/sim.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 3, 'fresh save must use schema v3');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(!fresh.setStaffingPlan('picking').ok, 'Rank 1 must not reassign Warehouse crew');

const migrated = createSimulation({
  schema_version: 2,
  money: 20000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {},
  shipped: 0,
  completedContracts: 4,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {},
  perks: {},
});
assert(migrated.state.facilityRank === 2, 'schema v2 Warehouse must migrate');
assert(migrated.state.schema_version === 3, 'migrated runtime must use schema v3');
assert(migrated.state.workers.length === 5, 'Warehouse must use five-person crew');
assert(migrated.setStaffingPlan('picking').ok, 'picking plan must be selectable');
let crew = migrated.staffingSummary();
assert(crew.store === 1 && crew.pick === 3 && crew.ship === 1, 'picking plan must be 1/3/1');
migrated.state.staffingCooldown = 0;
assert(migrated.setStaffingPlan('dock').ok, 'dock plan must be selectable');
crew = migrated.staffingSummary();
assert(crew.store === 2 && crew.pick === 1 && crew.ship === 2, 'dock plan must be 2/1/2');

migrated.state.money = 20000;
assert(migrated.purchaseFacility('bufferYard').ok, 'buffer yard must be buildable');
assert(!migrated.purchaseFacility('secondInbound').ok, 'zone A choice must be exclusive');
assert(migrated.purchaseFacility('fastPickRack').ok, 'zone B choice must be buildable');
assert(migrated.purchaseFacility('fastPackCell').ok, 'zone C choice must be buildable');
assert(migrated.decisionImpact()?.type === 'fastPackCell', 'facility purchase must start impact observation');
const ready = migrated.fulfillmentReadiness();
assert(ready.zones === 3, 'three selected zones must count toward Fulfillment readiness');
assert(ready.score >= 1, 'zone completion must contribute to readiness');

const roundTrip = createSimulation(migrated.serialize());
assert(roundTrip.state.staffingPlan === 'dock', 'staffing plan must survive save/load');
assert(roundTrip.state.facilities.bufferYard, 'facility choice must survive save/load');
assert(roundTrip.fulfillmentReadiness().zones === 3, 'readiness zone count must survive save/load');
console.log('Progression Spine / Rank 2 Systems smoke OK');
