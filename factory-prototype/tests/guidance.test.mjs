import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.19';
import {openingOffer,deliveryGuide,floorTicket} from '../../docs/forge-preview/guidance.mjs';

function ready(s) {
  for(let i=0;i<120;i++){
    const result=M.advanceToReady(s,200);
    if(result.status==='ready')return s.orders.find(o=>o.id===result.orderId);
    assert.equal(result.status,'producing');
  }
  assert.fail('fixture order did not finish within the normal skip limit');
}
function deliver(s,id='first') {
  assert.equal(M.accept(s,id),null);
  assert.equal(M.dispatch(s,ready(s).id),null);
  assert.equal(M.validate(s),true);
  return s.results[0];
}
function freeze(value) {
  if(value&&typeof value==='object'){
    Object.values(value).forEach(freeze);
    Object.freeze(value);
  }
  return value;
}

test('opening recommends the real 12-piece offer and falls back only when its materials are unaffordable',()=>{
  const s=M.fresh(),before=JSON.stringify(s);
  assert.equal(openingOffer(s),M.OFFERS.find(o=>o.id==='first'));
  assert.equal(JSON.stringify(s),before);
  s.cash=600;assert.equal(openingOffer(s).id,'first');
  s.cash=599.9;assert.equal(openingOffer(s).id,'relief');
  s.cash=0;
  const recommended=openingOffer(s);
  assert.equal(recommended.cost,0);
  assert.equal(M.accept(s,recommended.id),null);
  assert.equal(openingOffer(s),null);
  const order=ready(s);
  assert.equal(openingOffer(s),null,'a finished unshipped order still takes priority');
  assert.equal(M.dispatch(s,order.id),null);
  assert.equal(openingOffer(s),null,'opening advice ends after the first delivery');
});

test('missing or explicitly absent history has no invented delivery guide',()=>{
  const s=M.fresh();
  assert.equal(deliveryGuide(s),null);
  delete s.results;
  assert.equal(deliveryGuide(s),null);
  deliver(s);
  assert.equal(deliveryGuide(s,null),null);
});

test('first plate delivery offers a workshop improvement while keeping growth accessible',()=>{
  const s=M.fresh();deliver(s);
  const guide=deliveryGuide(s);
  assert.equal(guide.heading,'はじめての出荷完了！');
  assert.equal(guide.status,'納期内に納品');
  assert.equal(guide.tone,'success');
  assert.deepEqual(guide.primary,{type:'panel',panel:'improve',label:'工場の改善を選ぶ'});
  assert.equal(guide.secondary.panel,'growth');
  deliver(s,'relief');
  assert.equal(deliveryGuide(s).heading,'出荷完了！');
});

test('the actual funding shortfall of a selected goal precedes spending advice',()=>{
  const s=M.fresh();deliver(s);M.setGoal(s,'master');
  let guide=deliveryGuide(s);
  assert.equal(guide.primary.panel,'orders');
  assert.deepEqual(guide.secondary,{type:'growth',id:'master',label:'準備費を確認'});
  assert.match(guide.body,/¥8,200/);
  assert.match(guide.body,/¥2,200/);
  assert.match(guide.body,/¥2,781/);
  s.cash=10399.9;guide=deliveryGuide(s);
  assert.match(guide.body,/あと ¥1 /,'fractional shortfall must round up');
  assert.match(guide.body,/人件費は別/);
});

test('selected-goal guidance follows actual purchases and training without accepting the contract',()=>{
  const s=M.fresh();deliver(s);M.setGoal(s,'master');s.cash=10400;
  let guide=deliveryGuide(s);
  assert.equal(guide.primary.type,'growth');assert.equal(guide.primary.id,'master');
  assert.match(guide.title,/旋盤を設置/);
  assert.equal(M.purchase(s,'lathe',4,3),null);
  assert.equal(M.train(s,0),null);assert.equal(M.train(s,0),null);
  guide=deliveryGuide(s);
  assert.equal(M.growthPlan(s,'master').phase,'ready');
  assert.match(guide.title,/受注できる/);
  assert.match(guide.body,/¥2,200/);
  assert.equal(s.orders.filter(o=>!o.shipped).length,0);
  assert.equal(s.cash,2200);
  assert.equal(s.goalOffer,'master');
  assert.equal(M.validate(s),true);
});

test('a remaining producing order outranks selected-goal investment guidance',()=>{
  const s=M.fresh();deliver(s);M.setGoal(s,'master');
  assert.equal(M.accept(s,'relief'),null);
  const active=M.frontOrder(s),guide=deliveryGuide(s);
  assert.deepEqual(guide.primary,{type:'skip',id:active.id,label:'残りを完成まで進める'});
  assert.match(guide.body,/人件費・納期も進みます/);
  assert.equal(active.done,0,'guidance itself does not fast-forward');
  assert.equal(guide.secondary,undefined);
});

test('ready work takes precedence even when a producing order appears earlier in saved order order',()=>{
  const s=M.fresh();deliver(s);
  assert.equal(M.accept(s,'relief'),null);
  const complete=ready(s);
  assert.equal(M.accept(s,'first'),null);
  const producing=s.orders.find(o=>!o.shipped&&o.id!==complete.id);
  s.orders.reverse();
  const guide=deliveryGuide(s);
  assert.deepEqual(guide.primary,{type:'ship',id:complete.id,label:'もう1件を出荷する'});
  assert.equal(M.dispatch(s,guide.primary.id),null);
  assert.equal(deliveryGuide(s).primary.id,producing.id);
  assert.equal(deliveryGuide(s).primary.type,'skip');
  assert.equal(M.validate(s),true);
});

test('late growth delivery identifies the deduction and offers a review before retrying',()=>{
  const s=M.fresh();M.upgrade(s,'m2');
  const report=deliver(s,'rush'),guide=deliveryGuide(s);
  assert.equal(report.late,true,'minimum qualification is not a delivery-time guarantee');
  assert.equal(guide.heading,'成長案件を納品！');
  assert.equal(guide.status,'納期超過 · 報酬15%減');
  assert.equal(guide.tone,'late');
  assert.deepEqual(guide.primary,{type:'growth',id:'rush',label:'納期と配置を見直す'});
  assert.match(guide.body,/製作が納期を.+秒超え/);
  assert.equal(guide.secondary.panel,'machines');
  assert.equal(s.goalOffer,undefined,'report guidance does not select a goal');
  assert.equal(M.accept(s,'relief'),null);
  const remaining=deliveryGuide(s);
  assert.equal(remaining.primary.type,'skip','remaining work wins even over a late growth result');
  assert.equal(remaining.status,'納期超過 · 報酬15%減','status continues to describe the shipped report');
});

test('on-time growth delivery offers the actual delivered contract without assuming it was the selected goal',()=>{
  const s=M.fresh();s.cash=50000;
  for(const m of s.machines){M.upgrade(s,m.id);M.upgrade(s,m.id);}
  for(const w of s.workers)for(let i=0;i<3;i++)M.train(s,w.id);
  M.setGoal(s,'master');
  const report=deliver(s,'rush'),guide=deliveryGuide(s);
  assert.equal(report.late,false);
  assert.equal(guide.heading,'成長案件を納品！');
  assert.equal(guide.status,'納期内に納品');
  assert.equal(guide.primary.panel,'growth');
  assert.equal(guide.secondary.type,'growth');assert.equal(guide.secondary.id,'rush');
  assert.equal(s.goalOffer,'master');
  assert.doesNotMatch(JSON.stringify(guide),/初達成|初めての成長|追っていた|永久/);
});

test('legacy reports with no recognized offer retain ordinary guidance and no fabricated growth history',()=>{
  const s=M.fresh();
  assert.equal(M.accept(s,'first'),null);
  const oldOrder=s.orders[0];delete oldOrder.offerId;delete oldOrder.accounting;
  assert.equal(M.validate(s),true);
  assert.equal(M.dispatch(s,ready(s).id),null);
  assert.equal(s.results[0].offerId,null);assert.equal(s.results[0].wages,null);
  assert.equal(deliveryGuide(s).primary.panel,'growth');
  assert.equal(deliveryGuide(s).heading,'はじめての出荷完了！');
  const unknown={...s.results[0],offerId:'unrecognized-old-offer'};
  assert.equal(deliveryGuide(s,unknown).heading,'はじめての出荷完了！');
  assert.equal(M.validate(s),true);
});

test('serialized in-flight continuation produces the same read-only advice and no new save fields',()=>{
  const s=M.fresh();deliver(s);M.setGoal(s,'rush');M.accept(s,'relief');
  for(let i=0;i<70;i++)M.step(s,M.TICK);
  const serialized=JSON.stringify(s),copy=JSON.parse(serialized),keys=Object.keys(copy).sort();
  assert.equal(M.validate(copy),true);
  assert.deepEqual(deliveryGuide(copy),deliveryGuide(s));
  freeze(copy);
  for(let i=0;i<3;i++){deliveryGuide(copy);openingOffer(copy);}
  assert.equal(JSON.stringify(copy),serialized);
  assert.deepEqual(Object.keys(copy).sort(),keys);
  const cash=s.cash,clock=s.clock,report=s.results[0];
  deliveryGuide(s,report);openingOffer(s);
  assert.equal(s.cash,cash);assert.equal(s.clock,clock);assert.equal(JSON.stringify(s),serialized);
});

test('the floor ticket follows the opening through shipment, including paused and reloaded work',()=>{
  const s=M.fresh();
  const first=floorTicket(freeze(structuredClone(s)));
  assert.equal(first.action.id,'first');assert.match(first.action.label,/¥600/);
  M.accept(s,first.action.id);
  let ticket=floorTicket(JSON.parse(JSON.stringify(s)),{paused:true});
  assert.equal(ticket.label,'一時停止中');assert.equal(ticket.action.type,'skip');
  assert.match(ticket.hint,/人件費と納期/);
  assert.equal(floorTicket(s,{skipping:true}).action.type,'stop');
  const order=ready(s);
  ticket=floorTicket(s);assert.equal(ticket.progress,1);assert.equal(ticket.action.id,order.id);
  assert.equal(ticket.action.type,'ship');assert.match(ticket.hint,/2,800/);
  M.dispatch(s,order.id);
  assert.equal(floorTicket(s).action.panel,'improve');
});

test('zero-cost entry, concurrent orders, funding and legacy progress use the same ticket',()=>{
  const s=M.fresh();s.cash=100;
  const relief=floorTicket(s);
  assert.equal(relief.action.id,'relief');assert.match(relief.action.label,/¥0/);
  s.cash=5500;deliver(s);M.setGoal(s,'master');
  assert.equal(floorTicket(s).action.panel,'orders');
  M.accept(s,'first');const first=ready(s);M.accept(s,'relief');s.orders.reverse();
  assert.equal(floorTicket(s).action.id,first.id);
  M.dispatch(s,first.id);
  assert.equal(floorTicket(s).action.type,'skip');
  M.dispatch(s,ready(s).id);
  s.cash=25000;
  assert.equal(floorTicket(s).action.id,'master');
  delete s.goalOffer;delete s.results;
  assert.equal(floorTicket(s).action.panel,'growth');
});

test('a late shipment keeps its review action on the floor until another decision',()=>{
  const s=M.fresh();M.upgrade(s,'m2');M.setGoal(s,'rush');
  const report=deliver(s,'rush');
  assert.equal(report.late,true);
  assert.equal(floorTicket(s,{shipment:report}).action.label,'納期と配置を見直す');
  assert.equal(floorTicket(s).action.id,'rush');
  M.accept(s,'relief');
  assert.equal(floorTicket(s,{shipment:report}).action.type,'skip');
});
