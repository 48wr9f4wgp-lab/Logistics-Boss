import * as M from './model.mjs';
import {openingOffer,deliveryGuide,floorTicket} from './guidance.mjs?v=0.12';
import {project,pickMachine} from './view.mjs?v=0.13';
import {drawWorkshop} from './workshop.mjs?v=0.14';
const $=s=>document.querySelector(s),KEY='forge.factory.v1',canvas=$('#world'),ctx=canvas.getContext('2d');
let s=M.fresh(),speed=1,last=0,zoom=1,pan={x:0,y:0},placing=null,selected=null,tab=null,toastUntil=0,revision=null,writer=false,saveBlocked=false,paintTime=0,placementCells=[],resumeSpeed=1,skipping=null,tickRemainder=0,showLabels=false,lastDraw=-Infinity;
let growthFocus=null, recentShipment=null;
const reducedMotion=window.matchMedia('(prefers-reduced-motion: reduce)');
try{const raw=localStorage.getItem(KEY);if(raw){const env=JSON.parse(raw);if(!M.validate(env.state))throw Error('invalid');s=env.state;revision=env.revision;}}catch{saveBlocked=true;speed=0;}
// A completed saved order remains safe to dispatch after reopening the page.
if(s.orders.some(o=>!o.shipped&&o.done===o.qty))speed=0;
function toast(t){if(tab){$('#sheetNotice').textContent=t;$('#sheetNotice').hidden=false;}$('#toast').textContent=t;$('#toast').style.display='block';toastUntil=performance.now()+4200;}
function save(){if(!writer||saveBlocked)return;try{const previous=localStorage.getItem(KEY);if(previous&&JSON.parse(previous).revision!==revision){writer=false;speed=0;toast('別の画面で保存されました。再読み込みしてください');return;}revision=crypto.randomUUID?.()||String(Date.now()+Math.random());localStorage.setItem(KEY,JSON.stringify({revision,state:s}));}catch{saveBlocked=true;toast('保存できません。設定から進行を書き出せます');}}
if(navigator.locks){navigator.locks.request(KEY,{ifAvailable:true},async lock=>{if(!lock){toast('別のタブで起動中です。この画面は閲覧専用');return;}writer=true;update();if(saveBlocked)toast('保存データを読み込めません。上書きせず停止しました');await new Promise(resolve=>window.addEventListener('pagehide',()=>{save();resolve();},{once:true}));});}else{writer=true;}
window.addEventListener('storage',e=>{if(e.key===KEY){writer=false;speed=0;toast('別画面の更新を検出。再読み込みしてください');}});
window.addEventListener('pageshow',e=>{if(e.persisted){writer=false;speed=0;toast('復帰しました。続けるには再読み込みしてください');}});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopSkip();save();last=0;tickRemainder=0;});window.addEventListener('pagehide',save);setInterval(save,5000);
function act(fn,announce=true){if(!writer||saveBlocked){toast(saveBlocked?'保存に問題があります。設定を開いてください':'別画面で起動中です。再読み込みしてください');return;}stopSkip();const before=new Set(M.OFFERS.filter(o=>o.growth&&M.offerStatus(s,o.id).qualified).map(o=>o.id));const error=fn();if(error)toast(error);else{const unlocked=M.OFFERS.filter(o=>o.growth&&!before.has(o.id)&&M.offerStatus(s,o.id).qualified);if(unlocked.length)M.note(s,`受注条件を達成：${unlocked.map(o=>o.label).join('・')}`);recentShipment=null;save();if(announce)toast(s.log[0]);}update();if(tab)renderPanel();return !error;}
const money=v=>'¥'+Math.floor(v).toLocaleString('ja-JP');
function update(){
  const ticket=floorTicket(s,{skipping:!!skipping,paused:speed===0,shipment:recentShipment});
  const button=$('#orderAction');
  $('.order-strip').hidden=!!placing;
  $('#controls').hidden=!!placing;
  $('#cash').textContent=money(s.cash);
  $('#ticketLabel').textContent=ticket.label;
  if(recentShipment){
    const profit=M.resultProfit(recentShipment);
    $('#ticketLabel').textContent='出荷完了 · '+(profit===null?'入金 '+money(recentShipment.payout):'今回の利益 '+signedMoney(profit));
  }
  $('#orderTitle').textContent=ticket.title;
  $('#orderHint').textContent=ticket.hint;
  $('#orderHint').hidden=!ticket.hint;
  button.textContent=ticket.action.label;
  button.disabled=!!placing||!writer||saveBlocked;
  button.onclick=()=>runFloorAction(ticket.action);
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
function runFloorAction(action){
  if(placing||!writer||saveBlocked)return;
  if(action.type==='accept'){
    if(!M.frontOrder(s)&&act(()=>M.accept(s,action.id),false)){speed=speed||1;update();}
  }else if(action.type==='stop')stopSkip();
  else if(action.type==='skip')startSkip();
  else if(action.type==='ship')ship(action.id);
  else if(action.type==='growth')open('growth',action.id);
  else if(action.type==='panel')open(action.panel);
}
function open(panel,focusId=null){
  growthFocus=panel==='growth'?focusId:null;
  stopSkip();if(placing)endPlacement();
  $('#controls').open=false;
  tab=panel;$('#sheet').dataset.panel=panel;$('#sheetNotice').hidden=true;
  renderPanel();if(!$('#sheet').open)$('#sheet').showModal();
  $('#sheet').scrollTop=0;updateSelection();
}
function close(){tab=null;$('#sheet').close();updateSelection();}
$('#close').onclick=close;
$('#sheet').addEventListener('cancel',()=>{tab=null;updateSelection();});
$('#menu').onclick=()=>open('manage');
$('#controls').addEventListener('toggle',()=>{if($('#controls').open){selected=null;updateSelection();}});
document.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>{
  stopSkip();speed=+b.dataset.speed;
  if(speed===0)draw();
  update();
});
$('#plus').onclick=()=>zoom=Math.min(2,zoom+.15);
$('#minus').onclick=()=>{zoom=Math.max(.7,zoom-.15);if(zoom<=1)pan={x:0,y:0};};
$('#labels').onclick=()=>{showLabels=!showLabels;$('#labels').setAttribute('aria-pressed',String(showLabels));$('#labels').setAttribute('aria-label',showLabels?'設備名を隠す':'設備名を表示');};
$('#viewReset').onclick=()=>{zoom=1;pan={x:0,y:0};selected=null;updateSelection();};
const stageNames={cut:'切断',drill:'穴あけ',lathe:'旋盤',inspect:'検品'};
function selectMachine(id,focus=false){
  selected=id;
  if(id)$('#controls').open=false;
  const m=s.machines.find(m=>m.id===id);
  updateSelection();
  if(m&&focus)requestAnimationFrame(()=>{
    if(selected!==id||!viewport.u)return;
    const cardHeight=$('#machineQuick').getBoundingClientRect().height;
    const p=point(m.x+.5,m.y+.5,.5),targetY=Math.max(55,Math.min(viewport.h*.32,viewport.h-64-cardHeight-40));
    pan.x+=viewport.w*.5-p.x;pan.y+=targetY-p.y;
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
  $('#machineWorker').textContent=w?`${w.name} · ${w.job.phase==='walk'?'運搬中（光る線が経路）':w.job.rework?'品質調整中':'加工中'}`:'担当者・材料待ち';
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
function renderPanel(){const body=$('#sheetBody');$('#sheetTitle').textContent=({manage:'工場の管理',orders:'受注と出荷',growth:'成長案件',machines:'設備と配置',workers:'職人を育てる',finance:'経営と拡張',save:'保存と設定',result:'出荷結果'})[tab];let html='';
if(tab==='manage'){
  const links=[['orders','注文一覧'],['growth','成長目標'],['machines','設備と配置'],['workers','職人と研修'],['finance','経営と出荷記録'],['save','保存と設定']];
  html='<div class="manage-links">'+links.map(([panel,label])=>'<button data-next="'+panel+'">'+label+' <span aria-hidden="true">›</span></button>').join('')+'</div>';
}
if(tab==='orders'){
  for(const o of s.orders.filter(o=>!o.shipped)){
    const remain=Math.ceil(o.start+o.due-s.clock),quote=M.shipmentQuote(s,o);
    html+=card(escape(o.label),`<small>生産中 · ${o.qty}個 / 品質 ${o.quality}</small><p>${o.done}個完成 · ${!quote.late?'納期まで '+remain+'秒':'納期超過：報酬15%減額'}</p><progress value="${o.done}" max="${o.qty}"></progress><button class="primary wide" data-ship="${o.id}" ${o.done<o.qty?'disabled':''}>出荷して ${money(quote.pay)} を受け取る</button>`);
  }
  const recommended=openingOffer(s);
  html+=recommended?'<p>まずは一件、受注 → 完成まで進める → 出荷。詳細画面を開いている間は時間が止まります。</p>':'<p>同時受注は2件。受注時に材料を購入します。詳細画面を開いている間は時間が止まります。</p>';
  if(recommended)html+=offerCard(recommended,true);
  html+='<button class="wide growth-entry" data-next="growth">成長案件 · 投資で次の仕事へ ↗</button>';
  if(recommended)html+='<h3 class="other-offers">ほかの注文</h3>';
  for(const o of M.OFFERS.filter(o=>!o.growth&&o.id!==recommended?.id))html+=offerCard(o);
}
if(tab==='growth'){html='<p>目標を選ぶと工場画面で追えます。量産・精密はいつでも切替でき、両方を伸ばせます。</p>'+M.OFFERS.filter(o=>o.growth).sort((a,b)=>Number(b.id===(growthFocus||s.goalOffer))-Number(a.id===(growthFocus||s.goalOffer))).map(growthCard).join('')+'<button class="wide" data-next="orders">通常の注文を見る</button>';}
if(tab==='machines'){
  html='<p>改良の効果は次の作業割当から。表示は加工だけの時間で、注文全体は配置や職人の担当でも変わります。移動では今の工程を仕上げて停止し、配置後に再開します。</p>';
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
if(tab==='finance'){html=card('工場の状況','<div class="row"><span>出荷実績</span><b>'+s.delivered+'件</b></div><div class="row"><span>工場時間</span><b>'+Math.floor(s.clock/60)+'分'+Math.floor(s.clock%60)+'秒</b></div>')+card('収支',`<div class="row"><span>累計売上</span><b>${money(s.revenue)}</b></div><div class="row"><span>材料・投資・人件費</span><b>${money(s.expense)}</b></div><p>加工する部品がある間、人件費は毎秒¥0.7。画面を閉じている間の生産・請求はありません。</p>`)+'<h3>出荷の振り返り</h3><p>直近12件を保存。利益は設備・研修・増築費を引く前の金額です。</p>'+(s.results?.length?'<button class="wide" data-next="result">直近の出荷結果を開く</button>'+s.results.map(r=>`<details class="result-history"><summary>${escape(r.label)} × ${r.qty}<b>${M.resultProfit(r)===null?'記録なし':signedMoney(M.resultProfit(r))}</b></summary>${receipt(r,false)}</details>`).join(''):'<p>出荷すると結果をここで見返せます。</p>')+card('工場を広げる',`<p>床面積を8×6から10×8へ。追加設備と動線のための余白を作ります。</p><button class="primary wide" id="expand" ${s.width===10?'disabled':''}>${s.width===10?'拡張済み':'増築する · ¥3,500'}</button>`)+card('生産の記録',`<p>完了工程 ${s.stats.processed}回<br>品質調整 ${s.stats.rework}回<br>運搬・移動距離 ${Math.floor(s.stats.walk)}マス</p>`)+card('工場日誌',s.log.map(t=>`<p>${escape(t)}</p>`).join(''));}
if(tab==='save'){html=card('進行は自動保存',`<p>${saveBlocked?'保存エラー：元データは上書きしていません。書き出して保管できます。':writer?'このブラウザに5秒ごとに保存しています。':'別のタブで起動中、または復帰後の閲覧状態です。再読み込みしてください。'}<br>旧フロトラの保存データとは独立しています。</p><button id="export" class="wide">セーブを書き出す</button><label><p>書き出したセーブを読み込む（現在の進行と置き換え）</p><input id="import" type="file" accept="application/json,.json"></label><button id="reload" class="wide">再読み込み</button>`)+card('遊び方','<p>① 受注で材料を購入<br>② 完成まで進めるで待ち時間をスキップ（人件費・納期も進む）<br>③ 完成した注文を出荷して入金<br>④ 設備の追加・改良、研修に再投資<br><br>工場はドラッグで移動。「操作」で速度、拡大縮小、全景表示、設備名を切り替えます。機械や工程待ちをタップすると、担当者・運搬経路を確認して移動・改良できます。同じ工程をもう一度押すと次の同種設備を選びます。配置モードでは床をタップしてください。</p><small>開発版 v0.14</small>');}
body.innerHTML=html;body.querySelectorAll('[data-result-action]').forEach(b=>b.onclick=()=>runResultAction(b.dataset.resultAction));body.querySelectorAll('[data-goal]').forEach(b=>b.onclick=()=>{if(act(()=>M.setGoal(s,b.dataset.goal))){growthFocus=null;renderPanel();$('#sheet').scrollTop=0;}});body.querySelectorAll('[data-plan-action]').forEach(b=>b.onclick=()=>runPlan(b.dataset.planAction));body.querySelectorAll('[data-next]').forEach(b=>b.onclick=()=>open(b.dataset.next));body.querySelectorAll('[data-order]').forEach(b=>b.onclick=()=>{if(act(()=>M.accept(s,b.dataset.order))){close();speed=speed||1;update();}});body.querySelectorAll('[data-ship]').forEach(b=>b.onclick=()=>ship(+b.dataset.ship));body.querySelectorAll('[data-buy]').forEach(b=>b.onclick=()=>place({kind:b.dataset.buy}));body.querySelectorAll('[data-move]').forEach(b=>b.onclick=()=>place({id:b.dataset.move,kind:s.machines.find(m=>m.id===b.dataset.move).kind}));body.querySelectorAll('[data-upgrade]').forEach(b=>b.onclick=()=>act(()=>M.upgrade(s,b.dataset.upgrade)));body.querySelectorAll('[data-sell]').forEach(b=>b.onclick=()=>act(()=>M.sell(s,b.dataset.sell)));body.querySelectorAll('[data-train]').forEach(b=>b.onclick=()=>act(()=>M.train(s,+b.dataset.train)));body.querySelectorAll('[data-role]').forEach(b=>b.onchange=()=>act(()=>{s.workers.find(w=>w.id===+b.dataset.role).role=b.value;M.note(s,'担当の優先順位を変更');}));body.querySelectorAll('[data-mentor]').forEach(b=>b.onclick=()=>act(()=>{const w=s.workers.find(w=>w.id===+b.dataset.mentor);w.mentor=!w.mentor;M.note(s,`${w.name}の指導役を変更`);}));if($('#expand'))$('#expand').onclick=()=>act(()=>M.expand(s));if($('#export'))$('#export').onclick=()=>{const blob=new Blob([JSON.stringify({revision,state:s})],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='machikoba-save.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};if($('#reload'))$('#reload').onclick=()=>location.reload();if($('#import'))$('#import').onchange=async e=>{try{const f=e.target.files[0];if(!f||f.size>200000)throw Error();const data=JSON.parse(await f.text());if(!M.validate(data.state))throw Error();if(!writer){toast('別のタブを閉じて再読み込みしてください');return;}if(!confirm('現在の進行を、選んだセーブに置き換えますか？'))return;s=data.state;recentShipment=null;saveBlocked=false;revision=JSON.parse(localStorage.getItem(KEY)||'null')?.revision??null;save();update();renderPanel();toast('セーブを読み込みました');}catch{toast('対応する正常なセーブではありません。進行は変更していません');}};}


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
function growthCard(o){
  const p=M.growthPlan(s,o.id),chosen=s.goalOffer===o.id,n=p.next;
  const phaseLabel={prepare:'設備・職人を準備',funds:'資金を準備',slots:'受注枠を空ける',ready:'受注できる',producing:'生産中',ship:'出荷待ち'}[p.phase];
  const action=n.label+(n.cost!==undefined?' · '+money(n.cost):n.type==='accept'?' · 材料 '+money(o.cost):n.type==='ship'?' · '+money(M.shipmentQuote(s,p.order).pay):'');
  const budget=p.order?`<p class="goal-progress">${p.order.done} / ${p.order.qty}個 完成${M.shipmentQuote(s,p.order).late?' · 納期超過（報酬15%減）':''}</p><progress value="${p.order.done}" max="${p.order.qty}"></progress>`:`<ul class="offer-requirements">${p.status.requirements.map(r=>`<li class="${r.met?'met':''}">${r.met?'✓':'○'} ${r.label}</li>`).join('')}</ul><dl class="plan-budget"><div><dt>残りの準備費</dt><dd>${money(p.investment)}</dd></div><div><dt>受注時の材料費</dt><dd>${money(o.cost)}</dd></div><div class="budget-total"><dt>合わせて必要</dt><dd>${money(p.required)}</dd></div></dl>${p.preparations.length?`<p class="plan-detail">${p.preparations.map(v=>escape(v.label)+(v.type==='train'?' → 技能3まで':'')+' '+money(v.total)).join(' ／ ')}${p.preparations.some(v=>v.type==='train')?'<br>研修を使う場合の費用。実務で成長すると減ります。':''}</p>`:''}<p class="plan-funds ${p.shortage?'short':''}">${p.shortage?`手元 ${money(s.cash)} · あと ${money(p.shortage)}`:'準備費と材料費を確保できる資金があります'}</p><small class="plan-note">人件費・追加の効率化費は別。受注条件の達成だけでは納期は保証されません。</small>`;
  return `<article class="card growth-card ${chosen?'chosen-goal':''}"><div class="plan-heading"><small>${o.growth}</small><button data-goal="${o.id}" ${chosen?'disabled':''}>${chosen?'✓ 目標に設定中':'この目標を追う'}</button></div><h3>${o.label}</h3><small>${o.qty}個 · 品質${o.quality} · 納期${o.due}秒 · 納品${money(o.pay)}</small><ol class="plan-steps" aria-label="目標の進み方"><li class="${p.order||p.phase==='ready'?'done':'current'}">1 準備</li><li class="${p.phase==='producing'?'current':p.phase==='ship'?'done':''}">2 生産</li><li class="${p.phase==='ship'?'current':''}">3 出荷</li></ol><details class="growth-details"><summary>条件と費用の内訳</summary>${budget}</details><strong class="plan-next">${phaseLabel}</strong><button class="wide primary" data-plan-action="${o.id}">${escape(action)}</button></article>`;
}

function offerCard(o,recommended=false){
  const status=M.offerStatus(s,o.id),missingPanels=[...new Set(status.requirements.filter(r=>!r.met).map(r=>r.panel))];
  const description=o.id==='rush'?'通常の量産注文と同じ28個を、90秒短い納期で。追加投資と動線を整えて挑戦。':o.id==='master'?'技能不足の検品は時間が2.5倍。検品台の改良でも補えます。':'';
  return card(`${recommended?`<span class="offer-recommendation">${o.id==='relief'?'材料費0円で再出発':'最初はこの注文'}</span>`:''}${escape(o.label)}`,`${o.growth?`<div class="offer-path"><span>${o.growth}</span><b>${status.qualified?'条件達成':'準備中'}</b></div>`:''}<small>${escape(o.name)}</small><div class="row"><span class="tag">${o.qty}個</span><span class="tag">品質 ${o.quality}</span><span class="tag">納期 ${o.due}秒</span></div>${description?`<p>${description}</p>`:''}<p>材料 ${money(o.cost)} → 納品 ${money(o.pay)}<br>人件費・設備費を引く前の差額 ${money(o.pay-o.cost)}</p>${status.requirements.length?`<ul class="offer-requirements">${status.requirements.map(r=>`<li class="${r.met?'met':''}">${r.met?'✓':'○'} ${r.label}</li>`).join('')}</ul>`:''}${status.qualified&&status.reason?`<p class="offer-blocked">${status.reason}</p>`:''}<button class="wide primary" data-order="${o.id}" ${status.available?'':'disabled'}>${status.available?recommended?(o.id==='relief'?'材料費0円で受注する':'この12個を受注して始める'):'受注して生産開始':!status.qualified?'受注条件を満たすと開始':'今は受注できません'}</button>${missingPanels.map(panel=>`<button class="wide" data-next="${panel}">${panel==='workers'?'職人を育てる':'設備を整える'} ↗</button>`).join('')}`,recommended?'recommended-offer':'');
}

const signedMoney=v=>(v<0?'−':'+')+'¥'+Math.round(Math.abs(v)).toLocaleString('ja-JP');
const resultMoney=v=>'¥'+v.toLocaleString('ja-JP',{minimumFractionDigits:1,maximumFractionDigits:1});
const duration=v=>v.toFixed(1)+'秒';
function ship(id){
  if(!act(()=>M.dispatch(s,id),false))return;
  recentShipment=s.results[0];speed=0;
  if(tab)close();
  $('#toast').style.display='none';
  update();$('#orderAction').focus({preventScroll:true});
}
function runResultAction(which){
  const guide=deliveryGuide(s),action=guide?.[which];
  if(!action)return;
  if(action.type==='ship')ship(action.id);
  else if(action.type==='skip'){close();startSkip();}
  else if(action.type==='growth')open('growth',action.id);
  else if(action.type==='panel')open(action.panel);
}
function resultNext(guide){
  if(!guide)return '';
  const button=(action,which)=>action?`<button class="wide ${which==='primary'?'primary':''}" data-result-action="${which}" ${['ship','skip'].includes(action.type)&&(!writer||saveBlocked)?'disabled':''}>${escape(action.label)}</button>`:'';
  return `<section class="result-next" aria-label="出荷後の次の行動"><small>次の一手</small><h4>${escape(guide.title)}</h4><p>${escape(guide.body)}</p>${button(guide.primary,'primary')}${button(guide.secondary,'secondary')}</section>`;
}
function receipt(r,expanded){
  const profit=M.resultProfit(r),prev=M.previousResult(s,r),guide=expanded?deliveryGuide(s,r):null;
  let comparison='';
  if(profit!==null){
    comparison=prev?`<div class="result-compare"><strong>同じ注文の前回比</strong><div class="row"><span>生産時間</span><b>${change(r.seconds,prev.seconds,'秒',true)}</b></div><div class="row"><span>移動距離</span><b>${change(r.walk,prev.walk,'マス',true)}</b></div><div class="row"><span>受注利益</span><b>${signedMoney(profit-M.resultProfit(prev))}</b></div><small>納期・同時受注・職人の成長でも結果は変わります。</small></div>`:'<p>同じ注文をもう一度出荷すると、前回と比べられます。</p>';
  }
  const heading=guide?`<div class="receipt-heading"><span class="receipt-check ${guide.tone}" aria-hidden="true">✓</span><div><small>${escape(r.label)} × ${r.qty}</small><h3>${escape(guide.heading)}</h3></div></div><p class="receipt-status ${guide.tone}">${escape(guide.status)}</p>`:`<small>${escape(r.label)} × ${r.qty}${r.late?' · 納期超過':''}</small>`;
  const summary=`<div class="result-profit"><span>今回の受注利益</span><strong>${profit===null?'記録なし':signedMoney(profit)}</strong><small>設備・研修・増築費を引く前</small></div>`;
  const brief=expanded&&prev?`<p class="result-brief">同じ注文の前回比：生産 ${change(r.seconds,prev.seconds,'秒',true)} · 利益 ${signedMoney(profit-M.resultProfit(prev))}</p>`:'';
  const ledger=`<dl class="result-ledger"><div><dt>入金${r.late?'（15%減額）':''}</dt><dd>${resultMoney(r.payout)}</dd></div><div><dt>材料費</dt><dd>−${resultMoney(r.material)}</dd></div><div><dt>人件費</dt><dd>${r.wages===null?'記録なし':'−'+resultMoney(r.wages)}</dd></div></dl>`;
  const measured=profit===null?'<p>更新前に受けた注文のため、時間・人件費は未計測です。次の受注から記録します。</p>':`<div class="result-stats"><div><small>生産時間</small><b>${duration(r.seconds)}</b></div><div><small>移動距離</small><b>${Math.round(r.walk)}マス</b></div><div><small>品質調整</small><b>${r.rework}回</b></div></div>${comparison}<p class="accounting-note">人件費は未完成の注文で均等配分。生産時間は受注から完成まで（出荷待ちを除く）。金額は表示時に丸めています。</p>`;
  return `<article class="card receipt">${heading}${summary}${brief}${resultNext(guide)}${expanded?`<details class="receipt-details"><summary>収支の内訳・前回との比較</summary>${ledger}${measured}</details>`:ledger+measured}</article>`;
}
function change(now,before,unit,lowerBetter){const diff=now-before;if(Math.abs(diff)<.05)return '変化なし';return `${Math.abs(diff).toFixed(1)}${unit}${diff<0?(lowerBetter?'短縮':'減'):(lowerBetter?'増加':'増')}`;}
function escape(t){return String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function place(p){
  stopSkip();
  if(!writer||saveBlocked){toast('進行を保存できる画面で配置してください');return;}
  if(!p.id&&s.cash<M.MACHINES[p.kind].cost){toast('資金が足りません。材料費も残して投資しましょう');return;}
  $('#controls').open=false;close();selected=p.id||null;resumeSpeed=speed||1;placing={...p,draining:s.workers.some(w=>w.job)};
  speed=placing.draining?3:0;showPlacement();update();
}
function showPlacement(){
  $('#placeHint').hidden=false;
  const text=placing.draining?'今の工程を仕上げて停止します':'光る床をタップ → 配置して生産再開';
  $('#placeHint').innerHTML=`${text} <button id="cancelPlace">取消して再開</button>`;
  $('#cancelPlace').onclick=endPlacement;
  placementCells=[];
  if(!placing.draining)for(let x=1;x<s.width;x++)for(let y=0;y<s.height-1;y++)if(M.canPlace(s,placing.kind,x,y,placing.id))placementCells.push({x,y});
}
function endPlacement(){placing=null;placementCells=[];$('#placeHint').hidden=true;speed=resumeSpeed;update();if(selected)selectMachine(selected,true);}

let viewport={w:0,h:0,u:0,ox:0,oy:0},hitTargets=[];
function point(x,y,z=0){return project(viewport,x,y,z);}
function draw(t){
  const rect=canvas.getBoundingClientRect();
  if(rect.width<1||rect.height<1)return;
  const dpr=Math.min(devicePixelRatio||1,2),W=rect.width,H=rect.height;
  if(canvas.width!==Math.round(W*dpr)||canvas.height!==Math.round(H*dpr)){
    canvas.width=Math.round(W*dpr);canvas.height=Math.round(H*dpr);
  }
  ctx.setTransform(dpr,0,0,dpr,0,0);
  const u=Math.min(W/(s.width+s.height+2.45),(H-62)/((s.width+s.height)*.5+3.7))*zoom;
  viewport={w:W,h:H,u,ox:W*.5-(s.width-s.height)*u*.5+u*.22+pan.x,oy:H*.5-(s.width+s.height)*u*.21+pan.y};
  const running=writer&&!saveBlocked&&!document.hidden&&!tab&&(speed>0||!!skipping)&&(!placing||placing.draining);
  hitTargets=drawWorkshop(ctx,s,viewport,{time:s.clock*1000,running,reducedMotion:reducedMotion.matches,selected,placing,placementCells,showLabels});
}
let down=null;canvas.onpointerdown=e=>{down={x:e.clientX,y:e.clientY,px:pan.x,py:pan.y};canvas.setPointerCapture(e.pointerId);};canvas.onpointermove=e=>{if(down&&!placing){pan.x=Math.max(-300,Math.min(300,down.px+e.clientX-down.x));pan.y=Math.max(-200,Math.min(200,down.py+e.clientY-down.y));}};canvas.onpointerup=e=>{if(!down)return;const tap=Math.hypot(e.clientX-down.x,e.clientY-down.y)<8;down=null;if(!tap)return;const r=canvas.getBoundingClientRect(),{u,ox,oy}=viewport;const a=(e.clientX-r.left-ox)/u,b=(e.clientY-r.top-oy)/(u*.5),x=Math.floor((a+b)/2),y=Math.floor((b-a)/2);if(placing){if(placing.draining){toast('今の工程が終わると床を選べます');return;}const p=placing;const ok=act(()=>p.id?M.move(s,p.id,x,y):M.purchase(s,p.kind,x,y));if(ok){selected=p.id||s.machines.find(m=>m.x===x&&m.y===y)?.id||null;endPlacement();}}else{const id=pickMachine({x:e.clientX-r.left,y:e.clientY-r.top},hitTargets);selectMachine(id);}};canvas.onpointercancel=()=>down=null;
function startSkip(){
  if(placing||tab||!writer||saveBlocked)return;
  const o=M.frontOrder(s);if(!o||o.done===o.qty)return;
  skipping={ticks:0,clock:s.clock,cash:s.cash};speed=0;tickRemainder=0;last=0;update();
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
      const result=M.advanceToReady(s,100);skipping.ticks+=result.ticks;
      if(result.status==='ready')stopSkip(`生産完了 · 工場時間 +${Math.round(s.clock-skipping.clock)}秒 / 人件費 ${money(skipping.cash-s.cash)}。出荷できます`,false);
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
update();requestAnimationFrame(frame);

