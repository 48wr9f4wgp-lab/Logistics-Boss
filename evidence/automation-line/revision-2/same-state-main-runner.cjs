const {chromium}=require('/workspace/.flotra-tools/browser/node_modules/playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const output=process.argv[2]||'/tmp/flotra-state-comparison';const smoke=process.argv.includes('--smoke');
const sequence=smoke?['B0']:['A1','B1','B2','A2'];
(async()=>{fs.mkdirSync(output,{recursive:true});const all=[];
for(const label of sequence){const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true});
try{const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:smoke?1:3,isMobile:true,hasTouch:true});await context.addInitScript(()=>{window.__benchFrames=[];let last;function tick(now){if(window.flotraBenchmarkSampling&&last)window.__benchFrames.push(now-last);last=now;requestAnimationFrame(tick)}requestAnimationFrame(tick)});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
await page.goto(`http://127.0.0.1:8765/statefull-${label.startsWith('A')?'control':'candidate'}/?phone_qa=1`);
await page.waitForFunction(()=>window.flotraStateBenchmark,null,{timeout:180000});
const raw=await page.evaluate(()=>({...window.flotraStateBenchmark,raf_frames:window.__benchFrames}));assert.deepEqual(errors,[]);assert.equal(raw.rows.length,96);assert.equal(new Set(raw.rows.map(r=>r.ledger)).size,96,'Every measured row advances real cargo');assert.ok(raw.rows.some(r=>r.packing.length),'Actual packing is sampled');assert.ok(raw.rows.some(r=>r.save_pending),'Real staged autosave is sampled');assert.ok(raw.rows.at(-1).last_saved_generation>raw.rows[0].last_saved_generation,'Autosaves commit in isolated storage');assert.ok(raw.rows[0].time>85 && raw.rows.at(-1).time>raw.rows[0].time,'Expected mature fixture advances');
const env=await page.evaluate(()=>{const c=document.querySelector('#canvas'),gl=c.getContext('webgl2'),ext=gl.getExtension('WEBGL_debug_renderer_info');return {dpr:devicePixelRatio,css:[c.clientWidth,c.clientHeight],backing:[c.width,c.height],renderer:gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)}});
const percentile=(values,p)=>[...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(values.length*p))];
const summary={};for(const field of ['main_usec','draw_calls']){const values=raw.rows.map(r=>r[field]);summary[field]={p50:percentile(values,.5),p95:percentile(values,.95),max:Math.max(...values)};}
summary.raf_ms={p50:percentile(raw.raf_frames,.5),p95:percentile(raw.raf_frames,.95),max:Math.max(...raw.raf_frames)};summary.unchanged_view_usec={p50:percentile(raw.unchanged_view_usec,.5),p95:percentile(raw.unchanged_view_usec,.95)};
const result={label,environment:env,summary,...raw};all.push(result);fs.writeFileSync(path.join(output,label+'.json'),JSON.stringify(result,null,2));console.log(label,summary);
if(all.length>1){assert.deepEqual(raw.rows.map(r=>r.ledger),all[0].rows.map(r=>r.ledger));assert.deepEqual(env,all[0].environment);assert.deepEqual(raw.rows.map(r=>[r.save_phase,r.save_pending,r.generation,r.last_saved_generation]),all[0].rows.map(r=>[r.save_phase,r.save_pending,r.generation,r.last_saved_generation]));}
}finally{await browser.close();}}
fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify({scope:smoke?'harness smoke, not a qualified performance sample':'Sequential ABBA, identical full cargo state hash at every measured row',exactLedgerMatches:true,runs:all.map(({rows,unchanged_view_usec,...r})=>({...r,measuredRows:rows.length,busyPackingRows:rows.filter(x=>x.packing.length).length}))},null,2));
})().catch(e=>{console.error(e);process.exit(1)});
