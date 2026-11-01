import {BRIEFS,briefOutcomeText,earnedBriefs} from './brief.mjs?v=0.23';
import * as M from './model.mjs?v=0.23';
import {layoutPlan,layoutCandidate,legalLayoutCells,movementReason} from './layout.mjs?v=0.23';
import {createEstimator} from './estimate-client.mjs?v=0.23';

const el=id=>document.getElementById(id);
const cellName=({x,y})=>(x+1)+'列'+(y+1)+'段';
const same=(a,b)=>a.x===b.x&&a.y===b.y;
const time=q=>q.seconds.toFixed(1)+'秒';
const steps=q=>Math.round(q.walk)+'マス';

// A user's tap freely changes the draft. Candidate buttons use the same tap
// path and never modify a different machine choice or commit anything.
export function layoutEditor(s,p,offer,canWrite,onCells){
  const ranking=createEstimator(),preview=createEstimator(),history=[];
  const tools=el('layoutTools'),picker=el('layoutMachine'),suggestions=el('layoutSuggestions');
  let anchor=[],moves=[],selected=p.id,invalid=false,picked=false,rankingResult=null;
  const original=s.machines.find(m=>m.id===selected);
  const brief=el('layoutBrief'),briefField=el('layoutBriefField'),forecast=el('layoutBriefForecast');
  // Undefined is a pending estimate; null indicates the worker was unavailable.
  let measured,explicitBrief=false;
  briefField.hidden=forecast.hidden=!p.trial;
  if(p.trial){
    brief.replaceChildren(new Option('追加条件なし（通常報酬）',''));
    const earned=earnedBriefs(s);
    for(const [id,condition] of Object.entries(BRIEFS)){
      const label=condition.label+' '+condition.limit+condition.unit+' +¥'+condition.bonus;
      brief.add(new Option(earned.includes(id)?label+' 済':label,id));
    }
    brief.value=p.briefId||'';
    p.briefId=brief.value||null;
    explicitBrief=!!p.briefId;
  }
  tools.hidden=false;picker.replaceChildren();
  for(const m of s.machines){
    const option=document.createElement('option');
    option.value=String(s.machines.indexOf(m));
    option.selected=m.id===selected;picker.append(option);
  }
  const product=M.OFFERS.find(o=>o.id===offer),batch=product.qty+(product.product==='shaft'?'本':'個');
  const status=el('placeStatus'),estimate=el('layoutEstimate'),confirm=el('confirmPlace'),undo=el('layoutUndo');
  const canConfirm=()=>(moves.length>0||(!!p.trial&&(picked||explicitBrief)))&&!invalid&&canWrite();
  function showForecast(){
    if(!p.trial)return;
    if(!p.briefId){forecast.textContent='条件達成で＋¥'+BRIEFS.speed.bonus+'。未達でも通常報酬。';return;}
    forecast.textContent=measured===undefined?'この配置で追加条件を達成できるか見積中…':
      measured===null?'見積なし · 追加条件は出荷時に判定します。':
      briefOutcomeText(p.briefId,measured,true);
  }
  function buttons(){
    confirm.disabled=!canConfirm();
    confirm.textContent=p.trial?((picked||explicitBrief)&&!moves.length?'現状で受注 · ¥':'この配置で受注 · ¥')+product.cost.toLocaleString('ja-JP'):p.estimateOffer?'配置を確定して見積へ':'配置を確定';
    undo.disabled=!history.length;
  }
  function drawPlan(){
    const draft=layoutPlan(s,moves);
    p.planMachines=draft.machines;p.draftMoves=moves;
    const m=p.planMachines.find(m=>m.id===selected);
    p.id=selected;p.kind=m.kind;p.candidate=m;p.route=null;p.legs=[];
    p.planMachines.forEach((tool,i)=>{
      const label=M.MACHINES[tool.kind].name;
      picker.options[i].textContent=p.planMachines.some(other=>other.id!==tool.id&&other.kind===tool.kind)?label+'（'+cellName(tool)+'）':label;
    });
    for(const b of suggestions.children)b.setAttribute('aria-pressed',String(+b.dataset.x===m.x&&+b.dataset.y===m.y));
    el('placeTitle').textContent=batch+'の配置案';
    buttons();
  }
  function measure(){
    measured=undefined;showForecast();
    const input=[{offer,layout:[],trace:true}];
    if(moves.length)input.push({offer,layout:moves,trace:true});
    estimate.hidden=false;estimate.classList.remove('empty-estimate');estimate.textContent='完成時間と職人の歩数を見積中…';
    preview.request(s,input,rows=>{
      const before=rows?.[0],after=moves.length?rows?.[1]:before;
      measured=before&&!before.error&&after&&!after.error?after:null;showForecast();
      if(!before||!after||before.error||after.error){estimate.textContent=after?.error||before?.error||'この注文の見積を取得できません';return;}

      const term=p.estimateOffer?(offer==='rush'?'短納期':'通常便')+batch+'　':'';
      const deadline=p.estimateOffer?'納期'+Math.abs(after.margin).toFixed(1)+'秒'+(after.late?'超過':'余裕'):'';
      const lines=moves.length?[
        term+'完成　'+time(before)+' → '+time(after),
        '総移動　'+steps(before)+' → '+steps(after),
        [movementReason(before,after),deadline].filter(Boolean).join(' ／ ')
      ]:[term+'現状の完成　'+time(before),'総移動　'+steps(before),deadline];
      estimate.textContent=lines.filter(Boolean).join('\n');
      p.legs=after.legs||[];
    });
  }
  function option(row,label){
    const button=document.createElement('button');button.type='button';
    const here=same(row,rankingResult.base);
    const heading=document.createElement('span'),goal=document.createElement('span'),location=document.createElement('small'),value=document.createElement('strong');
    heading.className='candidate-heading';goal.textContent=label;location.textContent=here?'現在地':cellName(row);
    value.textContent=time(row.quote)+'／'+steps(row.quote);
    heading.append(goal,location);button.append(heading,value);
    button.dataset.x=row.x;button.dataset.y=row.y;
    button.setAttribute('aria-pressed',String(same(row,p.candidate)));
    button.onclick=()=>choose(row);suggestions.append(button);
  }
  function rank(){
    ranking.cancel();rankingResult=null;p.marks=[];
    suggestions.replaceChildren();el('layoutCoverage').textContent='置ける床を同じ条件で試算中…';
    ranking.request(s,[{rankLayout:{id:selected,offer,anchor}}],rows=>{
      const r=rows?.[0];if(!r||r.error){el('layoutCoverage').textContent='候補の比較は利用できません。光る床を直接選べます。';return;}
      rankingResult=r;
      const one=same(r.fastest,r.shortest);
      option(r.fastest,one?'◎ 速さ・歩数とも最良':'速 完成が最短');
      if(!one)option(r.shortest,'歩 歩数が最少');
      p.marks=one?[{...r.fastest,mark:'◎'}]:[{...r.fastest,mark:'速'},{...r.shortest,mark:'歩'}];
      el('layoutCoverage').textContent=(r.checked===r.legal?'置ける'+r.legal+'か所を比較済み':'見積できた'+r.checked+'／'+r.legal+'か所で比較')+'（現在地・入替含む）';
    });
  }
  function switchTool(id){
    selected=id;anchor=moves;invalid=false;picked=false;
    const cells=legalLayoutCells(s,anchor,id);
    onCells(cells);drawPlan();
    status.textContent=p.trial&&p.briefId?'今の配置でも受注できます。ほかの床や追加条件も試せます。':
      '光る床に仮置き。設備のある床では2台を入替。線は先頭の1個の運搬経路。';
    measure();rank();
  }
  function choose(cell){
    const next=layoutCandidate(s,anchor,selected,cell);
    if(next.error){
      invalid=true;status.textContent=next.error+'。案は保持しています。';buttons();return;
    }
    invalid=false;picked=true;
    const differs=JSON.stringify(next.moves)!==JSON.stringify(moves);
    if(differs)history.push(moves);
    moves=next.moves;drawPlan();
    status.textContent=cellName(cell)+(next.swap?' · '+M.MACHINES[next.swap].name+'と入替':'に仮置き')+' ／ 変更'+moves.length+'台';
    measure();
  }
  function back(){
    if(!history.length)return;
    moves=history.pop();switchTool(selected);status.textContent='直前の変更を戻しました ／ 変更'+moves.length+'台';
  }
  if(p.trial)brief.onchange=()=>{
    p.briefId=brief.value||null;explicitBrief=!!p.briefId;
    if(!invalid&&!moves.length)status.textContent=explicitBrief?'今の配置で受注するか、床を選んで仮案を試せます。':'光る床を選んで仮案を試せます。';
    showForecast();buttons();
  };
  picker.onchange=()=>switchTool(s.machines[Number(picker.value)].id);undo.onclick=back;
  switchTool(original.id);
  return {choose,canConfirm,suspend(){preview.cancel();ranking.cancel();},resume(){rank();measure();},get moves(){return moves;},close(){
    preview.cancel();ranking.cancel();tools.hidden=true;picker.onchange=null;undo.onclick=null;
    briefField.hidden=forecast.hidden=true;brief.onchange=null;forecast.textContent='';
    suggestions.replaceChildren();p.marks=[];p.legs=[];
  }};
}
