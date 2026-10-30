import * as M from './model.mjs';
import {project,machineHull,pickMachine} from './view.mjs';
const $=s=>document.querySelector(s),KEY='forge.factory.v1',canvas=$('#world'),ctx=canvas.getContext('2d');
let s=M.fresh(),speed=1,last=0,zoom=1,pan={x:0,y:0},placing=null,selected=null,tab=null,toastUntil=0,revision=null,writer=false,saveBlocked=false,paintTime=0,placementCells=[],resumeSpeed=1,skipping=null,tickRemainder=0;
try{const raw=localStorage.getItem(KEY);if(raw){const env=JSON.parse(raw);if(!M.validate(env.state))throw Error('invalid');s=env.state;revision=env.revision;}}catch{saveBlocked=true;speed=0;}
// A completed saved order remains safe to dispatch after reopening the page.
if(s.orders.some(o=>!o.shipped&&o.done===o.qty))speed=0;
function toast(t){if(tab){$('#sheetNotice').textContent=t;$('#sheetNotice').hidden=false;}$('#toast').textContent=t;$('#toast').style.display='block';toastUntil=performance.now()+4200;}
function save(){if(!writer||saveBlocked)return;try{const previous=localStorage.getItem(KEY);if(previous&&JSON.parse(previous).revision!==revision){writer=false;speed=0;toast('別の画面で保存されました。再読み込みしてください');return;}revision=crypto.randomUUID?.()||String(Date.now()+Math.random());localStorage.setItem(KEY,JSON.stringify({revision,state:s}));}catch{saveBlocked=true;toast('保存できません。設定から進行を書き出せます');}}
if(navigator.locks){navigator.locks.request(KEY,{ifAvailable:true},async lock=>{if(!lock){toast('別のタブで起動中です。この画面は閲覧専用');return;}writer=true;if(saveBlocked)toast('保存データを読み込めません。上書きせず停止しました');await new Promise(resolve=>window.addEventListener('pagehide',()=>{save();resolve();},{once:true}));});}else{writer=true;}
window.addEventListener('storage',e=>{if(e.key===KEY){writer=false;speed=0;toast('別画面の更新を検出。再読み込みしてください');}});
window.addEventListener('pageshow',e=>{if(e.persisted){writer=false;speed=0;toast('復帰しました。続けるには再読み込みしてください');}});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stopSkip();save();last=0;tickRemainder=0;});window.addEventListener('pagehide',save);setInterval(save,5000);
function act(fn){if(!writer||saveBlocked){toast(saveBlocked?'保存に問題があります。設定を開いてください':'別画面で起動中です。再読み込みしてください');return;}stopSkip();const before=new Set(M.OFFERS.filter(o=>o.growth&&M.offerStatus(s,o.id).qualified).map(o=>o.id));const error=fn();if(error)toast(error);else{const unlocked=M.OFFERS.filter(o=>o.growth&&!before.has(o.id)&&M.offerStatus(s,o.id).qualified);if(unlocked.length)M.note(s,`受注条件を達成：${unlocked.map(o=>o.label).join('・')}`);save();toast(s.log[0]);}update();if(tab)renderPanel();return !error;}
const money=v=>'¥'+Math.floor(v).toLocaleString('ja-JP');
function update(){ $('#cash').textContent=money(s.cash);$('#deliveries').textContent=s.delivered+' 件';$('#clock').textContent=`${Math.floor(s.clock/60).toString().padStart(2,'0')}:${Math.floor(s.clock%60).toString().padStart(2,'0')}`;$('#floor').textContent=`第一工場 · ${s.width} × ${s.height}`;const o=M.frontOrder(s);$('#orderTitle').textContent=o?`${o.label}　${o.done} / ${o.qty} 個`:'次の注文で工場を育てよう';$('#orderAction').textContent=skipping?'早送りを停止':o&&o.done===o.qty?'出荷する ↗':o?'完成まで進める »':'注文を見る ↗';$('#orderAction').disabled=!!placing||!writer||saveBlocked;$('#orderMore').hidden=!o;$('#orderMore').disabled=!!placing;$('#orderHint').textContent=skipping?'完成した注文で自動停止':o&&o.done===o.qty?(speed===0?'完成！ 出荷して代金を受け取ろう':'出荷して代金を受け取ろう'):o?'人件費・納期も進みます':'受注 → 完成まで進める → 出荷';$('#orderProgress').style.width=o?`${o.done/o.qty*100}%`:'0%';const busy=s.workers.filter(w=>w.job).length;$('#activity').textContent=placing?(placing.draining?'現在の工程を仕上げ中':'配置モード'):skipping?'完成まで進めています':speed===0?'一時停止中':`${busy} / 3 人 作業中`;const plan=M.growthPlan(s,s.goalOffer);$('#goal').textContent=plan?`目標：${plan.offer.label}`:s.delivered===0?'最初の製品を出荷しよう':'次の成長目標を選ぼう';$('#hint').textContent=plan?planHint(plan):s.delivered===0?'受注 → 完成まで進める → 出荷で入金':'必要な投資と材料費を見て、次の仕事へ';$('#growthAction').textContent=plan?'目標を見る ›':'成長案件 ›';updateSelection();document.querySelectorAll('[data-speed]').forEach(b=>{b.classList.toggle('active',+b.dataset.speed===speed);b.disabled=!!placing;});}
function open(panel){stopSkip();if(placing)endPlacement();tab=panel;$('#sheet').dataset.panel=panel;$('#sheetNotice').hidden=true;renderPanel();if(!$('#sheet').open)$('#sheet').showModal();$('#sheet').scrollTop=0;updateSelection();}function close(){tab=null;$('#sheet').close();updateSelection();}$('#close').onclick=close;$('#sheet').addEventListener('cancel',()=>{tab=null;updateSelection();});document.querySelectorAll('[data-panel]').forEach(b=>b.onclick=()=>open(b.dataset.panel));$('#menu').onclick=()=>open('save');$('#growthAction').onclick=()=>open('growth');$('#orderAction').onclick=()=>{if(skipping){stopSkip();return;}const o=M.frontOrder(s);if(o&&o.done===o.qty)ship(o.id);else if(o)startSkip();else open('orders');};$('#orderMore').onclick=()=>open('orders');document.querySelectorAll('[data-speed]').forEach(b=>b.onclick=()=>{stopSkip();speed=+b.dataset.speed;update();});$('#plus').onclick=()=>zoom=Math.min(2,zoom+.15);$('#minus').onclick=()=>{zoom=Math.max(.7,zoom-.15);if(zoom<=1)pan={x:0,y:0};};
const stageNames={cut:'切断',drill:'穴あけ',lathe:'旋盤',inspect:'検品'};
function selectMachine(id,focus=false){
  selected=id;
  const m=s.machines.find(m=>m.id===id);
  if(m&&focus&&viewport.u){const p=point(m.x+.5,m.y+.5,.5);pan.x+=viewport.w*.5-p.x;pan.y+=viewport.h*.32-p.y;}
  updateSelection();
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
    b.setAttribute('aria-label',`${M.MACHINES[kind].name}：工程待ち${q[kind].waiting}個。設備を選択`);
    b.setAttribute('aria-pressed',String(m?.kind===kind));
  }
  $('#machineQuick').hidden=!m||!!placing||!!tab;
  if(!m)return;
  const w=s.workers.find(w=>w.job?.machine===m.id),counts=q[m.kind];
  const peers=s.machines.filter(x=>x.kind===m.kind);
  $('#machineTitle').textContent=`${M.MACHINES[m.kind].name}${peers.length>1?' '+(peers.findIndex(x=>x.id===m.id)+1)+'/'+peers.length:''} · Lv.${m.level}`;
  $('#machineWorker').textContent=w?`${w.name} · ${w.job.phase==='walk'?'運搬中（光る線が経路）':w.job.rework?'品質調整中':'加工中'}`:'担当者・材料待ち';
  $('#machineQueue').textContent=`同種工程：待ち ${counts.waiting} · 運搬 ${counts.walking} · 加工 ${counts.working}`;
  $('#quickUpgrade').textContent=m.level>=3?'改良済み':`改良 ${money(1500*m.level)}`;
  $('#quickUpgrade').disabled=m.level>=3;
}
$('#quickClose').onclick=()=>{selected=null;updateSelection();};
$('#quickMove').onclick=()=>{const m=s.machines.find(m=>m.id===selected);if(m)place({id:m.id,kind:m.kind});};
$('#quickUpgrade').onclick=()=>act(()=>M.upgrade(s,selected));
$('#quickDetail').onclick=()=>open('machines');
const card=(title,body)=>`<article class="card"><h3>${title}</h3>${body}</article>`;
function renderPanel(){const body=$('#sheetBody');$('#sheetTitle').textContent=({orders:'受注と出荷',growth:'成長案件',machines:'設備と配置',workers:'職人を育てる',finance:'経営と拡張',save:'保存と設定',result:'出荷結果'})[tab];let html='';if(tab==='orders'){for(const o of s.orders.filter(o=>!o.shipped)){const remain=Math.ceil(o.start+o.due-s.clock),quote=M.shipmentQuote(s,o);html+=card(escape(o.label),`<small>生産中 · ${o.qty}個 / 品質 ${o.quality}</small><p>${o.done}個完成 · ${!quote.late?'納期まで '+remain+'秒':'納期超過：報酬15%減額'}</p><progress value="${o.done}" max="${o.qty}"></progress><button class="primary wide" data-ship="${o.id}" ${o.done<o.qty?'disabled':''}>出荷して ${money(quote.pay)} を受け取る</button>`);}html+='<p>同時受注は2件。受注時に材料を購入します。詳細画面を開いている間は時間が止まります。</p>';html+='<button class="wide growth-entry" data-next="growth">成長案件 · 投資で次の仕事へ ↗</button>';for(const o of M.OFFERS.filter(o=>!o.growth))html+=offerCard(o);}
if(tab==='growth'){html='<p>目標を選ぶと工場画面で追えます。量産・精密はいつでも切替でき、両方を伸ばせます。</p>'+M.OFFERS.filter(o=>o.growth).sort((a,b)=>Number(b.id===s.goalOffer)-Number(a.id===s.goalOffer)).map(growthCard).join('')+'<button class="wide" data-next="orders">通常の注文を見る</button>';}
if(tab==='machines'){html='<p>生産の途中でも配置を変えられます。今の工程だけを仕上げて停止し、配置後に再開します。機械の手前1マスは作業面です。</p>';for(const m of [...s.machines].sort((a,b)=>Number(b.id===selected)-Number(a.id===selected))){const worker=s.workers.find(w=>w.job?.machine===m.id),q=M.production(s).stages[m.kind];html+=card(`${m.id===selected?'<span class="tag">選択中</span> ':''}${M.MACHINES[m.kind].name}　Lv.${m.level}`,`<small>${worker?worker.job.phase==='walk'?'担当者が運搬中':worker.job.rework?'品質調整中':'加工中':'担当者・材料待ち'} · 座標 ${m.x}, ${m.y}</small><p>同種工程：待ち ${q.waiting}個 · 運搬 ${q.walking}個 · 加工 ${q.working}個</p><div class="row"><button data-move="${m.id}">移動</button><button data-upgrade="${m.id}" ${m.level>=3?'disabled':''}>改良 ${money(1500*m.level)}</button><button data-sell="${m.id}">売却</button></div>`);}html+='<h3>新しい設備</h3>';for(const [k,m]of Object.entries(M.MACHINES))html+=card(m.name,`<small>${k==='lathe'?'精密シャフトを生産できるようになります':'台数を増やすと並行作業ができます'}</small><button class="wide primary" data-buy="${k}">設置場所を選ぶ · ${money(m.cost)}</button>`);}
if(tab==='workers'){html='<p>担当は優先順位です。他工程も手伝います。技能は加工速度と検品品質に影響し、仕事でも経験が貯まります。</p>';for(const w of s.workers)html+=card(`${escape(w.name)} <span class="tag">技能 ${w.skill}</span>`,`<small>経験 ${Math.floor(w.xp)} / 30 · ${w.job?'作業中':'待機中'}</small><div class="row"><select data-role="${w.id}" aria-label="${escape(w.name)}の担当">${[['auto','全工程'],['machine','加工優先'],['inspect','検品優先']].map(([v,l])=>`<option value="${v}" ${w.role===v?'selected':''}>${l}</option>`).join('')}</select><button data-train="${w.id}" ${w.skill>=4?'disabled':''}>研修 ${money(800*w.skill)}</button></div><button class="wide" data-mentor="${w.id}">${w.mentor?'指導を終了':'指導役にする'}</button><small>指導中は本人の加工時間+25%、仲間の獲得経験+40%。</small>`);}
if(tab==='result'){const r=s.results?.[0];html=r?receipt(r,true):'<p>まだ出荷記録がありません。</p>';html+='<div class="result-actions"><button class="primary" data-next="orders">次の注文へ</button><button data-next="machines">設備に投資</button><button data-next="workers">職人を育てる</button></div>';}
if(tab==='finance'){html=card('収支',`<div class="row"><span>累計売上</span><b>${money(s.revenue)}</b></div><div class="row"><span>材料・投資・人件費</span><b>${money(s.expense)}</b></div><p>加工する部品がある間、人件費は毎秒¥0.7。画面を閉じている間の生産・請求はありません。</p>`)+'<h3>出荷の振り返り</h3><p>直近12件を保存。利益は設備・研修・増築費を引く前の金額です。</p>'+(s.results?.length?'<button class="wide" data-next="result">直近の出荷結果を開く</button>'+s.results.map(r=>`<details class="result-history"><summary>${escape(r.label)} × ${r.qty}<b>${M.resultProfit(r)===null?'記録なし':signedMoney(M.resultProfit(r))}</b></summary>${receipt(r,false)}</details>`).join(''):'<p>出荷すると結果をここで見返せます。</p>')+card('工場を広げる',`<p>床面積を8×6から10×8へ。追加設備と動線のための余白を作ります。</p><button class="primary wide" id="expand" ${s.width===10?'disabled':''}>${s.width===10?'拡張済み':'増築する · ¥3,500'}</button>`)+card('生産の記録',`<p>完了工程 ${s.stats.processed}回<br>品質調整 ${s.stats.rework}回<br>運搬・移動距離 ${Math.floor(s.stats.walk)}マス</p>`)+card('工場日誌',s.log.map(t=>`<p>${escape(t)}</p>`).join(''));}
if(tab==='save'){html=card('進行は自動保存',`<p>${saveBlocked?'保存エラー：元データは上書きしていません。書き出して保管できます。':writer?'このブラウザに5秒ごとに保存しています。':'別のタブで起動中、または復帰後の閲覧状態です。再読み込みしてください。'}<br>旧フロトラの保存データとは独立しています。</p><button id="export" class="wide">セーブを書き出す</button><label><p>書き出したセーブを読み込む（現在の進行と置き換え）</p><input id="import" type="file" accept="application/json,.json"></label><button id="reload" class="wide">再読み込み</button>`)+card('遊び方','<p>① 受注で材料を購入<br>② 職人が自動で運搬・加工<br>③ 完成した注文を出荷して入金<br>④ 設備の追加・改良、研修に再投資<br><br>工場はドラッグで移動、＋−で拡大縮小。機械や工程待ちをタップすると、担当者・運搬経路を確認して移動・改良できます。同じ工程をもう一度押すと次の同種設備を選びます。配置モードでは床をタップしてください。</p>');}
body.innerHTML=html;body.querySelectorAll('[data-goal]').forEach(b=>b.onclick=()=>{if(act(()=>M.setGoal(s,b.dataset.goal)))$('#sheet').scrollTop=0;});body.querySelectorAll('[data-plan-action]').forEach(b=>b.onclick=()=>runPlan(b.dataset.planAction));body.querySelectorAll('[data-next]').forEach(b=>b.onclick=()=>open(b.dataset.next));body.querySelectorAll('[data-order]').forEach(b=>b.onclick=()=>{if(act(()=>M.accept(s,b.dataset.order))){close();speed=speed||1;update();}});body.querySelectorAll('[data-ship]').forEach(b=>b.onclick=()=>ship(+b.dataset.ship));body.querySelectorAll('[data-buy]').forEach(b=>b.onclick=()=>place({kind:b.dataset.buy}));body.querySelectorAll('[data-move]').forEach(b=>b.onclick=()=>place({id:b.dataset.move,kind:s.machines.find(m=>m.id===b.dataset.move).kind}));body.querySelectorAll('[data-upgrade]').forEach(b=>b.onclick=()=>act(()=>M.upgrade(s,b.dataset.upgrade)));body.querySelectorAll('[data-sell]').forEach(b=>b.onclick=()=>act(()=>M.sell(s,b.dataset.sell)));body.querySelectorAll('[data-train]').forEach(b=>b.onclick=()=>act(()=>M.train(s,+b.dataset.train)));body.querySelectorAll('[data-role]').forEach(b=>b.onchange=()=>act(()=>{s.workers.find(w=>w.id===+b.dataset.role).role=b.value;M.note(s,'担当の優先順位を変更');}));body.querySelectorAll('[data-mentor]').forEach(b=>b.onclick=()=>act(()=>{const w=s.workers.find(w=>w.id===+b.dataset.mentor);w.mentor=!w.mentor;M.note(s,`${w.name}の指導役を変更`);}));if($('#expand'))$('#expand').onclick=()=>act(()=>M.expand(s));if($('#export'))$('#export').onclick=()=>{const blob=new Blob([JSON.stringify({revision,state:s})],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='forge-save.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};if($('#reload'))$('#reload').onclick=()=>location.reload();if($('#import'))$('#import').onchange=async e=>{try{const f=e.target.files[0];if(!f||f.size>200000)throw Error();const data=JSON.parse(await f.text());if(!M.validate(data.state))throw Error();if(!writer){toast('別のタブを閉じて再読み込みしてください');return;}if(!confirm('現在の進行を、選んだセーブに置き換えますか？'))return;s=data.state;saveBlocked=false;revision=JSON.parse(localStorage.getItem(KEY)||'null')?.revision??null;save();update();renderPanel();toast('セーブを読み込みました');}catch{toast('対応する正常なセーブではありません。進行は変更していません');}};}


function planHint(p){
  if(p.order)return p.phase==='ship'?'完成！ 出荷して入金しよう':`生産中 ${p.order.done} / ${p.order.qty}個 · 工場で動線を整えよう`;
  if(p.phase==='slots')return '進行中の注文を出荷して、受注枠を空けよう';
  if(p.phase==='funds')return `準備費＋材料費まで、あと ${money(p.shortage)}`;
  if(p.phase==='prepare')return `次は${p.next.label} · 材料費 ${money(p.offer.cost)}も残そう`;
  return `条件達成 · 材料費 ${money(p.offer.cost)}で受注できる`;
}
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
  return `<article class="card growth-card ${chosen?'chosen-goal':''}"><div class="plan-heading"><small>${o.growth}</small><button data-goal="${o.id}" ${chosen?'disabled':''}>${chosen?'✓ 目標に設定中':'この目標を追う'}</button></div><h3>${o.label}</h3><small>${o.qty}個 · 品質${o.quality} · 納期${o.due}秒 · 納品${money(o.pay)}</small><ol class="plan-steps" aria-label="目標の進み方"><li class="${p.order||p.phase==='ready'?'done':'current'}">1 準備</li><li class="${p.phase==='producing'?'current':p.phase==='ship'?'done':''}">2 生産</li><li class="${p.phase==='ship'?'current':''}">3 出荷</li></ol>${budget}<strong class="plan-next">${phaseLabel}</strong><button class="wide primary" data-plan-action="${o.id}">${escape(action)}</button></article>`;
}

function offerCard(o){
  const status=M.offerStatus(s,o.id),missingPanels=[...new Set(status.requirements.filter(r=>!r.met).map(r=>r.panel))];
  const description=o.id==='rush'?'通常の量産注文と同じ28個を、90秒短い納期で。追加投資と動線を整えて挑戦。':o.id==='master'?'技能不足の検品は時間が2.5倍。検品台の改良でも補えます。':'';
  return card(escape(o.label),`${o.growth?`<div class="offer-path"><span>${o.growth}</span><b>${status.qualified?'条件達成':'準備中'}</b></div>`:''}<small>${escape(o.name)}</small><div class="row"><span class="tag">${o.qty}個</span><span class="tag">品質 ${o.quality}</span><span class="tag">納期 ${o.due}秒</span></div>${description?`<p>${description}</p>`:''}<p>材料 ${money(o.cost)} → 納品 ${money(o.pay)}<br>人件費・設備費を引く前の差額 ${money(o.pay-o.cost)}</p>${status.requirements.length?`<ul class="offer-requirements">${status.requirements.map(r=>`<li class="${r.met?'met':''}">${r.met?'✓':'○'} ${r.label}</li>`).join('')}</ul>`:''}${status.qualified&&status.reason?`<p class="offer-blocked">${status.reason}</p>`:''}<button class="wide primary" data-order="${o.id}" ${status.available?'':'disabled'}>${status.available?'受注して生産開始':!status.qualified?'受注条件を満たすと開始':'今は受注できません'}</button>${missingPanels.map(panel=>`<button class="wide" data-next="${panel}">${panel==='workers'?'職人を育てる':'設備を整える'} ↗</button>`).join('')}`);
}

const signedMoney=v=>(v<0?'−':'+')+'¥'+Math.round(Math.abs(v)).toLocaleString('ja-JP');
const resultMoney=v=>'¥'+v.toLocaleString('ja-JP',{minimumFractionDigits:1,maximumFractionDigits:1});
const duration=v=>v.toFixed(1)+'秒';
function ship(id){if(act(()=>M.dispatch(s,id))){$('#toast').style.display='none';open('result');}}
function receipt(r,expanded){
  const profit=M.resultProfit(r),prev=M.previousResult(s,r);
  let comparison='';
  if(profit!==null){
    comparison=prev?`<div class="result-compare"><strong>同じ注文の前回比</strong><div class="row"><span>生産時間</span><b>${change(r.seconds,prev.seconds,'秒',true)}</b></div><div class="row"><span>移動距離</span><b>${change(r.walk,prev.walk,'マス',true)}</b></div><div class="row"><span>受注利益</span><b>${signedMoney(profit-M.resultProfit(prev))}</b></div><small>納期・同時受注・職人の成長でも結果は変わります。</small></div>`:'<p>同じ注文をもう一度出荷すると、前回と比べられます。</p>';
  }
  return `<article class="card receipt"><small>${expanded?'納品完了 · ':''}${escape(r.label)} × ${r.qty}${r.late?' · 納期超過':''}</small><div class="result-profit"><span>今回の受注利益</span><strong>${profit===null?'記録なし':signedMoney(profit)}</strong><small>設備・研修・増築費を引く前</small></div><dl class="result-ledger"><div><dt>入金${r.late?'（15%減額）':''}</dt><dd>${resultMoney(r.payout)}</dd></div><div><dt>材料費</dt><dd>−${resultMoney(r.material)}</dd></div><div><dt>人件費</dt><dd>${r.wages===null?'記録なし':'−'+resultMoney(r.wages)}</dd></div></dl>${profit===null?'<p>更新前に受けた注文のため、時間・人件費は未計測です。次の受注から記録します。</p>':`<div class="result-stats"><div><small>生産時間</small><b>${duration(r.seconds)}</b></div><div><small>移動距離</small><b>${Math.round(r.walk)}マス</b></div><div><small>品質調整</small><b>${r.rework}回</b></div></div>${comparison}<p class="accounting-note">人件費は未完成の注文で均等配分。生産時間は受注から完成まで（出荷待ちを除く）。金額は表示時に丸めています。</p>`}</article>`;
}
function change(now,before,unit,lowerBetter){const diff=now-before;if(Math.abs(diff)<.05)return '変化なし';return `${Math.abs(diff).toFixed(1)}${unit}${diff<0?(lowerBetter?'短縮':'減'):(lowerBetter?'増加':'増')}`;}
function escape(t){return String(t).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));}
function place(p){
  stopSkip();
  if(!writer||saveBlocked){toast('進行を保存できる画面で配置してください');return;}
  if(!p.id&&s.cash<M.MACHINES[p.kind].cost){toast('資金が足りません。材料費も残して投資しましょう');return;}
  close();selected=p.id||null;resumeSpeed=speed||1;placing={...p,draining:s.workers.some(w=>w.job)};
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

let viewport={w:0,h:0,u:0,ox:0,oy:0},hitTargets=[];function point(x,y,z=0){return project(viewport,x,y,z);}
function poly(points,color,stroke=null){ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.fillStyle=color;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=.7;ctx.stroke();}}
function box(x,y,w,d,h,color,top,side,z=0){const a=point(x,y,z),b=point(x+w,y,z),c=point(x+w,y+d,z),e=point(x,y+d,z),A=point(x,y,z+h),B=point(x+w,y,z+h),C=point(x+w,y+d,z+h),E=point(x,y+d,z+h);poly([b,c,C,B],side);poly([e,c,C,E],color);poly([A,B,C,E],top);}
function label(t,x,y,color='#f2f3e9',size=10){ctx.font=`600 ${size}px system-ui`;ctx.textAlign='center';ctx.fillStyle='#13242bdc';ctx.fillRect(x-ctx.measureText(t).width/2-5,y-size,ctx.measureText(t).width+10,size+7);ctx.fillStyle=color;ctx.fillText(t,x,y);return {x:x-ctx.measureText(t).width/2-5,y:y-size,w:ctx.measureText(t).width+10,h:size+7};}
function draw(t){const rect=canvas.getBoundingClientRect(),dpr=Math.min(devicePixelRatio,2);if(canvas.width!==Math.round(rect.width*dpr)||canvas.height!==Math.round(rect.height*dpr)){canvas.width=Math.round(rect.width*dpr);canvas.height=Math.round(rect.height*dpr);}ctx.setTransform(dpr,0,0,dpr,0,0);const W=rect.width,H=rect.height;const u=Math.min(W/(s.width+s.height+2),H/(s.width+s.height)*1.35)*zoom;viewport={w:W,h:H,u,ox:W*.5-(s.width-s.height)*u*.5+pan.x,oy:H*.51-(s.width+s.height)*u*.23+pan.y};ctx.fillStyle='#293b40';ctx.fillRect(0,0,W,H);
// Yard, road, concrete slab and low cutaway wall.
box(-1,-1,s.width+2,s.height+3,.12,'#31434a','#405358','#34474c',-.2);box(-1,s.height+.5,s.width+2,1.6,.03,'#1b2b31','#1b2b31','#1b2b31',-.05);for(let x=0;x<s.width;x+=2)box(x,s.height+1.2,.7,.045,.01,'#c9b880','#c9b880','#c9b880');box(0,0,s.width,s.height,.18,'#5b6d70','#758385','#4b6065',-.18);for(let x=0;x<s.width;x++)for(let y=0;y<s.height;y++){poly([point(x,y),point(x+1,y),point(x+1,y+1),point(x,y+1)],(x+y)%2?'#788789':'#7c8b8b','#92a0a044');}box(0,-.16,s.width,.16,.85,'#3a535d','#60808a','#354c56');box(-.16,0,.16,s.height,.85,'#3a535d','#60808a','#354c56');for(let x=0;x<s.width;x+=2){box(x+.2,-.08,1.1,.06,.28,'#a7c7bd','#d5e7dc','#7ba9a5',.38);}for(let y=0;y<s.height;y++)box(.1,y+.1,.06,.6,.01,'#e0bd68','#e0bd68','#e0bd68');
// Material stock and outbound pallets.
box(.12,.1,.65,.7,.13,'#926c45','#b18c57','#775637');for(let i=0;i<4;i++)box(.15,.15+i*.13,.58,.09,.2,'#6f8793','#bac9ca','#57707c',.13);box(.1,s.height-1,.7,.7,.12,'#916b46','#b18d60','#725439');for(let i=0;i<Math.min(4,s.orders.reduce((n,o)=>n+(!o.shipped?o.done:0),0));i++)box(.15+(i%2)*.3,s.height-.92+Math.floor(i/2)*.3,.26,.26,.27,'#b88a4e','#d3ad6e','#99703e',.12);
// Selection follows real worker path; the counts above are shared by machine kind.
const chosen=s.machines.find(m=>m.id===selected);
if(chosen&&!placing){
  const m=chosen,w=s.workers.find(w=>w.job?.machine===m.id);
  ctx.save();ctx.strokeStyle='#ffdc86';ctx.lineWidth=2.5;
  const outline=[point(m.x-.05,m.y-.05,.02),point(m.x+1.05,m.y-.05,.02),point(m.x+1.05,m.y+1.05,.02),point(m.x-.05,m.y+1.05,.02)];
  ctx.beginPath();outline.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.stroke();
  if(w?.job.phase==='walk'){
    const route=[{x:w.x,y:w.y},...w.job.path].map(p=>point(p.x+.45,p.y+.45,.04));
    ctx.strokeStyle='#e2eea2';ctx.setLineDash([5,4]);ctx.beginPath();route.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.stroke();
  }
  ctx.restore();
}
hitTargets=[];
for(const m of [...s.machines].sort((a,b)=>a.x+a.y-b.x-b.y)){const c=M.MACHINES[m.kind].color;const worker=s.workers.find(w=>w.job?.machine===m.id),active=worker?.job.phase==='work';poly([point(m.x+.1,m.y+.1),point(m.x+1.15,m.y+.1),point(m.x+1.15,m.y+1.05),point(m.x+.1,m.y+1.05)],'#263f4d55');box(m.x+.06,m.y+.08,.88,.8,.18,'#243e47','#38515a','#203640');if(m.kind==='cut'){box(m.x+.12,m.y+.13,.72,.64,.45,'#b58945',c,'#88652d',.18);box(m.x+.18,m.y+.2,.6,.43,.05,'#82969b','#c1ccca','#6a8086',.65);box(m.x+.52,m.y+.2,.12,.48,.35,'#9b783f',c,'#75592d',.7);}if(m.kind==='drill'){box(m.x+.4,m.y+.14,.18,.2,.95,'#467f8d',c,'#345f70',.18);box(m.x+.2,m.y+.3,.55,.45,.09,'#79989e','#c0d3d0','#5e7f86',.55);box(m.x+.25,m.y+.16,.42,.28,.25,'#477a88',c,'#315e6a',1);box(m.x+.38,m.y+.4,.06,.07,.28,'#becbd1','#eff1e9','#859da9',.7+(active?Math.sin(t/170)*.05:0));}if(m.kind==='lathe'){box(m.x+.1,m.y+.12,.8,.65,.55,'#486b93',c,'#344e72',.18);box(m.x+.22,m.y+.24,.52,.38,.25,'#172b38','#345365','#0e202e',.62);box(m.x+.18,m.y+.12,.2,.5,.4,'#4c74a0',c,'#345578',.65);}if(m.kind==='inspect'){for(const dx of [.15,.75])box(m.x+dx,m.y+.15,.08,.6,.5,'#486456','#779885','#324a40',.18);box(m.x+.08,m.y+.08,.84,.8,.11,'#7f9c7b',c,'#5c795f',.68);box(m.x+.5,m.y+.13,.25,.15,.22,'#293d43','#78bec0','#192f34',.79);}if(active){const p=point(m.x+.75,m.y+.75,1.1);ctx.fillStyle='#c1e8b0';ctx.beginPath();ctx.arc(p.x,p.y,3,0,Math.PI*2);ctx.fill();}const p=point(m.x+.5,m.y,1.35);const bounds=label(M.MACHINES[m.kind].name,p.x,p.y,m.id===selected?'#ffdc86':active?'#d7edb5':'#e5eee9',Math.max(9,Math.min(12,u*.4)));hitTargets.push({id:m.id,hull:machineHull(viewport,m),label:bounds});}
// Workers move along actual simulation routes.
for(const w of [...s.workers].sort((a,b)=>a.x+a.y-b.x-b.y)){const p=point(w.x+.45,w.y+.45);ctx.fillStyle='#20303955';ctx.beginPath();ctx.ellipse(p.x,p.y+2,7,3,0,0,Math.PI*2);ctx.fill();box(w.x+.32,w.y+.32,.2,.18,.32,'#d6a351','#f1c576','#a77a39',.12);const head=point(w.x+.42,w.y+.4,.57);ctx.fillStyle=['#f2d288','#e6e8db','#e59b65'][w.id];ctx.beginPath();ctx.arc(head.x,head.y,Math.max(3,u*.12),0,Math.PI*2);ctx.fill();if(w.job?.phase==='walk')box(w.x+.58,w.y+.38,.2,.2,.15,'#91a6ac','#c3d3d4','#647f89',.25);}
const trY=s.height+.7;box(s.width-2.4,trY,1.65,.65,.6,'#b7c9c7','#e5ece4','#829e9d');box(s.width-.7,trY,.65,.65,.42,'#b28d4f','#efc46f','#97723a');box(s.width-.55,trY+.05,.4,.52,.19,'#2e5360','#6b98a0','#294653',.42);for(const x of [s.width-2.1,s.width-.3]){const p=point(x,trY+.67,.02);ctx.fillStyle='#14242b';ctx.beginPath();ctx.arc(p.x,p.y,u*.14,0,Math.PI*2);ctx.fill();}
if(placing&&!placing.draining)for(const {x,y} of placementCells){poly([point(x+.05,y+.05,.01),point(x+.95,y+.05,.01),point(x+.95,y+.95,.01),point(x+.05,y+.95,.01)],'#b6d99544','#d8ed9d');}
}
let down=null;canvas.onpointerdown=e=>{down={x:e.clientX,y:e.clientY,px:pan.x,py:pan.y};canvas.setPointerCapture(e.pointerId);};canvas.onpointermove=e=>{if(down&&!placing){pan.x=Math.max(-300,Math.min(300,down.px+e.clientX-down.x));pan.y=Math.max(-200,Math.min(200,down.py+e.clientY-down.y));}};canvas.onpointerup=e=>{if(!down)return;const tap=Math.hypot(e.clientX-down.x,e.clientY-down.y)<8;down=null;if(!tap)return;const r=canvas.getBoundingClientRect(),{u,ox,oy}=viewport;const a=(e.clientX-r.left-ox)/u,b=(e.clientY-r.top-oy)/(u*.5),x=Math.floor((a+b)/2),y=Math.floor((b-a)/2);if(placing){if(placing.draining){toast('今の工程が終わると床を選べます');return;}const p=placing;const ok=act(()=>p.id?M.move(s,p.id,x,y):M.purchase(s,p.kind,x,y));if(ok){selected=p.id||s.machines.find(m=>m.x===x&&m.y===y)?.id||null;endPlacement();}}else{const id=pickMachine({x:e.clientX-r.left,y:e.clientY-r.top},hitTargets);selectMachine(id);}};canvas.onpointercancel=()=>down=null;
function startSkip(){
  if(placing||tab||!writer||saveBlocked)return;
  const o=M.frontOrder(s);if(!o||o.done===o.qty)return;
  skipping={ticks:0,clock:s.clock,cash:s.cash};speed=0;tickRemainder=0;last=0;update();
}
function stopSkip(message='早送りを停止しました'){
  if(!skipping)return;
  skipping=null;speed=0;tickRemainder=0;last=0;M.note(s,message);save();toast(message);update();
}
function frame(t){
  const playable=writer&&!saveBlocked&&!document.hidden&&!tab;
  if(skipping){
    if(!playable||placing)stopSkip();
    else{
      const result=M.advanceToReady(s,100);skipping.ticks+=result.ticks;
      if(result.status==='ready')stopSkip(`生産完了 · 工場時間 +${Math.round(s.clock-skipping.clock)}秒 / 人件費 ${money(skipping.cash-s.cash)}。出荷できます`);
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
  last=t;draw(t);if(t-paintTime>250){update();paintTime=t;}if(t>toastUntil)$('#toast').style.display='none';requestAnimationFrame(frame);
}
update();requestAnimationFrame(frame);
