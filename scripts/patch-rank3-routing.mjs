import fs from 'node:fs';

const path = new URL('../docs/src/sim.js', import.meta.url);
let source = fs.readFileSync(path, 'utf8');

function replaceOnce(label, from, to) {
  const count = source.split(from).length - 1;
  if (count !== 1) throw new Error(`${label}: expected exactly one anchor, found ${count}`);
  source = source.replace(from, to);
}

replaceOnce(
  'routing model import',
  "import { RANK3_NAME, rank3ReadinessFromState } from './rank3-model.js';\n",
  "import { RANK3_NAME, rank3ReadinessFromState } from './rank3-model.js';\nimport { ROUTING_PACKAGES, isRoutingMode, routingPackage, routingRevenue } from './routing-model.js';\n"
);

replaceOnce(
  'routing position constant',
  "  packed: { x: 3.1, z: -1.25 },\n  outbound: { x: 6.0, z: -3.4 },",
  "  packed: { x: 3.1, z: -1.25 },\n  routing: { x: 5.25, z: -2.45 },\n  outbound: { x: 6.0, z: -3.4 },"
);

replaceOnce(
  'routing position helper',
  `function packedPosition(index) {\n  return { x: 2.75 + (index % 3) * 0.55, y: 0.3, z: -1.45 - Math.floor(index / 3) * 0.58 };\n}\n`,
  `function packedPosition(index) {\n  return { x: 2.75 + (index % 3) * 0.55, y: 0.3, z: -1.45 - Math.floor(index / 3) * 0.58 };\n}\n\nfunction routingPosition(index) {\n  return { x: 4.85 + (index % 3) * 0.42, y: 0.3, z: -2.2 - Math.floor(index / 3) * 0.48 };\n}\n`
);

replaceOnce(
  'routing timers and revenue history',
  `  let saveDirty = false;\n  let simClock = 0;\n  const shipmentTimes = [];`,
  `  let saveDirty = false;\n  let simClock = 0;\n  let routingDispatchTimer = 0;\n  const shipmentTimes = [];\n  const shipmentRevenue = [];`
);

replaceOnce(
  'routing state and revenue metric',
  `    policy: 'balanced',\n    timeScale: 1,`,
  `    policy: 'balanced',\n    routingMode: 'balanced',\n    timeScale: 1,`
);
replaceOnce(
  'revenue metric state',
  `    metrics: { perMinute: 0 },`,
  `    metrics: { perMinute: 0, revenuePerMinute: 0 },`
);

replaceOnce(
  'routing normalization',
  `  function normalizePackedPositions() {\n    const packed = state.boxes.filter((box) => box.phase === 'packed' && !box.reservedBy);\n    packed.forEach((box, index) => Object.assign(box, packedPosition(index)));\n  }\n`,
  `  function normalizePackedPositions() {\n    const packed = state.boxes.filter((box) => box.phase === 'packed' && !box.reservedBy);\n    packed.forEach((box, index) => Object.assign(box, packedPosition(index)));\n  }\n\n  function normalizeRoutingPositions() {\n    const routing = state.boxes.filter((box) => box.phase === 'routing' && !box.reservedBy);\n    routing.forEach((box, index) => Object.assign(box, routingPosition(index)));\n  }\n`
);

replaceOnce(
  'packed counts include routing',
  `      else if (box.phase === 'packed' || box.phase === 'carried_ship') packed += 1;`,
  `      else if (box.phase === 'packed' || box.phase === 'carried_ship' || box.phase === 'routing') packed += 1;`
);
replaceOnce(
  'in process orders include routing',
  `      if (['carried_pick', 'waiting_pack', 'packing', 'packed', 'carried_ship'].includes(box.phase)) total += 1;`,
  `      if (['carried_pick', 'waiting_pack', 'packing', 'packed', 'carried_ship', 'routing'].includes(box.phase)) total += 1;`
);

replaceOnce(
  'complete shipment economics',
  `  function completeShipment(box, source = 'worker') {\n    const index = state.boxes.indexOf(box);\n    if (index >= 0) state.boxes.splice(index, 1);\n    state.ordersOpen = Math.max(0, state.ordersOpen - 1);\n    const unitRevenue = currentUnitRevenue(state.upgrades);\n    state.money += unitRevenue;\n    state.shipped += 1;\n    shipmentTimes.push(simClock);\n    emit('shipment', { text: \`出荷 +¥\${unitRevenue}\`, value: unitRevenue, source });\n    handleMilestone();\n    markDirty();\n  }`,
  `  function completeShipment(box, source = 'worker') {\n    const index = state.boxes.indexOf(box);\n    if (index >= 0) state.boxes.splice(index, 1);\n    state.ordersOpen = Math.max(0, state.ordersOpen - 1);\n    const baseRevenue = currentUnitRevenue(state.upgrades);\n    const routeMode = state.facilityRank >= 3 ? state.routingMode : 'balanced';\n    const unitRevenue = state.facilityRank >= 3 ? routingRevenue(baseRevenue, routeMode) : baseRevenue;\n    state.money += unitRevenue;\n    state.shipped += 1;\n    shipmentTimes.push(simClock);\n    shipmentRevenue.push({ at: simClock, value: unitRevenue });\n    emit('shipment', { text: \`出荷 +¥\${unitRevenue}\`, value: unitRevenue, source, routeMode });\n    handleMilestone();\n    markDirty();\n    return unitRevenue;\n  }\n\n  function stageForRouting(box, source = 'worker') {\n    if (state.facilityRank < 3) return completeShipment(box, source);\n    const hadQueue = state.boxes.some((item) => item.phase === 'routing');\n    box.phase = 'routing';\n    box.reservedBy = null;\n    box.carrierId = null;\n    box.rackSlot = null;\n    if (!hadQueue) routingDispatchTimer = routingPackage(state.routingMode).dispatchInterval;\n    normalizeRoutingPositions();\n    emit('routing_stage', { boxId: box.id, source, mode: state.routingMode, text: '出荷ステージへ搬送' });\n    return 0;\n  }`
);

replaceOnce(
  'worker route staging',
  `    } else if (kind === 'ship') {\n      completeShipment(box, 'worker');\n    }`,
  `    } else if (kind === 'ship') {\n      stageForRouting(box, 'worker');\n    }`
);

replaceOnce(
  'normalize routing after workers',
  `    normalizeInboundPositions();\n    normalizePackedPositions();\n  }`,
  `    normalizeInboundPositions();\n    normalizePackedPositions();\n    normalizeRoutingPositions();\n  }`
);

replaceOnce(
  'sorter route staging',
  `    const box = availableBox('packed');\n    if (!box || state.ordersOpen <= 0) return;\n    completeShipment(box, 'sorter');\n    emit('sorter_transfer', { text: '自動ソーター 1箱出荷', amount: 1 });\n  }`,
  `    const box = availableBox('packed');\n    if (!box || state.ordersOpen <= 0) return;\n    stageForRouting(box, 'sorter');\n    emit('sorter_transfer', { text: state.facilityRank >= 3 ? '自動ソーター 1箱ルーティングへ' : '自動ソーター 1箱出荷', amount: 1 });\n  }\n\n  function runRouting(dt) {\n    if (state.facilityRank < 3) return;\n    const queue = state.boxes.filter((box) => box.phase === 'routing');\n    if (!queue.length) {\n      routingDispatchTimer = 0;\n      return;\n    }\n    const route = routingPackage(state.routingMode);\n    routingDispatchTimer = Math.max(0, routingDispatchTimer - dt);\n    if (queue.length < route.minBatch || routingDispatchTimer > 0) return;\n    const amount = Math.min(route.batchSize, queue.length);\n    if (amount < route.minBatch) return;\n    let totalValue = 0;\n    for (const box of queue.slice(0, amount)) totalValue += completeShipment(box, \`routing:\${state.routingMode}\`);\n    routingDispatchTimer = route.dispatchInterval;\n    normalizeRoutingPositions();\n    emit('route_dispatch', { mode: state.routingMode, amount, value: totalValue, text: \`\${route.label} \${amount}箱出荷\` });\n  }`
);

replaceOnce(
  'rolling revenue metric',
  `  function updateMetrics() {\n    while (shipmentTimes.length && simClock - shipmentTimes[0] > 60) shipmentTimes.shift();\n    state.metrics.perMinute = shipmentTimes.length;`,
  `  function updateMetrics() {\n    while (shipmentTimes.length && simClock - shipmentTimes[0] > 60) shipmentTimes.shift();\n    while (shipmentRevenue.length && simClock - shipmentRevenue[0].at > 60) shipmentRevenue.shift();\n    state.metrics.perMinute = shipmentTimes.length;\n    state.metrics.revenuePerMinute = shipmentRevenue.reduce((sum, item) => sum + item.value, 0);`
);

replaceOnce(
  'routing update hook',
  `    runSorter(scaled);\n    updateWorkers(scaled);\n    updateMetrics();`,
  `    runSorter(scaled);\n    updateWorkers(scaled);\n    runRouting(scaled);\n    updateMetrics();`
);

replaceOnce(
  'routing mode setter anchor',
  `  function setPriority(kind, value) {`,
  `  function setRoutingMode(mode) {\n    if (state.facilityRank < 3) return { ok: false, reason: 'Fulfillment Centerで解禁' };\n    if (!isRoutingMode(mode)) return { ok: false, reason: '不明な配送ルート' };\n    if (state.routingMode === mode) return { ok: false, reason: '現在のルートです' };\n    state.routingMode = mode;\n    if (state.boxes.some((box) => box.phase === 'routing')) routingDispatchTimer = routingPackage(mode).dispatchInterval;\n    else routingDispatchTimer = 0;\n    emit('route_change', { mode, text: \`配送ルート: \${routingPackage(mode).label}\` });\n    markDirty();\n    return { ok: true, mode };\n  }\n\n  function setPriority(kind, value) {`
);

replaceOnce(
  'routing hydration',
  `    if (['balanced', 'inbound', 'ship'].includes(snapshot.policy)) state.policy = snapshot.policy;`,
  `    if (['balanced', 'inbound', 'ship'].includes(snapshot.policy)) state.policy = snapshot.policy;\n    if (isRoutingMode(snapshot.routingMode)) state.routingMode = snapshot.routingMode;`
);
replaceOnce(
  'routing serialization',
  `      policy: state.policy,\n      priorities: { ...state.priorities },`,
  `      policy: state.policy,\n      routingMode: state.routingMode,\n      priorities: { ...state.priorities },`
);
replaceOnce(
  'routing reset state',
  `    state.policy = 'balanced';\n    state.timeScale = 1;`,
  `    state.policy = 'balanced';\n    state.routingMode = 'balanced';\n    state.timeScale = 1;`
);
replaceOnce(
  'routing reset timers',
  `    nextBoxId = 1;\n    shipmentTimes.splice(0);\n    simClock = 0;`,
  `    nextBoxId = 1;\n    shipmentTimes.splice(0);\n    shipmentRevenue.splice(0);\n    routingDispatchTimer = 0;\n    simClock = 0;`
);
replaceOnce(
  'routing public api',
  `    setPolicy,\n    setPriority,`,
  `    setPolicy,\n    setRoutingMode,\n    routingInfo: ROUTING_PACKAGES,\n    setPriority,`
);

fs.writeFileSync(path, source);
console.log('Rank 3 routing simulation patch applied');
