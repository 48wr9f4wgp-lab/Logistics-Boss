import * as M from './model.mjs';

// Guidance describes existing state. It never accepts work, spends money or adds save fields.
const money=value=>'¥'+Math.ceil(value).toLocaleString('ja-JP');
const panel=(name,label)=>({type:'panel',panel:name,label});
const growth=(id,label)=>({type:'growth',id,label});

export function openingOffer(s) {
  if(s.delivered!==0||M.frontOrder(s))return null;
  const first=M.OFFERS.find(o=>o.id==='first');
  if(M.offerStatus(s,first.id).available)return first;
  const relief=M.OFFERS.find(o=>o.id==='relief');
  return s.cash<first.cost&&M.offerStatus(s,relief.id).available?relief:null;
}

export function deliveryGuide(s,report=s.results?.[0]) {
  if(!report)return null;
  const offer=M.OFFERS.find(o=>o.id===report.offerId);
  const isGrowth=!!offer?.growth;
  const summary={
    heading:isGrowth?'成長案件を納品！':s.delivered===1?'はじめての出荷完了！':'出荷完了！',
    status:report.late?'納期超過 · 報酬15%減':'納期内に納品',
    tone:report.late?'late':'success'
  };

  // A remaining commitment always comes before another order or an investment suggestion.
  const active=M.frontOrder(s);
  if(active){
    if(active.done===active.qty)return {
      ...summary,title:'もう1件、出荷できます',
      body:`「${active.label}」${active.qty}個が完成しています。出荷して代金を受け取ろう。`,
      primary:{type:'ship',id:active.id,label:'もう1件を出荷する'}
    };
    return {
      ...summary,title:'残りの注文を仕上げよう',
      body:`「${active.label}」は${active.done} / ${active.qty}個が完成。完成まで進めると、人件費・納期も進みます。`,
      primary:{type:'skip',id:active.id,label:'残りを完成まで進める'}
    };
  }

  if(isGrowth){
    if(report.late)return {
      ...summary,title:'次は、納期内の出荷を目指そう',
      body:'設備の加工時間や配置を見直して、次の注文に備えよう。受注条件の達成だけでは納期は保証されません。',
      primary:panel('machines','設備・動線を見直す'),
      secondary:growth(offer.id,'同じ案件に再挑戦')
    };
    return {
      ...summary,title:'工場の次の成長を考えよう',
      body:'同じ案件で効率を伸ばすことも、別の成長案件に挑むこともできます。',
      primary:panel('growth','次の成長目標を選ぶ'),
      secondary:growth(offer.id,'同じ案件をもう一度')
    };
  }

  const plan=M.growthPlan(s,s.goalOffer);
  if(plan){
    if(plan.phase==='funds')return {
      ...summary,title:`「${plan.offer.label}」に向けて資金を準備`,
      body:`残りの準備費 ${money(plan.investment)}＋材料費 ${money(plan.offer.cost)}。あと ${money(plan.shortage)} でそろいます。人件費は別に必要です。`,
      primary:panel('orders','資金を作る注文へ'),
      secondary:growth(plan.offer.id,'準備費を確認')
    };
    return {
      ...summary,
      title:plan.phase==='ready'?`「${plan.offer.label}」を受注できる`:`次は${plan.next.label}`,
      body:plan.phase==='ready'
        ?`受注条件を満たしています。材料費は ${money(plan.offer.cost)}。計画で確認してから受注できます。`
        :`残りの準備費 ${money(plan.investment)}＋材料費 ${money(plan.offer.cost)} を確保できます。投資の内容と費用を計画で確認しよう。人件費は別に必要です。`,
      primary:growth(plan.offer.id,'目標への次の一手を見る')
    };
  }

  return {
    ...summary,title:'次は、工場の成長目標を選ぼう',
    body:'設備や職人を育てて、次の仕事へ。必要な投資と材料費を比べて目標を選べます。',
    primary:panel('growth','次の成長目標を選ぶ'),
    secondary:panel('orders','通常の注文を続ける')
  };
}
