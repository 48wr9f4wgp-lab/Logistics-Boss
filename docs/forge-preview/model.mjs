import {assessBrief,validBriefRecord,earnedBriefs,validBriefCredits,recordBriefCredit} from './brief.mjs?v=0.23';
import {preferredOrder,recordPair,validPairRecord,validPairLinks} from './pairing.mjs?v=0.23';
export const VERSION=1;
// Shared by real-time playback and completion skipping; rendering frequency must not change outcomes.
export const TICK=.05;
export const MACHINES={cut:{name:'切断機',cost:2600,time:3,color:'#f3b65c'},drill:{name:'ボール盤',cost:3200,time:5,color:'#67b7c4'},inspect:{name:'検品台',cost:1800,time:2,color:'#9dbf8b'},lathe:{name:'旋盤',cost:5800,time:8,color:'#789fd1'}};
export const OFFERS=[{id:'first',name:'町の金物店',product:'plate',label:'取付プレート',qty:12,cost:600,pay:2800,due:200,quality:1},{id:'bulk',name:'建設会社の量産注文',product:'plate',label:'取付プレート',qty:28,cost:1300,pay:5900,due:290,quality:1},{id:'fine',name:'機械メーカーの特注',product:'shaft',label:'精密シャフト',qty:10,cost:1400,pay:6200,due:240,quality:2},{id:'relief',name:'支給材の小口加工',product:'plate',label:'取付プレート',qty:6,cost:0,pay:1000,due:180,quality:1},{id:'rush',name:'建設現場の追加便',product:'plate',label:'短納期プレート',qty:28,cost:1800,pay:7200,due:200,quality:1,growth:'量産ルート'},{id:'master',name:'測定機器メーカー',product:'shaft',label:'高精度シャフト',qty:10,cost:2200,pay:8800,due:150,quality:3,growth:'精密ルート'}];
export const route=p=>p==='shaft'?['cut','lathe','inspect']:['cut','drill','inspect'];
// The same per-piece calculation powers assignment and investment previews.
export function processingTime(kind,{skill=1,level=1,mentor=false,quality=1}={}){
  const rework=kind==='inspect'&&skill+level-1<quality;
  return MACHINES[kind].time/(1+.28*(skill-1)+.25*(level-1))*(mentor?1.25:1)*(rework?2.5:1);
}
export function fresh(){return {version:VERSION,cash:5500,revenue:0,expense:0,clock:0,width:8,height:6,next:1,delivered:0,machines:[{id:'m1',kind:'cut',x:2,y:1,level:1},{id:'m2',kind:'drill',x:5,y:1,level:1},{id:'m3',kind:'inspect',x:5,y:4,level:1}],workers:['青木','森','佐藤'].map((name,i)=>({id:i,name,x:1+i,y:3,skill:1,xp:0,role:'auto',mentor:false,job:null})),orders:[],results:[],parts:[],log:['小口注文から、最初の出荷を目指そう。'],stats:{rework:0,walk:0,processed:0}};}
export function note(s,t){s.log.unshift(t);s.log=s.log.slice(0,12);}
export function path(s,a,b,ms=s.machines){const block=new Set(ms.map(m=>`${m.x},${m.y}`));const key=p=>`${p.x},${p.y}`;let queue=[{x:Math.round(a.x),y:Math.round(a.y),p:[]}],seen=new Set();while(queue.length){const n=queue.shift(),k=key(n);if(seen.has(k))continue;seen.add(k);if(n.x===b.x&&n.y===b.y)return n.p;for(const [dx,dy]of [[1,0],[-1,0],[0,1],[0,-1]]){const q={x:n.x+dx,y:n.y+dy};if(q.x<0||q.y<0||q.x>=s.width||q.y>=s.height||block.has(key(q)))continue;queue.push({...q,p:[...n.p,q]});}}return null;}
// Validate the final floor, including swaps, in the same graph workers use.
export function floorIssue(s,machines,changed){
  if(s.workers.some(w=>w.job))return '職人が今の工程を終えると配置できます';
  for(const m of changed){
    if(!MACHINES[m.kind]||!Number.isInteger(m.x)||!Number.isInteger(m.y)||m.x<0||m.y<0||m.x>=s.width||m.y>=s.height)return '工場の床の内側を選んでください';
    if(m.x===0)return '左端の列は材料を運ぶ通路です';
    if(m.y===s.height-1)return '手前に職人が立つ作業マスを1つ残してください';
    if(machines.some(other=>other!==m&&other.x===m.x&&other.y===m.y))return '別の設備がこの床を使っています';
    if(s.workers.some(w=>Math.round(w.x)===m.x&&Math.round(w.y)===m.y))return '職人が立っている床です';
    if(s.parts.some(p=>!p.done&&p.x===m.x&&p.y===m.y))return '仕掛品が置かれている床です';
  }
  const gate={x:0,y:0};
  for(const m of machines){
    if(machines.some(other=>other.x===m.x&&other.y===m.y+1))return MACHINES[m.kind].name+'の正面の作業マスをふさいでいます';
    if(!path(s,gate,{x:m.x,y:m.y+1},machines))return '搬入口から'+MACHINES[m.kind].name+'の作業マスへの通路が途切れます';
  }
  if([...s.workers,...s.parts.filter(p=>!p.done)].some(p=>!path(s,gate,{x:Math.round(p.x),y:Math.round(p.y)},machines)))return '職人か仕掛品が搬入口から到達できなくなります';
  return null;
}
export function placementIssue(s,kind,x,y,ignore=null){
  const m={id:ignore,kind,x,y},machines=[...s.machines.filter(m=>m.id!==ignore),m];
  return floorIssue(s,machines,[m]);
}
export function canPlace(s,kind,x,y,ignore=null){return placementIssue(s,kind,x,y,ignore)===null;}
export function accept(s,id,quote){const o=OFFERS.find(o=>o.id===id),status=offerStatus(s,id);if(!status.available)return status.reason;const n={...o,id:s.next++,start:s.clock,done:0,shipped:false,offerId:o.id,accounting:{wages:0,walk:0,rework:0,completedAt:null}};
if(quote){
  const recorded={seconds:quote.seconds,profit:quote.profit};
  if(o.product==='shaft'&&quote.rework!==undefined)recorded.rework=quote.rework;
  if(validQuote(id,recorded))n.quote=recorded;
}
s.cash-=o.cost;s.expense+=o.cost;s.orders.push(n);for(let i=0;i<o.qty;i++)s.parts.push({id:`${n.id}-${i}`,order:n.id,product:o.product,stage:0,x:0,y:0,busy:false,done:false});note(s,`${o.label} ${o.qty}個を受注`);return null;}
export function dispatch(s,id){const o=s.orders.find(o=>o.id===id);if(!o||o.shipped||o.done!==o.qty)return 'まだ出荷できません';const {late,pay,briefBonus}=shipmentQuote(s,o);s.cash+=pay;s.revenue+=pay;s.delivered++;
const a=o.accounting,measured=!!a&&a.completedAt!==null;
const report={orderId:o.id,offerId:o.offerId??null,label:o.label,qty:o.qty,payout:pay,material:o.cost,late,shippedAt:s.clock,wages:measured?a.wages:null,seconds:measured?a.completedAt-o.start:null,walk:measured?a.walk:null,rework:measured?a.rework:null};
if(o.repeatCost!==undefined)report.repeatCost=o.repeatCost;
if(o.briefId!==undefined){report.briefId=o.briefId;report.briefBonus=briefBonus;}
if(o.quote)report.quote={...o.quote};
if(o.inspectorId!==undefined)report.inspectorId=o.inspectorId;
if(o.qualitySpend!==undefined){report.qualitySpend=o.qualitySpend;report.growth=a.growth||[];}
if(o.declinedExtra)report.declinedExtra={...o.declinedExtra};
const referral=recordBriefCredit(s,report);
recordPair(s,o,report);
s.results=[report,...(s.results||[])].slice(0,12);o.shipped=true;s.parts=s.parts.filter(p=>p.order!==id);s.orders=s.orders.filter(q=>!q.shipped||q.id===id);note(s,`出荷完了！ +¥${pay.toLocaleString()}${late?'（基本報酬は納期超過で15%減）':''}${referral?' · 金物店から短納期便の紹介':''}`);return null;}
export function purchase(s,kind,x,y){if(!canPlace(s,kind,x,y))return '作業中は配置変更できません。通路と作業面も空けてください';const cost=MACHINES[kind].cost;if(s.cash<cost)return '資金が足りません';s.cash-=cost;s.expense+=cost;s.machines.push({id:`m${s.next++ +10}`,kind,x,y,level:1});note(s,`${MACHINES[kind].name}を導入`);return null;}
export function move(s,id,x,y){const m=s.machines.find(m=>m.id===id);if(!m||!canPlace(s,m.kind,x,y,id))return '作業中は移動できません。空いた床を選んでください';m.x=x;m.y=y;note(s,'設備を移動しました');return null;}
export function upgrade(s,id){const m=s.machines.find(m=>m.id===id);if(!m||m.level>=3)return '改良済みです';const cost=1500*m.level;if(s.cash<cost)return '資金が足りません';s.cash-=cost;s.expense+=cost;m.level++;note(s,`${MACHINES[m.kind].name}を改良 Lv.${m.level}`);return null;}
export function train(s,id){const w=s.workers.find(w=>w.id===id);if(!w||w.skill>=4)return '最高技能です';const cost=800*w.skill;if(s.cash<cost)return '資金が足りません';s.cash-=cost;s.expense+=cost;w.skill++;note(s,`${w.name}の技能が ${w.skill} に向上`);return null;}
export function expand(s){if(s.width===10)return '敷地は拡張済みです';if(s.cash<3500)return '拡張には¥3,500必要です';s.cash-=3500;s.expense+=3500;s.width=10;s.height=8;note(s,'工場を拡張しました');return null;}
export function sell(s,id){if(s.workers.some(w=>w.job))return '作業終了後に売却できます';const m=s.machines.find(m=>m.id===id);if(!m)return '設備が見つかりません';if(['cut','drill','inspect'].includes(m.kind)&&s.machines.filter(x=>x.kind===m.kind).length===1)return '立て直しに必要な最後の基本設備は残します';if(m.kind==='lathe'&&s.orders.some(o=>!o.shipped&&o.product==='shaft'))return 'シャフトを出荷してから売却できます';const refund=Math.floor(MACHINES[m.kind].cost*.65);s.cash+=refund;s.machines=s.machines.filter(x=>x!==m);note(s,`設備売却 +¥${refund}`);return null;}
function assign(s,w,onAssign){
  const named=new Map(s.orders.filter(o=>!o.shipped&&o.inspectorId!==undefined).map(o=>[o.id,o.inspectorId]));
  const inspector=p=>p.stage===2?named.get(p.order):undefined;
  const priority=p=>{
    if(inspector(p)===w.id)return -1;
    const kind=route(p.product)[p.stage];
    return w.role==='inspect'?(kind==='inspect'?0:1):w.role==='machine'?(kind!=='inspect'?0:1):0;
  };
  const preferred=preferredOrder(s.orders);
  const candidates=s.parts.filter(p=>!p.done&&!p.busy&&(inspector(p)===undefined||inspector(p)===w.id))
    .sort((a,b)=>Number(b.order===preferred)-Number(a.order===preferred)||priority(a)-priority(b)||b.stage-a.stage);
  for(const p of candidates){const kind=route(p.product)[p.stage];const ms=s.machines.filter(m=>m.kind===kind&&!s.workers.some(v=>v.job?.machine===m.id));for(const m of ms){const a=path(s,w,p),b=path(s,p,{x:m.x,y:m.y+1});if(a===null||b===null)continue;const order=s.orders.find(o=>o.id===p.order);const rework=kind==='inspect'&&w.skill+m.level-1<order.quality;w.job={part:p.id,machine:m.id,path:[...a,...b],remaining:processingTime(kind,{skill:w.skill,level:m.level,mentor:w.mentor,quality:order.quality}),phase:'walk',rework};p.busy=true;if(onAssign)onAssign(p,m,b);return;}}}
export function step(s,dt,{assignNew=true,onWalk=null,onAssign=null}={}){if(!Number.isFinite(dt)||dt<=0)return;dt=Math.min(dt,.25);s.clock+=dt;const active=s.parts.some(p=>!p.done);if(active){const wage=Math.min(s.cash,dt*.7);s.cash-=wage;s.expense+=wage;
// Allocate the actual payroll once, including idle staff, among unfinished orders.
const producing=s.orders.filter(o=>!o.shipped&&o.done<o.qty);
for(const o of producing)if(o.accounting)o.accounting.wages+=wage/producing.length;
}for(const w of s.workers){if(!w.job&&assignNew)assign(s,w,onAssign);const j=w.job;if(!j)continue;const p=s.parts.find(p=>p.id===j.part);if(!p){w.job=null;continue;}if(j.path.length){const target=j.path[0],dist=Math.hypot(target.x-w.x,target.y-w.y),d=dt*2.2;if(dist<=d){w.x=target.x;w.y=target.y;j.path.shift();}else{w.x+=(target.x-w.x)*d/dist;w.y+=(target.y-w.y)*d/dist;}const distance=Math.min(dist,d);s.stats.walk+=distance;if(onWalk)onWalk(p,distance);const a=s.orders.find(o=>o.id===p.order).accounting;if(a)a.walk+=distance;j.phase='walk';}else{j.phase='work';j.remaining-=dt;if(j.remaining<=0){const m=s.machines.find(m=>m.id===j.machine);p.x=m.x;p.y=m.y+1;p.stage++;p.busy=false;p.done=p.stage===route(p.product).length;const order=s.orders.find(o=>o.id===p.order);if(p.done){order.done++;if(order.accounting&&order.done===order.qty)order.accounting.completedAt=s.clock;}if(j.rework){s.stats.rework++;if(order.accounting)order.accounting.rework++;}s.stats.processed++;w.xp+=1+(s.workers.some(v=>v.id!==w.id&&v.mentor)?0.4:0);if(w.xp>=30&&w.skill<4){w.skill++;w.xp-=30;order.accounting?.growth?.push({worker:w.id,skill:w.skill});note(s,`${w.name}が実務で成長しました`);}w.job=null;}}}}
function validState(s){if(!s||s.version!==VERSION||![s.cash,s.clock,s.revenue,s.expense].every(n=>Number.isFinite(n)&&n>=0)||![[8,6],[10,8]].some(([w,h])=>s.width===w&&s.height===h)||!Number.isInteger(s.next)||s.next<1||!Number.isInteger(s.delivered)||!s.stats||!Object.values(s.stats).every(Number.isFinite))return false;if(!Array.isArray(s.machines)||s.machines.length>70||!Array.isArray(s.workers)||s.workers.length!==3||!Array.isArray(s.orders)||s.orders.length>3||!Array.isArray(s.parts)||s.parts.length>60||!Array.isArray(s.log))return false;const ids=new Set(),cells=new Set();for(const m of s.machines){if(!MACHINES[m.kind]||!Number.isInteger(m.level)||m.level<1||m.level>3||!Number.isInteger(m.x)||!Number.isInteger(m.y)||m.x<1||m.y<0||m.x>=s.width||m.y>=s.height-1||ids.has(m.id)||cells.has(`${m.x},${m.y}`))return false;ids.add(m.id);cells.add(`${m.x},${m.y}`);}if(!['cut','drill','inspect'].every(k=>s.machines.some(m=>m.kind===k)))return false;if(!s.machines.every(m=>path(s,{x:0,y:0},{x:m.x,y:m.y+1})!==null))return false;for(const o of s.orders){if(!['plate','shaft'].includes(o.product)||![o.qty,o.cost,o.pay,o.start,o.done,o.due,o.quality].every(n=>Number.isFinite(n)&&n>=0)||o.qty>28||o.done>o.qty||!Number.isInteger(o.id))return false;}const partIds=new Set();for(const p of s.parts){if(partIds.has(p.id)||!s.orders.some(o=>o.id===p.order)||!['plate','shaft'].includes(p.product)||!Number.isInteger(p.stage)||p.stage<0||p.stage>3||![p.x,p.y].every(Number.isFinite))return false;partIds.add(p.id);}for(const w of s.workers){if(!Number.isInteger(w.id)||typeof w.name!=='string'||![w.x,w.y,w.skill,w.xp].every(Number.isFinite)||w.skill<1||w.skill>4||!['auto','machine','inspect'].includes(w.role))return false;if(w.job&&(!partIds.has(w.job.part)||!ids.has(w.job.machine)||!Number.isFinite(w.job.remaining)||!Array.isArray(w.job.path)||!w.job.path.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y))))return false;}return true;}

export function validate(s){try {if(!validState(s)||!validAccounting(s)||!validBriefCredits(s)||!validPairLinks(s))return false;
 if(s.goalOffer!==undefined&&s.goalOffer!==null&&!OFFERS.some(o=>o.id===s.goalOffer&&o.growth))return false;
 const orders=new Map(s.orders.map(o=>[o.id,o]));if(orders.size!==s.orders.length)return false;
 if(new Set(s.workers.map(w=>w.id)).size!==3||!s.workers.every(w=>w.id>=0&&w.id<3&&w.x>=0&&w.y>=0&&w.x<s.width&&w.y<s.height&&w.xp>=0&&typeof w.mentor==='boolean'))return false;
 const assigned=new Set(),occupied=new Set();for(const w of s.workers){const j=w.job;if(!j)continue;if(assigned.has(j.part)||occupied.has(j.machine)||!['walk','work'].includes(j.phase)||!j.path.every(p=>Number.isInteger(p.x)&&Number.isInteger(p.y)&&p.x>=0&&p.y>=0&&p.x<s.width&&p.y<s.height))return false;const part=s.parts.find(p=>p.id===j.part),order=orders.get(part?.order);
 if(part?.stage===2&&order?.inspectorId!==undefined&&order.inspectorId!==w.id)return false;
 assigned.add(j.part);occupied.add(j.machine);}
 for(const p of s.parts){const o=orders.get(p.order);if(p.product!==o.product||o.shipped||typeof p.done!=='boolean'||p.done!==(p.stage===3)||p.busy!==assigned.has(p.id)||p.done&&p.busy||!Number.isInteger(p.x)||!Number.isInteger(p.y)||p.x<0||p.y<0||p.x>=s.width||p.y>=s.height)return false;}
 for(const o of s.orders){if(typeof o.label!=='string'||typeof o.shipped!=='boolean'||!Number.isInteger(o.qty)||!Number.isInteger(o.done)||![1,2,3].includes(o.quality))return false;const parts=s.parts.filter(p=>p.order===o.id);if(!o.shipped&&(parts.length!==o.qty||parts.filter(p=>p.done).length!==o.done))return false;}
 return s.log.every(t=>typeof t==='string'&&t.length<500);
 }catch{return false;}}

// Read-only summaries: queued items are counted once, at their NEXT stage only.
export function production(s, orderId=null) {
  const stages=Object.fromEntries(Object.keys(MACHINES).map(k=>[k,{waiting:0,walking:0,working:0}]));
  let complete=0;
  for(const p of s.parts){
    if(orderId!==null&&p.order!==orderId)continue;
    if(p.done){complete++;continue;}
    const st=stages[route(p.product)[p.stage]];
    const w=s.workers.find(w=>w.job?.part===p.id);
    st[w?w.job.phase==='walk'?'walking':'working':'waiting']++;
  }
  return {stages,complete};
}
export function frontOrder(s){
  const active=s.orders.filter(o=>!o.shipped);
  return active.find(o=>o.done===o.qty)||active[0]||null;
}

// A bounded chunk, yielding to the UI between calls. Never dispatch or skip past a ready order.
export function advanceToReady(s,maxTicks=100,onWalk=null,onAssign=null){
  const limit=Number.isFinite(maxTicks)?Math.max(0,Math.min(200,Math.floor(maxTicks))):0;
  let ticks=0;
  while(true){
    const o=frontOrder(s);
    if(!o)return {status:'idle',ticks};
    if(o.done===o.qty)return {status:'ready',ticks,orderId:o.id};
    if(ticks>=limit)return {status:'producing',ticks};
    step(s,TICK,{onWalk,onAssign});ticks++;
  }
}

// Optional accounting keeps pre-v0.3 saves playable without inventing history.
const nonnegative=n=>Number.isFinite(n)&&n>=0;
// Optional cost of the improvement bundled with this repeat; paid once, before production.
function validRepeatCost(record){
  return record.repeatCost===undefined||(record.offerId==='first'&&[0,1500,3000].includes(record.repeatCost));
}
function validQuote(id,q){
  if(q===undefined)return true;
  if(!q||!nonnegative(q.seconds)||!Number.isFinite(q.profit))return false;
  if(id==='fine'||id==='master')return q.rework===undefined||(Number.isInteger(q.rework)&&q.rework>=0&&q.rework<=10);
  return (id==='bulk'||id==='rush')&&q.rework===undefined;
}
function validCrewChoice(record){
  if(record.inspectorId===undefined&&record.qualitySpend===undefined)return true;
  return (record.offerId==='fine'||record.offerId==='master')&&[0,800,1500,1600,2400,3000].includes(record.qualitySpend)&&
    (record.inspectorId===undefined||[0,1,2].includes(record.inspectorId));
}
function validGrowth(record,events){
  if(events===undefined)return true;
  return record.qualitySpend!==undefined&&Array.isArray(events)&&events.length<=9&&
    events.every(e=>e&&[0,1,2].includes(e.worker)&&[2,3,4].includes(e.skill))&&
    new Set(events.map(e=>e.worker+','+e.skill)).size===events.length;
}
function validAccounting(s){
  for(const o of s.orders){
    if(!validBriefRecord(o)||!validPairRecord(o,o.id)||!validGrowth(o,o.accounting?.growth)||!validCrewChoice(o)||!validRepeatCost(o)||!validQuote(o.offerId,o.quote))return false;
    if(o.accounting===undefined&&o.offerId===undefined)continue;
    const offer=OFFERS.find(v=>v.id===o.offerId),a=o.accounting;
    if(!offer||!a||!['product','qty','cost','pay','quality'].every(k=>o[k]===offer[k])||![a.wages,a.walk,a.rework].every(nonnegative)||!Number.isInteger(a.rework)||a.rework>o.qty)return false;
    if(a.completedAt!==null&&(!nonnegative(a.completedAt)||a.completedAt<o.start||a.completedAt>s.clock||o.done!==o.qty))return false;
    if(o.done===o.qty&&a.completedAt===null)return false;
  }
  if(s.results===undefined)return !s.orders.some(o=>o.shipped&&o.briefId!==undefined);
  if(!Array.isArray(s.results)||s.results.length>12||s.results.length>s.delivered)return false;
  const ids=new Set();let lastTime=Infinity;
  for(const r of s.results){
    if(!r||!validBriefRecord(r,true)||!validPairRecord(r,r.orderId)||((r.pair||r.declinedExtra)&&r.wages===null)||!validGrowth(r,r.growth)||!validCrewChoice(r)||((r.quote||r.qualitySpend!==undefined)&&r.wages===null)||!validRepeatCost(r)||!validQuote(r.offerId,r.quote)||!Number.isInteger(r.orderId)||r.orderId<1||ids.has(r.orderId)||typeof r.label!=='string'||r.label.length>100||!Number.isInteger(r.qty)||r.qty<1||r.qty>28||typeof r.late!=='boolean'||![r.payout,r.material,r.shippedAt].every(nonnegative)||r.shippedAt>s.clock||r.shippedAt>lastTime)return false;
    ids.add(r.orderId);lastTime=r.shippedAt;
    const values=[r.wages,r.seconds,r.walk,r.rework];
    if(!values.every(v=>v===null)&&!(values.every(nonnegative)&&Number.isInteger(r.rework)&&r.rework<=r.qty&&r.seconds<=r.shippedAt))return false;
    if(r.offerId!==null){const offer=OFFERS.find(o=>o.id===r.offerId);if(!offer||r.qty!==offer.qty||r.material!==offer.cost||r.payout!==Math.round(offer.pay*(r.late?.85:1))+(r.briefBonus||0))return false;}
    else if(!values.every(v=>v===null))return false;
  }
  return s.orders.every(o=>{
    const receipt=s.results.find(r=>r.orderId===o.id);
    if(o.briefId===undefined&&receipt?.briefId===undefined)return true;
    if(!receipt)return !o.shipped;
    return o.shipped&&o.briefId===receipt.briefId&&receipt.seconds===o.accounting.completedAt-o.start&&receipt.walk===o.accounting.walk;
  });
}
export function resultProfit(r){return r.wages===null?null:r.payout-r.material-r.wages;}
export function previousResult(s,r){
  if(r.wages===null||r.offerId===null)return null;
  const i=(s.results||[]).findIndex(v=>v.orderId===r.orderId);
  return i<0?null:s.results.slice(i+1).find(v=>v.offerId===r.offerId&&v.wages!==null)||null;
}

export function shipmentQuote(s,o){
  const late=s.clock>o.start+o.due,base=Math.round(o.pay*(late?.85:1));
  if(o.briefId===undefined)return {late,pay:base};
  const a=o.accounting;
  const complete=o.done===o.qty&&Number.isFinite(a?.completedAt);
  const briefBonus=complete?assessBrief(o.briefId,{seconds:a.completedAt-o.start,walk:a.walk})?.bonus||0:0;
  return {late,pay:base+briefBonus,briefBonus};
}

// Eligibility is derived, not a permanent unlock: existing contracts keep running.
export function offerStatus(s,id){
  const o=OFFERS.find(v=>v.id===id);
  if(!o)return {available:false,qualified:false,requirements:[],reason:'注文が見つかりません'};
  const requirements=route(o.product).filter(kind=>kind==='lathe'||!s.machines.some(m=>m.kind===kind)).map(kind=>({label:`${MACHINES[kind].name}を設置`,met:s.machines.some(m=>m.kind===kind),panel:'machines'}));
  if(id==='rush'){
    const equipped=s.machines.filter(m=>m.kind==='drill').reduce((n,m)=>n+m.level,0)>=2;
    requirements.push({label:'ボール盤 Lv.2以上か2台、または金物店の紹介',met:equipped||earnedBriefs(s).length===2,panel:'machines'});
  }
  if(id==='master')requirements.push({label:'技能3以上の職人が1人',met:s.workers.some(w=>w.skill>=3),panel:'workers'});
  const missing=requirements.filter(r=>!r.met),qualified=missing.length===0;
  const reason=!qualified?'受注条件：'+missing.map(r=>r.label).join('・'):s.orders.filter(o=>!o.shipped).length>=2?'進行中の注文は2件まで':s.cash<o.cost?'材料費が足りません。支給材の注文を選べます':null;
  return {available:reason===null,qualified,requirements,reason};
}

export function setGoal(s,id){
  const o=OFFERS.find(o=>o.id===id&&o.growth);
  if(!o)return '成長案件を選んでください';
  s.goalOffer=id;note(s,`目標：${o.label}を納品しよう`);return null;
}

// Read-only preparation budget, not a throughput or on-time delivery forecast.
export function growthPlan(s,id){
  const offer=OFFERS.find(o=>o.id===id&&o.growth);
  if(!offer)return null;
  const status=offerStatus(s,id),preparations=[];
  if(id==='rush'&&!status.qualified){
    const drill=s.machines.find(m=>m.kind==='drill');
    preparations.push({type:'upgrade',id:drill.id,label:'ボール盤を改良',cost:1500*drill.level,total:1500*drill.level});
  }
  if(id==='master'){
    if(!s.machines.some(m=>m.kind==='lathe'))preparations.push({type:'purchase',kind:'lathe',label:'旋盤を設置',cost:MACHINES.lathe.cost,total:MACHINES.lathe.cost});
    const worker=[...s.workers].sort((a,b)=>b.skill-a.skill||a.id-b.id)[0];
    if(worker.skill<3){
      let total=0;for(let level=worker.skill;level<3;level++)total+=800*level;
      preparations.push({type:'train',id:worker.id,label:`${worker.name}を研修`,cost:800*worker.skill,total,target:3});
    }
  }
  const investment=preparations.reduce((n,p)=>n+p.total,0),required=investment+offer.cost;
  const shortage=Math.max(0,Math.ceil(required-s.cash));
  const active=s.orders.filter(o=>!o.shipped&&o.offerId===id);
  const order=active.find(o=>o.done===o.qty)||active[0]||null;
  let phase,next;
  if(order){
    phase=order.done===order.qty?'ship':'producing';
    next=phase==='ship'?{type:'ship',id:order.id,label:'出荷して入金'}:{type:'floor',label:'工場で生産を見る'};
  }else if(s.orders.filter(o=>!o.shipped).length>=2){phase='slots';next={type:'orders',label:'進行中の注文を確認'};}
  else if(shortage){phase='funds';next={type:'orders',label:'通常受注で資金を作る'};}
  else if(preparations.length){phase='prepare';next=preparations[0];}
  else{phase='ready';next={type:'accept',id,label:'受注して生産開始'};}
  return {offer,status,preparations,investment,required,shortage,order,phase,next};
}
