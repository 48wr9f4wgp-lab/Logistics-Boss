import { createSimulation } from '../src/sim.js';
import {
  CAPITAL_INVESTMENTS,
  commercialTierForAssets,
  currentUnitRevenue,
  investedCapital,
  nextInvestmentCost,
  totalAssetValue,
} from '../src/capital-model.js';
import './ergonomics-smoke.mjs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 3, 'fresh save must use schema v3');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(!fresh.setStaffingPlan('picking').ok, 'Rank 1 must not reassign Warehouse crew');

assert(CAPITAL_INVESTMENTS.rack.costs[0] === 1000, 'capital loop must offer an early rack investment');
assert(nextInvestmentCost(fresh.state.upgrades, 'rack') === 1000, 'fresh rack investment cost must be 1000');
assert(investedCapital(fresh.state.upgrades) === 0, 'fresh game must have zero equipment assets');
fresh.state.upgrades.rack = 1;
assert(investedCapital(fresh.state.upgrades) === 1000, 'rack level 1 must count toward equipment assets');
assert(totalAssetValue(650, fresh.state.upgrades) === 1650, 'total assets must include cash plus equipment assets');
fresh.state.upgrades.rack = 0;
assert(currentUnitRevenue(fresh.state.upgrades) === 120, 'fresh commercial value must remain 120 per shipment');
assert(commercialTierForAssets(8000).saleValue === 450, 'mechanized tier must raise shipment value to tuned pacing baseline');
assert(commercialTierForAssets(40000).saleValue === 1500, '40k commercial tier must support active capital pacing');
assert(commercialTierForAssets(200000).saleValue === 2600, '200k commercial tier must support active capital pacing');
assert(commercialTierForAssets(500000).saleValue === 6000, '500k commercial tier must bridge toward million-yen automation');
assert(commercialTierForAssets(1000000).saleValue > commercialTierForAssets(500000).saleValue, 'commercial value must continue increasing after one million assets');

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
console.log('Progression Spine / Capital Expansion smoke OK');
