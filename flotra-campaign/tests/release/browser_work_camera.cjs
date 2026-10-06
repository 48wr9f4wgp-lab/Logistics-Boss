#!/usr/bin/env node
'use strict';
// Real Chromium/WebGL input into the exported game. Only initial, domain-earned
// fixture bytes are written, in a new isolated context; all diagnostics are read
// only. No engine commands, camera setters, frame gates or fake gameplay ticks.
// CHROMIUM_EXECUTABLE=/usr/bin/chromium node browser_work_camera.cjs URL OUTPUT FIXTURES [EXPORTED_DIRECTORY]
// FLOTRA_TEST_CASES=320x568,375x567,390x844,430x932,568x320 FLOTRA_TEST_DPRS=1,2,3
// CSS viewport/DPR emulation is not physical iPhone/Safari qualification.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const [requestedURL, output, fixturesDirectory, exportedDirectory] = process.argv.slice(2);
assert.ok(requestedURL && output && fixturesDirectory, 'Usage: browser_work_camera.cjs URL OUTPUT FIXTURES [EXPORTED_DIRECTORY]');
const target = new URL(requestedURL); target.searchParams.set('phone_qa', '1');
const url = target.href, saveKey = 'flotra.campaign.release.v1';
const fixture = JSON.parse(fs.readFileSync(path.join(fixturesDirectory, 'late.json'), 'utf8'));
assert.ok(typeof fixture.encoded === 'string' && fixture.status === 'running', 'Validated mature in-flight fixture is required');
const allCases = [[320, 568], [375, 567], [390, 844], [430, 932], [568, 320]];
const selected = process.env.FLOTRA_TEST_CASES?.split(',');
if (selected) assert.ok(selected.every(value => allCases.some(pair => pair.join('x') === value)), 'Every selected work-camera viewport is supported');
const cases = selected ? allCases.filter(pair => selected.includes(pair.join('x'))) : allCases;
const dprs = process.env.FLOTRA_TEST_DPRS ? process.env.FLOTRA_TEST_DPRS.split(',').map(Number) : [1, 2, 3];
assert.ok(cases.length && dprs.length && dprs.every(value => Number.isFinite(value) && value >= 1), 'A nonempty viewport/DPR matrix is required');
fs.mkdirSync(output, {recursive: true});
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const assetNames = ['index.html', 'index.pck', 'index.js', 'index.wasm', 'campaign-viewport.js', 'campaign-storage.js'];
const expectedAssets = exportedDirectory ? Object.fromEntries(assetNames.map(name => [name, hash(fs.readFileSync(path.join(exportedDirectory, name)))])) : null;
const report = {kind: 'Actual Chromium WebGL work-camera regression; CSS viewport/DPR emulation, not physical iPhone/Safari',
  url, startedAt: new Date().toISOString(), configuration: {cases, dprs}, harnessSha256: hash(fs.readFileSync(__filename)),
  fixtureSha256: hash(fixture.encoded), expectedExportAssets: expectedAssets, results: []};
const saveReport = () => fs.writeFileSync(path.join(output, 'browser-work-camera.json'), JSON.stringify(report, null, 2));
const cameraNames = ['CameraLeft', 'CameraRight', 'CameraOut', 'CameraIn', 'CameraWork', 'CameraReset'];
const poseKeys = ['framing', 'zoom', 'turn', 'panX', 'panY', 'size', 'fitSize'];
const domainKeys = ['wallet', 'upgrades', 'currentContract', 'status', 'simTime', 'progress', 'results', 'growth',
  'preferences', 'operation', 'layout', 'speed', 'trialRunning', 'currentBest', 'jobComparison'];
const ui = page => page.evaluate(() => window.FlotraViewport?.uiMetrics);
const pose = camera => Object.fromEntries(poseKeys.map(key => [key, camera[key]]));
const domain = state => Object.fromEntries(domainKeys.map(key => [key, state[key]]));
const saved = page => page.evaluate(key => ({primary: localStorage.getItem(key), backup: localStorage.getItem(key + '.backup'),
  keys: Object.keys(localStorage).sort()}), saveKey);
const closeEnough = (actual, expected, label, tolerance = .001) => assert.ok(Number.isFinite(actual) && Math.abs(actual - expected) <= tolerance, `${label}: ${actual} != ${expected}`);
const cdpSessions = new WeakMap();
async function session(page, context) {
  if (!cdpSessions.has(page)) cdpSessions.set(page, await context.newCDPSession(page));
  return cdpSessions.get(page);
}
async function dispatch(page, context, type, points) {
  await (await session(page, context)).send('Input.dispatchTouchEvent', {type, touchPoints: points});
}
async function refreshedDiagnostics(page) {
  // Godot publishes metrics on its own rendered-frame cadence. A fixed sleep
  // can still read the pre-release object on a busy DPR3 software renderer.
  // Observe two new engine reports after the action without repeating input.
  const after = await page.evaluate(() => window.__flotraWorkTrace.qaUpdates);
  await page.waitForFunction(after => window.__flotraWorkTrace.qaUpdates >= after + 2, after, {timeout: 10000});
}
async function expectCamera(page, expected) {
  await page.waitForFunction(expected => {
    const camera = window.FlotraViewport?.uiMetrics?.camera;
    return camera && Object.entries(expected).every(([key, value]) => camera[key] === value);
  }, expected, {timeout: 10000});
}
async function measure(page) {
  return page.evaluate(() => {
    const canvas = document.querySelector('#canvas');
    return {viewport: {width: innerWidth, height: innerHeight, dpr: devicePixelRatio, visualScale: visualViewport?.scale},
      canvas: {width: canvas.width, height: canvas.height, rect: canvas.getBoundingClientRect().toJSON()},
      bridge: window.FlotraViewport?.read(), engine: window.FlotraViewport?.engineMetrics};
  });
}
async function settle(page) {
  await page.waitForFunction(() => {
    const canvas = document.querySelector('#canvas'), engine = window.FlotraViewport?.engineMetrics;
    if (!canvas || !engine) return false;
    const rect = canvas.getBoundingClientRect();
    return Math.abs(engine.logicalWidth - Math.round(rect.width)) <= 1 && Math.abs(engine.logicalHeight - Math.round(rect.height)) <= 1 &&
      engine.rootWidth === canvas.width && engine.rootHeight === canvas.height;
  }, null, {timeout: 15000});
  await refreshedDiagnostics(page);
}
function verifyViewport(m, width, height, dpr, label) {
  assert.ok(m.bridge && m.engine, `${label}: actual engine and viewport metrics exist`);
  closeEnough(m.viewport.width, width, `${label}: configured CSS width`);
  closeEnough(m.viewport.height, height, `${label}: configured CSS height`);
  closeEnough(m.viewport.dpr, dpr, `${label}: configured DPR`);
  const r = m.canvas.rect, e = m.engine;
  assert.ok(r.width > 0 && r.height > 0 && r.x >= 0 && r.y >= 0 && r.right <= width + 1 && r.bottom <= height + 1, `${label}: nonempty canvas stays in viewport`);
  closeEnough(m.canvas.width, Math.round(r.width * dpr), `${label}: full-DPR backing width`, 1);
  closeEnough(m.canvas.height, Math.round(r.height * dpr), `${label}: full-DPR backing height`, 1);
  for (const [key, value] of [['logicalWidth', r.width], ['hudWidth', r.width], ['logicalHeight', r.height], ['hudHeight', r.height], ['rootWidth', m.canvas.width], ['rootHeight', m.canvas.height]])
    closeEnough(e[key], value, `${label}: ${key}`, 1);
  closeEnough(m.bridge.width, r.width, `${label}: CSS bridge width`, 1);
  closeEnough(m.bridge.height, r.height, `${label}: CSS bridge height`, 1);
  closeEnough(e.scaleX, m.canvas.width / e.logicalWidth, `${label}: engine X scaling`, .02);
  closeEnough(e.scaleY, m.canvas.height / e.logicalHeight, `${label}: engine Y scaling`, .02);
  closeEnough(m.viewport.visualScale, 1, `${label}: browser is not zoomed`, .01);
}
function overlaps(a, b) {
  return Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x) > .01 &&
    Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y) > .01;
}
function verifyControls(state, m, label) {
  const controls = state.buttons.filter(button => button.visible && cameraNames.includes(button.name));
  assert.deepEqual(controls.map(button => button.name).sort(), [...cameraNames].sort(), `${label}: all six distinct camera controls are visible`);
  for (const button of controls) {
    assert.equal(button.disabled, false, `${label}: ${button.name} enabled`);
    assert.ok(button.width >= 55.99 && button.height >= 56 && button.fontSize >= 18, `${label}: ${button.name} has 56px target / 18px type (0.01px width float tolerance)`);
    assert.ok(button.x >= 0 && button.y >= 0 && button.x + button.width <= m.canvas.rect.width + .01 && button.y + button.height <= m.canvas.rect.height + .01, `${label}: ${button.name} stays inside the HUD`);
    assert.ok(!overlaps(button, state.worldRect), `${label}: ${button.name} does not cover the rendered warehouse`);
    for (const other of state.buttons.filter(item => item.visible && item.name !== button.name))
      assert.ok(!overlaps(button, other), `${label}: ${button.name} does not overlap ${other.name}`);
  }
}
function equipmentRect(camera, id) {
  const found = camera.equipmentBounds?.filter(item => item.id === id);
  assert.equal(found?.length, 1, `One actual projected ${id} AABB is exposed`);
  const corners = found[0].corners;
  assert.equal(corners.length, 8, `${id}: all eight physical equipment corners are exposed`);
  assert.ok(corners.every(point => Number.isFinite(point.x) && Number.isFinite(point.y)), `${id}: physical corners are finite`);
  const xs = corners.map(point => point.x), ys = corners.map(point => point.y);
  return {x: Math.min(...xs), y: Math.min(...ys), width: Math.max(...xs) - Math.min(...xs), height: Math.max(...ys) - Math.min(...ys), corners};
}
function verifyWork(state, label) {
  assert.equal(state.sheet, '', `${label}: warehouse is unobscured`);
  assert.equal(state.worldVisible, true, `${label}: actual 3D viewport is visible`);
  assert.equal(state.selectedSlot, '', `${label}: equipment editor is closed`);
  assert.equal(state.camera.framing, 'work', `${label}: work preset remains selected`);
  assert.ok(state.camera.zoom >= 1.4 && state.camera.zoom <= 3, `${label}: mature work view is meaningfully enlarged within original zoom bounds`);
  const world = state.worldRect;
  for (const id of ['shelf', 'packing']) {
    const rect = equipmentRect(state.camera, id), point = state.slots[id];
    assert.ok(rect.width > 0 && rect.height > 0, `${label}: ${id} has nonempty projected physical extent`);
    for (const [index, corner] of rect.corners.entries()) assert.ok(corner.x >= world.x + 2 && corner.y >= world.y + 2 &&
      corner.x <= world.x + world.width - 2 && corner.y <= world.y + world.height - 2, `${label}: entire actual ${id} corner ${index} fits with 2px inset`);
    assert.ok(point && point.x > world.x && point.x < world.x + world.width && point.y > world.y && point.y < world.y + world.height, `${label}: actual ${id} pick target is onscreen`);
  }
  assert.equal(state.camera.touches, 0, `${label}: no held world touches`);
  assert.equal(state.camera.mouseDown, false, `${label}: no held mouse`);
}
async function expectUI(page, expected) {
  await page.waitForFunction(expected => {
    const state = window.FlotraViewport?.uiMetrics;
    return state && Object.entries(expected).every(([key, value]) => state[key] === value);
  }, expected, {timeout: 10000});
  await page.waitForTimeout(250); // Allow the actual post-sheet stale-input guard.
}
async function buttonPoint(page, name) {
  await page.waitForFunction(name => window.FlotraViewport?.uiMetrics?.buttons.some(button => button.name === name && button.visible && !button.disabled), name, {timeout: 10000});
  const state = await ui(page), control = state.buttons.find(button => button.name === name && button.visible), m = await measure(page);
  assert.ok(control.width >= 55.99 && control.height >= 56 && control.fontSize >= 18, `${name}: readable real touch target (0.01px width float tolerance)`);
  const x = control.x + control.width / 2, y = control.y + control.height / 2;
  assert.ok(x > 0 && x < m.canvas.rect.width && y > 0 && y < m.canvas.rect.height, `${name}: actual touch point is inside canvas`);
  return {x: m.canvas.rect.x + x, y: m.canvas.rect.y + y};
}
async function touch(page, context, point) {
  await dispatch(page, context, 'touchStart', [{id: 0, ...point}]);
  await page.waitForTimeout(100);
  await dispatch(page, context, 'touchEnd', []);
  await refreshedDiagnostics(page);
}
async function tap(page, context, name) {
  console.log(`WORK CAMERA TOUCH ${name}`);
  const before = (await ui(page)).camera;
  await touch(page, context, await buttonPoint(page, name));
  if (name === 'CameraReset') await expectCamera(page, {framing: 'overview', turn: 0, zoom: 1, panX: 0, panY: 0});
  else if (name === 'CameraWork') await expectCamera(page, {framing: 'work', turn: before.turn});
  else if (name === 'CameraRight' || name === 'CameraLeft') await expectCamera(page, {
    turn: (before.turn + (name === 'CameraRight' ? 1 : 3)) % 4,
    framing: before.framing === 'work' ? 'work' : (before.zoom === 1 ? 'overview' : 'manual'),
  });
}
async function closeSheets(page, context) {
  for (let attempt = 0; attempt < 4 && (await ui(page)).sheet; attempt++) {
    const previous = (await ui(page)).sheet;
    await tap(page, context, 'CloseSheet');
    await page.waitForFunction(previous => window.FlotraViewport.uiMetrics.sheet !== previous, previous);
  }
  await expectUI(page, {sheet: '', trialRunning: false});
}
async function invariant(page, baseline, result, label, lifecycle = false) {
  const storage = await saved(page);
  assert.equal(storage.primary, baseline.storage.primary, `${label}: exact prior encoded campaign save is preserved`);
  assert.deepEqual(domain(await ui(page)), baseline.domain, `${label}: complete observable gameplay state is preserved`);
  if (lifecycle) assert.ok(storage.backup === baseline.storage.backup || storage.backup === baseline.storage.primary, `${label}: lifecycle backup can only rotate the identical prior save`);
  else assert.equal(storage.backup, baseline.storage.backup, `${label}: prior backup is unchanged`);
  assert.ok(storage.keys.every(key => key === saveKey || key === saveKey + '.backup'), `${label}: no camera/session data added to localStorage`);
  result.invariants.push(label);
}
async function installTrace(context) {
  await context.addInitScript(() => {
    // Passive browser observations only: these samples never write to the game,
    // its diagnostics, its storage, its clock, or its requestAnimationFrame.
    const trace = window.__flotraWorkTrace = {frames: 0, qaUpdates: 0, events: [], samples: []};
    let previous;
    function observe() {
      trace.frames++;
      const state = window.FlotraViewport?.uiMetrics;
      if (state?.camera && state !== previous) {
        previous = state; trace.qaUpdates++;
        const camera = Object.fromEntries(['framing', 'zoom', 'turn', 'panX', 'panY', 'size', 'fitSize'].map(key => [key, state.camera[key]]));
        trace.samples.push({camera, equipmentBounds: state.camera.equipmentBounds, simTime: state.simTime, running: state.trialRunning});
      }
      requestAnimationFrame(observe);
    }
    requestAnimationFrame(observe);
    for (const type of ['touchstart', 'touchmove', 'touchend', 'touchcancel']) window.addEventListener(type, event => {
      trace.events.push({type, trusted: event.isTrusted, frames: trace.frames, qaUpdates: trace.qaUpdates, ms: performance.now()});
    }, {capture: true, passive: true});
  });
}
async function installAssetIdentity(page, context, result) {
  if (!expectedAssets) return {checkpoint: async () => {}};
  const exportBase = new URL('.', url), captures = [], completions = [], loaded = [], finished = [];
  let loadedCursor = 0, finishedCursor = 0;
  function assetName(requestURL) {
    const actual = new URL(requestURL);
    if (actual.origin !== exportBase.origin) return null;
    return assetNames.find(name => actual.pathname === new URL(name, exportBase).pathname ||
      (name === 'index.html' && actual.pathname === exportBase.pathname)) || null;
  }
  result.assets = {checkpoints: []};
  if (!report.originAssets) {
    report.originAssets = {};
    for (const name of assetNames) {
      const assetURL = new URL(name, exportBase).href;
      const response = await context.request.get(assetURL, {timeout: 120000, headers: {'Cache-Control': 'no-cache'}});
      try {
        assert.equal(response.status(), 200, `${name}: independently fetched export asset returns HTTP 200`);
        const body = await response.body(), sha256 = hash(body);
        assert.equal(sha256, expectedAssets[name], `${name}: independent origin bytes match the local final export`);
        report.originAssets[name] = {url: response.url(), sha256, bytes: body.length};
      } finally {await response.dispose();}
    }
    assert.deepEqual(Object.keys(report.originAssets).sort(), [...assetNames].sort(), 'All six final export assets are independently verified at the origin');
  }
  // Read origin bytes before fulfilling each genuine page request. As in the
  // qualified growth journey, this avoids late response.body() reads from the
  // evictable DevTools cache for the large WASM. The verified buffers themselves
  // are delivered to the browser; nothing is substituted from local files.
  await context.route('**/*', route => {
    const name = assetName(route.request().url());
    if (!name) return route.continue();
    const capture = (async () => {
      try {
        const response = await route.fetch({timeout: 120000});
        assert.equal(response.status(), 200, `${name}: actual engine asset request returns HTTP 200`);
        const body = await response.body(), sha256 = hash(body);
        assert.equal(sha256, expectedAssets[name], `${name}: exact bytes delivered to engine match final local export`);
        await route.fulfill({response, body});
        loaded.push({name, url: route.request().url(), sha256, bytes: body.length});
      } catch (error) {result.errors.push(error.message); await route.abort().catch(() => {});}
    })();
    captures.push(capture);
    return capture;
  });
  page.on('response', response => {
    const name = assetName(response.url());
    if (name !== 'index.pck' && name !== 'index.wasm') return;
    const completion = (async () => {
      try {
        const failure = await response.finished();
        assert.equal(failure, null, `${name}: actual browser engine response completes`);
        assert.equal(response.status(), 200, `${name}: completed engine response is HTTP 200`);
        finished.push({name, url: response.url(), completed: true});
      } catch (error) {result.errors.push(error.message);}
    })();
    completions.push(completion);
  });
  return {checkpoint: async (label, completeLoad = true) => {
    // Await every body capture and browser completion before any reload, which
    // would otherwise discard the old document's network response resources.
    await Promise.all(captures); await Promise.all(completions);
    assert.deepEqual(result.errors, [], `${label}: export capture completed without errors`);
    if (!completeLoad) return;
    const records = loaded.slice(loadedCursor), completed = finished.slice(finishedCursor);
    assert.deepEqual([...new Set(records.map(record => record.name))].sort(), [...assetNames].sort(), `${label}: all six verified assets actually loaded`);
    assert.deepEqual([...new Set(completed.map(record => record.name))].sort(), ['index.pck', 'index.wasm'], `${label}: actual PCK and WASM browser responses both completed`);
    const engineBodies = completed.map(record => {
      const body = records.find(item => item.name === record.name && item.url === record.url);
      assert.ok(body, `${label}: completed ${record.name} has a captured actual response body`);
      return {...record, sha256: body.sha256, bytes: body.bytes};
    });
    result.assets.checkpoints.push({label, loaded: records, engineBodies});
    loadedCursor = loaded.length; finishedCursor = finished.length;
  }};
}
async function heldWork(page, context, canceled) {
  const point = await buttonPoint(page, 'CameraWork'), before = pose((await ui(page)).camera);
  assert.equal(before.framing, 'overview', 'Held Work starts from an actual Whole reset');
  const traceBefore = await page.evaluate(() => ({events: window.__flotraWorkTrace.events.length, samples: window.__flotraWorkTrace.samples.length}));
  await dispatch(page, context, 'touchStart', [{id: 0, ...point}]);
  await page.waitForTimeout(650);
  await page.waitForFunction(start => window.__flotraWorkTrace.samples.length >= start + 2, traceBefore.samples, {timeout: 10000});
  const held = await page.evaluate(before => ({events: window.__flotraWorkTrace.events.slice(before.events), samples: window.__flotraWorkTrace.samples.slice(before.samples)}), traceBefore);
  assert.ok(held.samples.length >= 2, 'Held Work crosses at least two actual engine diagnostic refreshes');
  for (const sample of held.samples) assert.deepEqual(sample.camera, before, 'Work never activates before release');
  await dispatch(page, context, canceled ? 'touchCancel' : 'touchEnd', []);
  await refreshedDiagnostics(page);
  if (!canceled) await expectCamera(page, {framing: 'work', turn: before.turn});
  const events = await page.evaluate(start => window.__flotraWorkTrace.events.slice(start), traceBefore.events);
  assert.deepEqual(events.map(event => event.type), ['touchstart', canceled ? 'touchcancel' : 'touchend'], 'Real browser event sequence is exact');
  assert.ok(events.every(event => event.trusted), 'All Work button touch events are browser-trusted');
  assert.ok(events[1].frames > events[0].frames && events[1].qaUpdates > events[0].qaUpdates && events[1].ms - events[0].ms >= 600, 'Work stayed held across live rendering and engine refresh');
  if (canceled) assert.deepEqual(pose((await ui(page)).camera), before, 'Canceled Work preserves the exact overview pose');
  else assert.equal((await ui(page)).camera.framing, 'work', 'Fresh held/released Work recovers after cancellation');
  assert.equal((await ui(page)).camera.touches, 0, 'Work release clears world touch ownership');
  return {canceled, events, heldEngineSamples: held.samples.length};
}
function verifyOverview(state, label) {
  assert.equal(state.sheet, '', `${label}: no accidental sheet`);
  assert.equal(state.selectedSlot, '', `${label}: no accidental equipment selection`);
  assert.equal(state.camera.framing, 'overview', `${label}: Whole remains selected`);
  assert.equal(state.camera.turn, 0, `${label}: original bearing remains selected`);
  assert.equal(state.camera.zoom, 1, `${label}: whole-warehouse zoom remains selected`);
  closeEnough(state.camera.panX, 0, `${label}: horizontal pan is zero`);
  closeEnough(state.camera.panY, 0, `${label}: vertical pan is zero`);
  closeEnough(state.camera.size, state.camera.fitSize, `${label}: camera fits the current viewport`);
  assert.equal(state.camera.touches, 0, `${label}: world touch ownership is clear`);
  assert.equal(state.camera.mouseDown, false, `${label}: no emulated mouse remains held`);
}
async function narrowBreakpoints(page, context, result, baseline, initial, dpr) {
  result.narrowBreakpoints = {viewports: []};
  for (const width of [320, 347, 348]) {
    await page.setViewportSize({width, height: 568}); await settle(page);
    const before = await ui(page), m = await measure(page), label = `${width}x568 breakpoint`;
    verifyViewport(m, width, 568, dpr, label);
    verifyControls(before, m, label); verifyWork(before, label);
    const controls = before.buttons.filter(button => button.visible && cameraNames.includes(button.name));
    assert.equal(new Set(controls.map(button => Math.round(button.y))).size, width < 348 ? 2 : 1, `${label}: camera controls use exactly the expected row count`);
    await tap(page, context, 'CameraReset');
    verifyOverview(await ui(page), `${label}: real Whole activation`);
    await tap(page, context, 'CameraWork');
    const restored = await ui(page);
    verifyWork(restored, `${label}: real Work activation`);
    assert.deepEqual(pose(restored.camera), pose(before.camera), `${label}: real Work returns to exact resized work pose`);
    assert.deepEqual(restored.camera.equipmentBounds, before.camera.equipmentBounds, `${label}: real Work returns to exact projected machine bounds`);
    await invariant(page, baseline, result, `${label}: resize and preset activation`);
    result.narrowBreakpoints.viewports.push({width, height: 568, camera: restored.camera, worldRect: restored.worldRect, controls});
    await page.screenshot({path: path.join(output, `${result.label}-breakpoint-${width}.png`), scale: 'css'});
  }
  // Keep an actual Work press down as the two-row layout becomes one row.
  // Its old coordinates can now intersect another button, so the stale release
  // must neither reframe nor rotate the camera after this resize cancellation.
  await page.setViewportSize({width: 347, height: 568}); await settle(page);
  await tap(page, context, 'CameraReset');
  verifyOverview(await ui(page), 'Before held resize');
  const point = await buttonPoint(page, 'CameraWork'), heldPose = pose((await ui(page)).camera);
  const start = await page.evaluate(() => ({samples: window.__flotraWorkTrace.samples.length, events: window.__flotraWorkTrace.events.length}));
  await dispatch(page, context, 'touchStart', [{id: 0, ...point}]);
  await page.waitForTimeout(650);
  await page.waitForFunction(from => window.__flotraWorkTrace.samples.length >= from + 2, start.samples, {timeout: 10000});
  const held = await page.evaluate(from => window.__flotraWorkTrace.samples.slice(from), start.samples);
  for (const sample of held) assert.deepEqual(sample.camera, heldPose, 'Work does not activate while held before breakpoint resize');
  await page.setViewportSize({width: 348, height: 568}); await settle(page);
  const resized = await ui(page);
  verifyViewport(await measure(page), 348, 568, dpr, 'Held resize to 348');
  verifyControls(resized, await measure(page), 'Held resize to one row');
  verifyOverview(resized, 'Resize cancels held Work before release');
  await dispatch(page, context, 'touchEnd', []); await refreshedDiagnostics(page);
  const released = await ui(page);
  verifyOverview(released, 'Stale Work release after breakpoint resize');
  assert.deepEqual(pose(released.camera), pose(resized.camera), 'Stale release cannot reframe or activate the new control under the old finger position');
  const events = await page.evaluate(from => window.__flotraWorkTrace.events.slice(from), start.events);
  assert.equal(events[0]?.type, 'touchstart', 'Breakpoint cancellation starts with actual touch input');
  assert.ok(events.length >= 2 && events.every(event => event.trusted), 'Breakpoint cancellation and release use browser-trusted touch events');
  assert.ok(events.some(event => event.type === 'touchend' || event.type === 'touchcancel'), 'Held breakpoint press receives a real release/cancel');
  await tap(page, context, 'CameraWork');
  verifyWork(await ui(page), 'Fresh Work recovers after breakpoint cancellation');
  await invariant(page, baseline, result, 'Held Work cancellation across 347 to 348 breakpoint');
  result.narrowBreakpoints.resizeCancellation = {from: 347, to: 348, heldEngineSamples: held.length, events, recovered: true};
  await page.setViewportSize({width: 320, height: 568}); await settle(page);
  const restored = await ui(page);
  verifyViewport(await measure(page), 320, 568, dpr, 'Restored 320 baseline');
  verifyControls(restored, await measure(page), 'Restored 320 baseline');
  verifyWork(restored, 'Restored 320 baseline');
  assert.deepEqual(pose(restored.camera), pose(initial.camera), 'Restore exact original 320 work pose before remaining case');
  assert.deepEqual(restored.camera.equipmentBounds, initial.camera.equipmentBounds, 'Restore exact original 320 physical equipment projection');
  await invariant(page, baseline, result, 'Restored original 320 camera and saved/domain baseline');
}
async function gesture(page, context, starts, ends) {
  await dispatch(page, context, 'touchStart', starts);
  await page.waitForTimeout(100);
  for (let step = 1; step <= 8; step++) {
    await dispatch(page, context, 'touchMove', starts.map((point, index) => ({id: point.id,
      x: point.x + (ends[index].x - point.x) * step / 8, y: point.y + (ends[index].y - point.y) * step / 8})));
    await page.waitForTimeout(45);
  }
  await page.waitForTimeout(90);
  await dispatch(page, context, 'touchEnd', []);
  await refreshedDiagnostics(page);
  const state = await ui(page);
  assert.equal(state.camera.touches, 0, 'Manual gesture releases all fingers');
  assert.equal(state.camera.mouseDown, false, 'Manual gesture leaves no emulated mouse held');
  assert.equal(state.sheet, '', 'Manual gesture does not accidentally open an editor');
  assert.equal(state.selectedSlot, '', 'Manual gesture does not pick equipment');
}
async function manualView(page, context) {
  const initial = await ui(page), m = await measure(page), world = initial.worldRect;
  const cx = m.canvas.rect.x + world.x + world.width / 2, cy = m.canvas.rect.y + world.y + world.height / 2;
  const dx = Math.min(28, world.width * .08), dy = Math.min(12, world.height * .10);
  await gesture(page, context, [{id: 0, x: cx - dx / 2, y: cy - dy / 2}], [{id: 0, x: cx + dx / 2, y: cy + dy / 2}]);
  await expectCamera(page, {framing: 'manual'});
  await page.waitForFunction(before => {
    const camera = window.FlotraViewport.uiMetrics.camera;
    return Math.hypot(camera.panX - before.panX, camera.panY - before.panY) > .05;
  }, pose(initial.camera), {timeout: 10000});
  const panned = await ui(page);
  assert.equal(panned.camera.framing, 'manual', 'Actual touch pan releases automatic work framing');
  assert.ok(Math.hypot(panned.camera.panX - initial.camera.panX, panned.camera.panY - initial.camera.panY) > .05, 'Actual touch drag measurably moves the view');
  const outer = Math.min(100, world.width * .25), inner = outer * .72;
  await gesture(page, context, [{id: 0, x: cx - outer, y: cy}, {id: 1, x: cx + outer, y: cy}],
    [{id: 0, x: cx - inner, y: cy}, {id: 1, x: cx + inner, y: cy}]);
  await page.waitForFunction(before => {
    const camera = window.FlotraViewport.uiMetrics.camera;
    return camera.framing === 'manual' && camera.zoom < before - .15;
  }, panned.camera.zoom, {timeout: 10000});
  const pinched = await ui(page);
  assert.equal(pinched.camera.framing, 'manual', 'Real two-finger pinch retains manual mode');
  assert.ok(pinched.camera.zoom < panned.camera.zoom - .15 && pinched.camera.zoom >= 1 && pinched.camera.zoom <= 3, 'Actual inward pinch zooms out within original bounds');
  closeEnough((await measure(page)).viewport.visualScale, 1, 'Pinch changes the game rather than browser scale', .01);
  return {pan: pose(panned.camera), pinch: pose(pinched.camera)};
}
async function editorReturn(page, context, id, result) {
  const before = await ui(page), point = before.slots[id], world = before.worldRect, m = await measure(page);
  assert.ok(point && point.x >= world.x + 2 && point.x <= world.x + world.width - 2 && point.y >= world.y + 2 && point.y <= world.y + world.height - 2, `${id}: actual equipment pick remains safely onscreen`);
  await touch(page, context, {x: m.canvas.rect.x + point.x, y: m.canvas.rect.y + point.y});
  await expectUI(page, {sheet: 'editor', selectedSlot: id});
  const editor = await ui(page);
  assert.ok(!editor.buttons.some(button => cameraNames.includes(button.name) && button.visible), 'Work/Whole controls are unavailable inside the equipment editor');
  await page.screenshot({path: path.join(output, `${result.label}-${before.camera.framing}-${id}-editor.png`), scale: 'css'});
  await tap(page, context, 'CloseSheet');
  await expectUI(page, {sheet: '', selectedSlot: ''});
  await settle(page);
  await expectCamera(page, pose(before.camera));
  const after = await ui(page);
  assert.deepEqual(pose(after.camera), pose(before.camera), `Editor restores exact ${before.camera.framing} session pose`);
  assert.deepEqual(after.camera.equipmentBounds, before.camera.equipmentBounds, `Editor restores actual projected equipment geometry in ${before.camera.framing} view`);
  result.editorReturns.push({id, framing: before.camera.framing, pose: pose(after.camera)});
}
async function boot(page, context, reload = false) {
  if (reload) await page.reload({waitUntil: 'domcontentloaded', timeout: 60000});
  else await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 60000});
  await page.waitForFunction(() => !!window.FlotraViewport?.uiMetrics?.camera, null, {timeout: 120000});
  await settle(page);
  await closeSheets(page, context);
  await settle(page);
}
async function runCase(page, context, result, width, height, dpr, identity) {
  await boot(page, context);
  await identity.checkpoint('initial boot');
  const first = await ui(page), initialStorage = await saved(page);
  assert.equal(initialStorage.primary, fixture.encoded, 'Initial earned save is byte-identical after loading');
  assert.equal(first.wallet, fixture.wallet, 'Imported fixture wallet is exact');
  assert.equal(first.simTime, fixture.time, 'Imported in-flight time is exact and remains paused');
  assert.deepEqual(first.upgrades, fixture.upgrades, 'Imported purchased equipment is exact');
  assert.equal(first.growth.wing_count, 4, 'Default framing is tested in the full four-wing warehouse');
  const baseline = {storage: initialStorage, domain: domain(first)};
  verifyViewport(await measure(page), width, height, dpr, result.label);
  verifyControls(first, await measure(page), 'Fresh default');
  verifyWork(first, 'Fresh default before any camera input');
  assert.equal(first.camera.turn, 0, 'New session starts with the original bearing');
  result.defaultWork = {camera: first.camera, worldRect: first.worldRect, slots: first.slots};
  await page.screenshot({path: path.join(output, `${result.label}-default-work.png`), scale: 'css'});
  await page.screenshot({path: path.join(output, `${result.label}-default-work-device.png`), scale: 'device'});
  await invariant(page, baseline, result, 'Initial work framing');
  if (width === 320 && height === 568) await narrowBreakpoints(page, context, result, baseline, first, dpr);

  await tap(page, context, 'CameraReset');
  const whole = await ui(page);
  assert.equal(whole.camera.framing, 'overview', 'Actual Whole button selects overview');
  assert.equal(whole.camera.zoom, 1); assert.equal(whole.camera.turn, 0);
  closeEnough(whole.camera.panX, 0, 'Whole clears horizontal pan'); closeEnough(whole.camera.panY, 0, 'Whole clears vertical pan');
  closeEnough(whole.camera.size, whole.camera.fitSize, 'Whole fits the complete warehouse');
  assert.ok(whole.camera.floorPoints.length >= 4, 'All mature wing centers are exposed');
  for (const point of whole.camera.floorPoints) assert.ok(point.x >= whole.worldRect.x && point.x <= whole.worldRect.x + whole.worldRect.width &&
    point.y >= whole.worldRect.y && point.y <= whole.worldRect.y + whole.worldRect.height, `Whole view contains ${point.name}`);
  verifyControls(whole, await measure(page), 'Explicit Whole');
  result.linearEnlargement = whole.camera.size / first.camera.size;
  assert.ok(result.linearEnlargement >= 1.4, 'Default machines render at least 1.4x larger than actual Whole view');
  for (const id of ['shelf', 'packing']) {
    const workRect = equipmentRect(first.camera, id), wholeRect = equipmentRect(whole.camera, id);
    assert.ok(workRect.width / wholeRect.width >= 1.4 && workRect.height / wholeRect.height >= 1.4, `${id}: actual projected width and height both enlarge by at least 1.4x`);
    closeEnough(workRect.width / wholeRect.width, result.linearEnlargement, `${id}: physical projection agrees with camera scale`, .005);
  }
  await page.screenshot({path: path.join(output, `${result.label}-explicit-whole.png`), scale: 'css'});
  result.heldWork = [await heldWork(page, context, true), await heldWork(page, context, false)];
  verifyWork(await ui(page), 'Held Work recovery');
  assert.deepEqual(pose((await ui(page)).camera), pose(first.camera), 'Released Work restores exact initial work pose');
  await tap(page, context, 'CameraWork');
  assert.deepEqual(pose((await ui(page)).camera), pose(first.camera), 'Repeated Work is idempotent');
  await invariant(page, baseline, result, 'Whole, canceled/held Work and repeated Work');

  for (let turn = 1; turn <= 4; turn++) {
    await tap(page, context, 'CameraRight');
    const state = await ui(page);
    assert.equal(state.camera.turn, turn % 4, 'Work rotation advances exactly one quarter turn');
    verifyWork(state, `Work rotation ${turn}`);
  }
  await tap(page, context, 'CameraLeft');
  assert.equal((await ui(page)).camera.turn, 3, 'Work left rotation is opposite');
  verifyWork(await ui(page), 'Work left rotation');
  await tap(page, context, 'CameraRight');
  assert.deepEqual(pose((await ui(page)).camera), pose(first.camera), 'A full bearing cycle returns to exact initial work pose');
  await editorReturn(page, context, 'shelf', result);
  verifyWork(await ui(page), 'Work editor return');
  await invariant(page, baseline, result, 'Work rotation and editor return');

  result.manual = await manualView(page, context);
  await editorReturn(page, context, 'packing', result);
  await invariant(page, baseline, result, 'Manual touch pan/pinch and editor return');
  // Reload from a visibly different manual bearing. The fixture initializer is
  // guarded by sessionStorage, so a missing/replaced save can never be reseeded.
  await tap(page, context, 'CameraRight');
  assert.equal((await ui(page)).camera.framing, 'manual');
  assert.equal((await ui(page)).camera.turn, 1);
  await invariant(page, baseline, result, 'Manual pose before reload');
  const exactPriorSave = (await saved(page)).primary;
  await identity.checkpoint('before reload', false);
  await boot(page, context, true);
  await identity.checkpoint('reloaded final export');
  const reloaded = await ui(page);
  verifyWork(reloaded, 'Reload defaults to work');
  verifyControls(reloaded, await measure(page), 'Reload');
  verifyViewport(await measure(page), width, height, dpr, 'Reload');
  assert.deepEqual(pose(reloaded.camera), pose(first.camera), 'Reload restores initial work pose rather than prior manual camera');
  assert.equal((await saved(page)).primary, exactPriorSave, 'Reload preserves the exact prior encoded save bytes');
  await invariant(page, baseline, result, 'Reload defaults work without changing prior save', true);
  result.reload = {priorSaveSha256: hash(exactPriorSave), restoredSaveSha256: hash((await saved(page)).primary), camera: pose(reloaded.camera)};

  // Only now intentionally advance the real simulation. Camera/session tests
  // above required full gameplay/save invariance; normal time/cargo progression
  // below is expected and is not compared with the paused fixture.
  const fixedPose = pose(reloaded.camera), fixedBounds = reloaded.camera.equipmentBounds, startTime = reloaded.simTime;
  await tap(page, context, 'PauseResume');
  await expectUI(page, {trialRunning: true, sheet: ''});
  const observation = await page.evaluate(() => ({from: window.__flotraWorkTrace.samples.length, time: window.FlotraViewport.uiMetrics.simTime}));
  await page.waitForFunction(time => window.FlotraViewport.uiMetrics.simTime > time + 3, observation.time, {timeout: 30000});
  const running = await ui(page);
  assert.equal(running.trialRunning, true, 'Real simulation is running');
  assert.ok(running.simTime > startTime + 3, 'Real domain clock advances by more than three simulation seconds');
  const samples = await page.evaluate(from => window.__flotraWorkTrace.samples.slice(from).filter(sample => sample.running), observation.from);
  assert.ok(samples.length >= 3 && new Set(samples.map(sample => sample.simTime)).size >= 3, 'Camera stability is sampled across multiple distinct live simulation updates');
  for (const sample of samples) {
    assert.deepEqual(sample.camera, fixedPose, 'Work camera pose stays fixed throughout running simulation');
    assert.deepEqual(sample.equipmentBounds, fixedBounds, 'Actual projected stationary machines never drift or follow moving actors');
  }
  assert.deepEqual(pose(running.camera), fixedPose, 'Running work pose is exact');
  assert.deepEqual(running.camera.equipmentBounds, fixedBounds, 'Running physical equipment projection is exact');
  await tap(page, context, 'PauseResume');
  await expectUI(page, {trialRunning: false});
  verifyWork(await ui(page), 'Paused after real run');
  assert.deepEqual(pose((await ui(page)).camera), fixedPose, 'Pausing never reframes work view');
  result.running = {beforeTime: startTime, afterTime: (await ui(page)).simTime, samples, noAutoFollow: true};
  await page.screenshot({path: path.join(output, `${result.label}-running-work-stable.png`), scale: 'css'});
}
(async () => {
  let browser;
  try {
    browser = await chromium.launch({executablePath: process.env.CHROMIUM_EXECUTABLE || undefined, headless: process.env.FLOTRA_HEADLESS !== '0'});
    for (const [width, height] of cases) for (const dpr of dprs) {
      const started = Date.now(), label = `${width}x${height}-dpr${dpr}`;
      const result = {label, status: 'running', errors: [], invariants: [], editorReturns: []}; report.results.push(result); saveReport();
      const context = await browser.newContext({viewport: {width, height}, deviceScaleFactor: dpr, isMobile: true, hasTouch: true});
      await context.addInitScript(({key, encoded}) => {
        const marker = '__flotra_work_fixture_seeded';
        if (sessionStorage.getItem(marker) !== '1') {
          if (localStorage.getItem(key) !== null) throw new Error('Refusing to replace an existing campaign save');
          localStorage.setItem(key, encoded); sessionStorage.setItem(marker, '1');
        }
      }, {key: saveKey, encoded: fixture.encoded});
      await installTrace(context);
      const page = await context.newPage(); page.setDefaultTimeout(15000);
      page.on('pageerror', error => result.errors.push(error.message));
      page.on('console', message => {if (message.type() === 'error') result.errors.push(message.text());});
      try {
        console.log(`WORK CAMERA START ${label}`);
        const identity = await installAssetIdentity(page, context, result);
        // The WebGL check runs after boot inside the case; no synthetic renderer
        // or successful HTTP response can substitute for a live game surface.
        await runCase(page, context, result, width, height, dpr, identity);
        await identity.checkpoint('before closing context', false);
        result.environment = await page.evaluate(() => {
          const gl = document.querySelector('#canvas').getContext('webgl2'), ext = gl?.getExtension('WEBGL_debug_renderer_info');
          return {dpr: devicePixelRatio, renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : null, visibility: document.visibilityState};
        });
        assert.ok(result.environment.renderer, 'Actual WebGL2 renderer exists');
        assert.equal(result.environment.visibility, 'visible', 'Game rendered in a visible browser page');
        assert.deepEqual(result.errors, [], 'No runtime/render errors');
        result.status = 'passed'; console.log(`WORK CAMERA PASS ${label}`);
      } catch (error) {
        result.status = 'failed'; result.error = error.stack;
        result.last = await ui(page).catch(() => null);
        result.trace = await page.evaluate(() => window.__flotraWorkTrace).catch(() => null);
        await page.screenshot({path: path.join(output, `${label}-failure.png`), scale: 'css'}).catch(() => {});
        throw error;
      } finally {
        result.wallSeconds = (Date.now() - started) / 1000; saveReport(); await context.close();
      }
    }
    console.log(`BROWSER_WORK_CAMERA ${report.results.length} cases passed`);
  } catch (error) {report.error = error.stack; console.error(error); process.exitCode = 1;}
  finally {report.finishedAt = new Date().toISOString(); saveReport(); await browser?.close();}
})();
