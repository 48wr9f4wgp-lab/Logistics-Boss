#!/usr/bin/env node
'use strict';
// Focused actual WebGL regression. Helpers below follow browser_preparation_journey.cjs.
// Real trusted browser touch input; phone_qa is read-only. Domain-earned fixtures
// are seeded once in brand-new isolated contexts, never an existing player save.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const [requestedURL, output, fixturesDirectory, exportedDirectory] = process.argv.slice(2);
assert.ok(requestedURL && output && fixturesDirectory && exportedDirectory,
  'Usage: browser_upgrade_visibility.cjs URL OUTPUT FIXTURES EXPORTED_DIRECTORY');
const target=new URL(requestedURL); target.searchParams.set('phone_qa','1');
const exportContract=require('./browser_export_contract.cjs');
const fixedContract=exportContract.fromDirectory(exportedDirectory);
const url=target.href, tapHold=90, saveKey=fixedContract.saveKey;
const futureUpgrades=['crew_6','wing_3','robot_4','wing_4',...(fixedContract.version===5?['pick_dispatch_board']:[])];
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
const exportedFiles=fixedContract.assets;
fs.mkdirSync(output,{recursive:true});
const report={kind:'Actual cloud Chromium WebGL; CSS phone emulation at DPR 3, not physical iPhone/Safari',
  startedAt:new Date().toISOString(),url,status:'running',results:[],hashes:{harness:hash(fs.readFileSync(__filename))}};
for(const name of exportedFiles) report.hashes[name]=hash(fs.readFileSync(path.join(exportedDirectory,name)));
const closeEnough = (actual, expected, label, tolerance = 1) => assert.ok(Math.abs(actual - expected) <= tolerance, `${label}: ${actual} != ${expected}`);
const cdpSessions = new WeakMap();
let currentTest;

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
  const initialScroll=(await ui(page)).scroll.scrollVertical, startedAt=Date.now();
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
  currentTest?.scrollGestures.push({from:initialScroll,to:previous,upward,distance,durationMs:Date.now()-startedAt});
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

async function revealButton(page, context, name, scrollable = false) {
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
      assert.ok(control.height >= 56 && control.fontSize >= 18, `Readable CSS target: ${name}`);
      verify(m, `before touching ${name}`);
      console.log(`POINT ${name}: ${m.canvas.rect.x + x},${m.canvas.rect.y + y}; CSS ${m.engine.logicalWidth}x${m.engine.logicalHeight}; DPR ${m.viewport.dpr}`);
      return {control, x:m.canvas.rect.x + x, y:m.canvas.rect.y + y};
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

const saveReport=()=>fs.writeFileSync(path.join(output,'upgrade-visibility.json'),JSON.stringify(report,null,2));
const saved=page=>page.evaluate(key=>localStorage.getItem(key),saveKey);
const backupSaved=page=>page.evaluate(key=>localStorage.getItem(key+'.backup'),saveKey);
const expectedEncoded=fixture=>fixedContract.version===5?fixture.dispatchEncoded:fixture.encoded;
const progress=state=>Object.fromEntries(['wallet','upgrades','currentContract','status','simTime','progress','results','growth','preferences','operation','layout','speed','trialRunning','currentBest','jobComparison'].map(key=>[key,state[key]]));
const visibleUpgrades=state=>state.buttons.filter(b=>b.visible&&b.name.startsWith('BuyUpgrade_')).sort((a,b)=>a.y-b.y);
async function screenshot(page,name) {await page.screenshot({path:path.join(output,name+'.png'),scale:'css'});}
async function tapName(page,context,name,scrollable=false) {
  const point=await revealButton(page,context,name,scrollable);
  assert.equal(point.control.disabled,false,`Touchable button enabled: ${name}`);
  await touchAt(page,context,point.x,point.y);await page.waitForTimeout(240);
}
async function boot(page) {
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
  await settle(page);await expectUI(page,{sheet:'entry',status:'contract_complete',trialRunning:false});
  verify(await measure(page),'actual upgrade export');
}
async function closeSheets(page,context) {
  for(let attempt=0;attempt<4&&(await ui(page)).sheet;attempt++) {
    const state=await ui(page),signature=state.sheet+'|'+state.buttons.filter(b=>b.visible).map(b=>b.name).join(',');
    await tapName(page,context,'CloseSheet');
    await page.waitForFunction(previous=>{const s=window.FlotraViewport.uiMetrics;return s.sheet+'|'+s.buttons.filter(b=>b.visible).map(b=>b.name).join(',')!==previous;},signature);
  }
  await expectUI(page,{sheet:''});
}
async function openUpgrades(page,context) {
  await closeSheets(page,context);await tapName(page,context,'EquipmentChoice');await expectUI(page,{sheet:'jobs'});
  await button(page,'BuyUpgrade_rack_48');
  await page.waitForTimeout(250);
}
async function invariant(page,baseline,test,label,allowBackupRotation=false) {
  await page.waitForTimeout(260);
  assert.equal(await saved(page),baseline.encoded,`${label}: complete encoded localStorage state is byte-identical`);
  const backup=await backupSaved(page);
  if(allowBackupRotation)assert.ok(backup===baseline.backup||backup===baseline.encoded,`${label}: lifecycle save can only rotate the identical state into backup`);
  else assert.equal(backup,baseline.backup,`${label}: saved backup is unchanged`);
  assert.deepEqual(progress(await ui(page)),baseline.ui,`${label}: all read-only gameplay diagnostics are unchanged`);
  await exportContract.assertStorage(page,fixedContract,baseline.fixture);
  test.invariants.push(label);
}
async function installTrace(context) {
  await context.addInitScript(()=>{
    window.__upgradeTrace={frames:0,qaUpdates:0,events:[]};let previousMetrics;
    function observe(){window.__upgradeTrace.frames++;const metrics=window.FlotraViewport?.uiMetrics;if(metrics&&metrics!==previousMetrics){window.__upgradeTrace.qaUpdates++;previousMetrics=metrics;}requestAnimationFrame(observe);}requestAnimationFrame(observe);
    for(const type of ['touchstart','touchmove','touchend','touchcancel'])window.addEventListener(type,event=>{
      window.__upgradeTrace.events.push({type,trusted:event.isTrusted,frames:window.__upgradeTrace.frames,qaUpdates:window.__upgradeTrace.qaUpdates,ms:performance.now()});
    },{capture:true,passive:true});
  });
}
async function heldTouch(page,context,name,cancel=false) {
  const point=await revealButton(page,context,name,true),cdp=await session(page,context);
  const before=await page.evaluate(()=>({frames:window.__upgradeTrace.frames,events:window.__upgradeTrace.events.length}));
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x:point.x,y:point.y}]});
  // Longer than the 200ms diagnostics/refresh boundary; ordinary live frames,
  // with no frame gate, game state assignments, or game method calls.
  await page.waitForTimeout(650);
  await cdp.send('Input.dispatchTouchEvent',{type:cancel?'touchCancel':'touchEnd',touchPoints:[]});
  await page.waitForTimeout(350);
  const observed=await page.evaluate(before=>({frames:window.__upgradeTrace.frames-before.frames,events:window.__upgradeTrace.events.slice(before.events)}),before);
  assert.ok(observed.frames>=2,'Held touch crosses live rendered frames');
  assert.deepEqual(observed.events.map(e=>e.type),['touchstart',cancel?'touchcancel':'touchend']);
  assert.ok(observed.events.every(e=>e.trusted),'Input is browser-trusted');
  assert.ok(observed.events[1].frames>observed.events[0].frames,'Frames render while finger remains down');
  assert.ok(observed.events[1].qaUpdates>observed.events[0].qaUpdates,'Actual engine read-only diagnostics refresh while finger remains down');
  assert.ok(observed.events[1].ms-observed.events[0].ms>=600,'Input stays held across refresh interval');
  return {name,canceled:cancel,disabled:point.control.disabled,...observed};
}
function assertCatalog(state,wallet) {
  const cards=visibleUpgrades(state),ids=cards.map(b=>b.name.replace('BuyUpgrade_',''));
  assert.deepEqual(ids,['rack_48','auto_pack','robot_2','wing_2'],
    'Affordable cards lead, then all progression-unlocked unaffordable choices appear without future disclosure');
  const costs={rack_48:180,auto_pack:240,robot_2:260,wing_2:350};
  for(const b of cards) {
    const id=b.name.replace('BuyUpgrade_','');
    assert.ok(b.text.includes('資金'+costs[id]),`Unchanged exact cost visible for ${id}`);
    assert.equal(b.disabled,costs[id]>wallet,`${id} is enabled only when affordable`);
    assert.ok(b.height>=56&&b.fontSize>=18,`${id} keeps 56px/18px geometry`);
  }
  for(const id of [...futureUpgrades,'wing_1','crew_4'])assert.ok(!state.buttons.some(b=>b.name==='BuyUpgrade_'+id&&b.visible),`${id} stays in its folded group`);
  assert.ok(state.buttons.find(b=>b.name==='ToggleFutureUpgrades'&&b.visible).text.includes(futureUpgrades.length+'件'),'Exact build-specific truly locked upgrade count');
  if(wallet===200)for(const shortfall of [40,60,150])assert.ok(state.labels.some(l=>l.text==='資金があと'+shortfall+'必要です'&&l.fontSize>=18),`Exact readable shortfall ${shortfall}`);
  const heading=state.labels.find(l=>l.name==='UnlockedUpgradesHeading');
  assert.equal(heading?.text,'資金をためて導入');
  assert.ok(heading.y>cards.filter(b=>!b.disabled).at(-1).y,'Saving section follows every affordable card');
  return {ids,cards:cards.map(b=>({name:b.name,text:b.text,disabled:b.disabled,height:b.height,fontSize:b.fontSize})),futureCount:futureUpgrades.length};
}
async function exposeReason(page,context,amount) {
  const text='資金があと'+amount+'必要です';
  for(let attempt=0;attempt<18;attempt++) {
    const state=await ui(page),label=state.labels.find(l=>l.text===text),scroll=state.scroll;
    assert.ok(label,'Exact shortfall label exists');
    if(label.y>=scroll.y+4&&label.y+label.height<=scroll.y+scroll.height-4)return;
    await swipe(page,context,scroll,label.y>scroll.y,Math.abs(label.y-scroll.y)+100);
  }
  throw new Error('Could not scroll to shortfall '+amount);
}
async function verifyOperations(page,context,test,packingSeconds) {
  await tapName(page,context,'ToggleOperations',true);await button(page,'ChooseOperation_parcel');
  const state=await ui(page);
  const buttons=['balanced','parcel','pallet'].map(id=>state.buttons.find(b=>b.name==='ChooseOperation_'+id&&b.visible));
  assert.ok(buttons.every(Boolean),'All three existing operation controls preserved');
  for(const b of buttons)assert.ok(b.height>=56&&b.fontSize>=18,'Operation targets remain readable');
  assert.equal(buttons[0].disabled,true,'Current balanced mode remains selected');
  assert.ok(buttons.slice(1).every(b=>!b.disabled),'Other operation choices remain available');
  for(const id of ['balanced','parcel','pallet']){
    const preview=state.labels.find(l=>l.name==='OperationPreview_'+id);
    assert.ok(preview?.text.includes('梱包'+packingSeconds+'秒/個'),'Existing operation preview reflects actual packing duration');
    assert.ok(preview.text.includes('棚の容量12個'),'Unbought shelf does not alter capacity');
  }
  await revealButton(page,context,'ChooseOperation_parcel',true);
  await screenshot(page,'operations-'+test.name);
  test.operations={modes:buttons.map(b=>b.name),packingSeconds,rackCapacity:12};
  await tapName(page,context,'ToggleOperations',true);
  await page.waitForFunction(()=>!window.FlotraViewport.uiMetrics.buttons.some(b=>b.name==='ChooseOperation_parcel'&&b.visible));
}
async function walletScenario(page,context,test,fixture) {
  const baseline={encoded:await saved(page),backup:await backupSaved(page),ui:progress(await ui(page)),fixture};
  assert.equal(baseline.encoded,expectedEncoded(fixture),'Imported domain-earned completed save stays exact for its explicit schema');
  assert.equal(baseline.ui.wallet,200);assert.deepEqual(baseline.ui.upgrades,['wing_1','crew_4']);
  assert.equal(baseline.ui.growth.completed_milestones,2);
  test.invariants=[];test.inputs=[];
  fs.writeFileSync(path.join(output,'baseline-'+test.name+'.json'),JSON.stringify({encoded:baseline.encoded,fixture,ui:baseline.ui},null,2));
  await openUpgrades(page,context);test.catalog=assertCatalog(await ui(page),200);
  await screenshot(page,'opening-'+test.name);await invariant(page,baseline,test,'Open upgrades');
  for(const [id,shortfall] of [['auto_pack',40],['robot_2',60],['wing_2',150]]) {
    test.inputs.push(await heldTouch(page,context,'BuyUpgrade_'+id));
    await invariant(page,baseline,test,'Disabled held touch '+id);
    await exposeReason(page,context,shortfall);await screenshot(page,id+'-'+test.name);
    await invariant(page,baseline,test,'Scroll to '+id+' cost and shortfall');
  }
  await verifyOperations(page,context,test,'1.5');await invariant(page,baseline,test,'Expand, scroll, and collapse operations');
  await tapName(page,context,'ToggleFutureUpgrades',true);await button(page,'BuyUpgrade_crew_6');
  const expanded=visibleUpgrades(await ui(page));
  assert.deepEqual(expanded.map(b=>b.name.replace('BuyUpgrade_','')).slice(-futureUpgrades.length),futureUpgrades,'Future disclosure contains only truly locked upgrades');
  assert.ok(expanded.slice(-futureUpgrades.length).every(b=>b.disabled),'Future choices stay disabled');
  await screenshot(page,'future-'+test.name);await invariant(page,baseline,test,'Expand locked roadmap');
  await tapName(page,context,'ToggleFutureUpgrades',true);
  await page.waitForFunction(()=>!window.FlotraViewport.uiMetrics.buttons.some(b=>b.name==='BuyUpgrade_crew_6'&&b.visible));
  await invariant(page,baseline,test,'Collapse locked roadmap');
  test.inputs.push(await heldTouch(page,context,'BuyUpgrade_rack_48',true));
  assert.equal(test.inputs.at(-1).disabled,false,'Cancellation exercises an actually affordable purchase');
  await invariant(page,baseline,test,'Cancel affordable shelf held touch');
  await closeSheets(page,context);await invariant(page,baseline,test,'Close upgrades');
  await openUpgrades(page,context);assertCatalog(await ui(page),200);await invariant(page,baseline,test,'Fresh touch reopens upgrades after cancellation');
  test.beforeReloadTouchTrace=await page.evaluate(()=>window.__upgradeTrace);
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
  await settle(page);await expectUI(page,{sheet:'entry',trialRunning:false,status:'contract_complete'});
  await invariant(page,baseline,test,'Reload frozen completed state',true);
  test.completeEncodedStateUnchanged=true;
  fs.writeFileSync(path.join(output,'readonly-'+test.name+'.json'),JSON.stringify({encoded:await saved(page),ui:progress(await ui(page))},null,2));
}
async function fundedScenario(page,context,test,fixture) {
  assert.equal((await ui(page)).wallet,340);assert.equal(await saved(page),expectedEncoded(fixture));
  await openUpgrades(page,context);test.catalog=assertCatalog(await ui(page),340);
  const before=await ui(page),encodedBefore=await saved(page);
  await revealButton(page,context,'BuyUpgrade_auto_pack',true);await screenshot(page,'funded-before-'+test.name);
  test.input=await heldTouch(page,context,'BuyUpgrade_auto_pack');
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.wallet===100&&window.FlotraViewport.uiMetrics.upgrades.includes('auto_pack'),null,{timeout:10000});
  await page.waitForFunction(({key,before})=>localStorage.getItem(key)!==before,{key:saveKey,before:encodedBefore},{timeout:10000});
  const after=await ui(page),encodedAfter=await saved(page);
  if(fixedContract.version===5)assert.equal(encodedAfter,fixture.dispatchPurchasedEncoded,'Web purchase matches full native schema5 state, including all physical cargo');
  assert.deepEqual(after.upgrades,[...before.upgrades,'auto_pack'],'One actual held purchase adds exactly one upgrade');
  for(const key of ['simTime','results','progress','currentContract','status','preferences','layout'])assert.deepEqual(after[key],before[key],`Purchase preserves ${key}`);
  assert.equal(after.wallet,before.wallet-240,'One actual held purchase charges exactly 240');
  await page.waitForTimeout(800);assert.equal((await ui(page)).wallet,100);assert.equal(await saved(page),encodedAfter,'Holding/releasing never duplicates purchase');
  await verifyOperations(page,context,test,'0.7');
  assert.equal(await saved(page),encodedAfter,'Inspecting actual equipment effects preserves purchased save');
  fs.writeFileSync(path.join(output,'purchased-'+test.name+'.json'),JSON.stringify({encoded:encodedAfter,beforeEncoded:encodedBefore,ui:progress(await ui(page)),fixture},null,2));
  await tapName(page,context,'ToggleOwnedUpgrades',true);const owned=await button(page,'BuyUpgrade_auto_pack');
  assert.equal(owned.disabled,true);assert.equal(owned.text,'導入済み');
  await revealButton(page,context,'BuyUpgrade_auto_pack',true);await screenshot(page,'purchased-'+test.name);
  const repeated=await heldTouch(page,context,'BuyUpgrade_auto_pack');assert.equal(repeated.disabled,true);
  assert.equal((await ui(page)).wallet,100);assert.equal(await saved(page),encodedAfter,'Owned disabled touch cannot repurchase');
  test.beforeReloadTouchTrace=await page.evaluate(()=>window.__upgradeTrace);
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics,null,{timeout:120000});
  await settle(page);await expectUI(page,{sheet:'entry',trialRunning:false,status:'contract_complete',wallet:100});
  assert.deepEqual((await ui(page)).upgrades,[...before.upgrades,'auto_pack']);assert.equal(await saved(page),encodedAfter,'Reload preserves exact purchased state');
  await openUpgrades(page,context);await tapName(page,context,'ToggleOperations',true);
  for(const mode of ['parcel','balanced']) {
    await tapName(page,context,'ChooseOperation_'+mode,true);
    await page.waitForFunction(mode=>window.FlotraViewport.uiMetrics.operation.mode_id===mode,mode);
    assert.equal((await ui(page)).wallet,100,'Existing mode choices remain free after purchase');
    assert.equal((await ui(page)).simTime,after.simTime,'Mode choice does not start or advance the completed job');
    assert.deepEqual((await ui(page)).upgrades,after.upgrades,'Mode choice preserves equipment');
  }
  test.actualFreeModeSelection=['parcel','balanced'];
  test.purchase={cost:240,walletBefore:before.wallet,walletAfter:100,upgrade:'auto_pack',exactlyOnce:true,ownedRetouchNoOp:true,reloadPreserved:true,encodedHash:hash(encodedAfter)};
}
(async()=>{
 let browser;
 try {
  browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE||undefined,headless:true});
  const selectedViewports=process.env.FLOTRA_UPGRADE_VIEWPORTS?.split(',');
  for(const [width,height] of [[375,567],[390,844]].filter(([w,h])=>!selectedViewports||selectedViewports.includes(w+'x'+h)))for(const profile of ['wallet200','funded340']) {
    const name=profile+'-'+width+'x'+height;
    if(process.env.FLOTRA_UPGRADE_CASES&&!process.env.FLOTRA_UPGRADE_CASES.split(',').includes(name))continue;
    const fixtureText=fs.readFileSync(path.join(fixturesDirectory,profile+'.json'),'utf8'),fixture=JSON.parse(fixtureText);
    assert.ok(typeof fixture.encoded==='string'&&fixture.status==='contract_complete','Fixtures include native domain-earned encoded completed state');
    report.hashes[profile]=hash(fixtureText);
    const test={name,width,height,dpr:3,status:'running',scrollGestures:[]};currentTest=test;report.results.push(test);saveReport();console.log('SCENARIO '+name);
    const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:3,isMobile:true,hasTouch:true});
    await context.addInitScript(({key,encoded})=>{if(localStorage.getItem(key)===null)localStorage.setItem(key,encoded);},{key:exportContract.legacyKey,encoded:fixture.encoded});
    await installTrace(context);
    const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
    try {
      await boot(page);
      test.storageContract=await exportContract.fromPage(page,fixedContract);
      if(fixedContract.version===5){
        assert.ok(typeof fixture.dispatchEncoded==='string'&&JSON.parse(fixture.dispatchEncoded).version===5,'Fixture has exact native schema5 migration expectation');
        await exportContract.assertStorage(page,fixedContract,fixture);
        // The HUD ignores a same-speed press. Change and restore the preference
        // with trusted input while completed/paused, then require the entire
        // final state to equal the exact native migration before testing reads.
        await closeSheets(page,context);await tapName(page,context,'Back');await expectUI(page,{sheet:'controls'});
        assert.equal((await ui(page)).speed,2);await tapName(page,context,'Speed1x',true);await expectUI(page,{speed:1,trialRunning:false});
        await tapName(page,context,'Speed2x',true);await expectUI(page,{speed:2,trialRunning:false});
        await page.waitForFunction(({key,encoded})=>localStorage.getItem(key)===encoded,{key:saveKey,encoded:fixture.dispatchEncoded},{timeout:10000});
        await closeSheets(page,context);
        await exportContract.assertStorage(page,fixedContract,fixture);
        test.legacyMigratedExactly=true;
      }
      test.environment=await page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return {dpr:devicePixelRatio,userAgent:navigator.userAgent,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null};});
      if(profile==='wallet200')await walletScenario(page,context,test,fixture);else await fundedScenario(page,context,test,fixture);
      test.touchTrace=await page.evaluate(()=>window.__upgradeTrace);
      await exportContract.assertStorage(page,fixedContract,fixture);
      assert.deepEqual(errors,[],'No browser JavaScript or console errors');test.status='passed';console.log('PASS '+name);
    } catch(error){test.status='failed';test.error=error.stack;test.last=await ui(page).catch(()=>null);await screenshot(page,'failure-'+name).catch(()=>{});throw error;}
    finally{test.errors=errors;saveReport();await context.close();}
  }
  assert.ok(report.results.length,'At least one selected case ran');
  for(const name of exportedFiles)assert.equal(hash(fs.readFileSync(path.join(exportedDirectory,name))),report.hashes[name],'Frozen export did not change: '+name);
  report.status='passed';console.log('BROWSER_UPGRADE_VISIBILITY '+report.results.length+' cases passed');
 } catch(error){report.status='failed';report.error=error.stack;console.error(error);process.exitCode=1;}
 finally{report.finishedAt=new Date().toISOString();saveReport();await browser?.close();}
})();
