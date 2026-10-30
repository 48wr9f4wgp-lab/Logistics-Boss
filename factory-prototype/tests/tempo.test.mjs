import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';

function skip(s){
  for(let i=0;i<240;i++){
    const r=M.advanceToReady(s);
    if(r.status!=='producing')return r;
  }
  assert.fail('production did not complete within 1,200 game seconds');
}

test('skip and ordinary fixed ticks produce identical work, wages and skill growth',()=>{
  const normal=M.fresh();M.accept(normal,'first');
  const fast=structuredClone(normal);
  while(normal.orders[0].done<12)M.step(normal,M.TICK);
  assert.equal(skip(fast).status,'ready');
  assert.deepEqual(fast,normal);
  assert.equal(fast.delivered,0);assert.equal(fast.revenue,0);
  assert.equal(fast.stats.processed,36);
  assert.ok(Math.abs(fast.cash-(4900-fast.clock*.7))<1e-8);
  assert.ok(Math.abs(fast.orders[0].accounting.wages-fast.clock*.7)<1e-8);
  assert.equal(M.validate(fast),true);
});

test('completion is a barrier: stop at the first ready order and pay only on dispatch',()=>{
  const s=M.fresh();M.accept(s,'first');M.accept(s,'bulk');
  const r=skip(s),o=s.orders.find(o=>o.id===r.orderId);
  assert.equal(o.done,o.qty);assert.ok(s.orders.some(o=>o.done<o.qty));
  const ready=structuredClone(s);
  assert.equal(M.advanceToReady(s).ticks,0);assert.deepEqual(s,ready);
  const quote=M.shipmentQuote(s,o),cash=s.cash;
  assert.equal(M.dispatch(s,o.id),null);assert.equal(s.cash-cash,quote.pay);
  assert.ok(M.dispatch(s,o.id));assert.equal(s.cash-cash,quote.pay);
  const remaining=s.orders.find(o=>!o.shipped),second=skip(s);
  assert.equal(second.orderId,remaining.id);
  assert.equal(s.delivered,1);assert.equal(s.stats.processed,120);
  assert.ok(Math.abs(s.orders.reduce((n,o)=>n+o.accounting.wages,0)-s.clock*.7)<1e-7);
  assert.equal(M.validate(s),true);
});

test('ready second order and an empty factory never advance or accrue costs',()=>{
  const idle=M.fresh(),copy=structuredClone(idle);
  assert.deepEqual(M.advanceToReady(idle),{status:'idle',ticks:0});assert.deepEqual(idle,copy);
  const s=M.fresh();M.accept(s,'first');skip(s);M.accept(s,'bulk');s.orders.reverse();
  const before=structuredClone(s),ready=M.frontOrder(s);
  assert.notEqual(s.orders[0].id,ready.id);
  assert.equal(M.advanceToReady(s).orderId,ready.id);assert.deepEqual(s,before);
});

test('bounded chunks can be stopped and resumed from an existing in-flight save',()=>{
  const s=M.fresh();M.accept(s,'bulk');
  for(let i=0;i<173;i++)M.step(s,.1); // A v0.6-style in-flight save, with fractional positions.
  const restored=JSON.parse(JSON.stringify(s));assert.equal(M.validate(restored),true);
  const chunk=M.advanceToReady(restored,13);assert.equal(chunk.ticks,13);
  for(let i=0;i<13;i++)M.step(s,M.TICK);
  assert.deepEqual(restored,s);
  const resumed=JSON.parse(JSON.stringify(restored));
  skip(resumed);skip(s);assert.deepEqual(resumed,s);assert.equal(M.validate(resumed),true);
  const legacy=M.fresh();M.accept(legacy,'first');
  delete legacy.orders[0].offerId;delete legacy.orders[0].accounting;
  assert.equal(skip(legacy).status,'ready');assert.equal(M.validate(legacy),true);
});

test('skip preserves layout and investment benefits and still applies lateness',()=>{
  const base=M.fresh(),moved=M.fresh();
  M.move(moved,'m2',3,1);M.move(moved,'m3',4,1);
  for(const s of [base,moved]){M.accept(s,'bulk');skip(s);}
  assert.ok(moved.clock<base.clock);assert.ok(moved.stats.walk<base.stats.walk);
  assert.ok(moved.orders[0].accounting.wages<base.orders[0].accounting.wages);
  const slow=M.fresh(),fast=M.fresh();
  for(const s of [slow,fast]){s.cash=20000;M.upgrade(s,'m2');}
  M.upgrade(fast,'m1');M.upgrade(fast,'m2');M.upgrade(fast,'m3');
  M.move(fast,'m2',3,1);M.move(fast,'m3',4,1);
  for(const s of [slow,fast]){assert.equal(M.accept(s,'rush'),null);skip(s);}
  assert.ok(fast.clock<slow.clock);
  assert.equal(M.shipmentQuote(slow,slow.orders[0]).late,true);
  assert.equal(M.shipmentQuote(slow,slow.orders[0]).pay,6120);
  assert.equal(M.shipmentQuote(fast,fast.orders[0]).late,false);
});

test('zero funds recovery completes; stalled work and malformed chunk sizes stay bounded',()=>{
  const rescue=M.fresh();rescue.cash=0;M.accept(rescue,'relief');
  assert.equal(skip(rescue).status,'ready');assert.equal(rescue.cash,0);
  assert.equal(rescue.orders[0].accounting.wages,0);assert.equal(M.validate(rescue),true);
  const s=M.fresh();s.cash=20000;assert.equal(M.purchase(s,'lathe',4,3),null);assert.equal(M.accept(s,'fine'),null);
  // A stalled legacy state missing its required lathe must not hang the browser.
  s.machines=s.machines.filter(m=>m.kind!=='lathe');
  for(let i=0;i<10;i++)M.advanceToReady(s,200);
  const before=structuredClone(s);
  for(const n of [NaN,Infinity,-1])assert.equal(M.advanceToReady(s,n).ticks,0);
  assert.deepEqual(s,before);
  const r=M.advanceToReady(s,1e9);assert.equal(r.ticks,200);assert.equal(r.status,'producing');
  assert.ok(Math.abs(s.clock-before.clock-10)<1e-8);
});
