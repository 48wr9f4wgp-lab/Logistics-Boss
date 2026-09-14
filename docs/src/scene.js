import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.186.0/build/three.module.js';
import RAPIER from 'https://cdn.jsdelivr.net/npm/@dimforge/rapier3d-compat@0.20.0/+esm';
import { POS } from './sim.js';
import { createAsrsVisual } from './asrs-visual.js';

const TASK_TEXTURES = new Map();
const GEO = {
  box: new THREE.BoxGeometry(1, 1, 1),
  parcel: new THREE.BoxGeometry(0.52, 0.42, 0.5),
  parcelTape: new THREE.BoxGeometry(0.12, 0.425, 0.505),
};

function mat(color, roughness = 0.78, emissive = 0x000000, metalness = 0) {
  return new THREE.MeshStandardMaterial({ color, roughness, emissive, metalness });
}

function boxMesh(x, y, z, color, roughness = 0.78, emissive = 0x000000, metalness = 0) {
  const mesh = new THREE.Mesh(GEO.box, mat(color, roughness, emissive, metalness));
  mesh.scale.set(x, y, z);
  mesh.position.y = y / 2;
  return mesh;
}

function addBox(group, x, y, z, px, py, pz, color, roughness = 0.78, emissive = 0x000000, metalness = 0) {
  const mesh = boxMesh(x, y, z, color, roughness, emissive, metalness);
  mesh.position.set(px, py, pz);
  group.add(mesh);
  return mesh;
}

function floorLabel(text, color) {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 128;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, 512, 128);
  ctx.fillStyle = 'rgba(6,12,17,.78)';
  ctx.roundRect(8, 20, 496, 88, 18);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = 7;
  ctx.stroke();
  ctx.fillStyle = '#f8fbfd';
  ctx.font = '900 50px -apple-system,BlinkMacSystemFont,sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, 256, 65);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(1.72, 0.43),
    new THREE.MeshBasicMaterial({ map: texture, transparent: true, depthWrite: false, side: THREE.DoubleSide })
  );
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.y = 0.018;
  mesh.renderOrder = 3;
  return mesh;
}

function taskStyle(state) {
  if (state === 'store') return { label: 'IN', color: 0x63c8ff, css: '#2b89ca' };
  if (state === 'pick') return { label: 'PK', color: 0xffca62, css: '#b77b19' };
  if (state === 'ship') return { label: 'OUT', color: 0x61e89a, css: '#248957' };
  return { label: '•', color: 0xffffff, css: '#4b5560' };
}

function taskTexture(state) {
  if (TASK_TEXTURES.has(state)) return TASK_TEXTURES.get(state);
  const s = taskStyle(state);
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = 'rgba(6,11,15,.92)';
  ctx.beginPath();
  ctx.arc(64, 64, 45, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = s.css;
  ctx.lineWidth = 9;
  ctx.stroke();
  ctx.fillStyle = '#fff';
  ctx.font = '900 34px -apple-system,BlinkMacSystemFont,sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(s.label, 64, 66);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  TASK_TEXTURES.set(state, tex);
  return tex;
}

function hazardStripe(width, depth, color = 0xf5c04a) {
  const group = new THREE.Group();
  const stripeMat = new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.78, depthWrite: false });
  const darkMat = new THREE.MeshBasicMaterial({ color: 0x20272d, transparent: true, opacity: 0.72, depthWrite: false });
  const count = Math.max(4, Math.floor(width / 0.45));
  for (let i = 0; i < count; i += 1) {
    const stripe = new THREE.Mesh(new THREE.PlaneGeometry(0.22, depth), i % 2 ? darkMat : stripeMat);
    stripe.rotation.x = -Math.PI / 2;
    stripe.rotation.z = -0.42;
    stripe.position.set(-width / 2 + 0.25 + i * (width / count), 0.02, 0);
    group.add(stripe);
  }
  return group;
}

function loadingDock(pos) {
  const group = new THREE.Group();
  const steel = 0x4d5962;
  const base = addBox(group, 3.15, 0.1, 2.5, 0, 0.05, 0, 0x2b6591, 0.88);
  base.material.emissive = new THREE.Color(0x000000);
  addBox(group, 0.12, 1.85, 0.12, -1.35, 0.93, -0.8, steel, 0.66, 0, 0.25);
  addBox(group, 0.12, 1.85, 0.12, 1.35, 0.93, -0.8, steel, 0.66, 0, 0.25);
  addBox(group, 2.82, 0.12, 0.12, 0, 1.8, -0.8, steel, 0.66, 0, 0.25);
  addBox(group, 2.7, 0.52, 0.08, 0, 1.48, -0.84, 0x26323a, 0.75);
  for (let i = 0; i < 5; i += 1) {
    addBox(group, 0.42, 0.035, 0.72, -0.92 + i * 0.46, 0.095, 0.62, i % 2 ? 0x20272d : 0x5ebde6, 0.5);
  }
  const stripe = hazardStripe(2.5, 0.16, 0x69d7ff);
  stripe.position.set(0, 0, 0.95);
  group.add(stripe);
  const lamp = addBox(group, 0.9, 0.05, 0.06, 0, 1.7, -0.72, 0x8be5ff, 0.45, 0x5ecfff);
  lamp.material.emissiveIntensity = 0.65;
  const label = floorLabel('INBOUND', '#69cfff');
  label.position.set(0, 0.03, -0.12);
  group.add(label);
  group.position.set(pos.x, 0, pos.z);
  group.userData.base = base;
  return group;
}

function packStation(pos) {
  const group = new THREE.Group();
  const pad = addBox(group, 2.85, 0.08, 2.45, 0, 0.04, 0, 0x956a28, 0.88);
  pad.material.emissive = new THREE.Color(0x000000);
  const bench = addBox(group, 1.82, 0.12, 0.74, 0, 0.72, -0.1, 0x525d66, 0.58, 0, 0.35);
  addBox(group, 0.12, 0.68, 0.12, -0.74, 0.36, -0.1, 0x3d474f, 0.6, 0, 0.28);
  addBox(group, 0.12, 0.68, 0.12, 0.74, 0.36, -0.1, 0x3d474f, 0.6, 0, 0.28);
  addBox(group, 1.5, 0.1, 0.1, 0, 1.18, -0.16, 0xe3a846, 0.55);
  addBox(group, 0.1, 0.8, 0.1, -0.69, 0.84, -0.16, 0xe3a846, 0.55);
  addBox(group, 0.1, 0.8, 0.1, 0.69, 0.84, -0.16, 0xe3a846, 0.55);
  const screen = addBox(group, 0.44, 0.28, 0.04, 0.54, 1.02, 0.28, 0x79dfff, 0.45, 0x4dc8ff);
  screen.material.emissiveIntensity = 0.72;
  const stripe = hazardStripe(2.35, 0.16, 0xf3b74c);
  stripe.position.set(0, 0, 0.95);
  group.add(stripe);
  const label = floorLabel('PACK', '#ffc75f');
  label.position.set(0, 0.03, 0.72);
  group.add(label);
  group.position.set(pos.x, 0, pos.z);
  group.userData.base = pad;
  group.userData.bench = bench;
  return group;
}

function outboundStation(pos) {
  const group = new THREE.Group();
  const pad = addBox(group, 3.0, 0.08, 2.55, 0, 0.04, 0, 0x2c7b54, 0.88);
  pad.material.emissive = new THREE.Color(0x000000);
  const dark = 0x404b53;
  addBox(group, 0.16, 2.0, 0.16, -1.2, 1.0, -0.67, dark, 0.62, 0, 0.3);
  addBox(group, 0.16, 2.0, 0.16, 1.2, 1.0, -0.67, dark, 0.62, 0, 0.3);
  addBox(group, 2.56, 0.14, 0.16, 0, 1.94, -0.67, dark, 0.62, 0, 0.3);
  for (let i = 0; i < 4; i += 1) addBox(group, 0.46, 0.03, 0.68, -0.69 + i * 0.46, 0.09, 0.58, i % 2 ? 0x22292f : 0x64d99a, 0.5);
  const stripe = hazardStripe(2.4, 0.16, 0x75e3a7);
  stripe.position.set(0, 0, 0.98);
  group.add(stripe);
  const lamp = addBox(group, 1.15, 0.06, 0.07, 0, 1.78, -0.6, 0x79efac, 0.4, 0x62e69d);
  lamp.material.emissiveIntensity = 0.72;
  const label = floorLabel('OUTBOUND', '#73eda9');
  label.position.set(0, 0.03, 0.62);
  group.add(label);
  group.position.set(pos.x, 0, pos.z);
  group.userData.base = pad;
  group.userData.lamp = lamp;
  return group;
}

function rackBank(x, z, tint = 0xdf9d3e) {
  const group = new THREE.Group();
  const steel = mat(0x4b5964, 0.58, 0x000000, 0.36);
  const beamMat = mat(tint, 0.6, 0x000000, 0.16);
  const deck = mat(0x6d7880, 0.78);
  const heatMaterial = mat(0x4f5f69, 0.55, 0x000000, 0.3);
  const bays = 3;
  const width = 4.25;
  for (let i = 0; i <= bays; i += 1) {
    const px = -width / 2 + i * (width / bays);
    for (const pz of [-0.47, 0.47]) {
      const post = new THREE.Mesh(GEO.box, steel);
      post.scale.set(0.1, 2.65, 0.1);
      post.position.set(px, 1.325, pz);
      group.add(post);
    }
  }
  for (const py of [0.45, 1.18, 1.91]) {
    for (const pz of [-0.47, 0.47]) {
      const beam = new THREE.Mesh(GEO.box, beamMat);
      beam.scale.set(width, 0.1, 0.08);
      beam.position.set(0, py, pz);
      group.add(beam);
    }
    const shelf = new THREE.Mesh(GEO.box, deck);
    shelf.scale.set(width - 0.1, 0.055, 0.92);
    shelf.position.set(0, py - 0.03, 0);
    group.add(shelf);
  }
  for (let bay = 0; bay < bays; bay += 1) {
    const bx = -1.42 + bay * 1.42;
    for (let level = 0; level < 2; level += 1) {
      if ((bay + level) % 3 === 2) continue;
      addBox(group, 0.95, 0.07, 0.72, bx, 0.54 + level * 0.73, 0, 0x8d6137, 0.9);
      addBox(group, 0.7, 0.36, 0.56, bx, 0.75 + level * 0.73, 0, level ? 0x7fa8c1 : 0xc89a63, 0.83);
    }
  }
  const topLamp = new THREE.Mesh(GEO.box, heatMaterial);
  topLamp.scale.set(1.2, 0.06, 0.08);
  topLamp.position.set(0, 2.45, 0.5);
  group.add(topLamp);
  group.position.set(x, 0, z);
  group.userData.shelfMaterial = heatMaterial;
  return group;
}

function packModule(index) {
  const group = new THREE.Group();
  const metal = 0x56616a;
  const body = addBox(group, 0.92, 0.58, 0.82, 0, 0.42, 0, 0xd79a35, 0.62, 0x000000, 0.08);
  addBox(group, 0.78, 0.08, 0.9, 0, 0.76, 0, metal, 0.56, 0, 0.32);
  addBox(group, 0.08, 0.8, 0.08, -0.38, 0.74, 0, metal, 0.56, 0, 0.32);
  addBox(group, 0.08, 0.8, 0.08, 0.38, 0.74, 0, metal, 0.56, 0, 0.32);
  addBox(group, 0.8, 0.08, 0.08, 0, 1.1, 0, 0xf3bd5f, 0.5);
  const screen = addBox(group, 0.34, 0.2, 0.035, 0.25, 0.72, 0.43, 0x8fe8ff, 0.4, 0x55cfff);
  screen.material.emissiveIntensity = 0.7;
  const cols = 3;
  group.position.set(1.15 + (index % cols) * 1.02, 0.08, -0.76 - Math.floor(index / cols) * 0.92);
  group.userData.body = body;
  return group;
}

function conveyorModule(index) {
  const group = new THREE.Group();
  const belt = addBox(group, 2.8, 0.13, 0.66, 0, 0.41, 0, 0x242b30, 0.76, 0x000000, 0.2);
  const sideMat = mat(0x69757e, 0.56, 0x000000, 0.4);
  for (const pz of [-0.37, 0.37]) {
    const rail = new THREE.Mesh(GEO.box, sideMat);
    rail.scale.set(2.9, 0.16, 0.06);
    rail.position.set(0, 0.5, pz);
    group.add(rail);
  }
  const rollers = [];
  for (let i = 0; i < 8; i += 1) {
    const r = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.075, 0.58, 8), mat(0x9aa4aa, 0.45, 0, 0.45));
    r.rotation.z = Math.PI / 2;
    r.position.set(-1.28 + i * 0.365, 0.5, 0);
    group.add(r);
    rollers.push(r);
  }
  for (const px of [-1.1, 1.1]) {
    addBox(group, 0.08, 0.42, 0.08, px, 0.22, -0.24, 0x4d5962, 0.6, 0, 0.3);
    addBox(group, 0.08, 0.42, 0.08, px, 0.22, 0.24, 0x4d5962, 0.6, 0, 0.3);
  }
  const positions = [
    [-4.6, 0.0, 1.45, -0.5],
    [-2.4, 0.0, -4.35, 0],
    [1.0, 0.0, -5.0, 0],
    [4.25, 0.0, -4.3, -0.48],
  ];
  const [x, y, z, rot] = positions[index] || positions[0];
  group.position.set(x, y, z);
  group.rotation.y = rot;
  group.userData = { rollers, belt };
  return group;
}

function forkliftUnit(index) {
  const group = new THREE.Group();
  const bodyColor = index % 2 ? 0xf2b13f : 0xe88d32;
  const body = addBox(group, 0.82, 0.46, 1.06, 0, 0.42, 0.15, bodyColor, 0.56, 0x000000, 0.08);
  addBox(group, 0.62, 0.62, 0.62, 0, 0.88, 0.18, 0x38434a, 0.48, 0x000000, 0.28);
  const glass = addBox(group, 0.5, 0.38, 0.05, 0, 0.98, -0.16, 0x70cdea, 0.28, 0x2b8db3, 0.08);
  glass.material.emissiveIntensity = 0.18;
  const mast = addBox(group, 0.12, 1.38, 0.12, 0, 0.86, -0.58, 0x4b555c, 0.5, 0, 0.42);
  addBox(group, 0.52, 0.08, 0.08, 0, 1.42, -0.58, 0x59646b, 0.5, 0, 0.42);
  const forkA = addBox(group, 0.08, 0.07, 0.9, -0.18, 0.18, -0.86, 0x657078, 0.48, 0, 0.45);
  const forkB = addBox(group, 0.08, 0.07, 0.9, 0.18, 0.18, -0.86, 0x657078, 0.48, 0, 0.45);
  const pallet = addBox(group, 0.58, 0.08, 0.52, 0, 0.27, -0.96, 0x8d633b, 0.86);
  addBox(group, 0.48, 0.3, 0.42, 0, 0.46, -0.96, 0xc88f58, 0.84);
  for (const [x, z] of [[-0.38, -0.22], [0.38, -0.22], [-0.38, 0.46], [0.38, 0.46]]) {
    const wheel = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 0.13, 10), mat(0x20262a, 0.9));
    wheel.rotation.z = Math.PI / 2;
    wheel.position.set(x, 0.22, z);
    group.add(wheel);
  }
  group.visible = false;
  group.scale.setScalar(0.78);
  group.userData = { body, mast, forkA, forkB, pallet };
  return group;
}

function agvUnit(index) {
  const group = new THREE.Group();
  const body = addBox(group, 0.92, 0.18, 0.72, 0, 0.16, 0, index % 2 ? 0x4699b7 : 0x3d7f9f, 0.5, 0x102f3a, 0.22);
  body.material.emissiveIntensity = 0.08;
  addBox(group, 0.72, 0.08, 0.56, 0, 0.29, 0, 0x606d75, 0.54, 0, 0.28);
  addBox(group, 0.58, 0.06, 0.46, 0, 0.36, 0, 0x8b623b, 0.84);
  addBox(group, 0.46, 0.28, 0.36, 0, 0.54, 0, 0xc99459, 0.82);
  const lightA = addBox(group, 0.18, 0.05, 0.04, -0.25, 0.22, -0.37, 0x76e8ff, 0.36, 0x54dfff);
  const lightB = addBox(group, 0.18, 0.05, 0.04, 0.25, 0.22, -0.37, 0x76e8ff, 0.36, 0x54dfff);
  lightA.material.emissiveIntensity = 0.8;
  lightB.material.emissiveIntensity = 0.8;
  group.visible = false;
  group.scale.setScalar(0.72);
  group.userData = { body, lightA, lightB };
  return group;
}

function sorterModule(index) {
  const group = new THREE.Group();
  const belt = addBox(group, 2.15, 0.16, 0.62, 0, 0.46, 0, 0x252e34, 0.68, 0x000000, 0.2);
  const rollers = [];
  for (let i = 0; i < 7; i += 1) {
    const roller = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.5, 8), mat(0x9ca7ad, 0.42, 0, 0.48));
    roller.rotation.z = Math.PI / 2;
    roller.position.set(-0.88 + i * 0.29, 0.55, 0);
    group.add(roller);
    rollers.push(roller);
  }
  const archColor = index % 2 ? 0x65dda3 : 0x63c8ff;
  addBox(group, 0.08, 1.2, 0.08, -0.72, 1.0, 0, 0x56626a, 0.56, 0, 0.3);
  addBox(group, 0.08, 1.2, 0.08, 0.72, 1.0, 0, 0x56626a, 0.56, 0, 0.3);
  const scanner = addBox(group, 1.5, 0.1, 0.1, 0, 1.55, 0, archColor, 0.42, archColor);
  scanner.material.emissiveIntensity = 0.55;
  const diverter = addBox(group, 0.9, 0.1, 0.12, 0.28, 0.66, 0, 0xf0b24a, 0.48, 0x7e4c0f, 0.18);
  diverter.rotation.y = -0.42;
  const chute = addBox(group, 1.1, 0.08, 0.5, 0.92, 0.38, -0.48, 0x4f5b63, 0.62, 0, 0.3);
  chute.rotation.y = -0.58;
  for (const px of [-0.82, 0.82]) {
    addBox(group, 0.08, 0.42, 0.08, px, 0.22, -0.22, 0x4d5962, 0.6, 0, 0.3);
    addBox(group, 0.08, 0.42, 0.08, px, 0.22, 0.22, 0x4d5962, 0.6, 0, 0.3);
  }
  group.position.set(3.2 + index * 0.75, 0, -2.7 - index * 0.58);
  group.rotation.y = -0.38;
  group.visible = false;
  group.scale.setScalar(0.82);
  group.userData = { belt, rollers, scanner, diverter };
  return group;
}

function truckDockBay(index) {
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

function workerMesh(index) {
  const colors = [0x54b7ee, 0xf4aa45, 0x9a7de0, 0x55d18d, 0xec7182, 0x61c8c5, 0xd793e9, 0xe9bf52];
  const accent = colors[index % colors.length];
  const group = new THREE.Group();

  const shadow = new THREE.Mesh(
    new THREE.CircleGeometry(0.32, 16),
    new THREE.MeshBasicMaterial({ color: 0x0a0d0f, transparent: true, opacity: 0.28, depthWrite: false })
  );
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.y = 0.012;
  group.add(shadow);

  const legMat = mat(0x313b43, 0.8);
  for (const x of [-0.105, 0.105]) {
    const leg = new THREE.Mesh(new THREE.CapsuleGeometry(0.08, 0.25, 3, 6), legMat);
    leg.position.set(x, 0.31, 0);
    group.add(leg);
  }

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.22, 0.34, 5, 8), mat(accent, 0.6));
  torso.position.y = 0.73;
  group.add(torso);
  const vest = addBox(group, 0.36, 0.23, 0.28, 0, 0.73, 0.13, 0xf0c94f, 0.76);
  vest.material.color.offsetHSL(0, -0.12, 0.02);

  const head = new THREE.Mesh(new THREE.SphereGeometry(0.18, 10, 8), mat(0xe8b88f, 0.82));
  head.position.y = 1.12;
  group.add(head);
  const helmet = new THREE.Mesh(new THREE.SphereGeometry(0.19, 10, 7, 0, Math.PI * 2, 0, Math.PI * 0.58), mat(accent, 0.55));
  helmet.position.y = 1.17;
  group.add(helmet);
  addBox(group, 0.3, 0.04, 0.22, 0, 1.14, -0.03, accent, 0.55);

  const ring = new THREE.Mesh(
    new THREE.RingGeometry(0.28, 0.36, 20),
    new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5, side: THREE.DoubleSide })
  );
  ring.rotation.x = -Math.PI / 2;
  ring.position.y = 0.025;
  group.add(ring);

  const badge = new THREE.Sprite(new THREE.SpriteMaterial({ map: taskTexture('idle'), transparent: true, depthTest: false }));
  badge.position.y = 1.5;
  badge.scale.set(0.42, 0.42, 1);
  badge.visible = false;
  badge.renderOrder = 12;
  group.add(badge);

  group.userData = { ring, badge, badgeState: 'idle', torso, vest, accent };
  return group;
}

function parcelMesh() {
  const group = new THREE.Group();
  const parcel = new THREE.Mesh(GEO.parcel, mat(0xd39a59, 0.84));
  parcel.position.y = 0.21;
  group.add(parcel);
  const tape = new THREE.Mesh(GEO.parcelTape, mat(0xc9b789, 0.9));
  tape.position.y = 0.21;
  group.add(tape);
  const label = new THREE.Mesh(new THREE.PlaneGeometry(0.22, 0.12), new THREE.MeshBasicMaterial({ color: 0xf2f2e7 }));
  label.position.set(0.265, 0.25, 0.07);
  label.rotation.y = Math.PI / 2;
  group.add(label);
  return group;
}

function annex(level) {
  const group = new THREE.Group();
  const z = -8.3 - (level - 1) * 3.2;
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(17.4, 3.05), mat(level % 2 ? 0x46545e : 0x4b5963, 0.93, 0x16344a));
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = 0.006;
  floor.material.emissiveIntensity = 0;
  group.add(floor);

  const steel = 0x46515a;
  for (const x of [-8, -4, 0, 4, 8]) {
    addBox(group, 0.14, 3.0, 0.14, x, 1.5, 0, steel, 0.6, 0, 0.35);
    addBox(group, 0.08, 2.8, 0.08, x + 0.36, 1.5, -1.2, 0x59656e, 0.65, 0, 0.25);
  }
  addBox(group, 16.2, 0.14, 0.14, 0, 2.9, 0, steel, 0.6, 0, 0.35);
  addBox(group, 16.2, 0.09, 0.09, 0, 2.65, -1.15, 0x56636d, 0.62, 0, 0.28);
  for (let x = -6.4; x <= 6.4; x += 3.2) {
    const light = addBox(group, 1.1, 0.035, 0.08, x, 2.54, -1.12, 0xdff9ff, 0.4, 0xa7efff);
    light.material.emissiveIntensity = 0.7;
  }
  const sign = floorLabel(`HALL ${level + 1}`, '#89dfff');
  sign.rotation.x = 0;
  sign.position.set(0, 2.3, 0.08);
  sign.scale.setScalar(0.66);
  group.add(sign);
  group.position.z = z;
  group.visible = false;
  group.scale.setScalar(0.82);
  group.userData = { floor, reveal: 0 };
  return group;
}

function outboundGate(index) {
  const group = new THREE.Group();
  const dark = 0x46515a;
  addBox(group, 0.14, 2.45, 0.14, -0.82, 1.22, 0, dark, 0.62, 0, 0.34);
  addBox(group, 0.14, 2.45, 0.14, 0.82, 1.22, 0, dark, 0.62, 0, 0.34);
  addBox(group, 1.78, 0.14, 0.14, 0, 2.38, 0, dark, 0.62, 0, 0.34);
  addBox(group, 1.52, 1.7, 0.07, 0, 1.35, 0.04, 0x263039, 0.8);
  for (let y = 0.65; y < 2.1; y += 0.36) addBox(group, 1.42, 0.045, 0.04, 0, y, 0, 0x53616b, 0.65);
  const lamp = addBox(group, 1.22, 0.055, 0.08, 0, 2.24, -0.04, 0x76f0aa, 0.4, 0x5fe49b);
  lamp.material.emissiveIntensity = 0.65;
  addBox(group, 0.2, 0.38, 0.22, -0.7, 0.19, -0.28, 0x262d32, 0.76);
  addBox(group, 0.2, 0.38, 0.22, 0.7, 0.19, -0.28, 0x262d32, 0.76);
  group.position.set(5.6 - index * 2.0, 0, -6.3);
  group.userData.lamp = lamp;
  return group;
}

function lane(index) {
  const mesh = new THREE.Mesh(
    new THREE.PlaneGeometry(0.075, 8.6),
    new THREE.MeshBasicMaterial({ color: index % 2 ? 0x5ed7ff : 0xe9f2f7, transparent: true, opacity: 0.2, depthWrite: false })
  );
  mesh.rotation.x = -Math.PI / 2;
  mesh.rotation.z = -0.52;
  mesh.position.set(-2.8 + index * 0.28, 0.014, 1.2);
  return mesh;
}

function laneArrow(color = 0x81dfff) {
  const shape = new THREE.Shape();
  shape.moveTo(0, 0.55);
  shape.lineTo(0.34, 0.06);
  shape.lineTo(0.13, 0.06);
  shape.lineTo(0.13, -0.48);
  shape.lineTo(-0.13, -0.48);
  shape.lineTo(-0.13, 0.06);
  shape.lineTo(-0.34, 0.06);
  shape.closePath();
  const geom = new THREE.ShapeGeometry(shape);
  const mesh = new THREE.Mesh(geom, new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.18, depthWrite: false, side: THREE.DoubleSide }));
  mesh.rotation.x = -Math.PI / 2;
  return mesh;
}

function createWarehouseShell() {
  const group = new THREE.Group();
  const steel = 0x344049;
  const lightSteel = 0x4b5964;
  const fade = (mesh, opacity) => {
    mesh.material.transparent = true;
    mesh.material.opacity = opacity;
    mesh.material.depthWrite = false;
    return mesh;
  };

  for (const x of [-7.2, 0, 7.2]) {
    fade(addBox(group, 0.11, 3.15, 0.11, x, 1.575, -7.15, steel, 0.66, 0, 0.28), 0.34);
  }
  fade(addBox(group, 14.55, 0.08, 0.08, 0, 3.02, -7.15, lightSteel, 0.68, 0, 0.22), 0.3);

  for (const x of [-4.6, 4.6]) {
    const light = addBox(group, 0.82, 0.022, 0.05, x, 2.82, -5.95, 0xdaf6ff, 0.45, 0x9ee9ff);
    light.material.emissiveIntensity = 0.14;
    light.material.transparent = true;
    light.material.opacity = 0.42;
  }
  group.userData.dollhouse = true;
  group.userData.readabilityPass = 4;
  return group;
}

function createFloorMarkings() {
  const group = new THREE.Group();
  const white = new THREE.MeshBasicMaterial({ color: 0xc9d5db, transparent: true, opacity: 0.22, depthWrite: false });
  const yellow = new THREE.MeshBasicMaterial({ color: 0xf2c858, transparent: true, opacity: 0.3, depthWrite: false });
  for (const z of [-5.8, -1.0, 3.8]) {
    const line = new THREE.Mesh(new THREE.PlaneGeometry(15.8, 0.055), z === -1.0 ? yellow : white);
    line.rotation.x = -Math.PI / 2;
    line.position.set(0, 0.015, z);
    group.add(line);
  }
  for (const x of [-5.1, 0, 5.1]) {
    const line = new THREE.Mesh(new THREE.PlaneGeometry(0.055, 12.8), white);
    line.rotation.x = -Math.PI / 2;
    line.position.set(x, 0.016, -0.3);
    group.add(line);
  }
  const arrowPositions = [
    [-4.6, 2.2, -1.15], [-2.4, 0.8, -1.05], [0.2, 0.0, -1.25], [3.7, -1.8, -1.05],
  ];
  for (const [x, z, r] of arrowPositions) {
    const a = laneArrow();
    a.position.set(x, 0.018, z);
    a.rotation.z = r;
    a.scale.setScalar(0.82);
    group.add(a);
  }
  return group;
}

function createFlowFloorGuide() {
  const group = new THREE.Group();
  group.visible = false;
  group.userData.flowFloorGuide = true;
  group.userData.flowArrows = [];
  const points = [POS.inbound, POS.rack, POS.pack, POS.outbound];
  const colors = [0x63c8ff, 0xf2c858, 0x61e89a];
  for (let i = 0; i < points.length - 1; i += 1) {
    const a = points[i];
    const b = points[i + 1];
    const dx = b.x - a.x;
    const dz = b.z - a.z;
    const length = Math.hypot(dx, dz);
    const angle = -Math.atan2(dz, dx);
    const material = new THREE.MeshBasicMaterial({
      color: colors[i], transparent: true, opacity: 0.27, depthWrite: false, side: THREE.DoubleSide,
    });
    const segment = new THREE.Mesh(new THREE.PlaneGeometry(length, 0.5), material);
    segment.rotation.x = -Math.PI / 2;
    segment.rotation.z = angle;
    segment.position.set((a.x + b.x) / 2, 0.024, (a.z + b.z) / 2);
    segment.renderOrder = 2;
    group.add(segment);

    for (const t of [0.16, 0.48, 0.8]) {
      const arrow = laneArrow(colors[i]);
      arrow.position.set(a.x + dx * t, 0.032, a.z + dz * t);
      arrow.rotation.z = angle - Math.PI / 2;
      arrow.scale.setScalar(0.58);
      arrow.material.opacity = 0.62;
      arrow.renderOrder = 3;
      arrow.userData.flowPath = { ax: a.x, az: a.z, dx, dz, offset: t };
      group.userData.flowArrows.push(arrow);
      group.add(arrow);
    }
  }
  return group;
}

export async function createSceneView(canvas, sim) {
  await RAPIER.init();
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.03;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.25));
  renderer.setSize(innerWidth, innerHeight, false);

  const scene = new THREE.Scene();
  const asrsVisual = createAsrsVisual(scene, sim);
  scene.background = new THREE.Color(0x101920);
  scene.fog = new THREE.Fog(0x101920, 23, 48);
  const camera = new THREE.PerspectiveCamera(43, innerWidth / innerHeight, 0.1, 90);
  const cameraState = { yaw: 0.68, pitch: 0.64, distance: 14.45, targetDistance: 14.45, target: new THREE.Vector3(0, 0.52, -0.35) };

  scene.add(new THREE.HemisphereLight(0xe3f6ff, 0x273039, 2.2));
  const sun = new THREE.DirectionalLight(0xfff6e8, 2.15);
  sun.position.set(7, 12, 6);
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0x8fd8ff, 0.55);
  fill.position.set(-8, 6, -6);
  scene.add(fill);

  const floor = new THREE.Mesh(new THREE.PlaneGeometry(18, 16), mat(0x505c65, 0.95));
  floor.rotation.x = -Math.PI / 2;
  floor.position.z = -0.7;
  scene.add(floor);
  const grid = new THREE.GridHelper(18, 18, 0x68757e, 0x45515a);
  grid.position.z = -0.7;
  grid.material.transparent = true;
  grid.material.opacity = 0.28;
  scene.add(grid);
  scene.add(createFloorMarkings());
  const flowFloorGuide = createFlowFloorGuide();
  scene.add(flowFloorGuide);
  scene.add(createWarehouseShell());

  const inbound = loadingDock(POS.inbound);
  const pack = packStation(POS.pack);
  const outbound = outboundStation(POS.outbound);
  inbound.scale.setScalar(1.08);
  pack.scale.setScalar(1.12);
  outbound.scale.setScalar(1.08);
  scene.add(inbound, pack, outbound);

  const secondInboundFacility = loadingDock({ x: -4.25, z: 4.25 });
  secondInboundFacility.scale.setScalar(0.82);
  secondInboundFacility.visible = false;
  scene.add(secondInboundFacility);
  const bufferYardFacility = rackBank(-4.7, 2.65, 0x63c8ff);
  bufferYardFacility.scale.setScalar(0.72);
  bufferYardFacility.visible = false;
  scene.add(bufferYardFacility);
  const secondPackFacility = packStation({ x: 4.15, z: 1.45 });
  secondPackFacility.scale.setScalar(0.82);
  secondPackFacility.visible = false;
  scene.add(secondPackFacility);
  const fastPackCellFacility = packStation({ x: 4.15, z: 1.45 });
  fastPackCellFacility.scale.setScalar(0.68);
  fastPackCellFacility.userData.base.material.color.setHex(0x3c8f88);
  fastPackCellFacility.visible = false;
  scene.add(fastPackCellFacility);
  const fastPickRackFacility = rackBank(-2.15, -0.35, 0x65d8b4);
  fastPickRackFacility.scale.setScalar(0.9);
  fastPickRackFacility.visible = false;
  scene.add(fastPickRackFacility);
  const highDensityRackFacility = rackBank(-2.15, -3.7, 0xc783d9);
  highDensityRackFacility.scale.setScalar(0.96);
  highDensityRackFacility.visible = false;
  scene.add(highDensityRackFacility);

  const rackBanks = [rackBank(-2.15, -1.65)];
  rackBanks[0].scale.setScalar(1.06);
  scene.add(rackBanks[0]);
  for (let i = 0; i < 4; i += 1) {
    const bank = rackBank(-2.15, -2.75 - i * 0.95, 0xe2a048);
    bank.visible = false;
    bank.scale.setScalar(1.06);
    scene.add(bank);
    rackBanks.push(bank);
  }

  const packModules = [];
  for (let i = 0; i < 5; i += 1) {
    const module = packModule(i);
    module.visible = false;
    scene.add(module);
    packModules.push(module);
  }

  const conveyors = [];
  for (let i = 0; i < 4; i += 1) {
    const c = conveyorModule(i);
    c.visible = false;
    scene.add(c);
    conveyors.push(c);
  }

  const forklifts = [];
  for (let i = 0; i < 4; i += 1) {
    const unit = forkliftUnit(i);
    scene.add(unit);
    forklifts.push(unit);
  }

  const agvs = [];
  for (let i = 0; i < 4; i += 1) {
    const unit = agvUnit(i);
    scene.add(unit);
    agvs.push(unit);
  }

  const sorters = [];
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

  const annexes = [];
  for (let i = 1; i <= 3; i += 1) {
    const a = annex(i);
    scene.add(a);
    annexes.push(a);
  }

  const gates = [outboundGate(0), outboundGate(1), outboundGate(2)];
  gates.forEach((g, i) => { g.visible = i === 0; scene.add(g); });

  const lanes = [];
  for (let i = 0; i < 5; i += 1) {
    const l = lane(i);
    l.visible = false;
    scene.add(l);
    lanes.push(l);
  }

  const workerMeshes = new Map();
  const boxMeshes = new Map();
  const flowLines = new Map();
  const shipmentBursts = [];
  let flowMode = false;
  let flowGuideClock = 0;
  let automationClock = 0;
  let lastGrowth = -1;
  let forkliftPulse = 0;
  let agvPulse = 0;
  let sorterPulse = 0;
  let truckPulse = 0;

  const physics = new RAPIER.World({ x: 0, y: -9.81, z: 0 });
  physics.createCollider(RAPIER.ColliderDesc.cuboid(9, 0.08, 10).setTranslation(0, -0.08, -2));
  const overflow = [];

  function removeOverflow(item) {
    if (!item) return;
    scene.remove(item.mesh);
    physics.removeRigidBody(item.body);
  }

  function spawnOverflow() {
    const mesh = parcelMesh();
    scene.add(mesh);
    const body = physics.createRigidBody(
      RAPIER.RigidBodyDesc.dynamic().setTranslation(-6.2 + Math.random() * 0.7, 2.0, 4.1).setLinearDamping(0.08).setAngularDamping(0.16)
    );
    physics.createCollider(RAPIER.ColliderDesc.cuboid(0.23, 0.19, 0.23).setRestitution(0.16).setFriction(0.72), body);
    body.setLinvel({ x: 0.6 + Math.random(), y: 1.0, z: (Math.random() - 0.5) * 1.3 }, true);
    body.setAngvel({ x: 2, y: 3, z: 2 }, true);
    overflow.push({ mesh, body, born: performance.now() });
    while (overflow.length > 12) removeOverflow(overflow.shift());
  }

  function spawnShipmentBurst() {
    const group = new THREE.Group();
    group.position.set(POS.outbound.x, 0.08, POS.outbound.z);
    const ring = new THREE.Mesh(
      new THREE.RingGeometry(0.36, 0.43, 28),
      new THREE.MeshBasicMaterial({ color: 0x78efaa, transparent: true, opacity: 0.76, side: THREE.DoubleSide, depthWrite: false })
    );
    ring.rotation.x = -Math.PI / 2;
    group.add(ring);
    for (let i = 0; i < 5; i += 1) {
      const spark = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.05, 0.16), new THREE.MeshBasicMaterial({ color: 0xc8ffe0, transparent: true, opacity: 0.9 }));
      const a = (i / 5) * Math.PI * 2;
      spark.position.set(Math.cos(a) * 0.48, 0.18, Math.sin(a) * 0.48);
      spark.rotation.y = -a;
      group.add(spark);
    }
    group.userData.life = 1;
    scene.add(group);
    shipmentBursts.push(group);
  }

  let outboundPulse = 0;
  sim.onEvent((event) => {
    if (event.type === 'overflow') spawnOverflow();
    if (event.type === 'forklift_transfer') forkliftPulse = 1;
    if (event.type === 'agv_transfer') agvPulse = 1;
    if (event.type === 'sorter_transfer') sorterPulse = 1;
    if (event.type === 'truck_arrive') truckPulse = 1;
    if (event.type === 'truck_unload') truckPulse = Math.max(truckPulse, 0.45);
    if (event.type === 'truck_depart') truckPulse = Math.max(truckPulse, 0.7);
    if (event.type === 'shipment') {
      outboundPulse = 1;
      spawnShipmentBurst();
    }
  });

  const pointers = new Map();
  let lastSingle = null;
  let pinchStart = 0;
  let pinchCamera = cameraState.distance;
  const pointerDistance = () => {
    const p = [...pointers.values()];
    return p.length < 2 ? 0 : Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y);
  };
  canvas.addEventListener('pointerdown', (e) => {
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    canvas.setPointerCapture?.(e.pointerId);
    if (pointers.size === 1) lastSingle = { x: e.clientX, y: e.clientY };
    if (pointers.size === 2) { pinchStart = pointerDistance(); pinchCamera = cameraState.distance; }
  });
  canvas.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1 && lastSingle) {
      const dx = e.clientX - lastSingle.x;
      const dy = e.clientY - lastSingle.y;
      cameraState.yaw -= dx * 0.006;
      cameraState.pitch = THREE.MathUtils.clamp(cameraState.pitch + dy * 0.0046, 0.38, 1.16);
      lastSingle = { x: e.clientX, y: e.clientY };
    } else if (pointers.size === 2) {
      const d = pointerDistance();
      if (pinchStart > 0) cameraState.targetDistance = THREE.MathUtils.clamp(pinchCamera * (pinchStart / Math.max(1, d)), 9, 30);
    }
  });
  const endPointer = (e) => {
    pointers.delete(e.pointerId);
    const p = [...pointers.values()];
    lastSingle = p.length === 1 ? { ...p[0] } : null;
    if (p.length < 2) pinchStart = 0;
  };
  canvas.addEventListener('pointerup', endPointer);
  canvas.addEventListener('pointercancel', endPointer);
  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    cameraState.targetDistance = THREE.MathUtils.clamp(cameraState.targetDistance + e.deltaY * 0.012, 9, 30);
  }, { passive: false });

  function resetCamera() {
    cameraState.yaw = 0.68;
    cameraState.pitch = 0.64;
    const growth = growthLevel();
    cameraState.targetDistance = 14.45 + growth * 1.95;
    cameraState.target.set(0, 0.52, -0.35 - growth * 1.02);
  }

  function growthLevel() {
    return Math.max(0, Math.min(3, Math.floor(Number(sim.state.upgrades.hall || 0))));
  }

  function updateGrowth(dt) {
    const u = sim.state.upgrades;
    const facilities = sim.state.facilities || {};
    secondInboundFacility.visible = Boolean(facilities.secondInbound);
    bufferYardFacility.visible = Boolean(facilities.bufferYard);
    secondPackFacility.visible = Boolean(facilities.secondPack);
    fastPackCellFacility.visible = Boolean(facilities.fastPackCell);
    fastPickRackFacility.visible = Boolean(facilities.fastPickRack);
    highDensityRackFacility.visible = Boolean(facilities.highDensityRack);
    rackBanks.forEach((b, i) => { b.visible = i === 0 || i <= u.rack; });
    packModules.forEach((m, i) => { m.visible = i < u.pack; });
    conveyors.forEach((c, i) => { c.visible = i < u.conveyor; });
    lanes.forEach((l, i) => { l.visible = i < u.speed; });
    forklifts.forEach((unit, i) => { unit.visible = i < (u.forklift || 0); });
    agvs.forEach((unit, i) => { unit.visible = i < (u.agv || 0); });
    sorters.forEach((unit, i) => { unit.visible = i < (u.sorter || 0); });
    truckDockBays.forEach((bay, i) => { bay.visible = i < (u.truckDock || 0); });
    truck.visible = (u.truckDock || 0) > 0 && sim.state.truckWave?.phase !== 'away';
    gates.forEach((g, i) => { g.visible = i === 0 || i <= Math.floor((u.conveyor + u.worker + (u.sorter || 0)) / 3); });

    const growth = growthLevel();
    annexes.forEach((a, i) => {
      const shouldShow = i < growth;
      if (shouldShow && !a.visible) { a.visible = true; a.userData.reveal = 1; }
      if (!shouldShow) a.visible = false;
      if (a.visible && a.userData.reveal > 0) {
        a.userData.reveal = Math.max(0, a.userData.reveal - dt * 0.7);
        const t = 1 - a.userData.reveal;
        const s = 0.78 + t * 0.22;
        a.scale.setScalar(s);
        a.position.y = (1 - t) * 0.2;
        a.userData.floor.material.emissiveIntensity = a.userData.reveal * 0.9;
      } else if (a.visible) {
        a.scale.setScalar(1);
        a.position.y = 0;
        a.userData.floor.material.emissiveIntensity = 0;
      }
    });
    if (growth !== lastGrowth) {
      lastGrowth = growth;
      cameraState.targetDistance = Math.max(cameraState.targetDistance, 14.45 + growth * 1.95);
      cameraState.target.z = -0.35 - growth * 1.02;
    }
  }

  function updateCamera(dt) {
    cameraState.distance = THREE.MathUtils.lerp(cameraState.distance, cameraState.targetDistance, Math.min(1, dt * 3.8));
    const cp = Math.cos(cameraState.pitch);
    camera.position.set(
      cameraState.target.x + Math.sin(cameraState.yaw) * cp * cameraState.distance,
      cameraState.target.y + Math.sin(cameraState.pitch) * cameraState.distance,
      cameraState.target.z + Math.cos(cameraState.yaw) * cp * cameraState.distance
    );
    camera.lookAt(cameraState.target);
  }

  function ensureFlowLine(id) {
    let line = flowLines.get(id);
    if (!line) {
      line = new THREE.Line(new THREE.BufferGeometry(), new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.32, depthTest: false }));
      line.renderOrder = 8;
      scene.add(line);
      flowLines.set(id, line);
    }
    return line;
  }

  function flowTarget(worker) {
    if (!worker.task) return null;
    if (worker.task.stage === 'pickup') {
      const b = sim.state.boxes.find((x) => x.id === worker.task.boxId);
      if (b) return { x: b.x, y: Math.max(0.22, b.y || 0.22), z: b.z };
    }
    if (worker.task.kind === 'store') return { x: POS.rack.x, y: 0.35, z: POS.rack.z };
    if (worker.task.kind === 'pick') return { x: POS.pack.x, y: 0.35, z: POS.pack.z };
    return { x: POS.outbound.x, y: 0.35, z: POS.outbound.z };
  }

  function criticalTask(kind) {
    const key = sim.state.director?.key;
    if (key === 'inbound') return kind === 'store';
    if (key === 'orders' || key === 'rack') return kind === 'pick';
    if (key === 'packed') return kind === 'ship';
    return false;
  }

  function syncWorkers(dt) {
    const live = new Set();
    let stableLines = 0;
    let visibleLines = 0;
    sim.state.workers.forEach((worker, index) => {
      live.add(worker.id);
      let mesh = workerMeshes.get(worker.id);
      if (!mesh) { mesh = workerMesh(index); scene.add(mesh); workerMeshes.set(worker.id, mesh); }
      mesh.position.x = THREE.MathUtils.lerp(mesh.position.x, worker.x, Math.min(1, dt * 11));
      mesh.position.z = THREE.MathUtils.lerp(mesh.position.z, worker.z, Math.min(1, dt * 11));
      mesh.rotation.y = worker.facing;
      const s = taskStyle(worker.state);
      mesh.userData.ring.material.color.setHex(s.color);
      mesh.userData.ring.material.opacity = worker.state === 'idle' ? 0.25 : 0.62;
      const badge = mesh.userData.badge;
      badge.visible = flowMode && worker.state !== 'idle';
      if (mesh.userData.badgeState !== worker.state) {
        badge.material.map = taskTexture(worker.state);
        badge.material.needsUpdate = true;
        mesh.userData.badgeState = worker.state;
      }
      mesh.position.y = worker.task ? Math.sin(performance.now() * 0.011 + worker.id) * 0.018 : 0;

      const line = ensureFlowLine(worker.id);
      const target = flowTarget(worker);
      const directorStable = sim.state.director?.key === 'stable';
      const relevant = criticalTask(worker.task?.kind) || (directorStable && stableLines < 2);
      const show = flowMode && target && worker.task && relevant && visibleLines < 2;
      line.visible = Boolean(show);
      if (show) {
        visibleLines += 1;
        if (directorStable) stableLines += 1;
        line.material.color.setHex(s.color);
        const start = new THREE.Vector3(mesh.position.x, 0.12, mesh.position.z);
        const end = new THREE.Vector3(target.x, target.y, target.z);
        const mid = start.clone().lerp(end, 0.5); mid.y += 0.08;
        line.geometry.setFromPoints([start, mid, end]);
      }
    });
    for (const [id, mesh] of workerMeshes) {
      if (live.has(id)) continue;
      scene.remove(mesh); workerMeshes.delete(id);
      const line = flowLines.get(id);
      if (line) { scene.remove(line); line.geometry.dispose(); line.material.dispose(); flowLines.delete(id); }
    }
  }

  function syncBoxes(dt) {
    const live = new Set();
    for (const b of sim.state.boxes) {
      live.add(b.id);
      let mesh = boxMeshes.get(b.id);
      if (!mesh) { mesh = parcelMesh(); mesh.position.set(b.x, b.y, b.z); scene.add(mesh); boxMeshes.set(b.id, mesh); }
      mesh.position.x = THREE.MathUtils.lerp(mesh.position.x, b.x, Math.min(1, dt * 13));
      mesh.position.y = THREE.MathUtils.lerp(mesh.position.y, b.y, Math.min(1, dt * 13));
      mesh.position.z = THREE.MathUtils.lerp(mesh.position.z, b.z, Math.min(1, dt * 13));
      let c = 0xd39a59;
      if (b.phase === 'packing') c = 0xffbe4d;
      else if (b.phase === 'packed' || b.phase === 'carried_ship') c = 0x66dc96;
      const m = mesh.children[0]?.material;
      if (m) {
        m.color.setHex(c);
        m.emissive.setHex(c);
        m.emissiveIntensity = flowMode ? 0.12 : 0.012;
      }
      if (b.phase.startsWith('carried_')) mesh.rotation.y += dt * 1.4;
      else mesh.rotation.y = THREE.MathUtils.lerp(mesh.rotation.y, 0, Math.min(1, dt * 4));
    }
    for (const [id, mesh] of boxMeshes) if (!live.has(id)) { scene.remove(mesh); boxMeshes.delete(id); }
  }

  function updateAutomationVisuals(dt) {
    const scale = Math.max(0, sim.state.timeScale || 0);
    automationClock += dt * scale;
    forkliftPulse = THREE.MathUtils.lerp(forkliftPulse, 0, Math.min(1, dt * 2.5));
    agvPulse = THREE.MathUtils.lerp(agvPulse, 0, Math.min(1, dt * 2.8));
    sorterPulse = THREE.MathUtils.lerp(sorterPulse, 0, Math.min(1, dt * 3.2));

    const forkliftStart = { x: POS.inbound.x + 0.45, z: POS.inbound.z - 0.45 };
    const forkliftEnd = { x: POS.rack.x - 1.4, z: POS.rack.z + 0.8 };
    const forkliftAngle = Math.atan2(forkliftEnd.x - forkliftStart.x, forkliftEnd.z - forkliftStart.z);
    forklifts.forEach((unit, index) => {
      if (!unit.visible) return;
      const phase = (automationClock * (0.085 + (sim.state.upgrades.forklift || 0) * 0.01) + index * 0.22) % 1;
      const forward = phase < 0.5;
      const t = forward ? phase * 2 : (1 - phase) * 2;
      unit.position.set(
        THREE.MathUtils.lerp(forkliftStart.x, forkliftEnd.x, t),
        0.02 + forkliftPulse * 0.025,
        THREE.MathUtils.lerp(forkliftStart.z, forkliftEnd.z, t) + index * 0.08
      );
      unit.rotation.y = forward ? forkliftAngle : forkliftAngle + Math.PI;
      unit.userData.pallet.position.y = 0.27 + Math.sin((automationClock + index) * 5) * 0.012;
      unit.userData.body.material.emissive.setHex(forkliftPulse > 0.12 ? 0x5f3510 : 0x000000);
      unit.userData.body.material.emissiveIntensity = forkliftPulse * 0.38;
    });

    const agvStart = { x: POS.rack.x + 0.55, z: POS.rack.z + 0.25 };
    const agvEnd = { x: POS.pack.x - 0.7, z: POS.pack.z - 0.35 };
    const agvAngle = Math.atan2(agvEnd.x - agvStart.x, agvEnd.z - agvStart.z);
    agvs.forEach((unit, index) => {
      if (!unit.visible) return;
      const phase = (automationClock * (0.11 + (sim.state.upgrades.agv || 0) * 0.012) + index * 0.24) % 1;
      const forward = phase < 0.5;
      const t = forward ? phase * 2 : (1 - phase) * 2;
      unit.position.set(
        THREE.MathUtils.lerp(agvStart.x, agvEnd.x, t),
        0.04 + agvPulse * 0.018,
        THREE.MathUtils.lerp(agvStart.z, agvEnd.z, t) - index * 0.09
      );
      unit.rotation.y = forward ? agvAngle : agvAngle + Math.PI;
      const glow = 0.55 + agvPulse * 1.4 + Math.sin((automationClock + index) * 8) * 0.12;
      unit.userData.lightA.material.emissiveIntensity = glow;
      unit.userData.lightB.material.emissiveIntensity = glow;
    });

    sorters.forEach((unit, index) => {
      if (!unit.visible) return;
      const speed = 4.5 + (sim.state.upgrades.sorter || 0) * 1.2;
      unit.userData.rollers.forEach((roller) => { roller.rotation.x += dt * scale * speed; });
      unit.userData.diverter.rotation.y = -0.42 + Math.sin((automationClock + index * 0.4) * 3.8) * (0.08 + sorterPulse * 0.16);
      unit.userData.scanner.material.emissiveIntensity = 0.5 + sorterPulse * 1.2 + Math.sin((automationClock + index) * 6) * 0.08;
    });
  }

  function updateTruckVisuals(dt) {
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

  function heat(material, ratio) {
    if (!material?.emissive) return;
    const r = Math.max(0, ratio || 0);
    material.emissive.setHex(r >= 1 ? 0xff5151 : r >= 0.72 ? 0xffb347 : 0x48cf8d);
    material.emissiveIntensity = (flowMode ? 0.16 : 0.018) + Math.max(0, r - 0.5) * (flowMode ? 0.48 : 0.16);
  }

  function updateHeat() {
    const r = sim.state.director?.ratios || {};
    const c = sim.counts();
    heat(inbound.userData.base.material, r.inbound || 0);
    heat(pack.userData.base.material, Math.max(r.orders || 0, c.packing / 3));
    heat(outbound.userData.base.material, Math.max(r.packed || 0, c.packed / 4));
    rackBanks.forEach((b) => heat(b.userData.shelfMaterial, r.rack || 0));
  }

  function updateOverflow(dt) {
    physics.timestep = Math.min(1 / 30, Math.max(1 / 120, dt));
    physics.step();
    const now = performance.now();
    for (let i = overflow.length - 1; i >= 0; i -= 1) {
      const item = overflow[i];
      const p = item.body.translation(); const q = item.body.rotation();
      item.mesh.position.set(p.x, p.y, p.z); item.mesh.quaternion.set(q.x, q.y, q.z, q.w);
      if (now - item.born > 10000 || p.y < -2) { removeOverflow(item); overflow.splice(i, 1); }
    }
  }

  function updateShipmentBursts(dt) {
    for (let i = shipmentBursts.length - 1; i >= 0; i -= 1) {
      const burst = shipmentBursts[i];
      burst.userData.life -= dt * 1.65;
      const t = 1 - Math.max(0, burst.userData.life);
      burst.scale.setScalar(1 + t * 1.5);
      burst.position.y = 0.08 + t * 0.22;
      burst.children.forEach((child) => {
        if (child.material) child.material.opacity = Math.max(0, burst.userData.life) * 0.8;
      });
      if (burst.userData.life <= 0) {
        scene.remove(burst);
        burst.children.forEach((child) => {
          child.geometry?.dispose?.();
          child.material?.dispose?.();
        });
        shipmentBursts.splice(i, 1);
      }
    }
  }

  function setFlowMode(enabled) {
    flowMode = Boolean(enabled);
    grid.material.opacity = flowMode ? 0.38 : 0.28;
    flowFloorGuide.visible = flowMode;
    if (!flowMode) for (const line of flowLines.values()) line.visible = false;
  }

  function updateFlowFloorGuide(dt) {
    if (!flowMode) return;
    flowGuideClock = (flowGuideClock + dt * 0.32) % 1;
    for (const arrow of flowFloorGuide.userData.flowArrows || []) {
      const path = arrow.userData.flowPath;
      const t = (path.offset + flowGuideClock) % 1;
      arrow.position.x = path.ax + path.dx * t;
      arrow.position.z = path.az + path.dz * t;
      const pulse = 0.5 + Math.sin((t + flowGuideClock) * Math.PI * 2) * 0.5;
      arrow.material.opacity = 0.48 + pulse * 0.28;
      arrow.scale.setScalar(0.54 + pulse * 0.08);
    }
  }

  function update(dt) {
    updateGrowth(dt);
    updateCamera(dt);
    syncWorkers(dt);
    syncBoxes(dt);
    updateAutomationVisuals(dt);
    asrsVisual.update(dt);
    updateTruckVisuals(dt);
    updateFlowFloorGuide(dt);
    updateHeat();
    updateOverflow(dt);
    updateShipmentBursts(dt);
    conveyors.forEach((c) => {
      if (c.visible) c.userData.rollers.forEach((r) => { r.rotation.x += dt * Math.max(0, sim.state.timeScale || 0) * 4.5; });
    });
    outboundPulse = THREE.MathUtils.lerp(outboundPulse, 0, Math.min(1, dt * 3.5));
    outbound.scale.setScalar(1 + outboundPulse * 0.055);
    if (outbound.userData.lamp) outbound.userData.lamp.material.emissiveIntensity = 0.72 + outboundPulse * 1.1;
    gates.forEach((g) => {
      if (g.userData.lamp) g.userData.lamp.material.emissiveIntensity = 0.6 + outboundPulse * 0.8;
    });
    renderer.render(scene, camera);
  }

  function resize() {
    camera.aspect = innerWidth / innerHeight;
    camera.updateProjectionMatrix();
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.25));
    renderer.setSize(innerWidth, innerHeight, false);
  }
  addEventListener('resize', resize, { passive: true });
  resetCamera();
  return { update, resetCamera, setFlowMode, isFlowMode: () => flowMode };
}