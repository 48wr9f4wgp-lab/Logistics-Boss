'use strict';
// VM-only synthetic storage and locks; never opens a browser or real saves.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../dispatch-storage.js'),'utf8');
const P='flotra.campaign.dispatch.v5',O='flotra.campaign.release.v1';
const encoded=n=>JSON.stringify({format:'flotra-campaign',version:5,payload:Buffer.from('synthetic '+n).toString('base64'),sha256:'0'.repeat(64)});
const tick=()=>new Promise(r=>setImmediate(r));
function boot(initial=[], manager='delay') {
 const map=new Map(initial), requests=[],events={},timers=new Map(),writes=[];let timerId=0;
 const locks=manager==='delay'?{request:(name,options,callback)=>new Promise((resolve,reject)=>requests.push({name,options,callback,resolve,reject}))}:manager;
 const window={navigator:{locks},localStorage:{getItem:k=>map.get(k)??null,setItem:(k,v)=>{writes.push(k);map.set(k,v)}},addEventListener:(k,f)=>events[k]=f,setTimeout:f=>{timers.set(++timerId,f);return timerId},clearTimeout:id=>timers.delete(id)};
 vm.runInNewContext(source,{window});
 return {store:window.FlotraDispatchStore,map,requests,writes,events,timeout:()=>[...timers.values()].forEach(f=>f()),grant:i=>requests[i].resolve(requests[i].callback({name:requests[i].name})),deny:i=>requests[i].resolve(requests[i].callback(null))};
}
const results=[];
async function test(name,run){try{await run();results.push({name,ok:true})}catch(e){results.push({name,ok:false,error:e.stack})}}
(async()=>{
 await test('fresh loader waits for both delayed grants before engine and exact save/readback',async()=>{
  const a=boot();let starts=0;const done=a.store.ready().then(r=>{if(r.ok){starts++;assert.equal(a.store.read().source,'legacy');assert(a.store.write(encoded(1)).ok)}});
  await tick();assert.equal(starts,0);assert.equal(a.store.readiness().current.state,'pending');assert.equal(a.writes.length,0);
  a.grant(0);await tick();assert.equal(starts,0);assert.equal(a.requests.length,2);assert.equal(a.store.readiness().legacy.state,'pending');
  a.grant(1);await done;assert.equal(starts,1);assert.equal(a.map.get(P),encoded(1));assert.equal(a.store.read().primary,encoded(1));assert(!a.map.has(O));
 });
 await test('existing v5 requires no legacy lock',async()=>{const a=boot([[P,encoded(1)],[O,'old untouched']]);const done=a.store.ready();a.grant(0);assert((await done).ok);assert.equal(a.requests.length,1);a.store.read();assert(a.store.write(encoded(2)).ok);assert.equal(a.map.get(O),'old untouched')});
 await test('backup-only and malformed v5 never fall back to legacy lock',async()=>{for(const initial of [[[P+'.backup',encoded(1)]],[[P,'invalid']]]){const a=boot(initial),done=a.store.ready();a.grant(0);assert((await done).ok);assert.equal(a.requests.length,1);a.store.read();assert(!a.store.write(encoded(2)).ok);assert.equal(a.writes.length,0)}});
 await test('occupied v5 stays blocked with no retry or write',async()=>{const a=boot(),done=a.store.ready();a.deny(0);assert.equal((await done).state,'occupied');assert.equal((await a.store.ready()).state,'occupied');a.store.read();assert(!a.store.write(encoded(1)).ok);assert.equal(a.writes.length,0)});
 await test('occupied legacy keeps existing bytes unchanged',async()=>{const a=boot([[O,'legacy bytes']]),done=a.store.ready();a.grant(0);await tick();a.deny(1);assert.equal((await done).state,'occupied');assert.equal(a.map.get(O),'legacy bytes');assert.equal(a.writes.length,0)});
 await test('API absence and async rejection fail closed distinctly',async()=>{for(const manager of [null,{request:()=>Promise.reject(Error('SecurityError'))}]){const a=boot([],manager);assert.equal((await a.store.ready()).state,'unavailable');assert.equal(a.writes.length,0)}});
 await test('timeout cancels later grant; no engine or writes',async()=>{const a=boot(),done=a.store.ready();a.timeout();assert.equal((await done).state,'timeout');a.grant(0);await tick();assert(!a.store.readiness().current.ok);assert.equal(a.writes.length,0)});
 await test('pagehide while pending cancels startup and late callback',async()=>{const a=boot(),done=a.store.ready();a.events.pagehide();assert.equal((await done).state,'cancelled');a.grant(0);await tick();assert(!a.store.readiness().current.ok);assert.equal(a.writes.length,0)});
 await test('pagehide after grant but before continuation cannot start',async()=>{const a=boot([[P,encoded(1)]]),done=a.store.ready();a.grant(0);a.events.pagehide();assert.equal((await done).state,'cancelled');assert.equal(a.writes.length,0)});
 await test('explicit reload obtains fresh locks; no stale takeover',async()=>{const a=boot(),done=a.store.ready();a.deny(0);assert.equal((await done).state,'occupied');a.events.pagehide();const b=boot(),fresh=b.store.ready();b.grant(0);await tick();b.grant(1);assert((await fresh).ok);assert.equal(a.writes.length,0);assert.equal(b.writes.length,0)});
 await test('bfcache reacquisition never overwrites newer snapshot',async()=>{const a=boot([[P,encoded(1)]]),done=a.store.ready();a.grant(0);assert((await done).ok);a.store.read();a.events.pagehide();a.map.set(P,encoded(2));a.events.pageshow({persisted:true});assert(!a.store.write(encoded(3)).ok);assert.equal(a.requests.length,1);assert.equal(a.store.write(encoded(3)).reason,'page_restore_required');assert.equal(a.map.get(P),encoded(2))});
 await test('restore during engine download rejects read and notifies late Main',async()=>{const a=boot(),done=a.store.ready();a.grant(0);await tick();a.grant(1);assert((await done).ok);a.events.pagehide();a.events.pageshow({persisted:true});assert.equal(a.store.read().reason,'page_restore_required');assert.equal(a.requests.length,2);let notified=0;a.store.setRestoreHandler(()=>notified++);assert.equal(notified,1);assert.equal(a.writes.length,0)});
 console.log(JSON.stringify({suite:'dispatch_writer_ready',results},null,2));if(results.some(r=>!r.ok))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1});
