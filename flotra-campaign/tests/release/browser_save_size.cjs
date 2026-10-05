'use strict';
// Runs the isolated diagnostic export built from unchanged production sources.
// Each case owns a new browser context, never a real save origin.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const root=path.resolve(process.argv[2]||'build/save-size-export'),out=path.resolve(process.argv[3]||'build/save-size-browser');
const key='flotra.campaign.release.v1';
const report={cases:[],errors:[],console:[],requests:[]};
fs.mkdirSync(out,{recursive:true});
fs.copyFileSync(path.join(root,"source-sha256.txt"),path.join(out,"source-sha256.txt"));
const server=http.createServer((req,res)=>{
 let file=path.resolve(root,'.'+new URL(req.url,'http://localhost').pathname);
 if(file===root)file=path.join(root,'index.html');
 if(!file.startsWith(root+path.sep)){res.writeHead(403);return res.end();}
 fs.readFile(file,(e,raw)=>{if(e){res.writeHead(404);return res.end();}
  res.writeHead(200,{'Content-Type':({'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm'})[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});res.end(raw);
 });
});
(async()=>{let browser;
 try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const options={headless:true};if(process.env.CHROMIUM_EXECUTABLE)options.executablePath=process.env.CHROMIUM_EXECUTABLE;
  browser=await chromium.launch(options);report.browser=browser.version();
  for(const mode of ['boundaries','quota']){
   const context=await browser.newContext({viewport:{width:375,height:567},deviceScaleFactor:3});
   await context.addInitScript(()=>{window.flotraDisposableSizeTest=true;window.flotraSizeWrites=0;const set=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k==='flotra.campaign.release.v1'||k==='flotra.campaign.release.v1.backup')window.flotraSizeWrites++;return set.call(this,k,v);};});
   const page=await context.newPage();page.on('pageerror',e=>report.errors.push(String(e)));page.on('console',m=>{report.console.push(m.text());fs.writeFileSync(path.join(out,'progress.json'),JSON.stringify(report,null,2));if(m.type()==='error'&&!/favicon/.test(m.text()))report.errors.push(m.text());});
   page.on('response',r=>{if(r.status()>=400){report.requests.push({url:r.url(),status:r.status()});fs.writeFileSync(path.join(out,'progress.json'),JSON.stringify(report,null,2));}});
   await page.goto(`http://127.0.0.1:${server.address().port}/`,{waitUntil:'domcontentloaded'});
   try { await page.waitForFunction(()=>window.flotraSizeReady===true || window.flotraSizeLoadError,null,{timeout:120000}); } catch(error) {report.startup=await page.evaluate(()=>({entered:window.flotraSizeEntered,ready:window.flotraSizeReady,flag:window.flotraDisposableSizeTest,html:document.documentElement.outerHTML}));await page.screenshot({path:path.join(out,'startup.png')});throw error;}
   assert.equal(await page.evaluate(()=>window.flotraSizeLoadError),undefined);
   await page.waitForFunction(async k=>(await navigator.locks.query()).held.some(x=>x.name===k+'.writer'),key);
   const result=await page.evaluate(mode=>{window.FlotraSizeTestInvoke(mode);return window.flotraSizeReport;},mode);
   report.cases.push({mode,result});fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
   assert.deepEqual(result.failures,[],mode);await context.close();
  }
  assert.deepEqual(report.errors,[]);report.ok=true;console.log(JSON.stringify(report));
 }finally{if(browser)await browser.close();await new Promise(r=>server.close(r));fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));}
})().catch(e=>{console.error(e);process.exitCode=1;});
