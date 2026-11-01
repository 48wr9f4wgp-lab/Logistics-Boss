// An assignment and an optional investment belong to this shaft contract only.
// An unnamed inspector keeps the factory's normal scheduling rules.
import * as M from './model.mjs?v=0.25';

export function shaftEntryCost(s){
  const material=M.OFFERS.find(o=>o.id==='fine').cost;
  return material+(s.machines.some(m=>m.kind==='lathe')?0:M.MACHINES.lathe.cost);
}

export function installStarterLathe(s,cell){
  if(s.machines.some(m=>m.kind==='lathe'))return '旋盤は設置済みです';
  if(M.frontOrder(s))return '進行中の注文を出荷してから設置してください';
  if(s.cash<shaftEntryCost(s))return '旋盤と標準10本の材料費が必要です';
  return M.purchase(s,'lathe',cell.x,cell.y);
}

export function precisionPlan(s,{offer,inspector=null,investment='none',benchId=null}){
  const job=M.OFFERS.find(o=>o.id===offer&&o.product==='shaft');
  if(!job)return {error:'シャフトの注文を選んでください'};
  const worker=s.workers.find(w=>w.id===inspector);
  const bench=benchId===null?s.machines.find(m=>m.kind==='inspect'):s.machines.find(m=>m.kind==='inspect'&&m.id===benchId);
  let target=worker?.skill,cost=0,error=null;
  if(inspector!==null&&!worker)error='検品する職人を選んでください';
  else if(investment==='train'){
    if(!worker)error='研修を受ける職人を選んでください';
    else if(worker.skill===4)error='この職人は最高技能です';
    else{
      target=Math.max(worker.skill+1,offer==='master'?3:1);
      for(let i=worker.skill;i<target;i++)cost+=800*i;
    }
  }else if(investment==='bench'){
    if(!bench||bench.level>=3)error='改良できる検品台を選んでください';
    else cost=1500*bench.level;
  }else if(investment!=='none')error='準備方法を選んでください';
  const total=cost+job.cost;
  if(!error){
    if(!s.machines.some(m=>m.kind==='lathe'))error='旋盤を設置してください';
    else if(s.orders.filter(o=>!o.shipped).length>=2)error='進行中の注文は2件までです';
    else if(offer==='master'&&!s.workers.some(w=>(w===worker?target:w.skill)>=3))error='技能3の職人が必要です。職人を選んで研修するか、標準品で経験を積めます';
    else if(s.cash<total)error='材料と準備費まであと ¥'+Math.ceil(total-s.cash).toLocaleString('ja-JP');
  }
  return {job,worker,bench,target,cost,total,error};
}

export function acceptPrecision(s,choice,quote,expectedNext=s.next){
  if(s.next!==expectedNext)return '受注状況が変わりました。見積を開き直してください';
  const plan=precisionPlan(s,choice);
  if(plan.error)return plan.error;
  const copy=structuredClone(s);
  if(choice.investment==='train'){
    for(let level=plan.worker.skill;level<plan.target;level++){
      const error=M.train(copy,plan.worker.id);if(error)return error;
    }
  }else if(choice.investment==='bench'){
    const error=M.upgrade(copy,plan.bench.id);if(error)return error;
  }
  const error=M.accept(copy,plan.job.id,quote);
  if(error)return error;
  const order=copy.orders.at(-1);
  if(plan.worker)order.inspectorId=plan.worker.id;
  order.qualitySpend=plan.cost;
  order.accounting.growth=[];
  Object.assign(s,copy);
  return null;
}
