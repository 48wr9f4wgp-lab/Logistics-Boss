import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';

test('investment reference times include real level, skill, mentoring and inspection adjustment',()=>{
  assert.equal(M.processingTime('cut'),3);
  assert.equal(M.processingTime('drill'),5);
  assert.equal(M.processingTime('lathe'),8);
  assert.equal(M.processingTime('inspect'),2);
  assert.equal(M.processingTime('drill',{level:2}),4);
  assert.equal(M.processingTime('cut',{level:2}),2.4);
  assert.equal(M.processingTime('inspect',{quality:3}),5);
  assert.equal(M.processingTime('inspect',{quality:3,level:3}),2/1.5);
  assert.equal(M.processingTime('inspect',{quality:3,skill:2,level:2,mentor:true}),2/1.53*1.25);
  assert.equal(M.processingTime('inspect',{quality:3,skill:2,level:1,mentor:true}),2/1.28*1.25*2.5);
});

test('display calculation matches actual assigned work for all routes and quality cases',()=>{
  for(const offer of ['first','fine','master']){
    const s=M.fresh();s.cash=50000;
    if(offer!=='first')assert.equal(M.purchase(s,'lathe',4,3),null);
    if(offer==='master')s.workers[0].skill=3;
    s.workers[1].mentor=true;M.upgrade(s,'m2');M.upgrade(s,'m3');
    assert.equal(M.accept(s,offer),null);
    const previous=new Map(),seen=new Set();
    while(s.parts.some(p=>!p.done)){
      M.step(s,M.TICK);
      for(const w of s.workers){
        const j=w.job;if(!j){previous.delete(w.id);continue;}
        if(previous.get(w.id)===j)continue;
        previous.set(w.id,j);
        const m=s.machines.find(m=>m.id===j.machine),o=s.orders[0];
        const expected=M.processingTime(m.kind,{skill:w.skill,level:m.level,mentor:w.mentor,quality:o.quality});
        // A new job with no walk starts processing in this same tick.
        assert.ok(Math.abs(j.remaining-expected)<1e-10||Math.abs(j.remaining-(expected-M.TICK))<1e-10);
        seen.add(m.kind);
      }
      assert.ok(s.clock<1000);
    }
    assert.deepEqual([...seen].sort(),M.route(s.orders[0].product).sort());
    assert.equal(M.validate(s),true);
  }
});

test('upgrades and training charge once and affect future assignments, preserving in-flight work',()=>{
  const s=M.fresh();M.accept(s,'first');M.step(s,M.TICK);
  const w=s.workers.find(w=>w.job),job=structuredClone(w.job),m=s.machines.find(m=>m.id===job.machine),cash=s.cash;
  const before=M.processingTime(m.kind,{skill:w.skill,level:m.level});
  assert.equal(M.upgrade(s,m.id),null);assert.equal(M.train(s,w.id),null);
  assert.equal(cash-s.cash,2300);assert.deepEqual(w.job,job);
  assert.ok(M.processingTime(m.kind,{skill:w.skill,level:m.level})<before);
  const restored=JSON.parse(JSON.stringify(s));assert.equal(M.validate(restored),true);
  for(const state of [s,restored])while(state.parts.some(p=>!p.done)){
    M.step(state,M.TICK);assert.ok(state.clock<1000);
  }
  assert.deepEqual(s,restored);
  const noFunds=M.fresh();noFunds.cash=0;const saved=structuredClone(noFunds);
  assert.ok(M.upgrade(noFunds,'m1'));assert.ok(M.train(noFunds,0));assert.deepEqual(noFunds,saved);
});
