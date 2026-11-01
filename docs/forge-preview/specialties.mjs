// Each qualifying dispatch stamps one route once. The earliest stamp remains
// the first ending even after the twelve most recent receipts rotate.
export const SPECIALTIES={rush:'量産の町工場',master:'精密の町工場'};
const qualifies=r=>Object.hasOwn(SPECIALTIES,r.offerId)&&r.late===false;

function addStamp(s,entries,r){
  if(!qualifies(r)||entries.some(e=>e.offerId===r.offerId))return;
  const o=s.orders.find(o=>o.id===r.orderId);
  entries.push({offerId:r.offerId,orderId:r.orderId,shippedAt:r.shippedAt,
    margin:o?Math.max(0,o.start+o.due-r.shippedAt):null,
    inspectorId:r.inspectorId??null,rework:r.rework});
}

export function restoreSpecialties(s){
  if(s.specialties!==undefined)return;
  s.specialties=[];
  for(const r of [...(s.results||[])].reverse())addStamp(s,s.specialties,r);
}

export function recordSpecialty(s,receipt){
  restoreSpecialties(s);
  addStamp(s,s.specialties,receipt);
}

export function validSpecialties(s,offers){
  const entries=s.specialties;
  if(entries===undefined)return true;
  if(!Array.isArray(entries)||entries.length>2||entries.length>s.delivered)return false;
  const seen=new Set(),ids=new Set(),receipts=s.results||[];
  let last=-1,expired=0;
  for(const e of entries){
    if(!e||!Object.hasOwn(SPECIALTIES,e.offerId)||seen.has(e.offerId)||ids.has(e.orderId))return false;
    const offer=offers.find(o=>o.id===e.offerId);
    if(!Number.isInteger(e.orderId)||e.orderId<1||e.orderId>=s.next||
      !Number.isFinite(e.shippedAt)||e.shippedAt<0||e.shippedAt<last||e.shippedAt>s.clock||
      !(e.margin===null||Number.isFinite(e.margin)&&e.margin>=0&&e.margin<=offer.due+1e-6)||
      !(e.rework===null||Number.isInteger(e.rework)&&e.rework>=0&&e.rework<=offer.qty)||
      !(e.inspectorId===null||e.offerId==='master'&&s.workers.some(w=>w.id===e.inspectorId)))return false;
    const order=s.orders.find(o=>o.id===e.orderId);
    if(order&&(!order.shipped||order.offerId!==e.offerId||e.margin!==Math.max(0,order.start+order.due-e.shippedAt)))return false;
    const i=receipts.findIndex(r=>r.orderId===e.orderId);
    if(i<0){
      expired++;
      if(receipts.length&&e.shippedAt>receipts.at(-1).shippedAt)return false;
    }else{
      const r=receipts[i];
      if(!qualifies(r)||r.offerId!==e.offerId||r.shippedAt!==e.shippedAt||
        (r.inspectorId??null)!==e.inspectorId||r.rework!==e.rework||
        receipts.slice(i+1).some(old=>old.offerId===e.offerId&&qualifies(old)))return false;
    }
    last=e.shippedAt;seen.add(e.offerId);ids.add(e.orderId);
  }
  return expired<=s.delivered-receipts.length&&receipts.every(r=>!qualifies(r)||seen.has(r.offerId));
}
