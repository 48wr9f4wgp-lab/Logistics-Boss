const assert=require('node:assert/strict');

const key='forge.factory.v1';
const read=page=>page.evaluate(key=>JSON.parse(localStorage.getItem(key)),key);
const life=(page,event)=>page.evaluate(event=>window.dispatchEvent(new PageTransitionEvent(event,{persisted:true})),event);
async function snapshot(context){
  const saved=await context.storageState();
  return JSON.parse(saved.origins.flatMap(o=>o.localStorage).find(item=>item.name===key).value);
}
async function checkResume(browser,url){
  const M=await import('../docs/forge-preview/model.mjs');
  const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
  const engine=browser.browserType().name();
  const options={viewport:{width:390,height:844},isMobile:true,hasTouch:true};
  const ctx=await browser.newContext(options);
  try{
    const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
    const btn=name=>page.getByRole('button',{name,exact:true});
    await ctx.addInitScript(()=>window.addEventListener('pageshow',e=>{window.restoredFromHistory=e.persisted;}));
    await page.goto(url);await btn('材料費 ¥600 で受注する').click();
    await page.locator('#orderHint').filter({hasText:/順番待ち|進めています/}).waitFor();
    await page.waitForTimeout(250);await page.goto('about:blank');
    const suspended=await snapshot(ctx);assert.equal(M.frontOrder(suspended.state).offerId,'first');
    assert.ok(suspended.state.clock>0);
    await page.waitForTimeout(350);assert.deepEqual(await snapshot(ctx),suspended,'nothing runs while away');
    await page.goBack();await btn('工場の改善を選ぶ').waitFor({timeout:30000});
    const cached=await page.evaluate(()=>window.restoredFromHistory);
    const expected=structuredClone(suspended.state);
    let ready;do{ready=M.advanceToReady(expected,200);}while(ready.status==='producing');
    M.dispatch(expected,ready.orderId);
    const paid=(await read(page)).state;
    assert.deepEqual(paid.results,expected.results);assert.equal(paid.cash,expected.cash);
    await btn('工場の改善を選ぶ').click();await btn('改良して受注 · ¥2,100').click();
    await btn('短納期の注文を見る').click();await page.locator('.term-layout summary').click();
    await page.locator('#estimateMachine').selectOption('m3');await btn('床で配置を試す').click();
    const world=page.locator('#world'),box=await world.boundingBox();
    await world.tap({position:project(frameWorkshop(box.width,box.height,8),1.5,1.5)});
    await page.locator('#layoutEstimate').filter({hasText:'196.8秒'}).waitFor();
    await life(page,'pagehide');
    const draftCheckpoint=await snapshot(ctx);
    const visitor=await ctx.newPage();await visitor.goto(url);
    await visitor.getByRole('button',{name:'短納期の注文を見る',exact:true}).waitFor();
    await visitor.waitForFunction(()=>!document.querySelector('#orderAction').disabled);
    await visitor.close();
    assert.deepEqual(await snapshot(ctx),draftCheckpoint,'visiting a paused factory cannot replace the draft revision');
    await page.bringToFront();await life(page,'pageshow');
    await page.locator('#layoutEstimate').filter({hasText:'196.8秒'}).waitFor();
    await btn('配置を確定して見積へ').click();
    await page.locator('[data-estimate="rush"]').filter({hasText:/余裕/}).waitFor();
    await page.locator('#acceptTerm').click();await btn('小口6個の条件を見る').click();
    await page.locator('#inquiryPicker input[value="extra"]').check();
    await life(page,'pagehide');const held=(await read(page)).state;
    assert.equal(M.frontOrder(held).done,0);await page.waitForTimeout(250);
    await life(page,'pageshow');await btn('今回は見送る').waitFor();
    assert.ok(await page.locator('#inquiryPicker input[value="extra"]').isChecked(),'retain the unconfirmed choice on a same-document return');
    assert.deepEqual((await read(page)).state,held);await btn('今回は見送る').click();
    await page.locator('#orderTitle').filter({hasText:'量産の町工場'}).waitFor({timeout:30000});
    const end=(await read(page)).state;
    assert.ok(M.validate(end));assert.equal(end.delivered,3);assert.equal(end.results[0].seconds.toFixed(1),'196.8');
    assert.equal(end.specialties.length,1);assert.equal(end.specialties[0].orderId,end.results[0].orderId);
    assert.deepEqual(errors,[]);console.log(engine+' new auto factory, navigation/back (persisted='+cached+'), draft and inquiry resume, rushed 28 delivered in '+end.results[0].seconds.toFixed(1)+'s, one ending.');
  }finally{await ctx.close();}
  // Explicit persisted events cover the cached-document callback even on engines
  // that choose to reload after a real back navigation in headless mode.
  const handoff=await browser.newContext(options);
  try{
    const a=await handoff.newPage();await a.goto(url);
    const start=a.getByRole('button',{name:'材料費 ¥600 で受注する',exact:true});
    await start.waitFor();await a.waitForFunction(()=>!document.querySelector('#orderAction').disabled);
    await life(a,'pagehide');
    const b=await handoff.newPage();await b.goto(url);
    await b.getByRole('button',{name:'材料費 ¥600 で受注する',exact:true}).click();
    await life(a,'pageshow');
    await a.waitForFunction(()=>document.querySelector('#orderAction').disabled);
    await b.getByRole('button',{name:'工場の改善を選ぶ',exact:true}).waitFor({timeout:30000});
    const other=(await read(b)).state;await b.close();await a.bringToFront();await life(a,'pageshow');
    const choice=a.getByRole('button',{name:'工場の改善を選ぶ',exact:true});await choice.click();
    assert.deepEqual((await read(a)).state,other);
    assert.ok(await a.getByRole('button',{name:'置き場所を試す',exact:true}).isEnabled());
    console.log(engine+' returned tab obtained the latest paid factory without manual reload or duplicate revenue.');
  }finally{await handoff.close();}
}
module.exports={checkResume};
