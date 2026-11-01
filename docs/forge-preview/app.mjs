import {SPECIALTIES,restoreSpecialties} from './specialties.mjs?v=0.24';
import {BRIEFS,briefTarget,briefOutcomeText,earnedBriefs} from './brief.mjs?v=0.24';
import {layoutEditor} from './layout-editor.mjs?v=0.24';
import {applyLayout} from './layout.mjs?v=0.24';
import {floorGesture,changeCamera} from './floor-input.mjs?v=0.16';
import {departureDuration} from './shipping.mjs?v=0.16';
import * as M from './model.mjs?v=0.24';
import {openingOffer,deliveryGuide,floorTicket} from './guidance.mjs?v=0.24';
import {repeatOffer,startRepeat,comparisonLine} from './improvement.mjs?v=0.24';
import {frameWorkshop,project,pickMachine} from './view.mjs?v=0.17';
import {drawWorkshop} from './workshop.mjs?v=0.24';
import {createArtLoader} from './miniature-art.mjs?v=0.17';
import {createEstimator} from './estimate-client.mjs?v=0.24';
import {acceptPrecision,installStarterLathe} from './precision.mjs?v=0.24';
import {precisionDesk,bindPrecisionDesk} from './precision-view.mjs?v=0.24';
import {advanceToReview,decideInquiry,inquiryContext} from './inquiry.mjs?v=0.24';
import {pairResult,yenGain} from './pairing.mjs?v=0.24';
import {bindInquiry,inquirySheet} from './inquiry-view.mjs?v=0.24';
const workshopArt=createArtLoader(),estimator=createEstimator();
const shaftChoice={offer:'fine',inspector:null,investment:'none',benchId:null};
const $=s=>document.querySelector(s),KEY='forge.factory.v1',canvas=$('#world'),ctx=canvas.getContext('2d');
let s=M.fresh(),speed=1,last=0,zoom=1,pan={x:0,y:0},placing=null,selected=null,tab=null,toastUntil=0,revision=null,writer=false,saveBlocked=false,paintTime=0,placementCells=[],resumeSpeed=1,skipping=null,tickRemainder=0,showLabels=false,lastDraw=-Infinity;
let freightSelection=null,growthFocus=null, recentShipment=null, departure=null;
const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
try{const raw=localStorage.getItem(KEY);if(raw){const env=JSON.parse(raw);if(!M.validate(env.state))throw Error('invalid');s=env.state;restoreSpecialties(s);revision=env.revision;}}catch{saveBlocked=true;speed=0;}
// A completed saved order remains safe to dispatch after reopening the page.
if(s.orders.some(o=>!o.shipped&&o.done===o.qty))speed=0;
function toast(t){if(tab){$('#sheetNotice').textContent=t;$('#sheetNotice').hidden=false;}$('#toast').textContent=t;$('#toast').style.display='block';toastUntil=performance.now()+4200;}
function save(){if(!writer||saveBlocked)return;try{const previous=localStorage.getItem(KEY);if(previous&&JSON.parse(previous).revision!==revision){writer=false;speed=0;toast('別の画面で保存されました。再読み込みしてください');return;}revision=crypto.randomUUID?.()||String(Date.now()+Math.random());localStorage.setItem(KEY,JSON.stringify({revision,state:s}));}catch{saveBlocked=true;toast('保存できません。設定から進行を書き出せます');}}
if(navigator.locks){navigator.locks.request(KEY,{ifAvailable:true},async lock=>{if(!lock){toast('別のタブで起動中です。この画面は閲覧専用');return;}writer=true;update();if(saveBlocked)toast('保存データを読み込めません。上書きせず停止しました');await new Promise(resolve=>window.addEventListener('pagehide',()=>{save();resolve();},{once:true}));});}else{writer=true;}
window.addEventListener('storage',e=>{if(e.key===KEY){writer=false;speed=0;toast('別画面の更新を検出。再読み込みしてください');}});
window.addEventListener('pageshow',e=>{if(e.persisted){writer=false;speed=0;toast('復帰しました。続けるには再読み込みしてください');}});
document.addEventListener('visibilitychange',()=>{if(document.hidden){departure=null;stopSkip();}save();last=0;tickRemainder=0;});window.addEventListener('pagehide',save);setInterval(save,5000);
function act(fn,announce=true){if(!writer||saveBlocked){toast(saveBlocked?'保存に問題があります。設定を開いてください':'別画面で起動中です。再読み込みしてください');return;}stopSkip();const before=new Set(M.OFFERS.filter(o=>o.growth&&M.offerStatus(s,o.id).qualified).map(o=>o.id));const error=fn();if(error)toast(error);else{const unlocked=M.OFFERS.filter(o=>o.growth&&!before.has(o.id)&&M.offerStatus(s,o.id).qualified);if(unlocked.length)M.note(s,`受注条件を達成：${unlocked.map(o=>o.label).join('・')}`);recentShipment=null;save();if(announce)toast(s.log[0]);}update();if(tab)renderPanel();return !error;}
const money=v=>'¥'+Math.floor(v).toLocaleString('ja-JP');
function update(){
  const ticket=floorTicket(s,{skipping:!!skipping,paused:speed===0,shipment:recentShipment});
  const button=$('#orderAction');
  $('.order-strip').hidden=!!placing;
  $('#controls').hidden=!!placing;
  $('#placementBar').hidden=!placing;
  if(placing)$('#confirmPlace').disabled=placing.editor?!placing.editor.canConfirm():!placing.candidate||!writer||saveBlocked;
  $('#cash').textContent=money(s.cash);
  $('#ticketLabel').textContent=ticket.label;
  const consult=!placing&&!skipping&&inquiryContext(s),entry=$('#inquiryEntry');
  entry.hidden=!consult;entry.disabled=!writer||saveBlocked;
  if(consult)entry.textContent=consult.extra?'作業順の見直し':'＋6個の相談';
  const active=M.frontOrder(s);
  const latest=s.results?.[0];
  const shownReport=recentShipment||(!active&&(!s.goalOffer||latest?.repeatCost!==undefined||latest?.qualitySpend!==undefined||latest?.pair||latest?.declinedExtra)?latest:null);
  const result=!active&&pairResult(shownReport);
  const briefId=!active&&shownReport?.briefId;
  const comparison=briefId?BRIEFS[briefId].label+' '+briefOutcomeText(briefId,shownReport):result?pairLine(result,false):active?'':shownReport?.declinedExtra?declineLine(shownReport):comparisonLine(s,shownReport);
  $('#orderComparison').textContent=comparison;
  $('#orderComparison').classList.toggle('brief-outcome',!!briefId);
  $('#orderComparison').hidden=!comparison;
  if(result)$('#ticketLabel').textContent='出荷完了 · 先約＋小口';
  else if(recentShipment||(comparison&&!s.goalOffer)){
    const profit=M.resultProfit(shownReport);
    if(shownReport.qualitySpend!==undefined)$('#ticketLabel').textContent='出荷完了 · 手残り '+signedMoney(profit-shownReport.qualitySpend);
    else $('#ticketLabel').textContent='出荷完了 · '+(profit===null?'入金 '+money(shownReport.payout):'受注利益 '+signedMoney(profit)+(shownReport.repeatCost?' · 改良費 '+money(shownReport.repeatCost):''));
  }
  $('#orderTitle').textContent=active?.pair?(active.id===active.pair.primary?'先約 · ':'小口 · ')+ticket.title:result?'2件の受注利益 '+roundedCash(result.profit):comparison&&(recentShipment||!s.goalOffer)?shownReport.label+' '+shownReport.qty+(M.OFFERS.find(o=>o.id===shownReport.offerId)?.product==='shaft'?'本':'個')+'を出荷':ticket.title;
  if(briefId&&!s.goalOffer&&shownReport.briefBonus){
    $('#orderTitle').textContent=earnedBriefs(s).length===2?'金物店の紹介 · 28個の短納期便':'金物店の紹介まであと1種類';
  }
  let floorHint=ticket.hint,action=ticket.action;
  if(skipping?.review)floorHint='先約の半分で止まり、小口の相談に戻ります。';
  else if(consult?.extra)floorHint=(consult.primary.pair.priority==='primary'?'先約優先':'小口優先')+' · 追加の6個は '+consult.extra.done+'/6個完成。';
  const stamp=(recentShipment||!s.goalOffer||s.goalOffer===latest?.offerId)&&!active&&s.specialties?.find(e=>e.orderId===latest?.orderId);
  $('.order-strip').classList.toggle('earned-sign',!!stamp&&!result);
  if(stamp){
    if(!result){
      $('#ticketLabel').textContent=stampCaption(stamp);
      $('#orderTitle').textContent=SPECIALTIES[stamp.offerId];
      if(s.specialties.length===1){
        const next=stamp.offerId==='rush'?'master':'rush';
        action={type:'growth',id:next,label:(next==='master'?'精密':'量産')+'の仕事を見る'};
      }else action={type:'panel',panel:'growth',label:'この工場で続ける'};
    }
    floorHint=(result?SPECIALTIES[stamp.offerId]+' · ':'')+stampDetail(stamp);
  }else if(active&&!skipping&&Object.hasOwn(SPECIALTIES,active.offerId)&&!s.specialties?.some(e=>e.offerId===active.offerId)){
    $('#ticketLabel').textContent=ticket.label+' · '+SPECIALTIES[active.offerId]+'に挑戦';
  }
  $('#orderHint').textContent=floorHint;
  $('#orderHint').hidden=!floorHint;
  button.textContent=action.label;
  button.disabled=!!placing||!writer||saveBlocked;
  button.onclick=()=>runFloorAction(action);
  $('#orderProgress').hidden=!ticket.progress;
  $('#orderProgress').style.width=(ticket.progress||0)*100+'%';
  const busy=s.workers.filter(w=>w.job).length;
  $('#activity').textContent='第一工場 '+s.width+'×'+s.height+' · '+busy+'/'+s.workers.length+'人作業中';
  updateSelection();
  document.querySelectorAll('[data-speed]').forEach(b=>{
    const current=+b.dataset.speed===speed;
    b.classList.toggle('active',current);
    b.setAttribute('aria-pressed',String(current));
    b.disabled=!!placing;
  });
}
$('#inquiryEntry').onclick=()=>{if(inquiryContext(s))open('inquiry');};
function runFloorAction(action){
  if(placing||!writer||saveBlocked)return;
  if(action.type==='accept'){
    if(!M.frontOrder(s)&&act(()=>M.accept(s,action.id),false)){speed=speed||1;update();}
  }else if(action.type==='stop')stopSkip();
  else if(action.type==='skip')startSkip();
  else if(action.type==='ship')ship(action.id);
  else if(action.type==='briefRetry')retryBrief(action.id);
  else if(action.type==='growth')open('growth',action.id);
  else if(action.type==='panel')open(action.panel);
}
function retryBrief(id){
  const trial=repeatOffer(s);
  if(trial)place({id:trial.drill.id,kind:'drill',trial:true,briefId:id});
}
const sheetTrail=[];
function open(panel,focusId=null,restoring=false,term=null){
  freightSelection=term;
  const sheet=$('#sheet');
  if(!tab)sheetTrail.length=0;
  else if(!restoring&&tab!==panel){
    const ancestor=sheetTrail.findIndex(entry=>entry.panel===panel&&entry.focusId===focusId);
    if(ancestor>=0)sheetTrail.length=ancestor;
    else sheetTrail.push({panel:tab,focusId:growthFocus,scroll:sheet.scrollTop,
      focusIndex:[...$('#sheetBody').querySelectorAll('button,summary,select')].indexOf(document.activeElement)});
  }
  growthFocus=panel==='growth'?focusId:null;
  stopSkip();if(placing)endPlacement();
  $('#controls').open=false;
  tab=panel;sheet.dataset.panel=panel;$('#sheetNotice').hidden=true;
  $('#sheetBack').hidden=sheetTrail.length===0;
  renderPanel();if(!sheet.open)sheet.showModal();
  sheet.scrollTop=0;$('#sheetTitle').focus({preventScroll:true});updateSelection();
}
$('#sheetBack').onclick=()=>{
  const previous=sheetTrail.pop();
  if(!previous)return;
  open(previous.panel,previous.focusId,true);
  const control=$('#sheetBody').querySelectorAll('button,summary,select')[previous.focusIndex];
  control?.focus({preventScroll:true});
  $('#sheet').scrollTop=previous.scroll;
};
function close(){estimator.cancel();tab=null;sheetTrail.length=0;$('#sheet').close();updateSelection();}
$('#close').onclick=close;
$('#sheet').addEventListener('cancel',()=>{estimator.cancel();tab=null;sheetTrail.length=0;updateSelection();});
$('#menu').onclick=()=>open('manage');
$('#controls').addEventListener('toggle',()=>{if($('#controls').open){selected=null;updateSelection();}});
document.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>{
  stopSkip();speed=+b.dataset.speed;
  if(speed===0)draw();
  update();
});
function zoomButton(delta){
  const center={x:canvas.clientWidth/2,y:canvas.clientHeight/2};
  applyCamera(center,center,(zoom+delta)/zoom);
}
$('#plus').onclick=()=>zoomButton(.25);
$('#minus').onclick=()=>zoomButton(-.25);
$('#labels').onclick=()=>{showLabels=!showLabels;$('#labels').setAttribute('aria-pressed',String(showLabels));$('#labels').setAttribute('aria-label',showLabels?'設備名を隠す':'設備名を表示');};
$('#viewReset').onclick=()=>{zoom=1;pan={x:0,y:0};selected=null;updateSelection();draw();};
const stageNames={cut:'切断',drill:'穴あけ',lathe:'旋盤',inspect:'検品'};
function selectMachine(id,focus=false){
  selected=id;
  if(id)$('#controls').open=false;
  const m=s.machines.find(m=>m.id===id);
  updateSelection();
  if(m)requestAnimationFrame(()=>{
    if(selected!==id||!viewport.u)return;
    const cardHeight=$('#machineQuick').getBoundingClientRect().height;
    const p=point(m.x+.5,m.y+.5,.5),targetY=Math.max(55,Math.min(viewport.h*.32,viewport.h-64-cardHeight-40));
    // Direct taps only move the camera if the card would cover the selected tool.
    const cardTop=$('#machineQuick').getBoundingClientRect().top-canvas.getBoundingClientRect().top;
    if(focus){pan.x+=viewport.w*.5-p.x;pan.y+=targetY-p.y;}
    else if(p.y+viewport.u*.75>cardTop)pan.y-=p.y+viewport.u*.75-cardTop+8;
  });
}
function updateSelection(){
  const q=M.production(s).stages,m=s.machines.find(m=>m.id===selected);
  if(!m)selected=null;
  for(const [kind,name] of Object.entries(stageNames)){
    let b=$(`#flow [data-stage="${kind}"]`);
    if(!b){b=document.createElement('button');b.dataset.stage=kind;b.onclick=()=>{
      const machines=s.machines.filter(m=>m.kind===kind),i=machines.findIndex(m=>m.id===selected);
      if(machines.length)selectMachine(machines[(i+1)%machines.length].id,true);
    };$('#flow').append(b);}
    b.hidden=!s.machines.some(m=>m.kind===kind);b.disabled=!!placing;
    b.textContent=`${name} ${q[kind].waiting}`;
    b.dataset.active=String(q[kind].working>0&&(speed>0||!!skipping)&&!tab);
    b.setAttribute('aria-label',`${M.MACHINES[kind].name}：工程待ち${q[kind].waiting}個。設備を選択`);
    b.setAttribute('aria-pressed',String(m?.kind===kind));
  }
  $('#machineQuick').hidden=!m||!!placing||!!tab;
  if(!m)return;
  const w=s.workers.find(w=>w.job?.machine===m.id),counts=q[m.kind];
  const peers=s.machines.filter(x=>x.kind===m.kind);
  $('#machineTitle').textContent=`${M.MACHINES[m.kind].name}${peers.length>1?' '+(peers.findIndex(x=>x.id===m.id)+1)+'/'+peers.length:''} · Lv.${m.level}`;
  const jobPart=w&&s.parts.find(p=>p.id===w.job.part),jobOrder=jobPart&&s.orders.find(o=>o.id===jobPart.order);
  const lot=jobOrder?.pair?(jobOrder.id===jobOrder.pair.primary?'先約 · ':'小口 · '):'';
  $('#machineWorker').textContent=w?`${w.name} · ${lot}${w.job.phase==='walk'?'運搬中（光る線が経路）':w.job.rework?'品質調整中':'加工中'}`:'担当者・材料待ち';
  $('#machineEffect').innerHTML=machineEffect(m,true);
  $('#machineQueue').textContent=`同種工程：待ち ${counts.waiting} · 運搬 ${counts.walking} · 加工 ${counts.working}`;
  $('#quickUpgrade').textContent=m.level>=3?'改良済み':`改良 ${money(1500*m.level)}`;
  $('#quickUpgrade').disabled=m.level>=3||s.cash<1500*m.level;
}
$('#quickClose').onclick=()=>{selected=null;updateSelection();};
$('#quickMove').onclick=()=>{const m=s.machines.find(m=>m.id===selected);if(m)place({id:m.id,kind:m.kind});};
$('#quickUpgrade').onclick=()=>act(()=>M.upgrade(s,selected));
$('#quickDetail').onclick=()=>open('machines');
const seconds=v=>v.toFixed(1)+'秒';
function fundsAfter(cost){return `<small class="investment-funds ${s.cash<cost?'short':''}">${s.cash<cost?'あと '+money(Math.ceil(cost-s.cash))+' 必要':'投資後の手元 '+money(s.cash-cost)}</small>`;}
function machineEffect(m,compact=false){
  const before=M.processingTime(m.kind,{level:m.level});
  const after=m.level<3?M.processingTime(m.kind,{level:m.level+1}):null;
  if(compact)return `<div class="quick-investment"><span>基準加工 · 技能1</span><b>${seconds(before)}${after!==null?' → '+seconds(after):' / 個'}</b></div><small>運搬・待ち時間は別。改良は次の作業から。</small>`;
  const quality=m.kind==='inspect'?`<small>調整なしで検品：品質${m.level}${after!==null?' → '+(m.level+1):'まで'}</small>`:'';
  return `<div class="investment-effect"><div><span>${compact?'単体加工':'1個の基準加工'}</span><b>${seconds(before)}${after!==null?' <span>→</span> '+seconds(after):' / 個'}</b></div>${quality}<small>技能1・品質調整なし。運搬・担当待ちは別。</small>${after!==null?fundsAfter(1500*m.level):'<small>最高レベルです</small>'}</div>`;
}
function workerEffect(w){
  const next=w.skill<4?w.skill+1:null;
  const rows=Object.keys(stageNames).flatMap(kind=>{
    const m=s.machines.find(m=>m.kind===kind);if(!m)return [];
    const before=M.processingTime(kind,{skill:w.skill,level:m.level,mentor:w.mentor});
    const after=next?M.processingTime(kind,{skill:next,level:m.level,mentor:w.mentor}):null;
    return [`<div><span>${stageNames[kind]} <small>設備Lv.${m.level}</small></span><b>${seconds(before)}${after!==null?' <span>→</span> '+seconds(after):' / 個'}</b></div>`];
  }).join('');
  const inspection=s.machines.find(m=>m.kind==='inspect'),quality=skill=>Math.min(3,skill+inspection.level-1);
  return `<div class="investment-effect">${rows}<small>検品台Lv.${inspection.level}で調整なし：品質${quality(w.skill)}${next&&quality(next)!==quality(w.skill)?' → '+quality(next):'まで'}</small><small>各工程の1個あたり・品質調整なし。${w.mentor?'指導中の時間増を含みます。':''}</small>${next?fundsAfter(800*w.skill):'<small>最高技能です</small>'}</div>`;
}
const card=(title,body,className='')=>`<article class="card ${className}"><h3>${title}</h3>${body}</article>`;
function improvementSheet(){
  const trial=repeatOffer(s);
  if(!trial)return '<p>現在の注文や準備状況を確認できます。</p><button class="wide" data-next="orders">注文一覧へ</button>';
  const {report,offer,drill,upgradeCost}=trial,material=offer.cost;
  const before=M.processingTime('drill',{level:drill.level});
  const next=M.processingTime('drill',{level:drill.level+1});
  const total=upgradeCost===null?null:material+upgradeCost;
  const unlock=!M.offerStatus(s,'rush').qualified;
  const upgradeText=upgradeCost===null?'このボール盤は最高レベルです。':
    `技能1の穴あけ ${seconds(before)} → ${seconds(next)}／個。${unlock?'短納期の注文も開きます。':''}`;
  const disabled=total===null||s.cash<total||!writer||saveBlocked;
  const shortage=total!==null&&s.cash<total?'あと '+money(Math.ceil(total-s.cash))+' 必要':'';
  return `<p class="trial-baseline"><strong>取付プレート ${offer.qty}個 · 再注文</strong>前回 ${seconds(report.seconds)} · 移動 ${Math.round(report.walk)}マス<br>今回の材料費 ${money(material)}</p>
    <article class="card trial-choice"><div><h3>設備の配置を組み直す</h3><small>移設 ¥0</small></div><p>改善依頼の達成で＋¥400。早仕上げ・省運搬を両方達成すると、金物店が28個の短納期便を紹介してくれます。</p><button class="wide" id="trialMove" ${!writer||saveBlocked?'disabled':''}>置き場所を試す</button></article>
    <article class="card trial-choice"><div><h3>ボール盤を改良する</h3><small>${upgradeCost===null?'最高レベル':'改良 '+money(upgradeCost)}</small></div><p>${upgradeText}</p>${!disabled?'<small id="upgradeEstimate">12個の見積中…</small>':''}<button class="wide" id="trialUpgrade" ${disabled?'disabled':''}>${total===null?'改良済み':'改良して受注 · '+money(total)}</button>${shortage?'<small>'+shortage+'</small>':''}</article>
    <button class="wide" data-next="growth">改善はあとで · 成長目標へ</button>`;
}

function deadlineText(row){
  return Math.abs(row.margin).toFixed(1)+'秒'+(row.late?'超過':'余裕');
}
function roundedCash(value){
  return '¥'+Math.round(value).toLocaleString('ja-JP');
}
function setupPanelEstimate(){
  if(tab==='inquiry'){
    bindInquiry($('#sheetBody'),s,estimator,writer&&!saveBlocked,(ids,priority,solo)=>{
      if(act(()=>decideInquiry(s,ids.primaryId,priority,solo,ids.extraId),false)){
        if(priority!=='decline'&&ids.extraId===null)speed=speed||1;
        close();update();$('#orderAction').focus({preventScroll:true});
      }
    },(id,target)=>{
      if(!writer||saveBlocked||inquiryContext(s)?.primary.id!==id)return;
      close();startSkip({id,target});
    });
    return;
  }
  if(tab==='precision'){
    bindPrecisionDesk($('#sheetBody'),s,shaftChoice,estimator,writer&&!saveBlocked,
      ()=>place({kind:'lathe',precisionLathe:true}),(choice,quote,next)=>{
        if(act(()=>acceptPrecision(s,choice,quote,next),false)){
          shaftChoice.investment='none';close();speed=speed||1;update();$('#orderAction').focus({preventScroll:true});
        }
      });
    return;
  }
  const output=$('#upgradeEstimate');
  if(output){
    estimator.request(s,[{repeat:'upgrade'}],rows=>{
      const quote=rows?.[0];
      output.textContent=quote&&!quote.error?'12個の見積 '+seconds(quote.seconds)+' · 改良費を引くと '+signedMoney(quote.net):'見積を表示できません';
    });
    return;
  }
  const picker=$('#termPicker');
  if(!picker){estimator.cancel();return;}
  const accept=$('#acceptTerm');
  const quotes=new Map();
  accept.onclick=()=>{
    if(!tab||!accept.isConnected)return;
    const id=picker.querySelector('input:checked').value;
    if(act(()=>M.accept(s,id,quotes.get(id)))){close();speed=speed||1;update();}
  };
  picker.onchange=()=>{
    const id=picker.querySelector('input:checked').value;freightSelection=id;
    const o=M.OFFERS.find(o=>o.id===id);
    accept.textContent='受注して生産開始 · 材料 '+money(o.cost);
  };
  const terms=['bulk','rush'];
  estimator.request(s,terms.map(offer=>({offer})),rows=>{
    terms.forEach((id,i)=>{
      const el=picker.querySelector('[data-estimate="'+id+'"]'),q=rows?.[i];
      if(q&&!q.error)quotes.set(id,{seconds:q.seconds,profit:q.profit});
      el.textContent=q&&!q.error?seconds(q.seconds)+'で完成 · '+deadlineText(q)+' ／ 利益 '+roundedCash(q.profit):q?.error||'見積を表示できません';
    });
  });
  const select=$('#estimateMachine');
  if(select)$('#testLayout').onclick=()=>{
    const machine=s.machines.find(m=>m.id===select.value);
    if(machine&&!M.frontOrder(s))place({id:machine.id,kind:machine.kind,estimateOffer:picker.querySelector('input:checked').value});
  };
}

function freightTerms(s,focused=false){
  const canRush=M.offerStatus(s,'rush').available;
  const selected=canRush&&freightSelection!=='bulk'?'rush':'bulk';
  const rows=['bulk','rush'].map(id=>{
    const o=M.OFFERS.find(o=>o.id===id);
    return `<label><input type="radio" name="freightTerm" value="${id}" ${id===selected?'checked':''} ${id==='rush'&&!canRush?'disabled':''}><span><strong>${id==='rush'?'短納期便':'通常便'} · 納期${o.due}秒</strong><small data-estimate="${id}">見積中…</small></span></label>`;
  }).join('');
  const offer=M.OFFERS.find(o=>o.id===selected);
  const machines=s.machines.filter(m=>m.kind!=='lathe').map(m=>`<option value="${escape(m.id)}">${M.MACHINES[m.kind].name}（${m.x+1}列${m.y+1}段）</option>`).join('');
  const layout=M.frontOrder(s)?'':`<details class="term-layout"><summary>設備の配置を試す</summary><label>移す設備 <select id="estimateMachine">${machines}</select></label><button id="testLayout" class="wide">床で配置を試す</button></details>`;
  return `<fieldset id="termPicker"><legend>${focused?'納品条件を選ぶ':'同じ28個の受注見積'}</legend>${rows}</fieldset><small class="estimate-note">今の人員・配置で追加受注せず、各注文を完成時に出荷する見積。利益は材料・人件費を引いた額です。</small><button id="acceptTerm" class="wide primary" ${!writer||saveBlocked?'disabled':''}>受注して生産開始 · 材料 ${money(offer.cost)}</button>${layout}`;
}

function renderPanel(){const body=$('#sheetBody');$('#sheetTitle').textContent=({manage:'工場の管理',orders:'受注と出荷',growth:'成長案件',machines:'設備と配置',workers:'職人を育てる',finance:'経営と拡張',save:'保存と設定',result:'出荷結果',improve:'工場の改善',precision:'10本の段取り',inquiry:'小口6個の相談'})[tab];let html='';
if(tab==='improve')html=improvementSheet();
if(tab==='inquiry')html=inquirySheet(s,writer&&!saveBlocked);
if(tab==='precision')html=precisionDesk(s,shaftChoice,writer&&!saveBlocked,escape);
if(tab==='manage'){
  const links=[['orders','注文一覧'],['growth','成長目標'],['machines','設備と配置'],['workers','職人と研修'],['finance','経営と出荷記録'],['save','保存と設定']];
  html='<div class="manage-links">'+links.map(([panel,label])=>'<button data-next="'+panel+'">'+label+' <span aria-hidden="true">›</span></button>').join('')+'</div>';
}
if(tab==='orders'){
  for(const o of s.orders.filter(o=>!o.shipped)){
    const remain=Math.ceil(o.start+o.due-s.clock),quote=M.shipmentQuote(s,o);
    html+=card(escape(o.label),`<small>生産中 · ${o.qty}個 / 品質 ${o.quality}</small><p>${o.done}個完成 · ${!quote.late?'納期まで '+remain+'秒':'納期超過：基本報酬15%減額'}${o.briefId?'<br>改善依頼 · '+briefTarget(o.briefId):''}</p><progress value="${o.done}" max="${o.qty}"></progress><button class="primary wide" data-ship="${o.id}" ${o.done<o.qty?'disabled':''}>出荷して ${money(quote.pay)} を受け取る</button>`);
  }
  const recommended=openingOffer(s);
  html+=recommended?'<p>まずは一件、受注 → 完成まで進める → 出荷。詳細画面を開いている間は時間が止まります。</p>':'<p>同時受注は2件。受注時に材料を購入します。詳細画面を開いている間は時間が止まります。</p>';
  if(recommended)html+=offerCard(recommended,true);
  else if(repeatOffer(s))html+='<button class="wide" data-next="improve">前回の12個で改善を試す</button>';
  html+='<button class="wide growth-entry" data-next="growth">成長案件 · 投資で次の仕事へ ↗</button>';
  if(recommended)html+='<h3 class="other-offers">ほかの注文</h3>';
  for(const o of M.OFFERS.filter(o=>!o.growth&&o.id!==recommended?.id))html+=offerCard(o);
}
if(tab==='growth'){
  const offers=M.OFFERS.filter(o=>o.growth),rush=M.growthPlan(s,'rush');
  if(growthFocus==='rush'&&canCompareFreight(rush)){
    $('#sheetTitle').textContent='28個の受注見積';
    html=growthCard(rush.offer,true)+'<button class="wide" id="allGrowth">ほかの成長目標を見る</button>';
  }else{
    html='<p>量産か精密、得意にしたい方を選んでください。その仕事を納期内に初出荷すると、町工場の看板がつきます。</p>'+offers.sort((a,b)=>Number(b.id===(growthFocus||s.goalOffer))-Number(a.id===(growthFocus||s.goalOffer))).map(o=>growthCard(o)).join('')+'<button class="wide" data-next="orders">通常の注文を見る</button>';
  }
}
if(tab==='machines'){
  html='<p>改良の効果は次の作業割当から。表示は加工だけの時間で、注文全体は配置や職人の担当でも変わります。移動では今の工程を仕上げて停止し、配置後は直前の再生速度に戻ります。</p>';
  for(const m of [...s.machines].sort((a,b)=>Number(b.id===selected)-Number(a.id===selected))){
    const worker=s.workers.find(w=>w.job?.machine===m.id),q=M.production(s).stages[m.kind];
    html+=card(`${m.id===selected?'<span class="tag">選択中</span> ':''}${M.MACHINES[m.kind].name}　Lv.${m.level}`,`<small>${worker?worker.job.phase==='walk'?'担当者が運搬中':worker.job.rework?'品質調整中':'加工中':'担当者・材料待ち'} · 座標 ${m.x}, ${m.y}</small><p>同種工程：待ち ${q.waiting}個 · 運搬 ${q.walking}個 · 加工 ${q.working}個</p>${machineEffect(m)}<div class="row"><button data-move="${m.id}">移動</button><button data-upgrade="${m.id}" ${m.level>=3||s.cash<1500*m.level?'disabled':''}>${m.level>=3?'改良済み':`Lv.${m.level+1}に改良 · ${money(1500*m.level)}`}</button><button data-sell="${m.id}">売却</button></div>`);
  }
  html+='<h3>新しい設備</h3>';
  for(const [k,m]of Object.entries(M.MACHINES))html+=card(m.name,`<small>${k==='lathe'?'精密シャフトを生産できるようになります':'台数を増やすと並行作業ができます'}</small><p>基準加工 ${seconds(M.processingTime(k))} / 個 · 技能1</p>${fundsAfter(m.cost)}<button class="wide primary" data-buy="${k}" ${s.cash<m.cost?'disabled':''}>設置場所を選ぶ · ${money(m.cost)}</button>`);
}
if(tab==='workers'){
  html='<p>研修の効果は次の作業割当から。現在の設備を1台ずつ使う場合の加工時間です。運搬・担当待ちは別。技能は仕事の経験でも育ちます。</p>';
  for(const w of s.workers)html+=card(`${escape(w.name)} <span class="tag">技能 ${w.skill}${w.skill<4?' → '+(w.skill+1):''}</span>`,`<small>経験 ${Math.floor(w.xp)} / 30 · ${w.job?'作業中':'待機中'}</small>${workerEffect(w)}<div class="row"><select data-role="${w.id}" aria-label="${escape(w.name)}の担当">${[['auto','全工程'],['machine','加工優先'],['inspect','検品優先']].map(([v,l])=>`<option value="${v}" ${w.role===v?'selected':''}>${l}</option>`).join('')}</select><button data-train="${w.id}" ${w.skill>=4||s.cash<800*w.skill?'disabled':''}>${w.skill>=4?'最高技能':`技能${w.skill+1}へ研修 · ${money(800*w.skill)}`}</button></div><button class="wide" data-mentor="${w.id}">${w.mentor?'指導を終了':'指導役にする'}</button><small>指導中は本人の加工時間+25%、仲間の獲得経験+40%。担当は優先順位で、他工程も手伝います。</small>`);
}
if(tab==='result'){const r=s.results?.[0];html=r?receipt(r,true):'<p>まだ出荷記録がありません。</p>';}
if(tab==='finance'){html=workshopRecord()+card('工場の状況','<div class="row"><span>出荷実績</span><b>'+s.delivered+'件</b></div><div class="row"><span>工場時間</span><b>'+Math.floor(s.clock/60)+'分'+Math.floor(s.clock%60)+'秒</b></div>')+card('収支',`<div class="row"><span>累計売上</span><b>${money(s.revenue)}</b></div><div class="row"><span>材料・投資・人件費</span><b>${money(s.expense)}</b></div><p>加工する部品がある間、人件費は毎秒¥0.7。画面を閉じている間の生産・請求はありません。</p>`)+'<h3>出荷の振り返り</h3><p>直近12件を保存。利益は設備・研修・増築費を引く前の金額です。</p>'+(s.results?.length?'<button class="wide" data-next="result">直近の出荷結果を開く</button>'+s.results.map(r=>`<details class="result-history"><summary>${escape(r.label)} × ${r.qty}<b>${M.resultProfit(r)===null?'記録なし':signedMoney(M.resultProfit(r))}</b></summary>${receipt(r,false)}</details>`).join(''):'<p>出荷すると結果をここで見返せます。</p>')+card('工場を広げる',`<p>床面積を8×6から10×8へ。追加設備と動線のための余白を作ります。</p><button class="primary wide" id="expand" ${s.width===10?'disabled':''}>${s.width===10?'拡張済み':'増築する · ¥3,500'}</button>`)+card('生産の記録',`<p>完了工程 ${s.stats.processed}回<br>品質調整 ${s.stats.rework}回<br>運搬・移動距離 ${Math.floor(s.stats.walk)}マス</p>`)+card('工場日誌',s.log.map(t=>`<p>${escape(t)}</p>`).join(''));}
if(tab==='save'){html=card('進行は自動保存',`<p>${saveBlocked?'保存エラー：元データは上書きしていません。書き出して保管できます。':writer?'このブラウザに5秒ごとに保存しています。':'別のタブで起動中、または復帰後の閲覧状態です。再読み込みしてください。'}<br>旧フロトラの保存データとは独立しています。</p><button id="export" class="wide">セーブを書き出す</button><label><p>書き出したセーブを読み込む（現在の進行と置き換え）</p><input id="import" type="file" accept="application/json,.json"></label><button id="reload" class="wide">再読み込み</button>`)+card('遊び方','<p>① 受注で材料を購入<br>② 完成まで進めるで待ち時間をスキップ（人件費・納期も進む）<br>③ 完成した注文を出荷して入金<br>④ 設備の追加・改良、研修に再投資<br><br>工場はドラッグで移動。二本指で拡大縮小できます。「操作」でも速度、拡大縮小、全景表示、設備名を切り替えられます。機械や工程待ちをタップすると、担当者・運搬経路を確認して移動・改良できます。同じ工程をもう一度押すと次の同種設備を選びます。配置では光る床を押して仮置きし、画面下で確定します。矢印キーでも候補を選べます。</p><small>開発版 v0.24</small>');}
body.innerHTML=html;
setupPanelEstimate();
if($('#allGrowth'))$('#allGrowth').onclick=()=>open('growth');
if(tab==='improve'){
  const trial=repeatOffer(s);
  if(trial){
    $('#trialMove').onclick=()=>place({id:trial.drill.id,kind:'drill',trial:true});
    $('#trialUpgrade').onclick=()=>{
      if(act(()=>startRepeat(s,'upgrade'),false)){
        selected=null;close();speed=speed||1;update();$('#orderAction').focus({preventScroll:true});
      }
    };
  }
}
body.querySelectorAll('[data-result-action]').forEach(b=>b.onclick=()=>runResultAction(b.dataset.resultAction));body.querySelectorAll('[data-goal]').forEach(b=>b.onclick=()=>{if(act(()=>M.setGoal(s,b.dataset.goal))){growthFocus=null;renderPanel();$('#sheet').scrollTop=0;}});body.querySelectorAll('[data-plan-action]').forEach(b=>b.onclick=()=>runPlan(b.dataset.planAction));body.querySelectorAll('[data-next]').forEach(b=>b.onclick=()=>open(b.dataset.next));body.querySelectorAll('[data-order]').forEach(b=>b.onclick=()=>{if(!tab||!b.isConnected)return;if(act(()=>M.accept(s,b.dataset.order))){close();speed=speed||1;update();}});body.querySelectorAll('[data-ship]').forEach(b=>b.onclick=()=>ship(+b.dataset.ship));body.querySelectorAll('[data-buy]').forEach(b=>b.onclick=()=>place({kind:b.dataset.buy}));body.querySelectorAll('[data-move]').forEach(b=>b.onclick=()=>place({id:b.dataset.move,kind:s.machines.find(m=>m.id===b.dataset.move).kind}));body.querySelectorAll('[data-upgrade]').forEach(b=>b.onclick=()=>act(()=>M.upgrade(s,b.dataset.upgrade)));body.querySelectorAll('[data-sell]').forEach(b=>b.onclick=()=>act(()=>M.sell(s,b.dataset.sell)));body.querySelectorAll('[data-train]').forEach(b=>b.onclick=()=>act(()=>M.train(s,+b.dataset.train)));body.querySelectorAll('[data-role]').forEach(b=>b.onchange=()=>act(()=>{s.workers.find(w=>w.id===+b.dataset.role).role=b.value;M.note(s,'担当の優先順位を変更');}));body.querySelectorAll('[data-mentor]').forEach(b=>b.onclick=()=>act(()=>{const w=s.workers.find(w=>w.id===+b.dataset.mentor);w.mentor=!w.mentor;M.note(s,`${w.name}の指導役を変更`);}));if($('#expand'))$('#expand').onclick=()=>act(()=>M.expand(s));if($('#export'))$('#export').onclick=()=>{const blob=new Blob([JSON.stringify({revision,state:s})],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='machikoba-save.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};if($('#reload'))$('#reload').onclick=()=>location.reload();if($('#import'))$('#import').onchange=async e=>{try{const f=e.target.files[0];if(!f||f.size>200000)throw Error();const data=JSON.parse(await f.text());if(!M.validate(data.state))throw Error();if(!writer){toast('別のタブを閉じて再読み込みしてください');return;}if(!confirm('現在の進行を、選んだセーブに置き換えますか？'))return;s=data.state;restoreSpecialties(s);recentShipment=null;departure=null;saveBlocked=false;revision=JSON.parse(localStorage.getItem(KEY)||'null')?.revision??null;save();update();renderPanel();toast('セーブを読み込みました');}catch{toast('対応する正常なセーブではありません。進行は変更していません');}};}


function runPlan(id){
  const p=M.growthPlan(s,id);if(!p)return;const n=p.next;
  if(n.type==='upgrade')act(()=>M.upgrade(s,n.id));
  else if(n.type==='train')act(()=>M.train(s,n.id));
  else if(n.type==='purchase')place({kind:n.kind});
  else if(n.type==='accept'){if(act(()=>M.accept(s,id))){close();speed=speed||1;update();}}
  else if(n.type==='ship')ship(n.id);
  else if(n.type==='floor'){close();speed=speed||1;update();}
  else open('orders');
}
function canCompareFreight(plan){
  return plan.phase==='ready'||(['prepare','funds'].includes(plan.phase)&&
    (growthFocus==='rush'||s.goalOffer==='rush')&&M.offerStatus(s,'bulk').available);
}
function growthCard(o,focused=false){
  const p=M.growthPlan(s,o.id),chosen=s.goalOffer===o.id,n=p.next;
  const phaseLabel={prepare:'設備・職人を準備',funds:'資金を準備',slots:'受注枠を空ける',ready:'受注できる',producing:'生産中',ship:'出荷待ち'}[p.phase];
  const action=n.label+(n.cost!==undefined?' · '+money(n.cost):n.type==='accept'?' · 材料 '+money(o.cost):n.type==='ship'?' · '+money(M.shipmentQuote(s,p.order).pay):'');
  const budget=p.order?`<p class="goal-progress">${p.order.done} / ${p.order.qty}個 完成${M.shipmentQuote(s,p.order).late?' · 納期超過（報酬15%減）':''}</p><progress value="${p.order.done}" max="${p.order.qty}"></progress>`:`<ul class="offer-requirements">${p.status.requirements.map(r=>`<li class="${r.met?'met':''}">${r.met?'✓':'○'} ${r.label}</li>`).join('')}</ul><dl class="plan-budget"><div><dt>残りの準備費</dt><dd>${money(p.investment)}</dd></div><div><dt>受注時の材料費</dt><dd>${money(o.cost)}</dd></div><div class="budget-total"><dt>合わせて必要</dt><dd>${money(p.required)}</dd></div></dl>${p.preparations.length?`<p class="plan-detail">${p.preparations.map(v=>escape(v.label)+(v.type==='train'?' → 技能3まで':'')+' '+money(v.total)).join(' ／ ')}${p.preparations.some(v=>v.type==='train')?'<br>研修を使う場合の費用。実務で成長すると減ります。':''}</p>`:''}<p class="plan-funds ${p.shortage?'short':''}">${p.shortage?`手元 ${money(s.cash)} · あと ${money(p.shortage)}`:'準備費と材料費を確保できる資金があります'}</p><small class="plan-note">人件費・追加の効率化費は別。受注条件の達成だけでは納期は保証されません。</small>`;
  const showTerms=o.id==='rush'&&canCompareFreight(p);
  const referral=o.id==='rush'&&!p.status.qualified&&repeatOffer(s)?'<button class="wide" data-next="improve">金物店の改善依頼から目指す（'+earnedBriefs(s).length+'/2達成）</button>':'';
  const planButton=`<strong class="plan-next">${phaseLabel}</strong><button class="wide primary" data-plan-action="${o.id}">${escape(action)}</button>`;
  const decision=o.id==='master'&&!p.order&&p.phase!=='slots'?'<button class="wide primary" data-next="precision">シャフト10本の段取りへ</button>':
    showTerms?freightTerms(s,focused)+(p.phase==='ready'?'':planButton+referral):planButton+referral;
  if(focused)return `<section class="freight-focus"><p>取付プレート28個 · 材料費は受注時に支払います。</p>${decision}<details class="growth-details"><summary>成長目標と費用の内訳</summary>${budget}<button data-goal="${o.id}" ${chosen?'disabled':''}>${chosen?'目標に設定中':'この目標を追う'}</button></details></section>`;
  return `<article class="card growth-card ${chosen?'chosen-goal':''}"><div class="plan-heading"><small>${o.growth}</small><button data-goal="${o.id}" ${chosen?'disabled':''}>${chosen?'✓ 目標に設定中':'この目標を追う'}</button></div><h3>${o.label}</h3><small>${o.qty}個 · 品質${o.quality} · 納期${o.due}秒 · 納品${money(o.pay)}</small><ol class="plan-steps" aria-label="目標の進み方"><li class="${p.order||p.phase==='ready'?'done':'current'}">1 準備</li><li class="${p.phase==='producing'?'current':p.phase==='ship'?'done':''}">2 生産</li><li class="${p.phase==='ship'?'current':''}">3 出荷</li></ol><details class="growth-details"><summary>条件と費用の内訳</summary>${budget}</details>${decision}</article>`;
}

function offerCard(o,recommended=false){
  const status=M.offerStatus(s,o.id),missingPanels=[...new Set(status.requirements.filter(r=>!r.met).map(r=>r.panel))];
  const description=o.id==='rush'?'通常の量産注文と同じ28個を、90秒短い納期で。追加投資と動線を整えて挑戦。':o.id==='master'?'技能不足の検品は時間が2.5倍。検品台の改良でも補えます。':'';
  return card(`${recommended?`<span class="offer-recommendation">${o.id==='relief'?'材料費0円で再出発':'最初はこの注文'}</span>`:''}${escape(o.label)}`,`${o.growth?`<div class="offer-path"><span>${o.growth}</span><b>${status.qualified?'条件達成':'準備中'}</b></div>`:''}<small>${escape(o.name)}</small><div class="row"><span class="tag">${o.qty}個</span><span class="tag">品質 ${o.quality}</span><span class="tag">納期 ${o.due}秒</span></div>${description?`<p>${description}</p>`:''}<p>材料 ${money(o.cost)} → 納品 ${money(o.pay)}<br>人件費・設備費を引く前の差額 ${money(o.pay-o.cost)}</p>${status.requirements.length?`<ul class="offer-requirements">${status.requirements.map(r=>`<li class="${r.met?'met':''}">${r.met?'✓':'○'} ${r.label}</li>`).join('')}</ul>`:''}${status.qualified&&status.reason?`<p class="offer-blocked">${status.reason}</p>`:''}<button class="wide primary"  ${o.id==='fine'?'data-next="precision"':'data-order="'+o.id+'"'} ${status.available?'':'disabled'}>${status.available?o.id==='fine'?'担当を決めて受注':recommended?(o.id==='relief'?'材料費0円で受注する':'この12個を受注して始める'):'受注して生産開始':!status.qualified?'受注条件を満たすと開始':'今は受注できません'}</button>${missingPanels.map(panel=>`<button class="wide" data-next="${panel}">${panel==='workers'?'職人を育てる':'設備を整える'} ↗</button>`).join('')}`,recommended?'recommended-offer':'');
}

const signedMoney=v=>(v<0?'−':'+')+'¥'+Math.round(Math.abs(v)).toLocaleString('ja-JP');
const resultMoney=v=>'¥'+v.toLocaleString('ja-JP',{minimumFractionDigits:1,maximumFractionDigits:1});
const duration=v=>v.toFixed(1)+'秒';
function ship(id){
  const order=s.orders.find(o=>o.id===id);
  if(!act(()=>M.dispatch(s,id),false))return;
  recentShipment=s.results[0];speed=0;
  departure={product:order.product,qty:order.qty,start:performance.now()};
  if(tab)close();
  $('#toast').style.display='none';
  update();$('#orderAction').focus({preventScroll:true});
}
function runResultAction(which){
  const guide=deliveryGuide(s),action=guide?.[which];
  if(!action)return;
  if(action.type==='ship')ship(action.id);
  else if(action.type==='skip'){close();startSkip();}
  else if(action.type==='briefRetry')retryBrief(action.id);
  else if(action.type==='growth')open('growth',action.id);
  else if(action.type==='panel')open(action.panel);
}
function resultNext(guide){
  if(!guide)return '';
  const button=(action,which)=>action?`<button class="wide ${which==='primary'?'primary':''}" data-result-action="${which}" ${['ship','skip'].includes(action.type)&&(!writer||saveBlocked)?'disabled':''}>${escape(action.label)}</button>`:'';
  return `<section class="result-next" aria-label="出荷後の次の行動"><small>次の一手</small><h4>${escape(guide.title)}</h4><p>${escape(guide.body)}</p>${button(guide.primary,'primary')}${button(guide.secondary,'secondary')}</section>`;
}
function pairLine(result,includeTotal=true){
  const deadlines=result.primaryLate||result.extraLate?
    (result.primaryLate?'先約超過':'先約納期内')+'・'+(result.extraLate?'小口超過':'小口納期内'):'両方納期内';
  return deadlines+(includeTotal?' · 2件利益 '+roundedCash(result.profit):'')+(result.soloProfit===null?'':' · 先約単独比 '+signedMoney(yenGain(result.profit,result.soloProfit)));
}
function declineLine(r){
  const solo=r.declinedExtra.solo;
  return '小口を見送り · 先約'+(r.late?'超過':'納期内')+' · 受注利益 '+roundedCash(M.resultProfit(r))+(solo?'（見積 '+roundedCash(solo.profit)+'）':'');
}
function stampCaption(entry){
  return entry.orderId===s.specialties?.[0]?.orderId?'最初のエンディング':'もう一つの得意分野';
}
function stampDetail(entry){
  if(entry.offerId==='rush')return '短納期プレート28個を納品'+(entry.margin===null?' · 納期内':' · 納期に'+entry.margin.toFixed(1)+'秒の余裕');
  const worker=s.workers.find(w=>w.id===entry.inspectorId);
  return '高精度シャフト10本を納品 · '+(worker?'検品 '+worker.name:'検品 おまかせ')+(entry.rework===null?'':' · 品質調整'+entry.rework+'本');
}
function stampCard(entry){
  return `<section class="shop-sign"><small>工場の歩み　／　${stampCaption(entry)}</small><h3>${SPECIALTIES[entry.offerId]}</h3><p>${escape(stampDetail(entry))}</p></section>`;
}
function workshopRecord(){
  return (s.specialties||[]).map(stampCard).join('');
}
function receipt(r,expanded){
  const profit=M.resultProfit(r),prev=M.previousResult(s,r),guide=expanded?deliveryGuide(s,r):null;
  let comparison='';
  if(profit!==null){
    comparison=prev?`<div class="result-compare"><strong>同じ注文の前回比</strong><div class="row"><span>生産時間</span><b>${change(r.seconds,prev.seconds,'秒',true)}</b></div><div class="row"><span>移動距離</span><b>${change(r.walk,prev.walk,'マス',true)}</b></div><div class="row"><span>受注利益</span><b>${signedMoney(profit-M.resultProfit(prev))}</b></div><small>納期・同時受注・職人の成長でも結果は変わります。</small></div>`:'<p>同じ注文をもう一度出荷すると、前回と比べられます。</p>';
  }
  const heading=guide?`<div class="receipt-heading"><span class="receipt-check ${guide.tone}" aria-hidden="true">✓</span><div><small>${escape(r.label)} × ${r.qty}</small><h3>${escape(guide.heading)}</h3></div></div><p class="receipt-status ${guide.tone}">${escape(guide.status)}</p>`:`<small>${escape(r.label)} × ${r.qty}${r.late?' · 納期超過':''}</small>`;
  const summary=r.qualitySpend!==undefined?`<div class="result-profit"><span>今回の手残り</span><strong>${signedMoney(profit-r.qualitySpend)}</strong><small>受注利益 ${signedMoney(profit)} − 準備費 ${money(r.qualitySpend)}</small></div>`:
    `<div class="result-profit"><span>今回の受注利益</span><strong>${profit===null?'記録なし':signedMoney(profit)}</strong><small>${r.repeatCost?'今回の改良費 '+money(r.repeatCost)+' を引くと '+signedMoney(profit-r.repeatCost):'設備・研修・増築費を引く前'}</small></div>`;
  const brief=expanded&&prev?`<p class="result-brief">${comparisonLine(s,r)}</p>`:'';
  const quote=r.quote?`<p class="result-brief">受注時の見積 ${seconds(r.quote.seconds)}・利益 ${roundedCash(r.quote.profit)}<br>今回の実績 ${seconds(r.seconds)}・利益 ${roundedCash(profit)}</p>`:'';
  const name=id=>escape(s.workers.find(w=>w.id===id)?.name||'職人');
  const quality=r.qualitySpend===undefined?'':`<p class="result-brief">検品 ${r.inspectorId===undefined?'おまかせ':name(r.inspectorId)} · 品質調整 ${r.rework}/${r.qty}本${r.quote?.rework!==undefined?'（見積 '+r.quote.rework+'本）':''}${r.growth?.length?'<br>実務で成長　'+r.growth.map(g=>name(g.worker)+' 技能'+g.skill).join('・'):''}</p>`;
  const paired=pairResult(r);
  const pairReport=r.declinedExtra?`<p class="result-brief">${declineLine(r)}</p>`:r.pair?`<p class="result-brief">${paired?pairLine(paired):'もう1件を出荷すると2件の実績がそろいます。'}</p>`:'';
  const target=r.briefId?`<p class="result-brief brief-receipt"><strong>改善依頼 · ${BRIEFS[r.briefId].label}</strong><br>${briefOutcomeText(r.briefId,r)}<br>基本報酬 ${money(r.payout-r.briefBonus)} ＋ 改善協力金 ${money(r.briefBonus)} ＝ 入金 ${money(r.payout)}</p>`:'';
  const ledger=`<dl class="result-ledger"><div><dt>入金${r.late?(r.briefId?'（基本報酬15%減）':'（15%減額）'):''}</dt><dd>${resultMoney(r.payout)}</dd></div><div><dt>材料費</dt><dd>−${resultMoney(r.material)}</dd></div><div><dt>人件費</dt><dd>${r.wages===null?'記録なし':'−'+resultMoney(r.wages)}</dd></div></dl>`;
  const measured=profit===null?'<p>更新前に受けた注文のため、時間・人件費は未計測です。次の受注から記録します。</p>':`<div class="result-stats"><div><small>生産時間</small><b>${duration(r.seconds)}</b></div><div><small>移動距離</small><b>${Math.round(r.walk)}マス</b></div><div><small>品質調整</small><b>${r.rework}回</b></div></div>${comparison}<p class="accounting-note">人件費は未完成の注文で均等配分。生産時間は受注から完成まで（出荷待ちを除く）。金額は表示時に丸めています。</p>`;
  const stamp=s.specialties?.find(e=>e.orderId===r.orderId);
  return `<article class="card receipt">${stamp?stampCard(stamp):''}${heading}${summary}${target}${brief}${quote}${quality}${pairReport}${resultNext(guide)}${expanded?`<details class="receipt-details"><summary>収支の内訳・前回との比較</summary>${ledger}${measured}</details>`:ledger+measured}</article>`;
}
function change(now,before,unit,lowerBetter){const diff=now-before;if(Math.abs(diff)<.05)return '変化なし';return `${Math.abs(diff).toFixed(1)}${unit}${diff<0?(lowerBetter?'短縮':'減'):(lowerBetter?'増加':'増')}`;}
function escape(t){return String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function place(p){
  stopSkip();
  if(!writer||saveBlocked){toast('進行を保存できる画面で配置してください');return;}
  if(!p.id&&s.cash<M.MACHINES[p.kind].cost){toast('資金が足りません。材料費も残して投資しましょう');return;}
  $('#controls').open=false;close();selected=p.id||null;resumeSpeed=speed;placing={...p,candidate:null,draining:s.workers.some(w=>w.job)};
  speed=placing.draining?3:0;showPlacement();update();
  canvas.tabIndex=0;canvas.setAttribute('aria-describedby','placeStatus');canvas.focus({preventScroll:true});
}
function showPlacement(){
  placementCells=[];
  if(!placing.draining && placing.id && !M.frontOrder(s)){
    const offer=placing.estimateOffer||(placing.kind==='lathe'?'fine':'first');
    $('#placementBar').dataset.estimating='true';
    placing.editor=layoutEditor(s,placing,offer,()=>writer&&!saveBlocked,cells=>{placementCells=cells;});
    return;
  }
  if(!placing.draining){
    const original=s.machines.find(m=>m.id===placing.id);
    for(let x=1;x<s.width;x++)for(let y=0;y<s.height-1;y++){
      if(original?.x===x&&original.y===y)continue;
      if(M.canPlace(s,placing.kind,x,y,placing.id))placementCells.push({x,y});
    }
  }
  placementTicket();
}
function placementTicket(message){
  const p=placing,c=p.candidate,m=M.MACHINES[p.kind],button=$('#confirmPlace');
  $('#placeTitle').textContent=m.name+(p.id?'の移動':'の設置');
  $('#placeStatus').textContent=message||(p.draining?'職人が今の工程を終えると、床を選べます。':
    c?'仮置き中 · '+(c.x+1)+'列 '+(c.y+1)+'段。ほかの床を押して変更できます。':
    placementCells.length?'光る床をタップして仮置き。二本指で拡大できます。':'置ける床がありません。ほかの設備や通路を確認してください。');
  button.disabled=!c||!writer||saveBlocked;
  if(p.precisionLathe){
    $('#placeTitle').textContent='最初の旋盤を試す';
    button.textContent='旋盤を設置 · '+money(m.cost);
  }else button.textContent=p.id?'ここに移動':'ここに設置 · '+money(m.cost);
  placementEstimate(p,c);
}
function placementEstimate(p,cell){
  const el=$('#layoutEstimate');
  const estimating=!!p.precisionLathe;
  $('#placementBar').dataset.estimating=String(estimating);
  el.hidden=!estimating;
  el.classList.toggle('empty-estimate',!cell);
  if(!estimating||!cell){el.textContent='';estimator.cancel();return;}
  el.textContent='標準10本を見積中…';
  estimator.request(s,[{lathe:cell,precision:{offer:'fine'}}],rows=>{
    const q=rows?.[0];
    el.textContent=q&&!q.error?'設置後の標準10本　'+seconds(q.seconds)+' · 品質調整 '+q.rework+'本':q?.error||'見積を表示できません';
  });
}
function endPlacement(){
  placing?.editor?.close();estimator.cancel();$('#layoutEstimate').hidden=true;
  placing=null;placementCells=[];speed=resumeSpeed;
  canvas.removeAttribute('tabindex');canvas.removeAttribute('aria-describedby');
  update();if(selected)selectMachine(selected,true);
  const next=selected?$('#quickMove'):$('#orderAction');
  if(!tab)next.focus({preventScroll:true});
}
function cancelPlacement(){
  const trial=placing?.trial,freight=placing?.estimateOffer,shaft=placing?.precisionLathe;
  if(trial||freight||shaft)selected=null;
  endPlacement();
  if(trial)open('improve');
  else if(freight)open('growth','rush',false,freight);
  else if(shaft)open('precision');
}
$('#cancelPlace').onclick=cancelPlacement;
$('#confirmPlace').onclick=()=>{
  const p=placing,c=p?.candidate;
  if(!c||p.draining)return;
  if(p.editor){
    if(!p.editor.canConfirm())return;
    const ok=act(()=>p.trial?startRepeat(s,'layout',p.editor.moves,p.briefId??null):applyLayout(s,p.editor.moves),false);
    if(ok){
      if(p.trial)resumeSpeed=resumeSpeed||1;
      selected=null;endPlacement();
      if(p.estimateOffer)open('growth','rush',false,p.estimateOffer);
    }
    return;
  }
  const ok=p.precisionLathe?act(()=>installStarterLathe(s,c),false):
    act(()=>p.id?M.move(s,p.id,c.x,c.y):M.purchase(s,p.kind,c.x,c.y));
  if(ok){
    selected=p.precisionLathe?null:p.id||s.machines.find(m=>m.x===c.x&&m.y===c.y)?.id||null;
    endPlacement();
    if(p.precisionLathe){shaftChoice.offer='fine';open('precision');}
  }else if(placing){p.candidate=null;showPlacement();}
};
canvas.addEventListener('keydown',event=>{
  if(!placing)return;
  if(event.key==='Escape'){event.preventDefault();cancelPlacement();return;}
  if(placing.draining||!placementCells.length)return;
  if(event.key==='Enter'){event.preventDefault();if(!$('#confirmPlace').disabled)$('#confirmPlace').focus();return;}
  if(!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key))return;
  event.preventDefault();
  const index=placementCells.findIndex(c=>c.x===placing.candidate?.x&&c.y===placing.candidate?.y),n=placementCells.length;
  const delta=['ArrowLeft','ArrowUp'].includes(event.key)?-1:1;
  const cell=placementCells[index===-1?(delta>0?0:n-1):(index+delta+n)%n];
  if(placing.editor)placing.editor.choose(cell);
  else{placing.candidate=cell;placementTicket();}
  draw();
});

let viewport={w:0,h:0,u:0,ox:0,oy:0},hitTargets=[];
function point(x,y,z=0){return project(viewport,x,y,z);}
function draw(t=performance.now()){
  const rect=canvas.getBoundingClientRect();
  if(rect.width<1||rect.height<1)return;
  const dpr=Math.min(devicePixelRatio||1,2),W=rect.width,H=rect.height;
  if(canvas.width!==Math.round(W*dpr)||canvas.height!==Math.round(H*dpr)){
    canvas.width=Math.round(W*dpr);canvas.height=Math.round(H*dpr);
  }
  ctx.setTransform(dpr,0,0,dpr,0,0);
  viewport=frameWorkshop(W,H,s.width,zoom,pan);
  const running=writer&&!saveBlocked&&!document.hidden&&!tab&&(speed>0||!!skipping)&&(!placing||placing.draining);
  const art=workshopArt(s.width);
  const artMode=art.machines&&art.crew&&art.truck&&art.room&&art.shipping&&art.station?'ready':'partial';
  if(canvas.dataset.artwork!==artMode)canvas.dataset.artwork=artMode;
  const elapsed=departure?Math.max(0,t-departure.start):0;
  if(elapsed>=departureDuration)departure=null;
  const floor=placing?.planMachines?{...s,machines:placing.planMachines}:s;
  hitTargets=drawWorkshop(ctx,floor,viewport,{art,shipment:departure,shipmentElapsed:elapsed,time:s.clock*1000,running,reducedMotion:reducedMotion.matches,selected,placing,placementCells,showLabels});
}
function applyCamera(from,to,ratio){
  const camera=changeCamera({zoom,pan},from,to,ratio,canvas.clientWidth,canvas.clientHeight);
  zoom=camera.zoom;pan=camera.pan;
}
function tapFloor(p){
  if(tab)return;
  // A pinch/pan and the next tap can occur between animation frames.
  draw();
  if(!placing){selectMachine(pickMachine(p,hitTargets));return;}
  if(placing.draining)return;
  const {u,ox,oy}=viewport;
  if(!u)return;
  const a=(p.x-ox)/u,b=(p.y-oy)/(u*.5);
  const x=Math.floor((a+b)/2),y=Math.floor((b-a)/2);
  if(placing.editor){placing.editor.choose({x,y});draw();return;}
  placing.candidate=placementCells.find(c=>c.x===x&&c.y===y)||null;
  placementTicket(placing.candidate?null:(M.placementIssue(s,placing.kind,x,y,placing.id)||'現在と違う床を選んでください'));
  draw();
}
const gesture=floorGesture(applyCamera,tapFloor);
const localPoint=e=>{
  const r=canvas.getBoundingClientRect();return {x:e.clientX-r.left,y:e.clientY-r.top};
};
canvas.onpointerdown=e=>{
  if(e.button!==0||tab)return;
  $('#controls').open=false;
  canvas.setPointerCapture(e.pointerId);gesture.down(e.pointerId,localPoint(e));
};
canvas.onpointermove=e=>gesture.move(e.pointerId,localPoint(e));
canvas.onpointerup=e=>gesture.up(e.pointerId,localPoint(e));
canvas.onpointercancel=canvas.onlostpointercapture=e=>gesture.cancel(e.pointerId);
document.addEventListener('visibilitychange',()=>{if(document.hidden)gesture.reset();});
window.addEventListener('blur',()=>gesture.reset());
function startSkip(review=null){
  if(placing||tab||!writer||saveBlocked)return;
  const o=M.frontOrder(s);if(!o||o.done===o.qty)return;
  skipping={ticks:0,clock:s.clock,cash:s.cash,review};speed=0;tickRemainder=0;last=0;update();
}
function stopSkip(message='早送りを停止しました',announce=true){
  if(!skipping)return;
  skipping=null;speed=0;tickRemainder=0;last=0;M.note(s,message);save();if(announce)toast(message);update();
}
function frame(t){
  const playable=writer&&!saveBlocked&&!document.hidden&&!tab;
  if(skipping){
    if(!playable||placing)stopSkip();
    else{
      const review=skipping.review;
      const result=review?advanceToReview(s,review.id,review.target,100):M.advanceToReady(s,100);
      skipping.ticks+=result.ticks;
      if(result.status==='review'){
        stopSkip('先約の半分が完成。小口はまだ引き受けていません',false);open('inquiry');
      }
      else if(result.status==='ready')stopSkip(`生産完了 · 工場時間 +${Math.round(s.clock-skipping.clock)}秒 / 人件費 ${money(skipping.cash-s.cash)}。出荷できます`,false);
      else if(result.status==='idle')stopSkip('進める注文がありません');
      else if(skipping.ticks>=24000)stopSkip('いったん停止しました。設備と工程待ちを確認してください');
    }
  }else if(last&&playable&&(!placing||placing.draining)&&speed){
    tickRemainder+=Math.min((t-last)/1000,.25)*speed;
    while(tickRemainder>=M.TICK){
      M.step(s,M.TICK,{assignNew:!placing});tickRemainder-=M.TICK;
      if(placing?.draining&&!s.workers.some(w=>w.job)){placing.draining=false;speed=0;tickRemainder=0;save();showPlacement();break;}
    }
  }else tickRemainder=0;
  last=t;if(!document.hidden&&t-lastDraw>=1000/30){draw(t);lastDraw=t;}if(t-paintTime>250){update();paintTime=t;}if(t>toastUntil)$('#toast').style.display='none';requestAnimationFrame(frame);
}
document.addEventListener('visibilitychange',()=>{
  if(document.hidden){estimator.cancel();placing?.editor?.suspend();}
  else if(placing?.editor)placing.editor.resume();
  else if(placing)placementTicket();
  else if(tab)setupPanelEstimate();
});
window.addEventListener('pagehide',()=>estimator.cancel());
update();requestAnimationFrame(frame);

