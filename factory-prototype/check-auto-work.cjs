const assert=require('node:assert/strict');
async function checkAutoWork(browser,url){
  const M=await import('../docs/forge-preview/model.mjs');
  const engine=browser.browserType().name(),width=engine==='webkit'?390:320,height=width===320?568:844;
  function finish(s){
    let r;do{r=M.advanceToReady(s,200);}while(r.status==='producing');
    assert.equal(M.dispatch(s,r.orderId),null);
  }
  for(const scenario of ['first','inquiry','pair','legacy']){
    const s=M.fresh(),expected=structuredClone(s);
    if(scenario==='first'){M.accept(expected,'first');finish(expected);}
    else if(scenario!=='legacy'){for(let i=0;i<2;i++){M.accept(s,'first');finish(s);}M.accept(s,'bulk');}
    else{M.accept(s,'first');delete s.autoWork;}
    const ctx=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
    try{
      if(scenario!=='first')await ctx.addInitScript(seed=>{
        if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({state:seed,revision:'auto'}));
      },s);
      const page=await ctx.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
      const button=name=>page.getByRole('button',{name,exact:true});
      const read=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
      await page.goto(url);await page.locator('#world[data-artwork="ready"]').waitFor();
      if(scenario==='first'){
        await button('材料費 ¥600 で受注する').click();
        assert.equal(await page.locator('#orderAction').isVisible(),false);
        await page.reload();
        await button('工場の改善を選ぶ').waitFor({timeout:30000});
        const paid=await read();assert.equal(paid.delivered,1);assert.equal(M.frontOrder(paid),null);
        assert.equal(paid.cash,expected.cash);assert.deepEqual(paid.results,expected.results);
        await page.reload();await button('工場の改善を選ぶ').waitFor();
        assert.equal((await read()).cash,paid.cash);
      }else if(scenario!=='legacy'){
        await button('小口6個の条件を見る').waitFor();
        await page.waitForTimeout(350);await page.reload();await button('小口6個の条件を見る').waitFor();
        const paused=await read();assert.equal(paused.clock,s.clock);assert.deepEqual(paused.parts,s.parts);
        await button('小口6個の条件を見る').click();
        if(scenario==='pair'){
          await button('先約14個まで進める').click();
          await page.locator('#inquiryPicker').waitFor();
          assert.equal(M.frontOrder(await read()).done,14);
          await button('6個を引き受ける · 材料費 ¥0').click();
          await page.waitForFunction(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state.delivered===4,{},{timeout:30000});
          const pair=await read();assert.ok(M.validate(pair));assert.equal(M.frontOrder(pair),null);
          assert.deepEqual(pair.results.slice(0,2).map(r=>r.offerId).sort(),['bulk','relief']);
          assert.ok(pair.results[0].pair&&pair.results[1].pair);
          assert.deepEqual(errors,[]);console.log(engine+' work mode paired dispatch passed.');continue;
        }
        await button('今回は見送る').click();await button('管理').click();await button('工場へ戻る').click();
        await page.locator('#controls summary').click();await button('出荷まで早送り').click();
        await page.waitForFunction(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state.delivered===3);
        const paid=await read();assert.equal(paid.results[0].offerId,'bulk');assert.ok(paid.results[0].declinedExtra);
        assert.equal(paid.orders.length,1);assert.ok(M.validate(paid));
        const solo=structuredClone(s);finish(solo);
        assert.equal(paid.results[0].seconds,solo.results[0].seconds,'no extra work advances while deciding');
        assert.equal(paid.results[0].payout,solo.results[0].payout);
      }else{
        await button('完成まで進める').click();await button('出荷する').waitFor();
        const held=await read();assert.equal(held.delivered,0);assert.equal(held.autoWork,false);
        await page.locator('#controls summary').click();await button('おまかせ運転').click();
        await page.waitForFunction(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state.delivered===1);
        assert.equal((await read()).autoWork,true);
      }
      assert.deepEqual(errors,[]);console.log(engine+' work mode '+scenario+' passed.');
    }finally{await ctx.close();}
  }
}
module.exports={checkAutoWork};
