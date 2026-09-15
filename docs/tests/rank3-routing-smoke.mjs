import assert from 'node:assert/strict';
import { createSimulation } from '../src/sim.js';
import { routingRevenue } from '../src/routing-model.js';
import { currentUnitRevenue } from '../src/capital-model.js';

function rank3Snapshot(overrides = {}) {
  return {
    schema_version: 3,
    money: 1000000,
    research: 0,
    logisticsRating: 8,
    facilityRank: 3,
    facilities: {
      secondInbound: true,
      bufferYard: false,
      fastPickRack: true,
      highDensityRack: false,
      secondPack: true,
      fastPackCell: false,
    },
    staffingPlan: 'balanced',
    shipped: 0,
    completedContracts: 0,
    milestoneAwarded: 0,
    policy: 'balanced',
    routingMode: 'balanced',
    priorities: { store: 3, pick: 3, ship: 4 },
    upgrades: {
      worker: 0,
      speed: 0,
      rack: 0,
      pack: 0,
      conveyor: 0,
      forklift: 0,
      agv: 0,
      sorter: 0,
      hall: 0,
      truckDock: 0,
      asrs: 0,
    },
    perks: { smartDispatch: 0, bulkPack: 0, contractBonus: 0 },
    ...overrides,
  };
}

function addRoutingBoxes(sim, amount) {
  sim.state.boxes.splice(0);
  sim.state.workers.splice(0);
  sim.state.ordersOpen = 100;
  for (let i = 0; i < amount; i += 1) {
    sim.state.boxes.push({
      id: 1000 + i,
      phase: 'routing',
      reservedBy: null,
      rackSlot: null,
      packRemaining: 0,
      carrierId: null,
      x: 5,
      y: 0.3,
      z: -2.3,
    });
  }
}

function runRoute(mode, seconds = 20) {
  const sim = createSimulation(rank3Snapshot({ routingMode: mode }));
  addRoutingBoxes(sim, 30);
  const events = [];
  sim.onEvent((event) => events.push(event));
  const beforeMoney = sim.state.money;
  const beforeShipped = sim.state.shipped;
  for (let t = 0; t < seconds; t += 0.05) sim.update(0.05);
  const shipments = events.filter((event) => event.type === 'shipment');
  const dispatches = events.filter((event) => event.type === 'route_dispatch');
  const moneyDelta = sim.state.money - beforeMoney;
  const shippedDelta = sim.state.shipped - beforeShipped;
  assert.equal(shippedDelta, shipments.length, `${mode}: shipment event count must match authoritative shipped delta`);
  assert.equal(moneyDelta, shipments.reduce((sum, event) => sum + event.value, 0), `${mode}: shipment values must exactly match money delta`);
  assert.equal(moneyDelta, dispatches.reduce((sum, event) => sum + event.value, 0), `${mode}: route dispatch values must not double-count revenue`);
  return { sim, events, shipments, dispatches, moneyDelta, shippedDelta };
}

// Workers and sorter may stage freight, but Rank 3 routing owns the actual shipment/revenue boundary.
{
  const sim = createSimulation(rank3Snapshot({ upgrades: { ...rank3Snapshot().upgrades, sorter: 1 } }));
  sim.state.boxes.splice(0);
  sim.state.workers.splice(0);
  sim.state.ordersOpen = 1;
  sim.state.boxes.push({ id: 999, phase: 'packed', reservedBy: null, rackSlot: null, packRemaining: 0, carrierId: null, x: 3.1, y: 0.3, z: -1.25 });
  const startMoney = sim.state.money;
  sim.update(0.05);
  assert.equal(sim.state.shipped, 0, 'sorter must not bypass the Rank 3 routing gate');
  assert.equal(sim.state.money, startMoney, 'staging into routing must not create revenue');
  assert.equal(sim.state.boxes.some((box) => box.phase === 'routing'), true, 'sorter should stage the parcel in routing');
  for (let t = 0; t < 4.3; t += 0.05) sim.update(0.05);
  assert.equal(sim.state.shipped, 1, 'Balanced routing should eventually release the staged parcel');
}

const balanced = runRoute('balanced');
const express = runRoute('express');
const consolidated = runRoute('consolidated');

assert.ok(express.shippedDelta > balanced.shippedDelta, `Express should clear more parcels in the same window (${express.shippedDelta} <= ${balanced.shippedDelta})`);
assert.ok(consolidated.dispatches.length > 0, 'Consolidated must dispatch real batches');
assert.ok(consolidated.dispatches.every((event) => event.amount === 3), 'Consolidated dispatches must release three parcels at a time');
assert.ok(consolidated.shippedDelta < express.shippedDelta, 'Consolidated should trade clearance speed for margin in this fixed observation window');

const baseRevenue = currentUnitRevenue(rank3Snapshot().upgrades);
const balancedUnit = routingRevenue(baseRevenue, 'balanced');
const expressUnit = routingRevenue(baseRevenue, 'express');
const consolidatedUnit = routingRevenue(baseRevenue, 'consolidated');
assert.ok(expressUnit < balancedUnit, 'Express must have lower unit margin than Balanced');
assert.ok(consolidatedUnit > balancedUnit, 'Consolidated must have higher unit margin than Balanced');
assert.equal(express.shipments[0]?.value, expressUnit, 'Express shipment event must use route economics');
assert.equal(consolidated.shipments[0]?.value, consolidatedUnit, 'Consolidated shipment event must use route economics');

const routeChanged = balanced.sim.setRoutingMode('express');
assert.equal(routeChanged.ok, true, 'Rank 3 should allow switching routing package');
const saved = balanced.sim.serialize();
assert.equal(saved.routingMode, 'express', 'routing mode must serialize');
const restored = createSimulation(saved);
assert.equal(restored.state.routingMode, 'express', 'routing mode must survive hydration');
assert.equal(restored.state.facilityRank, 3, 'routing save/load must preserve Rank 3');
assert.equal(restored.state.completedContracts, 0, 'routing must not turn contracts into a hidden requirement');

console.log(`Rank 3 routing smoke passed: balanced=${balanced.shippedDelta}, express=${express.shippedDelta}, consolidated=${consolidated.shippedDelta}`);
