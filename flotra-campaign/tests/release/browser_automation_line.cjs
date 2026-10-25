#!/usr/bin/env node
'use strict';
// Real, isolated browser contexts seeded only with earned synthetic fixtures.
// Generate with FLOTRA_LINE_FIXTURES=... godot --headless --path flotra-campaign
// --script res://tests/release/automation_line.gd, then supply URL, fixtures, output.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const [url, fixtures, output] = process.argv.slice(2);
assert.ok(url && fixtures && output, 'Supply local export URL, fixture directory, output directory');
const dpr = Number(process.env.FLOTRA_LINE_DPR || 1);
const report = { scope: 'Chromium emulation; synthetic earned saves; no real user storage', dpr, cases: [] };
(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_EXECUTABLE || undefined, headless: true });
  try {
    for (const [width, height] of [[375, 667], [390, 844], [1280, 720]]) {
    for (const name of ['before', 'owned', 'conveyor', 'sealing', 'transfer']) {
      const prefix = `${width}-${name}`;
      const context = await browser.newContext({ viewport: { width, height }, deviceScaleFactor: dpr, isMobile: width < 1000, hasTouch: true });
      try {
        const { encoded } = JSON.parse(fs.readFileSync(path.join(fixtures, name + '.json')));
        await context.addInitScript(encoded => localStorage.setItem('flotra.campaign.dispatch.v5', encoded), encoded);
        const page = await context.newPage();
        const errors = [];
        page.on('pageerror', error => errors.push(error.message));
        const target = new URL(url); target.searchParams.set('phone_qa', '1');
        await page.goto(target.href);
        const state = () => page.evaluate(() => window.FlotraViewport.uiMetrics);
        await page.waitForFunction(() => window.FlotraViewport?.uiMetrics?.buttons?.some(b => b.name === 'CloseSheet' && b.visible), null, { timeout: 60000 });
        const initial = await state();
        async function tap(name) {
          await page.waitForFunction(name => window.FlotraViewport.uiMetrics.buttons.some(b => b.name === name && b.visible && !b.disabled), name);
          const b = (await state()).buttons.find(b => b.name === name && b.visible);
          await page.waitForTimeout(300);
          await page.touchscreen.tap(b.x + b.width / 2, b.y + b.height / 2);
        }
        for (let i = 0; i < 4; i++) {
          const previous = (await state()).sheet;
          if (!previous) break;
          await tap('CloseSheet');
          await page.waitForFunction(previous => window.FlotraViewport.uiMetrics.sheet !== previous, previous);
        }
        await page.waitForFunction(() => window.FlotraViewport.uiMetrics.worldVisible && !window.FlotraViewport.uiMetrics.sheet);
        await page.waitForTimeout(600);
        await page.screenshot({ path: path.join(output, prefix + '-overview.png'), scale: 'css' });
        for (let i = 0; i < 2; i++) {
          const zoom = (await state()).camera.zoom;
          await tap('CameraIn');
          await page.waitForFunction(zoom => window.FlotraViewport.uiMetrics.camera.zoom > zoom, zoom);
        }
        await page.screenshot({ path: path.join(output, prefix + '-zoom.png'), scale: 'css' });
        if (name === 'transfer') {
          await tap('ChangeLayout');
          await page.waitForFunction(() => window.FlotraViewport.uiMetrics.sheet === 'editor');
          await tap('NextSlot');
          await page.waitForFunction(() => window.FlotraViewport.uiMetrics.selectedSlot === 'packing');
          await page.screenshot({ path: path.join(output, `${width}-transfer-layout-detail.png`), scale: 'css' });
        }
        const final = await state();
        assert.equal(final.trialRunning, false, 'Saved work stays paused');
        assert.equal(final.simTime, initial.simTime, 'Camera and layout selection never advance work');
        assert.deepEqual(final.progress, initial.progress, 'No invented output');
        assert.equal(final.wallet, initial.wallet, 'No hidden purchase');
        assert.deepEqual(errors, []);
        report.cases.push({ name, width, height, simTime: final.simTime, progress: final.progress, wallet: final.wallet, passed: true });
        if (name === 'transfer') {
          await tap('CloseSheet');
          await page.waitForFunction(() => !window.FlotraViewport.uiMetrics.sheet);
          await tap('CameraReset');
          await page.waitForFunction(() => window.FlotraViewport.uiMetrics.camera.zoom === 1);
          await tap('PauseResume');
          await page.waitForFunction(t => window.FlotraViewport.uiMetrics.trialRunning && window.FlotraViewport.uiMetrics.simTime > t + 1, initial.simTime);
          await page.screenshot({ path: path.join(output, `${width}-running-overview.png`), scale: 'css' });
          for (let i = 0; i < 2; i++) {
            const zoom = (await state()).camera.zoom;
            await tap('CameraIn');
            await page.waitForFunction(zoom => window.FlotraViewport.uiMetrics.camera.zoom > zoom, zoom);
          }
          await page.screenshot({ path: path.join(output, `${width}-running-zoom.png`), scale: 'css' });
          report.cases.push({ name: 'running', width, height, simTime: (await state()).simTime, progress: (await state()).progress, passed: true });
        }
      } finally { await context.close(); }
    }
    }
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(output, 'automation-line.json'), JSON.stringify(report, null, 2));
  }
  console.log('BROWSER_AUTOMATION_LINE ' + report.cases.length + ' cases passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
