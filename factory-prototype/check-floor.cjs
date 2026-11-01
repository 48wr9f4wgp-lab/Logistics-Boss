// Exercises the real entry point on an isolated save; accepts a local or deployed preview URL.
const assert = require('node:assert/strict');
const { mkdir } = require('node:fs/promises');
const path = require('node:path');
const {checkInquiry}=require('./check-inquiry.cjs');
const {checkPrecision}=require('./check-precision.cjs');
const {checkEstimates}=require('./check-estimates.cjs');
const {checkImprovement}=require('./check-improvement.cjs');
const {checkFloorControls}=require('./check-floor-controls.cjs');
const { chromium, webkit } = require('playwright-core');

async function check(browser, url, width, height) {
  const context = await browser.newContext({viewport:{width,height}, isMobile:true, hasTouch:true});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const folder = path.join(process.env.RUNNER_TEMP || '.', 'factory-floor-screens');
  await mkdir(folder, {recursive:true});
  const engine=browser.browserType().name();
  const capture = name => page.screenshot({path:path.join(folder, engine+'-'+width+'-'+name+'.jpg'), quality:86});
  const button = name => page.getByRole('button', {name,exact:true});
  const ticket = page.locator('#orderAction');
  const shown = async locator => locator.waitFor({state:'visible',timeout:10000});
  try {
    await page.goto(url, {waitUntil:'load'});
    await shown(button('材料費 ¥600 で受注する'));
    await page.locator('#world[data-artwork="ready"]').waitFor();
    await page.waitForFunction(()=>!document.querySelector('#orderAction').disabled);
    await page.evaluate(async()=>{
      await document.fonts.ready;
      const backdrop=new Image();
      backdrop.src=new URL('art/workbench-v013.webp',document.baseURI).href;
      await backdrop.decode();
      if(!getComputedStyle(document.querySelector('#scene')).backgroundImage.includes(backdrop.src))throw Error('workbench is not displayed');
    });
    assert.equal(await page.locator('button:visible, summary:visible').count(), 3, 'one ticket, management and floor controls');
    const bounds = await ticket.boundingBox();
    assert.ok(bounds && bounds.height >= 44 && bounds.y + bounds.height <= height);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth), true);
    await capture('opening');
    await button('管理').click();
    await button('注文一覧').click();
    await shown(button('この12個を受注して始める'));
    await button('工場へ戻る').click();
    await ticket.click();
    await shown(button('完成まで進める'));
    await page.reload();
    await page.locator('#world[data-artwork="ready"]').waitFor();
    await shown(button('完成まで進める'));
    await page.waitForFunction(()=>!document.querySelector('#orderAction').disabled);
    await capture('work');
    await page.locator('#controls summary').click();
    await button('一時停止').click();
    await shown(page.getByText('一時停止中',{exact:true}));
    // Compare actual paused pixels across a zoom/reset. A transparent canvas must clear old art.
    const world=page.locator('#world');
    const frame=()=>world.evaluate(c=>c.toDataURL());
    const paused=await frame();
    await button('拡大').click();
    await page.waitForFunction(ref=>document.querySelector('#world').toDataURL()!==ref,paused);
    await button('全景').click();
    await page.waitForFunction(ref=>document.querySelector('#world').toDataURL()===ref,paused);
    await page.locator('#controls summary').click();
    // Press the head of the initial drill as rendered on the factory floor.
    const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
    const rect=await world.boundingBox();
    const hit=project(frameWorkshop(rect.width,rect.height,8),5.5,1.5,1.22);
    await world.click({position:hit});
    await shown(page.getByText('ボール盤 · Lv.1',{exact:true}));
    await button('設備の選択を解除').click();
    await page.locator('#controls summary').click();
    await button('設備名').click();
    await button('拡大').click();
    await button('全景').click();
    await page.getByRole('button',{name:/切断機：工程待ち/}).click();
    await shown(button('移動'));
    await button('設備の選択を解除').click();
    await page.locator('#controls summary').click();
    await button('設備名を隠す').click();
    await button('全景').click();
    await page.locator('#controls summary').click();
    await ticket.click();
    await shown(button('出荷する'));
    const readyBounds = await ticket.boundingBox();
    assert.ok(Math.abs((bounds.y+bounds.height)-(readyBounds.y+readyBounds.height)) <= 1);
    await ticket.click();
    await shown(button('工場の改善を選ぶ'));
    assert.match(await page.locator('#ticketLabel').innerText(),/出荷完了.*利益/);
    await capture('shipped');
    await ticket.click();
    await button('改善はあとで · 成長目標へ').click();
    await shown(page.getByRole('heading',{name:'成長案件',exact:true}));
    await page.getByRole('button',{name:'この目標を追う'}).first().click();
    await button('工場へ戻る').click();
    await shown(button('目標の計画を見る'));
    await button('管理').click();await button('経営と出荷記録').click();
    await button('直近の出荷結果を開く').click();
    await shown(page.getByText('今回の受注利益',{exact:true}));
    await page.getByText('収支の内訳・前回との比較',{exact:true}).click();
    await shown(page.getByText('人件費',{exact:true}));
    assert.deepEqual(errors,[]);
    console.log(engine+' '+width+'×'+height+' passed: opening, reload, controls, work, dispatch, growth and receipt.');
  } finally {
    await context.close();
  }
}
// Restore a busy shift through the same save path that a returning player uses.
async function checkShift(browser,url) {
  const M=await import('../docs/forge-preview/model.mjs');
  const s=M.fresh();
  M.accept(s,'first');
  for(let i=0;i<744;i++)M.step(s,M.TICK);
  assert.ok(M.validate(s));
  const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true});
  try {
    await context.addInitScript(state=>{
      localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'crew-visual-check',state}));
    },s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    await page.goto(url,{waitUntil:'load'});
    const ticket=page.getByRole('button',{name:'完成まで進める',exact:true});
    await ticket.waitFor({state:'visible'});
    await page.locator('#world[data-artwork="ready"]').waitFor();
    await page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',browser.browserType().name()+'-390-crew-working.jpg'),quality:90});
    await ticket.click();
    await page.getByRole('button',{name:'出荷する',exact:true}).click();
    await page.getByRole('button',{name:'工場の改善を選ぶ',exact:true}).waitFor({state:'visible'});
    assert.deepEqual(errors,[]);
    console.log('390×844 DPR2 passed: restored busy crew, rendering and shipment.');
  } finally {await context.close();}
}
async function checkExpandedArt(browser,url,offlineArt=false){
  const M=await import('../docs/forge-preview/model.mjs'),s=M.fresh();
  s.cash=50000;M.expand(s);M.purchase(s,'lathe',4,3);
  for(const m of s.machines){M.upgrade(s,m.id);M.upgrade(s,m.id);}
  M.accept(s,'fine');
  for(let i=0;i<2000&&!s.workers.some(w=>w.job?.phase==='work'&&s.machines.find(m=>m.id===w.job.machine)?.kind==='lathe');i++)M.step(s,M.TICK);
  assert.ok(M.validate(s));
  const engine=browser.browserType().name();
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,reducedMotion:'reduce'});
  try{
    if(offlineArt)await context.route(/\/art\/[^/]+-v01[567]\.webp(?:\?.*)?$/,r=>r.abort());
    await context.addInitScript(state=>localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'expanded-art',state})),s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    await page.goto(url,{waitUntil:'load'});
    const world=page.locator('#world[data-artwork="'+(offlineArt?'partial':'ready')+'"]');
    await world.waitFor();
    if(!offlineArt){
      await page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-expanded.jpg'),quality:90});
      const assets=await page.evaluate(()=>performance.getEntriesByType('resource').map(r=>r.name));
      assert.ok(assets.some(f=>f.includes('room-10-v017.webp')));
      assert.ok(!assets.some(f=>f.includes('room-8-v017.webp')));
    }
    await page.getByRole('button',{name:'完成まで進める',exact:true}).click();
    await page.getByRole('button',{name:'出荷する',exact:true}).click();
    await page.getByRole('button',{name:'次の成長目標を選ぶ',exact:true}).waitFor();
    assert.deepEqual(errors,[]);
    console.log(engine+' expanded '+(offlineArt?'fallback':'baked')+' passed: level 3, lathe, reduced motion and dispatch.');
  }finally{await context.close();}
}
(async()=>{
  const browser=process.argv[3]==='webkit'?await webkit.launch():await chromium.launch({channel:'chrome',args:['--no-sandbox']});
  try {
    const sizes=process.argv[3]==='webkit'?[[390,844]]:[[390,844],[320,568]];
    for(const [width,height] of sizes)await check(browser,process.argv[2],width,height);
    for(const choice of ['move','upgrade'])await checkImprovement(browser,process.argv[2],choice);
    for(const term of ['bulk','rush'])await checkEstimates(browser,process.argv[2],term);
    if(process.argv[3]!=='webkit')await checkEstimates(browser,process.argv[2],'offline');
    for(const route of ['entry','bench'])await checkPrecision(browser,process.argv[2],route);
    for(const flow of ['hold','switch',...(process.argv[3]==='webkit'?[]:['decline','offline'])])await checkInquiry(browser,process.argv[2],flow);
    await checkFloorControls(browser,process.argv[2]);
    await checkShift(browser,process.argv[2]);
    await checkExpandedArt(browser,process.argv[2]);
    if(process.argv[3]!=='webkit')await checkExpandedArt(browser,process.argv[2],true);
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
