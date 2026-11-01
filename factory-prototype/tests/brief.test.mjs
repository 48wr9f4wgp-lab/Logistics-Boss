import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.24';
import {assessBrief,briefTarget,briefOutcomeText,earnedBriefs} from '../../docs/forge-preview/brief.mjs?v=0.24';
import {startRepeat} from '../../docs/forge-preview/improvement.mjs?v=0.24';

function complete(s){
  let ready;
  do{ready=M.advanceToReady(s,200);}while(ready.status==='producing');
  assert.equal(ready.status,'ready');
  return M.frontOrder(s);
}
function firstReceipt(){
  const s=M.fresh();M.accept(s,'first');M.dispatch(s,complete(s).id);
  assert.equal(s.results[0].briefBonus,undefined);
  return s;
}
// One order seed with layout, pay and skill held constant for each comparison.
const first=firstReceipt(),dest=x=>[{id:'m3',x,y:1}];

test('option labels, preview, and payout use the precision displayed to players',()=>{
  assert.equal(briefTarget('speed'),'完成108.0秒以内');
  assert.equal(briefTarget('walk'),'総移動225マス以内');
  assert.deepEqual(assessBrief('speed',{seconds:108.04}),{value:108,met:true,bonus:400});
  assert.deepEqual(assessBrief('speed',{seconds:108.06}),{value:108.1,met:false,bonus:0});
  assert.equal(assessBrief('walk',{walk:225.499}).met,true);
  assert.equal(assessBrief('walk',{walk:225.5}).met,false);
  assert.match(briefOutcomeText('speed',{seconds:106.6},true),/達成見込.*余裕1.4秒.*400/);
  assert.match(briefOutcomeText('walk',{walk:232}),/未達.*232マス／225マス.*あと7マス/);
  for(const id of ['toString','__proto__',{},null])assert.equal(assessBrief(id,{seconds:0}),null);
  for(const bad of [NaN,-1,Infinity,null,undefined])assert.equal(assessBrief('walk',{walk:bad}),null);
});
for(const [id,x,bonus] of [['speed',4,400],['speed',6,0],['walk',4,0],['walk',6,400]]){
  test(id+' repeat at column '+(x+1)+' earns '+bonus+' once after real production',()=>{
    let s=structuredClone(first);
    assert.equal(startRepeat(s,'layout',dest(x),id),null);
    const n=M.frontOrder(s),orderId=n.id;
    assert.equal(n.briefId,id);assert.equal(n.repeatCost,0);assert.equal(s.cash,first.cash-600);
    assert.equal(M.shipmentQuote(s,n).pay,2800);
    assert.equal(M.shipmentQuote(s,n).briefBonus,0);
    const initial=JSON.stringify(s);assert.ok(M.dispatch(s,orderId));assert.equal(JSON.stringify(s),initial);
    for(let i=0;i<230;i++)M.step(s,M.TICK);
    s=JSON.parse(JSON.stringify(s));assert.ok(M.validate(s));assert.equal(M.frontOrder(s).briefId,id);
    complete(s);const q=M.shipmentQuote(s,M.frontOrder(s)),cash=s.cash,revenue=s.revenue;
    assert.deepEqual(q,{late:false,pay:2800+bonus,briefBonus:bonus});
    assert.equal(M.dispatch(s,orderId),null);
    const r=s.results[0];
    assert.equal(r.briefBonus,bonus);assert.equal(r.briefId,id);
    assert.equal(s.cash,cash+q.pay);assert.equal(s.revenue,revenue+q.pay);
    assert.equal(M.resultProfit(r),q.pay-r.material-r.wages);
    assert.ok(M.validate(JSON.parse(JSON.stringify(s))));
    assert.ok(M.dispatch(s,orderId));assert.equal(s.revenue,revenue+q.pay);
  });
}
test('a late dispatch discounts only the base while a completed condition survives shipping delay',()=>{
  const s=structuredClone(first);startRepeat(s,'layout',dest(4),'speed');const n=complete(s);
  s.clock=n.start+n.due+1;
  const q=M.shipmentQuote(s,n);
  assert.deepEqual(q,{late:true,pay:2780,briefBonus:400});
  M.dispatch(s,n.id);assert.ok(M.validate(s));assert.equal(s.results[0].payout,2780);
});
test('conditions require a valid layout repeat and cannot alter a save on rejection or retry',()=>{
  const s=structuredClone(first),prior=structuredClone(s);
  for(const [choice,moves,id] of [['upgrade',null,'speed'],['move',{x:3,y:1},'walk'],
    ['layout',[],'toString'],['layout',[],''],['layout',[{id:'m2',x:0,y:1}],'walk']]){
    assert.ok(startRepeat(s,choice,moves,id));assert.deepEqual(s,prior);
  }
  assert.equal(startRepeat(s,'layout',[],'walk'),null);
  const accepted=structuredClone(s);
  assert.ok(startRepeat(s,'layout',[],'speed'));assert.deepEqual(s,accepted);
});
test('legacy receipts remain valid, inconsistent signed receipts and partial bonus records are rejected',()=>{
  assert.ok(M.validate(first));const unsigned=structuredClone(first);
  startRepeat(unsigned,'layout',[]);M.dispatch(unsigned,complete(unsigned).id);
  assert.ok(M.validate(unsigned));assert.equal(unsigned.results[0].briefId,undefined);
  const s=structuredClone(first);startRepeat(s,'layout',dest(6),'walk');M.dispatch(s,complete(s).id);
  for(const change of [
    t=>{t.results[0].briefId='unknown';},t=>{t.results[0].briefId='speed';},t=>{t.results[0].payout=2800;},
    t=>{t.results[0].briefBonus=0;},t=>{delete t.results[0].briefId;},t=>{delete t.orders[0].briefId;},
    t=>{t.results[0].repeatCost=1500;},t=>{t.orders[0].briefBonus=400;},t=>{t.results[0].walk=310;}
  ]){
    const forged=structuredClone(s);change(forged);assert.equal(M.validate(forged),false);
  }
  // An older signed receipt still validates after a new order replaces the shipped copy.
  M.accept(s,'relief');M.dispatch(s,complete(s).id);assert.ok(M.validate(s));
  assert.equal(s.results[1].briefBonus,400);
});

function deliverBrief(s,id,moves){
  assert.equal(startRepeat(s,'layout',moves,id),null);
  const running=complete(s),cash=s.cash;
  assert.equal(M.dispatch(s,running.id),null);
  const r=s.results[0];assert.equal(s.cash,cash+r.payout);
  assert.ok(M.validate(s));return r;
}
for(const firstId of ['speed','walk']){
  test('both kinds earn the referral in '+firstId+'-first order; factory still has to fund and produce rush',()=>{
    const s=structuredClone(first);
    const firstMoves=firstId==='speed'?dest(4):dest(6);
    assert.equal(deliverBrief(s,firstId,firstMoves).briefBonus,400);
    assert.deepEqual(earnedBriefs(s),[firstId]);assert.equal(M.offerStatus(s,'rush').qualified,false);
    const nextId=firstId==='speed'?'walk':'speed';
    const nextMoves=nextId==='walk'?[{id:'m2',x:3,y:1}]:dest(4);
    assert.equal(deliverBrief(s,nextId,nextMoves).briefBonus,400);
    assert.deepEqual(earnedBriefs(s),['speed','walk']);
    assert.equal(s.log.filter(line=>line.includes('短納期便の紹介')).length,1);
    assert.equal(M.frontOrder(s),null);assert.ok(s.machines.every(m=>m.level===1));
    assert.equal(s.machines.filter(m=>m.kind==='drill').length,1);
    const plan=M.growthPlan(s,'rush');
    assert.equal(plan.phase,'ready');assert.equal(plan.investment,0);assert.equal(plan.required,1800);
    const short=structuredClone(s);short.cash=1799;
    assert.equal(M.offerStatus(short,'rush').qualified,true);assert.equal(M.offerStatus(short,'rush').available,false);
    assert.ok(M.accept(short,'rush'));assert.equal(short.cash,1799);
    const cash=s.cash;assert.equal(M.accept(s,'rush'),null);assert.equal(s.cash,cash-1800);
    assert.ok(M.validate(s));assert.equal(M.frontOrder(s).done,0);
  });
}
test('a failed and two successful repeats of the same goal never earn the referral',()=>{
  const s=structuredClone(first);
  assert.equal(deliverBrief(s,'walk',dest(4)).briefBonus,0);assert.deepEqual(earnedBriefs(s),[]);
  for(let i=0;i<2;i++)assert.equal(deliverBrief(s,'speed',[]).briefBonus,400);
  assert.deepEqual(earnedBriefs(s),['speed']);assert.equal(M.growthPlan(s,'rush').phase,'prepare');
  assert.equal(M.offerStatus(s,'rush').qualified,false);
  const withDrill=structuredClone(s);M.upgrade(withDrill,'m2');
  assert.equal(M.offerStatus(withDrill,'rush').qualified,true);
});
test('legacy history migrates credits before receipts rotate and invalid credit lists are rejected',()=>{
  const s=structuredClone(first);
  deliverBrief(s,'walk',dest(6));deliverBrief(s,'speed',dest(4));
  delete s.briefCredits;
  assert.ok(M.validate(s));assert.equal(M.offerStatus(s,'rush').qualified,true);
  for(let i=0;i<14;i++){assert.equal(M.accept(s,'relief'),null);M.dispatch(s,complete(s).id);}
  assert.equal(s.results.length,12);assert.ok(s.results.every(r=>r.briefId===undefined));
  assert.deepEqual(s.briefCredits,['speed','walk']);assert.ok(M.validate(JSON.parse(JSON.stringify(s))));
  assert.equal(M.offerStatus(s,'rush').qualified,true);
  for(const bad of ['walk',['speed','speed'],['other'],[null],{},['speed','walk','other']]){
    assert.equal(M.validate({...s,briefCredits:bad}),false);
  }
  assert.equal(M.validate({...first,briefCredits:['walk']}),false);
});
