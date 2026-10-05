#!/usr/bin/env node
'use strict';
// Actual Chromium/WebGL input; never calls game mutation APIs. Optional fixture
// imports are domain-earned saves installed only in new isolated test contexts.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const requestedURL = process.argv[2];
const output = process.argv[3];
const fixturesDirectory = process.argv[4];
const exportedDirectory = process.argv[5];
assert.ok(requestedURL && output && fixturesDirectory, 'Usage: browser_preparation_journey.cjs URL OUTPUT FIXTURES [EXPORTED_DIRECTORY]');
const target = new URL(requestedURL); target.searchParams.set('phone_qa', '1');
const url = target.href;
const tapHold = 90;
fs.mkdirSync(output, {recursive:true});
const report = {kind:'Actual cloud Chromium WebGL; CSS phone emulation at DPR 3, not physical iPhone/Safari', url,
  startedAt:new Date().toISOString(), results:[], hashes:{}};
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
report.hashes.harness = hash(fs.readFileSync(__filename));
if(exportedDirectory) for(const name of ['index.html','index.pck','index.js','index.wasm','campaign-viewport.js','campaign-storage.js']) {
  const file=path.join(exportedDirectory,name); if(fs.existsSync(file))report.hashes[name]=hash(fs.readFileSync(file));
}
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
  const distance = Math.min(bottom - top, 180, (requestedDistance || bottom - top) * 0.5);
  const end = start + (upward ? -distance : distance);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x, y: start }] });
  for (let step = 1; step <= 9; step++) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y: start + (end - start) * step / 9 }] });
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
  }
  // Hold at the end so this is a deliberate drag, not an uncontrolled fling in
  // a short editor scroll area whose entire range can be smaller than a swipe.
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(resolve)))));
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
    const inScroll = !scrollable || (control.y >= scroll.y - 1 && control.y + control.height <= scroll.y + scroll.height + 1);
    if (inCanvas && inScroll) {
      assert.ok(!control.disabled, `Touchable button is enabled: ${name}`);
      assert.ok(control.height >= 56 && control.fontSize >= 18, `Readable CSS target: ${name}`);
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

const saveReport = () => fs.writeFileSync(path.join(output,'preparation-journey.json'),JSON.stringify(report,null,2));
const labelText = (state,name) => state.labels.find(item=>item.name===name)?.text || '';
const immutableProgress = state => ({wallet:state.wallet,currentContract:state.currentContract,status:state.status,simTime:state.simTime,progress:state.progress,results:state.results});
async function stablePause(page) {
  await expectUI(page,{trialRunning:false});
  const before=await ui(page); await page.waitForTimeout(850);
  assert.deepEqual(immutableProgress(await ui(page)),immutableProgress(before),'Pause keeps clock, cargo, records, and wallet unchanged');
  return before;
}
async function boot(page) {
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
  await settle(page);await expectUI(page,{sheet:'entry'});verify(await measure(page),'actual preparation export');
}
async function reloaded(page) {
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
  await settle(page);await expectUI(page,{sheet:'entry',trialRunning:false});
}
async function closeSheets(page,context) {
  for(let i=0;i<4 && (await ui(page)).sheet;i++) {
    const before=await ui(page);
    const signature=before.sheet+'|'+before.buttons.filter(b=>b.visible).map(b=>b.name).join(',');
    await tapName(page,context,'CloseSheet');
    await page.waitForFunction(previous=>{const state=window.FlotraViewport.uiMetrics;return state.sheet+'|'+state.buttons.filter(b=>b.visible).map(b=>b.name).join(',')!==previous;},signature,{timeout:10000});
  }
  await expectUI(page,{sheet:''});
}
async function showJobs(page,context) {
  await closeSheets(page,context);await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});
}
async function prepare(page,context,id) {
  await tapName(page,context,'PrepareContract_'+id,true);
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.buttons.some(b=>b.name==='StartPreparedJob'&&b.visible),null,{timeout:10000});
  await expectUI(page,{sheet:'jobs',trialRunning:false});
}
async function alternateLayout(page,context,apply) {
  const before=(await ui(page)).layout.current;
  if(!(await ui(page)).buttons.some(b=>b.name==='PrepareLayout'&&b.visible)) {
    await tapName(page,context,'TogglePreparationDetails',true);
    await button(page,'PrepareLayout');
  }
  await tapName(page,context,'PrepareLayout',true);await expectUI(page,{sheet:'editor',trialRunning:false});
  const options=(await ui(page)).buttons.filter(b=>b.name.startsWith('Candidate_')&&b.visible&&!b.disabled&&!b.text.includes('使用中'));
  assert.ok(options.length,'Alternate free layout exists');
  await tapName(page,context,options[0].name,true);
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.buttons.some(b=>b.name==='ApplyChoice'&&b.visible&&!b.disabled));
  const action=await button(page,'ApplyChoice'),metrics=await measure(page),state=await ui(page);
  assert.ok(action.height>=56&&action.fontSize>=18,'Pinned Apply retains readable touch geometry');
  assert.ok(action.y>=state.scroll.y+state.scroll.height && action.y+action.height<=metrics.canvas.rect.height,'Apply stays outside scroll and inside phone viewport');
  await tapName(page,context,apply?'ApplyChoice':'CloseSheet');
  await expectUI(page,{sheet:'jobs',trialRunning:false});
  await button(page,'StartPreparedJob');
  if(apply)await page.waitForFunction(old=>window.FlotraViewport.uiMetrics.layout.current!==old,before);
  else assert.equal((await ui(page)).layout.current,before,'Cancel discards selected but unapplied layout');
  return {before,after:(await ui(page)).layout.current,candidate:options[0].name};
}
async function chooseMode(page,context,mode) {
  if((await ui(page)).operation.mode_id===mode)return;
  await tapName(page,context,'ChooseOperation_'+mode,true);
  await page.waitForFunction(mode=>window.FlotraViewport.uiMetrics.operation.mode_id===mode,mode);
  await expectUI(page,{sheet:'jobs'});
  assert.notEqual((await ui(page)).status,'running','Transport selection does not start an active job');
}
async function screenshot(page,name) {
  await page.screenshot({path:path.join(output,name+'.png'),scale:'css'});
}
async function revealLabel(page,context,name) {
  for(let attempt=0;attempt<30;attempt++) {
    const state=await ui(page),label=state.labels.find(l=>l.name===name); assert.ok(label,`Visible label exists: ${name}`);
    const scroll=state.scroll;
    if(label.y>=scroll.y+4&&label.y+Math.min(label.height,60)<=scroll.y+scroll.height-4)return label;
    await swipe(page,context,scroll,label.y>scroll.y,Math.abs(label.y-scroll.y)+70);
  }
  throw new Error('Could not expose label '+name);
}
async function cancellationBurst(page,context,test) {
  await closeSheets(page,context);await tapName(page,context,'Back');await expectUI(page,{sheet:'controls'});
  // Hold requestAnimationFrame callbacks in this isolated context so all three
  // genuine browser touch pairs reach the app before any engine frame. This
  // changes only test scheduling; no game, save, or diagnostic state is edited.
  const control=await button(page,'Speed4x');
  const m=await measure(page);const x=m.canvas.rect.x+control.x+control.width/2,y=m.canvas.rect.y+control.y+control.height/2;
  const cdp=await session(page,context);const before=await ui(page);
  const mark=await page.evaluate(()=>{window.__preparationFrameGate.hold=true;return {frames:window.__preparationFrameGate.frames,events:window.__preparationTouchTrace.length};});
  try {
    for(let pair=0;pair<3;pair++) {
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x,y}]});
      await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]});
    }
    const observed=await page.evaluate(mark=>({frames:window.__preparationFrameGate.frames,events:window.__preparationTouchTrace.slice(mark.events)}),mark);
    assert.equal(observed.frames,mark.frames,'Three genuine touch/cancel pairs arrived before any engine animation frame');
    assert.deepEqual(observed.events.map(e=>e.type),['touchstart','touchcancel','touchstart','touchcancel','touchstart','touchcancel']);
    assert.ok(observed.events.every(e=>e.trusted),'All six input events are browser-trusted CDP inputs');
    test.cancelBurst={scheduler:'Isolated requestAnimationFrame callback gate; original callbacks released afterward',...observed};
  } finally {await page.evaluate(()=>window.__preparationFrameGate.release());}
  await page.waitForTimeout(800);
  assert.equal((await ui(page)).speed,before.speed,'Canceled burst never activates speed button');
  assert.equal((await ui(page)).trialRunning,false,'Canceled input does not start work');
  // Also exercise unsuspended, held cancellation across ordinary live frames.
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x,y}]});
  await page.waitForTimeout(180);await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]});
  await page.waitForTimeout(500);assert.equal((await ui(page)).speed,before.speed,'Ordinary held cancellation does not activate button');
  await tapName(page,context,'Speed4x',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.speed===4);
  test.cancelBurst.freshTouchRecovery=true;test.cancelBurst.ordinaryHeldCancel=true;
  await tapName(page,context,'Speed2x',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.speed===2);
  await closeSheets(page,context);
  const turn=(await ui(page)).camera.turn;
  await tapName(page,context,'CameraRight');await page.waitForFunction(turn=>window.FlotraViewport.uiMetrics.camera.turn===(turn+1)%4,turn);
  await tapName(page,context,'CameraReset');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.turn===0);
  test.cancelBurst.freshCameraRecovery=true;
}
async function installFrameGate(context) {
  await context.addInitScript(()=>{
    const request=window.requestAnimationFrame.bind(window),cancel=window.cancelAnimationFrame.bind(window);
    let next=1;const callbacks=new Map();
    const gate={hold:false,frames:0,release(){this.hold=false;window.requestAnimationFrame=request;window.cancelAnimationFrame=cancel;for(const [id,item] of callbacks)if(item.waiting){item.waiting=false;item.native=request(time=>run(id,time));}}};
    function run(id,time){const item=callbacks.get(id);if(!item)return;if(gate.hold){item.waiting=true;return;}callbacks.delete(id);gate.frames++;item.callback(time);}
    window.requestAnimationFrame=callback=>{const id=next++;const item={callback,waiting:false,native:0};callbacks.set(id,item);item.native=request(time=>run(id,time));return id;};
    window.cancelAnimationFrame=id=>{const item=callbacks.get(id);if(item){cancel(item.native);callbacks.delete(id);}};
    window.__preparationFrameGate=gate;window.__preparationTouchTrace=[];
    for(const type of ['touchstart','touchend','touchcancel'])window.addEventListener(type,event=>{
      window.__preparationTouchTrace.push({type,frames:gate.frames,trusted:event.isTrusted,time:performance.now()});
    },{capture:true,passive:true});
  });
}
async function compactPreparation(page,context) {
  const initial=await ui(page),scroll=initial.scroll;
  assert.equal(scroll.scrollVertical,0,'Preparation opens at top');
  for(const mode of ['balanced','parcel','pallet']) {
    const b=await button(page,'ChooseOperation_'+mode);
    assert.ok(b.x>=scroll.x&&b.x+b.width<=scroll.x+scroll.width+1&&b.y>=scroll.y&&b.y+b.height<=scroll.y+scroll.height+1,`All three choices above initial fold: ${mode}`);
    assert.ok(b.height>=56&&b.fontSize>=18,'Full-size readable mode targets');
  }
  const start=await button(page,'StartPreparedJob'),height=(await measure(page)).canvas.rect.height;
  assert.ok(start.y>=scroll.y+scroll.height&&start.y+start.height<=height,'Start is pinned outside scroll');
  assert.ok(!initial.buttons.some(b=>b.name==='PrepareLayout'&&b.visible),'Long detail panel starts folded');
  await tapName(page,context,'TogglePreparationDetails',true);await button(page,'PrepareLayout');
  await swipe(page,context,(await ui(page)).scroll,true,180);
  const after=await button(page,'StartPreparedJob');
  assert.deepEqual([after.x,after.y,after.width,after.height],[start.x,start.y,start.width,start.height],'Start does not move when details are expanded/scrolled');
  assert.deepEqual(immutableProgress(await ui(page)),immutableProgress(initial),'Details expansion is read-only');
  await tapName(page,context,'TogglePreparationDetails',true);
  await page.waitForFunction(()=>!window.FlotraViewport.uiMetrics.buttons.some(b=>b.name==='PrepareLayout'&&b.visible));
  const cdp=await session(page,context),canvas=(await measure(page)).canvas.rect;
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x:canvas.x+start.x+start.width/2,y:canvas.y+start.y+start.height/2}]});
  await page.waitForTimeout(tapHold);
  await cdp.send('Input.dispatchTouchEvent',{type:'touchCancel',touchPoints:[]});
  await page.waitForTimeout(300);
  assert.deepEqual(immutableProgress(await ui(page)),immutableProgress(initial),'Canceled pinned Start never accepts work');
  assert.equal((await ui(page)).sheet,'jobs');
  return {allModesAboveFold:true,pinnedStart:[start.x,start.y,start.width,start.height],readOnlyDetails:true,canceledStartSafe:true};
}
async function journey(page,context,test,mature) {
  const id=mature?'route_pick':'growth_1',reward=mature?300:140;
  const initial=await ui(page),initialWallet=initial.wallet;
  if(mature){assert.equal(initial.growth.wing_count,4);assert.equal(initial.growth.robot_count,4);assert.equal(initial.growth.catalog_complete,false);assert.equal(initial.hall.owned,false);}
  await cancellationBurst(page,context,test);
  await showJobs(page,context);
  if(mature){
    const copy=(await ui(page)).labels.map(l=>l.text).join('\n');
    assert.ok(copy.includes('広域配送棟'),'Former mature cap truthfully offers the earned next hall');
    await tapName(page,context,'Tab_upgrades');
    // Tabs share sheet='jobs'; wait for their actual rendered content rather
    // than a fixed post-touch delay or the previous tab's diagnostics.
    await tapName(page,context,'ToggleFutureUpgrades',true);
    const hall=await button(page,'BuyUpgrade_regional_hall');
    assert.equal(hall.disabled,true,'Earned original mature fixture still needs funds for the next hall');
    assert.ok(!(await ui(page)).labels.some(label=>label.name==='GrowthCatalogComplete'),'Former four-wing cap is not misreported as the final catalog');
    await screenshot(page,'mature-catalog-'+test.name);
    await tapName(page,context,'Tab_contracts');
  }
  await prepare(page,context,id);
  const original=immutableProgress(await ui(page));
  await page.waitForTimeout(500);assert.deepEqual(immutableProgress(await ui(page)),original,'Preparation itself does not start/advance work');
  test.compact=await compactPreparation(page,context);
  test.jobTitle=labelText(await ui(page),'PreparedJobTitle');
  await screenshot(page,'prepared-job-'+test.name);
  for(const mode of ['parcel','pallet','balanced','parcel'])await chooseMode(page,context,mode);
  assert.equal((await ui(page)).wallet,initialWallet,'All three existing transport modes are free');
  test.layoutCanceled=await alternateLayout(page,context,false);
  assert.deepEqual(immutableProgress(await ui(page)),original,'Canceling layout preserves job, cargo, wallet, and records');
  test.layoutApplied=await alternateLayout(page,context,true);
  assert.equal((await ui(page)).wallet,initialWallet,'Applying layout is free');
  const chosenLayout=(await ui(page)).layout.current;
  await tapName(page,context,'CloseSheet');await expectUI(page,{sheet:'jobs',trialRunning:false});
  assert.equal((await ui(page)).layout.current,chosenLayout,'Closing preparation keeps explicitly applied layout');
  assert.equal((await ui(page)).operation.mode_id,'parcel','Closing preparation keeps explicitly selected transport');
  await reloaded(page);assert.equal((await ui(page)).trialRunning,false);assert.equal((await ui(page)).wallet,initialWallet);
  assert.equal((await ui(page)).layout.current,chosenLayout);assert.equal((await ui(page)).operation.mode_id,'parcel');
  await stablePause(page);await showJobs(page,context);await prepare(page,context,id);
  await tapName(page,context,'StartPreparedJob');await expectUI(page,{sheet:'',trialRunning:true,currentContract:id});
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.simTime>1);
  await tapName(page,context,'PauseResume');const paused=await stablePause(page);
  await reloaded(page);const restored=await ui(page);
  assert.deepEqual(immutableProgress(restored),immutableProgress(paused),'Reload preserves paused in-flight work and does not duplicate rewards');
  await closeSheets(page,context);await stablePause(page);
  await screenshot(page,'paused-reloaded-'+test.name);
  await tapName(page,context,'PauseResume');await expectUI(page,{trialRunning:true});
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.status==='contract_complete',null,{timeout:150000});
  const first=await ui(page);assert.equal(first.wallet,initialWallet+reward);assert.equal(first.progress.shipped,mature?36:12);
  assert.deepEqual(first.jobComparison,{},'First current-session completion never fabricates prior setup');
  test.first={elapsed:first.simTime,wallet:first.wallet,results:first.results[id],layout:first.layout.current,operation:first.operation.mode_id};
  await tapName(page,context,'SessionRecord');await expectUI(page,{sheet:'records'});
  assert.ok(labelText(await ui(page),'SameJobComparison').includes('この起動中'),'Unavailable baseline is explained honestly');
  await tapName(page,context,'AdjustReplayJob',true);await expectUI(page,{sheet:'jobs',status:'contract_complete'});
  await button(page,'StartPreparedJob');
  assert.equal((await ui(page)).simTime,first.simTime,'Adjusting a completed job does not start a new run');
  assert.equal(labelText(await ui(page),'PreparedJobTitle'),test.jobTitle,'Adjust action retains the same selected job');
  await chooseMode(page,context,'balanced');
  await tapName(page,context,'StartPreparedJob');await expectUI(page,{sheet:'',trialRunning:true,currentContract:id});
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.status==='contract_complete',null,{timeout:150000});
  const second=await ui(page),comparison=second.jobComparison;
  assert.equal(second.wallet,initialWallet+2*reward,'Each completed replay pays exactly once');
  assert.equal(comparison.previous.contract_id,id);assert.equal(comparison.current.contract_id,id);
  closeEnough(comparison.previous.elapsed,first.simTime,'Baseline is this same job previous run',0.00001);
  closeEnough(comparison.current.elapsed,second.simTime,'Current comparison uses actual completion',0.00001);
  assert.equal(comparison.previous.operation_id,'parcel');assert.equal(comparison.current.operation_id,'balanced');
  closeEnough(comparison.current.units_per_minute,second.progress.shipped*60/second.simTime,'Throughput derives from same run',0.00001);
  assert.equal(second.currentBest,Math.min(first.currentBest,second.simTime),'Best remains the minimum completed time');
  assert.equal(second.results[id].attempts,first.results[id].attempts+1,'Replay increments only its own attempt count');
  test.comparison=comparison;test.finalRecord=second.results[id];
  await tapName(page,context,'SessionRecord');await expectUI(page,{sheet:'records'});
  assert.ok(labelText(await ui(page),'SameJobComparison').includes('前回 → 今回'),'Visible result has same-job comparison');
  await revealLabel(page,context,'SameJobComparison');await screenshot(page,'same-job-comparison-'+test.name);
  await reloaded(page);const final=await stablePause(page);
  assert.equal(final.wallet,second.wallet);assert.deepEqual(final.results,second.results);assert.equal(final.currentBest,second.currentBest);
  assert.deepEqual(final.jobComparison,{},'Reload never fabricates session-only comparison');
  await closeSheets(page,context);await tapName(page,context,'SessionRecord');await expectUI(page,{sheet:'records'});
  assert.ok(labelText(await ui(page),'SameJobComparison').includes('この起動中') && labelText(await ui(page),'SameJobComparison').includes('2回'),'Reload fallback accurately requires two same-job completions in this session');
  test.reload={inFlightPreserved:true,preparationNeverStarted:true,rewardsNotDuplicated:true,bestPersisted:final.currentBest,sessionComparisonCleared:true};
}
(async()=>{
 let browser;
 try {
  browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE||undefined,headless:true});
  const completeText=fs.readFileSync(path.join(fixturesDirectory,'complete.json'),'utf8'),fixture=JSON.parse(completeText);
  report.hashes.completeFixture=hash(completeText);
  for(const [width,height] of [[375,567],[390,844]])for(const profile of ['quickstart','fresh','mature']) {
    const name=`${profile}-${width}x${height}`;
    if(process.env.FLOTRA_PREPARATION_CASES&&!process.env.FLOTRA_PREPARATION_CASES.split(',').includes(name))continue;
    const test={name,width,height,dpr:3,status:'running'};report.results.push(test);saveReport();console.log('SCENARIO '+name);
    const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:3,isMobile:true,hasTouch:true});
    await installFrameGate(context);
    if(profile==='mature')await context.addInitScript(encoded=>{if(localStorage.getItem('flotra.campaign.release.v1')===null)localStorage.setItem('flotra.campaign.release.v1',encoded);},fixture.encoded);
    const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    try {
      await boot(page);
      test.environment=await page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return {dpr:devicePixelRatio,userAgent:navigator.userAgent,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null};});
      if(profile==='quickstart'){
        await tapName(page,context,'CloseSheet');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'AcceptContract_growth_1',true);await expectUI(page,{sheet:'',trialRunning:true,currentContract:'growth_1'});test.directStartPreserved=true;
      } else await journey(page,context,test,profile==='mature');
      assert.deepEqual(errors,[],'No browser JavaScript or console errors');test.status='passed';console.log('PASS '+name);
    } catch(error){test.status='failed';test.error=error.stack;test.last=await ui(page).catch(()=>null);await screenshot(page,'failure-'+name).catch(()=>{});throw error;}
    finally{test.errors=errors;saveReport();await context.close();}
  }
  assert.ok(report.results.length,'At least one selected case ran');
  if(exportedDirectory)for(const [name,digest] of Object.entries(report.hashes))if(fs.existsSync(path.join(exportedDirectory,name)))assert.equal(hash(fs.readFileSync(path.join(exportedDirectory,name))),digest,'Export did not change while tested: '+name);
  report.status='passed';console.log('BROWSER_PREPARATION_JOURNEY '+report.results.length+' cases passed');
 } catch(error){report.status='failed';report.error=error.stack;console.error(error);process.exitCode=1;}
 finally{report.finishedAt=new Date().toISOString();saveReport();await browser?.close();}
})();
