import * as M from './model.mjs?v=0.22';
import {layoutPlan,layoutCandidate,legalLayoutCells,movementReason} from './layout.mjs?v=0.22';
import {createEstimator} from './estimate-client.mjs?v=0.22';

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
  tools.hidden=false;picker.replaceChildren();
  for(const m of s.machines){
    const option=document.createElement('option');
    option.value=String(s.machines.indexOf(m));
    option.textContent=M.MACHINES[m.kind].name+(s.machines.some(other=>other.id!==m.id&&other.kind===m.kind)?'（'+cellName(m)+'）':'');
    option.selected=m.id===selected;picker.append(option);
  }
  const product=M.OFFERS.find(o=>o.id===offer),batch=product.qty+(product.product==='shaft'?'本':'個');
  const status=el('placeStatus'),estimate=el('layoutEstimate'),confirm=el('confirmPlace'),undo=el('layoutUndo');
  const canConfirm=()=>(moves.length>0||(p.trial&&picked))&&!invalid&&canWrite();
  function buttons(){
    confirm.disabled=!canConfirm();
    confirm.textContent=p.trial?(picked&&!moves.length?'現状で受注 · ¥':'この配置で受注 · ¥')+product.cost.toLocaleString('ja-JP'):p.estimateOffer?'配置を確定して見積へ':'配置を確定';
    undo.disabled=!history.length;
  }
  function drawPlan(){
    const draft=layoutPlan(s,moves);
    p.planMachines=draft.machines;p.draftMoves=moves;
    const m=p.planMachines.find(m=>m.id===selected);
    p.id=selected;p.kind=m.kind;p.candidate=m;p.route=null;p.legs=[];
    el('placeTitle').textContent=batch+'の配置案';
    buttons();
  }
  function measure(){
    const input=[{offer,layout:[],trace:true},{offer,layout:moves,trace:true}];
    estimate.hidden=false;estimate.classList.remove('empty-estimate');estimate.textContent='完成時間と職人の歩数を見積中…';
    preview.request(s,input,rows=>{
      const [before,after]=rows||[];
      if(!before||!after||before.error||after.error){estimate.textContent='この注文の見積を取得できません';return;}

      const role=movementReason(before,after);
      estimate.textContent=moves.length?'完成 '+time(before)+' → '+time(after)+' ／ 移動 '+steps(before)+' → '+steps(after)+'。'+role:
        '現状の'+batch+'　完成 '+time(before)+' ／ 総移動 '+steps(before);
      if(p.estimateOffer)estimate.textContent=(offer==='rush'?'短納期':'通常便')+batch+'　'+estimate.textContent+' ／ 納期'+Math.abs(after.margin).toFixed(1)+'秒'+(after.late?'超過':'余裕');
      p.legs=after.legs||[];
    });
  }
  function option(row,label){
    const button=document.createElement('button');button.type='button';
    const here=same(row,rankingResult.base);
    button.textContent=label+' · '+(here?'現在地':cellName(row))+'\n'+time(row.quote)+'／'+steps(row.quote);
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
      el('layoutCoverage').textContent='この設備の'+r.checked+'/'+r.legal+'か所を比較（現在地・入替含む）';
    });
  }
  function switchTool(id){
    selected=id;anchor=moves;invalid=false;picked=false;
    const cells=legalLayoutCells(s,anchor,id);
    onCells(cells);drawPlan();
    status.textContent='光る床に仮置き。設備のある床では2台を入替。線は先頭の1個の運搬経路。';
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
  picker.onchange=()=>switchTool(s.machines[Number(picker.value)].id);undo.onclick=back;
  switchTool(original.id);
  return {choose,canConfirm,suspend(){preview.cancel();ranking.cancel();},resume(){rank();measure();},get moves(){return moves;},close(){
    preview.cancel();ranking.cancel();tools.hidden=true;picker.onchange=null;undo.onclick=null;
    suggestions.replaceChildren();p.marks=[];p.legs=[];
  }};
}
