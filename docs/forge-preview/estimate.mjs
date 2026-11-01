// Run an offered order on a copy, including shared labor, paths, experience,
// payroll and deadlines. Existing orders ship as soon as they are ready.
import * as M from './model.mjs?v=0.20';
import {startRepeat} from './improvement.mjs?v=0.20';

import {acceptPrecision,installStarterLathe} from './precision.mjs?v=0.20';

export function estimateOrder(state,scenario,maxTicks=24000){
  const s=structuredClone(state);
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
  const limit=Number.isFinite(maxTicks)?Math.max(0,Math.min(24000,Math.floor(maxTicks))):24000;
  let ticks=0;
  while(true){
    const ready=M.advanceToReady(s,Math.min(200,limit-ticks));
    ticks+=ready.ticks;
    if(ready.status==='ready'){
      const order=s.orders.find(o=>o.id===ready.orderId);
      M.dispatch(s,order.id);
      if(order.id!==id)continue;
      const r=s.results[0],profit=M.resultProfit(r);
      return {seconds:r.seconds,walk:r.walk,margin:order.due-r.seconds,late:r.late,
        payout:r.payout,profit,rework:r.rework,net:profit-(r.repeatCost||r.qualitySpend||0)};
    }
    if(ready.status==='idle'||ticks>=limit)return {error:'見積の範囲を超えました'};
  }
}
