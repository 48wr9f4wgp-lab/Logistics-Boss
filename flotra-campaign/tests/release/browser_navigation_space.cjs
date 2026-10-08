#!/usr/bin/env node
'use strict';
// Actual rendered-pixel qualification, for an authorized disposable CI runner.
// Never use a user profile or public origin. Baseline mode captures the old UI
// without asserting the new routing; it is comparison evidence, not a pass.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const url = new URL(process.argv[2]);
assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(url.hostname), 'Loopback export only');
url.searchParams.set('phone_qa', '1');
const output = path.resolve(process.argv[3]);
const fixture = JSON.parse(fs.readFileSync(path.join(process.argv[4], 'complete.json'), 'utf8'));
const baseline = process.env.FLOTRA_UI_BASELINE === '1';
const report = { kind: 'Fresh Chromium WebGL pixels and CSS geometry; not physical Windows/iPhone qualification', baseline, url: url.href, cases: [] };
const sizes = [[1280,720,1], [1920,1080,1], [1280,720,2], [375,667,2], [390,844,3]];
fs.mkdirSync(output, { recursive: true });
const ui = page => page.evaluate(() => window.FlotraViewport?.uiMetrics);
async function waitSheet(page, sheet) {
  await page.waitForFunction(sheet => window.FlotraViewport?.uiMetrics?.sheet === sheet, sheet);
  await page.waitForTimeout(250); // Existing dismissal guard, never bypass it.
}
async function click(page, name, mobile) {
  await page.waitForFunction(name => window.FlotraViewport?.uiMetrics?.buttons.some(b => b.name === name && b.visible && !b.disabled), name);
  const button = (await ui(page)).buttons.find(b => b.name === name && b.visible);
  const rect = await page.locator('#canvas').boundingBox();
  const x = rect.x + button.x + button.width/2, y = rect.y + button.y + button.height/2;
  assert.ok(y >= rect.y && y <= rect.y + rect.height && x >= rect.x && x <= rect.x + rect.width, 'Real visible target: ' + name);
  if (mobile) await page.touchscreen.tap(x,y); else await page.mouse.click(x,y);
  await page.waitForTimeout(250);
}
async function shot(page, item, state) {
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const name = item.name + '-' + state;
  await page.screenshot({ path: path.join(output, name + '.jpg'), type: 'jpeg', quality: 85, scale: 'css' });
  item.screenshots.push(name + '.jpg');
  item.states[state] = await ui(page);
  console.log('NAVIGATION_CAPTURE_SCREEN '+JSON.stringify({case:item.name,screen:state,sheet:item.states[state].sheet,worldRect:item.states[state].worldRect,status:item.states[state].status}));
}
(async () => {
  let browser;
  try {
    browser = await chromium.launch({ executablePath: process.env.CHROMIUM_EXECUTABLE || undefined, headless: true });
    report.chromiumVersion = browser.version();
    for (const [width,height,dpr] of sizes) for (const mature of [false,true]) {
      const mobile = width < 1000;
      const item = { name: `${width}x${height}-dpr${dpr}-${mature ? 'mature' : 'starter'}`, screenshots: [], states: {}, errors: [] };
      report.cases.push(item);
      const context = await browser.newContext({ viewport:{width,height}, deviceScaleFactor:dpr, isMobile:mobile, hasTouch:mobile, serviceWorkers:'block' });
      const page = await context.newPage();
      page.setDefaultTimeout(15000);
      page.on('pageerror', e => item.errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') item.errors.push(m.text()); });
      try {
        if (mature) await context.addInitScript(encoded => { if (localStorage.getItem('flotra.campaign.release.v1') === null) localStorage.setItem('flotra.campaign.release.v1', encoded); }, fixture.encoded);
        await page.goto(url.href, { waitUntil:'domcontentloaded', timeout:60000 });
        await page.waitForFunction(() => !!window.FlotraViewport?.uiMetrics, null, {timeout:120000});
        await waitSheet(page,'entry');
        await click(page,'CloseSheet',mobile);
        if ((await ui(page)).sheet === 'jobs') await click(page,'CloseSheet',mobile);
        await waitSheet(page,'');
        const state = await ui(page);
        const canvas = await page.evaluate(() => { const c=document.querySelector('#canvas'),r=c.getBoundingClientRect(); return {width:c.width,height:c.height,cssWidth:r.width,cssHeight:r.height}; });
        assert.equal(canvas.width,Math.round(width*dpr),'Full-DPR render width preserved');
        assert.equal(canvas.height,Math.round(height*dpr),'Full-DPR render height preserved');
        assert.equal(canvas.cssWidth,width); assert.equal(canvas.cssHeight,height);
        assert.ok(state.labels.length && state.labels.every(l=>l.fontSize>=18),'Visible labels retain 18px+');
        item.viewport = {width,height,dpr,world:state.worldRect,warehouseHeightRatio:state.worldRect.height/height};
        if (!baseline) {
          assert.equal(state.worldRect.y,mobile?140:104);
          assert.equal(state.worldRect.height,height-(mobile?360:188));
          const actions=['WorkChoice','EquipmentChoice','ChangeLayout','CameraLeft','CameraRight','CameraOut','CameraIn','CameraReset'];
          for (const name of actions) {
            const b=state.buttons.find(b=>b.name===name&&b.visible);
            assert.ok(b&&b.fontSize>=18&&b.height>=(mobile?56:44),'Readable direct action: '+name);
          }
          const reset=state.buttons.find(b=>b.name==='CameraReset');
          assert.ok(reset.width<=80,'Whole-view is a restrained button');
          // dispatch_save.load_into owns these two fixture states. A fresh
          // warehouse has status '新しい倉庫', which correctly lacks '保存'.
          const expectedStatus=mature?'旧保存を読み込みました。旧データを残して新版専用に保存します':'新しい倉庫';
          const save=state.labels.find(l=>l.text===expectedStatus&&l.x===(mobile?104:220)&&l.y===(mobile?40:14));
          assert.ok(save,'Actual header status control exposes exact source-owned fixture text');
          assert.ok(save.fontSize>=18&&save.width>0&&save.height>0&&save.x>=0&&save.y>=0&&save.x+save.width<=width&&save.y+save.height<=(mobile?76:60),'Header status remains readable and inside its visible header');
        }
        await shot(page,item,'warehouse');
        await click(page,'WorkChoice',mobile); await waitSheet(page,'jobs');
        await shot(page,item,'jobs');
        if (!baseline) assert.ok(!(await ui(page)).buttons.some(b=>b.name.startsWith('Tab_')&&b.visible),'No shared jobs/equipment tabs');
        await click(page,'CloseSheet',mobile); await waitSheet(page,'');
        if (baseline) { await click(page,'WorkChoice',mobile); await waitSheet(page,'jobs'); await click(page,'Tab_upgrades',mobile); }
        else await click(page,'EquipmentChoice',mobile);
        await waitSheet(page,'jobs'); await shot(page,item,'equipment');
        await click(page,'CloseSheet',mobile); await waitSheet(page,'');
        await click(page,'ChangeLayout',mobile); await waitSheet(page,'editor'); await shot(page,item,'placement');
        await click(page,'CloseSheet',mobile); await waitSheet(page,'');
        await click(page,'CameraIn',mobile); await click(page,'CameraRight',mobile); await shot(page,item,'camera');
        await click(page,'CameraReset',mobile); await shot(page,item,'reset');
        assert.deepEqual(item.errors,[],'No runtime/browser errors');
        item.status='passed';
      } catch (error) {
        item.status='failed'; item.error=error.stack;
        console.error('NAVIGATION_CAPTURE_FIRST_FAILURE '+JSON.stringify({case:item.name,completedScreens:Object.keys(item.states),error:error.stack}));
        await shot(page,item,'failure').catch(()=>{});
        throw error;
      } finally { await context.close(); fs.writeFileSync(path.join(output,'navigation-space.json'),JSON.stringify(report,null,2)); }
    }
  } catch (error) { report.error=error.stack; process.exitCode=1; }
  finally { if(browser) await browser.close(); fs.writeFileSync(path.join(output,'navigation-space.json'),JSON.stringify(report,null,2)); }
})();
