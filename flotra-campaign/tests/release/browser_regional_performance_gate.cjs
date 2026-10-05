'use strict';
// Compare the exact candidate with PR152 in one runner/browser. A failed
// control marks the gate unavailable, never passes the candidate by waiver.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const [candidateURL,controlURL,output,fixtures,headSHA,controlSHA]=process.argv.slice(2);
assert.ok(candidateURL&&controlURL&&output&&fixtures&&headSHA&&controlSHA,'Usage: candidateURL controlURL output fixtures headSHA controlSHA');
fs.mkdirSync(output,{recursive:true});
const repository=path.resolve(__dirname,'../../..');
const manifest=JSON.parse(fs.readFileSync(path.join(repository,'REGIONAL_HALL_ARTIFACTS.json'),'utf8'));
assert.equal(controlSHA,manifest.base,'Control commit is the frozen public baseline');
for(const [file,expected] of Object.entries(manifest.production_sources)){
 const bytes=fs.readFileSync(path.join(repository,'flotra-campaign',file));
 assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),expected,'Frozen production source: '+file);
}
assert.deepEqual(fs.readFileSync(path.join(repository,'flotra-campaign/campaign-storage.js')),fs.readFileSync(path.join(repository,'docs/godot-jobs-preview/campaign-storage.js')),'Exported storage bridge matches source');

const report={kind:'Exact-head/pinned-PR152 Chromium software-renderer comparison; CSS375x567/DPR3/t180; not physical-device FPS',headSHA,controlSHA,limits:{cpuP95:100,drawCalls:250,medianRatio:1.75,p95Ratio:2,medianFloor:75,p95Floor:120,stableNodes:4},cases:[]};
const percentile=(a,q)=>{a.sort((x,y)=>x-y);return a[Math.min(a.length-1,Math.floor(a.length*q))]};
async function ui(page){return page.evaluate(()=>window.FlotraViewport.uiMetrics)}
async function tap(page,context,name){await page.waitForFunction(n=>window.FlotraViewport?.uiMetrics?.buttons.some(b=>b.name===n&&b.visible&&!b.disabled),name);const b=(await ui(page)).buttons.find(b=>b.name===name&&b.visible),cdp=await context.newCDPSession(page);await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{id:0,x:b.x+b.width/2,y:b.y+b.height/2}]});await page.waitForTimeout(90);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await cdp.detach();await page.waitForTimeout(350)}
async function sample(page,ms,guard=null){
 const x=await page.evaluate(({ms,guard})=>new Promise(resolve=>{
  const frames=[],cpu=[],draw=[],nodes=[];let last=performance.now(),start=last,badState=false;
  function frame(now){
   frames.push(now-last);last=now;const state=window.FlotraViewport.uiMetrics,m=state.performance;
   cpu.push(m.processMs);draw.push(m.drawCalls);nodes.push(m.nodes);
   if(guard&&(state.worldVisible!==true||state.trialRunning!==true||state.status!=='running'||state.currentContract!==guard.contract||state.progress.total!==guard.total||state.progress.shipped>=guard.total||(guard.hall&&(state.hall?.owned!==true||state.hall.plan!==guard.hall))))badState=true;
   if(now-start<ms)requestAnimationFrame(frame);else resolve({frames:frames.slice(5),cpu:cpu.slice(5),draw:draw.slice(5),nodes:nodes.slice(5),badState});
  }requestAnimationFrame(frame);
 }),{ms,guard});
 assert.equal(x.badState,false,'Active samples retain visible running work and expected cargo/hall');
 for(const name of ['frames','cpu','draw','nodes'])assert.ok(x[name].length>=10&&x[name].every(Number.isFinite),'Finite nonempty samples: '+name);
 return {frameP50:percentile(x.frames,.5),frameP95:percentile(x.frames,.95),cpuP50:percentile(x.cpu,.5),cpuP95:percentile(x.cpu,.95),drawMax:Math.max(...x.draw),nodeMin:Math.min(...x.nodes),nodeMax:Math.max(...x.nodes),samples:x.frames.length};
}

(async()=>{const browser=await chromium.launch({executablePath:process.env.FLOTRA_CHROMIUM||process.env.CHROMIUM_EXECUTABLE||undefined,headless:true});try{
report.browser=browser.version();
for(const item of [{id:'control-pr152-288',url:controlURL,fixture:'active-v3.json'},{id:'candidate-288',url:candidateURL,fixture:'active-v3.json'},{id:'candidate-storage480',url:candidateURL,fixture:'hall-storage-v4.json'},{id:'candidate-express480',url:candidateURL,fixture:'hall-express-v4.json'}]){
 const fixture=JSON.parse(fs.readFileSync(path.join(fixtures,item.fixture),'utf8'));
 const guard={contract:fixture.hall.owned?'route_regional':'route_hub',total:fixture.offered,hall:fixture.hall.owned?fixture.hall.plan:null};
 const context=await browser.newContext({viewport:{width:375,height:567},deviceScaleFactor:3,isMobile:true,hasTouch:true});
 await context.addInitScript(text=>{if(localStorage.getItem('flotra.campaign.release.v1')===null)localStorage.setItem('flotra.campaign.release.v1',text)},fixture.encoded);
 const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const target=new URL(item.url);target.searchParams.set('phone_qa','1');console.log('BEGIN',item.id);
 await page.goto(target.href,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.FlotraViewport?.uiMetrics?.sheet==='entry',null,{timeout:120000});await tap(page,context,'StartTrial');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.sheet==='');await page.waitForTimeout(1000);
 const initial=await ui(page);assert.equal(initial.simTime,fixture.time);assert.equal(initial.wallet,fixture.wallet);assert.equal(initial.progress.shipped,fixture.shipped);assert.equal(initial.trialRunning,false);assert.equal(initial.worldVisible,true);assert.equal(initial.status,'running');assert.equal(initial.currentContract,guard.contract);assert.equal(initial.progress.total,guard.total);if(guard.hall){assert.equal(initial.hall.owned,true);assert.equal(initial.hall.plan,guard.hall);}
 const environment=await page.evaluate(()=>{const gl=document.querySelector('#canvas').getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return {userAgent:navigator.userAgent,width:innerWidth,height:innerHeight,dpr:devicePixelRatio,visibility:document.visibilityState,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):null}});
 const pckHash=await page.evaluate(async()=>{const bytes=await(await fetch('index.pck',{cache:'no-store'})).arrayBuffer();return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('')});
 assert.equal(pckHash,item.id.startsWith('control-')?manifest.public_control_pck_sha256:manifest.candidate_pck_sha256,'Served PCK matches frozen '+item.id);
 const idle=await sample(page,6000);await page.screenshot({path:path.join(output,item.id+'-paused.png')});
 await tap(page,context,'SessionRecord');await page.waitForFunction(()=>!window.FlotraViewport.uiMetrics.worldVisible);await page.waitForTimeout(800);const uiOnly=await sample(page,6000);
 await tap(page,context,'CloseSheet');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.sheet===''&&window.FlotraViewport.uiMetrics.worldVisible===true);await tap(page,context,'PauseResume');await page.waitForFunction(()=>window.FlotraViewport.uiMetrics.trialRunning);await page.waitForTimeout(1000);const active=await sample(page,12000,guard);const activeEnd=await ui(page);assert.equal(activeEnd.worldVisible,true);assert.equal(activeEnd.trialRunning,true);assert.equal(activeEnd.status,'running');
 await tap(page,context,'PauseResume');await page.waitForFunction(()=>!window.FlotraViewport.uiMetrics.trialRunning);await page.waitForTimeout(500);const idleAfter=await sample(page,6000),last=await ui(page);
 const limits={cpuP95:100,draws:250,median:Math.max(75,uiOnly.frameP50*1.75),p95:Math.max(120,uiOnly.frameP95*2),stableNodes:4};
 const checks={cpu:active.cpuP95<100,draws:active.drawMax<=250,median:active.frameP50<=limits.median,p95:active.frameP95<=limits.p95,stableNodes:idleAfter.nodeMax-idleAfter.nodeMin<=4,realProgress:last.simTime>initial.simTime,worldVisible:last.worldVisible===true,unfinished:last.status==='running'&&last.progress.shipped<guard.total,console:errors.length===0};
 const row={id:item.id,pckHash,fixtureHash:crypto.createHash('sha256').update(fixture.encoded).digest('hex'),environment,idle,uiOnly,active,idleAfter,limits,checks,pass:Object.values(checks).every(Boolean),initial:{time:initial.simTime,wallet:initial.wallet,progress:initial.progress},final:{time:last.simTime,progress:last.progress},errors};report.cases.push(row);console.log('RESULT',JSON.stringify(row));fs.writeFileSync(path.join(output,'renderer-gate.json'),JSON.stringify(report,null,2));await context.close();
}
report.controlHealthy=report.cases[0].pass;report.candidatePass=report.cases.slice(1).every(x=>x.pass);report.decision=!report.controlHealthy?'environment-control-failed: approval unavailable':(report.candidatePass?'passed':'candidate-failed');
fs.writeFileSync(path.join(output,'renderer-gate.json'),JSON.stringify(report,null,2));console.log('DECISION',report.decision);if(!report.controlHealthy||!report.candidatePass)process.exitCode=1;
}finally{await browser.close()}})().catch(error=>{report.failure=String(error);fs.writeFileSync(path.join(output,'renderer-gate.json'),JSON.stringify(report,null,2));console.error(error);process.exitCode=1});
