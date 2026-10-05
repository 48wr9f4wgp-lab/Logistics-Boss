const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const tapHold=90;
const output=process.argv[3]||path.join(__dirname,'evidence');
fs.mkdirSync(output,{recursive:true});
const target=new URL(process.argv[2]||'http://127.0.0.1:8837/');target.searchParams.set('phone_qa','1');const url=target.href;
const fixturesDirectory=process.argv[4]||path.join(__dirname,'fixtures');
const key='flotra.campaign.release.v1',archiveKey=key+'.pre-v4';
const fixture=JSON.parse(fs.readFileSync(path.join(fixturesDirectory,'mature-v3.json'),'utf8'));
const report={kind:'Real integrated schema4 app, fresh Chromium contexts, synthetic schema3 progress only; no public release or real user data',tests:[]};
const hash=text=>crypto.createHash('sha256').update(text).digest('hex');
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



(async()=>{let browser;try{
 browser=await chromium.launch({executablePath:process.env.FLOTRA_CHROMIUM||process.env.CHROMIUM_EXECUTABLE||undefined,headless:true});
 for(const [width,height] of [[375,567],[390,844]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:3,isMobile:true,hasTouch:true});
  await context.addInitScript(({key,text})=>{if(localStorage.getItem(key)===null)localStorage.setItem(key,text)},{key,text:fixture.encoded});
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'){errors.push(m.text());console.log('ERROR',m.text())}});
  await page.goto(url,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.FlotraViewport?.uiMetrics?.sheet==='entry',null,{timeout:120000});await settle(page);
  let state=await ui(page);assert.equal(state.schema,4);assert.equal(state.wallet,fixture.wallet);assert.equal(state.hall.owned,false);assert.equal(state.saving.blocked,false);
  let stored=await page.evaluate(({key,archiveKey})=>({primary:localStorage.getItem(key),archive:localStorage.getItem(archiveKey)}),{key,archiveKey});assert.equal(stored.primary,fixture.encoded);assert.equal(stored.archive,null,'loading alone never writes archive');
  await tapName(page,context,'StartTrial');await expectUI(page,{sheet:'',trialRunning:false});
  await page.screenshot({path:path.join(output,`${width}-integrated-before-hall.png`)});
  await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'Tab_upgrades');
  await tapName(page,context,'BuyUpgrade_regional_hall',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.hall.owned===true&&window.FlotraViewport.uiMetrics.sheet==='');await settle(page);
  state=await ui(page);assert.equal(state.wallet,fixture.wallet-1800);assert.equal(state.hall.plan,'storage');assert.ok(state.growth.area>878&&state.growth.area<880);
  stored=await page.evaluate(({key,archiveKey})=>({primary:localStorage.getItem(key),backup:localStorage.getItem(key+'.backup'),archive:localStorage.getItem(archiveKey)}),{key,archiveKey});
  assert.equal(stored.archive,fixture.encoded,'first migration preserves exact original bytes and whitespace');assert.equal(JSON.parse(stored.primary).pre_v4_sha256,fixture.sha256);assert.equal(stored.backup,fixture.encoded);
  await page.screenshot({path:path.join(output,`${width}-integrated-storage-hall.png`)});
  await tapName(page,context,'CameraIn');await tapName(page,context,'CameraRight');await tapName(page,context,'CameraReset');
  await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'Tab_upgrades');
  await tapName(page,context,'HallPlan_express',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.hall.plan==='express');assert.equal((await ui(page)).wallet,state.wallet);
  await tapName(page,context,'CloseSheet');await expectUI(page,{sheet:''});await page.screenshot({path:path.join(output,`${width}-integrated-express-hall.png`)});
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.FlotraViewport?.uiMetrics?.sheet==='entry',null,{timeout:120000});await settle(page);
  state=await ui(page);assert.equal(state.hall.plan,'express');assert.equal(state.hall.owned,true);assert.equal(state.wallet,fixture.wallet-1800);assert.equal(state.saving.blocked,false);
  assert.equal(await page.evaluate(k=>localStorage.getItem(k),archiveKey),fixture.encoded);
  await tapName(page,context,'StartTrial');await expectUI(page,{sheet:'',trialRunning:false});await tapName(page,context,'WorkChoice');await expectUI(page,{sheet:'jobs'});await tapName(page,context,'Tab_contracts');
  await tapName(page,context,'PrepareContract_route_regional',true);await tapName(page,context,'ChooseOperation_parcel',true);
  const plan=await ui(page);for(const mode of ['balanced','parcel','pallet']){const b=plan.buttons.find(b=>b.name==='ChooseOperation_'+mode&&b.visible);assert.ok(b.y>=plan.scroll.y-1&&b.y+b.height<=plan.scroll.y+plan.scroll.height+1,'three modes remain above fold')}
  await tapName(page,context,'StartPreparedJob');await expectUI(page,{sheet:'',trialRunning:true,currentContract:'route_regional'});
  const started=await ui(page),startedPrimary=await page.evaluate(k=>localStorage.getItem(k),key);
  await page.waitForFunction(({key,before,time})=>{
   const state=window.FlotraViewport.uiMetrics;
   return state.trialRunning===true&&state.simTime>Math.max(18,time)&&localStorage.getItem(key)!==before;
  },{key,before:startedPrimary,time:started.simTime},{timeout:90000});
  const autosaved=await page.evaluate(({key,archiveKey})=>({primary:localStorage.getItem(key),archive:localStorage.getItem(archiveKey),running:window.FlotraViewport.uiMetrics.trialRunning,time:window.FlotraViewport.uiMetrics.simTime}),{key,archiveKey});
  assert.equal(autosaved.running,true,'Timed checkpoint was observed before any pause/menu action');
  assert.notEqual(autosaved.primary,startedPrimary);assert.equal(autosaved.archive,fixture.encoded);assert.equal(JSON.parse(autosaved.primary).pre_v4_sha256,fixture.sha256);

  await tapName(page,context,'PauseResume');await expectUI(page,{trialRunning:false});await settle(page);
  const paused=await ui(page);assert.ok(paused.progress.offered>0);assert.equal(paused.saving.blocked,false);
  stored=await page.evaluate(({key,archiveKey})=>({primary:localStorage.getItem(key),backup:localStorage.getItem(key+'.backup'),archive:localStorage.getItem(archiveKey)}),{key,archiveKey});assert.equal(stored.archive,fixture.encoded);assert.equal(JSON.parse(stored.primary).pre_v4_sha256,fixture.sha256);assert.equal(JSON.parse(stored.backup).pre_v4_sha256,fixture.sha256);
  await page.screenshot({path:path.join(output,`${width}-integrated-regional-active.png`)});
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.FlotraViewport?.uiMetrics?.sheet==='entry',null,{timeout:120000});await settle(page);
  const resumed=await ui(page);assert.equal(resumed.simTime,paused.simTime,'pause commits exact in-flight time');assert.deepEqual(resumed.progress,paused.progress);assert.equal(resumed.operation.mode_id,'parcel');assert.equal(resumed.hall.plan,'express');assert.equal(resumed.trialRunning,false);assert.equal(resumed.saving.blocked,false);
  assert.equal(await page.evaluate(k=>localStorage.getItem(k),archiveKey),fixture.encoded);
  const keys=await page.evaluate(()=>Object.keys(localStorage));assert.deepEqual(keys.sort(),[key,key+'.backup',archiveKey].sort());
  assert.deepEqual(errors,[]);report.tests.push({width,height,steps:['schema3-read-no-write','earned-hall-purchase','exact-immutable-archive','free-plan-save-reload','camera','compact-preparation','actual480-job','autosave','exact-pause-reload'],paused:{time:paused.simTime,progress:paused.progress,performance:paused.performance},autosave:{observedWhileRunning:autosaved.running,time:autosaved.time,primaryHash:hash(autosaved.primary)},archiveHash:fixture.sha256,errors});
  fs.writeFileSync(path.join(output,'integrated-journey.json'),JSON.stringify(report,null,2));
  if(width===375){
   const before=await page.evaluate(k=>localStorage.getItem(k),key);await page.evaluate(k=>localStorage.setItem(k,'unrecognized-protected-archive'),archiveKey);await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.FlotraViewport?.uiMetrics?.sheet==='entry',null,{timeout:120000});await settle(page);
   const blocked=await ui(page);assert.equal(blocked.saving.blocked,true);assert.equal(blocked.hall.owned,true);assert.equal(blocked.simTime,paused.simTime);assert.equal(await page.evaluate(k=>localStorage.getItem(k),key),before);assert.equal(await page.evaluate(k=>localStorage.getItem(k),archiveKey),'unrecognized-protected-archive');
   await page.screenshot({path:path.join(output,'375-integrated-archive-block.png')});report.archiveConflict={readableProgress:true,blocked:true,status:blocked.saving.status,unchangedPrimary:true};fs.writeFileSync(path.join(output,'integrated-journey.json'),JSON.stringify(report,null,2));
  }
  await context.close();
 }
 console.log(JSON.stringify(report));
}finally{await browser?.close()}})().catch(e=>{report.failure=String(e);fs.writeFileSync(path.join(output,'integrated-journey.json'),JSON.stringify(report,null,2));console.error(e);process.exitCode=1});
