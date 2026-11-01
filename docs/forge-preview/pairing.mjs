// Persistent facts for one two-order decision. A peer summary survives even
// when its original receipt rolls out of the twelve-entry shipment history.
export const eligiblePrimary=id=>['bulk','rush','fine','master'].includes(id);
export const validPriority=p=>p==='primary'||p==='extra';
export const peerId=(pair,id)=>id===pair.primary?pair.extra:pair.primary;

export function preferredOrder(orders){
  const live=orders.filter(o=>!o.shipped&&o.done<o.qty);
  if(live.length!==2)return null;
  const p=live[0].pair;
  return p&&live[1].pair?.extra===p.extra?p[p.priority]:null;
}

function actual(r){
  return {id:r.orderId,profit:r.payout-r.material-r.wages,late:r.late};
}

export function recordPair(s,order,report){
  if(!order.pair)return;
  const pair=report.pair={...order.pair},other=peerId(pair,order.id),own=actual(report);
  const otherOrder=s.orders.find(o=>o.id===other);
  if(otherOrder?.pair)otherOrder.pair.peer=own;
  const earlier=s.results?.find(r=>r.orderId===other);
  if(earlier?.pair){
    pair.peer=actual(earlier);
    earlier.pair.peer=own;
  }
}
export function pairResult(r){
  const p=r?.pair;
  if(!p?.peer)return null;
  const profit=actual(r).profit+p.peer.profit;
  const primaryLate=r.orderId===p.primary?r.late:p.peer.late;
  const extraLate=r.orderId===p.extra?r.late:p.peer.late;
  return {profit,delta:p.solo?profit-p.solo.profit:null,primaryLate,extraLate};
}

function validSolo(solo){
  return solo===null||(solo&&Number.isFinite(solo.profit)&&Number.isFinite(solo.seconds)&&solo.seconds>=0&&typeof solo.late==='boolean');
}
export function soloSnapshot(solo){
  return solo&&validSolo(solo)?{profit:solo.profit,seconds:solo.seconds,late:solo.late}:null;
}
export function validPairRecord(record,id){
  const p=record.pair;
  if(record.declinedExtra!==undefined&&(!record.declinedExtra||!validSolo(record.declinedExtra.solo)||!eligiblePrimary(record.offerId)||p))return false;
  if(p===undefined)return true;
  if(!p||!Number.isInteger(p.primary)||p.primary<1||!Number.isInteger(p.extra)||p.extra<=p.primary||!validPriority(p.priority))return false;
  if(id===p.primary?!eligiblePrimary(record.offerId):id!==p.extra||record.offerId!=='relief')return false;
  if(!validSolo(p.solo))return false;
  return !('peer' in p)||(p.peer&&p.peer.id===peerId(p,id)&&Number.isFinite(p.peer.profit)&&typeof p.peer.late==='boolean');
}

export function validPairLinks(s){
  const records=[...s.orders,...(s.results||[])];
  return records.every(r=>{
    if(!r.pair)return true;
    const id=r.orderId??r.id,other=peerId(r.pair,id);
    const linked=records.filter(x=>(x.orderId??x.id)===other);
    if(!linked.length)return !!r.pair.peer;
    if(Boolean(r.pair.peer)!==linked.some(x=>x.orderId!==undefined||x.shipped))return false;
    return linked.every(x=>x.pair?.primary===r.pair.primary&&x.pair.extra===r.pair.extra&&x.pair.priority===r.pair.priority&&
      (x.pair.solo?.profit??null)===(r.pair.solo?.profit??null)&&
      (x.pair.solo?.seconds??null)===(r.pair.solo?.seconds??null)&&
      (x.pair.solo?.late??null)===(r.pair.solo?.late??null)&&
      (x.orderId===undefined||r.pair.peer?.profit===actual(x).profit&&r.pair.peer?.late===x.late));
  });
}
