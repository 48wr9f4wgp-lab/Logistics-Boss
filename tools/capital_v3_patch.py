from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path, old, new, count=1):
    p = ROOT / path
    text = p.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'anchor missing in {path}: {old[:120]!r}')
    text2 = text.replace(old, new, count)
    p.write_text(text2, encoding='utf-8')


# 1) Capital model: Truck Dock / Truck Waves + clear current -> next effects.
replace('docs/src/capital-model.js', """  hall: {
    key: 'hall',
    upgrade: 'hall',
    label: '物流ホール拡張',
    short: '敷地',
    costs: [300000, 2500000, 20000000],
    unlockAssets: 200000,
    effect: '保管容量 +8箱 / 入荷上限 +4箱 / 3Dホール棟を増設',
    emphasis: '建物そのものを拡張し、受入・保管余力を増やす',
  },
};""", """  hall: {
    key: 'hall',
    upgrade: 'hall',
    label: '物流ホール拡張',
    short: '敷地',
    costs: [300000, 2500000, 20000000],
    unlockAssets: 200000,
    effect: '保管容量 +8箱 / 入荷上限 +4箱 / 3Dホール棟を増設',
    emphasis: '建物そのものを拡張し、受入・保管余力を増やす',
  },
  truckDock: {
    key: 'truckDock',
    upgrade: 'truckDock',
    label: 'トラックドック',
    short: '幹線入荷',
    costs: [650000, 5000000, 40000000],
    unlockAssets: 500000,
    effect: '連続入荷をトラック波動へ変更 / ドック・トラックを3D表示',
    emphasis: 'まとまった荷量を受け、ドック能力と倉庫内処理の差を経営する',
  },
};""")

replace('docs/src/capital-model.js', """export function sorterIntervalForLevel(level) {
  if (!level) return Infinity;
  return Math.max(1.6, 4.8 - Math.max(1, level) * 0.8);
}

export function formatInvestmentEffect""", """export function sorterIntervalForLevel(level) {
  if (!level) return Infinity;
  return Math.max(1.6, 4.8 - Math.max(1, level) * 0.8);
}

export function truckWaveSizeForLevel(level) {
  if (!level) return 0;
  return [0, 10, 12, 15][Math.min(3, Math.max(1, Math.floor(level)))] || 10;
}

export function truckWaveIntervalForLevel(level) {
  if (!level) return Infinity;
  return [Infinity, 28, 24, 20][Math.min(3, Math.max(1, Math.floor(level)))] || 28;
}

export function truckUnloadIntervalForLevel(level) {
  if (!level) return Infinity;
  return [Infinity, 0.75, 0.55, 0.4][Math.min(3, Math.max(1, Math.floor(level)))] || 0.75;
}

export function formatInvestmentEffect""")

replace('docs/src/capital-model.js', """  if (key === 'hall') return `ホール +${level}棟 / 保管 +${level * 8}箱 / 入荷上限 +${level * 4}箱`;
  return '';""", """  if (key === 'hall') return `ホール +${level}棟 / 保管 +${level * 8}箱 / 入荷上限 +${level * 4}箱`;
  if (key === 'truckDock') return `${truckWaveSizeForLevel(level)}箱/便 · 約${truckWaveIntervalForLevel(level)}秒周期 · 荷下ろし${truckUnloadIntervalForLevel(level).toFixed(2)}秒/箱`;
  return '';""")

# 2) Capital card: show current state and what the next purchase changes to.
replace('docs/src/capital.js', """      if (!unlocked) {
        button.innerHTML = `<span class="capitalLevel">CAPITAL</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>投資総額 ${yen(def.unlockAssets)} で解禁</em><b>LOCKED</b>`;
      } else {
        button.innerHTML = `<span class="capitalLevel">Lv.${level}/${def.costs.length}</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>${maxed ? '最大段階' : formatInvestmentEffect(key, level + 1)}</em><b>${maxed ? 'MAX' : yen(cost)}</b>`;
      }""", """      if (!unlocked) {
        button.innerHTML = `<span class="capitalLevel">CAPITAL</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>投資総額 ${yen(def.unlockAssets)} で解禁</em><b>LOCKED</b>`;
      } else {
        const currentEffect = level > 0 ? formatInvestmentEffect(key, level) : '未導入';
        const nextEffect = maxed ? null : formatInvestmentEffect(key, level + 1);
        const effectLine = maxed ? `現在 ${currentEffect} / 最大段階` : `現在 ${currentEffect} → 次 ${nextEffect}`;
        button.innerHTML = `<span class="capitalLevel">Lv.${level}/${def.costs.length}</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>${effectLine}</em><b>${maxed ? 'MAX' : yen(cost)}</b>`;
      }""")

# 3) Simulation-domain truck waves.
replace('docs/src/sim.js', """  sorterIntervalForLevel,
} from './capital-model.js';""", """  sorterIntervalForLevel,
  truckUnloadIntervalForLevel,
  truckWaveIntervalForLevel,
  truckWaveSizeForLevel,
} from './capital-model.js';""")

replace('docs/src/sim.js', """  sorter: { label: '自動ソーター', max: 4, baseCost: 90000 },
  hall: { label: '物流ホール拡張', max: 3, baseCost: 300000 },
};""", """  sorter: { label: '自動ソーター', max: 4, baseCost: 90000 },
  hall: { label: '物流ホール拡張', max: 3, baseCost: 300000 },
  truckDock: { label: 'トラックドック', max: 3, baseCost: 650000 },
};""")

replace('docs/src/sim.js', """  let sorterTimer = 0;
  let overflowCooldown = 0;""", """  let sorterTimer = 0;
  let truckWaveTimer = 9;
  let truckUnloadTimer = 0;
  let overflowCooldown = 0;""")

replace('docs/src/sim.js', """    upgrades: { worker: 0, speed: 0, rack: 0, pack: 0, conveyor: 0, forklift: 0, agv: 0, sorter: 0, hall: 0 },
    perks:""", """    upgrades: { worker: 0, speed: 0, rack: 0, pack: 0, conveyor: 0, forklift: 0, agv: 0, sorter: 0, hall: 0, truckDock: 0 },
    truckWave: { phase: 'away', progress: 0, cargo: 0, waveSize: 0, trip: 0 },
    perks:""")

replace('docs/src/sim.js', """  function inboundMax() {
    const hallBonus = (state.upgrades.hall || 0) * 4;
    if (state.facilities.bufferYard) return BASE.inboundMax + 14 + hallBonus;
    return BASE.inboundMax + (state.facilities.secondInbound ? 6 : 0) + hallBonus;
  }""", """  function inboundMax() {
    const hallBonus = (state.upgrades.hall || 0) * 4;
    const truckDockBonus = (state.upgrades.truckDock || 0) * 2;
    if (state.facilities.bufferYard) return BASE.inboundMax + 14 + hallBonus + truckDockBonus;
    return BASE.inboundMax + (state.facilities.secondInbound ? 6 : 0) + hallBonus + truckDockBonus;
  }""")

replace('docs/src/sim.js', """  function sorterInterval() {
    return sorterIntervalForLevel(state.upgrades.sorter);
  }

  function upgradeCost""", """  function sorterInterval() {
    return sorterIntervalForLevel(state.upgrades.sorter);
  }

  function truckWaveInterval() {
    return truckWaveIntervalForLevel(state.upgrades.truckDock);
  }

  function truckWaveSize() {
    return truckWaveSizeForLevel(state.upgrades.truckDock);
  }

  function truckUnloadInterval() {
    return truckUnloadIntervalForLevel(state.upgrades.truckDock);
  }

  function upgradeCost""")

replace('docs/src/sim.js', """  function spawnInbound() {
    const current = counts().inbound;""", """  function spawnInbound(source = 'ambient') {
    const current = counts().inbound;""")
replace('docs/src/sim.js', """    emit('inbound', { boxId: box.id });
    return true;""", """    emit('inbound', { boxId: box.id, source });
    return true;""", 1)

replace('docs/src/sim.js', """  function orderInterval() {
    return BASE.orderInterval;
  }

  function updateSpawners(dt) {
    inboundTimer -= dt;
    orderTimer -= dt;
    overflowCooldown -= dt;
    if (inboundTimer <= 0) {
      inboundTimer += inboundInterval();
      spawnInbound();
    }
    if (orderTimer <= 0) {""", """  function orderInterval() {
    return BASE.orderInterval;
  }

  function startTruckWave() {
    const waveSize = truckWaveSize();
    if (!waveSize) return;
    state.truckWave.phase = 'approach';
    state.truckWave.progress = 0;
    state.truckWave.cargo = waveSize;
    state.truckWave.waveSize = waveSize;
    state.truckWave.trip += 1;
    emit('truck_approach', { amount: waveSize, trip: state.truckWave.trip, text: `入荷トラック ${waveSize}箱 接近` });
  }

  function updateTruckWave(dt) {
    const level = state.upgrades.truckDock || 0;
    if (!level) {
      state.truckWave.phase = 'away';
      state.truckWave.progress = 0;
      state.truckWave.cargo = 0;
      return;
    }
    const wave = state.truckWave;
    if (wave.phase === 'away') {
      truckWaveTimer -= dt;
      if (truckWaveTimer <= 0) startTruckWave();
      return;
    }
    if (wave.phase === 'approach') {
      wave.progress = Math.min(1, wave.progress + dt / 2.5);
      if (wave.progress >= 1) {
        wave.phase = 'unload';
        wave.progress = 0;
        truckUnloadTimer = 0;
        emit('truck_arrive', { amount: wave.waveSize, trip: wave.trip, text: `トラック到着 ${wave.waveSize}箱` });
      }
      return;
    }
    if (wave.phase === 'unload') {
      truckUnloadTimer -= dt;
      if (wave.cargo > 0 && truckUnloadTimer <= 0) {
        if (spawnInbound('truck')) {
          wave.cargo -= 1;
          wave.progress = wave.waveSize > 0 ? 1 - wave.cargo / wave.waveSize : 1;
          truckUnloadTimer += truckUnloadInterval();
          emit('truck_unload', { amount: 1, remaining: wave.cargo, text: `トラック荷下ろし 残${wave.cargo}箱` });
        } else {
          truckUnloadTimer = 0.45;
        }
      }
      if (wave.cargo <= 0) {
        wave.phase = 'depart';
        wave.progress = 0;
        emit('truck_depart', { trip: wave.trip, text: '入荷トラック出発' });
      }
      return;
    }
    if (wave.phase === 'depart') {
      wave.progress = Math.min(1, wave.progress + dt / 2.2);
      if (wave.progress >= 1) {
        wave.phase = 'away';
        wave.progress = 0;
        wave.waveSize = 0;
        truckWaveTimer = truckWaveInterval();
        emit('truck_cycle_complete', { trip: wave.trip });
      }
    }
  }

  function updateSpawners(dt) {
    orderTimer -= dt;
    overflowCooldown -= dt;
    if ((state.upgrades.truckDock || 0) > 0) {
      updateTruckWave(dt);
    } else {
      inboundTimer -= dt;
      if (inboundTimer <= 0) {
        inboundTimer += inboundInterval();
        spawnInbound();
      }
    }
    if (orderTimer <= 0) {""")

replace('docs/src/sim.js', """    sorterTimer = 0;
    emit('upgrade',""", """    sorterTimer = 0;
    if (type === 'truckDock') {
      truckWaveTimer = 2.5;
      state.truckWave = { phase: 'away', progress: 0, cargo: 0, waveSize: 0, trip: state.truckWave?.trip || 0 };
    }
    emit('upgrade',""", 1)

replace('docs/src/sim.js', """    sorterTimer = 0;
    emit('capital_investment',""", """    sorterTimer = 0;
    if (type === 'truckDock') {
      truckWaveTimer = 2.5;
      state.truckWave = { phase: 'away', progress: 0, cargo: 0, waveSize: 0, trip: state.truckWave?.trip || 0 };
    }
    emit('capital_investment',""", 1)

replace('docs/src/sim.js', """    state.upgrades = { worker: 0, speed: 0, rack: 0, pack: 0, conveyor: 0, forklift: 0, agv: 0, sorter: 0, hall: 0 };
    state.perks""", """    state.upgrades = { worker: 0, speed: 0, rack: 0, pack: 0, conveyor: 0, forklift: 0, agv: 0, sorter: 0, hall: 0, truckDock: 0 };
    state.truckWave = { phase: 'away', progress: 0, cargo: 0, waveSize: 0, trip: 0 };
    state.perks""")

replace('docs/src/sim.js', """    sorterTimer = 0;
    offerCooldown = 0;""", """    sorterTimer = 0;
    truckWaveTimer = 9;
    truckUnloadTimer = 0;
    offerCooldown = 0;""")

replace('docs/src/sim.js', """    sorterInterval,
    facilityRankName,""", """    sorterInterval,
    truckWaveInterval,
    truckWaveSize,
    truckUnloadInterval,
    facilityRankName,""")

# 4) Visible 3D truck/docks and traffic motion.
replace('docs/src/scene.js', """function workerMesh(index) {""", """function truckDockBay(index) {
  const group = new THREE.Group();
  const slab = addBox(group, 1.55, 0.08, 2.45, 0, 0.04, 0, index % 2 ? 0x34566a : 0x3e6275, 0.9);
  const steel = 0x4c5860;
  addBox(group, 0.12, 1.7, 0.12, -0.62, 0.85, -0.72, steel, 0.62, 0, 0.3);
  addBox(group, 0.12, 1.7, 0.12, 0.62, 0.85, -0.72, steel, 0.62, 0, 0.3);
  addBox(group, 1.36, 0.12, 0.12, 0, 1.62, -0.72, steel, 0.62, 0, 0.3);
  const lamp = addBox(group, 0.72, 0.05, 0.07, 0, 1.48, -0.66, 0x84e8ff, 0.42, 0x55d7ff);
  lamp.material.emissiveIntensity = 0.6;
  const stripe = hazardStripe(1.26, 0.15, 0x75dfff);
  stripe.position.set(0, 0.01, 0.86);
  group.add(stripe);
  group.position.set(-6.15 + index * 1.72, 0, 5.95);
  group.visible = false;
  group.userData = { slab, lamp };
  return group;
}

function truckUnit() {
  const group = new THREE.Group();
  const trailer = addBox(group, 1.28, 1.38, 2.7, 0, 0.86, 0.72, 0xd5dde1, 0.72, 0x000000, 0.08);
  addBox(group, 1.18, 0.12, 2.55, 0, 0.2, 0.72, 0x56616a, 0.62, 0, 0.3);
  const cab = addBox(group, 1.18, 1.08, 1.0, 0, 0.72, -1.18, 0x2f82a7, 0.55, 0x0b2d3a, 0.14);
  const glass = addBox(group, 0.92, 0.38, 0.05, 0, 0.93, -1.7, 0x7bdcf1, 0.3, 0x43bad6, 0.08);
  glass.material.emissiveIntensity = 0.18;
  for (const z of [-1.2, 0.1, 1.3]) {
    for (const x of [-0.58, 0.58]) {
      const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.2, 0.14, 10), mat(0x20262a, 0.9));
      wheel.rotation.z = Math.PI / 2;
      wheel.position.set(x, 0.24, z);
      group.add(wheel);
    }
  }
  const tail = addBox(group, 0.64, 0.08, 0.05, 0, 0.45, 2.08, 0x71efad, 0.38, 0x58dd98);
  tail.material.emissiveIntensity = 0.7;
  group.rotation.y = Math.PI;
  group.scale.setScalar(0.82);
  group.visible = false;
  group.userData = { trailer, cab, tail };
  return group;
}

function workerMesh(index) {""")

replace('docs/src/scene.js', """  const sorters = [];
  for (let i = 0; i < 4; i += 1) {
    const unit = sorterModule(i);
    scene.add(unit);
    sorters.push(unit);
  }

  const annexes = [];""", """  const sorters = [];
  for (let i = 0; i < 4; i += 1) {
    const unit = sorterModule(i);
    scene.add(unit);
    sorters.push(unit);
  }

  const truckDockBays = [];
  for (let i = 0; i < 3; i += 1) {
    const bay = truckDockBay(i);
    scene.add(bay);
    truckDockBays.push(bay);
  }
  const truck = truckUnit();
  scene.add(truck);

  const annexes = [];""")

replace('docs/src/scene.js', """  let sorterPulse = 0;

  const physics""", """  let sorterPulse = 0;
  let truckPulse = 0;

  const physics""")

replace('docs/src/scene.js', """    if (event.type === 'sorter_transfer') sorterPulse = 1;
    if (event.type === 'shipment') {""", """    if (event.type === 'sorter_transfer') sorterPulse = 1;
    if (event.type === 'truck_arrive') truckPulse = 1;
    if (event.type === 'truck_unload') truckPulse = Math.max(truckPulse, 0.45);
    if (event.type === 'truck_depart') truckPulse = Math.max(truckPulse, 0.7);
    if (event.type === 'shipment') {""")

replace('docs/src/scene.js', """    sorters.forEach((unit, i) => { unit.visible = i < (u.sorter || 0); });
    gates.forEach""", """    sorters.forEach((unit, i) => { unit.visible = i < (u.sorter || 0); });
    truckDockBays.forEach((bay, i) => { bay.visible = i < (u.truckDock || 0); });
    truck.visible = (u.truckDock || 0) > 0 && sim.state.truckWave?.phase !== 'away';
    gates.forEach""")

replace('docs/src/scene.js', """  function heat(material, ratio) {""", """  function updateTruckVisuals(dt) {
    truckPulse = THREE.MathUtils.lerp(truckPulse, 0, Math.min(1, dt * 2.2));
    const wave = sim.state.truckWave || { phase: 'away', progress: 0, cargo: 0, waveSize: 0 };
    if (!truck.visible) return;
    const p = THREE.MathUtils.clamp(Number(wave.progress) || 0, 0, 1);
    const roadZ = 8.45;
    const dockZ = 6.78;
    let z = dockZ;
    if (wave.phase === 'approach') z = THREE.MathUtils.lerp(roadZ, dockZ, p);
    else if (wave.phase === 'depart') z = THREE.MathUtils.lerp(dockZ, roadZ, p);
    truck.position.set(-6.15, 0.02 + truckPulse * 0.02, z);
    const loadRatio = wave.waveSize > 0 ? wave.cargo / wave.waveSize : 0;
    truck.userData.trailer.material.emissive.setHex(loadRatio > 0.55 ? 0x24465a : 0x173323);
    truck.userData.trailer.material.emissiveIntensity = 0.05 + loadRatio * 0.12 + truckPulse * 0.18;
    truck.userData.tail.material.emissiveIntensity = 0.55 + truckPulse * 1.2;
    truckDockBays.forEach((bay, i) => {
      if (!bay.visible) return;
      bay.userData.lamp.material.emissiveIntensity = 0.5 + (i === 0 ? truckPulse * 1.2 : 0);
    });
  }

  function heat(material, ratio) {""")

replace('docs/src/scene.js', """    updateAutomationVisuals(dt);
    updateFlowFloorGuide(dt);""", """    updateAutomationVisuals(dt);
    updateTruckVisuals(dt);
    updateFlowFloorGuide(dt);""")

# 5) Regression test for the new logistics wave behavior.
(ROOT / 'docs/tests/capital-v3-smoke.mjs').write_text(r'''import { createSimulation } from '../src/sim.js';
import {
  CAPITAL_INVESTMENTS,
  investmentUnlocked,
  nextInvestmentCost,
  truckUnloadIntervalForLevel,
  truckWaveIntervalForLevel,
  truckWaveSizeForLevel,
} from '../src/capital-model.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

assert(CAPITAL_INVESTMENTS.truckDock.costs[0] === 650000, 'truck dock must be a property/logistics-scale investment');
assert(!investmentUnlocked({}, 'truckDock'), 'truck dock must not unlock at game start');
assert(truckWaveSizeForLevel(1) === 10 && truckWaveSizeForLevel(3) === 15, 'truck wave size must scale by dock level');
assert(truckWaveIntervalForLevel(3) < truckWaveIntervalForLevel(1), 'higher dock levels must increase truck frequency');
assert(truckUnloadIntervalForLevel(3) < truckUnloadIntervalForLevel(1), 'higher dock levels must unload faster');

const sim = createSimulation({
  schema_version: 3,
  money: 100000000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: { bufferYard: true, highDensityRack: true, secondPack: true },
  staffingPlan: 'receiving',
  shipped: 0,
  completedContracts: 8,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 5, pick: 3, ship: 3 },
  upgrades: { worker: 5, speed: 5, rack: 4, pack: 5, conveyor: 4, forklift: 4, agv: 4, sorter: 4, hall: 2, truckDock: 0 },
  perks: {},
});

const cost = nextInvestmentCost(sim.state.upgrades, 'truckDock');
const bought = sim.purchaseCapitalUpgrade('truckDock', cost);
assert(bought.ok && bought.level === 1, 'truck dock level 1 must purchase through simulation domain');
assert(sim.state.upgrades.truckDock === 1, 'truck dock level must be stored in upgrades');
assert(sim.inboundMax() >= 2, 'truck dock must contribute receiving headroom');

const events = [];
sim.onEvent((event) => events.push(event));
sim.setTimeScale(4);
for (let i = 0; i < 600; i += 1) sim.update(0.05);

assert(events.some((event) => event.type === 'truck_approach'), 'truck must visibly begin an approach cycle');
assert(events.some((event) => event.type === 'truck_arrive'), 'truck must reach the dock');
assert(events.some((event) => event.type === 'truck_unload'), 'truck must unload real inbound parcels');
assert(events.some((event) => event.type === 'inbound' && event.source === 'truck'), 'truck unload must feed the real inbound queue');
assert(events.some((event) => event.type === 'truck_depart'), 'truck must leave after unloading');

const saved = sim.serialize();
const reloaded = createSimulation(saved);
assert(reloaded.state.upgrades.truckDock === 1, 'truck dock investment must survive save/load');

console.log('Capital v2 Phase 3 truck-wave smoke OK');
''', encoding='utf-8')

# 6) CI locks.
replace('.github/workflows/qa.yml', """          test -f docs/tests/capital-v2-smoke.mjs
          test -f GDD_LOGISTICS_BOSS.md""", """          test -f docs/tests/capital-v2-smoke.mjs
          test -f docs/tests/capital-v3-smoke.mjs
          test -f GDD_LOGISTICS_BOSS.md""")
replace('.github/workflows/qa.yml', """          node --check docs/tests/capital-v2-smoke.mjs
          echo "JavaScript syntax OK"""", """          node --check docs/tests/capital-v2-smoke.mjs
          node --check docs/tests/capital-v3-smoke.mjs
          echo "JavaScript syntax OK""")
replace('.github/workflows/qa.yml', """          node docs/tests/capital-v2-smoke.mjs
          echo "Capital Expansion v2 contract OK"""", """          node docs/tests/capital-v2-smoke.mjs
          echo "Capital Expansion v2 contract OK"

      - name: Truck Dock / Waves Phase 3 contract
        shell: bash
        run: |
          set -euo pipefail
          grep -Fq 'truckDock:' docs/src/capital-model.js
          grep -Fq "truckDock: { label: 'トラックドック'" docs/src/sim.js
          grep -Fq "function startTruckWave()" docs/src/sim.js
          grep -Fq "function updateTruckWave(dt)" docs/src/sim.js
          grep -Fq "event.type === 'truck_arrive'" docs/src/scene.js
          grep -Fq "function truckUnit()" docs/src/scene.js
          grep -Fq "function truckDockBay(index)" docs/src/scene.js
          grep -Fq '現在 ${currentEffect} → 次 ${nextEffect}' docs/src/capital.js
          node docs/tests/capital-v3-smoke.mjs
          echo "Truck Dock / Waves Phase 3 contract OK""")

# 7) Title-specific spec append.
p = ROOT / 'CAPITAL_EXPANSION_V2.md'
text = p.read_text(encoding='utf-8')
if '## Phase 3 — Truck Dock / Truck Waves' not in text:
    text += '''\n\n## Phase 3 — Truck Dock / Truck Waves\n\nPhase 3 converts late-game inbound flow from a smooth drip into visible truck arrivals.\n\n- Capital card: `トラックドック`\n- Costs: `¥650,000 / ¥5,000,000 / ¥40,000,000`\n- Unlock: investment total `¥500,000`\n- Level 1–3 add visible 3D dock bays and a real truck arrival/unload/depart cycle.\n- Once installed, inbound supply comes in waves instead of the old continuous cadence.\n- Higher levels increase boxes per truck and arrival frequency while reducing unload time per box.\n- Trucks unload into the same authoritative inbound parcel queue, so insufficient receiving/rack/picking/packing capacity creates a new bottleneck instead of being bypassed.\n- Existing 25-second Capital Before/After measurement applies without forcing a prescribed solution.\n\nFour-condition gate:\n1. Visible 3D dock/truck change.\n2. Real logistics behavior changes from drip to waves.\n3. Before/After remains measurable.\n4. More dock capacity can expose internal bottlenecks.\n'''
    p.write_text(text, encoding='utf-8')

print('Capital v2 Phase 3 patch applied')
