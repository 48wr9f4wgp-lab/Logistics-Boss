import {OFFERS} from './model.mjs?v=0.22';
import {yenGain} from './pairing.mjs?v=0.22';
import {inquiryContext} from './inquiry.mjs?v=0.22';

const cash=value=>(value<0?'−':'')+'¥'+Math.round(Math.abs(value)).toLocaleString('ja-JP');
const diff=value=>(value<0?'':'+')+cash(value);
const margin=q=>Math.abs(q.margin).toFixed(1)+'秒'+(q.late?'超過':'余裕');

export function inquirySheet(s,canWrite){
  const ctx=inquiryContext(s);
  if(!ctx)return '<p>今の注文を工場で確認できます。</p>';
  const {primary,extra}=ctx,selected=extra?.pair.priority||'primary',half=Math.ceil(primary.qty/2);
  const options=['primary','extra'].map(priority=>`<label><input type="radio" name="shopPriority" value="${priority}" ${selected===priority?'checked':''}><span><strong>${priority==='primary'?'先約を優先':'小口を優先'}</strong><small data-impact="${priority}">見積中…</small></span></label>`).join('');
  return `<section class="inquiry-desk"><p>先約・${OFFERS.find(o=>o.id===primary.offerId).label} ${primary.done}/${primary.qty}${primary.product==='shaft'?'本':'個'}完成 · 小口は支給材の6個<br>小口の納期は引受から180秒。納期内の売上は¥1,000。</p>
    <div class="inquiry-base" id="inquirySolo">先約単独の見積中…</div>
    <fieldset id="inquiryPicker"><legend>次の空き工程をどちらに回す？</legend>${options}</fieldset>
    <button class="wide primary" id="inquiryConfirm" ${!canWrite?'disabled':''}>${extra?'この優先順で続ける':'6個を引き受ける · 材料費 ¥0'}</button>
    ${!extra?`<div class="inquiry-alternatives">${primary.done<half?`<button id="inquiryHold" ${!canWrite?'disabled':''}>先約${half}${primary.product==='shaft'?'本':'個'}まで進める</button>`:''}<button id="inquiryDecline" ${!canWrite?'disabled':''}>今回は見送る</button></div>`:''}
    <small class="inquiry-note">着手済みの作業と検品担当は維持します。見積は各注文を完成時に出荷した場合です。${!extra&&primary.done<half?'半数まで進めると相談に戻ります。賃金・納期も進みます。':''}</small></section>`;
}

export function bindInquiry(root,s,estimator,canWrite,decide,hold){
  const ctx=inquiryContext(s);
  if(!ctx){estimator.cancel();return;}
  const {primary,extra}=ctx,find=id=>root.querySelector('#'+id);
  const ids={primaryId:primary.id,extraId:extra?.id??null};
  let solo=extra?.pair.solo||null;
  function paintSolo(){
    find('inquirySolo').textContent=solo?'先約だけなら '+cash(solo.profit)+' · '+margin({margin:primary.due-solo.seconds,late:solo.late}):'先約単独の見積はありません';
  }
  if(extra)paintSolo();
  const scenarios=(extra?['primary','extra']:['solo','primary','extra']).map(priority=>({inquiry:{...ids,priority}}));
  estimator.request(s,scenarios,rows=>{
    if(!extra)solo=rows?.[0]?.primary??null;
    paintSolo();
    ['primary','extra'].forEach((key,i)=>{
      const el=root.querySelector('[data-impact="'+key+'"]'),q=rows?.[i+(extra?0:1)];
      if(!q?.extra){el.textContent=q?.error||'見積を表示できません';return;}
      const deadline=(name,r)=>{
        const span=document.createElement('span');span.className=r.late?'inquiry-late':'';
        span.textContent=name+' '+margin(r);return span;
      };
      el.replaceChildren(deadline('先約',q.primary),' ／ ',deadline('小口',q.extra),document.createElement('br'),
        '2件利益 '+cash(q.profit)+(solo?'（単独比 '+diff(yenGain(q.profit,solo.profit))+'）':''));
    });
  });
  find('inquiryConfirm').onclick=()=>{if(canWrite&&find('inquiryConfirm')?.isConnected)
    decide(ids,root.querySelector('input[name="shopPriority"]:checked').value,solo);};
  if(find('inquiryDecline'))find('inquiryDecline').onclick=()=>decide(ids,'decline',solo);
  if(find('inquiryHold'))find('inquiryHold').onclick=()=>hold(ids.primaryId,Math.ceil(primary.qty/2));
}
