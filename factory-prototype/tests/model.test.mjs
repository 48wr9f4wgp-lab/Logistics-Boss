import test from 'node:test';import assert from 'node:assert/strict';import * as M from '../../docs/forge-preview/model.mjs';
function finish(s,limit=2000){let i=0;while(s.parts.some(p=>!p.done)&&i++<limit*10)M.step(s,.1);assert.ok(i<limit*10,'production must finish');return s.clock;}
test('first order: purchase materials, finish with three workers, pay exactly once',()=>{const s=M.fresh();assert.equal(M.accept(s,'first'),null);assert.equal(s.cash,4900);finish(s);assert.equal(s.orders[0].done,12);assert.ok(s.stats.walk>0);const before=s.cash;assert.equal(M.dispatch(s,s.orders[0].id),null);assert.equal(s.cash-before,2800);assert.ok(M.dispatch(s,s.orders[0].id));assert.equal(s.cash-before,2800);assert.equal(s.parts.length,0);});
test('lathe unlock and two orders sharing one cutter; no duplicated work',()=>{const s=M.fresh();assert.ok(M.accept(s,'fine'));M.accept(s,'first');finish(s);M.dispatch(s,s.orders[0].id);assert.equal(M.purchase(s,'lathe',3,3),null);assert.equal(M.accept(s,'fine'),null);assert.equal(M.accept(s,'relief'),null);assert.ok(M.accept(s,'first'));for(let i=0;i<5000;i++){M.step(s,.1);const assigned=s.workers.flatMap(w=>w.job?[w.job.machine]:[]);assert.equal(new Set(assigned).size,assigned.length);}assert.ok(s.orders.filter(o=>!o.shipped).every(o=>o.done===o.qty));assert.ok(s.stats.rework>0);});
test('training and equipment upgrades improve throughput',()=>{const base=M.fresh(),improved=M.fresh();improved.cash=20000;for(const w of improved.workers)M.train(improved,w.id);for(const m of improved.machines)M.upgrade(improved,m.id);M.accept(base,'bulk');M.accept(improved,'bulk');assert.ok(finish(improved)<finish(base));});
test('placement affects travel and cannot block service access or overlap',()=>{const a=M.fresh(),b=M.fresh();assert.equal(M.move(b,'m2',3,1),null);assert.equal(M.move(b,'m3',4,1),null);M.accept(a,'bulk');M.accept(b,'bulk');finish(a);finish(b);assert.ok(b.stats.walk<a.stats.walk);assert.equal(M.canPlace(a,'drill',2,1),false);assert.equal(M.canPlace(a,'cut',-1,0),false);assert.equal(M.canPlace(a,'cut',2,5),false);});
test('placement refuses active work, costs cannot overspend, rescue order stays available',()=>{const s=M.fresh();s.cash=0;assert.ok(M.accept(s,'first'));assert.ok(M.train(s,0));assert.ok(M.purchase(s,'lathe',3,3));assert.equal(M.accept(s,'relief'),null);M.step(s,.1);assert.ok(M.move(s,'m1',3,2));finish(s);M.dispatch(s,s.orders[0].id);assert.ok(s.cash>0);assert.ok(M.sell(s,'m1'));});
test('serialize mid-walk and mid-work restores exact ongoing simulation',()=>{const a=M.fresh();M.accept(a,'first');for(let i=0;i<150;i++)M.step(a,.1);const b=JSON.parse(JSON.stringify(a));assert.equal(M.validate(b),true);finish(a);finish(b);assert.deepEqual(a,b);});
test('expansion, sale and training change state only on valid transactions',()=>{const s=M.fresh();assert.equal(M.expand(s),null);assert.equal(s.width,10);assert.ok(M.expand(s));s.cash=10000;M.purchase(s,'cut',8,2);const m=s.machines.at(-1),cash=s.cash;assert.equal(M.sell(s,m.id),null);assert.equal(s.cash,cash+Math.floor(M.MACHINES.cut.cost*.65));M.train(s,1);assert.equal(s.workers[1].skill,2);});
test('save validation rejects wrong version, negative funds, invalid job and unreachable geometry',()=>{assert.equal(M.validate(M.fresh()),true);for(const mutate of [s=>s.version=2,s=>s.cash=-1,s=>s.machines[0].kind='unknown',s=>s.workers[0].job={part:'bad',machine:'m1',remaining:1,path:[]},s=>s.machines[0].y=6]){const s=M.fresh();mutate(s);assert.equal(M.validate(s),false);}});
test('late orders disclose and apply bounded penalty',()=>{const s=M.fresh();M.accept(s,'relief');finish(s);s.clock=999;const before=s.cash;M.dispatch(s,s.orders[0].id);assert.equal(s.cash-before,850);});
test('malformed saves cannot duplicate a part or assign one machine twice',()=>{const a=M.fresh();M.accept(a,'first');M.step(a,.1);assert.equal(M.validate(a),true);const b=structuredClone(a);b.workers[1].job=structuredClone(b.workers[0].job);assert.equal(M.validate(b),false);const c=structuredClone(a);c.parts.push(structuredClone(c.parts[0]));assert.equal(M.validate(c),false);assert.equal(M.validate({version:1,machines:[null]}),false);});
test('layout pause finishes only assigned stages, then resumes an unfinished order without losing parts',()=>{
 const s=M.fresh();M.accept(s,'bulk');for(let i=0;i<160;i++)M.step(s,.1);
 const ids=s.parts.map(p=>p.id),stages=s.parts.reduce((n,p)=>n+p.stage,0),jobs=s.workers.filter(w=>w.job).length;
 assert.ok(jobs>0);let ticks=0;while(s.workers.some(w=>w.job)&&ticks++<1000)M.step(s,.1,{assignNew:false});
 assert.ok(ticks<1000);assert.equal(s.parts.reduce((n,p)=>n+p.stage,0),stages+jobs);assert.ok(s.orders[0].done<s.orders[0].qty);
 assert.deepEqual(s.parts.map(p=>p.id),ids);assert.equal(M.validate(JSON.parse(JSON.stringify(s))),true);
 let dest=null;for(let x=1;x<s.width;x++)for(let y=0;y<s.height-1;y++)if(M.canPlace(s,'drill',x,y,'m2')&&(x!==5||y!==1))dest={x,y};
 assert.ok(dest);assert.equal(M.move(s,'m2',dest.x,dest.y),null);finish(s);assert.equal(s.orders[0].done,28);assert.equal(s.stats.processed,84);
});
test('new equipment cannot cover unfinished material after a layout pause',()=>{const s=M.fresh();M.accept(s,'first');s.parts[0].x=3;s.parts[0].y=3;assert.equal(M.canPlace(s,'cut',3,3),false);});
test('production board counts every part once across waiting, carrying, working and complete',()=>{
 const s=M.fresh();M.accept(s,'first');M.accept(s,'relief');const original=JSON.stringify(s);const initial=M.production(s);assert.equal(JSON.stringify(s),original);assert.equal(initial.stages.cut.waiting,18);
 for(let t=0;t<1600;t++){M.step(s,.1);if(t%100===0){const p=M.production(s);assert.equal(Object.values(p.stages).reduce((n,q)=>n+q.waiting+q.walking+q.working,p.complete),18);const first=M.production(s,s.orders[0].id);assert.equal(Object.values(first.stages).reduce((n,q)=>n+q.waiting+q.walking+q.working,first.complete),12);}}
});
test('a completed second order is offered for dispatch before an unfinished first one',()=>{const s=M.fresh();M.accept(s,'bulk');M.accept(s,'relief');const second=s.orders[1];for(const p of s.parts.filter(p=>p.order===second.id)){p.stage=3;p.done=true;}second.done=second.qty;second.accounting.completedAt=s.clock;assert.equal(M.validate(s),true);assert.equal(M.frontOrder(s).id,second.id);M.dispatch(s,second.id);assert.equal(M.frontOrder(s).id,s.orders[0].id);});

test('shipment receipt reconciles the actual payroll and excludes investment, and pays only once',()=>{
 const s=M.fresh();M.train(s,0);M.accept(s,'first');const initial=s.cash;finish(s);
 const o=s.orders[0],completed=o.accounting.completedAt,wages=o.accounting.wages;
 assert.ok(Math.abs((initial-s.cash)-wages)<1e-7);for(let i=0;i<2500;i++)M.step(s,.1);
 M.dispatch(s,o.id);const r=s.results[0];assert.equal(r.late,true);assert.equal(r.payout,2380);
 assert.equal(r.seconds,completed-o.start);assert.equal(r.wages,wages);assert.equal(r.walk,s.stats.walk);
 assert.ok(Math.abs(M.resultProfit(r)-(s.cash-initial-o.cost))<1e-7);
 const serialized=JSON.stringify(s);assert.ok(M.dispatch(s,o.id));assert.equal(JSON.stringify(s),serialized);assert.equal(M.validate(s),true);
});
test('two simultaneous orders share actual payroll, completed orders stop accruing it',()=>{
 const s=M.fresh();M.accept(s,'first');M.accept(s,'relief');const before=s.expense;
 M.step(s,.1);assert.equal(s.orders[0].accounting.wages,s.orders[1].accounting.wages);
 let frozen=null;for(let i=0;i<3000&&s.parts.some(p=>!p.done);i++){
  M.step(s,.1);const ready=s.orders.find(o=>o.done===o.qty);
  if(frozen)assert.equal(s.orders.find(o=>o.id===frozen.id).accounting.wages,frozen.wages);
  else if(ready)frozen={id:ready.id,wages:ready.accounting.wages};
 }
 assert.ok(frozen);assert.ok(Math.abs(s.orders.reduce((n,o)=>n+o.accounting.wages,0)-(s.expense-before))<1e-7);
 assert.ok(Math.abs(s.orders.reduce((n,o)=>n+o.accounting.walk,0)-s.stats.walk)<1e-7);
 for(const o of s.orders)assert.equal(o.done,o.qty);assert.equal(M.validate(s),true);
 const poor=M.fresh();poor.cash=.02;M.accept(poor,'relief');finish(poor);M.dispatch(poor,poor.orders[0].id);
 assert.equal(poor.results[0].wages,.02);assert.equal(M.resultProfit(poor.results[0]),999.98);
});
test('legacy in-flight save finishes honestly, then new orders gain full measurements',()=>{
 const s=M.fresh();M.accept(s,'first');for(let i=0;i<120;i++)M.step(s,.1);
 delete s.results;delete s.orders[0].accounting;delete s.orders[0].offerId;
 const legacy=JSON.parse(JSON.stringify(s));assert.equal(M.validate(legacy),true);finish(legacy);
 M.dispatch(legacy,legacy.orders[0].id);assert.equal(legacy.results[0].wages,null);assert.equal(M.resultProfit(legacy.results[0]),null);
 M.accept(legacy,'first');finish(legacy);M.dispatch(legacy,legacy.orders.find(o=>!o.shipped).id);
 assert.ok(legacy.results[0].wages>0);assert.equal(M.previousResult(legacy,legacy.results[0]),null);assert.equal(M.validate(legacy),true);
});
test('same-offer comparisons survive reload and history is bounded without changing receipts',()=>{
 const s=M.fresh();for(let i=0;i<14;i++){M.accept(s,i===12?'first':'relief');finish(s);M.dispatch(s,s.orders.find(o=>!o.shipped).id);}
 assert.equal(s.results.length,12);const r=s.results[0],before=JSON.stringify(s);
 assert.equal(M.previousResult(s,r).orderId,s.results[2].orderId);assert.equal(JSON.stringify(s),before);
 const restored=JSON.parse(before);assert.equal(M.validate(restored),true);assert.deepEqual(restored.results,s.results);
 assert.deepEqual(M.previousResult(restored,restored.results[0]),M.previousResult(s,r));
});
test('receipt shows shorter routes and lower actual wages after layout improvement',()=>{
 const a=M.fresh(),b=M.fresh();M.move(b,'m2',3,1);M.move(b,'m3',4,1);
 for(const s of [a,b]){M.accept(s,'bulk');finish(s);M.dispatch(s,s.orders[0].id);}
 const old=a.results[0],improved=b.results[0];assert.ok(improved.walk<old.walk);assert.ok(improved.seconds<old.seconds);
 assert.ok(improved.wages<old.wages);assert.ok(M.resultProfit(improved)>M.resultProfit(old));
});
test('optional receipt data is validated, including null fields, bounds and duplicates',()=>{
 const s=M.fresh();M.accept(s,'first');finish(s);M.dispatch(s,s.orders[0].id);
 for(const mutate of [
  s=>s.results=null,s=>s.results[0].wages=-1,s=>s.results[0].seconds=null,s=>s.results[0].rework=.5,
  s=>s.results[0].offerId='unknown',s=>s.results[0].payout=999999,s=>s.results[0].seconds=s.clock+1,
  s=>{s.results.push({...s.results[0]});s.delivered++;},s=>s.orders[0].accounting.completedAt=s.clock+1,
  s=>s.orders[0].accounting.wages=NaN,s=>delete s.orders[0].accounting
 ]){const b=structuredClone(s);mutate(b);assert.equal(M.validate(b),false);}
});

test('display quote and payment agree at the exact deadline and a fraction past it',()=>{
 for(const over of [0,.01]){const s=M.fresh();M.accept(s,'relief');finish(s);const o=s.orders[0];s.clock=o.start+o.due+over;
  const before=JSON.stringify(s),quote=M.shipmentQuote(s,o);assert.equal(JSON.stringify(s),before);
  assert.equal(quote.late,over>0);assert.equal(quote.pay,over?850:1000);const cash=s.cash;M.dispatch(s,o.id);assert.equal(s.cash-cash,quote.pay);assert.equal(s.results[0].payout,quote.pay);
 }
});
test('growth contracts reject missing prerequisites without spending or changing state',()=>{
 const s=M.fresh();for(const id of ['rush','master']){const before=JSON.stringify(s);assert.equal(M.offerStatus(s,id).qualified,false);assert.ok(M.accept(s,id));assert.equal(JSON.stringify(s),before);}
 assert.equal(M.offerStatus(s,'first').available,true);assert.equal(M.offerStatus(s,'relief').available,true);
 assert.equal(M.offerStatus(s,'unknown').available,false);
});
test('volume qualification opens with drill upgrade OR a second drill, and funds/slots still apply',()=>{
 for(const option of ['upgrade','second']){const s=M.fresh();assert.equal(option==='upgrade'?M.upgrade(s,'m2'):M.purchase(s,'drill',4,3),null);
  const before=JSON.stringify(s);assert.equal(M.offerStatus(s,'rush').qualified,true);assert.equal(JSON.stringify(s),before);
  assert.equal(M.offerStatus(s,'master').qualified,false);assert.equal(M.accept(s,'rush'),null);M.accept(s,'relief');const full=JSON.stringify(s);
  assert.equal(M.offerStatus(s,'rush').available,false);assert.ok(M.accept(s,'rush'));assert.equal(JSON.stringify(s),full);
 }
 const poor=M.fresh();M.upgrade(poor,'m2');poor.cash=1799;assert.equal(M.offerStatus(poor,'rush').qualified,true);assert.equal(M.offerStatus(poor,'rush').available,false);assert.ok(M.accept(poor,'rush'));assert.equal(poor.cash,1799);assert.equal(M.accept(poor,'relief'),null);
});
test('precision requires BOTH a lathe and skill 3, and natural experience can qualify',()=>{
 const a=M.fresh();a.cash=15000;M.train(a,0);M.train(a,0);assert.equal(M.offerStatus(a,'master').qualified,false);M.purchase(a,'lathe',4,3);assert.equal(M.offerStatus(a,'master').qualified,true);
 const b=M.fresh();b.cash=15000;M.purchase(b,'lathe',4,3);M.train(b,0);assert.equal(M.offerStatus(b,'master').qualified,false);
 b.workers[0].xp=29;M.accept(b,'relief');finish(b);assert.ok(b.workers[0].skill>=3);assert.equal(M.offerStatus(b,'master').qualified,true);
});
test('selling qualifying equipment closes future acceptance without cancelling an accepted order',()=>{
 const s=M.fresh();M.purchase(s,'drill',4,3);const extra=s.machines.at(-1).id;M.accept(s,'rush');assert.equal(M.sell(s,extra),null);
 assert.equal(M.offerStatus(s,'rush').qualified,false);finish(s);assert.equal(M.dispatch(s,s.orders[0].id),null);assert.equal(s.results[0].offerId,'rush');assert.equal(M.validate(s),true);
});
test('both growth contracts serialize mid-job, finish, pay once and preserve receipt validation',()=>{
 for(const id of ['rush','master']){
  const s=M.fresh();s.cash=25000;M.upgrade(s,'m2');M.purchase(s,'lathe',4,3);M.train(s,0);M.train(s,0);
  assert.equal(M.accept(s,id),null);for(let i=0;i<110;i++)M.step(s,.1);const restored=JSON.parse(JSON.stringify(s));assert.equal(M.validate(restored),true);
  finish(s);finish(restored);assert.deepEqual(restored,s);const o=restored.orders[0];assert.equal(o.done,o.qty);M.dispatch(restored,o.id);
  const saved=JSON.stringify(restored);assert.ok(M.dispatch(restored,o.id));assert.equal(JSON.stringify(restored),saved);assert.equal(M.validate(JSON.parse(saved)),true);
 }
});
test('investment paths alter growth-order outcomes: faster volume, less precision rework',()=>{
 function run(id,improve){const s=M.fresh();s.cash=30000;
  if(id==='rush'){M.upgrade(s,'m2');if(improve)for(const m of s.machines)M.upgrade(s,m.id);}
  else{M.purchase(s,'lathe',4,3);M.train(s,0);M.train(s,0);s.workers[0].role='inspect';if(improve)for(const w of s.workers)while(w.skill<3)M.train(s,w.id);}
  M.accept(s,id);finish(s);M.dispatch(s,s.orders[0].id);return s.results[0];
 }
 const slow=run('rush',false),fast=run('rush',true);assert.equal(slow.late,true);assert.equal(fast.late,false);assert.ok(fast.seconds<slow.seconds);assert.ok(M.resultProfit(fast)>M.resultProfit(slow));
 const apprentice=run('master',false),skilled=run('master',true);assert.ok(apprentice.rework>0);assert.equal(skilled.rework,0);assert.ok(skilled.seconds<apprentice.seconds);assert.equal(skilled.late,false);
});
