#!/usr/bin/env node
'use strict';
// Browser lifecycle unit test with an explicit DOM mock; not a WebGL pass.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const script = fs.readFileSync(process.argv[2] || path.resolve(__dirname, '../../campaign-viewport.js'), 'utf8');
let checks = 0;
for (const dpr of [1, 1.25, 2, 3]) {
  const frames = [];
  const events = new Map();
  const visualEvents = new Map();
  const queries = [];
  const insets = { left: 0, right: 0, top: 0, bottom: 0 };
  let heightProperty = '844px';
  let writes = 0;
  let width = 300;
  let height = 150;
  let observer;
  const window = {
    innerWidth: 390, innerHeight: 844, devicePixelRatio: dpr,
    visualViewport: { height: 844, scale: 1, addEventListener: (name, cb) => visualEvents.set(name, cb) },
    addEventListener: (name, cb) => events.set(name, cb),
    matchMedia: query => {
      const result = { query, addEventListener: (name, cb, options) => { result.callback = cb; result.options = options; } };
      queries.push(result);
      return result;
    },
  };
  const canvas = {
    get width() { return width; }, set width(value) { writes++; width = value; },
    get height() { return height; }, set height(value) { writes++; height = value; },
    getBoundingClientRect: () => ({ x: insets.left, y: insets.top, width: window.innerWidth - insets.left - insets.right, height: parseFloat(heightProperty) - insets.top - insets.bottom }),
  };
  const document = { getElementById: id => id === 'canvas' ? canvas : null, documentElement: { style: { setProperty: (name, value) => { assert.equal(name, '--flotra-visible-height'); heightProperty = value; } } } };
  class ResizeObserver { constructor(callback) { observer = callback; } observe(node) { assert.equal(node, canvas); } }
  window.ResizeObserver = ResizeObserver;
  const context = { window, document, ResizeObserver, requestAnimationFrame: callback => frames.push(callback) };
  vm.createContext(context);
  vm.runInContext(script, context);
  const flush = () => { while (frames.length) frames.shift()(); };
  const metrics = () => window.FlotraViewport.read();
  assert.equal(metrics().width, 390);
  assert.equal(metrics().height, 844);
  assert.equal(width, Math.round(390 * dpr));
  assert.equal(height, Math.round(844 * dpr));
  checks += 4;
  // The bridge observes only real DOM mouse state, without changing input or
  // canvas geometry. It recovers a missing release even when Godot's internal
  // mouse-motion mask still reports the previous press.
  assert.equal(window.FlotraViewport.mouseButtons, -1, 'Unknown mouse state starts unset');
  events.get('pointerdown')({pointerType: 'mouse', buttons: 1});
  assert.equal(window.FlotraViewport.mouseButtons, 1, 'Mouse down is observed');
  events.get('pointermove')({pointerType: 'touch', buttons: 0});
  assert.equal(window.FlotraViewport.mouseButtons, 1, 'Touch cannot overwrite mouse state');
  events.get('pointermove')({pointerType: 'mouse', buttons: 0});
  assert.equal(window.FlotraViewport.mouseButtons, 0, 'Hover recovers a missed mouse release');
  events.get('pointerdown')({pointerType: 'mouse', buttons: 1});
  events.get('pointercancel')({pointerType: 'mouse', buttons: 1});
  assert.equal(window.FlotraViewport.mouseButtons, 0, 'Canceled mouse cannot remain held');
  events.get('pointerdown')({pointerType: 'mouse', buttons: 1});
  events.get('blur')();
  assert.equal(window.FlotraViewport.mouseButtons, 0, 'Window blur clears observed mouse buttons');
  assert.equal(Object.getOwnPropertyDescriptor(window.FlotraViewport, 'mouseButtons').set, undefined, 'Mouse observation is read-only');
  checks += 7;
  const originalWrites = writes;
  events.get('resize')(); events.get('orientationchange')(); observer();
  assert.equal(frames.length, 1, 'Resize events coalesce into one animation frame');
  flush();
  assert.equal(writes, originalWrites, 'Unchanged size never clears the existing canvas buffer');
  checks += 2;
  window.visualViewport.height = 624;
  visualEvents.get('resize')(); flush();
  assert.equal(metrics().height, 624, 'Dynamic browser toolbar/keyboard height is respected');
  insets.top = 47; insets.bottom = 34; insets.left = 12; insets.right = 12;
  observer(); flush();
  assert.deepEqual([metrics().x, metrics().y, metrics().width, metrics().height], [12, 47, 366, 543], 'Canvas CSS safe-area rectangle is the metric authority');
  checks += 2;
  // Pinch zoom must not shrink/reflow the logical UI and double-apply zoom.
  window.visualViewport.scale = 2;
  window.visualViewport.height = 312;
  visualEvents.get('scroll')(); flush();
  assert.equal(metrics().height, 763, 'Pinch-zoom viewport does not replace layout height');
  window.visualViewport.scale = 1;
  window.visualViewport.height = 844;
  visualEvents.get('resize')(); flush();
  const oldQuery = queries.at(-1);
  window.devicePixelRatio = dpr === 3 ? 2 : 3;
  oldQuery.callback(); flush();
  assert.equal(metrics().dpr, window.devicePixelRatio, 'DPR-only changes update the backing buffer');
  assert.equal(width, Math.round(366 * window.devicePixelRatio));
  assert.equal(height, Math.round(763 * window.devicePixelRatio));
  assert.equal(oldQuery.options.once, true, 'DPR listener is consumed once before re-subscribing');
  assert.equal(queries.length, 2, 'DPR watcher re-subscribes at the new resolution');
  checks += 6;
  window.innerWidth = 844; window.innerHeight = 390; window.visualViewport.height = 390;
  events.get('orientationchange')(); flush();
  assert.deepEqual([metrics().width, metrics().height], [820, 309], 'Orientation is measured in current CSS pixels');
  checks++;
}
console.log(`REVIEW_VIEWPORT_BRIDGE ${checks} checks passed (explicit DOM mock)`);
