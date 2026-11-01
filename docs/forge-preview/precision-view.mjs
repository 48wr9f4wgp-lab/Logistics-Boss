import * as M from './model.mjs?v=0.20';
import {precisionPlan,shaftEntryCost} from './precision.mjs?v=0.20';

const yen=n=>'¥'+Math.round(n).toLocaleString('ja-JP');

export function precisionDesk(s,choice,canWrite,escape){
  if(!s.machines.some(m=>m.kind==='lathe')){
    const required=shaftEntryCost(s),missing=Math.max(0,Math.ceil(required-s.cash)),active=M.frontOrder(s);
    const summary=missing?'あと '+yen(missing)+'で旋盤と最初の材料を用意できます。':active?'進行中の注文を出荷すると、床で設置場所を試せます。':'標準品の10本から始められます。床で試してから設置します。';
    return `<section class="shaft-desk"><h3>最初の旋盤を置く</h3><p>旋盤 ${yen(M.MACHINES.lathe.cost)} ＋ 標準シャフトの材料 ${yen(required-M.MACHINES.lathe.cost)}</p><p>${summary}</p><button id="shaftInstall" class="wide primary" ${missing||active||!canWrite?'disabled':''}>旋盤の置き場所を試す</button><button class="wide" data-next="orders">ほかの注文を見る</button></section>`;
  }
  const benches=s.machines.filter(m=>m.kind==='inspect');
  const benchOptions=benches.map(m=>`<option value="${escape(m.id)}" ${choice.benchId===m.id?'selected':''}>Lv.${m.level}（${m.x+1}列${m.y+1}段）</option>`).join('');
  const workers=s.workers.map(w=>`<option value="${w.id}" ${choice.inspector===w.id?'selected':''}>${escape(w.name)} · 技能${w.skill}</option>`).join('');
  return `<section class="shaft-desk"><label>仕事<select id="shaftOffer"><option value="fine">標準10本 · 品質2／240秒</option><option value="master" ${choice.offer==='master'?'selected':''}>高精度10本 · 品質3／150秒</option></select></label>
    <label>検品担当<select id="shaftInspector"><option value="">おまかせ</option>${workers}</select></label>
    <label>今回の準備<select id="shaftInvestment"><option value="none">投資しない</option><option value="train" ${choice.investment==='train'?'selected':''}>指名した職人を研修</option><option value="bench" ${choice.investment==='bench'?'selected':''}>検品台を改良</option></select></label>
    ${benches.length>1?`<label id="benchPick">改良する台<select id="shaftBench">${benchOptions}</select></label>`:''}
    <p id="shaftCost"></p><div class="shaft-estimate" aria-live="polite"><strong id="shaftForecast"></strong><small id="shaftNet"></small></div>
    <button id="shaftStart" class="wide primary"></button>
    <details class="shaft-detail"><summary>おまかせとの比較・育成</summary><p id="shaftBaseline"></p><small id="shaftExperience"></small><p>指名はこの10本だけ。研修で上げた技能と検品台の改良は、その後の仕事にも残ります。見積では、追加の変更をせず各注文を完成時に出荷します。</p></details></section>`;
}

export function bindPrecisionDesk(root,s,choice,estimator,canWrite,install,accept){
  const find=id=>root.querySelector('#'+id);
  if(find('shaftInstall')){estimator.cancel();find('shaftInstall').onclick=install;return;}
  let seenQuote=null;
  const shownNext=s.next;
  const sync=()=>{
    const inspector=find('shaftInspector').value;
    Object.assign(choice,{offer:find('shaftOffer').value,inspector:inspector===''?null:Number(inspector),
      investment:find('shaftInvestment').value,benchId:find('shaftBench')?.value??null});
    if(find('benchPick'))find('benchPick').hidden=choice.investment!=='bench';
    seenQuote=null;
    const plan=precisionPlan(s,choice),button=find('shaftStart');
    const training=choice.investment==='train'&&plan.worker?' · '+plan.worker.name+' 技能'+plan.worker.skill+' → '+plan.target:'';
    find('shaftCost').textContent='材料 '+yen(plan.job.cost)+' ＋ 準備 '+yen(plan.cost)+training;
    button.textContent='この10本を受注 · '+yen(plan.total);
    button.disabled=!canWrite||!!plan.error;
    find('shaftExperience').textContent=plan.worker?'現在の'+plan.worker.name+'　技能'+plan.worker.skill+' · 経験'+Math.floor(plan.worker.xp)+'/30'+(plan.worker.mentor?' · 指導役':''):'作業経験で技能が上がります。研修で上げた技能も次の注文に引き継ぎます。';
    const forecast=find('shaftForecast'),net=find('shaftNet'),baseline=find('shaftBaseline');
    forecast.textContent=plan.error||'この10本を見積中…';net.textContent='';baseline.textContent='';
    if(plan.error){estimator.cancel();return;}
    const options=[{precision:{...choice}}];
    if(choice.inspector!==null||choice.investment!=='none')options.push({precision:{offer:choice.offer}});
    estimator.request(s,options,rows=>{
      const [q,base]=rows||[];
      if(!q||q.error){forecast.textContent=q?.error||'見積を表示できません';return;}
      seenQuote=q;
      forecast.textContent='品質調整 '+q.rework+'/10本 · '+q.seconds.toFixed(1)+'秒で完成';
      net.textContent='納期'+Math.abs(q.margin).toFixed(1)+'秒'+(q.late?'超過':'余裕')+' · 準備費後 '+yen(q.net);
      baseline.textContent=base?(base.error?'準備なしでは受注条件を満たせません。':'準備なし・おまかせなら '+base.rework+'/10本を調整、'+base.seconds.toFixed(1)+'秒。'):'現在は準備なし・おまかせで見積もっています。';
    });
  };
  root.querySelectorAll('.shaft-desk select').forEach(el=>el.onchange=sync);
  find('shaftStart').onclick=()=>{if(find('shaftStart')?.isConnected)accept({...choice},seenQuote,shownNext);};
  sync();
}
