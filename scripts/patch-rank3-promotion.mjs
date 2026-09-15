import fs from 'node:fs';

const path = new URL('../docs/src/sim.js', import.meta.url);
let source = fs.readFileSync(path, 'utf8');

function replaceOnce(label, from, to) {
  const count = source.split(from).length - 1;
  if (count !== 1) throw new Error(`${label}: expected exactly one anchor, found ${count}`);
  source = source.replace(from, to);
}

replaceOnce(
  'rank3 model import',
  "} from './capital-model.js';\n",
  "} from './capital-model.js';\nimport { RANK3_NAME, rank3ReadinessFromState } from './rank3-model.js';\n"
);

replaceOnce(
  'facility rank table',
  "const FACILITY_RANKS = {\n  1: { name: 'Small Depot', rating: 0 },\n  2: { name: 'Warehouse', rating: 8 },\n};",
  "const FACILITY_RANKS = {\n  1: { name: 'Small Depot', rating: 0 },\n  2: { name: 'Warehouse', rating: 8 },\n  3: { name: RANK3_NAME, rating: null },\n};"
);

replaceOnce(
  'facility promotion',
  `  function updateFacilityRank() {\n    if (state.facilityRank < 2 && state.logisticsRating >= FACILITY_RANKS[2].rating) {\n      state.facilityRank = 2;\n      ensureWorkers();\n      applyStaffingPlan();\n      emit('rank_up', { rank: 2, name: facilityRankName(2), text: '施設ランクUP: Warehouse / 5人編成を解禁' });\n      markDirty();\n    }\n  }`,
  `  function updateFacilityRank() {\n    if (state.facilityRank < 2 && state.logisticsRating >= FACILITY_RANKS[2].rating) {\n      state.facilityRank = 2;\n      ensureWorkers();\n      applyStaffingPlan();\n      emit('rank_up', { rank: 2, name: facilityRankName(2), text: '施設ランクUP: Warehouse / 5人編成を解禁' });\n      markDirty();\n    }\n    if (state.facilityRank === 2 && fulfillmentReadiness().ready) {\n      state.facilityRank = 3;\n      emit('rank_up', { rank: 3, name: facilityRankName(3), text: '施設ランクUP: Fulfillment Center' });\n      markDirty();\n    }\n  }`
);

replaceOnce(
  'readiness implementation',
  `  function fulfillmentReadiness() {\n    const groups = ['intakeStrategy', 'rackStrategy', 'packStrategy'];\n    const zones = groups.filter((group) => Object.keys(FACILITY_INFO).some((key) => FACILITY_INFO[key].group === group && state.facilities[key])).length;\n    const contracts = Math.min(8, state.completedContracts);\n    const throughput = Math.min(6, state.metrics.perMinute);\n    const conditions = { zones: zones >= 3, contracts: state.completedContracts >= 8, throughput: state.metrics.perMinute >= 6 };\n    const score = Number(conditions.zones) + Number(conditions.contracts) + Number(conditions.throughput);\n    return { zones, contracts, throughput, conditions, score, ready: score === 3 };\n  }`,
  `  function fulfillmentReadiness() {\n    return rank3ReadinessFromState(state, FACILITY_INFO);\n  }`
);

replaceOnce(
  'promotion update hook',
  `    updateWorkers(scaled);\n    updateMetrics();\n    updateContract(scaled);`,
  `    updateWorkers(scaled);\n    updateMetrics();\n    updateFacilityRank();\n    updateContract(scaled);`
);

replaceOnce(
  'rank3 hydration',
  'state.facilityRank = clamp(Math.floor(snapshot.facilityRank), 1, 2);',
  'state.facilityRank = clamp(Math.floor(snapshot.facilityRank), 1, 3);'
);

fs.writeFileSync(path, source);
console.log('Rank 3 sim codemod applied');
