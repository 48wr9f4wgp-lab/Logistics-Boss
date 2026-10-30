import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';

function finish(s){for(let i=0;i<10000&&s.parts.some(p=>!p.done);i++)M.step(s,.1);assert.ok(s.parts.every(p=>p.done));}

test('plans read existing capability and include material funding without mutating state',()=>{
  const s=M.fresh(),before=JSON.stringify(s),rush=M.growthPlan(s,'rush'),master=M.growthPlan(s,'master');
  assert.deepEqual([rush.investment,rush.required,rush.shortage,rush.next.type],[1500,3300,0,'upgrade']);
  assert.deepEqual([master.investment,master.required,master.shortage,master.next.type],[8200,10400,4900,'orders']);
  assert.equal(JSON.stringify(s),before);assert.equal(M.growthPlan(s,'first'),null);
  s.cash=3299.7;assert.equal(M.growthPlan(s,'rush').shortage,1);
  assert.equal(M.growthPlan(s,'rush').phase,'funds');
});

test('prepared budget matches actual lathe and successive training charges, leaving material funds',()=>{
  const s=M.fresh();s.cash=10400;
  let p=M.growthPlan(s,'master');assert.equal(p.next.type,'purchase');
  assert.equal(M.purchase(s,p.next.kind,4,3),null);
  p=M.growthPlan(s,'master');assert.deepEqual([p.investment,p.next.cost,p.next.id],[2400,800,0]);
  assert.equal(M.train(s,p.next.id),null);
  p=M.growthPlan(s,'master');assert.deepEqual([p.investment,p.next.cost],[1600,1600]);
  assert.equal(M.train(s,p.next.id),null);
  p=M.growthPlan(s,'master');assert.equal(p.phase,'ready');assert.equal(s.cash,2200);
  assert.equal(M.accept(s,'master'),null);assert.equal(s.cash,0);assert.equal(M.validate(s),true);
});

test('alternate equipment and real skill growth reduce the plan; either route remains usable',()=>{
  const s=M.fresh();s.cash=20000;
  assert.equal(M.purchase(s,'drill',3,1),null);
  assert.equal(M.growthPlan(s,'rush').investment,0);
  s.workers[2].skill=2;let p=M.growthPlan(s,'master');
  assert.equal(p.preparations.find(x=>x.type==='train').id,2);assert.equal(p.investment,7400);
  s.workers[2].skill=3;assert.equal(M.growthPlan(s,'master').investment,5800);
  assert.equal(M.setGoal(s,'master'),null);
  assert.equal(M.accept(s,'rush'),null);assert.equal(s.goalOffer,'master');
});

test('selected goal is optional, validates strictly, and survives save reload without spending',()=>{
  const s=M.fresh(),cash=s.cash;assert.equal(M.validate(s),true);
  assert.equal(M.setGoal(s,'rush'),null);assert.equal(s.cash,cash);
  const copy=JSON.parse(JSON.stringify(s));assert.equal(M.validate(copy),true);assert.equal(copy.goalOffer,'rush');
  for(const goal of ['first','unknown',{},42]){copy.goalOffer=goal;assert.equal(M.validate(copy),false);}
  copy.goalOffer=null;assert.equal(M.validate(copy),true);delete copy.goalOffer;assert.equal(M.validate(copy),true);
  const before=JSON.stringify(s);assert.ok(M.setGoal(s,'first'));assert.equal(JSON.stringify(s),before);
});

test('active goal orders override new-investment advice and select a ready second order for shipping',()=>{
  const s=M.fresh();s.cash=20000;M.purchase(s,'drill',3,1);M.setGoal(s,'rush');
  M.accept(s,'rush');finish(s);M.accept(s,'rush');
  const ready=s.orders[0],running=s.orders[1];s.orders.reverse();
  let p=M.growthPlan(s,'rush');assert.equal(p.phase,'ship');assert.equal(p.next.id,ready.id);
  M.sell(s,s.machines.find(m=>m.kind==='drill'&&m.id!=='m2').id);
  assert.equal(M.offerStatus(s,'rush').qualified,false);
  assert.equal(M.growthPlan(s,'rush').phase,'ship');
  M.dispatch(s,ready.id);p=M.growthPlan(s,'rush');assert.equal(p.phase,'producing');assert.equal(p.order.id,running.id);
  finish(s);M.dispatch(s,running.id);assert.equal(s.goalOffer,'rush');assert.equal(M.growthPlan(s,'rush').phase,'prepare');
  assert.equal(M.validate(s),true);
});

test('full order slots direct the player to current work rather than premature investment',()=>{
  const s=M.fresh();M.accept(s,'first');M.accept(s,'relief');
  const p=M.growthPlan(s,'master');assert.equal(p.phase,'slots');assert.equal(p.next.type,'orders');
  assert.equal(p.order,null);
});
