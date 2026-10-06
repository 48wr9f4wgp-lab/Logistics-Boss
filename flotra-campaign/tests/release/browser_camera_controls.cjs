#!/usr/bin/env node
'use strict';
// Camera input is driven through actual Chromium touch/mouse events into WebGL.
// Domain-earned fixtures seed isolated test contexts only. No app commands exist.
// CHROMIUM_EXECUTABLE=/usr/bin/chromium node browser_camera_controls.cjs URL OUTPUT FIXTURES
// Headed Chromium emulation is not physical iPhone/Safari evidence.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const requestedURL = process.argv[2];
const output = process.argv[3] || '/tmp/flotra-camera-browser';
if (!requestedURL) throw new Error('Supply the local or published FLOTRA export URL');
const testURL = new URL(requestedURL);
testURL.searchParams.set('phone_qa', '1');
const url = testURL.href;
fs.mkdirSync(output, { recursive: true });
const allCases = [[375, 567], [375, 667], [390, 844], [430, 932]];
const selectedCases = process.env.FLOTRA_TEST_CASES?.split(',');
const cases = selectedCases ? [...allCases, [568, 320]].filter(([width, height]) => selectedCases.includes(`${width}x${height}`)) : allCases;
assert.ok(cases.length > 0, 'At least one known phone case is selected');
const dprs = process.env.FLOTRA_TEST_DPRS ? process.env.FLOTRA_TEST_DPRS.split(',').map(Number) : [1, 2, 3];
const tapHold = Number(process.env.FLOTRA_TAP_HOLD_MS ?? 90);
assert.ok(Number.isFinite(tapHold) && tapHold >= 0 && tapHold <= 500, 'Supported touch hold duration');
const freshOnly = process.env.FLOTRA_FRESH_ONLY === '1';
const report = { kind: 'Headed Chromium camera touch/WebGL, CSS viewport/DPR emulation; not physical iPhone/Safari', url, configuration: { tapHoldMilliseconds: tapHold, freshContextOnly: freshOnly, phase: process.env.FLOTRA_CAMERA_PHASE || 'full' }, results: [] };
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
    const inScroll = !scrollable || (control.y >= scroll.y + 8 && control.y + control.height <= scroll.y + scroll.height - 8);
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


const fixturesDirectory = process.argv[4];
assert.ok(fixturesDirectory, 'Supply domain-earned validated fixtures');
const matureFixture = JSON.parse(fs.readFileSync(path.join(fixturesDirectory, 'late.json'), 'utf8'));
const camera = async page => (await ui(page)).camera;
async function freshCamera(page) { await page.waitForTimeout(350); return camera(page); }
async function closeSheets(page, context) {
  for (let i = 0; i < 3; i++) {
    const previous = (await ui(page)).sheet;
    if (!previous) break;
    await tapName(page, context, 'CloseSheet');
    await page.waitForFunction(previous => window.FlotraViewport.uiMetrics.sheet !== previous, previous);
  }
  await expectUI(page, {sheet: ''});
}
async function dispatch(page, context, type, points) {
  await (await session(page, context)).send('Input.dispatchTouchEvent', {type, touchPoints: points});
}
async function moveTouches(page, context, starts, ends, steps = 6) {
  for (let step = 1; step <= steps; step++) {
    await dispatch(page, context, 'touchMove', starts.map((point, index) => ({id: point.id,
      x: point.x + (ends[index].x - point.x) * step / steps,
      y: point.y + (ends[index].y - point.y) * step / steps})));
    await page.waitForTimeout(45);
  }
}
async function dragWorld(page, context, starts, ends, cancel = false) {
  await dispatch(page, context, 'touchStart', starts);
  await page.waitForTimeout(120);
  await moveTouches(page, context, starts, ends);
  await page.waitForTimeout(90);
  await dispatch(page, context, cancel ? 'touchCancel' : 'touchEnd', []);
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===0,null,{timeout:3000});
}
function assertNoSelection(state, label) {
  assert.equal(state.sheet, '', `${label}: no sheet opened through world input`);
  assert.equal(state.selectedSlot, '', `${label}: no equipment accidentally selected`);
}
function pose(c) { return {zoom:c.zoom,turn:c.turn,panX:c.panX,panY:c.panY}; }
function unchanged(before, after, label, tolerance = 0.002) {
  for (const key of ['zoom','turn','panX','panY']) closeEnough(after[key],before[key],`${label} ${key}`,tolerance);
}
function released(c, label) { assert.equal(c.touches,0,`${label}: touch count cleared`); assert.equal(c.mouseDown,false,`${label}: mouse not held`); }
function moved(before, after, label) { assert.ok(Math.hypot(after.panX-before.panX,after.panY-before.panY)>0.05,`${label}: view actually pans`); }
function checkCallouts(state, label) {
  const c=state.camera, r=state.worldRect;
  assert.ok(Array.isArray(c.callouts) && c.callouts.length >= 3,`${label}: real callout geometry exposed`);
  for (const item of c.callouts) {
    if (!item.text) continue;
    const inView=item.anchorX>=0 && item.anchorX<r.width && item.anchorY>=0 && item.anchorY<r.height;
    assert.equal(item.visible,inView,`${label}: ${item.text} visibility tracks actual anchor`);
    if(item.visible){
      assert.ok(item.fontSize>=18,`${label}: CSS-readable ${item.text}`);
      assert.ok(item.x>=-1 && item.y>=-1 && item.x+item.width<=r.width+1 && item.y+item.height<=r.height+1,`${label}: ${item.text} stays inside world viewport`);
    }
  }
}
async function points(page) {
  const state=await ui(page), rect=state.worldRect, m=await measure(page);
  const x=m.canvas.rect.x+rect.x, y=m.canvas.rect.y+rect.y;
  return {rect,x,y,cx:x+rect.width*.5,cy:y+rect.height*.5,dx:Math.min(85,rect.width*.22),dy:Math.min(55,rect.height*.22)};
}
async function reset(page,context,baseline){
  await tapName(page,context,'CameraReset');await page.waitForFunction(()=>{const c=window.FlotraViewport.uiMetrics.camera;return c.zoom===1 && c.turn===0 && Math.abs(c.panX)<.002 && Math.abs(c.panY)<.002 && c.touches===0 && !c.mouseDown;},null,{timeout:3000});const c=await camera(page);unchanged(baseline,c,'Reset');released(c,'Reset');
  closeEnough(c.size,c.fitSize,'Reset fits whole warehouse',0.001);
  return c;
}
async function onePan(page,context,cancel=false,reverse=false){
  const p=await points(page), before=await camera(page),sign=reverse?-1:1;
  await dragWorld(page,context,[{id:0,x:p.cx+sign*p.dx*.6,y:p.cy-sign*p.dy*.5}],[{id:0,x:p.cx-sign*p.dx*.6,y:p.cy+sign*p.dy*.5}],cancel);
  const after=await camera(page);moved(before,after,cancel?'Cancelled drag has already moved':'World touch drag');released(after,'Touch completion');assertNoSelection(await ui(page),'Touch pan');return after;
}
async function pinch(page,context,outward=true){
  const p=await points(page), before=await camera(page);
  const small=Math.min(45,p.rect.width*.12),large=Math.min(120,p.rect.width*.32), a=outward?small:large,b=outward?large:small;
  await dragWorld(page,context,[{id:0,x:p.cx-a,y:p.cy},{id:1,x:p.cx+a,y:p.cy}],[{id:0,x:p.cx-b,y:p.cy},{id:1,x:p.cx+b,y:p.cy}]);
  const after=await camera(page);
  assert.ok(outward ? after.zoom>before.zoom+.15 : after.zoom<before.zoom-.15,'Real two-finger pinch changes zoom in expected direction');
  assert.ok(after.zoom>=1 && after.zoom<=3,'Pinch respects zoom bounds');released(after,'Pinch');assertNoSelection(await ui(page),'Pinch');
  closeEnough((await measure(page)).viewport.visualScale,1,'Pinch changes game camera rather than browser zoom',.01);return after;
}
async function interruptions(page,context,baseline,result){
  let p;
  if(!['lost-release','focus-resize'].includes(process.env.FLOTRA_CAMERA_PHASE)){await reset(page,context,baseline);await onePan(page,context,true);await onePan(page,context,false,true);result.touchCancelRecovery=true;}
  if(process.env.FLOTRA_CAMERA_PHASE!=='focus-resize'){
  await reset(page,context,baseline);
  p=await points(page);
  await page.mouse.move(p.cx,p.cy);await page.mouse.down();await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.mouseDown===true,null,{timeout:3000});
  assert.equal((await camera(page)).mouseDown,true,'Actual mouse press held');
  await page.mouse.move(p.cx+45,p.cy+10,{steps:5});await page.waitForTimeout(250);
  await (await session(page,context)).send('Input.dispatchMouseEvent',{type:'mouseMoved',x:p.cx+50,y:p.cy+15,button:'none',buttons:0});
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.mouseDown===false,null,{timeout:3000});released(await camera(page),'Lost mouse release');
  const ended=await camera(page);await page.mouse.move(p.cx-40,p.cy-20);await page.mouse.up();
  unchanged(ended,await freshCamera(page),'Hover after lost release');assertNoSelection(await ui(page),'Lost release');result.lostReleaseRecovery=true;
  if(process.env.FLOTRA_CAMERA_PHASE==='lost-release')return;
  }
  await reset(page,context,baseline);p=await points(page);
  await dispatch(page,context,'touchStart',[{id:0,x:p.cx,y:p.cy}]);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===1,null,{timeout:3000});
  const size=page.viewportSize();await page.setViewportSize({width:size.width,height:size.height-35});await settle(page);await page.waitForTimeout(350);
  await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===0,null,{timeout:3000});released(await camera(page),'Resize interrupts held touch');
  const resized=await camera(page);await dispatch(page,context,'touchEnd',[]);unchanged(resized,await freshCamera(page),'Stale release after resize');
  await page.setViewportSize(size);await settle(page);await page.waitForTimeout(350);await onePan(page,context);result.resizeRecovery=true;
  await reset(page,context,baseline);p=await points(page);
  await (await session(page,context)).send('Emulation.setFocusEmulationEnabled',{enabled:false});
  await dispatch(page,context,'touchStart',[{id:0,x:p.cx,y:p.cy}]);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===1,null,{timeout:3000});
  const other=await context.newPage();await other.goto('about:blank');await (await session(other,context)).send('Emulation.setFocusEmulationEnabled',{enabled:false});await other.bringToFront();await page.waitForTimeout(800);
  assert.equal(await page.evaluate(()=>document.hasFocus()),false,'Actual headed browser focus moved to another tab');
  await page.bringToFront();await other.close();assert.equal(await page.evaluate(()=>document.hasFocus()),true,'Actual game tab regained focus');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===0,null,{timeout:3000});released(await camera(page),'Real focus loss cancels camera');
  const focused=await camera(page);await dispatch(page,context,'touchEnd',[]);unchanged(focused,await freshCamera(page),'Stale release after real focus return');
  await onePan(page,context);result.focusRecovery=true;
  await reset(page,context,baseline);p=await points(page);
  await dispatch(page,context,'touchStart',[{id:0,x:p.cx,y:p.cy}]);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.touches===1,null,{timeout:3000});
  await moveTouches(page,context,[{id:0,x:p.cx,y:p.cy}],[{id:0,x:p.cx,y:p.y-25}]);
  await dispatch(page,context,'touchEnd',[]);released(await freshCamera(page),'World-to-HUD crossing');assertNoSelection(await ui(page),'World-to-HUD crossing');result.hudBoundaryRecovery=true;
  await reset(page,context,baseline);
}
async function cameraCase(page,context,result){
  await closeSheets(page,context);
  const initial=await ui(page);assert.equal(initial.growth.wing_count,4,'Validated mature fixture has all four wings');assert.equal(initial.trialRunning,false,'QA starts paused');
  // A new session now starts in the work preset. Check that independently,
  // then use the actual Whole button before every preserved overview gate.
  assert.equal(initial.camera.framing,'work','Fresh session defaults to work framing before any Reset input');
  assert.equal(initial.camera.turn,0,'Fresh work view retains the original bearing');
  assert.ok(initial.camera.zoom>=1.4 && initial.camera.zoom<=3,'Mature default work view is meaningfully closer within original zoom bounds');
  released(initial.camera,'Initial work');
  for(const id of ['shelf','packing']){
    const p=initial.slots[id],r=initial.worldRect;
    assert.ok(p && p.x>r.x && p.x<r.x+r.width && p.y>r.y && p.y<r.y+r.height,`Default work framing shows actual ${id}`);
  }
  result.initialWork=initial.camera;
  await tapName(page,context,'CameraReset');
  await page.waitForFunction(()=>{const c=window.FlotraViewport.uiMetrics.camera;return c.framing==='overview' && c.zoom===1 && c.turn===0 && Math.abs(c.panX)<.002 && Math.abs(c.panY)<.002;},null,{timeout:3000});
  const start=await ui(page);
  const domain={wallet:start.wallet,simTime:start.simTime,upgrades:start.upgrades,progress:start.progress};
  const baseline=await freshCamera(page);result.baseline=baseline;
  const measured=await measure(page);
  const controls=start.buttons.filter(b=>b.visible && ['CameraLeft','CameraRight','CameraOut','CameraIn','CameraWork','CameraReset'].includes(b.name));
  assert.equal(controls.length,6,'All six camera controls stay visible in overview');
  for(const b of controls){
    assert.ok(b.width>=55.99 && b.height>=56 && b.fontSize>=18,`${b.name} retains minimum CSS touch/readability size (0.01px float tolerance)`);
    assert.ok(b.x>=0 && b.y>=0 && b.x+b.width<=measured.canvas.rect.width+1 && b.y+b.height<=measured.canvas.rect.height+1,`${b.name} remains inside phone HUD`);
    for(const other of start.buttons.filter(x=>x.visible && x.name!==b.name)){
      const overlapW=Math.min(b.x+b.width,other.x+other.width)-Math.max(b.x,other.x);
      const overlapH=Math.min(b.y+b.height,other.y+other.height)-Math.max(b.y,other.y);
      assert.ok(overlapW<=1 || overlapH<=1,`${b.name} does not overlap ${other.name}`);
    }
  }
  assert.equal(baseline.turn,0);assert.equal(baseline.zoom,1);released(baseline,'Initial');
  verify(await measure(page),result.label);checkCallouts(await ui(page),'Initial view');
  const floors=baseline.floorPoints;assert.ok(floors.length>=4,'All four mature wing centers exposed');
  const r=start.worldRect;for(const f of floors) assert.ok(f.x>=r.x && f.x<=r.x+r.width && f.y>=r.y && f.y<=r.y+r.height,`Reset shows ${f.name}`);
  await page.screenshot({path:path.join(output,`overview-${result.label}.png`),scale:'css'});
  if(['interruptions','lost-release','focus-resize'].includes(process.env.FLOTRA_CAMERA_PHASE)){await interruptions(page,context,baseline,result);return;}
  await onePan(page,context);checkCallouts(await ui(page),'Panned');await reset(page,context,baseline);
  await pinch(page,context);checkCallouts(await ui(page),'Zoomed');await pinch(page,context,false);await reset(page,context,baseline);result.panPinch=true;
  await tapName(page,context,'CameraIn');let c=await freshCamera(page);assert.ok(c.zoom>1,'Accessible zoom-in control changes view');
  await tapName(page,context,'CameraOut');c=await freshCamera(page);closeEnough(c.zoom,1,'Accessible zoom-out restores base zoom',.002);
  for(let turn=1;turn<=4;turn++){
    await tapName(page,context,'CameraRight');await page.waitForFunction(turn=>window.FlotraViewport.uiMetrics.camera.turn===turn,turn%4,{timeout:3000});c=await camera(page);assert.equal(c.turn,turn%4,'Right control rotates one quarter turn');
    checkCallouts(await ui(page),`Right ${turn}`);assertNoSelection(await ui(page),'Rotation');
    if(turn===1 || turn===2)await page.screenshot({path:path.join(output,`rotate${turn}-${result.label}.png`),scale:'css'});
  }
  await tapName(page,context,'CameraLeft');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.camera.turn===3,null,{timeout:3000});assert.equal((await camera(page)).turn,3,'Left control rotates opposite quarter turn');await reset(page,context,baseline);result.rotateReset=true;
  // Zoom into every authoritative wing and pan its center into the world view.
  const wings=floors.slice(0,4).map((f,index)=>({...f,index}));
  for(const target of wings){
    await reset(page,context,baseline);await pinch(page,context);
    for(let attempt=0;attempt<5;attempt++){
      let state=await ui(page), f=state.camera.floorPoints[target.index],p=await points(page);
      const fx=f.x+(await measure(page)).canvas.rect.x,fy=f.y+(await measure(page)).canvas.rect.y;
      if(fx>p.x+15 && fx<p.x+p.rect.width-15 && fy>p.y+15 && fy<p.y+p.rect.height-15)break;
      const dx=Math.max(-p.rect.width*.5,Math.min(p.rect.width*.5,p.cx-fx));
      const dy=Math.max(-p.rect.height*.5,Math.min(p.rect.height*.5,p.cy-fy));
      await dragWorld(page,context,[{id:0,x:p.cx-dx*.5,y:p.cy-dy*.5}],[{id:0,x:p.cx+dx*.5,y:p.cy+dy*.5}]);
    }
    const state=await ui(page),f=state.camera.floorPoints[target.index],v=state.worldRect;
    assert.ok(f.x>=v.x && f.x<=v.x+v.width && f.y>=v.y && f.y<=v.y+v.height,`Zoomed ${target.name} reachable by touch pan`);
    checkCallouts(state,`Reached ${target.name}`);
  }
  result.reachableFloors=wings.map(f=>({name:f.name,index:f.index}));await reset(page,context,baseline);
  // Scroll/tap actions in opaque reading sheets cannot modify overview pose.
  await tapName(page,context,'Back');await expectUI(page,{sheet:'controls'});const menuPose=await camera(page);
  await tapName(page,context,'Speed4x',true);await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.speed===4);
  const scroll=(await ui(page)).scroll;await swipe(page,context,scroll,true);unchanged(menuPose,await camera(page),'Menu tap/scroll camera isolation');
  await closeSheets(page,context);unchanged(baseline,await freshCamera(page),'Closing controls restores same view');result.uiIsolation=true;
  await interruptions(page,context,baseline,result);
  if(result.label==='375x567-dpr3'){
    const style=await page.addStyleTag({content:'#canvas { position: fixed !important; left: 12px !important; top: 47px !important; width: calc(100vw - 24px) !important; height: calc(var(--flotra-visible-height) - 81px) !important; }'});
    await settle(page);await page.waitForTimeout(450);verify(await measure(page),'Camera synthetic safe area');
    const inset=await ui(page);for(const b of inset.buttons.filter(b=>b.visible && b.name.startsWith('Camera'))){
      assert.ok(b.width>=55.99 && b.height>=56,`${b.name} remains a 56px target with side insets (0.01px float tolerance)`);
      assert.ok(b.x>=0 && b.x+b.width<=351,'Camera controls fit inset CSS canvas');
    }
    await onePan(page,context);await pinch(page,context);checkCallouts(await ui(page),'Synthetic inset gestures');await reset(page,context,baseline);
    await page.screenshot({path:path.join(output,`inset-camera-${result.label}.png`),scale:'css'});
    await style.evaluate(el=>el.remove());await settle(page);await page.waitForTimeout(400);result.syntheticSafeArea=true;
  }
  const after=await ui(page);for(const key of ['wallet','simTime','upgrades','progress'])assert.deepEqual(after[key],domain[key],`Camera controls preserve ${key}`);
  result.domainUnchanged=true;result.final=after.camera;
}
(async()=>{
  let browser;
  try{
    browser=await chromium.launch({executablePath:process.env.CHROMIUM_EXECUTABLE||undefined,headless:false});
    for(const [width,height] of cases)for(const dpr of dprs){
      const started=Date.now(),label=`${width}x${height}-dpr${dpr}`,result={label,status:'running',errors:[]};report.results.push(result);
      const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:dpr,isMobile:true,hasTouch:true});
      await context.addInitScript(encoded=>{if(localStorage.getItem('flotra.campaign.release.v1')===null)localStorage.setItem('flotra.campaign.release.v1',encoded);},matureFixture.encoded);
      const page=await context.newPage();page.setDefaultTimeout(15000);
      await page.addInitScript(()=>{window.__cameraDOMMouse=[];for(const type of ['mousedown','mousemove','mouseup'])window.addEventListener(type,e=>{window.__cameraDOMMouse.push({type,x:e.clientX,y:e.clientY,buttons:e.buttons,button:e.button,time:performance.now()});if(window.__cameraDOMMouse.length>40)window.__cameraDOMMouse.shift();},{capture:true});});
      page.on('pageerror',e=>result.errors.push(e.message));page.on('console',m=>{if(m.type()==='error')result.errors.push(m.text());});
      try{
        console.log(`CAMERA START ${label}`);await page.goto(url,{waitUntil:'domcontentloaded',timeout:60000});
        await page.waitForFunction(()=>!!window.FlotraViewport?.uiMetrics?.camera,null,{timeout:120000});await settle(page);await page.waitForTimeout(400);
        result.environment=await page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return {dpr:devicePixelRatio,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,visibility:document.visibilityState};});
        assert.ok(result.environment.renderer,'Actual WebGL2 renderer exists');
        await cameraCase(page,context,result);assert.deepEqual(result.errors,[],'No runtime errors');result.status='passed';console.log(`CAMERA PASS ${label}`);
      }catch(error){result.status='failed';result.error=error.message;result.last=await ui(page).catch(()=>null);result.domMouse=await page.evaluate(()=>window.__cameraDOMMouse).catch(()=>null);await page.screenshot({path:path.join(output,`failure-${label}.png`),scale:'css'}).catch(()=>{});throw error;}
      finally{result.wallSeconds=(Date.now()-started)/1000;fs.writeFileSync(path.join(output,'browser-camera-controls.json'),JSON.stringify(report,null,2));await context.close();}
    }
    console.log(`BROWSER_CAMERA_CONTROLS ${report.results.length} cases passed`);
  }catch(error){report.error=error.message;console.error(error);process.exitCode=1;}
  finally{fs.writeFileSync(path.join(output,'browser-camera-controls.json'),JSON.stringify(report,null,2));await browser?.close();}
})();
