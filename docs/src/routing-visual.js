import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.186.0/build/three.module.js';
import { POS } from './sim.js';
import { ROUTING_MODES, routingPackage } from './routing-model.js';

const MODE_COLORS = {
  balanced: 0x6fd8ff,
  express: 0xffc263,
  consolidated: 0x8ce3a5,
};

function material(color, emissive = 0x000000, transparent = false) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.68, metalness: 0.18, emissive, transparent, opacity: transparent ? 0.72 : 1 });
}

function box(group, sx, sy, sz, x, y, z, color, emissive = 0x000000) {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(1, 1, 1), material(color, emissive));
  mesh.scale.set(sx, sy, sz);
  mesh.position.set(x, y, z);
  group.add(mesh);
  return mesh;
}

function routeLabel(text, color) {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 96;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = 'rgba(5,12,17,.88)';
  ctx.fillRect(4, 10, 248, 76);
  ctx.strokeStyle = `#${color.toString(16).padStart(6, '0')}`;
  ctx.lineWidth = 5;
  ctx.strokeRect(5, 11, 246, 74);
  ctx.fillStyle = '#f4fbff';
  ctx.font = '900 34px -apple-system,BlinkMacSystemFont,sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, 128, 49);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(1.18, 0.44),
    new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false, side: THREE.DoubleSide })
  );
  return mesh;
}

function createLane(mode, index) {
  const def = routingPackage(mode);
  const color = MODE_COLORS[mode];
  const group = new THREE.Group();
  const x = (index - 1) * 1.18;

  const pad = box(group, 0.92, 0.055, 2.4, x, 0.034, -0.15, 0x273640);
  const stripe = box(group, 0.64, 0.025, 2.05, x, 0.074, -0.14, color, color);
  stripe.material.transparent = true;
  stripe.material.opacity = 0.28;
  stripe.material.emissiveIntensity = 0.25;

  const left = box(group, 0.08, 1.28, 0.08, x - 0.36, 0.64, -1.05, 0x45535d);
  const right = box(group, 0.08, 1.28, 0.08, x + 0.36, 0.64, -1.05, 0x45535d);
  const beam = box(group, 0.82, 0.08, 0.08, x, 1.24, -1.05, 0x45535d);
  const lamp = box(group, 0.46, 0.06, 0.08, x, 1.08, -1.01, color, color);
  lamp.material.emissiveIntensity = 0.45;

  const label = routeLabel(def.shortLabel, color);
  label.position.set(x, 1.55, -1.08);
  label.rotation.y = 0;
  group.add(label);

  const beacon = new THREE.Mesh(
    new THREE.RingGeometry(0.14, 0.2, 24),
    new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.35, side: THREE.DoubleSide, depthWrite: false })
  );
  beacon.rotation.x = -Math.PI / 2;
  beacon.position.set(x, 0.095, 0.72);
  group.add(beacon);

  group.userData = { mode, color, pad, stripe, lamp, beacon, left, right, beam };
  return group;
}

function createDispatchParcel(color, offset = 0) {
  const group = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(0.28, 0.22, 0.28), material(0xd9a467, color));
  body.material.emissiveIntensity = 0.12;
  group.add(body);
  const tape = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.225, 0.285), material(0xf2dbad));
  group.add(tape);
  group.userData = { life: 1, offset };
  return group;
}

export function createRoutingVisual(scene, sim) {
  const root = new THREE.Group();
  root.position.set(POS.routing.x + 0.35, 0, POS.routing.z - 1.9);
  root.visible = false;
  scene.add(root);

  const platform = box(root, 4.25, 0.08, 3.25, 0, 0.04, -0.15, 0x1d2b34);
  platform.material.emissive = new THREE.Color(0x0d202a);
  platform.material.emissiveIntensity = 0.08;
  box(root, 4.0, 0.08, 0.18, 0, 0.09, 1.25, 0x52626c);
  const hubSign = routeLabel('ROUTING HUB', 0xb8d7e6);
  hubSign.position.set(0, 1.9, 0.58);
  root.add(hubSign);
  box(root, 0.12, 1.55, 0.12, -1.7, 0.78, 0.63, 0x495861);
  box(root, 0.12, 1.55, 0.12, 1.7, 0.78, 0.63, 0x495861);
  box(root, 3.52, 0.1, 0.12, 0, 1.5, 0.63, 0x495861);

  const lanes = ROUTING_MODES.map((mode, index) => {
    const lane = createLane(mode, index);
    root.add(lane);
    return lane;
  });

  const dispatchParcels = [];
  let flowMode = false;
  let clock = 0;
  let switchPulse = 0;

  function spawnDispatch(event) {
    const mode = event.mode || sim.state.routingMode || 'balanced';
    const laneIndex = Math.max(0, ROUTING_MODES.indexOf(mode));
    const laneX = (laneIndex - 1) * 1.18;
    const amount = Math.max(1, Math.min(3, Number(event.amount) || 1));
    const color = MODE_COLORS[mode] || MODE_COLORS.balanced;
    for (let i = 0; i < amount; i += 1) {
      const parcel = createDispatchParcel(color, i * 0.12);
      parcel.userData.start = new THREE.Vector3(-0.05 + i * 0.12, 0.35, 1.22);
      parcel.userData.end = new THREE.Vector3(laneX + (i - (amount - 1) / 2) * 0.12, 0.32, -1.65);
      parcel.position.copy(parcel.userData.start);
      root.add(parcel);
      dispatchParcels.push(parcel);
    }
  }

  sim.onEvent((event) => {
    if (event.type === 'route_dispatch') spawnDispatch(event);
    if (event.type === 'route_change') switchPulse = 1;
  });

  function updateParcels(dt) {
    for (let i = dispatchParcels.length - 1; i >= 0; i -= 1) {
      const parcel = dispatchParcels[i];
      parcel.userData.life -= dt * 1.15;
      const t = Math.min(1, Math.max(0, 1 - parcel.userData.life - parcel.userData.offset));
      const eased = t * t * (3 - 2 * t);
      parcel.position.lerpVectors(parcel.userData.start, parcel.userData.end, eased);
      parcel.position.y += Math.sin(eased * Math.PI) * 0.22;
      parcel.rotation.y += dt * 2.4;
      if (parcel.userData.life <= -parcel.userData.offset) {
        root.remove(parcel);
        parcel.traverse((child) => {
          child.geometry?.dispose?.();
          child.material?.dispose?.();
        });
        dispatchParcels.splice(i, 1);
      }
    }
  }

  function update(dt) {
    const active = sim.state.facilityRank >= 3;
    root.visible = active;
    if (!active) return;
    clock += dt * Math.max(0, sim.state.timeScale || 0);
    switchPulse = THREE.MathUtils.lerp(switchPulse, 0, Math.min(1, dt * 3.2));
    const mode = sim.state.routingMode || 'balanced';
    lanes.forEach((lane) => {
      const selected = lane.userData.mode === mode;
      const interval = routingPackage(lane.userData.mode).dispatchInterval;
      const pulse = selected ? 0.5 + Math.sin((clock / interval) * Math.PI * 2) * 0.5 : 0;
      lane.userData.stripe.material.opacity = selected ? (flowMode ? 0.62 : 0.42) + switchPulse * 0.18 : 0.08;
      lane.userData.stripe.material.emissiveIntensity = selected ? 0.45 + pulse * 0.55 + switchPulse : 0.06;
      lane.userData.lamp.material.emissiveIntensity = selected ? 0.72 + pulse * 0.75 + switchPulse : 0.12;
      lane.userData.beacon.material.opacity = selected ? 0.38 + pulse * 0.48 : 0.08;
      lane.userData.beacon.scale.setScalar(selected ? 0.9 + pulse * 0.35 : 0.72);
    });
    updateParcels(dt);
  }

  function setFlowMode(enabled) {
    flowMode = Boolean(enabled);
  }

  return { update, setFlowMode, root };
}
