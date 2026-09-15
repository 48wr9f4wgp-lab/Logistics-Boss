import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(path, import.meta.url), 'utf8');
const main = read('../src/main.js');
const scene = read('../src/scene.js');
const routingUi = read('../src/routing.js');
const routingVisual = read('../src/routing-visual.js');
const routingModel = read('../src/routing-model.js');
const css = read('../routing.css');

assert.match(main, /bindCarrierRouting/);
assert.match(main, /routing\.update\(dt\)/);
assert.match(main, /routing\.render\(\)/);

assert.match(routingUi, /sim\.setRoutingMode\(mode\)/);
assert.match(routingUi, /25/);
assert.match(routingUi, /throughput/);
assert.match(routingUi, /packed/);
assert.match(routingUi, /orders/);
assert.match(routingUi, /revenuePerMinute/);
assert.match(routingUi, /Carrier Routing/);
assert.doesNotMatch(routingUi, /recommended|おすすめ|正解/);

assert.match(scene, /createRoutingVisual/);
assert.match(scene, /routingVisual\.update\(dt\)/);
assert.match(scene, /routingVisual\.setFlowMode\(flowMode\)/);
assert.match(scene, /b\.phase === 'routing'/);

assert.match(routingVisual, /event\.type === 'route_dispatch'/);
assert.match(routingVisual, /event\.type === 'route_change'/);
assert.match(routingVisual, /sim\.state\.facilityRank >= 3/);
assert.match(routingVisual, /ROUTING HUB/);
assert.doesNotMatch(routingVisual, /setInterval\(|setTimeout\(/, 'shipment movement must not be a timer-driven decorative loop');

assert.match(routingModel, /balanced/);
assert.match(routingModel, /express/);
assert.match(routingModel, /consolidated/);
assert.match(css, /carrierRoutingPanel/);
assert.match(css, /routingChoices/);

console.log('Rank 3 routing integration smoke passed');
