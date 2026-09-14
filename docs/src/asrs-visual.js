import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.186.0/build/three.module.js';

const GEO = new THREE.BoxGeometry(1, 1, 1);

function mat(color, roughness = 0.68, emissive = 0x000000, metalness = 0.2) {
  return new THREE.MeshStandardMaterial({ color, roughness, emissive, metalness });
}

function addBox(group, size, pos, material) {
  const mesh = new THREE.Mesh(GEO, material);
  mesh.scale.set(size[0], size[1], size[2]);
  mesh.position.set(pos[0], pos[1], pos[2]);
  group.add(mesh);
  return mesh;
}

function createAsrsModule(index) {
  const group = new THREE.Group();
  const steel = mat(0x41505b, 0.5, 0x000000, 0.42);
  const beam = mat(index % 2 ? 0x478fa8 : 0x3f809b, 0.52, 0x102c38, 0.28);
  const shelf = mat(0x596873, 0.72, 0x000000, 0.25);
  const parcel = mat(0xc89357, 0.82);

  const width = 2.2;
  const height = 4.25;
  for (const x of [-width / 2, width / 2]) {
    for (const z of [-0.68, 0.68]) addBox(group, [0.1, height, 0.1], [x, height / 2, z], steel);
  }
  for (const y of [0.55, 1.35, 2.15, 2.95, 3.75]) {
    for (const z of [-0.68, 0.68]) addBox(group, [width + 0.1, 0.08, 0.08], [0, y, z], beam);
    addBox(group, [width, 0.045, 1.28], [0, y - 0.03, 0], shelf);
  }

  for (let bay = 0; bay < 2; bay += 1) {
    for (let level = 0; level < 4; level += 1) {
      if ((bay + level + index) % 3 === 1) continue;
      const x = -0.53 + bay * 1.06;
      const y = 0.78 + level * 0.8;
      addBox(group, [0.72, 0.42, 0.52], [x, y, index % 2 ? -0.28 : 0.28], parcel);
    }
  }

  const aisle = new THREE.Group();
  const mast = addBox(aisle, [0.1, 4.05, 0.1], [0, 2.05, 0], mat(0x60717d, 0.42, 0x000000, 0.48));
  const carriage = addBox(aisle, [0.72, 0.12, 0.78], [0, 0.62, 0], mat(0x49b0cd, 0.4, 0x164756, 0.32));
  const shuttle = addBox(aisle, [0.52, 0.32, 0.48], [0, 0.84, 0], mat(0xd69b45, 0.58, 0x55330e, 0.08));
  const scanner = addBox(aisle, [0.48, 0.07, 0.07], [0, 1.08, -0.3], mat(0x86f2ff, 0.3, 0x5be5ff, 0.14));
  scanner.material.emissiveIntensity = 0.75;
  aisle.position.z = -0.05;
  group.add(aisle);

  const header = addBox(group, [2.45, 0.13, 1.55], [0, 4.22, 0], mat(0x33414b, 0.52, 0x102d39, 0.36));
  const beacon = addBox(group, [0.75, 0.06, 0.08], [0, 4.16, 0.79], mat(0x77efff, 0.32, 0x53deff, 0.12));
  beacon.material.emissiveIntensity = 0.65;

  group.position.set(-0.2 + index * 2.55, 0, -5.65 - index * 0.12);
  group.scale.setScalar(0.86);
  group.visible = false;
  group.userData = { aisle, mast, carriage, shuttle, scanner, beacon, header };
  return group;
}

export function createAsrsVisual(scene, sim) {
  const modules = [];
  for (let i = 0; i < 3; i += 1) {
    const module = createAsrsModule(i);
    scene.add(module);
    modules.push(module);
  }

  let clock = 0;
  let pulse = 0;
  let direction = 'store';

  sim.onEvent((event) => {
    if (event.type === 'asrs_store' || event.type === 'asrs_pick') {
      pulse = 1;
      direction = event.type === 'asrs_pick' ? 'pick' : 'store';
    }
  });

  function update(dt) {
    const level = Math.max(0, Math.min(3, Math.floor(Number(sim.state.upgrades.asrs || 0))));
    const scale = Math.max(0, Number(sim.state.timeScale) || 0);
    clock += Math.max(0, Number(dt) || 0) * scale;
    pulse = THREE.MathUtils.lerp(pulse, 0, Math.min(1, Math.max(0, Number(dt) || 0) * 3.2));

    modules.forEach((module, index) => {
      module.visible = index < level;
      if (!module.visible) return;
      const speed = 0.22 + level * 0.035;
      const phase = (clock * speed + index * 0.31) % 1;
      const lift = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
      const y = 0.62 + lift * 2.95;
      const sway = Math.sin((clock + index * 0.7) * 1.55) * 0.34;
      module.userData.carriage.position.y = y;
      module.userData.shuttle.position.y = y + 0.22;
      module.userData.scanner.position.y = y + 0.46;
      module.userData.carriage.position.x = sway;
      module.userData.shuttle.position.x = sway + (direction === 'pick' ? 0.18 : -0.18) * pulse;
      module.userData.scanner.position.x = sway;
      module.userData.scanner.material.emissiveIntensity = 0.65 + pulse * 1.8 + Math.sin((clock + index) * 7) * 0.12;
      module.userData.beacon.material.emissiveIntensity = 0.55 + pulse * 1.5;
    });
  }

  return { update };
}
