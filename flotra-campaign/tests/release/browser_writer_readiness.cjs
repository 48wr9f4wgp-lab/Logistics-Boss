#!/usr/bin/env node
'use strict';
// Narrow, REAL desktop Chromium qualification. Never point this at a public
// origin/profile: only a loopback export and fresh disposable contexts are used.
//
// Generate domain-earned legacy.json using tests/release/growth_browser_fixtures.gd:
// FLOTRA_GROWTH_FIXTURES=/tmp/flotra-fixtures /path/to/godot-4.7.2 \
//   --headless --path flotra-campaign -s res://tests/release/growth_browser_fixtures.gd
// Export with export_web.sh. Add a static writer-away.html to that export
// (a minimal inert HTML page for real navigation), serve it on loopback, then:
// CHROMIUM_EXECUTABLE=/path/to/chromium node tests/release/browser_writer_readiness.cjs \
//   http://127.0.0.1:8000/ /tmp/flotra-writer-browser /tmp/flotra-fixtures
// Playwright must be available. FLOTRA_BROWSER_HEADED=1 is optional (needs DISPLAY).
// Exit 0 = every gate verified; 1 = failure; 2 = genuine BFCache coverage blocked.
// No dispatched lifecycle events, fake lock objects, game mutation API, user
// storage, persistent browser context, clock acceleration, or skip switches.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const exportContract = require('./browser_export_contract.cjs');
const P = 'flotra.campaign.dispatch.v5';
const O = 'flotra.campaign.release.v1';
const LOCK = P + '.writer';
const OLD_LOCK = O + '.writer';
const BOOT_MS = 120000;
const UI_MS = 15000;
const output = path.resolve(process.argv[3] || '/tmp/flotra-writer-browser');
fs.mkdirSync(output, { recursive: true });
const report = {
  suite: 'desktop-writer-readiness',
  scope: 'Real disposable desktop Chromium, local synthetic saves, actual mouse; not a physical Windows PC',
  startedAt: new Date().toISOString(), tests: [],
};
const digest = value => crypto.createHash('sha256').update(value).digest('hex');
let browser, target, legacy, earned;
const saveReport = () => fs.writeFileSync(path.join(output, 'writer-readiness.json'), JSON.stringify(report, null, 2));
const briefStorage = storage => Object.fromEntries(Object.entries(storage).map(([key, value]) => [key, { bytes: Buffer.byteLength(value), sha256: digest(value) }]));
const storage = page => page.evaluate(() => Object.fromEntries(Object.keys(localStorage).sort().map(key => [key, localStorage.getItem(key)])));
const ui = page => page.evaluate(() => window.FlotraViewport?.uiMetrics || null);
const diagnostics = page => page.evaluate(() => ({
  harness: window.__writerHarness?.data,
  readiness: window.FlotraDispatchStore?.readiness(),
  ui: window.FlotraViewport?.uiMetrics || null,
  notice: document.querySelector('#status-notice')?.innerText || '',
  label: document.querySelector('#status-label')?.innerText || '',
  navigation: performance.getEntriesByType('navigation').map(entry => ({ type: entry.type, notRestoredReasons: entry.notRestoredReasons?.toJSON?.() || null })),
}));
// Only values already exposed by the game's scalar read-only QA interface.
function durable(state) {
  assert.ok(state, 'Real game QA state exists');
  return Object.fromEntries(['wallet', 'growth', 'progress', 'status', 'upgrades', 'currentContract', 'simTime', 'speed', 'preferences', 'operation', 'layout'].map(key => [key, state[key]]));
}
async function shot(page, name) {
  await page.screenshot({ path: path.join(output, name + '.png'), scale: 'css', timeout: 15000 });
}
async function expectUI(page, expected) {
  await page.waitForFunction(expected => {
    const state = window.FlotraViewport?.uiMetrics;
    return state && Object.entries(expected).every(([key, value]) => state[key] === value);
  }, expected, { timeout: UI_MS });
  // Respect the real 180ms dismissal guard; do not bypass engine input.
  await page.waitForTimeout(240);
}
async function readyUI(page, sheet = 'entry') {
  await page.waitForFunction(() => !!window.FlotraViewport?.uiMetrics, null, { timeout: BOOT_MS });
  await expectUI(page, { sheet, trialRunning: false });
  await page.waitForFunction(() => {
    const c = document.querySelector('#canvas');
    const e = window.FlotraViewport?.engineMetrics;
    if (!c || !e) return false;
    const r = c.getBoundingClientRect();
    return Math.abs(e.logicalWidth - r.width) <= 1 && Math.abs(e.logicalHeight - r.height) <= 1 && e.rootWidth === c.width && e.rootHeight === c.height;
  }, null, { timeout: UI_MS });
  const contract = await exportContract.fromPage(page);
  assert.equal(contract.version, 5, 'Candidate is actually the schema-5 export');
  const d = await diagnostics(page);
  assert.equal(d.harness.starts.length, 1, 'Exactly one real engine.startGame call in this document');
  assert.equal(d.harness.engineInstances, 1, 'Exactly one actual engine instance');
  assert.ok(d.harness.statuses.some(item => item.text.includes('保存データの安全を確認しています')), 'Real loader displayed its readiness phase');
}
async function mouseButton(page, name, { disabled = false, scroll = false } = {}) {
  for (let attempt = 0; attempt < 18; attempt++) {
    await page.waitForFunction(name => window.FlotraViewport?.uiMetrics?.buttons.some(item => item.name === name && item.visible), name, { timeout: UI_MS });
    const state = await ui(page);
    const b = state.buttons.find(item => item.name === name && item.visible);
    assert.equal(b.disabled, disabled, name + ': actual disabled state');
    const canvas = await page.locator('#canvas').boundingBox();
    assert.ok(canvas, 'Actual canvas is visible');
    const x = b.x + b.width / 2, y = b.y + b.height / 2;
    const s = state.scroll;
    const visible = x >= 0 && x <= canvas.width && y >= 0 && y <= canvas.height;
    const inScroll = !scroll || (s && b.y >= s.y + 2 && b.y + b.height <= s.y + s.height - 2);
    if (visible && inScroll) {
      await page.mouse.move(canvas.x + x, canvas.y + y);
      await page.mouse.down();
      await page.waitForTimeout(90); // Cross a real refresh boundary while held.
      await page.mouse.up();
      await page.waitForTimeout(300);
      return;
    }
    assert.ok(scroll && s?.height > 32, 'A real scroll area can reveal ' + name);
    await page.mouse.move(canvas.x + s.x + s.width / 2, canvas.y + s.y + s.height / 2);
    await page.mouse.wheel(0, y > s.y + s.height / 2 ? 180 : -180);
    await page.waitForTimeout(250);
  }
  assert.fail('Real mouse scrolling did not reveal ' + name);
}
async function closeIntro(page) {
  await mouseButton(page, 'CloseSheet');
  await expectUI(page, { sheet: '' });
}
async function normalBack(page) {
  await mouseButton(page, 'Back');
  await expectUI(page, { sheet: 'controls', trialRunning: false });
  const before = durable(await ui(page));
  await mouseButton(page, 'PauseResume', { disabled: true });
  await expectUI(page, { sheet: 'controls', trialRunning: false });
  assert.deepEqual(durable(await ui(page)), before, 'Normal modal still guards Work');
  await mouseButton(page, 'Back');
  await expectUI(page, { sheet: '', trialRunning: false });
}
// The fixture page is separate from the game. Its only writes seed synthetic
// bytes in a new context. Its lock callbacks are native browser Lock instances.
async function fixturePage(context) {
  const helper = await context.newPage();
  const href = new URL('__writer_fixture__.html', target).href;
  await helper.route(href, route => route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><title>Disposable writer fixture</title><p>Synthetic CI fixture only</p>' }));
  await helper.goto(href, { waitUntil: 'load' });
  assert.equal(await helper.evaluate(() => isSecureContext && typeof navigator.locks?.request === 'function'), true, 'CI loopback has actual Web Locks');
  return helper;
}
async function hold(helper, name) {
  assert.equal(await helper.evaluate(name => new Promise(resolve => {
    window.__heldPromise = navigator.locks.request(name, { mode: 'exclusive', ifAvailable: true }, lock => {
      if (!lock) { resolve(false); return; }
      return new Promise(release => {
        window.__fixtureRelease = release;
        window.__fixtureLock = { name: lock.name, mode: lock.mode, type: Object.prototype.toString.call(lock) };
        resolve(true);
      });
    });
  }), name), true, 'Fixture acquired a native exclusive lock: ' + name);
  const actual = await helper.evaluate(() => window.__fixtureLock);
  assert.deepEqual(actual, { name, mode: 'exclusive', type: '[object Lock]' });
}
async function release(helper) {
  await helper.evaluate(async () => { window.__fixtureRelease?.(); await window.__heldPromise; });
}
async function probe(helper, name) {
  return helper.evaluate(name => navigator.locks.request(name, { mode: 'exclusive', ifAvailable: true }, lock => !!lock), name);
}
async function installHarness(page, config = {}) {
  await page.addInitScript(config => {
    const data = { realm: crypto.randomUUID(), engineInstances: 0, starts: [], locks: [], writes: [], statuses: [], lifecycle: [], input: [] };
    const stamp = () => Math.round(performance.now());
    const controls = new Map();
    window.__writerHarness = { data, release: name => {
      if (!controls.has(name)) throw new Error('No held native callback for ' + name);
      controls.get(name)(); controls.delete(name);
    } };
    for (const type of ['pageshow', 'pagehide']) addEventListener(type, event => {
      const item = { type, persisted: event.persisted, trusted: event.isTrusted, at: stamp(), realm: data.realm, writes: data.writes.length, lockRequests: data.locks.length, starts: data.starts.length };
      data.lifecycle.push(item);
      console.debug('WRITER_LIFECYCLE ' + JSON.stringify(item));
    });
    for (const type of ['mousedown', 'mouseup', 'keydown']) addEventListener(type, event => {
      data.input.push({ type, trusted: event.isTrusted, key: event.key, x: event.clientX, y: event.clientY, at: stamp() });
      if (data.input.length > 300) data.input.shift();
    }, true);
    new MutationObserver(records => {
      for (const record of records) {
        if (record.target.id === 'status-label' || record.target.id === 'status-notice') {
          const text = Array.from(record.addedNodes, node => node.textContent).join('') || record.target.textContent;
          data.statuses.push({ text, at: stamp() });
        }
      }
    }).observe(document, { subtree: true, childList: true, characterData: true });
    for (const method of ['setItem', 'removeItem', 'clear']) {
      const native = Storage.prototype[method];
      Storage.prototype[method] = function (...args) {
        if (this === localStorage) data.writes.push({ method, key: args[0] ?? null, length: String(args[1] ?? '').length, at: stamp() });
        return Reflect.apply(native, this, args);
      };
    }
    // index.js declares a global lexical `const Engine`, so replacing only
    // window.Engine would miss the loader's real constructor. Its exported
    // feature check runs after `const engine` is constructed and before ready().
    // Observe that actual instance then forward startGame and the check intact.
    // No game/QA method is called or exposed by this instrumentation.
    let EngineValue;
    const observed = new WeakSet();
    Object.defineProperty(window, 'Engine', {
      configurable: true, get: () => EngineValue,
      set(value) {
        EngineValue = value;
        if (typeof value?.getMissingFeatures !== 'function') return;
        const check = value.getMissingFeatures;
        value.getMissingFeatures = function (...args) {
          const instance = (0, eval)('engine'); // Read the real loader lexical.
          if (!observed.has(instance)) {
            observed.add(instance); data.engineInstances++;
            const start = instance.startGame;
            instance.startGame = function (...args) {
              const item = { at: stamp(), state: 'pending' }; data.starts.push(item);
              const result = Reflect.apply(start, this, args);
              result.then(() => { item.state = 'fulfilled'; }, error => { item.state = 'rejected'; item.error = String(error); });
              return result;
            };
          }
          return Reflect.apply(check, this, args);
        };
      },
    });
    const manager = navigator.locks;
    if (config.api === 'absent') {
      Object.defineProperty(navigator, 'locks', { configurable: true, value: undefined });
    } else if (config.api === 'reject') {
      Object.defineProperty(navigator, 'locks', { configurable: true, value: {
        request(name, options) { data.locks.push({ name, options, refused: true, at: stamp() }); return Promise.reject(new DOMException('Synthetic CI API refusal', 'SecurityError')); },
      } });
    } else {
      if (!manager) throw new Error('Actual Web Locks unavailable in the CI browser');
      const nativeRequest = manager.request.bind(manager);
      Object.defineProperty(manager, 'request', { configurable: true, value(name, options, callback) {
        const item = { name, options, requestedAt: stamp() }; data.locks.push(item);
        return nativeRequest(name, options, async lock => {
          item.nativeGrant = lock ? { name: lock.name, mode: lock.mode, type: Object.prototype.toString.call(lock) } : null;
          item.grantedAt = stamp();
          if (lock && config.delayLock === name) {
            item.delayed = true;
            await new Promise(resolve => controls.set(name, resolve));
          }
          item.deliveredAt = stamp();
          try { return await callback(lock); }
          finally { item.callbackCompletedAt = stamp(); }
        });
      } });
    }
  }, config);
}
async function goto(page) {
  const response = await page.goto(target.href, { waitUntil: 'domcontentloaded', timeout: 60000 });
  assert.ok(response?.ok(), 'Local export HTTP response succeeds');
  assert.equal(new URL(page.url()).origin, target.origin, 'No redirect away from the disposable local export');
}
async function noBootNoWrites(page, baseline, expectedState) {
  await page.waitForTimeout(300);
  const d = await diagnostics(page);
  assert.equal(d.harness.starts.length, 0, 'Loader has not started Godot');
  assert.equal(d.ui, null, 'No game was created');
  assert.equal(d.harness.writes.length, 0, 'No storage write/removal was even attempted');
  assert.deepEqual(await storage(page), baseline, 'All synthetic bytes remain exact');
  if (expectedState) assert.equal(d.readiness.current.state, expectedState);
}
async function failureNotice(page, text, baseline, state) {
  await page.waitForFunction(text => {
    const e = document.querySelector('#status-notice');
    return e && getComputedStyle(e).display !== 'none' && e.innerText.includes(text);
  }, text, { timeout: 17000 });
  await noBootNoWrites(page, baseline, state);
}
async function delayPending(page, helper, name, baseline, test) {
  await page.waitForFunction(name => window.__writerHarness?.data.locks.some(item => item.name === name && item.delayed && !item.deliveredAt), name, { timeout: 10000 });
  const d = await diagnostics(page);
  assert.match(d.label, /保存データの安全を確認しています/);
  assert.equal(d.readiness[name === LOCK ? 'current' : 'legacy'].state, 'pending');
  await noBootNoWrites(page, baseline);
  assert.equal(await probe(helper, name), false, 'Independent page sees a truly held native exclusive lock');
  const locks = await helper.evaluate(() => navigator.locks.query());
  assert.ok(locks.held.some(lock => lock.name === name && lock.mode === 'exclusive'));
  test.pending = { readiness: d.readiness, nativeLocks: locks };
  await shot(page, test.name + '-waiting');
}
async function releaseDelayed(page, name) {
  await page.evaluate(name => window.__writerHarness.release(name), name);
}
async function savedCheckpoint(page) {
  await page.waitForFunction(key => {
    const state = window.FlotraViewport?.uiMetrics;
    return state && !state.trialRunning && state.autosave?.last_saved_generation >= 0 && localStorage.getItem(key) !== null;
  }, P, { timeout: UI_MS });
  const state = durable(await ui(page));
  const all = await storage(page);
  const value = all[P];
  const envelope = JSON.parse(value);
  assert.equal(envelope.version, 5);
  assert.equal(envelope.format, 'flotra-campaign');
  assert.equal(digest(Buffer.from(envelope.payload, 'base64').toString('hex')), envelope.sha256, 'Production checksum is SHA256 of lowercase hex text');
  const inputs = (await diagnostics(page)).harness.input;
  assert.ok(inputs.some(event => event.type === 'mousedown' && event.trusted) && inputs.some(event => event.type === 'mouseup' && event.trusted), 'Save was reached with genuine browser mouse events');
  return { state, encoded: value, all, trustedMouseEvents: inputs.filter(event => event.trusted && event.type.startsWith('mouse')).length };
}
async function startAndSave(page) {
  await mouseButton(page, 'CloseSheet');
  await expectUI(page, { sheet: 'jobs' });
  await mouseButton(page, 'AcceptContract_growth_1', { scroll: true });
  await expectUI(page, { sheet: '', trialRunning: true });
  await page.waitForFunction(() => window.FlotraViewport.uiMetrics.simTime > 0, null, { timeout: UI_MS });
  await mouseButton(page, 'PauseResume');
  await expectUI(page, { sheet: '', trialRunning: false });
  const checkpoint = await savedCheckpoint(page);
  assert.equal(checkpoint.state.currentContract, 'growth_1');
  assert.equal(checkpoint.state.status, 'running');
  assert.equal(checkpoint.state.wallet, 0);
  assert.ok(Number.isInteger(checkpoint.state.progress.shipped) && checkpoint.state.progress.shipped >= 0 && checkpoint.state.progress.shipped < 12, 'Started job has not completed');
  assert.ok(checkpoint.state.simTime > 0);
  return checkpoint;
}
async function reloadExact(page, expected) {
  await page.reload({ waitUntil: 'domcontentloaded', timeout: 60000 });
  await readyUI(page);
  assert.deepEqual(durable(await ui(page)), expected.state, 'All selected durable QA fields restore exactly');
  assert.equal((await storage(page))[P], expected.encoded, 'Reload does not rewrite the checkpoint');
}
async function protectedControls(page, baseline, test, reload = true) {
  await expectUI(page, { sheet: 'save_protection', trialRunning: false });
  const before = durable(await ui(page));
  const initialWrites = (await diagnostics(page)).harness.writes.length;
  async function assertProtected() {
    const state = await ui(page);
    assert.equal(state.sheet, 'save_protection'); assert.equal(state.trialRunning, false);
    for (const [name, text] of [['Back', '保護中'], ['PauseResume', '停止中'], ['CloseSheet', '停止中']]) {
      const control = state.buttons.find(button => button.name === name && button.visible);
      assert.ok(control, 'Protected control is present: ' + name);
      assert.equal(control.disabled, true, name + ' remains disabled');
      assert.equal(control.text, text, name + ' has truthful protection label');
    }
    assert.deepEqual(durable(state), before, 'Protection preserves observed game state');
    assert.deepEqual(await storage(page), baseline, 'Protection does not modify primary, backup or legacy bytes');
    assert.equal((await diagnostics(page)).harness.writes.length, initialWrites, 'Protected controls attempt no storage writes');
  }
  await assertProtected();
  for (const name of ['Back', 'PauseResume', 'CloseSheet', 'Back']) await mouseButton(page, name, { disabled: true });
  for (let i = 0; i < 6; i++) { await page.keyboard.press('Tab'); await page.keyboard.press('Enter'); }
  await page.waitForTimeout(500);
  await assertProtected();
  await page.setViewportSize({ width: 1180, height: 660 });
  await page.waitForTimeout(600);
  await assertProtected();
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.waitForTimeout(600);
  await assertProtected();
  await shot(page, test.name + '-protected-desktop');
  test.protectedControls = { realMouse: true, keyboard: true, resizeAndFrameRefresh: true };
  if (reload) {
    await page.reload({ waitUntil: 'domcontentloaded' });
    await readyUI(page, 'save_protection');
    await assertProtected();
    test.protectedControls.explicitReload = true;
  }
}
async function scenario(name, options, action) {
  const test = { name, dpr: options.dpr || 1, status: 'running' };
  report.tests.push(test); saveReport();
  let context, page, helper;
  const messages = [], errors = [], pageErrors = [], failures = [];
  const started = Date.now();
  try {
    if (options.needsEarned) assert.ok(earned, 'Cold-start gate must earn and verify a v5 fixture first');
    context = await browser.newContext({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: test.dpr, isMobile: false, hasTouch: false, serviceWorkers: 'block' });
    context.setDefaultTimeout(UI_MS);
    context.setDefaultNavigationTimeout(60000);
    await context.tracing.start({ screenshots: true, snapshots: true, sources: true });
    helper = await fixturePage(context);
    assert.deepEqual(await storage(helper), {}, 'Every case starts with an empty disposable context');
    const initial = typeof options.seed === 'function' ? options.seed() : (options.seed || {});
    await helper.evaluate(seed => { for (const [key, value] of Object.entries(seed)) localStorage.setItem(key, value); }, initial);
    const baseline = await storage(helper);
    test.initialStorage = briefStorage(baseline);
    page = await context.newPage();
    page.on('pageerror', error => { pageErrors.push(error.message); errors.push(error.message); });
    page.on('console', message => {
      if (message.type() === 'error') errors.push(message.text());
      if (message.type() === 'error' || message.text().startsWith('WRITER_LIFECYCLE ')) messages.push({ type: message.type(), text: message.text() });
    });
    page.on('requestfailed', request => failures.push({ url: request.url(), failure: request.failure() }));
    await installHarness(page, options);
    await action({ page, helper, context, baseline, test });
    assert.deepEqual(pageErrors, [], 'No uncaught browser exceptions, including negative cases');
    if (!options.expectedEngineFailure) assert.deepEqual(errors, [], 'No console or page errors');
    else assert.ok((await diagnostics(page)).harness.starts.some(call => call.state === 'rejected'), 'Real engine load actually rejected');
    test.status = test.status === 'blocked' ? 'blocked' : 'passed';
  } catch (error) {
    test.status = 'failed'; test.error = error.stack || String(error);
    if (page) await shot(page, name + '-failure').catch(error => { test.screenshotError = error.message; });
  } finally {
    if (page) {
      test.final = await diagnostics(page).catch(error => ({ unavailable: error.message }));
      test.finalStorage = await storage(page).then(briefStorage).catch(error => ({ unavailable: error.message }));
    }
    test.messages = messages; test.errors = errors; test.pageErrors = pageErrors; test.requestFailures = failures;
    test.elapsedSeconds = (Date.now() - started) / 1000;
    if (context) {
      try { await context.tracing.stop({ path: path.join(output, name + '-trace.zip') }); }
      catch (error) { test.traceError = error.message; test.status = 'failed'; }
      await context.close();
    }
    console.log('BROWSER_WRITER_READINESS ' + name + ': ' + test.status);
    saveReport();
  }
}
(async () => {
  try {
    assert.ok(process.argv[2] && process.argv[4], 'Supply a loopback export URL, output directory and earned-fixture directory');
    target = new URL(process.argv[2]);
    assert.ok(['http:', 'https:'].includes(target.protocol) && ['127.0.0.1', 'localhost', '[::1]'].includes(target.hostname), 'Only disposable loopback exports are allowed');
    assert.ok(!target.username && !target.password, 'No credentials in test URLs');
    target.searchParams.set('phone_qa', '1');
    report.url = target.href;
    legacy = JSON.parse(fs.readFileSync(path.join(process.argv[4], 'legacy.json'), 'utf8'));
    assert.ok(typeof legacy.encoded === 'string' && legacy.encoded.length > 0 && Number.isFinite(legacy.time), 'Domain-earned legacy.json is required');
    report.legacyFixture = { sha256: digest(legacy.encoded), simTime: legacy.time, wallet: legacy.wallet };
    const { chromium } = require('playwright');
    browser = await chromium.launch({
      executablePath: process.env.CHROMIUM_EXECUTABLE || undefined,
      headless: process.env.FLOTRA_BROWSER_HEADED !== '1',
      // Playwright normally disables BFCache. Restore the browser's ordinary
      // feature, without forcing eligibility or fabricating lifecycle events.
      ignoreDefaultArgs: ['--disable-back-forward-cache'],
    });
    report.chromiumVersion = browser.version();
    report.headed = process.env.FLOTRA_BROWSER_HEADED === '1';

    for (const dpr of [1, 1.5]) await scenario('cold-start-dpr-' + dpr, { dpr }, async ({ page, test }) => {
      await goto(page); await readyUI(page);
      const checkpoint = await startAndSave(page);
      await normalBack(page);
      await shot(page, test.name + '-saved');
      await reloadExact(page, checkpoint);
      await shot(page, test.name + '-reloaded');
      const evidence = (await diagnostics(page)).harness;
      assert.ok(evidence.starts[0].state === 'fulfilled', 'Real WASM boot fulfilled');
      test.restored = checkpoint.state; test.checkpointSHA256 = digest(checkpoint.encoded); test.trustedMouseEvents = checkpoint.trustedMouseEvents;
      if (dpr === 1) earned = checkpoint;
    });

    for (const name of [LOCK, OLD_LOCK]) await scenario('delayed-' + (name === LOCK ? 'v5' : 'legacy'), { delayLock: name }, async ({ page, helper, baseline, test }) => {
      await goto(page); await delayPending(page, helper, name, baseline, test);
      await releaseDelayed(page, name); await readyUI(page);
      const checkpoint = await startAndSave(page);
      test.granted = (await diagnostics(page)).harness.locks;
      // The fixture-only delay is still installed after reload; release the
      // real v5 callback again, but an existing v5 must not request legacy.
      await page.reload({ waitUntil: 'domcontentloaded' });
      if (name === LOCK) {
        await page.waitForFunction(name => window.__writerHarness.data.locks.some(item => item.name === name && item.delayed), name);
        await releaseDelayed(page, name);
      }
      await readyUI(page);
      assert.deepEqual(durable(await ui(page)), checkpoint.state);
      assert.equal((await storage(page))[P], checkpoint.encoded);
      test.exactSavedReadback = true;
    });

    for (const name of [LOCK, OLD_LOCK]) await scenario('occupied-' + (name === LOCK ? 'v5' : 'legacy'), { seed: { [O]: legacy.encoded } }, async ({ page, helper, baseline, test }) => {
      await hold(helper, name); await goto(page);
      await failureNotice(page, '別のFLOTRA画面が保存機能を使用しています', baseline, 'occupied');
      await shot(page, test.name + '-conflict');
      if (name === OLD_LOCK) assert.equal(await probe(helper, LOCK), true, 'Refused legacy startup releases its acquired v5 lock');
      await release(helper);
      await noBootNoWrites(page, baseline, 'occupied'); // No silent retry/takeover.
      await page.reload({ waitUntil: 'domcontentloaded' }); await readyUI(page);
      const state = await ui(page);
      assert.equal(state.wallet, legacy.wallet); assert.equal(state.simTime, legacy.time); assert.equal(state.progress.shipped, legacy.shipped);
      assert.deepEqual(state.upgrades, legacy.upgrades);
      assert.equal((await storage(page))[O], legacy.encoded);
      test.explicitReloadRecovered = true;
    });

    await scenario('existing-v5-ignores-held-legacy', { needsEarned: true, seed: () => ({ [P]: earned.encoded, [O]: legacy.encoded }) }, async ({ page, helper, baseline, test }) => {
      await hold(helper, OLD_LOCK); await goto(page); await readyUI(page);
      assert.deepEqual(durable(await ui(page)), earned.state);
      const d = await diagnostics(page);
      assert.equal(d.readiness.legacy.state, 'idle');
      assert.ok(d.harness.locks.every(lock => lock.name !== OLD_LOCK), 'Existing v5 never requests legacy ownership');
      assert.deepEqual(await storage(page), baseline);
      test.legacyStillHeld = await helper.evaluate(() => navigator.locks.query());
      assert.equal(await probe(helper, OLD_LOCK), false);
    });

    for (const variant of ['invalid-v5', 'backup-only-v5']) await scenario(variant + '-protected', {
      needsEarned: true,
      seed: () => ({ [variant === 'invalid-v5' ? P : P + '.backup']: variant === 'invalid-v5' ? '{"synthetic_invalid_v5":true}' : earned.encoded, [O]: legacy.encoded }),
    }, async ({ page, helper, baseline, test }) => {
      await hold(helper, OLD_LOCK); await goto(page); await readyUI(page, 'save_protection');
      assert.equal((await diagnostics(page)).readiness.legacy.state, 'idle');
      if (variant === 'backup-only-v5') assert.deepEqual(durable(await ui(page)), earned.state, 'Read-only backup recovery uses current-version state');
      else assert.notEqual((await ui(page)).simTime, legacy.time, 'Malformed v5 never loads legacy state');
      await protectedControls(page, baseline, test);
      assert.equal((await diagnostics(page)).harness.writes.length, 0, 'Protected engine never attempts a storage write');
    });

    for (const api of ['absent', 'reject']) await scenario('api-' + api, { api, seed: { [O]: legacy.encoded } }, async ({ page, baseline, test }) => {
      await goto(page);
      await failureNotice(page, 'このブラウザーで安全な保存機能を利用できない', baseline, 'unavailable');
      await shot(page, test.name + '-notice');
    });

    for (const name of [LOCK, OLD_LOCK]) await scenario('timeout-' + (name === LOCK ? 'v5' : 'legacy'), { delayLock: name, seed: { [O]: legacy.encoded } }, async ({ page, helper, baseline, test }) => {
      await goto(page); await delayPending(page, helper, name, baseline, test);
      await failureNotice(page, '保存機能の確認に時間がかかっています', baseline, 'timeout');
      const d = await diagnostics(page);
      const waiting = d.harness.statuses.find(item => item.text.includes('保存データの安全を確認しています'));
      const timeout = d.harness.statuses.find(item => item.text.includes('保存機能の確認に時間がかかっています'));
      assert.ok(timeout.at - waiting.at >= 9500, 'Real ten-second timer was not accelerated');
      await shot(page, test.name + '-notice');
      await releaseDelayed(page, name);
      await page.waitForFunction(name => window.__writerHarness.data.locks.some(item => item.name === name && item.callbackCompletedAt), name);
      await noBootNoWrites(page, baseline, 'timeout');
      assert.equal(await probe(helper, LOCK), true, 'Late callback cannot retain current ownership');
      assert.equal(await probe(helper, OLD_LOCK), true, 'Late callback cannot retain legacy ownership');
      test.lateGrantDidNotRestart = true;
    });

    await scenario('engine-load-rejection-releases-locks', { expectedEngineFailure: true }, async ({ page, helper, baseline, test }) => {
      await page.route('**/index.wasm*', route => route.abort('failed'));
      await goto(page);
      await page.waitForFunction(() => document.querySelector('#status-notice')?.innerText.includes('FLOTRAを起動できませんでした'), null, { timeout: BOOT_MS });
      const d = await diagnostics(page);
      assert.equal(d.harness.starts.length, 1);
      assert.equal(d.readiness.current.state, 'cancelled');
      assert.equal(d.ui, null);
      assert.equal(d.harness.writes.length, 0);
      assert.deepEqual(await storage(page), baseline);
      assert.equal(await probe(helper, LOCK), true);
      assert.equal(await probe(helper, OLD_LOCK), true);
      test.bothNativeLocksReleased = true;
      await shot(page, test.name + '-notice');
    });

    await scenario('real-bfcache-restoration', { needsEarned: true, seed: () => ({ [P]: earned.encoded }) }, async ({ page, helper, context, baseline, test }) => {
      await goto(page); await readyUI(page); await closeIntro(page);
      const before = await diagnostics(page);
      const oldState = durable(await ui(page));
      // No routing or fake events on this tested page. CI serves a static inert
      // HTML file with a different document and an actual history entry.
      const away = new URL('writer-away.html', target); away.searchParams.set('writer_navigation', '1');
      const response = await page.goto(away.href, { waitUntil: 'load' });
      assert.ok(response?.ok(), 'Real navigation destination is served');
      assert.equal(page.url(), away.href);
      assert.match(response.headers()['content-type'] || '', /text\/html/, 'Navigation fixture is an actual served HTML document');
      const latestPage = await context.newPage();
      const latestErrors = [];
      latestPage.on('pageerror', error => latestErrors.push(error.message));
      latestPage.on('console', message => { if (message.type() === 'error') latestErrors.push(message.text()); });
      await installHarness(latestPage);
      await goto(latestPage); await readyUI(latestPage); await closeIntro(latestPage);
      await mouseButton(latestPage, 'Back'); await expectUI(latestPage, { sheet: 'controls' });
      await mouseButton(latestPage, 'Speed4x', { scroll: true });
      await latestPage.waitForFunction(() => window.FlotraViewport.uiMetrics.speed === 4);
      const latest = await savedCheckpoint(latestPage);
      assert.notEqual(latest.encoded, earned.encoded, 'A different real UI-earned checkpoint exists while old page is away');
      assert.deepEqual(latestErrors, []);
      await latestPage.close(); // Release native locks before restoring old heap.
      const newestStorage = await storage(helper);
      await page.goBack({ waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForFunction(() => !!window.__writerHarness, null, { timeout: UI_MS });
      const returned = await diagnostics(page);
      const persisted = returned.harness.lifecycle.find(event => event.type === 'pageshow' && event.persisted && event.trusted);
      test.lifecycle = { beforeRealm: before.harness.realm, returnedRealm: returned.harness.realm, events: returned.harness.lifecycle, navigation: returned.navigation };
      if (!persisted) {
        // A cache miss is not proof of restoration safety and cannot pass this
        // qualification. Still check the actual fallback reload outcome.
        await readyUI(page);
        assert.deepEqual(durable(await ui(page)), latest.state, 'Ordinary history reload reads latest synthetic checkpoint');
        test.status = 'blocked';
        test.reason = 'UNVERIFIED: actual Back navigation did not emit trusted pageshow.persisted=true; no event was synthesized.';
        await shot(page, test.name + '-not-restored');
        return;
      }
      assert.equal(returned.harness.realm, before.harness.realm, 'The real previous JS heap was restored');
      assert.equal(returned.harness.starts.length, before.harness.starts.length, 'Restoration does not start another engine');
      assert.equal(returned.harness.locks.length, before.harness.locks.length, 'Restoration never reacquires ownership');
      assert.equal(returned.readiness.current.state, 'reload_required');
      await expectUI(page, { sheet: 'save_protection', trialRunning: false });
      assert.deepEqual(durable(await ui(page)), oldState, 'Protected restored heap remains its original state');
      const writeCount = persisted.writes;
      assert.equal((await diagnostics(page)).harness.writes.length, writeCount, 'Trusted pageshow restoration itself makes no storage writes');
      await protectedControls(page, newestStorage, test, false);
      assert.equal((await diagnostics(page)).harness.writes.length, writeCount, 'Restored protection makes no new save attempts');
      assert.ok((await ui(page)).labels.some(label => label.text.includes('再読み込み')), 'Actual protection screen gives reload guidance');
      await reloadExact(page, latest);
      assert.equal((await storage(page))[P], newestStorage[P]);
      await shot(page, test.name + '-latest-reload');
      test.latestCheckpointLoaded = true;
      test.initialCheckpointSHA256 = digest(baseline[P]);
    });
  } catch (error) {
    report.fatal = error.stack || String(error);
  } finally {
    await browser?.close();
    report.finishedAt = new Date().toISOString();
    report.summary = {
      passed: report.tests.filter(test => test.status === 'passed').length,
      failed: report.tests.filter(test => test.status === 'failed').length,
      blocked: report.tests.filter(test => test.status === 'blocked').length,
    };
    report.status = report.fatal || report.summary.failed ? 'failed' : report.summary.blocked ? 'blocked' : 'passed';
    process.exitCode = report.status === 'failed' ? 1 : report.status === 'blocked' ? 2 : 0;
    saveReport();
    console.log('BROWSER_WRITER_READINESS ' + JSON.stringify({ status: report.status, ...report.summary, report: path.join(output, 'writer-readiness.json') }));
  }
})();
