import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.21';
import {deliveryGuide,floorTicket} from '../../docs/forge-preview/guidance.mjs';
import {repeatOffer,startRepeat,transferPath,neighboringCell,comparisonLine} from '../../docs/forge-preview/improvement.mjs';

function finish(s,fast=true){
  const order=M.frontOrder(s);
  let ticks=0;
  while(order.done<order.qty&&ticks<20000){
    if(fast)ticks+=M.advanceToReady(s,200).ticks;
    else{M.step(s,M.TICK);ticks++;}
  }
  assert.equal(order.done,order.qty);
  assert.equal(M.dispatch(s,order.id),null);
  assert.ok(M.validate(s));
  return s.results[0];
}
function firstShipment(){
  const s=M.fresh();assert.equal(M.accept(s,'first'),null);finish(s);return s;
}
test('the suggested spot is legal and its colored trip is the actual service-to-service route',()=>{
  const s=firstShipment(),drill=repeatOffer(s).drill,snapshot=JSON.stringify(s),cells=[];
  for(let x=1;x<s.width;x++)for(let y=0;y<s.height-1;y++){
    if((x!==drill.x||y!==drill.y)&&M.canPlace(s,'drill',x,y,drill.id))cells.push({x,y});
  }
  const suggested=neighboringCell(s,drill,cells);
  assert.deepEqual(suggested,{x:3,y:1});
  assert.equal(transferPath(s,drill).length-1,3);
  assert.deepEqual(transferPath(s,drill,suggested),[{x:2,y:2},{x:3,y:2}]);
  assert.equal(neighboringCell(s,drill,[]),null);
  assert.equal(JSON.stringify(s),snapshot);
});

for(const [choice,investment] of [['move',0],['upgrade',1500]]){
  test(choice+' repeats the measured order at the posted cost, once, with the same result on skip and reload',()=>{
    const s=firstShipment(),baseline=s.results[0],cash=s.cash,cell={x:3,y:1};
    assert.equal(startRepeat(s,choice,cell),null);
    const afterStart=JSON.stringify(s);
    assert.equal(s.cash,cash-investment-600);assert.equal(M.frontOrder(s).repeatCost,investment);
    assert.ok(startRepeat(s,choice,cell));assert.equal(JSON.stringify(s),afterStart);
    const drill=s.machines.find(m=>m.kind==='drill');
    assert.equal(drill.level,choice==='upgrade'?2:1);assert.equal(drill.x,choice==='move'?3:5);
    assert.match(floorTicket(s).hint,/前回の完成/);
    assert.equal(M.offerStatus(s,'rush').qualified,choice==='upgrade');
    for(let i=0;i<107;i++)M.step(s,M.TICK);
    const restored=JSON.parse(JSON.stringify(s));
    const r=finish(s),other=finish(restored,false);
    assert.deepEqual(r,other);assert.equal(r.repeatCost,investment);
    assert.deepEqual(M.previousResult(s,r),baseline);
    assert.ok(Math.abs(s.cash-cash-(M.resultProfit(r)-investment))<1e-6);
    const comparison=comparisonLine(s,r);
    assert.match(comparison,/短縮.*移動.*減/);
    assert.equal(comparison,comparisonLine(restored,other));
    assert.equal(deliveryGuide(s).primary.id,'rush');
    assert.equal(repeatOffer(s).report.orderId,r.orderId);
  });
}
test('an occupied or unchanged tile, insufficient combined funds and an invalid choice spend nothing',()=>{
  const s=firstShipment();
  for(const [mode,cell] of [['move',{x:2,y:1}],['move',{x:5,y:1}],['move',null],['wrong',null]]){
    const before=JSON.stringify(s);assert.ok(startRepeat(s,mode,cell));assert.equal(JSON.stringify(s),before);
  }
  s.cash=2099.99;
  const before=JSON.stringify(s);assert.ok(startRepeat(s,'upgrade'));assert.equal(JSON.stringify(s),before);
  s.cash=2100;assert.equal(startRepeat(s,'upgrade'),null);assert.equal(s.cash,0);
});
test('existing higher-level tools use their actual price and highest level cannot be charged',()=>{
  const s=firstShipment();assert.equal(M.upgrade(s,'m2'),null);
  assert.equal(repeatOffer(s).upgradeCost,3000);
  const max=structuredClone(s);assert.equal(M.upgrade(max,'m2'),null);
  const before=JSON.stringify(max);assert.ok(startRepeat(max,'upgrade'));assert.equal(JSON.stringify(max),before);
  const cash=s.cash;assert.equal(startRepeat(s,'upgrade'),null);assert.equal(s.cash,cash-3600);
  assert.equal(M.frontOrder(s).repeatCost,3000);
});
test('a current commitment, missing funds, legacy report or relief job alone does not start the improvement flow',()=>{
  const s=firstShipment();
  for(const alter of [
    k=>M.accept(k,'relief'),k=>{k.cash=599;},k=>{delete k.results;}
  ]){
    const k=structuredClone(s);alter(k);const before=JSON.stringify(k);
    assert.equal(repeatOffer(k),null);assert.ok(startRepeat(k,'upgrade'));assert.equal(JSON.stringify(k),before);
  }
  const relief=M.fresh();M.accept(relief,'relief');finish(relief);
  assert.equal(repeatOffer(relief),null);assert.equal(comparisonLine(relief,relief.results[0]),'');
});
test('comparisons use the matching offer, including slower trips and rounded ties',()=>{
  const s=firstShipment(),first=s.results[0];
  M.accept(s,'relief');finish(s);
  assert.equal(comparisonLine(s,s.results[0]),'');
  M.accept(s,'first');const current=finish(s);
  assert.equal(M.previousResult(s,current).orderId,first.orderId);
  Object.assign(current,{seconds:first.seconds+2.71,walk:first.walk+5.9});
  assert.equal(comparisonLine(s,current),'同じ注文の前回比　2.7秒増加・移動6マス増');
  Object.assign(current,{seconds:first.seconds+.003,walk:first.walk+.02});
  assert.equal(comparisonLine(s,current),'同じ注文の前回比　時間同じ・移動同じ');
  assert.equal(comparisonLine(s,null),'');
});
test('repeat expenses are optional on old saves and invalid attributions are rejected',()=>{
  const s=firstShipment();assert.ok(M.validate(s));
  M.accept(s,'relief');let order=M.frontOrder(s);order.repeatCost=1500;assert.equal(M.validate(s),false);
  delete order.repeatCost;finish(s);s.results[0].repeatCost=0;assert.equal(M.validate(s),false);
  delete s.results[0].repeatCost;s.results[1].repeatCost=-600;assert.equal(M.validate(s),false);
});

test('a returning factory can explicitly repeat its last retained 12-piece order while keeping its growth goal',()=>{
  const s=firstShipment(),first=s.results[0];
  M.accept(s,'relief');finish(s);
  assert.equal(floorTicket(s).action.panel,'growth');
  M.setGoal(s,'master');
  const next=floorTicket(s).action;
  assert.notEqual(next.panel,'improve');
  assert.equal(repeatOffer(s).report.orderId,first.orderId);
  assert.equal(startRepeat(s,'move',{x:3,y:1}),null);
  const r=finish(s);
  assert.equal(M.previousResult(s,r).orderId,first.orderId);
  assert.equal(s.goalOffer,'master');
  assert.notEqual(floorTicket(s).action.panel,'improve');
});
