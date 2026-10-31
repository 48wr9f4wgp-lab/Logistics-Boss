// Exercises the real entry point on an isolated save; accepts a local or deployed preview URL.
const assert = require('node:assert/strict');
const { mkdir } = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require('playwright-core');

async function check(browser, url, width, height) {
  const context = await browser.newContext({viewport:{width,height}, isMobile:true, hasTouch:true});
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const folder = path.join(process.env.RUNNER_TEMP || '.', 'factory-floor-screens');
  await mkdir(folder, {recursive:true});
  const capture = name => page.screenshot({path:path.join(folder, width+'-'+name+'.jpg'), quality:86});
  const button = name => page.getByRole('button', {name,exact:true});
  const ticket = page.locator('#orderAction');
  const shown = async locator => locator.waitFor({state:'visible',timeout:10000});
  try {
    await page.goto(url, {waitUntil:'load'});
    await shown(button('材料費 ¥600 で受注する'));
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
    const hit=await world.evaluate(c=>{
      const {width:w,height:h}=c.getBoundingClientRect();
      const u=Math.min(w/16.45,(h-62)/10.7);
      const ox=w*.5-u+.22*u,oy=h*.5-14*u*.21;
      return {x:ox+4*u,y:oy+3.5*u-1.22*u};
    });
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
    await shown(button('次の成長目標を選ぶ'));
    assert.match(await page.locator('#ticketLabel').innerText(),/出荷完了.*利益/);
    await capture('shipped');
    await ticket.click();
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
    console.log(width+'×'+height+' passed: opening, reload, controls, work, dispatch, growth and receipt.');
  } finally {
    await context.close();
  }
}
(async()=>{
  const browser=await chromium.launch({channel:'chrome',args:['--no-sandbox']});
  try {
    for(const [width,height] of [[390,844],[320,568]])await check(browser,process.argv[2],width,height);
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
