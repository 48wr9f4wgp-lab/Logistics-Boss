import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';
import {workerVisualState} from '../../docs/forge-preview/workshop.mjs';

const at=(a,b)=>a.x===b.x&&a.y===b.y;
const idle={phase:'idle',part:null,machine:null};

function advanceUntil(s,condition) {
  for(let i=0;i<1000;i++){
    if(condition())return;
    M.step(s,M.TICK,{assignNew:false});
  }
  assert.fail('worker did not reach the expected point in the existing simulation');
}

function allocated(offer='first') {
  const s=M.fresh();
  if(offer==='fine'){
    s.cash=20000;
    assert.equal(M.purchase(s,'lathe',4,3),null);
  }
  assert.equal(M.accept(s,offer),null);
  M.step(s,M.TICK);
  const w=s.workers[0],part=s.parts.find(p=>p.id===w.job.part),machine=s.machines.find(m=>m.id===w.job.machine);
  assert.equal(w.job.phase,'walk');
  assert.ok(!at(w,part),'initial worker has not physically reached the material');
  return {s,w,part,machine};
}

function freeze(value) {
  if(value&&typeof value==='object'){
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

test('real plate and shaft routes stay empty-handed until arrival, then carry to their machine',()=>{
  for(const [offer,product] of [['first','plate'],['fine','shaft']]){
    const {s,w,part,machine}=allocated(offer);
    const pickup={x:part.x,y:part.y},service={x:machine.x,y:machine.y+1};
    for(let tick=0;tick<1000&&!at(w,pickup);tick++){
      const visual=workerVisualState(s,w);
      assert.equal(visual.phase,'pickup');
      assert.equal(visual.part,part);assert.equal(visual.machine,machine);
      M.step(s,M.TICK,{assignNew:false});
    }
    assert.ok(at(w,pickup),'worker reached the physical material cell');
    assert.equal(w.job.phase,'walk');
    assert.equal(workerVisualState(s,w).phase,'carry','material is picked up when the worker reaches it');
    assert.equal(workerVisualState(s,w).part.product,product);
    for(let tick=0;tick<1000&&!at(w,service);tick++){
      assert.equal(workerVisualState(s,w).phase,'carry');
      M.step(s,M.TICK,{assignNew:false});
      assert.ok(!at(w,pickup),'the delivery leg never revisits its material origin');
    }
    assert.ok(at(w,service),'worker reached the actual machine service cell');
    assert.equal(w.job.phase,'walk','arrival is consumed before the next work tick');
    assert.equal(workerVisualState(s,w).phase,'carry');
    M.step(s,M.TICK,{assignNew:false});
    assert.equal(w.job.phase,'work');
    assert.equal(workerVisualState(s,w).phase,'work');
    assert.equal(M.validate(s),true);
  }
});

test('a worker already at the material picks it up before taking the first outbound step',()=>{
  const s=M.fresh();M.accept(s,'first');
  const w=s.workers[0],part=s.parts[0];
  w.x=part.x;w.y=part.y;
  assert.equal(M.validate(s),true);
  M.step(s,M.TICK);
  assert.equal(w.job.part,part.id);
  assert.ok(!at(w,part),'the actual simulation has started moving away from the material');
  assert.ok(Math.hypot(w.x-part.x,w.y-part.y)<=M.TICK*2.2+.000001);
  assert.equal(workerVisualState(s,w).phase,'carry');
  assert.equal(workerVisualState(s,w).part,part);
});

test('finishing a stage allows the same worker to carry that real part directly to the next stage',()=>{
  const {s,w,part,machine}=allocated();
  advanceUntil(s,()=>w.job===null);
  assert.equal(part.stage,1);
  assert.deepEqual({x:part.x,y:part.y},{x:machine.x,y:machine.y+1});
  assert.ok(at(w,part));
  assert.deepEqual(workerVisualState(s,w),idle);
  M.step(s,M.TICK);
  assert.equal(w.job.part,part.id,'the next assignment continues the part just processed');
  const visual=workerVisualState(s,w);
  assert.equal(visual.machine.kind,'drill');
  assert.equal(visual.part,part);
  assert.equal(visual.phase,'carry');
  assert.ok(!at(w,part),'the worker has started walking to the next machine');
  assert.equal(M.validate(s),true);
});

test('material already at the destination service cell changes from pickup to work at actual arrival',()=>{
  // Valid saved-state boundary: ordinary distinct machine cells normally keep these points separate.
  const s=M.fresh();M.accept(s,'first');
  const machine=s.machines.find(m=>m.kind==='cut'),service={x:machine.x,y:machine.y+1};
  for(const part of s.parts)Object.assign(part,service);
  assert.equal(M.validate(s),true);
  M.step(s,M.TICK);
  const w=s.workers[0];
  assert.equal(workerVisualState(s,w).phase,'pickup');
  advanceUntil(s,()=>at(w,service));
  assert.equal(w.job.path.length,0);
  assert.equal(w.job.phase,'walk');
  assert.equal(workerVisualState(s,w).phase,'carry','the arrival tick hands the material to the machine');
  M.step(s,M.TICK,{assignNew:false});
  assert.equal(workerVisualState(s,w).phase,'work');
  assert.equal(M.validate(s),true);
});

test('when worker, material and service cell coincide the model goes straight to work',()=>{
  const s=M.fresh();M.accept(s,'first');
  const machine=s.machines.find(m=>m.kind==='cut'),service={x:machine.x,y:machine.y+1};
  for(const part of s.parts)Object.assign(part,service);
  const w=s.workers[0];Object.assign(w,service);
  assert.equal(M.validate(s),true);
  M.step(s,M.TICK);
  assert.equal(w.job.phase,'work');
  assert.equal(workerVisualState(s,w).phase,'work');
  assert.equal(workerVisualState(s,w).machine,machine);
});

test('pickup and carry phases survive saving midway through movement and continue identically',()=>{
  const {s,w,part}=allocated();
  const snapshots=[{phase:'pickup',json:JSON.stringify(s)}];
  advanceUntil(s,()=>at(w,part));
  M.step(s,M.TICK,{assignNew:false});
  assert.ok(!at(w,part),'the carry checkpoint is beyond the physical pickup point');
  snapshots.push({phase:'carry',json:JSON.stringify(s)});
  for(const snapshot of snapshots){
    const original=JSON.parse(snapshot.json),restored=JSON.parse(JSON.stringify(original));
    assert.equal(M.validate(restored),true);
    const restoredWorker=restored.workers[0],visual=workerVisualState(restored,restoredWorker);
    assert.equal(visual.phase,snapshot.phase);
    assert.equal(visual.part,restored.parts.find(p=>p.id===restoredWorker.job.part));
    assert.equal(visual.machine,restored.machines.find(m=>m.id===restoredWorker.job.machine));
    for(let i=0;i<200;i++){
      M.step(original,M.TICK,{assignNew:false});
      M.step(restored,M.TICK,{assignNew:false});
      assert.deepEqual(workerVisualState(restored,restored.workers[0]),workerVisualState(original,original.workers[0]));
    }
    assert.deepEqual(restored,original);
  }
});

test('read-only visual classification never changes state, including frozen movement and work snapshots',()=>{
  const {s,w,part}=allocated(),snapshots=[JSON.stringify(M.fresh()),JSON.stringify(s)];
  advanceUntil(s,()=>at(w,part));snapshots.push(JSON.stringify(s));
  advanceUntil(s,()=>w.job?.phase==='work');snapshots.push(JSON.stringify(s));
  for(const json of snapshots){
    const state=freeze(JSON.parse(json));
    for(let repeat=0;repeat<3;repeat++)for(const worker of state.workers)workerVisualState(state,worker);
    assert.equal(JSON.stringify(state),json);
  }
});

test('missing jobs, broken references and unknown job phases safely return an empty idle visual',()=>{
  const {s}=allocated(),snapshot=JSON.stringify(s);
  for(const change of [
    w=>{w.job=null;},
    w=>{delete w.job;},
    w=>{w.job.part='missing-part';},
    w=>{w.job.machine='missing-machine';},
    w=>{w.job.phase='unknown-phase';}
  ]){
    const state=JSON.parse(snapshot),worker=state.workers[0];change(worker);
    const before=JSON.stringify(state);
    assert.deepEqual(workerVisualState(state,worker),idle);
    assert.equal(JSON.stringify(state),before);
  }
});
