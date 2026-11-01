// Conditions on the twelve-plate repeat. Only production time or total walking
// counts. Waiting to dispatch may discount the base contract, never this bonus.
export const BRIEFS={
  speed:{label:'早仕上げ',metric:'seconds',limit:108,unit:'秒',bonus:400},
  walk:{label:'省運搬',metric:'walk',limit:225,unit:'マス',bonus:400}
};

export const isBriefId=id=>typeof id==='string'&&Object.hasOwn(BRIEFS,id);
const amount=(brief,value)=>value.toFixed(brief.metric==='seconds'?1:0)+brief.unit;

export function briefTarget(id){
  if(!isBriefId(id))return '';
  const brief=BRIEFS[id];
  return (id==='speed'?'完成':'総移動')+amount(brief,brief.limit)+'以内';
}

// Use the same displayed precision as the layout ticket. Incomplete records
// cannot earn a bonus merely because their counter starts at zero.
export function assessBrief(id,metrics){
  if(!isBriefId(id))return null;
  const brief=BRIEFS[id],raw=metrics?.[brief.metric];
  if(!Number.isFinite(raw)||raw<0)return null;
  const value=brief.metric==='seconds'?Number(raw.toFixed(1)):Math.round(raw);
  const met=value<=brief.limit;
  return {met,value,bonus:met?brief.bonus:0};
}

export function briefOutcomeText(id,metrics,preview=false){
  const result=assessBrief(id,metrics);
  if(!result)return '';
  const brief=BRIEFS[id],{value,met,bonus}=result;
  const verdict=met?(preview?'達成見込':'達成'):(preview?'未達見込':'未達');
  const measure=amount(brief,value);
  const margin=met?'余裕'+amount(brief,brief.limit-value):'あと'+amount(brief,value-brief.limit);
  if(preview)return verdict+' · '+measure+'（'+margin+'）'+(met?'＋¥'+bonus:'');
  return verdict+' · '+measure+'／'+amount(brief,brief.limit)+' · '+(met?'＋¥'+bonus:margin);
}

export function validBriefRecord(record,receipt=false){
  const {briefId,briefBonus}=record;
  if(briefId===undefined)return briefBonus===undefined;
  if(!isBriefId(briefId)||record.offerId!=='first'||record.repeatCost!==0)return false;
  if(!receipt)return briefBonus===undefined;
  const result=assessBrief(briefId,record);
  return !!result&&briefBonus===result.bonus;
}

// A result is only retained for twelve shipments. Remember the distinct skills
// earned in this factory independently of that receipt window.
function successfulReceipt(record,id){
  return record?.briefId===id&&record.briefBonus===BRIEFS[id].bonus&&validBriefRecord(record,true);
}
export function earnedBriefs(s){
  return Object.keys(BRIEFS).filter(id=>s.briefCredits?.includes(id)||s.results?.some(r=>successfulReceipt(r,id)));
}

export function validBriefCredits(s){
  const ids=s.briefCredits;
  if(ids===undefined)return true;
  if(!Array.isArray(ids)||ids.length>2||!ids.every(isBriefId)||new Set(ids).size!==ids.length)return false;
  // An unmatched credit requires at least one shipment beyond stored history.
  const receipts=s.results||[];
  const missing=ids.filter(id=>!receipts.some(r=>successfulReceipt(r,id)));
  return missing.length<=s.delivered-receipts.length;
}

export function recordBriefCredit(s,receipt){
  // Read the old history before adding this receipt or dropping the oldest.
  const before=earnedBriefs(s);
  const ids=Object.keys(BRIEFS).filter(id=>before.includes(id)||successfulReceipt(receipt,id));
  if(ids.length)s.briefCredits=ids;
  return before.length<2&&ids.length===2;
}
