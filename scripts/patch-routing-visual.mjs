import fs from 'node:fs';

const path = new URL('../docs/src/scene.js', import.meta.url);
let source = fs.readFileSync(path, 'utf8');

function replaceOnce(label, from, to) {
  const count = source.split(from).length - 1;
  if (count !== 1) throw new Error(`${label}: expected exactly one anchor, found ${count}`);
  source = source.replace(from, to);
}

replaceOnce(
  'routing visual import',
  "import { createAsrsVisual } from './asrs-visual.js';\n",
  "import { createAsrsVisual } from './asrs-visual.js';\nimport { createRoutingVisual } from './routing-visual.js';\n"
);

replaceOnce(
  'routing visual create',
  `  const scene = new THREE.Scene();\n  const asrsVisual = createAsrsVisual(scene, sim);`,
  `  const scene = new THREE.Scene();\n  const asrsVisual = createAsrsVisual(scene, sim);\n  const routingVisual = createRoutingVisual(scene, sim);`
);

replaceOnce(
  'routing parcel color',
  `      if (b.phase === 'packing') c = 0xffbe4d;\n      else if (b.phase === 'packed' || b.phase === 'carried_ship') c = 0x66dc96;`,
  `      if (b.phase === 'packing') c = 0xffbe4d;\n      else if (b.phase === 'routing') c = 0x6fd8ff;\n      else if (b.phase === 'packed' || b.phase === 'carried_ship') c = 0x66dc96;`
);

replaceOnce(
  'routing flow mode',
  `    flowFloorGuide.visible = flowMode;\n    if (!flowMode) for (const line of flowLines.values()) line.visible = false;`,
  `    flowFloorGuide.visible = flowMode;\n    routingVisual.setFlowMode(flowMode);\n    if (!flowMode) for (const line of flowLines.values()) line.visible = false;`
);

replaceOnce(
  'routing visual update',
  `    updateAutomationVisuals(dt);\n    asrsVisual.update(dt);\n    updateTruckVisuals(dt);`,
  `    updateAutomationVisuals(dt);\n    asrsVisual.update(dt);\n    routingVisual.update(dt);\n    updateTruckVisuals(dt);`
);

fs.writeFileSync(path, source);
console.log('Routing visual scene patch applied');
