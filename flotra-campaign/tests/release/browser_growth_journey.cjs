#!/usr/bin/env node
'use strict';
// Real browser/WebGL regression check, separate from headless Godot unit tests.
// Serve docs/godot-jobs-preview, then:
// CHROMIUM_EXECUTABLE=/usr/bin/chromium \
//   node flotra-campaign/tests/release/browser_phone_geometry.cjs http://127.0.0.1:8000/godot-jobs-preview/ /tmp/flotra-phone-browser
// This tests Chromium emulation, not physical iPhone/Safari compatibility.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const requestedURL = process.argv[2];
const output = process.argv[3] || '/tmp/flotra-phone-browser';
if (!requestedURL) throw new Error('Supply the local or published FLOTRA export URL');
const testURL = new URL(requestedURL);
testURL.searchParams.set('phone_qa', '1');
const url = testURL.href;
fs.mkdirSync(output, { recursive: true });
const allCases = [[375, 567], [375, 667], [390, 844], [430, 932]];
const selectedCases = process.env.FLOTRA_TEST_CASES?.split(',');
const cases = selectedCases ? allCases.filter(([width, height]) => selectedCases.includes(`${width}x${height}`)) : allCases;
assert.ok(cases.length > 0, 'At least one known phone case is selected');
const dprs = process.env.FLOTRA_TEST_DPRS ? process.env.FLOTRA_TEST_DPRS.split(',').map(Number) : [1, 2, 3];
const tapHold = Number(process.env.FLOTRA_TAP_HOLD_MS ?? 90);
assert.ok(Number.isFinite(tapHold) && tapHold >= 0 && tapHold <= 500, 'Supported touch hold duration');
const freshOnly = process.env.FLOTRA_FRESH_ONLY === '1';
const report = { kind: 'Chromium CSS viewport/DPR/WebGL emulation; not physical device verification', url, configuration: { tapHoldMilliseconds: tapHold, freshContextOnly: freshOnly }, results: [] };
const closeEnough = (actual, expected, label, tolerance = 1) => assert.ok(Math.abs(actual - expected) <= tolerance, `${label}: ${actual} != ${expected}`);
const cdpSessions = new WeakMap();

async function session(page, context) {
  if (!cdpSessions.has(page)) cdpSessions.set(page, await context.newCDPSession(page));
  return cdpSessions.get(page);
}

async function touchAt(page, context, x, y) {
  if (tapHold === 0) {
    await page.touchscreen.tap(x, y);
    return;
  }
  const cdp = await session(page, context);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ id: 0, x, y }] });
  // Hold across a rendering/refresh boundary to detect real press cancellation
  // bugs. A zero-duration tap can complete before a faulty refresh runs.
  await page.waitForTimeout(tapHold);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function measure(page) {
  return page.evaluate(() => {
    const c = document.querySelector('#canvas');
    return {
      viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio, visualHeight: visualViewport?.height, visualScale: visualViewport?.scale },
      canvas: { width: c.width, height: c.height, rect: c.getBoundingClientRect().toJSON() },
      bridge: window.FlotraViewport?.read(),
      engine: window.FlotraViewport?.engineMetrics,
      status: document.querySelector('#status')?.innerText || '',
    };
  });
}

async function installDOMTrace(page) {
  if (process.env.FLOTRA_DOM_TRACE !== '1') return;
  await page.addInitScript(() => {
    window.__phoneDomTrace = [];
    for (const type of ['touchstart', 'touchmove', 'touchend', 'touchcancel', 'mousedown', 'mousemove', 'mouseup', 'focus', 'blur']) {
      window.addEventListener(type, event => {
        const canvas = document.querySelector('#canvas');
        const rect = canvas?.getBoundingClientRect();
        const points = event.changedTouches ? Array.from(event.changedTouches).map(touch => ({ id: touch.identifier, x: touch.clientX, y: touch.clientY })) : [{ x: event.clientX, y: event.clientY }];
        window.__phoneDomTrace.push({ type, ms: performance.now(), target: event.target?.id || event.target?.nodeName, points, dpr: devicePixelRatio, viewport: [innerWidth, innerHeight], canvas: rect ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height, backingWidth: canvas.width, backingHeight: canvas.height } : null });
        if (window.__phoneDomTrace.length > 2000) window.__phoneDomTrace.shift();
      }, { capture: true, passive: true });
    }
  });
}

function verify(m, label) {
  assert.ok(m.bridge && m.engine, `${label}: actual bridge and engine metrics must be present`);
  const r = m.canvas.rect;
  assert.ok(r.width > 0 && r.height > 0, `${label}: nonempty canvas`);
  closeEnough(m.canvas.width, Math.round(r.width * m.viewport.dpr), `${label}: full-DPR backing width`);
  closeEnough(m.canvas.height, Math.round(r.height * m.viewport.dpr), `${label}: full-DPR backing height`);
  closeEnough(m.bridge.width, r.width, `${label}: bridge CSS width`);
  closeEnough(m.bridge.height, r.height, `${label}: bridge CSS height`);
  closeEnough(m.engine.logicalWidth, Math.round(r.width), `${label}: Godot logical width is CSS width`);
  closeEnough(m.engine.logicalHeight, Math.round(r.height), `${label}: Godot logical height is CSS height`);
  closeEnough(m.engine.hudWidth, Math.round(r.width), `${label}: actual HUD width is CSS width`);
  closeEnough(m.engine.hudHeight, Math.round(r.height), `${label}: actual HUD height is CSS height`);
  closeEnough(m.engine.rootWidth, m.canvas.width, `${label}: Godot backing width`);
  closeEnough(m.engine.rootHeight, m.canvas.height, `${label}: Godot backing height`);
  closeEnough(m.engine.scaleX, m.canvas.width / m.engine.logicalWidth, `${label}: engine X scaling`, 0.02);
  closeEnough(m.engine.scaleY, m.canvas.height / m.engine.logicalHeight, `${label}: engine Y scaling`, 0.02);
  assert.ok(r.x >= -1 && r.y >= -1 && r.right <= m.viewport.width + 1 && r.bottom <= m.viewport.height + 1, `${label}: canvas stays inside browser viewport`);
}

async function settle(page) {
  await page.waitForFunction(() => {
    const c = document.querySelector('#canvas');
    const e = window.FlotraViewport?.engineMetrics;
    if (!c || !e) return false;
    const r = c.getBoundingClientRect();
    return Math.abs(e.logicalWidth - Math.round(r.width)) <= 1 && Math.abs(e.logicalHeight - Math.round(r.height)) <= 1 && e.rootWidth === c.width && e.rootHeight === c.height;
  }, null, { timeout: 15000 });
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function ui(page) {
  return page.evaluate(() => window.FlotraViewport?.uiMetrics);
}

async function expectUI(page, expected) {
  await page.waitForFunction(expected => {
    const state = window.FlotraViewport?.uiMetrics;
    return state && Object.entries(expected).every(([key, value]) => state[key] === value);
  }, expected, { timeout: 10000 });
  // The app deliberately rejects stale input for 180ms after sheet dismissal.
  await page.waitForTimeout(220);
}

async function swipe(page, context, rect, upward, requestedDistance) {
  const canvas = (await measure(page)).canvas.rect;
  const cdp = await session(page, context);
  const x = canvas.x + rect.x + rect.width / 2;
  const bottom = canvas.y + rect.y + rect.height - 16;
  const top = canvas.y + rect.y + 16;
  const start = upward ? bottom : top;
  const distance = Math.min(bottom - top, requestedDistance || bottom - top);
  const end = start + (upward ? -distance : distance);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: start }] });
  for (let step = 1; step <= 9; step++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: start + (end - start) * step / 9 }] });
    await page.waitForTimeout(25);
  }
  // Hold at the end so this is a deliberate drag, not an uncontrolled fling in
  // a short editor scroll area whose entire range can be smaller than a swipe.
  await page.waitForTimeout(250);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  let previous;
  let stable = 0;
  for (let sample = 0; sample < 15 && stable < 3; sample++) {
    await page.waitForTimeout(200);
    const current = (await ui(page))?.scroll?.scrollVertical;
    stable = current === previous ? stable + 1 : 0;
    previous = current;
  }
}

async function button(page, name) {
  // UI diagnostics arrive after rendered input, especially on software GPUs.
  // Wait for the requested real control, rather than reading a stale sheet.
  await page.waitForFunction(name => window.FlotraViewport?.uiMetrics?.buttons.some(item => item.name === name && item.visible), name, { timeout: 10000 });
  const state = await ui(page);
  const result = state?.buttons.find(item => item.name === name && item.visible);
  assert.ok(result, `Visible real engine button exists: ${name}`);
  return result;
}

async function tapName(page, context, name, scrollable = false) {
  console.log(`TOUCH ${name}`);
  let stalled = 0;
  for (let attempt = 0; attempt < 24; attempt++) {
    const control = await button(page, name);
    const state = await ui(page);
    const m = await measure(page);
    const x = control.x + control.width / 2;
    const y = control.y + control.height / 2;
    const scroll = state.scroll;
    const inCanvas = x >= 0 && x <= m.canvas.rect.width && y >= 0 && y <= m.canvas.rect.height;
    const inScroll = !scrollable || (y >= scroll.y + 8 && y <= scroll.y + scroll.height - 8);
    if (inCanvas && inScroll) {
      assert.ok(!control.disabled, `Touchable button is enabled: ${name}`);
      assert.ok(control.height >= 48 && control.fontSize >= 18, `Readable CSS target: ${name}`);
      verify(m, `before touching ${name}`);
      console.log(`POINT ${name}: ${m.canvas.rect.x + x},${m.canvas.rect.y + y}; CSS ${m.engine.logicalWidth}x${m.engine.logicalHeight}; DPR ${m.viewport.dpr}`);
      await touchAt(page, context, m.canvas.rect.x + x, m.canvas.rect.y + y);
      await page.waitForTimeout(240);
      return;
    }
    assert.ok(scroll?.height > 32, `A usable scroll area can reveal ${name}`);
    const distance = Math.max(24, Math.abs(y - (scroll.y + scroll.height / 2)));
    await swipe(page, context, scroll, y > scroll.y + scroll.height / 2, distance);
    const after = (await ui(page)).scroll.scrollVertical;
    console.log(`SCROLL ${name}: ${scroll.scrollVertical} -> ${after}`);
    stalled = after === scroll.scrollVertical ? stalled + 1 : 0;
    if (stalled >= 3) throw new Error(`Real touch drag did not move the scroll area for ${name} at ${after}`);
  }
  throw new Error(`Real touch scrolling could not reveal ${name}`);
}

async function touchJourney(page, context, label, result) {
  await expectUI(page, { sheet: '' });
  await tapName(page, context, 'Back');
  await expectUI(page, { sheet: 'entry' });
  await tapName(page, context, 'StartTrial', true);
  await expectUI(page, { sheet: '' });
  await tapName(page, context, 'WorkChoice');
  await expectUI(page, { sheet: 'jobs' });
  await page.screenshot({ path: path.join(output, `contracts-${label}.png`), scale: 'css' });
  await tapName(page, context, 'AcceptContract_growth_1', true);
  await expectUI(page, { sheet: '', trialRunning: true });
  await page.screenshot({ path: path.join(output, `running-${label}.png`), scale: 'css' });
  await tapName(page, context, 'PauseResume');
  await expectUI(page, { sheet: '', trialRunning: false });

  // Real 3D selection goes through browser touch -> canvas origin/DPR mapping ->
  // Godot root transform -> SubViewport input -> ray picking. No direct mutation.
  const state = await ui(page);
  const m = await measure(page);
  assert.ok(state.slots?.shelf, 'Actual projected shelf location is available');
  await touchAt(page, context, m.canvas.rect.x + state.slots.shelf.x, m.canvas.rect.y + state.slots.shelf.y);
  await expectUI(page, { sheet: 'editor', selectedSlot: 'shelf', trialRunning: false });
  await tapName(page, context, 'NextSlot');
  await expectUI(page, { sheet: 'editor', selectedSlot: 'packing', trialRunning: false });
  await tapName(page, context, 'PreviousSlot');
  await expectUI(page, { sheet: 'editor', selectedSlot: 'shelf', trialRunning: false });
  const candidate = (await ui(page)).buttons.find(item => item.name.startsWith('Candidate_') && item.visible && !item.disabled && !item.text.includes('使用中'));
  assert.ok(candidate, 'An alternate real placement is selectable');
  await tapName(page, context, candidate.name, true);
  await page.waitForFunction(() => window.FlotraViewport.uiMetrics.buttons.some(item => item.name === 'ApplyChoice' && item.visible && !item.disabled), null, { timeout: 10000 });
  const apply = await button(page, 'ApplyChoice');
  const beforeApply = await measure(page);
  assert.ok(apply.y >= 0 && apply.y + apply.height <= beforeApply.canvas.rect.height, 'Apply is pinned inside the CSS viewport');
  assert.ok(apply.y >= (await ui(page)).scroll.y + (await ui(page)).scroll.height, 'Apply stays outside the scrolling content');
  await page.screenshot({ path: path.join(output, `editor-${label}.png`), scale: 'css' });
  await tapName(page, context, 'ApplyChoice');
  await expectUI(page, { sheet: '', trialRunning: false });
  await tapName(page, context, 'SessionRecord');
  await expectUI(page, { sheet: 'records', trialRunning: false });
  await page.screenshot({ path: path.join(output, `results-${label}.png`), scale: 'css' });
  await tapName(page, context, 'CloseSheet');
  await expectUI(page, { sheet: '', trialRunning: false });
  result.touch = { introClose: true, introScrollAndStart: true, contractAcceptance: true, pause: true, worldShelfPick: true, equipmentTabs: true, candidateSelection: true, pinnedApply: true, results: true, finalState: await ui(page) };
}


const fixturesDirectory = process.argv[4];
assert.ok(fixturesDirectory, 'Supply a directory of domain-earned, validated test fixtures');
const percentile = (values, fraction) => [...values].sort((a,b)=>a-b)[Math.min(values.length-1, Math.floor(values.length*fraction))];
async function boot(page) {
  await page.goto(url, { waitUntil:'domcontentloaded', timeout:60000 });
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics, null, {timeout:120000});
  await settle(page); await expectUI(page,{sheet:'entry'});
  verify(await measure(page),'growth journey actual WebGL');
}
async function closeSheets(page,context) {
  for(let i=0;i<3;i++) {
    const previous=(await ui(page)).sheet;
    if(!previous) break;
    await tapName(page,context,'CloseSheet');
    await page.waitForFunction(previous=>window.FlotraViewport.uiMetrics.sheet!==previous,previous,{timeout:10000});
  }
  await expectUI(page,{sheet:''});
}
async function setRunning(page,context,running) {
  if ((await ui(page)).trialRunning !== running) await tapName(page,context,'PauseResume');
  await expectUI(page,{trialRunning:running});
}
async function samplePerformance(page,milliseconds) {
  return page.evaluate(ms=>new Promise(resolve=>{
    const frames=[],metrics=[];let last=performance.now(),start=last;
    function frame(now){frames.push(now-last);last=now;const p=window.FlotraViewport?.uiMetrics?.performance;if(p)metrics.push({...p});
      if(now-start<ms)requestAnimationFrame(frame);else resolve({frames:frames.slice(5),metrics:metrics.slice(5),elapsed:now-start});}
    requestAnimationFrame(frame);
  }),milliseconds);
}
(async()=>{
 let browser;
 const result={kind:'Isolated actual Chromium WebGL growth journey, old-save migration and late-state performance; not physical Safari', tests:[]};
 try {
  browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE||undefined,headless:true});
  async function scenario(name,fixture,action){
   if(process.env.FLOTRA_JOURNEY_CASES && !process.env.FLOTRA_JOURNEY_CASES.split(',').includes(name))return;
   const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:3,isMobile:true,hasTouch:true});
   if(fixture)await context.addInitScript(encoded=>localStorage.setItem('flotra.campaign.release.v1',encoded),fixture.encoded);
   const page=await context.newPage();const errors=[];
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   const test={name};result.tests.push(test);
   try{await boot(page);test.environment=await page.evaluate(()=>{
    const gl=document.querySelector('#canvas').getContext('webgl2');
    const ext=gl?.getExtension('WEBGL_debug_renderer_info');
    return {visibility:document.visibilityState,dpr:devicePixelRatio,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):null};
   });await action(page,context,test);assert.deepEqual(errors,[]);test.status='passed';}
   catch(error){test.status='failed';test.error=error.message;test.last=await ui(page).catch(()=>null);await page.screenshot({path:path.join(output,'failure-'+name+'.png'),scale:'css'}).catch(()=>{});throw error;}
   finally{test.errors=errors;fs.writeFileSync(path.join(output,'growth-journey.json'),JSON.stringify(result,null,2));await context.close();}
  }
  await scenario('fresh-growth',null,async(page,context,test)=>{
   const started=Date.now();await tapName(page,context,'CloseSheet');await expectUI(page,{sheet:'jobs'});
   await tapName(page,context,'AcceptContract_growth_1',true);await expectUI(page,{sheet:'',trialRunning:true});
   await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.status==='contract_complete',null,{timeout:90000});
   let state=await ui(page);assert.equal(state.wallet,240);assert.equal(state.progress.shipped,12);
   test.firstDeliveryWallSeconds=(Date.now()-started)/1000;
   await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});
   await tapName(page,context,'Tab_upgrades');await tapName(page,context,'BuyUpgrade_wing_1',true);
   await expectUI(page,{sheet:''});await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.growth.wing_count===1);
   state=await ui(page);assert.equal(state.wallet,90);test.firstExpansionWallSeconds=(Date.now()-started)/1000;
   assert.ok(test.firstExpansionWallSeconds<60,'First real expansion arrives within 60 seconds with real touch navigation');
   await page.screenshot({path:path.join(output,'first-earned-expansion.png'),scale:'css'});
   await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'Tab_upgrades');
   await tapName(page,context,'BuyUpgrade_crew_4',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.growth.human_count===4);
   assert.equal((await ui(page)).wallet,0);await closeSheets(page,context);
   await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
   await settle(page);state=await ui(page);assert.equal(state.wallet,0);assert.equal(state.growth.wing_count,1);assert.equal(state.growth.human_count,4);assert.equal(state.trialRunning,false);
   test.reload={wallet:state.wallet,wings:state.growth.wing_count,humans:state.growth.human_count,paused:!state.trialRunning};
   await closeSheets(page,context);await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'Tab_contracts');
   await tapName(page,context,'AcceptContract_growth_2',true);await expectUI(page,{sheet:'',trialRunning:true});
   await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.status==='contract_complete',null,{timeout:90000});
   assert.equal((await ui(page)).wallet,200);test.zeroWalletRecovery=true;
  });
  const legacy=JSON.parse(fs.readFileSync(path.join(fixturesDirectory,'legacy.json'),'utf8'));
  await scenario('legacy-inflight',legacy,async(page,context,test)=>{
   let state=await ui(page);assert.equal(state.wallet,legacy.wallet);assert.equal(state.progress.shipped,legacy.shipped);assert.equal(state.simTime,legacy.time);assert.equal(state.growth.legacy_profile,true);assert.deepEqual(state.upgrades,legacy.upgrades);assert.equal(state.trialRunning,false);
   await closeSheets(page,context);await setRunning(page,context,true);
   await page.waitForTimeout(1200);await tapName(page,context,'PauseResume');await expectUI(page,{trialRunning:false});
   state=await ui(page);assert.ok(state.simTime>legacy.time);test.preserved=true;test.resumedAt=state.simTime;
   await page.screenshot({path:path.join(output,'legacy-save-preserved.png'),scale:'css'});
  });
  const late=JSON.parse(fs.readFileSync(path.join(fixturesDirectory,'late.json'),'utf8'));
  await scenario('mature-performance',late,async(page,context,test)=>{
   let state=await ui(page);assert.equal(state.growth.wing_count,4);assert.equal(state.growth.robot_count,4);assert.equal(state.progress.shipped,late.shipped);assert.equal(state.wallet,late.wallet);assert.equal(state.trialRunning,false);
   await closeSheets(page,context);await setRunning(page,context,false);await page.waitForTimeout(1000);
   const idle=await samplePerformance(page,6000);
   await tapName(page,context,'SessionRecord');await expectUI(page,{sheet:'records',worldVisible:false});
   await page.waitForTimeout(800);
   const uiOnly=await samplePerformance(page,6000);
   await closeSheets(page,context);await expectUI(page,{worldVisible:true});
   await setRunning(page,context,true);await page.waitForTimeout(1000);
   const active=await samplePerformance(page,12000);
   await tapName(page,context,'PauseResume');await expectUI(page,{trialRunning:false});await page.waitForTimeout(500);
   await page.screenshot({path:path.join(output,'mature-warehouse.png'),scale:'css'});
   await page.setViewportSize({width:375,height:567});await settle(page);verify(await measure(page),'mature shortphone');
   await page.screenshot({path:path.join(output,'mature-short-phone.png'),scale:'css'});
   const idleAfter=await samplePerformance(page,6000);
   function summarize(samples){const cpu=samples.metrics.map(m=>m.processMs),nodes=samples.metrics.map(m=>m.nodes),draws=samples.metrics.map(m=>m.drawCalls);return {rafMedianMs:percentile(samples.frames,.5),rafP95Ms:percentile(samples.frames,.95),processMedianMs:percentile(cpu,.5),processP95Ms:percentile(cpu,.95),nodesMin:Math.min(...nodes),nodesMax:Math.max(...nodes),drawCallsMax:Math.max(...draws)};}
   test.performance={uiOnly:summarize(uiOnly),idle:summarize(idle),active:summarize(active),idleAfter:summarize(idleAfter)};
   assert.ok(test.performance.idleAfter.nodesMax-test.performance.idleAfter.nodesMin<=4,'Mature paused warehouse has stable node count');
   assert.ok(test.performance.active.processP95Ms<100,'Mature simulation/render CPU updates stay below 100ms on software Chromium');
   assert.ok(test.performance.active.drawCallsMax<=250,'Mature geometry stays within 250 draw calls, including shadows');
   // A full-DPR HUD-only diagnostic already costs ~117ms on this cloud
   // SwiftShader renderer; do not confuse that compositor floor with 3D cost.
   // Budget the added warehouse work against the same-run covered-menu baseline.
   assert.ok(test.performance.active.rafMedianMs<=Math.max(75,test.performance.uiOnly.rafMedianMs*1.75) && test.performance.active.rafP95Ms<=Math.max(120,test.performance.uiOnly.rafP95Ms*2),'Mature 3D overhead stays within the same-renderer baseline budget');
   state=await ui(page);test.progress={before:late.shipped,after:state.progress.shipped,time:state.simTime};assert.ok(state.simTime>late.time);
   const keys=await page.evaluate(()=>Object.keys(localStorage));assert.ok(keys.every(k=>k==='flotra.campaign.release.v1'||k==='flotra.campaign.release.v1.backup'),'Only isolated campaign save keys written');
  });
  assert.ok(result.tests.length>0,'At least one requested journey scenario ran');
  console.log(`BROWSER_GROWTH_JOURNEY ${result.tests.length} scenarios passed`);
 }catch(error){result.error=error.message;console.error(error);process.exitCode=1;}
 finally{fs.writeFileSync(path.join(output,'growth-journey.json'),JSON.stringify(result,null,2));await browser?.close();}
})();
