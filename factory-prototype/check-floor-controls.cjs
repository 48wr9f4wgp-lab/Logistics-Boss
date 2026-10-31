// Mobile input regression coverage. Every action runs against an isolated normal save.
const assert=require('node:assert/strict');
const path=require('node:path');

async function touchPinch(page,context){
  const canvas=page.locator('#world'),r=await canvas.boundingBox(),client=await context.newCDPSession(page);
  const x=Math.round(r.x+r.width/2),y=Math.round(r.y+r.height/2);
  const touch=(id,offset)=>({id,x:x+offset,y,radiusX:4,radiusY:4,force:.6});
  const dispatch=(type,touchPoints)=>client.send('Input.dispatchTouchEvent',{type,touchPoints});
  try{
    await dispatch('touchStart',[touch(1,-40)]);
    await dispatch('touchStart',[touch(1,-40),touch(2,40)]);
    await dispatch('touchMove',[touch(1,-50),touch(2,50)]);
    await dispatch('touchMove',[touch(1,-60),touch(2,60)]);
    await dispatch('touchEnd',[]);
  }finally{await client.detach();}
}

async function checkFloorControls(browser,url){
  const M=await import('../docs/forge-preview/model.mjs'),s=M.fresh(),engine=browser.browserType().name();
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  try{
    await context.addInitScript(state=>localStorage.setItem('forge.factory.v1',JSON.stringify({revision:'edit-floor',state})),s);
    const page=await context.newPage(),errors=[];
    page.on('pageerror',e=>errors.push(e.message));
    await page.goto(url,{waitUntil:'load'});
    const world=page.locator('#world'),btn=name=>page.getByRole('button',{name,exact:true});
    await page.locator('#world[data-artwork="ready"]').waitFor();
    const saved=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('forge.factory.v1')).state);
    const tile=async(x,y)=>{
      const hit=await world.evaluate((c,{x,y})=>{
        const {width:w,height:h}=c.getBoundingClientRect(),u=Math.min(w/16.45,(h-62)/10.7);
        return {x:w*.5-u+.22*u+(x-y)*u,y:h*.5-14*u*.21+(x+y+1)*u*.5};
      },{x,y});
      await world.tap({position:hit});
    };
    const reset=async()=>{
      await page.locator('#controls summary').tap();await btn('全景').tap();await page.locator('#controls summary').tap();
    };
    await btn('管理').tap();await btn('設備と配置').tap();
    await btn('前の画面へ戻る').tap();
    await btn('設備と配置').waitFor();await btn('設備と配置').tap();
    await page.locator('[data-move="m1"]').tap();
    const confirm=page.locator('#confirmPlace');
    assert.equal(await confirm.isEnabled(),false);
    if(engine==='chromium'){
      const initial=await world.evaluate(c=>c.toDataURL());
      await touchPinch(page,context);
      await page.waitForFunction(ref=>document.querySelector('#world').toDataURL()!==ref,initial);
      assert.equal(await confirm.isEnabled(),false,'a pinch must not stage a tile');
      assert.deepEqual((await saved()).machines,s.machines);
      await btn('取消').tap();await reset();
      await btn('管理').tap();await btn('設備と配置').tap();await page.locator('[data-move="m1"]').tap();
    }
    await tile(3,1);
    assert.ok(await confirm.isEnabled());assert.deepEqual((await saved()).machines,s.machines);
    await tile(5,1);assert.equal(await confirm.isEnabled(),false,'occupied cell disarms the previous destination');
    await tile(4,2);
    await page.screenshot({path:path.join(process.env.RUNNER_TEMP||'.','factory-floor-screens',engine+'-390-placement.jpg'),quality:91});
    await btn('ここに移動').tap();
    let state=await saved(),machine=state.machines.find(m=>m.id==='m1');
    assert.deepEqual([machine.x,machine.y],[4,2]);assert.equal(state.cash,s.cash);
    await reset();
    const buy=async()=>{
      await btn('管理').tap();await btn('設備と配置').tap();await page.locator('[data-buy="cut"]').tap();
    };
    await buy();await tile(3,1);assert.ok(await confirm.isEnabled());
    assert.equal((await saved()).cash,s.cash);
    await btn('取消').tap();
    assert.equal((await saved()).machines.length,s.machines.length);
    await buy();await tile(3,1);await confirm.tap();
    state=await saved();assert.equal(state.cash,s.cash-M.MACHINES.cut.cost);
    assert.equal(state.machines.filter(m=>m.x===3&&m.y===1&&m.kind==='cut').length,1);
    assert.deepEqual(errors,[]);
    console.log(engine+' passed: management back, staged move, invalid tile, cancel and single-charge purchase'+(engine==='chromium'?', native pinch without placement':'')+'.');
  }finally{await context.close();}
}
module.exports={checkFloorControls};
