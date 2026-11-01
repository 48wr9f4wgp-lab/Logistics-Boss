import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.20';
import {estimateOrder} from '../../docs/forge-preview/estimate.mjs';
import {createEstimator} from '../../docs/forge-preview/estimate-client.mjs';
import {startRepeat,transferPath} from '../../docs/forge-preview/improvement.mjs?v=0.20';
import {deliveryGuide,floorTicket} from '../../docs/forge-preview/guidance.mjs';

function finish(s){
  for(let ticks=0;ticks<24000;ticks++){
    const o=M.frontOrder(s);
    if(o.done===o.qty){
      assert.equal(M.dispatch(s,o.id),null);
      return s.results[0];
    }
    M.step(s,M.TICK);
  }
  assert.fail('production stalled');
}
function base(){
  const s=M.fresh();M.accept(s,'first');finish(s);return s;
}
function invested(){
  const s=base();assert.equal(startRepeat(s,'upgrade'),null);finish(s);return s;
}
function checkReceipt(q,r){
  assert.equal(q.seconds,r.seconds);assert.equal(q.profit,M.resultProfit(r));
  assert.equal(q.payout,r.payout);assert.equal(q.walk,r.walk);assert.equal(q.late,r.late);
}

test('two payment terms use actual wages, reductions and the production schedule without spending',()=>{
  const s=invested(),before=JSON.stringify(s);
  for(const id of ['bulk','rush']){
    const quote=estimateOrder(s,{offer:id});
    const play=structuredClone(s);M.accept(play,id);checkReceipt(quote,finish(play));
    assert.equal(quote.late,id==='rush');
    assert.equal(Math.round(quote.profit),id==='rush'?4177:4457);
  }
  assert.equal(JSON.stringify(s),before);
});
test('a short service trip can slow down the whole order, and every legal candidate agrees with actual work',()=>{
  const s=base(),before=JSON.stringify(s),control=estimateOrder(s,{offer:'first'});
  let checked=0;
  for(let y=0;y<s.height-1;y++)for(let x=1;x<s.width;x++){
    const cell={x,y},play=structuredClone(s);
    if(startRepeat(play,'move',cell))continue;
    const quote=estimateOrder(s,{repeat:'move',cell});checkReceipt(quote,finish(play));checked++;
    if(x===1&&y===0){
      assert.ok(transferPath(s,s.machines[1],cell).length<transferPath(s,s.machines[1]).length);
      assert.ok(quote.seconds>control.seconds);
    }
  }
  assert.equal(checked,28);assert.equal(JSON.stringify(s),before);
});
test('proposed inspection relocation passes a previously missed deadline; confirmation moves only the tool',()=>{
  const s=invested(),before=JSON.stringify(s);
  const move={id:'m3',x:1,y:1},q=estimateOrder(s,{offer:'rush',move});
  assert.equal(JSON.stringify(s),before);assert.equal(q.late,false);assert.equal(q.payout,7200);
  const cash=s.cash;assert.equal(M.move(s,move.id,move.x,move.y),null);
  assert.equal(s.cash,cash);assert.equal(M.frontOrder(s),null);
  assert.deepEqual(q,estimateOrder(s,{offer:'rush'}));
  M.accept(s,'rush');checkReceipt(q,finish(s));
});
test('the estimate dispatches another commitment when ready and correctly allocates shared labor',()=>{
  const s=invested();M.accept(s,'relief');
  for(let i=0;i<120;i++)M.step(s,M.TICK);
  const q=estimateOrder(s,{offer:'rush'}),restored=JSON.parse(JSON.stringify(s));
  M.accept(restored,'rush');
  assert.equal(finish(restored).offerId,'relief');checkReceipt(q,finish(restored));
  assert.equal(M.frontOrder(s).offerId,'relief');assert.ok(M.validate(s));
});
test('unaffordable, ineligible, blocked and timed out quotes do not return promises of profit',()=>{
  const s=base();
  for(const opt of [{offer:'rush'},{repeat:'move',cell:{x:2,y:1}},{offer:'unknown'}])assert.ok(estimateOrder(s,opt).error);
  const copy=structuredClone(s);copy.cash=0;assert.ok(estimateOrder(copy,{offer:'bulk'}).error);
  assert.ok(estimateOrder(s,{offer:'first'},3).error);
  const q=estimateOrder(s,{repeat:'upgrade'});assert.equal(q.net,q.profit-1500);
});
test('a missed production deadline is distinguished from a completed order left waiting for dispatch',()=>{
  const s=invested();M.move(s,'m3',1,1);M.accept(s,'rush');
  let ready;do{ready=M.advanceToReady(s,200);}while(ready.status==='producing');
  for(let i=0;i<200;i++)M.step(s,M.TICK);
  M.dispatch(s,ready.orderId);const report=s.results[0];
  assert.ok(report.late&&report.seconds<200);
  assert.match(deliveryGuide(s).body,/完成から出荷/);
  assert.match(floorTicket(s,{shipment:report}).hint,/製作は納期内/);
});
test('rapid candidate changes coalesce; cancelled and superseded workers cannot publish stale rows',()=>{
  const workers=[],shown=[];
  const factory=()=>{const worker={messages:[],postMessage(m){this.messages.push(m);},terminate(){this.stopped=true;}};
    workers.push(worker);return worker;};
  const client=createEstimator(factory);
  for(const term of ['a','b','c'])client.request({},[term],rows=>shown.push([term,rows]));
  const first=workers[0];
  assert.equal(first.messages.length,1);first.onmessage({data:['old']});
  assert.deepEqual(shown,[]);assert.deepEqual(first.messages.map(m=>m.scenarios),[['a'],['c']]);
  first.onmessage({data:['latest']});assert.deepEqual(shown,[['c',['latest']]]);
  client.request({},['d'],rows=>shown.push(['d',rows]));const stale=first.onmessage;
  client.cancel();assert.ok(first.stopped);
  client.request({},['e'],rows=>shown.push(['e',rows]));stale({data:['discard']});
  workers[1].onmessage({data:['real']});
  assert.deepEqual(shown,[['c',['latest']],['e',['real']]]);
});
test('worker startup failure returns an unavailable quote and leaves next requests usable',()=>{
  let calls=0,picture;
  const client=createEstimator(()=>{
    if(!calls++)throw new Error('unavailable');
    return picture={postMessage(){},terminate(){}};
  });
  const seen=[];
  client.request({},[],r=>seen.push(r));client.request({},[],r=>seen.push(r));picture.onmessage({data:['ok']});
  assert.deepEqual(seen,[null,['ok']]);
});

test('only a quote seen at acceptance persists; later work and manual dispatch can change the actual profit',()=>{
  const s=invested(),quote=estimateOrder(s,{offer:'bulk'});
  M.accept(s,'bulk',quote);M.accept(s,'first');
  const restored=JSON.parse(JSON.stringify(s));
  assert.ok(M.validate(restored));
  let r;do{r=finish(restored);}while(r.offerId!=='bulk');
  assert.deepEqual(r.quote,{seconds:quote.seconds,profit:quote.profit});
  assert.notEqual(r.seconds,quote.seconds);
  assert.ok(M.validate(restored));
  assert.equal(restored.results.find(r=>r.offerId==='first').quote,undefined);
  r.quote.profit=Infinity;assert.equal(M.validate(restored),false);
});
