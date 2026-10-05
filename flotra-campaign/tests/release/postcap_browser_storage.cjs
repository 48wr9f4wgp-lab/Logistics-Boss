'use strict';
// Real localStorage/Web Locks, fresh isolated Chromium contexts, loopback only.
// The payloads are explicit mock envelopes: strict domain acceptance belongs to
// the Godot suites. This does not claim actual BFCache or game-scene coverage.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const source=fs.readFileSync(process.env.FLOTRA_STORAGE_BRIDGE||path.resolve(__dirname,'../../campaign-storage.js'),'utf8');
const P='flotra.campaign.release.v1',B=P+'.backup',A=P+'.pre-v4',digest='a'.repeat(64);
const env=(n,linked=false)=>JSON.stringify({format:'flotra-campaign',version:1,payload:'mock'+n,sha256:'mock',...(linked?{pre_v4_sha256:digest}:{})});
const old='\n  '+env('old')+' \n';
const migrated={archiveSource:old,validatedArchive:'',archiveDigest:digest};
const continued={validatedArchive:old,archiveDigest:digest};
(async()=>{
 const server=http.createServer((req,res)=>{
  res.setHeader('Content-Type',req.url==='/storage.js'?'application/javascript':'text/html');
  res.end(req.url==='/storage.js'?source:'<!doctype html><meta charset="utf-8"><title>Disposable archive test</title><script src="/storage.js"></script>');
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin='http://127.0.0.1:'+server.address().port;
 let browser,checks=0;
 const verify=(value,label)=>{assert(value,label);checks++;};
 try {
  browser=await chromium.launch({executablePath:process.env.FLOTRA_CHROMIUM||process.env.CHROMIUM_EXECUTABLE||undefined,headless:true,args:['--no-sandbox']});
  async function scenario(seed,run) {
   const context=await browser.newContext();
   try {
    const page=await context.newPage();await page.goto(origin);
    await page.waitForFunction(async()=>{const q=await navigator.locks.query();return q.held.some(l=>l.name==='flotra.campaign.release.v1.writer');});
    await page.evaluate(entries=>{for(const[k,v]of entries)localStorage.setItem(k,v);window.FlotraCampaignStore.read();},seed);
    await run(page,context);
   } finally {await context.close();}
  }
  async function write(page,text,protection={}) {return page.evaluate(({text,protection})=>window.FlotraCampaignStore.write(text,protection),{text,protection});}
  async function snapshot(page) {return page.evaluate(keys=>Object.fromEntries(keys.map(k=>[k,localStorage.getItem(k)])),[P,B,A]);}
  await scenario([[P,old],[B,env('older')]],async(page,context)=>{
   verify((await write(page,env(0,true),migrated)).ok,'first migration saves');
   let slots=await snapshot(page);verify(slots[A]===old&&slots[B]===old,'original exact in both protective slots');
   for(let i=1;i<=30;i++)verify((await write(page,env(i,true),continued)).ok,'autosave '+i);
   verify((await snapshot(page))[A]===old,'30 real autosaves preserve original');
   const loser=await context.newPage();await loser.goto(origin);await loser.evaluate(()=>window.FlotraCampaignStore.read());
   verify((await write(loser,env('loser',true),continued)).reason==='writer_unavailable','other tab cannot write');
   await page.close();
   const reloaded=await context.newPage();await reloaded.goto(origin);
   await reloaded.waitForFunction(async()=>{const q=await navigator.locks.query();return q.held.some(l=>l.name==='flotra.campaign.release.v1.writer');});
   await reloaded.evaluate(()=>window.FlotraCampaignStore.read());
   verify((await write(reloaded,env('reloaded',true),continued)).ok,'new owner resumes with validated archive');
   verify((await snapshot(reloaded))[A]===old,'reload preserves exact immutable archive');
  });
  for(const failing of [A,B,P])await scenario([[P,old],[B,env('older')]],async page=>{
   await page.evaluate(key=>{const original=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k===key)throw new DOMException('Synthetic quota','QuotaExceededError');return original.call(this,k,v);};},failing);
   const result=await write(page,env('quota',true),migrated),slots=await snapshot(page);
   verify(!result.ok,'quota failure reported '+failing);
   verify(slots[P]===old,'quota leaves readable primary '+failing);
   verify(slots[A]===(failing===A?null:old),'quota never stores partial archive '+failing);
  });
  for(const slot of [B,A])await scenario([[P,env(1,true)],[B,env(0,true)],[A,old]],async page=>{
   await page.evaluate(({slot,text})=>localStorage.setItem(slot,text),{slot,text:env('other')});
   const before=await snapshot(page);
   verify((await write(page,env(2,true),continued)).reason==='concurrent_change','changed slot comparison '+slot);
   verify(JSON.stringify(await snapshot(page))===JSON.stringify(before),'concurrent values preserved '+slot);
  });
  await scenario([[P,env(1,true)],[B,env(0,true)],[A,old]],async page=>{
   const before=await snapshot(page);
   verify((await write(page,env(2),continued)).reason==='archive_conflict','cannot drop archive binding');
   verify(JSON.stringify(await snapshot(page))===JSON.stringify(before),'binding rejection does not mutate');
  });
  await scenario([[P,old],[A,'{corrupt']],async page=>{
   const before=await snapshot(page);
   verify((await write(page,env(2,true),migrated)).reason==='archive_unrecognized','unknown archive blocked');
   verify(JSON.stringify(await snapshot(page))===JSON.stringify(before),'unknown archive unchanged');
  });
  console.log(JSON.stringify({suite:'postcap_real_chromium_storage',checks,ok:true,browser:await browser.version(),limits:['Mock envelopes only; real domain validation is in Godot tests','No actual BFCache assertion','No production scene or device-performance assertion']}));
 } finally {if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
