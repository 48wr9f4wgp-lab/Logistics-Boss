import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.21';
import {startRepeat} from '../../docs/forge-preview/improvement.mjs?v=0.21';
import {acceptPrecision} from '../../docs/forge-preview/precision.mjs?v=0.21';
import {estimateOrder} from '../../docs/forge-preview/estimate.mjs?v=0.21';
import {decideInquiry,inquiryContext,advanceToReview} from '../../docs/forge-preview/inquiry.mjs?v=0.21';
import {pairResult} from '../../docs/forge-preview/pairing.mjs?v=0.21';

function finish(s){
  let q;do{q=M.advanceToReady(s,200);}while(q.status==='producing');
  assert.equal(q.status,'ready');assert.equal(M.dispatch(s,q.orderId),null);
  assert.ok(M.validate(s));return s.results[0];
}
function factory(offer='rush'){
  const s=M.fresh();M.accept(s,'first');finish(s);
  if(offer==='master'){
    M.purchase(s,'lathe',3,2);acceptPrecision(s,{offer:'fine'});finish(s);
    acceptPrecision(s,{offer:'master',inspector:1,investment:'train'});
  }else{
    startRepeat(s,'upgrade');finish(s);M.move(s,'m3',1,1);M.accept(s,offer);
  }
  return s;
}
const forecast=(s,primaryId,priority,extraId=null)=>estimateOrder(s,{inquiry:{primaryId,extraId,priority}});
for(const offer of ['rush','bulk','master'])for(const priority of ['primary','extra']){
  test(offer+' with '+priority+' priority: a real pair matches its estimate and pays exactly once',()=>{
    const s=factory(offer),p=M.frontOrder(s),id=p.id,before=JSON.stringify(s),cash=s.cash;
    const solo=forecast(s,id,'solo').primary,quote=forecast(s,id,priority);
    assert.equal(JSON.stringify(s),before);
    assert.equal(decideInquiry(s,id,priority,solo),null);
    assert.equal(s.cash,cash);assert.ok(M.validate(s));
    const extraId=inquiryContext(s).extra.id,after=JSON.stringify(s);
    assert.ok(decideInquiry(s,id,priority,solo));assert.equal(JSON.stringify(s),after);
    for(let i=0;i<95;i++)M.step(s,M.TICK);
    const restored=JSON.parse(JSON.stringify(s));
    const first=finish(restored);
    assert.equal(first.pair.peer,undefined);assert.equal(pairResult(first),null);
    assert.equal(inquiryContext(restored),null);
    // The first receipt may be written while the second job is still in flight.
    const reopened=JSON.parse(JSON.stringify(restored)),second=finish(reopened),summary=pairResult(second);
    assert.equal(summary.profit,quote.profit);assert.equal(summary.delta,quote.profit-solo.profit);
    assert.deepEqual(pairResult(reopened.results[1]),summary);
    assert.equal(summary.primaryLate,quote.primary.late);assert.equal(summary.extraLate,quote.extra.late);
    const primary=reopened.results.find(r=>r.orderId===id),extra=reopened.results.find(r=>r.orderId===extraId);
    assert.equal(primary.seconds,quote.primary.seconds);assert.equal(extra.seconds,quote.extra.seconds);
    assert.ok(Math.abs(reopened.cash-cash-(primary.payout+extra.payout-primary.wages-extra.wages))<1e-6);
    const paid=reopened.cash;assert.ok(M.dispatch(reopened,second.orderId));assert.equal(reopened.cash,paid);
    if(offer==='rush')assert.equal(Math.round(summary.delta),priority==='primary'?824:-106);
    if(offer==='bulk')assert.equal(Math.round(summary.delta),priority==='primary'?824:974);
    if(offer==='master')assert.equal(primary.inspectorId,1);
  });
}
test('halfway defers the actual offer, pays real payroll and brings both deadlines within reach',()=>{
  const s=factory(),control=structuredClone(s),id=M.frontOrder(s).id,cash=s.cash;
  let q;do{q=advanceToReview(s,id,14,73);}while(q.status==='producing');
  while(M.frontOrder(control).done<14)M.step(control,M.TICK);
  assert.deepEqual(s,control);assert.ok(s.cash<cash);assert.equal(M.frontOrder(s).done,14);
  const estimate=forecast(s,id,'primary');assert.equal(Math.round(estimate.profit),6236);
  assert.equal(estimate.primary.late,false);assert.equal(estimate.extra.late,false);
  assert.equal(decideInquiry(s,id,'primary',forecast(s,id,'solo').primary),null);
  assert.equal(M.frontOrder(s).start+M.frontOrder(s).due,control.orders.at(-1).start+200);
  assert.equal(s.orders.at(-1).start,s.clock);
});
test('an explicit decline persists, but opening or cancelling a quote never declines or advances production',()=>{
  const s=factory(),id=M.frontOrder(s).id,prior=JSON.stringify(s);
  forecast(s,id,'primary');forecast(s,id,'extra');assert.equal(JSON.stringify(s),prior);
  const solo=forecast(s,id,'solo').primary;
  assert.equal(decideInquiry(s,id,'decline',solo),null);
  assert.equal(s.cash,JSON.parse(prior).cash);assert.equal(inquiryContext(JSON.parse(JSON.stringify(s))),null);
  assert.ok(decideInquiry(s,id,'extra'));assert.equal(advanceToReview(s,id,14,100).ticks,0);
  const r=finish(s);assert.equal(r.pair,undefined);assert.equal(r.declinedExtra.solo.profit,M.resultProfit(r));
});
test('switching priority preserves current assignments, both order clocks, money and the original baseline',()=>{
  const s=factory('master'),id=M.frontOrder(s).id,solo=forecast(s,id,'solo').primary;
  decideInquiry(s,id,'extra',solo);
  for(let i=0;i<373;i++)M.step(s,M.TICK);
  const {extra}=inquiryContext(s),est=forecast(s,id,'primary',extra.id);
  const jobs=JSON.stringify(s.workers),cash=s.cash,starts=s.orders.map(o=>o.start);
  assert.equal(decideInquiry(s,id,'primary',null,extra.id),null);
  assert.equal(JSON.stringify(s.workers),jobs);assert.equal(s.cash,cash);assert.deepEqual(s.orders.map(o=>o.start),starts);
  assert.equal(extra.pair.solo.profit,solo.profit);
  assert.ok(decideInquiry(s,id,'decline',null,extra.id));
  const r=[finish(s),finish(s)];assert.equal(pairResult(r[1]).profit,est.profit);
  assert.deepEqual(pairResult(r[1]),pairResult(s.results[1]));
});
test('receipt totals survive history turnover and actual late dispatch, without inventing an unavailable baseline',()=>{
  const s=factory(),id=M.frontOrder(s).id;
  decideInquiry(s,id,'extra',null);
  const early=finish(s);assert.equal(early.offerId,'relief');
  // Same state shape as a partner receipt that has rolled out of the retained history.
  s.results=s.results.filter(r=>r.orderId!==early.orderId);
  s.orders=s.orders.filter(o=>!o.shipped);
  assert.ok(M.validate(s));for(let i=0;i<5000;i++)M.step(s,M.TICK);
  const later=finish(s),result=pairResult(later);assert.equal(result.primaryLate,true);
  assert.equal(result.delta,null);assert.equal(result.profit,M.resultProfit(early)+M.resultProfit(later));
});
test('missing, stale or corrupt links are rejected, and initial orders keep their original flow',()=>{
  const opening=M.fresh();M.accept(opening,'first');assert.equal(inquiryContext(opening),null);
  const s=factory(),p=M.frontOrder(s);const before=JSON.stringify(s);
  assert.ok(decideInquiry(s,p.id+99,'extra'));assert.ok(decideInquiry(s,p.id,'bogus'));
  assert.equal(JSON.stringify(s),before);decideInquiry(s,p.id,'primary');const e=s.orders.at(-1);
  assert.equal(M.validate(s),true);e.pair.priority='extra';assert.equal(M.validate(s),false);
  e.pair.priority='primary';p.pair.peer={id:e.id,profit:10,late:false};assert.equal(M.validate(s),false);
  delete p.pair.peer;s.orders=s.orders.filter(o=>o.id!==e.id);assert.equal(M.validate(s),false);
});

test('finishing one side releases the slot without granting the old priority to an unrelated third job',()=>{
  const s=factory('master'),id=M.frontOrder(s).id,solo=forecast(s,id,'solo').primary;
  decideInquiry(s,id,'extra',solo);
  const small=finish(s);assert.equal(small.offerId,'relief');
  assert.equal(M.accept(s,'bulk'),null);assert.equal(inquiryContext(s),null);
  const comparison=structuredClone(s);
  // Remove only the association on the comparison copy. Work must schedule identically.
  for(const o of comparison.orders)delete o.pair;for(const r of comparison.results)delete r.pair;
  for(let i=0;i<400;i++){M.step(s,M.TICK);M.step(comparison,M.TICK);}
  assert.deepEqual(s.workers,comparison.workers);assert.deepEqual(s.parts,comparison.parts);
  const reports=[finish(s),finish(s)],parent=reports.find(r=>r.orderId===id);
  assert.equal(pairResult(parent).profit,M.resultProfit(small)+M.resultProfit(parent));
  assert.equal(reports.find(r=>r.offerId==='bulk').pair,undefined);
});
