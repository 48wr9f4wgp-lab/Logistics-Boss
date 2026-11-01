// A saved factory after the paid v0.18 repeat, before its first 28-piece job.
const assert=require('node:assert/strict');
const path=require('node:path');

async function checkEstimates(browser,url,term){
  const M=await import('../docs/forge-preview/model.mjs');
  const {estimateOrder}=await import('../docs/forge-preview/estimate.mjs');
  const {startRepeat}=await import('../docs/forge-preview/improvement.mjs');
  const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
  const s=M.fresh();
  function finish(){
    let r;do{r=M.advanceToReady(s,200);}while(r.status==='producing');M.dispatch(s,r.orderId);
  }
  M.accept(s,'first');finish();startRepeat(s,'upgrade');finish();
  const width=term==='bulk'?320:390,height=width===320?568:844;
  const engine=browser.browserType().name();
  const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(seed=>{
      if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'terms',state:seed}));
    },s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    const btn=name=>page.getByRole('button',{name,exact:true});
    const read=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const screen=k=>page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-estimate-'+k+'.jpg'),quality:90});
    await page.goto(url,{waitUntil:'load'});await btn('短納期の注文を見る').click();
    const picker=page.locator('#termPicker'),rush=picker.locator('[data-estimate="rush"]');
    await rush.filter({hasText:/超過/}).waitFor();
    assert.match(await picker.locator('[data-estimate="bulk"]').innerText(),/利益 ¥4,457/);
    assert.match(await rush.innerText(),/利益 ¥4,177/);
    await picker.locator('input[value="'+term+'"]').check();
    await picker.scrollIntoViewIfNeeded();await screen('terms');
    const openLayout=async()=>{
      await page.locator('.term-layout summary').click();
      await page.locator('#estimateMachine').selectOption('m3');await btn('床で配置を試す').click();
    };
    const tile=async(x,y)=>{
      const canvas=page.locator('#world'),rect=await canvas.boundingBox();
      await canvas.tap({position:project(frameWorkshop(rect.width,rect.height,8),x+.5,y+.5)});
    };
    await openLayout();await tile(4,1);await tile(1,1);
    const preview=page.locator('#layoutEstimate');
    await preview.filter({hasText:/196\.8秒/}).waitFor();
    assert.match(await preview.innerText(),term==='rush'?/短納期28個/:/通常便28個/);
    await screen('preview');
    await tile(2,1);assert.equal(await preview.isVisible(),false);
    assert.equal(await page.locator('#confirmPlace').isEnabled(),false);
    await btn('取消').click();
    assert.equal(await picker.locator('input:checked').inputValue(),term);
    let state=await read();assert.deepEqual(state.machines,s.machines);assert.equal(state.cash,s.cash);
    if(term==='rush'){
      await openLayout();await tile(1,1);await preview.filter({hasText:/196\.8秒/}).waitFor();
      await btn('移動して見積に戻る').click();
      await rush.filter({hasText:/余裕/}).waitFor();assert.match(await rush.innerText(),/利益 ¥5,262/);
      state=await read();assert.equal(state.cash,s.cash);assert.equal(M.frontOrder(state),null);
    }else await rush.filter({hasText:/超過/}).waitFor();
    const expected=estimateOrder(state,{offer:term});
    await page.locator('#acceptTerm').click();
    const live=M.frontOrder(await read());assert.equal(live.offerId,term);
    assert.ok(Math.abs(live.quote.seconds-expected.seconds)<0.00001);
    await page.reload();await btn('完成まで進める').click();await btn('出荷する').click();
    state=await read();const receipt=state.results[0];
    assert.equal(receipt.offerId,term);assert.ok(Math.abs(receipt.seconds-receipt.quote.seconds)<0.00001);
    assert.ok(Math.abs(M.resultProfit(receipt)-receipt.quote.profit)<0.00001);
    await btn('管理').click();await btn('経営と出荷記録').click();await btn('直近の出荷結果を開く').click();
    assert.match(await page.locator('#sheetBody').innerText(),/受注時の見積.*秒[\s\S]*今回の実績/);
    assert.deepEqual(errors,[]);
    console.log(engine+' '+term+' estimate passed: both terms, candidate changes, cancel, actual quote and restored receipt.');
  }finally{await context.close();}
}
module.exports={checkEstimates};
