import * as M from './model.mjs?v=0.25';

export function layoutPlan(s,moves){
  if(!Array.isArray(moves)||moves.length>s.machines.length)return {error:'配置案を読み直してください'};
  const byId=new Map();
  for(const move of moves){
    if(!move||byId.has(move.id)||!s.machines.some(m=>m.id===move.id))return {error:'対象の設備が変わりました'};
    byId.set(move.id,move);
  }
  const changed=[];
  const machines=s.machines.map(m=>{
    const at=byId.get(m.id);
    if(!at||(at.x===m.x&&at.y===m.y))return m;
    const placed={...m,x:at.x,y:at.y};changed.push(placed);return placed;
  });
  const error=changed.length?M.floorIssue(s,machines,changed):null;
  return error?{error}:{machines,moves:changed.map(({id,x,y})=>({id,x,y}))};
}

// Every candidate is an alternative to the same anchored arrangement. Occupied
// cells swap both tools at once; neither tool needs a temporary empty bay.
export function layoutCandidate(s,anchor,id,cell){
  const base=layoutPlan(s,anchor);
  if(base.error)return base;
  const selected=base.machines.find(m=>m.id===id);
  if(!selected||!cell)return {error:'設備と床を選んでください'};
  const other=base.machines.find(m=>m.id!==id&&m.x===cell.x&&m.y===cell.y);
  const moves=anchor.filter(m=>m.id!==id&&m.id!==other?.id);
  moves.push({id,x:cell.x,y:cell.y});
  if(other)moves.push({id:other.id,x:selected.x,y:selected.y});
  const plan=layoutPlan(s,moves);
  if(!plan.error&&other)plan.swap=other.kind;
  return plan;
}

export function applyLayout(s,moves){
  const plan=layoutPlan(s,moves);
  if(plan.error)return plan.error;
  if(!plan.moves.length)return '変更した設備がありません';
  s.machines=plan.machines;
  M.note(s,plan.moves.length+'台の配置を確定');return null;
}

export function legalLayoutCells(s,anchor,id){
  const cells=[];
  for(let y=0;y<s.height-1;y++)for(let x=1;x<s.width;x++){
    const plan=layoutCandidate(s,anchor,id,{x,y});
    if(!plan.error)cells.push({x,y});
  }
  return cells;
}

export function movementReason(before,after){
  if(!before?.travel||!after?.travel)return '';
  const changes=Object.keys(before.travel).map(kind=>({kind,diff:Math.round(after.travel[kind])-Math.round(before.travel[kind])}))
    .sort((a,b)=>Math.abs(b.diff)-Math.abs(a.diff));
  const biggest=changes[0];
  if(!biggest||!biggest.diff)return '工程別の移動はほぼ同じ';
  return ({cut:'切断',drill:'穴あけ',inspect:'検品',lathe:'旋削'}[biggest.kind])+'担当の移動が'+Math.abs(biggest.diff)+'マス'+(biggest.diff<0?'減':'増');
}
