import {layoutCandidate,layoutPlan} from './layout.mjs?v=0.25';
// Run an offered order on a copy, including shared labor, paths, experience,
// payroll and deadlines. Existing orders ship as soon as they are ready.
import * as M from './model.mjs?v=0.25';
import {startRepeat} from './improvement.mjs?v=0.25';

import {acceptPrecision,installStarterLathe} from './precision.mjs?v=0.25';

import {inquiryContext,decideInquiry} from './inquiry.mjs?v=0.25';

export function estimateOrder(state,scenario,maxTicks=24000){
  const s=structuredClone(state);
  if(scenario.rankLayout)return rankLayout(s,scenario.rankLayout,maxTicks);
  if(scenario.layout){
    const plan=layoutPlan(s,scenario.layout);
    if(plan.error)return plan;
    s.machines=plan.machines;
  }
  if(scenario.inquiry){
    const {primaryId,extraId=null,priority}=scenario.inquiry;
    const context=inquiryContext(s);
    if(!context||context.primary.id!==primaryId||(context.extra?.id??null)!==extraId)return {error:'相談できる注文がありません'};
    if(priority==='solo'){
      if(context.extra)return {error:'追加受注は確定済みです'};
      const rows=settle(s,[primaryId],maxTicks);
      return rows.error?rows:{primary:rows[0]};
    }
    const error=decideInquiry(s,primaryId,priority,null,extraId);
    if(error)return {error};
    const rows=settle(s,[primaryId,inquiryContext(s).extra.id],maxTicks);
    return rows.error?rows:{primary:rows[0],extra:rows[1],profit:rows[0].profit+rows[1].profit};
  }
  if(scenario.lathe){
    const error=installStarterLathe(s,scenario.lathe);if(error)return {error};
  }
  if(scenario.move){
    const {id:machine,x,y}=scenario.move;
    const error=M.move(s,machine,x,y);
    if(error)return {error};
  }
  const id=s.next;
  const error=scenario.precision?acceptPrecision(s,scenario.precision):scenario.repeat?startRepeat(s,scenario.repeat,scenario.cell):M.accept(s,scenario.offer);
  if(error)return {error};
  const rows=settle(s,[id],maxTicks,scenario.trace?id:null);
  return rows.error?rows:rows[0];
}

function settle(s,ids,maxTicks,traceId=null){
  const order=s.orders.find(o=>o.id===traceId);
  const travel=order?Object.fromEntries(M.route(order.product).map(kind=>[kind,0])):null;
  const example=order?s.parts.find(part=>part.order===traceId)?.id:null,legs=[];
  const onAssign=travel?(part,m,path)=>{
    if(part.id===example)legs.push({machine:m.id,kind:m.kind,path:[{x:part.x,y:part.y},...path]});
  }:null;
  const onWalk=travel?(part,distance)=>{if(part.order===traceId)travel[M.route(part.product)[part.stage]]+=distance;}:null;
  const receipts=new Map();
  const limit=Number.isFinite(maxTicks)?Math.max(0,Math.min(24000,Math.floor(maxTicks))):24000;
  let ticks=0;
  while(true){
    const ready=M.advanceToReady(s,Math.min(200,limit-ticks),onWalk,onAssign);
    ticks+=ready.ticks;
    if(ready.status==='ready'){
      const order=s.orders.find(o=>o.id===ready.orderId);
      M.dispatch(s,order.id);
      if(!ids.includes(order.id))continue;
      const r=s.results[0],profit=M.resultProfit(r);
      receipts.set(order.id,{...(travel&&order.id===traceId?{travel,legs}:{}),seconds:r.seconds,walk:r.walk,margin:order.due-r.seconds,late:r.late,
        payout:r.payout,profit,rework:r.rework,net:profit-(r.repeatCost||r.qualitySpend||0)});
      if(receipts.size===ids.length)return ids.map(key=>receipts.get(key));
      continue;
    }
    if(ready.status==='idle'||ticks>=limit)return {error:'見積の範囲を超えました'};
  }
}

// Compare a single tool's alternatives with the other drafted positions fixed.
// A tie keeps the current cell if possible, then prefers fewer moved tools.
function rankLayout(s,{id,anchor=[],offer},maxTicks){
  const base=layoutPlan(s,anchor);
  if(base.error)return base;
  const machine=base.machines.find(m=>m.id===id);
  if(!machine)return {error:'設備が見つかりません'};
  const baseline=estimateOrder(s,{offer,layout:anchor,trace:true},maxTicks);
  if(baseline.error)return baseline;
  const current={x:machine.x,y:machine.y,quote:baseline,changes:0};
  let fastest=current,shortest=current,checked=0,legal=0;
  for(let y=0;y<s.height-1;y++)for(let x=1;x<s.width;x++){
    const plan=layoutCandidate(s,anchor,id,{x,y});
    if(plan.error)continue;
    legal++;
    if(x===current.x&&y===current.y){checked++;continue;}
    const quote=estimateOrder(s,{offer,layout:plan.moves,trace:true},maxTicks);
    if(quote.error)continue;
    checked++;
    const row={x,y,quote,changes:plan.swap?2:1,swap:plan.swap};
    if(better(row,fastest,'seconds','walk'))fastest=row;
    if(better(row,shortest,'walk','seconds'))shortest=row;
  }
  return {base:current,fastest,shortest,checked,legal};
}
function better(a,b,main,secondary){
  for(const key of [main,secondary]){
    const d=a.quote[key]-b.quote[key];if(Math.abs(d)>1e-6)return d<0;
  }
  return a.changes<b.changes;
}
