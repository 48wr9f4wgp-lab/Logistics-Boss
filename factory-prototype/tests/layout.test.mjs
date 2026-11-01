import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs?v=0.24';
import {applyLayout,layoutCandidate,layoutPlan,legalLayoutCells,movementReason} from '../../docs/forge-preview/layout.mjs?v=0.24';
import {estimateOrder} from '../../docs/forge-preview/estimate.mjs?v=0.24';
import {startRepeat} from '../../docs/forge-preview/improvement.mjs?v=0.24';

function ship(s){
  const o=M.frontOrder(s);
  for(let i=0;o.done<o.qty&&i<24000;i++)M.step(s,M.TICK);
  assert.equal(M.dispatch(s,o.id),null);return s.results[0];
}
function seed(){
  const s=M.fresh();M.accept(s,'first');ship(s);return s;
}
test('inspection candidates really minimize different measures across all reachable floors',()=>{
  const s=seed(),snapshot=structuredClone(s);
  const {fastest,shortest,checked,legal}=estimateOrder(s,{rankLayout:{id:'m3',offer:'first'}});
  assert.equal(checked,31);assert.equal(checked,legal);
  for(const cell of legalLayoutCells(s,[],'m3')){
    const run=structuredClone(s),draft=layoutCandidate(s,[],'m3',cell);
    run.machines=draft.machines;M.accept(run,'first');
    const receipt=ship(run);
    assert.ok(receipt.seconds>=fastest.quote.seconds-1e-6);
    assert.ok(receipt.walk>=shortest.quote.walk-1e-6);
  }
  assert.deepEqual([fastest.x,fastest.y,fastest.quote.seconds.toFixed(1),Math.round(fastest.quote.walk)],[4,1,'106.6',232]);
  assert.deepEqual([shortest.x,shortest.y,shortest.quote.seconds.toFixed(1),Math.round(shortest.quote.walk)],[6,1,'110.0',220]);
  assert.equal(movementReason(estimateOrder(s,{offer:'first',trace:true}),shortest.quote),'検品担当の移動が75マス減');
  assert.deepEqual(s,snapshot);
});
test('route follows one real part and stage travel accounts for all labor walking',()=>{
  const s=seed(),draft=layoutCandidate(s,[],'m2',{x:3,y:1});
  const q=estimateOrder(s,{offer:'first',layout:draft.moves,trace:true});
  assert.deepEqual(q.legs.map(l=>l.kind),['cut','drill','inspect']);
  assert.ok(Math.abs(Object.values(q.travel).reduce((a,b)=>a+b)-q.walk)<1e-6);
  let last={x:0,y:0};
  for(const leg of q.legs){
    const m=draft.machines.find(m=>m.id===leg.machine);
    assert.deepEqual(leg.path[0],last);
    for(const point of leg.path.slice(1)){
      assert.equal(Math.abs(last.x-point.x)+Math.abs(last.y-point.y),1);
      assert.ok(!draft.machines.some(tool=>tool.x===point.x&&tool.y===point.y));last=point;
    }
    assert.deepEqual(last,{x:m.x,y:m.y+1});
  }
});
test('compose an occupied swap with another move, then bill one real job and match the receipt',()=>{
  const s=seed(),before=structuredClone(s);
  const first=layoutCandidate(s,[],'m3',{x:4,y:1}),combined=layoutCandidate(s,first.moves,'m1',{x:5,y:1});
  assert.equal(combined.swap,'drill');assert.equal(combined.moves.length,3);
  const quote=estimateOrder(s,{offer:'first',layout:combined.moves});
  assert.deepEqual(s,before);
  assert.equal(startRepeat(s,'layout',combined.moves),null);
  assert.deepEqual(s.machines.map(m=>m.id),before.machines.map(m=>m.id));
  assert.deepEqual(s.machines,combined.machines);assert.equal(s.cash,before.cash-600);
  const accepted=structuredClone(s);
  assert.ok(startRepeat(s,'layout',combined.moves));assert.deepEqual(s,accepted);
  const restored=JSON.parse(JSON.stringify(s));assert.ok(M.validate(restored));
  const receipt=ship(restored);assert.equal(receipt.repeatCost,0);
  assert.ok(Math.abs(receipt.seconds-quote.seconds)<1e-6&&Math.abs(receipt.walk-quote.walk)<1e-6);
});
test('unusable floors explain the specific rule and never partially apply a draft',()=>{
  const s=seed(),original=structuredClone(s),at=(x,y)=>layoutCandidate(s,[],'m2',{x,y}).error;
  assert.match(at(-1,1),/内側/);assert.match(at(0,1),/材料/);assert.match(at(3,5),/手前/);
  assert.match(at(2,2),/職人/);assert.match(at(2,0),/正面/);
  const bad=[{id:'m3',x:4,y:1},{id:'m1',x:0,y:1}];
  assert.match(applyLayout(s,bad),/材料/);assert.match(startRepeat(s,'layout',bad),/材料/);
  assert.match(layoutPlan(s,[{id:'missing'}]).error,/変わりました/);
  assert.deepEqual(s,original);
});
test('keep the current factory if it suits the job, and handle an expanded factory with duplicate tools',()=>{
  const s=seed(),original=structuredClone(s.machines);
  assert.equal(startRepeat(s,'layout',[]),null);assert.deepEqual(s.machines,original);ship(s);
  s.cash=50000;M.expand(s);assert.equal(M.purchase(s,'drill',8,2),null);
  const second=s.machines.at(-1),cells=legalLayoutCells(s,[],second.id);
  assert.ok(cells.some(c=>c.x===9&&c.y===6));
  const swap=layoutCandidate(s,[],second.id,s.machines[1]);assert.equal(swap.swap,'drill');
  assert.ok(M.validate({...s,machines:swap.machines}));
});
