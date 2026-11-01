// Run an offered order on a copy, including shared labor, paths, experience,
// payroll and deadlines. Existing orders ship as soon as they are ready.
import * as M from './model.mjs?v=0.21';
import {startRepeat} from './improvement.mjs?v=0.21';

import {acceptPrecision,installStarterLathe} from './precision.mjs?v=0.21';

import {inquiryContext,decideInquiry} from './inquiry.mjs?v=0.21';

export function estimateOrder(state,scenario,maxTicks=24000){
  const s=structuredClone(state);
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
  const rows=settle(s,[id],maxTicks);
  return rows.error?rows:rows[0];
}

function settle(s,ids,maxTicks){
  const receipts=new Map();
  const limit=Number.isFinite(maxTicks)?Math.max(0,Math.min(24000,Math.floor(maxTicks))):24000;
  let ticks=0;
  while(true){
    const ready=M.advanceToReady(s,Math.min(200,limit-ticks));
    ticks+=ready.ticks;
    if(ready.status==='ready'){
      const order=s.orders.find(o=>o.id===ready.orderId);
      M.dispatch(s,order.id);
      if(!ids.includes(order.id))continue;
      const r=s.results[0],profit=M.resultProfit(r);
      receipts.set(order.id,{seconds:r.seconds,walk:r.walk,margin:order.due-r.seconds,late:r.late,
        payout:r.payout,profit,rework:r.rework,net:profit-(r.repeatCost||r.qualitySpend||0)});
      if(receipts.size===ids.length)return ids.map(key=>receipts.get(key));
      continue;
    }
    if(ready.status==='idle'||ticks>=limit)return {error:'見積の範囲を超えました'};
  }
}
