'use strict';
// Storage faults and multi-tab races. All keys live in a synthetic Map.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.resolve(__dirname, '../../dispatch-storage.js'), 'utf8');
const P = 'flotra.campaign.dispatch.v5', B = P + '.backup';
const O = 'flotra.campaign.release.v1', OB = O + '.backup';
const env = n => JSON.stringify({format:'flotra-campaign',version:5,payload:Buffer.from('synthetic-'+n).toString('base64'),sha256:'0'.repeat(64)});
const flush = () => new Promise(resolve => setImmediate(resolve));
const results = [];
function locks() {
  const owners = new Map();
  return {request:async(name, options, callback) => {
    await Promise.resolve();
    assert.equal(options.mode,'exclusive'); assert.equal(options.ifAvailable,true);
    if (owners.has(name)) return callback(null);
    const token = {name}; owners.set(name,token);
    try { return await callback(token); }
    finally { if (owners.get(name) === token) owners.delete(name); }
  }};
}
function boot(map, hooks = {}, manager = locks()) {
  const writes = [], events = {};
  const localStorage = {
    getItem(key) { hooks.get?.(key); return map.get(key) ?? null; },
    setItem(key,value) { hooks.set?.(key,value); writes.push(key); map.set(key,value); }
  };
  const context = {window:{localStorage,navigator:{locks:manager},addEventListener:(n,fn)=>(events[n]??=[]).push(fn)}};
  vm.runInNewContext(source,context);
  return {store:context.window.FlotraDispatchStore,writes,event:(n,e={})=>(events[n]??[]).forEach(fn=>fn(e))};
}
async function ready(app) { await flush(); const read = app.store.read(); await flush(); return read; }
async function test(name, action) {
  try { await action(); results.push({name,ok:true}); }
  catch (error) { results.push({name,ok:false,error:error.stack}); }
}
(async () => {
  await test('migration writes only new primary; old primary/backup remain exact', async () => {
    const map = new Map([[O,'old primary'],[OB,'old backup'],['flotra.save','unrelated']]);
    const app = boot(map); const read = await ready(app);
    assert.equal(read.source,'legacy'); assert.equal(read.primary,'old primary');
    assert(app.store.write(env(1)).ok); assert(!map.has(B));
    assert(app.store.write(env(2)).ok); assert.equal(map.get(B),env(1));
    assert.equal(map.get(O),'old primary'); assert.equal(map.get(OB),'old backup');
    assert.equal(map.get('flotra.save'),'unrelated'); assert.deepEqual(app.writes,[P,B,P]);
  });
  await test('existing new generation takes precedence; no old reads', async () => {
    const map = new Map([[P,env(1)],[O,'newer old-version progress']]);
    const app = boot(map,{get:key=>assert(![O,OB].includes(key))});
    assert.equal((await ready(app)).source,'v5'); assert(app.store.write(env(2)).ok);
  });
  await test('first-write quota failure preserves old source and creates nothing', async () => {
    const map = new Map([[O,'old primary'],[OB,'old backup']]); const before = [...map];
    let fail = true;
    const app = boot(map,{set:key=>{if (key===P && fail) throw Error('QuotaExceededError');}});
    await ready(app); assert.equal(app.store.write(env(1)).reason,'storage_write_failed');
    assert.deepEqual([...map],before); fail = false; assert(app.store.write(env(1)).ok);
  });
  await test('backup quota failure preserves both valid new slots', async () => {
    const map = new Map([[P,env(1)],[B,env(0)]]); const before = [...map];
    const app = boot(map,{set:key=>{if(key===B)throw Error('QuotaExceededError');}});
    await ready(app); assert(!app.store.write(env(2)).ok); assert.deepEqual([...map],before);
  });
  await test('primary failure retains checkpoint and retry recognizes own rotation', async () => {
    const map = new Map([[P,env(1)],[B,env(0)]]); let fail = true;
    const app = boot(map,{set:key=>{if(key===P && fail)throw Error('QuotaExceededError');}});
    await ready(app); assert(!app.store.write(env(2)).ok);
    assert.equal(map.get(P),env(1)); assert.equal(map.get(B),env(1));
    fail = false; assert(app.store.write(env(2)).ok); assert.equal(map.get(P),env(2));
  });
  await test('an old-version tab prevents migration until it is closed and new page reopened', async () => {
    const map = new Map([[O,'old primary']]), manager = locks(); let releaseOld;
    manager.request(O+'.writer',{mode:'exclusive',ifAvailable:true},() => new Promise(resolve=>{releaseOld=resolve;}));
    await flush(); const app = boot(map,{},manager); await ready(app);
    assert.equal(app.store.write(env(1)).reason,'legacy_writer_unavailable'); assert(!map.has(P));
    app.event('pagehide'); releaseOld(); await flush();
    const reopened = boot(map,{},manager); await ready(reopened); assert(reopened.store.write(env(1)).ok);
  });
  await test('legacy mutation between read and first write refuses stale migration', async () => {
    const map = new Map([[O,'old primary']]); const app = boot(map); await ready(app);
    map.set(O,'changed old source'); assert.equal(app.store.write(env(1)).reason,'concurrent_change');
    assert(!map.has(P)); assert.equal(map.get(O),'changed old source');
  });
  await test('new backup external mutation refuses rotation', async () => {
    const map = new Map([[P,env(1)],[B,env(0)]]); const app=boot(map); await ready(app);
    map.set(B,env(9)); assert.equal(app.store.write(env(2)).reason,'concurrent_change');
    assert.equal(map.get(P),env(1)); assert.equal(map.get(B),env(9));
  });
  await test('second new tab cannot overwrite the writer', async () => {
    const map = new Map(), manager=locks(); const a=boot(map,{},manager), b=boot(map,{},manager);
    await ready(a); await ready(b); assert(a.store.write(env(1)).ok);
    assert.equal(b.store.write(env(2)).reason,'writer_unavailable'); assert.equal(map.get(P),env(1));
  });
  await test('empty, corrupt and future new envelopes are retained, not old fallback', async () => {
    for (const bad of ['', '{broken', env(1).replace('"version":5','"version":6')]) {
      const map = new Map([[P,bad],[O,'old primary']]); const app=boot(map); const read=await ready(app);
      assert.equal(read.source,'v5'); assert.equal(read.primary_present,true);
      assert.equal(app.store.write(env(2)).reason,'existing_unrecognized'); assert.equal(map.get(P),bad);
    }
  });
  await test('missing new primary with backup requires explicit recovery', async () => {
    const map=new Map([[B,env(1)],[O,'old primary']]); const app=boot(map); await ready(app);
    assert.equal(app.store.write(env(2)).reason,'backup_requires_recovery'); assert(!map.has(P));
  });
  await test('Web Lock absence/refusal fails closed', async () => {
    for (const manager of [null,{request:()=>Promise.reject(Error('SecurityError'))}]) {
      const map=new Map(); const app=boot(map,{},manager); await ready(app);
      assert.equal(app.store.write(env(1)).reason,'writer_unavailable'); assert.equal(map.size,0);
    }
  });
  await test('bfcache snapshot cannot overwrite a newer checkpoint', async () => {
    const map=new Map([[P,env(1)]]), manager=locks(); const a=boot(map,{},manager); await ready(a);
    a.event('pagehide'); await flush(); const b=boot(map,{},manager); await ready(b);
    assert(b.store.write(env(2)).ok); b.event('pagehide'); await flush();
    a.event('pageshow',{persisted:true}); await flush();
    assert.equal(a.store.write(env(3)).reason,'page_restore_required'); assert.equal(map.get(P),env(2));
  });
  await test('2 MB decoded ceiling applies before browser writes', async () => {
    const map=new Map(), app=boot(map); await ready(app);
    const large = count => JSON.stringify({format:'flotra-campaign',version:5,payload:Buffer.alloc(count).toString('base64'),sha256:'0'.repeat(64)});
    assert(app.store.write(large(2000000)).ok); const before=[...map], writes=app.writes.length;
    assert.equal(app.store.write(large(2000001)).reason,'invalid_envelope');
    assert.deepEqual([...map],before); assert.equal(app.writes.length,writes);
  });
  console.log(JSON.stringify({suite:'dispatch_storage_faults',checks:results.length,results},null,2));
  if(results.some(r=>!r.ok)) process.exitCode=1;
})().catch(error=>{console.error(error);process.exitCode=1;});
