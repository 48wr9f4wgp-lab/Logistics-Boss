// Both production routes reach the same optional inquiry on the real mobile floor.
const assert=require('node:assert/strict');
const path=require('node:path');
async function checkInquiry(browser,url,flow){
  const M=await import('../docs/forge-preview/model.mjs');
  const {startRepeat}=await import('../docs/forge-preview/improvement.mjs');
  const {acceptPrecision}=await import('../docs/forge-preview/precision.mjs');
  const {pairResult}=await import('../docs/forge-preview/pairing.mjs');
  const s=M.fresh();
  function finish(){
    let q;do{q=M.advanceToReady(s,200);}while(q.status==='producing');M.dispatch(s,q.orderId);
  }
  M.accept(s,'first');finish();
  if(flow==='switch'){
    M.purchase(s,'lathe',3,2);acceptPrecision(s,{offer:'fine'});finish();
    acceptPrecision(s,{offer:'master',inspector:1,investment:'train'});
  }else{
    startRepeat(s,'upgrade');finish();M.move(s,'m3',1,1);M.accept(s,'rush');
  }
  const width=flow==='hold'?320:390,height=width===320?568:844,engine=browser.browserType().name();
  const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(seed=>{
      if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'inquiry',state:seed}));
    },s);
    if(flow==='offline')await context.addInitScript(()=>{window.Worker=undefined;});
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    const read=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const btn=name=>page.getByRole('button',{name,exact:true});
    const capture=name=>page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-inquiry-'+name+'.jpg'),quality:90});
    await page.goto(url,{waitUntil:'load'});await btn('＋6個の相談').click();
    const picker=page.locator('#inquiryPicker');
    const impact=key=>picker.locator('[data-impact="'+key+'"]');
    if(flow==='offline'){
      await impact('primary').filter({hasText:'見積を表示できません'}).waitFor();
      await btn('6個を引き受ける · 材料費 ¥0').click();
      const st=await read();assert.equal(st.orders.at(-1).pair.solo,null);assert.ok(M.validate(st));
      return;
    }
    await impact('primary').filter({hasText:/2件利益/}).waitFor();
    const action=await page.locator('#inquiryConfirm').boundingBox();
    assert.ok(action.height>=44&&action.y+action.height<=height);
    await capture('offer');
    if(flow==='decline'){
      await btn('今回は見送る').click();await page.reload();
      assert.equal(await btn('＋6個の相談').count(),0);
      assert.ok(M.frontOrder(await read()).declinedExtra);
      await btn('完成まで進める').click();await btn('出荷する').click();
      const state=await read();assert.equal(state.results[0].pair,undefined);assert.ok(M.validate(state));
      return;
    }
    if(flow==='hold'){
      await btn('先約14個まで進めて再検討').click();
      await page.locator('.inquiry-desk>p').filter({hasText:/14\/28個完成/}).waitFor();
      const half=await read();assert.equal(half.orders.filter(o=>!o.shipped).length,1);
      assert.ok(half.cash<s.cash);await impact('primary').filter({hasText:/2件利益/}).waitFor();
    }else await picker.locator('input[value="extra"]').check();
    await btn('6個を引き受ける · 材料費 ¥0').click();
    const accepted=await read(),orders=accepted.orders.filter(o=>!o.shipped),base=orders[0].pair.solo;
    assert.equal(orders.length,2);assert.ok(base);assert.ok(M.validate(accepted));
    assert.equal(orders[1].cost,0);
    await page.reload();
    if(flow==='switch'){
      await btn('作業順の見直し').click();
      await picker.locator('input[value="primary"]').check();
      await impact('primary').filter({hasText:/2件利益/}).waitFor();await btn('この優先順で続ける').click();
      const updated=await read();assert.equal(updated.next,accepted.next);assert.equal(updated.orders.at(-1).pair.priority,'primary');
      assert.deepEqual(updated.orders.map(o=>o.start),accepted.orders.map(o=>o.start));assert.deepEqual(updated.orders.at(-1).pair.solo,base);
    }
    await btn('完成まで進める').click();await btn('出荷する').click();
    let state=await read();assert.equal(pairResult(state.results[0]),null);
    await page.reload();
    await btn('完成まで進める').click();await btn('出荷する').click();
    state=await read();assert.ok(M.validate(state));
    const result=pairResult(state.results[0]);assert.ok(result);
    assert.deepEqual(result,pairResult(state.results[1]));
    assert.match(await page.locator('#orderComparison').innerText(),/2件利益.*先約単独比/);
    await capture('result');await page.reload();
    assert.match(await page.locator('#orderComparison').innerText(),/2件利益/);
    await btn('管理').click();await btn('経営と出荷記録').click();await btn('直近の出荷結果を開く').click();
    assert.match(await page.locator('#sheetBody').innerText(),/2件利益.*先約単独比/);
    assert.deepEqual(errors,[]);
    console.log(engine+' '+flow+' paired orders passed: estimate, optional decision, production, reload and both receipts.');
  }finally{await context.close();}
}
module.exports={checkInquiry};
