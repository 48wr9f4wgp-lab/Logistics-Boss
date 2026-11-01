import * as M from './model.mjs?v=0.25';
import {eligiblePrimary,validPriority,soloSnapshot} from './pairing.mjs?v=0.25';

export function inquiryContext(s){
  if(s.delivered<2)return null;
  const live=s.orders.filter(o=>!o.shipped);
  if(!live.length||live.some(o=>o.done===o.qty))return null;
  if(live.length===2){
    const [primary,extra]=live[0].pair?.primary===live[0].id?live:[live[1],live[0]];
    return primary.pair?.extra===extra.id&&extra.pair?.primary===primary.id?{primary,extra}:null;
  }
  const primary=live[0];
  return eligiblePrimary(primary.offerId)&&primary.accounting&&!primary.pair&&!primary.declinedExtra?{primary,extra:null}:null;
}
export function decideInquiry(s,primaryId,priority,solo=null,expectedExtra=null){
  const context=inquiryContext(s);
  if(!context||context.primary.id!==primaryId||(context.extra?.id??null)!==expectedExtra)return '受注状況が変わりました。工場に戻ってください';
  const {primary,extra}=context;
  if(priority==='decline'&&!extra){
    primary.declinedExtra={solo:soloSnapshot(solo)};M.note(s,'小口の打診を見送り、先約の製作を続けます');return null;
  }
  if(!validPriority(priority))return '優先する注文を選んでください';
  if(extra){
    primary.pair.priority=priority;extra.pair.priority=priority;
    M.note(s,(priority==='primary'?'先約':'小口')+'を次の作業から優先');return null;
  }
  const error=M.accept(s,'relief');
  if(error)return error;
  const added=s.orders.at(-1);
  const pair={primary:primary.id,extra:added.id,priority,solo:soloSnapshot(solo)};
  primary.pair={...pair};added.pair={...pair};
  M.note(s,'支給材6個を追加受注 · '+(priority==='primary'?'先約':'小口')+'を優先');
  return null;
}

export function advanceToReview(s,primaryId,target,maxTicks){
  const limit=Math.max(0,Math.min(200,Math.floor(maxTicks)||0));
  let ticks=0;
  while(true){
    const state=inquiryContext(s);
    if(!state||state.extra||state.primary.id!==primaryId||!Number.isInteger(target)||target<1||target>=state.primary.qty)return {status:'idle',ticks};
    if(state.primary.done>=target)return {status:'review',ticks};
    if(ticks>=limit)return {status:'producing',ticks};
    M.step(s,M.TICK);ticks++;
  }
}
