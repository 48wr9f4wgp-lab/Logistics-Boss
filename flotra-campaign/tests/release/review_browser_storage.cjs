'use strict';
// Uses an isolated temporary headless Chromium profile and loopback-only test origin.
const http=require('node:http'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const source=fs.readFileSync(process.env.FLOTRA_STORAGE_BRIDGE || path.resolve(__dirname,'../../../../web/campaign-storage.js'),'utf8');
const PRIMARY='flotra.campaign.release.v1';
const env=n=>JSON.stringify({format:'flotra-campaign',version:1,payload:'mock'+n,sha256:'mock'});
(async()=>{
 const server=http.createServer((req,res)=>{
   res.setHeader('Content-Type',req.url==='/storage.js'?'application/javascript':'text/html');
   res.end(req.url==='/storage.js'?source:'<!doctype html><meta charset="utf-8"><title>Isolated FLOTRA storage test</title><script src="/storage.js"></script>');
 });
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const origin='http://127.0.0.1:'+server.address().port;
 let browser;
 try {
   browser=await chromium.launch({executablePath:process.env.FLOTRA_CHROMIUM||process.env.CHROMIUM_EXECUTABLE||undefined,headless:true,args:['--no-sandbox']});
   const context=await browser.newContext();
   const first=await context.newPage();await first.goto(origin);
   await first.waitForFunction(async()=>{const state=await navigator.locks.query();return state.held.some(lock=>lock.name==='flotra.campaign.release.v1.writer');});
   await first.evaluate(()=>{localStorage.setItem('legacy-save-sentinel','unchanged');window.FlotraCampaignStore.read();});
   assert((await first.evaluate(text=>window.FlotraCampaignStore.write(text),env(1))).ok);
   const second=await context.newPage();await second.goto(origin);
   await second.evaluate(()=>window.FlotraCampaignStore.read());
   assert.equal((await second.evaluate(text=>window.FlotraCampaignStore.write(text),env(2))).reason,'writer_unavailable');
   assert.equal(await second.evaluate(k=>localStorage.getItem(k),PRIMARY),env(1));
   await first.close();
   const resumed=await context.newPage();await resumed.goto(origin);
   await resumed.waitForFunction(async()=>{const state=await navigator.locks.query();return state.held.some(lock=>lock.name==='flotra.campaign.release.v1.writer');});
   assert.equal((await resumed.evaluate(()=>window.FlotraCampaignStore.read())).primary,env(1));
   assert((await resumed.evaluate(text=>window.FlotraCampaignStore.write(text),env(3))).ok);
   assert.equal((await second.evaluate(text=>window.FlotraCampaignStore.write(text),env(4))).reason,'writer_unavailable');
   assert.equal(await resumed.evaluate(()=>localStorage.getItem('legacy-save-sentinel')),'unchanged');
   assert.equal(await resumed.evaluate(k=>localStorage.getItem(k),PRIMARY+'.backup'),env(1));
   console.log(JSON.stringify({suite:'independent_real_chromium_storage',checks:8,ok:true,browser:await browser.version()}));
 } finally {if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
