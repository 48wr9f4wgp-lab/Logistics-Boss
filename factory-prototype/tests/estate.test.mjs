import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';

test('first shipment can fund either dream, with ownership surviving a save',()=>{
  const start=M.fresh();
  assert.ok(M.ownerPurchase(start,'car'));
  assert.equal(M.accept(start,'first'),null);
  while(start.parts.some(p=>!p.done))M.step(start,M.TICK);
  M.dispatch(start,start.orders[0].id);
  for(const [choice,other,cost] of [['car','warehouse',6000],['warehouse','car',3500]]){
    const s=structuredClone(start);
    assert.equal(M.ownerPurchase(s,choice),null);
    assert.equal(s.cash,start.cash-cost);
    assert.ok(M.ownerPurchase(s,other));
    assert.ok(M.ownerPurchase(s,choice));
    assert.equal(M.validate(JSON.parse(JSON.stringify(s))),true);
    if(choice==='car')assert.equal(s.ownerCar,true);
    else assert.deepEqual([s.width,s.height],[10,8]);
  }
  assert.equal(M.ownerPurchase(start,'savings'),null);
  assert.equal(start.ownerSavings,5000);
  assert.equal(M.validate(start),true);
});
