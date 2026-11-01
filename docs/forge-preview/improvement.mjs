import {isBriefId} from './brief.mjs?v=0.24';
import {applyLayout} from './layout.mjs?v=0.24';
// First repeat order. The saved shipment, route planner and normal work orders
// are the source of truth. There is no tutorial cursor or simulated reward.
import * as M from './model.mjs?v=0.24';

export function repeatOffer(s){
  if(M.frontOrder(s))return null;
  const report=s.results?.find(r=>r.offerId==='first'&&r.seconds!=null);
  if(!report)return null;
  const offer=M.OFFERS.find(o=>o.id===report.offerId);
  if(!M.offerStatus(s,offer.id).available)return null;
  const drill=s.machines.find(m=>m.kind==='drill');
  return {report,offer,drill,upgradeCost:drill.level<3?1500*drill.level:null};
}

// Another worker can be assigned on the trip back. This preview measures only
// one piece's trip from the cutting station's service cell to this drill's.
export function transferPath(s,drill,candidate=drill){
  const cutter=s.machines.find(m=>m.kind==='cut');
  const from={x:cutter.x,y:cutter.y+1},to={x:candidate.x,y:candidate.y+1};
  const layout=s.machines.map(m=>m.id===drill.id?{...m,x:candidate.x,y:candidate.y}:m);
  const path=M.path(s,from,to,layout);
  return path&&[from,...path];
}

export function neighboringCell(s,drill,cells){
  const cutter=s.machines.find(m=>m.kind==='cut');
  const current=transferPath(s,drill);
  for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
    const candidate=cells.find(p=>p.x===cutter.x+dx&&p.y===cutter.y+dy);
    if(candidate&&transferPath(s,drill,candidate)?.length<current?.length)return candidate;
  }
  return null;
}

export function startRepeat(s,choice,candidate=null,briefId=null){
  if(briefId!==null&&(choice!=='layout'||!isBriefId(briefId)))return '再注文の条件を選び直してください';
  const trial=repeatOffer(s);
  if(!trial)return 'この注文の条件が変わりました。受注画面を確認してください';
  const {offer,drill,upgradeCost}=trial;
  if(choice==='upgrade'){
    if(upgradeCost===null)return 'このボール盤は最高レベルです';
    if(s.cash<upgradeCost+offer.cost)return '改良費と材料費を合わせた資金が必要です';
  }else if(choice==='layout'){
    if(!Array.isArray(candidate))return '配置案を選んでください';
  }else if(choice==='move'){
    if(!candidate||(candidate.x===drill.x&&candidate.y===drill.y))return '別の設置場所を選んでください';
  }else return '改善方法を選んでください';

  // Apply both existing operations to a draft. Insufficient funds, an occupied
  // tile or a retried confirmation cannot leave a moved tool or partial charge.
  const draft=structuredClone(s);
  const error=choice==='upgrade'?M.upgrade(draft,drill.id):choice==='layout'?(candidate.length?applyLayout(draft,candidate):null):M.move(draft,drill.id,candidate.x,candidate.y);
  if(error)return error;
  const rejected=M.accept(draft,offer.id);
  if(rejected)return rejected;
  const order=M.frontOrder(draft);
  order.repeatCost=choice==='upgrade'?upgradeCost:0;
  if(briefId!==null)order.briefId=briefId;
  Object.assign(s,draft);
  return null;
}

export function comparisonLine(s,report){
  if(!report)return '';
  const previous=M.previousResult(s,report);
  if(!previous)return '';
  const time=Math.round((report.seconds-previous.seconds)*10)/10;
  const walk=Math.round(report.walk-previous.walk);
  const elapsed=time===0?'時間同じ':Math.abs(time)+'秒'+(time<0?'短縮':'増加');
  const travel=walk===0?'移動同じ':'移動'+Math.abs(walk)+'マス'+(walk<0?'減':'増');
  return '同じ注文の前回比　'+elapsed+'・'+travel;
}
