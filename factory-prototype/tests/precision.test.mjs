import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.20';
import {estimateOrder} from '../../docs/forge-preview/estimate.mjs?v=0.20';
import {acceptPrecision,installStarterLathe,precisionPlan,shaftEntryCost} from '../../docs/forge-preview/precision.mjs?v=0.20';
import {deliveryGuide,floorTicket} from '../../docs/forge-preview/guidance.mjs?v=0.20';

function finish(s){
  let q;do{q=M.advanceToReady(s,200);}while(q.status==='producing');
  assert.equal(q.status,'ready');assert.equal(M.dispatch(s,q.orderId),null);
  assert.ok(M.validate(s));return s.results[0];
}
function afterPlates(n,lathe=true){
  const s=M.fresh();
  for(let i=0;i<n;i++){M.accept(s,'first');finish(s);}
  if(lathe)assert.equal(installStarterLathe(s,{x:3,y:2}),null);
  return s;
}
test('the first standard contract is affordable before full master preparation, and the floor preview is truthful',()=>{
  const s=afterPlates(1,false),before=JSON.stringify(s),cell={x:3,y:2};
  assert.equal(shaftEntryCost(s),7200);assert.equal(M.growthPlan(s,'master').shortage,2781);
  const q=estimateOrder(s,{lathe:cell,precision:{offer:'fine'}});
  assert.equal(JSON.stringify(s),before);assert.equal(q.rework,10);
  const cash=s.cash;assert.equal(installStarterLathe(s,cell),null);assert.equal(s.cash,cash-5800);
  assert.ok(installStarterLathe(s,{x:4,y:2}));assert.equal(M.frontOrder(s),null);
  assert.equal(acceptPrecision(s,{offer:'fine'},q),null);
  const r=finish(s);assert.equal(r.seconds,q.seconds);assert.equal(r.rework,q.rework);
});
test('guided lathe purchase preserves material cash and rejects an invalid bay or busy factory',()=>{
  const s=afterPlates(1,false);
  s.cash=7199.9;let before=JSON.stringify(s);assert.ok(installStarterLathe(s,{x:3,y:2}));assert.equal(JSON.stringify(s),before);
  s.cash=7200;before=JSON.stringify(s);assert.ok(installStarterLathe(s,{x:2,y:1}));assert.equal(JSON.stringify(s),before);
  M.accept(s,'relief');before=JSON.stringify(s);assert.ok(installStarterLathe(s,{x:3,y:2}));assert.equal(JSON.stringify(s),before);
});
for(const investment of ['none','train','bench']){
  test('assigned shaft inspection, '+investment+': forecast equals real visits, exact costs, resume and skip',()=>{
    const s=afterPlates(2),choice={offer:'fine',inspector:1,investment};
    const start=s.next,cash=s.cash,snap=JSON.stringify(s),q=estimateOrder(s,{precision:choice});
    assert.equal(JSON.stringify(s),snap);
    assert.equal(acceptPrecision(s,choice,q,start),null);
    const cost={none:0,train:800,bench:1500}[investment];
    assert.equal(s.cash,cash-1400-cost);assert.equal(M.frontOrder(s).qualitySpend,cost);
    const accepted=JSON.stringify(s);
    assert.ok(acceptPrecision(s,choice,q,start));assert.equal(JSON.stringify(s),accepted);
    assert.match(floorTicket(s).hint,/森が検品を担当/);
    const id=M.frontOrder(s).id,visits=new Set();let copy;
    for(let tick=0;tick<10000&&M.frontOrder(s).done<10;tick++){
      M.step(s,M.TICK);
      for(const w of s.workers){
        const p=s.parts.find(p=>p.id===w.job?.part);
        if(p?.order===id&&p.stage===2&&s.machines.find(m=>m.id===w.job.machine)?.kind==='inspect'){
          assert.equal(w.id,1);visits.add(p.id);
          if(!copy){copy=JSON.parse(JSON.stringify(s));assert.ok(M.validate(copy));}
        }
      }
    }
    assert.equal(visits.size,10);assert.equal(M.dispatch(s,id),null);
    const r=s.results[0],restored=finish(copy);
    assert.deepEqual(r,restored);assert.equal(q.seconds,r.seconds);assert.equal(q.rework,r.rework);
    assert.equal(r.quote.rework,r.rework);assert.deepEqual(r.inspectorId,1);
    assert.ok(Math.abs(s.cash-cash-q.net)<1e-6);assert.equal(r.qualitySpend,cost);
    assert.ok(r.growth.some(event=>event.worker===1&&event.skill===(investment==='train'?3:2)));
    assert.match(deliveryGuide(s).title,/成長/);
  });
}
test('train to the actual quality gate, keep edits atomic and leave unrelated orders free to use staff',()=>{
  const s=afterPlates(2),choice={offer:'master',inspector:0,investment:'train'};
  s.cash=4599.99;let before=JSON.stringify(s);
  assert.ok(acceptPrecision(s,choice));assert.equal(JSON.stringify(s),before);
  s.cash=4600;assert.equal(precisionPlan(s,choice).cost,2400);
  assert.equal(acceptPrecision(s,choice),null);assert.equal(s.workers[0].skill,3);assert.equal(s.cash,0);
  s.cash=5000;M.accept(s,'first');
  const records=[finish(s),finish(s)];const shaft=records.find(r=>r.offerId==='master');
  assert.equal(shaft.rework,0);assert.equal(shaft.inspectorId,0);
  assert.equal(records.find(r=>r.offerId==='first').inspectorId,undefined);
});
test('two shaft contracts can share an inspector without deadlocking, including mentoring and expanded routing',()=>{
  const s=afterPlates(3);s.cash=50000;M.expand(s);s.workers[2].mentor=true;
  const a={offer:'master',inspector:2,investment:'train'},b={offer:'fine',inspector:2};
  assert.equal(acceptPrecision(s,a),null);
  const q=estimateOrder(s,{precision:b});assert.equal(acceptPrecision(s,b,q),null);
  const results=[finish(s),finish(s)],r=results.find(v=>v.offerId==='fine');
  assert.equal(r.seconds,q.seconds);assert.equal(r.rework,q.rework);assert.ok(M.validate(s));
});
test('saved precision fields reject wrong roles or corrupt quality history while legacy reports stay valid',()=>{
  const s=afterPlates(3);assert.ok(M.validate(s));
  const raw=JSON.stringify(s);assert.ok(acceptPrecision(s,{offer:'master',inspector:9}));assert.equal(JSON.stringify(s),raw);
  const spec={offer:'fine',inspector:1};assert.equal(acceptPrecision(s,spec),null);
  const o=M.frontOrder(s);o.inspectorId=3;assert.equal(M.validate(s),false);o.inspectorId=1;
  o.accounting.growth.push({worker:1,skill:2},{worker:1,skill:2});assert.equal(M.validate(s),false);o.accounting.growth=[];
  finish(s);s.results[0].quote={seconds:100,profit:100,rework:11};assert.equal(M.validate(s),false);
  delete s.results[0].quote;s.results[1].inspectorId=0;assert.equal(M.validate(s),false);
});
