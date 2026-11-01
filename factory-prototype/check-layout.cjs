// Start with the real first-shipment save. Tap the floor, compare both goals,
// switch equipment, then commit only the three-tool draft the player chose.
const assert=require('node:assert/strict');
const path=require('node:path');
async function checkLayout(browser,url){
  const M=await import('../docs/forge-preview/model.mjs');
  const {estimateOrder}=await import('../docs/forge-preview/estimate.mjs');
  const {frameWorkshop,project}=await import('../docs/forge-preview/view.mjs');
  const s=M.fresh();s.autoWork=false;M.accept(s,'first');
  let ready;do{ready=M.advanceToReady(s,200);}while(ready.status==='producing');M.dispatch(s,ready.orderId);
  const engine=browser.browserType().name(),width=engine==='webkit'?390:320,height=width===320?568:844;
  const context=await browser.newContext({viewport:{width,height},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(state=>{
      if(!localStorage.getItem('forge.factory.v1'))localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'open-floor',state}));
    },s);
    const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
    const floor=page.locator('#world'),quote=page.locator('#layoutEstimate'),status=page.locator('#placeStatus');
    const confirm=page.locator('#confirmPlace'),picker=page.locator('#layoutMachine');
    const saved=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const btn=name=>page.getByRole('button',{name,exact:true});
    const tap=async(x,y)=>{
      const box=await floor.boundingBox();
      await floor.tap({position:project(frameWorkshop(box.width,box.height,s.width),x+.5,y+.5)});
    };
    const open=async()=>{await btn('置き場所を試す').click();await picker.selectOption({label:'検品台'});};
    await page.goto(url);await page.locator('#world[data-artwork="ready"]').waitFor();await btn('工場の改善を選ぶ').click();await open();
    const fast=page.locator('#layoutSuggestions button').filter({hasText:'完成が最短'});
    const walk=page.locator('#layoutSuggestions button').filter({hasText:'歩数が最少'});
    await fast.waitFor();assert.match(await fast.innerText(),/5列2段[\s\S]+106.6秒／232マス/);
    assert.match(await walk.innerText(),/7列2段[\s\S]+110.0秒／220マス/);
    const fits=await fast.evaluate(b=>{
      const box=b.getBoundingClientRect();
      return [...b.querySelectorAll('span,small,strong')].every(n=>{
        const r=n.getBoundingClientRect();return r.x>=box.x&&r.right<=box.right+.5&&r.bottom<=box.bottom;
      });
    });
    assert.ok(fits,'candidate text must stay inside its phone-sized button');
    await fast.tap();await quote.filter({hasText:/106.6秒[\s\S]*検品担当の移動が65マス減/}).waitFor();
    await walk.tap();await quote.filter({hasText:/110.0秒[\s\S]*検品担当の移動が75マス減/}).waitFor();
    assert.equal(await confirm.isEnabled(),true);
    const box=await confirm.boundingBox();assert.ok(box.y>=0&&box.y+box.height<=height);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    await page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-'+width+'-layout-tradeoff.jpg'),quality:92});
    await tap(0,1);assert.match(await status.innerText(),/材料を運ぶ通路/);assert.equal(await confirm.isEnabled(),false);
    await btn('1手戻す').tap();await quote.filter({hasText:/106.6秒/}).waitFor();
    await btn('取消').tap();
    const discarded=await saved();assert.deepEqual(discarded.machines,s.machines);assert.equal(discarded.cash,s.cash);
    await open();await fast.tap();await picker.selectOption({label:'切断機'});await tap(5,1);
    assert.match(await status.innerText(),/ボール盤と入替.*変更3台/);
    const draft=[{id:'m1',x:5,y:1},{id:'m2',x:2,y:1},{id:'m3',x:4,y:1}];
    const expected=estimateOrder(s,{layout:draft,offer:'first',trace:true});
    await quote.filter({hasText:expected.seconds.toFixed(1)+'秒'}).waitFor();await confirm.tap();
    const paid=await saved(),order=M.frontOrder(paid);
    for(const dest of draft){const m=paid.machines.find(m=>m.id===dest.id);assert.deepEqual([m.x,m.y],[dest.x,dest.y]);}
    assert.ok(Math.abs(paid.cash-(s.cash-600-order.accounting.wages))<1e-5);assert.equal(order.repeatCost,0);
    await page.reload();await btn('完成まで進める').click();await btn('出荷する').click();
    const r=(await saved()).results[0];assert.ok(Math.abs(r.seconds-expected.seconds)<1e-6&&Math.abs(r.walk-expected.walk)<1e-6);
    assert.deepEqual(errors,[]);console.log(engine+' ranked layout passed: competing goals, stage reason, undo, swap, cancel, reload, exact shipment.');
  }finally{await context.close();}
}
module.exports={checkLayout};
