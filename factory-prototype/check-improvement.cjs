// Exercise the confirmed purchase/placement through the actual mobile UI.
// Seed a genuine first receipt once. Reload then reads the application's own save.
const assert=require('node:assert/strict');
const path=require('node:path');

async function checkImprovement(browser,url,choice){
  const M=await import('../docs/forge-preview/model.mjs');
  const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
  const {comparisonLine}=await import('../docs/forge-preview/improvement.mjs');
  const s=M.fresh();M.accept(s,'first');
  let ready;
  do{ready=M.advanceToReady(s,200);}while(ready.status==='producing');
  M.dispatch(s,ready.orderId);
  const engine=browser.browserType().name(),width=choice==='upgrade'?320:390,height=width===320?568:844;
  const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(state=>{
      if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'first-comparison',state}));
    },s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',error=>errors.push(error.message));
    const saved=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const button=name=>page.getByRole('button',{name,exact:true});
    const screen=name=>page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-improve-'+name+'.jpg'),quality:89});
    await page.goto(url,{waitUntil:'load'});
    await page.locator('#world[data-artwork="ready"]').waitFor();
    const choose=button('工場の改善を選ぶ');
    await choose.click();
    const drillButton=await page.locator('#trialUpgrade').boundingBox(),moveButton=await page.locator('#trialMove').boundingBox();
    assert.ok(moveButton&&drillButton&&moveButton.height>=44&&drillButton.height>=44);
    assert.ok(drillButton.y+drillButton.height<=height,'both choices must fit on the initial phone screen');
    await screen('choices');
    await button('置き場所を試す').click();
    assert.match(await page.locator('#placeStatus').innerText(),/3 → 1マス/);
    await button('取消').click();
    assert.equal((await saved()).cash,s.cash);
    assert.deepEqual((await saved()).machines,s.machines);
    if(choice==='move'){
      await button('置き場所を試す').click();
      const world=page.locator('#world'),rect=await world.boundingBox();
      const v=frameWorkshop(rect.width,rect.height,s.width);
      await world.tap({position:project(v,2.5,1.5)});
      assert.equal(await page.locator('#confirmPlace').isEnabled(),false);
      await world.tap({position:project(v,3.5,1.5)});
      await screen('route');
      await button('移動して受注 · ¥600').click();
    }else{
      await button('改良して受注 · ¥2,100').click();
    }
    let state=await saved(),order=M.frontOrder(state);
    assert.ok(M.validate(state));
    assert.equal(order.offerId,'first');
    assert.equal(order.repeatCost,choice==='move'?0:1500);
    assert.ok(Math.abs(s.cash-state.cash-600-order.repeatCost-order.accounting.wages)<0.00001);
    const drill=state.machines.find(m=>m.id==='m2');
    assert.deepEqual([drill.x,drill.level],choice==='move'?[3,1]:[5,2]);
    await page.reload();await button('完成まで進める').click();await button('出荷する').click();
    const next=button(choice==='move'?'次の成長目標を選ぶ':'短納期の注文を見る');
    await next.waitFor();state=await saved();
    assert.equal(state.delivered,2);assert.equal(state.results[0].repeatCost,order.repeatCost);
    const comparison=comparisonLine(state,state.results[0]);
    assert.match(comparison,/短縮.*移動.*減/);
    assert.equal(await page.locator('#orderComparison').textContent(),comparison);
    await screen('result');
    await page.reload();await next.waitFor();
    assert.equal(await page.locator('#orderComparison').textContent(),comparison);
    if(choice==='upgrade'){
      await next.click();await button('受注して生産開始 · 材料 ¥1,800').waitFor();
      await button('工場へ戻る').click();await button('管理').click();await button('経営と出荷記録').click();
      await button('直近の出荷結果を開く').click();assert.match(await page.locator('.result-profit').innerText(),/改良費 ¥1,500 を引くと \+¥/);
    }
    if(choice==='move'){
      await button('管理').click();await button('注文一覧').click();
      await button('前回の12個で改善を試す').click();
      assert.match(await page.locator('.trial-baseline').innerText(),new RegExp('前回 '+state.results[0].seconds.toFixed(1)+'秒'));
    }
    assert.deepEqual(errors,[]);
    console.log(engine+' repeat '+choice+' passed: cancel without charge, actual repeat costs, reload, skip, receipt and next contract.');
  }finally{await context.close();}
}
module.exports={checkImprovement};
