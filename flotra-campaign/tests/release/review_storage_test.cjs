'use strict';
// Independent adversarial checks. Shared Web Lock model holds ownership until callback settles.
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const src = fs.readFileSync(process.env.FLOTRA_STORAGE_BRIDGE || path.resolve(__dirname, '../../../../web/campaign-storage.js'), 'utf8');
const PRIMARY = 'flotra.campaign.release.v1';
const BACKUP = PRIMARY + '.backup';
const env = n => JSON.stringify({format:'flotra-campaign', version:1, payload:'mock'+n, sha256:'mock'});
const results = [];
const flush = () => new Promise(resolve => setImmediate(resolve));
function lockManager() {
  let owner = null;
  return {request: async (name,opts,callback) => {
    await Promise.resolve();
    assert.equal(name, PRIMARY+'.writer'); assert.equal(opts.mode,'exclusive'); assert.equal(opts.ifAvailable,true);
    if(owner) return callback(null);
    const token={name}; owner=token;
    try { return await callback(token); } finally { if(owner===token) owner=null; }
  }};
}
function boot(map, hooks={},locks=lockManager()) {
  const localStorage={
    getItem(key) { if(hooks.beforeGet) hooks.beforeGet(key); return map.get(key) ?? null; },
    setItem(key,value) { if(hooks.beforeSet) hooks.beforeSet(key,value); map.set(key,value); },
  };
  const events={};
  const ctx={window:{localStorage,navigator:{locks},addEventListener:(name,fn)=>{(events[name]??=[]).push(fn);}}};
  vm.runInNewContext(src,ctx);
  return {store:ctx.window.FlotraCampaignStore, dispatch:(name,event={})=>(events[name]??[]).forEach(fn=>fn(event))};
}
async function test(name, fn) { try { await fn(); results.push({name,ok:true}); } catch(e) { results.push({name,ok:false,error:e.message}); } }
(async()=>{
await test('isolated keys never change legacy data',async()=>{
  const map=new Map([['flotra.save','sentinel'],['/userfs','sentinel']]); const {store}=boot(map); await flush();
  store.read(); assert(store.write(env(1)).ok); assert(store.write(env(2)).ok);
  assert.equal(map.get('flotra.save'),'sentinel'); assert.equal(map.get('/userfs'),'sentinel');
  assert.deepEqual([...map.keys()].sort(),['/userfs',PRIMARY,BACKUP,'flotra.save'].sort());
});
await test('quota error at backup preserves primary',async()=>{
  const map=new Map([[PRIMARY,env(1)],[BACKUP,env(0)]]);
  const {store}=boot(map,{beforeSet:key=>{if(key===BACKUP) throw Error('QuotaExceededError');}}); await flush();
  store.read(); assert(!store.write(env(2)).ok); assert.equal(map.get(PRIMARY),env(1)); assert.equal(map.get(BACKUP),env(0));
});
await test('quota error at primary keeps valid recoverable state',async()=>{
  const map=new Map([[PRIMARY,env(1)],[BACKUP,env(0)]]);
  const {store}=boot(map,{beforeSet:key=>{if(key===PRIMARY) throw Error('QuotaExceededError');}}); await flush();
  store.read(); assert(!store.write(env(2)).ok); assert.equal(map.get(PRIMARY),env(1)); assert.equal(map.get(BACKUP),env(1));
});
await test('second tab cannot overwrite winner',async()=>{
  const map=new Map([[PRIMARY,env(1)]]),locks=lockManager(); const a=boot(map,{},locks),b=boot(map,{},locks); await flush();
  a.store.read(); b.store.read(); assert(a.store.write(env(2)).ok); assert(!b.store.write(env(3)).ok); assert.equal(map.get(PRIMARY),env(2));
});
await test('interleaved tabs cannot both accept conflicting writes',async()=>{
  const map=new Map([[PRIMARY,env(1)]]),locks=lockManager(); let trigger=false; let bResult;
  const a=boot(map,{beforeGet:key=>{ if(trigger && key===BACKUP) { trigger=false; bResult=b.store.write(env(2)); } }},locks);
  const b=boot(map,{},locks); await flush(); a.store.read(); b.store.read(); trigger=true;
  const aResult=a.store.write(env(3)); assert(aResult.ok); assert(!bResult.ok);
});
await test('foreign and future primary remain byte-for-byte unchanged',async()=>{
  for(const text of ['{bad', JSON.stringify({format:'flotra-campaign',version:2,payload:'x',sha256:'x'}), JSON.stringify({format:'foreign',version:1,payload:'x',sha256:'x'})]) {
    const map=new Map([[PRIMARY,text]]); const {store}=boot(map); await flush(); store.read(); assert(!store.write(env(1)).ok); assert.equal(map.get(PRIMARY),text);
  }
});
await test('foreign/future backup is preserved even with valid primary',async()=>{
  for(const text of ['{bad', JSON.stringify({format:'flotra-campaign',version:2,payload:'x',sha256:'x'}), JSON.stringify({format:'foreign',version:1,payload:'x',sha256:'x'})]) {
    const map=new Map([[PRIMARY,env(1)],[BACKUP,text]]); const {store}=boot(map); await flush(); store.read(); assert(!store.write(env(2)).ok); assert.equal(map.get(PRIMARY),env(1)); assert.equal(map.get(BACKUP),text);
  }
});
await test('lock API absent fails closed',async()=>{
  const map=new Map(); const {store}=boot(map,{},null); await flush(); assert(store.read().ok);
  assert.equal(store.write(env(1)).reason,'writer_unavailable'); assert.equal(map.size,0);
});
await test('lock API rejected fails closed',async()=>{
  const map=new Map(); const {store}=boot(map,{},{request:()=>Promise.reject(Error('SecurityError'))}); await flush(); assert(store.read().ok);
  assert.equal(store.write(env(1)).reason,'writer_unavailable'); assert.equal(map.size,0);
});
await test('before asynchronous lock admission fails closed',async()=>{
  const map=new Map(); const {store}=boot(map); store.read(); assert(!store.write(env(1)).ok); await flush(); assert(store.write(env(1)).ok);
});
await test('pagehide releases ownership; second tab remains read-only until reload',async()=>{
  const map=new Map([[PRIMARY,env(1)]]),locks=lockManager(); const a=boot(map,{},locks),b=boot(map,{},locks); await flush();
  a.store.read(); b.store.read(); a.dispatch('pagehide'); await flush(); assert(!a.store.write(env(2)).ok); assert(!b.store.write(env(2)).ok);
  const reloaded=boot(map,{},locks); await flush(); reloaded.store.read(); assert(reloaded.store.write(env(2)).ok);
});
await test('bfcache stale snapshot rejected after ownership reacquisition',async()=>{
  const map=new Map([[PRIMARY,env(1)]]),locks=lockManager(); const a=boot(map,{},locks); await flush(); a.store.read(); a.dispatch('pagehide'); await flush();
  const b=boot(map,{},locks); await flush(); b.store.read(); assert(b.store.write(env(2)).ok); b.dispatch('pagehide'); await flush();
  a.dispatch('pageshow',{persisted:true}); await flush(); assert.equal(a.store.write(env(3)).reason,'concurrent_change'); assert.equal(map.get(PRIMARY),env(2));
});
console.log(JSON.stringify({suite:'independent_storage_review',checks:results.length,results},null,2));
if(results.some(result=>!result.ok)) process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
