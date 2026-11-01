// Each run begins just after a real first shipment. Compare the promised target
// in the editor with the normal workforce, saved shipment and actual cash.
const assert=require('node:assert/strict');
const path=require('node:path');

async function checkBrief(browser,url){
  const M=await import('../docs/forge-preview/model.mjs');
  const {estimateOrder}=await import('../docs/forge-preview/estimate.mjs');
  const s=M.fresh();M.accept(s,'first');
  let ready;do{ready=M.advanceToReady(s,200);}while(ready.status==='producing');
  M.dispatch(s,ready.orderId);
  const engine=browser.browserType().name(),width=engine==='webkit'?390:320,height=width===320?568:844;
  for(const met of [true,false]){
    const id=(engine==='chromium')===met?'speed':'walk',speed=id==='speed';
    const label=speed?'早仕上げ':'省運搬',limit=speed?'108.0秒':'225マス';
    const value=speed?(met?'106.6秒':'117.4秒'):(met?'220マス':'312マス');
    const reward=met?400:0,base=M.OFFERS.find(o=>o.id==='first').pay;
    const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
    try{
      await context.addInitScript(state=>{
        if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'brief-seed',state}));
      },s);
      const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
      const button=name=>page.getByRole('button',{name,exact:true});
      const read=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
      const picker=page.locator('#layoutBrief'),forecast=page.locator('#layoutBriefForecast'),confirm=page.locator('#confirmPlace');
      const world=page.locator('#world'),open=()=>button('置き場所を試す').click();
      const screenshot=phase=>page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-brief-'+id+'-'+phase+'.jpg'),quality:90});
      await page.goto(url);await page.locator('#world[data-artwork="ready"]').waitFor();
      await button('工場の改善を選ぶ').click();
      const offline=engine==='chromium'&&!met;
      const worker=offline?await page.evaluateHandle(()=>window.Worker):null;
      if(offline)await page.evaluate(()=>{window.Worker=undefined;});
      await open();
      assert.equal(await picker.inputValue(),'');assert.equal(await confirm.isEnabled(),false);
      await picker.selectOption(id);
      if(offline){
        await forecast.filter({hasText:'出荷時に判定'}).waitFor();
        assert.equal(await confirm.isEnabled(),true,'an unavailable estimator must not block accepting');
      }
      await button('取消').click();
      if(worker){await page.evaluate(native=>{window.Worker=native;},worker);await worker.dispose();}

      const discarded=await read();assert.equal(discarded.cash,s.cash);assert.deepEqual(discarded.machines,s.machines);
      assert.equal(M.frontOrder(discarded),null);
      await open();assert.equal(await picker.inputValue(),'');
      const originalHeight=(await world.boundingBox()).height;
      if(met){
        await page.locator('#layoutMachine').selectOption({label:'検品台'});
        const fastest=page.locator('#layoutSuggestions button').filter({hasText:'完成が最短'});
        const shortest=page.locator('#layoutSuggestions button').filter({hasText:'歩数が最少'});
        await fastest.click();await picker.selectOption('speed');
        await forecast.filter({hasText:/達成見込.*106.6秒/}).waitFor();
        await picker.selectOption('walk');await forecast.filter({hasText:/未達見込.*232マス/}).waitFor();
        // Check the immediate state in the same event turn, before a worker
        // can deliver the new quote. Old shortfall cannot describe this floor.
        const interim=await shortest.evaluate(b=>{
          b.click();return document.querySelector('#layoutBriefForecast').textContent;
        });
        assert.doesNotMatch(interim,/未達見込.*232マス/);
        await forecast.filter({hasText:/達成見込.*220マス/}).waitFor();
        await picker.selectOption('speed');await forecast.filter({hasText:/未達見込.*110.0秒/}).waitFor();
        await picker.selectOption(id);if(speed)await fastest.click();
      }else{
        // Selecting a brief alone is enough to accept the unchanged factory.
        await picker.selectOption(id);
        assert.equal(await confirm.isEnabled(),true);
      }
      const prediction=forecast.filter({hasText:value});await prediction.waitFor();
      assert.match(await prediction.innerText(),met?/達成見込/:/未達見込/);
      assert.ok(Math.abs((await world.boundingBox()).height-originalHeight)<=1,'the floor must stay still after selecting a brief and obtaining a quote');
      const hit=await confirm.boundingBox();assert.ok(hit.y>=0&&hit.y+hit.height<=height+.5);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
      await screenshot('forecast');await confirm.click();
      const accepted=await read(),order=M.frontOrder(accepted);
      assert.equal(order.briefId,id);assert.equal(order.repeatCost,0);
      assert.ok(Math.abs(accepted.cash-(s.cash-600-order.accounting.wages))<1e-5);
      await page.reload();await page.locator('#orderHint').filter({hasText:label}).waitFor();
      await button('完成まで進める').click();await button('出荷する').waitFor();
      const before=await read();assert.equal(M.frontOrder(before).done,12);
      await button('出荷する').click();
      const paid=await read(),receipt=paid.results[0];
      assert.ok(M.validate(paid));assert.equal(receipt.briefId,id);assert.equal(receipt.briefBonus,reward);
      assert.equal(receipt.payout,base+reward);assert.equal(receipt.late,false);
      assert.ok(Math.abs(paid.cash-before.cash-receipt.payout)<1e-5);
      assert.ok(Math.abs(paid.revenue-before.revenue-receipt.payout)<1e-5);
      assert.equal(speed?receipt.seconds.toFixed(1)+'秒':Math.round(receipt.walk)+'マス',value);
      const comparison=page.locator('#orderComparison');
      await comparison.filter({hasText:value}).waitFor();await screenshot('result');
      await page.reload();await comparison.filter({hasText:value}).waitFor();
      const outcome=await comparison.innerText();assert.ok(outcome.includes(label)&&outcome.includes(limit));
      assert.match(outcome,met?/達成.*¥400/:/未達.*あと/);
      const restored=await read();assert.equal(restored.delivered,2);assert.equal(restored.cash,paid.cash);assert.equal(restored.revenue,paid.revenue);
      await button('管理').click();await button('経営と出荷記録').click();
      const entry=page.locator('.result-history').first();await entry.locator('summary').click();
      await entry.locator('.brief-receipt').filter({hasText:value}).waitFor();
      await button('直近の出荷結果を開く').click();
      await page.locator('.receipt .brief-receipt').filter({hasText:value}).waitFor();
      await button('工場へ戻る').click();
      if(!met){
        await button('配置を変えて再挑戦').click();
        assert.equal(await picker.inputValue(),id);
      }else{
        const nextId=speed?'walk':'speed',nextLabel=speed?'省運搬':'早仕上げ';
        assert.equal(M.offerStatus(restored,'rush').qualified,false,'one brief alone cannot qualify for a referral');
        await button(nextLabel+'に挑む').click();assert.equal(await picker.inputValue(),nextId);
        await page.locator('#layoutMachine').selectOption({label:'ボール盤'});
        const currentDrill=restored.machines.find(m=>m.kind==='drill');
        const rank=estimateOrder(restored,{rankLayout:{id:currentDrill.id,offer:'first'}});
        const best=nextId==='speed'?rank.fastest:rank.shortest;
        // Workers have moved and gained skills. Use this fresh quote and its
        // matching floor button rather than repeating the first order's plan.
        await page.locator('#layoutSuggestions button[data-x="'+best.x+'"][data-y="'+best.y+'"]').click();
        const nextValue=nextId==='walk'?Math.round(best.quote.walk)+'マス':best.quote.seconds.toFixed(1)+'秒';
        await forecast.filter({hasText:nextValue}).waitFor();
        assert.match(await forecast.innerText(),/^達成見込/);
        await confirm.click();assert.equal(M.frontOrder(await read()).briefId,nextId);
        await button('完成まで進める').click();await button('出荷する').click();
        await button('紹介された28個の見積へ').waitFor();
        assert.match(await page.locator('#orderTitle').innerText(),/金物店の紹介/);
        const third=await read();assert.equal(third.results[0].briefId,nextId);assert.equal(third.results[0].briefBonus,400);
        assert.ok(Math.abs(third.results[0].seconds-best.quote.seconds)<1e-5&&Math.abs(third.results[0].walk-best.quote.walk)<1e-5);
        assert.ok(third.machines.every(m=>m.level===1));assert.ok(M.offerStatus(third,'rush').qualified);
        await screenshot('referral');await page.reload();
        await button('紹介された28個の見積へ').click();
        const rush=page.locator('#termPicker input[value="rush"]');
        assert.equal(await rush.isEnabled(),true);await rush.check();
        await page.locator('[data-estimate="rush"]').filter({hasText:'利益'}).waitFor();
        await page.locator('#acceptTerm').click();
        const rushOrder=M.frontOrder(await read());assert.equal(rushOrder.offerId,'rush');assert.equal(rushOrder.qty,28);
      }
      assert.deepEqual(errors,[]);
      console.log(engine+' repeat brief '+id+' '+(met?'met':'missed')+': preview, reload, actual payout, persistent receipt'+(met?', second brief and referral rush at Lv.1':', retained retry')+'.');
    }finally{await context.close();}
  }
}
module.exports={checkBrief};
