// Exercise the working floor, worker dispatch and receipt using real saved shifts.
const assert=require('node:assert/strict');
const path=require('node:path');
async function checkPrecision(browser,url,route){
  const M=await import('../docs/forge-preview/model.mjs');
  const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
  const {installStarterLathe}=await import('../docs/forge-preview/precision.mjs');
  const {estimateOrder}=await import('../docs/forge-preview/estimate.mjs');
  const s=M.fresh();s.autoWork=false;
  function finish(){
    let q;do{q=M.advanceToReady(s,200);}while(q.status==='producing');M.dispatch(s,q.orderId);
  }
  M.accept(s,'first');finish();
  if(route==='bench'){M.accept(s,'first');finish();installStarterLathe(s,{x:3,y:2});}
  M.setGoal(s,'master');
  const width=route==='entry'?320:390,height=route==='entry'?568:844,engine=browser.browserType().name();
  const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(state=>{
      if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'precision-check',state}));
    },s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    const btn=name=>page.getByRole('button',{name,exact:true});
    const saved=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const capture=name=>page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-shaft-'+name+'.jpg'),quality:90});
    const tile=async(x,y)=>{
      const world=page.locator('#world'),rect=await world.boundingBox();
      await world.tap({position:project(frameWorkshop(rect.width,rect.height,8),x+.5,y+.5)});
    };
    const forecast=page.locator('#shaftForecast'),next=btn('シャフト10本の段取りへ');
    async function acceptAndShip(choice){
      const before=await saved(),q=estimateOrder(before,{precision:choice});
      assert.ok(!q.error);await forecast.filter({hasText:'品質調整 '+q.rework+'/10本'}).waitFor();
      const button=page.locator('#shaftStart'),rect=await button.boundingBox();
      assert.ok(rect.height>=44&&rect.y+rect.height<=height,'confirm is visible without scrolling');
      await button.click();
      const start=await saved(),order=M.frontOrder(start);
      assert.equal(order.offerId,choice.offer);
      assert.equal(order.inspectorId,choice.inspector??undefined);
      assert.equal(order.quote.rework,q.rework);assert.ok(Math.abs(order.quote.seconds-q.seconds)<1e-5);
      assert.ok(Math.abs(before.cash-start.cash-order.cost-order.qualitySpend-order.accounting.wages)<1e-5);
      await page.reload();await btn('完成まで進める').click();await btn('出荷する').click();
      const end=await saved(),r=end.results[0];assert.ok(M.validate(end));
      assert.equal(r.rework,q.rework);assert.ok(Math.abs(r.seconds-r.quote.seconds)<1e-5);
      assert.ok(Math.abs(M.resultProfit(r)-r.qualitySpend-q.net)<1e-5);
      return r;
    }
    await page.goto(url,{waitUntil:'load'});await next.click();
    if(route==='entry'){
      await btn('旋盤の置き場所を試す').click();await tile(3,2);
      await page.locator('#layoutEstimate').filter({hasText:/標準10本.*品質調整/}).waitFor();
      await btn('取消').click();let st=await saved();assert.equal(st.cash,s.cash);assert.deepEqual(st.machines,s.machines);
      await btn('旋盤の置き場所を試す').click();await tile(2,1);assert.equal(await page.locator('#confirmPlace').isEnabled(),false);
      await tile(3,2);await btn('旋盤を設置 · ¥5,800').click();
      st=await saved();assert.equal(M.frontOrder(st),null);assert.equal(st.cash,s.cash-5800);
      await acceptAndShip({offer:'fine'});await next.click();
      await page.locator('#shaftOffer').selectOption('master');await forecast.filter({hasText:/技能3/}).waitFor();
      assert.equal(await page.locator('#shaftStart').isEnabled(),false);
    }
    const spec={offer:route==='entry'?'master':'fine',inspector:1,investment:route==='entry'?'train':'bench'};
    await page.locator('#shaftInspector').selectOption('1');
    await page.locator('#shaftInvestment').selectOption(spec.investment);
    await forecast.filter({hasText:/品質調整 0\/10本/}).waitFor();await capture('plan');
    const r=await acceptAndShip(spec);
    assert.equal(r.qualitySpend,route==='entry'?2400:1500);
    if(route==='entry'){
      await page.locator('#orderTitle').filter({hasText:'精密の町工場'}).waitFor();
      assert.match(await page.locator('#orderHint').innerText(),/検品 森.*品質調整0本/);
      await capture('ending');await page.reload();
      await page.locator('#orderTitle').filter({hasText:'精密の町工場'}).waitFor();
      await btn('量産の仕事を見る').click();await page.locator('#termPicker').waitFor();
      assert.equal(M.frontOrder(await saved()),null);await btn('工場へ戻る').click();
    }
    await btn('管理').click();await btn('経営と出荷記録').click();
    if(route==='entry')await page.locator('.shop-sign').first().filter({hasText:'精密の町工場'}).waitFor();
    await btn('直近の出荷結果を開く').click();
    if(route==='entry')assert.match(await page.locator('.receipt .shop-sign').innerText(),/最初のエンディング/);
    assert.equal(await page.locator('.result-profit strong').textContent(),'+¥'+Math.round(M.resultProfit(r)-r.qualitySpend).toLocaleString('ja-JP'));
    assert.match(await page.locator('#sheetBody').innerText(),/検品 森 · 品質調整 0\/10本（見積 0本）/);
    if(r.growth.length)assert.match(await page.locator('#sheetBody').innerText(),/実務で成長/);
    await capture('receipt');assert.deepEqual(errors,[]);
    console.log(engine+' shaft '+route+' passed: named inspection, preparation and material charges, reload, work and measured receipt.');
  }finally{await context.close();}
}
module.exports={checkPrecision};
