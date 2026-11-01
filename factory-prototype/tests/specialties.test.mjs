import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.24';
import {restoreSpecialties} from '../../docs/forge-preview/specialties.mjs?v=0.24';
import {acceptPrecision} from '../../docs/forge-preview/precision.mjs?v=0.24';

function shop(){
  const s=M.fresh();s.cash=40000;M.upgrade(s,'m2');M.purchase(s,'lathe',4,3);
  assert.equal(M.move(s,'m2',3,1),null);assert.equal(M.move(s,'m3',4,1),null);
  M.train(s,1);M.train(s,1);return s;
}
function ready(s){
  let r;do{r=M.advanceToReady(s,200);}while(r.status==='producing');
  assert.equal(r.status,'ready');return M.frontOrder(s);
}
function send(s,offer){
  assert.equal(offer==='master'?acceptPrecision(s,{offer,inspector:1}):M.accept(s,offer),null);
  const o=ready(s);assert.equal(M.dispatch(s,o.id),null);assert.ok(M.validate(s));return o;
}
for(const [first,second] of [['rush','master'],['master','rush']]){
  test(first+' can earn the first ending, keep producing and later earn '+second,()=>{
    let s=shop();const o=send(s,first),stamp=structuredClone(s.specialties[0]);
    assert.equal(s.specialties.length,1);assert.equal(stamp.orderId,o.id);
    assert.equal(stamp.margin,o.start+o.due-s.clock);
    if(first==='master'){assert.equal(stamp.inspectorId,1);assert.equal(stamp.rework,s.results[0].rework);}
    let cash=s.cash;assert.ok(M.dispatch(s,o.id));assert.equal(s.cash,cash);
    send(s,first);s=JSON.parse(JSON.stringify(s));send(s,second);
    assert.deepEqual(s.specialties.map(e=>e.offerId),[first,second]);
    for(let i=0;i<13;i++)send(s,'relief');
    assert.ok(s.results.every(r=>r.offerId==='relief'));
    assert.deepEqual(s.specialties[0],stamp);assert.ok(M.validate(s));
  });
}
test('only dispatch by the deadline earns a stamp, including exactly on the deadline',()=>{
  const s=shop();M.accept(s,'rush');let o=ready(s);
  assert.equal(s.specialties.length,0);
  s.clock=o.start+o.due+1;M.dispatch(s,o.id);assert.equal(s.results[0].late,true);
  assert.deepEqual(s.specialties,[]);M.accept(s,'rush');o=ready(s);s.clock=o.start+o.due;
  M.dispatch(s,o.id);assert.equal(s.specialties[0].margin,0);assert.ok(M.validate(s));
});
test('a legacy save recovers its earliest retained evidence and leaves unknown shipping margin unset',()=>{
  const s=shop();send(s,'rush');send(s,'rush');send(s,'master');const original=structuredClone(s.specialties);
  delete s.specialties;assert.ok(M.validate(s));restoreSpecialties(s);assert.ok(M.validate(s));
  assert.deepEqual(s.specialties.map(e=>e.orderId),original.map(e=>e.orderId));
  assert.equal(s.specialties[0].margin,null);assert.deepEqual(s.specialties[1],original[1]);
  const before=JSON.stringify(s);restoreSpecialties(s);assert.equal(JSON.stringify(s),before);
});
test('validation rejects duplicate, missing or mismatched milestone evidence',()=>{
  const s=shop();send(s,'rush');send(s,'master');
  for(const alter of [a=>a.reverse(),a=>a.pop(),a=>a.push(a[0]),a=>{a[0].orderId=a[1].orderId;},
    a=>{a[1].rework=17;},a=>{a[0].margin=-1;},a=>{a[1].inspectorId=0;}]){
    const bad=structuredClone(s);alter(bad.specialties);assert.equal(M.validate(bad),false);
  }
});
