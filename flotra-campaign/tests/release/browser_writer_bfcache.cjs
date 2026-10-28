'use strict';
// Native Chromium CDP pipe: no Playwright Page/lifecycle bookkeeping, no fake
// persisted events and no flags that force cache eligibility. Disposable only.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { createHash } = require('node:crypto');
const { StringDecoder } = require('node:string_decoder');
const observer = require('./browser_writer_observer.cjs');
const P = 'flotra.campaign.dispatch.v5';
const durable = state => Object.fromEntries(['wallet', 'growth', 'progress', 'status', 'upgrades', 'currentContract', 'simTime', 'speed', 'preferences', 'operation', 'layout'].map(key => [key, state[key]]));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
module.exports = async function verifyNativeBFCache({ url, output, encoded, executable }) {
  const target = new URL(url);
  assert.ok(['http:', 'https:'].includes(target.protocol) && ['127.0.0.1', 'localhost', '[::1]'].includes(target.hostname) && !target.username && !target.password, 'Disposable loopback only');
  assert.ok(typeof encoded === 'string' && encoded.length > 0, 'Actual UI-earned checkpoint required');
  target.searchParams.set('phone_qa', '1');
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'flotra-native-bfcache-'));
  const report = { name: 'real-bfcache-restoration', status: 'running', driver: 'Native Chromium CDP pipe, real history navigation', events: [], errors: [] };
  let sequence = 0, buffer = '', context, oldTab, helperTab;
  const destroyedTargets = new Set();
  const fingerprints = values => Object.fromEntries(Object.entries(values).map(([key, value]) => [key, { bytes: Buffer.byteLength(value), sha256: createHash('sha256').update(value).digest('hex') }]));
  const decoder = new StringDecoder('utf8');
  const pending = new Map(), sessions = new Map();
  const process = spawn(executable, ['--headless=new', '--no-sandbox', '--remote-debugging-pipe', '--disable-dev-shm-usage', '--no-first-run', '--no-default-browser-check', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--user-data-dir=' + profile], { stdio: ['ignore', 'ignore', 'pipe', 'pipe', 'pipe'] });
  const stderr = fs.createWriteStream(path.join(output, 'native-bfcache-browser.log'));
  process.stderr.pipe(stderr);
  const rejectPending = error => { for (const item of pending.values()) { clearTimeout(item.timer); item.reject(error); } pending.clear(); };
  process.on('error', rejectPending);
  process.on('exit', code => rejectPending(new Error('Native Chromium exited: ' + code)));
  function call(method, params = {}, sessionId) {
    return new Promise((resolve, reject) => {
      const id = ++sequence;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error('CDP timeout: ' + method)); }, 30000);
      pending.set(id, { resolve, reject, timer });
      process.stdio[3].write(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }) + '\0', error => { if (error) { clearTimeout(timer); pending.delete(id); reject(error); } });
    });
  }
  process.stdio[4].on('data', bytes => {
    buffer += decoder.write(bytes);
    let end;
    while ((end = buffer.indexOf('\0')) >= 0) {
      const message = JSON.parse(buffer.slice(0, end)); buffer = buffer.slice(end + 1);
      if (message.id) {
        const item = pending.get(message.id);
        if (!item) continue;
        pending.delete(message.id); clearTimeout(item.timer);
        if (message.error) item.reject(new Error(message.error.message)); else item.resolve(message.result);
      } else if (message.method === 'Target.targetDestroyed') {
        destroyedTargets.add(message.params.targetId);
      } else if (message.sessionId && sessions.has(message.sessionId)) {
        const events = sessions.get(message.sessionId);
        if (message.method === 'Page.backForwardCacheNotUsed') report.events.push({ session: message.sessionId, ...message.params });
        if (message.method === 'Runtime.exceptionThrown') report.errors.push(message.params.exceptionDetails.text);
        if (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') report.errors.push(message.params.args.map(a => a.value ?? a.description ?? '').join(' '));
        events.push(message);
      }
    }
  });
  async function tab() {
    const { targetId } = await call('Target.createTarget', { url: 'about:blank', browserContextId: context });
    const { sessionId } = await call('Target.attachToTarget', { targetId, flatten: true });
    sessions.set(sessionId, []);
    const send = (method, params) => call(method, params, sessionId);
    await send('Page.enable'); await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
    await send('Page.addScriptToEvaluateOnNewDocument', { source: '(' + observer.toString() + ')({});' });
    return { targetId, sessionId, send };
  }
  async function evaluate(t, expression) {
    const r = await t.send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.text + ': ' + (r.exceptionDetails.exception?.description || ''));
    return r.result.value;
  }
  async function until(t, expression, label, timeout = 15000) {
    const deadline = Date.now() + timeout;
    do {
      try { const value = await evaluate(t, expression); if (value) return value; }
      catch (error) { if (!/context|Cannot find|navigation|undefined|not defined/i.test(error.message)) throw error; }
      await sleep(100);
    } while (Date.now() < deadline);
    throw new Error('Native browser wait timed out: ' + label);
  }
  const ui = t => evaluate(t, 'window.FlotraViewport?.uiMetrics || null');
  const store = t => evaluate(t, 'Object.fromEntries(Object.keys(localStorage).sort().map(k=>[k,localStorage.getItem(k)]))');
  const data = t => evaluate(t, 'window.__writerHarness.data');
  async function navigate(t, href) {
    const r = await t.send('Page.navigate', { url: href });
    assert.ok(!r.errorText, 'Native navigation succeeded');
    await until(t, 'location.href === ' + JSON.stringify(href) + ' && document.readyState === "complete"', 'actual document load', 120000);
  }
  async function ready(t, sheet = 'entry') {
    await until(t, 'window.FlotraViewport?.uiMetrics?.sheet === ' + JSON.stringify(sheet) + ' && window.FlotraViewport.uiMetrics.trialRunning === false', 'real game UI', 120000);
    await sleep(260);
    const h = await data(t);
    assert.equal(h.engineInstances, 1); assert.equal(h.starts.length, 1);
    assert.equal(h.starts[0].state, 'fulfilled');
    assert.ok(h.statuses.some(item => item.text.includes('保存データの安全を確認しています')));
    assert.equal(await evaluate(t, 'window.FlotraDispatchStore.readiness().current.state'), 'held');
  }
  async function click(t, name, disabled = false) {
    for (let attempt = 0; attempt < 18; attempt++) {
      const state = await ui(t), b = state?.buttons.find(b => b.name === name && b.visible);
      assert.ok(b, 'Real native UI control exists: ' + name); assert.equal(b.disabled, disabled);
      const canvas = await evaluate(t, '(()=>{const r=document.querySelector("#canvas").getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height};})()');
      const x = canvas.x + b.x + b.width / 2, y = canvas.y + b.y + b.height / 2;
      const s = state.scroll;
      if (y > canvas.y && y < canvas.y + canvas.height && (!s || (b.y >= s.y && b.y + b.height <= s.y + s.height) || ['Back', 'PauseResume', 'CloseSheet'].includes(name))) {
        await t.send('Input.dispatchMouseEvent', { type: 'mouseMoved', x, y });
        await t.send('Input.dispatchMouseEvent', { type: 'mousePressed', button: 'left', buttons: 1, clickCount: 1, x, y });
        await sleep(90);
        await t.send('Input.dispatchMouseEvent', { type: 'mouseReleased', button: 'left', buttons: 0, clickCount: 1, x, y });
        await sleep(300); return;
      }
      assert.ok(s, 'Native scroll area exists');
      await t.send('Input.dispatchMouseEvent', { type: 'mouseWheel', x: canvas.x + s.x + s.width / 2, y: canvas.y + s.y + s.height / 2, deltaX: 0, deltaY: 160 });
      await sleep(200);
    }
    assert.fail('Could not reveal native UI control: ' + name);
  }
  async function screenshot(t, name) {
    const r = await t.send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(path.join(output, name + '.png'), Buffer.from(r.data, 'base64'));
  }
  try {
    report.browser = await call('Browser.getVersion');
    await call('Target.setDiscoverTargets', { discover: true });
    ({ browserContextId: context } = await call('Target.createBrowserContext'));
    const helper = helperTab = await tab();
    const away = new URL('writer-away.html', target).href;
    await navigate(helper, away);
    assert.deepEqual(await store(helper), {});
    await evaluate(helper, 'localStorage.setItem(' + JSON.stringify(P) + ',' + JSON.stringify(encoded) + ')');
    const old = oldTab = await tab();
    await navigate(old, target.href); await ready(old); await click(old, 'CloseSheet');
    await until(old, 'window.FlotraViewport.uiMetrics.sheet === ""', 'intro closes');
    const before = await data(old), oldState = durable(await ui(old));
    await navigate(old, away);
    const latest = await tab();
    await navigate(latest, target.href); await ready(latest); await click(latest, 'CloseSheet');
    await click(latest, 'Back'); await until(latest, 'window.FlotraViewport.uiMetrics.sheet === "controls"', 'real controls sheet');
    await click(latest, 'Speed4x');
    await until(latest, 'window.FlotraViewport.uiMetrics.speed === 4 && window.FlotraViewport.uiMetrics.autosave.last_saved_generation >= 0 && localStorage.getItem(' + JSON.stringify(P) + ') !== ' + JSON.stringify(encoded), 'new real UI-earned checkpoint');
    const latestState = durable(await ui(latest));
    const inputs = (await data(latest)).input;
    assert.ok(inputs.some(e => e.type === 'mousedown' && e.trusted) && inputs.some(e => e.type === 'mouseup' && e.trusted), 'Native UI mouse events are trusted');
    report.beforeClose = fingerprints(await store(latest));
    await call('Target.closeTarget', { targetId: latest.targetId });
    // closeTarget only acknowledges a request. Wait for actual destruction and
    // the real writer lock's release before taking the post-close baseline.
    const closedDeadline = Date.now() + 15000;
    while (!destroyedTargets.has(latest.targetId) && Date.now() < closedDeadline) await sleep(50);
    assert.ok(destroyedTargets.has(latest.targetId), 'Latest document was actually destroyed');
    await until(helper, 'navigator.locks.request(' + JSON.stringify(P + '.writer') + ', {mode: "exclusive", ifAvailable: true}, lock => !!lock)', 'latest real writer lock released');
    const newest = await store(helper);
    report.afterClose = fingerprints(newest);
    const envelope = JSON.parse(newest[P]);
    assert.equal(envelope.version, 5); assert.equal(envelope.format, 'flotra-campaign');
    assert.equal(createHash('sha256').update(Buffer.from(envelope.payload, 'base64').toString('hex')).digest('hex'), envelope.sha256);
    await call('Target.activateTarget', { targetId: old.targetId });
    const history = await old.send('Page.getNavigationHistory');
    const entry = history.entries[history.currentIndex - 1];
    assert.equal(entry.url, target.href);
    await old.send('Page.navigateToHistoryEntry', { entryId: entry.id });
    await until(old, 'location.href === ' + JSON.stringify(target.href) + ' && window.__writerHarness?.data.lifecycle.some(e=>e.type === "pageshow")', 'actual Back navigation', 120000);
    const returned = await data(old);
    const persisted = returned.lifecycle.find(e => e.type === 'pageshow' && e.persisted && e.trusted);
    report.lifecycle = { beforeRealm: before.realm, returnedRealm: returned.realm, events: returned.lifecycle };
    if (!persisted) {
      await ready(old);
      assert.deepEqual(durable(await ui(old)), latestState, 'Actual fallback reload reads latest checkpoint');
      assert.deepEqual(report.errors, []);
      report.status = 'blocked'; report.reason = 'No trusted persisted pageshow; no synthetic event counts as coverage.';
      await screenshot(old, 'native-bfcache-not-restored');
      return report;
    }
    assert.equal(returned.realm, before.realm, 'Actual old JS heap restored');
    assert.equal(returned.engineInstances, before.engineInstances); assert.equal(returned.starts.length, before.starts.length); assert.equal(returned.locks.length, before.locks.length);
    await until(old, 'window.FlotraDispatchStore.readiness().current.state === "reload_required" && window.FlotraViewport.uiMetrics.sheet === "save_protection" && !window.FlotraViewport.uiMetrics.trialRunning', 'restored heap protects saves');
    assert.deepEqual(durable(await ui(old)), oldState, 'Restored heap preserves old observed state');
    assert.equal(returned.writes.length, persisted.writes, 'Restoration itself attempts no storage writes');
    async function protectedState() {
      const state = await ui(old);
      assert.equal(state.sheet, 'save_protection'); assert.equal(state.trialRunning, false);
      const storageNow = await store(helper);
      (report.protectionSnapshots ||= []).push({ writes: (await data(old)).writes.length, storage: fingerprints(storageNow) });
      assert.deepEqual(durable(state), oldState); assert.deepEqual(storageNow, newest);
      assert.equal((await data(old)).writes.length, persisted.writes);
      for (const [name, text] of [['Back', '保護中'], ['PauseResume', '停止中'], ['CloseSheet', '停止中']]) {
        const b = state.buttons.find(b => b.name === name && b.visible);
        assert.ok(b, 'Protected control exists: ' + name); assert.equal(b.disabled, true); assert.equal(b.text, text);
      }
    }
    await protectedState();
    for (const name of ['Back', 'PauseResume', 'CloseSheet', 'Back']) await click(old, name, true);
    for (let i = 0; i < 6; i++) for (const [key, code] of [['Tab', 9], ['Enter', 13]]) {
      await old.send('Input.dispatchKeyEvent', { type: 'keyDown', key, code: key, windowsVirtualKeyCode: code });
      await old.send('Input.dispatchKeyEvent', { type: 'keyUp', key, code: key, windowsVirtualKeyCode: code });
    }
    await sleep(500); await protectedState();
    assert.ok((await data(old)).input.some(e => e.type === 'keydown' && e.trusted), 'Protected keyboard events were trusted');
    for (const [width, height] of [[1180, 660], [1280, 720]]) {
      await old.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
      await sleep(600); await protectedState();
    }
    assert.ok((await ui(old)).labels.some(l => l.text.includes('再読み込み')));
    await screenshot(old, 'native-bfcache-protected');
    await old.send('Page.reload'); await ready(old);
    assert.deepEqual(durable(await ui(old)), latestState, 'Explicit reload loads newest real checkpoint');
    assert.deepEqual(await store(helper), newest, 'Reload preserves exact primary/backup bytes');
    assert.deepEqual(report.errors, []);
    await screenshot(old, 'native-bfcache-latest-reload');
    report.latestCheckpointLoaded = true; report.protectedControls = { realMouse: true, keyboard: true, resizeAndFrameRefresh: true, explicitReload: true };
    report.status = 'passed';
  } catch (error) { report.status = 'failed'; report.error = (error.stack || String(error)).replace(/[A-Za-z0-9+/]{80,}={0,2}/g, '[encoded data redacted]').slice(0, 6000); }
  finally {
    if (oldTab) report.finalObserver = await data(oldTab).then(d => ({ realm: d.realm, writes: d.writes, locks: d.locks, starts: d.starts })).catch(error => ({ error: error.message }));
    if (helperTab) report.finalStorage = await store(helperTab).then(fingerprints).catch(error => ({ error: error.message }));
    fs.writeFileSync(path.join(output, 'native-bfcache.json'), JSON.stringify(report, null, 2));
    if (process.pid && process.exitCode === null) await call('Browser.close').catch(() => {});
    if (process.exitCode === null) process.kill('SIGTERM');
    process.stderr.unpipe(stderr); stderr.end();
  }
  return report;
};
