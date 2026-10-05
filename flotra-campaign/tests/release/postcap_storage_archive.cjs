'use strict';
// Disposable Map-only browser storage. Domain/checksum validation is separately
// exercised by postcap_save_archive.gd with real frozen compatibility models.
const vm = require('node:vm'), fs = require('node:fs'), path = require('node:path'), assert = require('node:assert/strict');
const src = fs.readFileSync(process.env.FLOTRA_STORAGE_BRIDGE || path.resolve(__dirname,'../../campaign-storage.js'),'utf8');
const P = 'flotra.campaign.release.v1', B = P+'.backup', A = P+'.pre-v4';
const digest = 'a'.repeat(64), otherDigest = 'b'.repeat(64);
const env = (n, link='') => JSON.stringify({format:'flotra-campaign',version:1,payload:'mock'+n,sha256:'mock',...(link ? {pre_v4_sha256:link} : {})});
const old = '\n  '+env('old')+' \n';
const linked = n => env(n,digest);
const protection = {archiveSource:old,validatedArchive:'',archiveDigest:digest};
const continued = {validatedArchive:old,archiveDigest:digest};
const flush = () => new Promise(resolve => setImmediate(resolve));
function lockManager() {
  let owner;
  return {request:async(name, options, callback)=>{
    await Promise.resolve();
    assert.equal(name,P+'.writer'); assert.equal(options.mode,'exclusive'); assert.equal(options.ifAvailable,true);
    if(owner) return callback(null);
    const token = {}; owner = token;
    try { return await callback(token); } finally { if(owner === token) owner = null; }
  }};
}
function boot(map = new Map(), hooks = {}, locks = lockManager()) {
  const writes = [], events = {};
  const window = {navigator:{locks},localStorage:{
    getItem(key) { hooks.get?.(key); return map.get(key) ?? null; },
    setItem(key, value) { hooks.set?.(key,value); writes.push({key,value}); map.set(key,value); }
  },addEventListener:(name, fn)=>(events[name]??=[]).push(fn)};
  vm.runInNewContext(src,{window});
  return {store:window.FlotraCampaignStore,writes,dispatch:(name,event={})=>(events[name]??[]).forEach(fn=>fn(event))};
}
const results=[];
async function test(name,run) { try { await run(); results.push({name,ok:true}); } catch(e) { results.push({name,ok:false,error:e.stack}); } }
(async()=>{
await test('first migration pins original bytes; 50 autosaves and reload never replace archive',async()=>{
  const map=new Map([[P,old],[B,env('older')]]),locks=lockManager(),a=boot(map,{},locks); await flush();
  assert.equal(a.store.read().archive_exists,false); assert.equal(a.writes.length,0);
  assert(a.store.write(linked(0),protection).ok); assert.equal(map.get(A),old); assert.equal(map.get(B),old);
  for(let i=1;i<=50;i++) assert(a.store.write(linked(i),continued).ok);
  assert.equal(map.get(A),old); assert.equal(a.writes.filter(w=>w.key===A).length,1);
  a.dispatch('pagehide'); await flush(); const b=boot(map,{},locks); await flush(); b.store.read();
  assert(b.store.write(linked(51),continued).ok); assert.equal(map.get(A),old); assert.equal(b.writes.filter(w=>w.key===A).length,0);
});
await test('archive quota failure precedes any primary or backup write',async()=>{
  const map=new Map([[P,old],[B,env('older')]]),before=[...map],a=boot(map,{set:k=>{if(k===A)throw Error('QuotaExceededError');}});await flush();a.store.read();
  assert.equal(a.store.write(linked(1),protection).reason,'archive_write_failed');assert.deepEqual([...map],before);assert.equal(a.writes.length,0);
});
await test('backup and primary quota failures retain exact protected archive and readable old primary',async()=>{
  for(const failing of [B,P]) {
    const map=new Map([[P,old],[B,env('older')]]),a=boot(map,{set:k=>{if(k===failing)throw Error('QuotaExceededError');}});await flush();a.store.read();
    assert.equal(a.store.write(linked(1),protection).reason,'storage_write_failed');assert.equal(map.get(P),old);assert.equal(map.get(A),old);
    assert.equal(map.get(B),failing===B?env('older'):old);
  }
});
await test('changed backup or archive blocks before any write even with unchanged primary',async()=>{
  for(const key of [B,A]) {
    const map=new Map([[P,linked(1)],[B,linked(0)],[A,old]]),a=boot(map);await flush();a.store.read();map.set(key,env('different'));
    const before=[...map];assert.equal(a.store.write(linked(2),continued).reason,'concurrent_change');assert.deepEqual([...map],before);assert.equal(a.writes.length,0);
  }
});
await test('foreign future empty and unvalidated archives fail closed',async()=>{
  for(const archive of ['', '{broken', JSON.stringify({format:'foreign',version:1,payload:'x',sha256:'x'}),JSON.stringify({format:'flotra-campaign',version:2,payload:'x',sha256:'x'}),old]) {
    const map=new Map([[P,linked(1)],[A,archive]]),before=[...map],a=boot(map);await flush();a.store.read();
    assert.equal(a.store.write(linked(2)).reason,'archive_unrecognized');assert.deepEqual([...map],before);assert.equal(a.writes.length,0);
  }
});
await test('existing different archive is immutable; requested original conflicts',async()=>{
  const archive=env('another-old'),map=new Map([[P,old],[A,archive]]),before=[...map],a=boot(map);await flush();a.store.read();
  assert.equal(a.store.write(linked(1),{...protection,validatedArchive:archive}).reason,'archive_conflict');assert.deepEqual([...map],before);
});
await test('engine cannot silently drop or change carried archive binding',async()=>{
  for(const next of [env(2),env(2,otherDigest)]) {
    const map=new Map([[P,linked(1)],[B,linked(0)],[A,old]]),before=[...map],a=boot(map);await flush();a.store.read();
    assert.equal(a.store.write(next,continued).reason,'archive_conflict');assert.deepEqual([...map],before);
  }
});
await test('bound primary cannot continue with missing archive',async()=>{
  const map=new Map([[P,linked(1)],[B,linked(0)]]),before=[...map],a=boot(map);await flush();a.store.read();
  assert.equal(a.store.write(linked(2),continued).reason,'archive_conflict');assert.deepEqual([...map],before);
});
await test('mixed schema4 primary with old backup can pin backup exact original',async()=>{
  const map=new Map([[P,env('unlinked4')],[B,old]]),a=boot(map);await flush();a.store.read();
  assert(a.store.write(linked(1),protection).ok);assert.equal(map.get(A),old);assert.equal(map.get(B),env('unlinked4'));
});
await test('archive-only storage never resets into a fresh campaign',async()=>{
  const map=new Map([[A,old]]),before=[...map],a=boot(map);await flush();a.store.read();
  assert.equal(a.store.write(linked(1),continued).reason,'archive_requires_recovery');assert.deepEqual([...map],before);
});
await test('web-lock loser cannot create migration archive',async()=>{
  const map=new Map([[P,old]]),locks=lockManager(),a=boot(map,{},locks),b=boot(map,{},locks);await flush();a.store.read();b.store.read();
  assert.equal(b.store.write(linked(1),protection).reason,'writer_unavailable');assert(!map.has(A));assert(a.store.write(linked(2),protection).ok);
});
await test('BFCache return catches archive-only and backup-only changes',async()=>{
  for(const key of [A,B]) {
    const map=new Map([[P,linked(1)],[B,linked(0)],[A,old]]),locks=lockManager(),a=boot(map,{},locks);await flush();a.store.read();a.dispatch('pagehide');await flush();
    map.set(key,env('changed'));const before=[...map];a.dispatch('pageshow',{persisted:true});await flush();
    assert.equal(a.store.write(linked(2),continued).reason,'concurrent_change');assert.deepEqual([...map],before);
  }
});
await test('pagehide before asynchronous lock admission cannot revive hidden writer',async()=>{
  const map=new Map([[P,old]]),a=boot(map);a.store.read();a.dispatch('pagehide');await flush();assert.equal(a.store.write(linked(1),protection).reason,'writer_unavailable');
  a.dispatch('pageshow',{persisted:true});await flush();assert(a.store.write(linked(1),protection).ok);
});
await test('interleaved archive change during compare phase never overwrites it',async()=>{
  const map=new Map([[P,old]]);let trigger=false;
  const a=boot(map,{get:k=>{if(trigger && k===A){trigger=false;map.set(A,env('intruder'));}}});await flush();a.store.read();trigger=true;
  assert.equal(a.store.write(linked(1),protection).reason,'concurrent_change');assert.equal(map.get(A),env('intruder'));assert.equal(map.get(P),old);assert.equal(a.writes.length,0);
});
await test('empty present primary and backup are protected, not absence',async()=>{
  for(const key of [P,B]) {
    const map=new Map([[key,'']]),a=boot(map);await flush();const read=a.store.read();assert.equal(read[key===P?'primary_exists':'backup_exists'],true);
    assert(!a.store.write(env('new')).ok);assert.equal(map.get(key),'');assert.equal(a.writes.length,0);
  }
});
console.log(JSON.stringify({suite:'postcap_storage_archive',checks:results.length,results},null,2));
if(results.some(r=>!r.ok))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
