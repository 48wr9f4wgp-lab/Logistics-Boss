import {project} from './view.mjs';

// Authored sprite atlas: generated once, bundled locally, no runtime network service.
export const ATLAS_URL=new URL('./assets/machine-atlas.png',import.meta.url).href;
const sprites={
  cut:{crop:[65,28,570,660],width:1.95,height:2.1,name:'切断機',color:'#d2a23f'},
  drill:{crop:[775,25,375,678],width:1.30,height:2.35,name:'ボール盤',color:'#568c91'},
  lathe:{crop:[35,672,660,568],width:2.10,height:1.80,name:'旋盤',color:'#899267'},
  inspect:{crop:[730,700,515,540],width:1.95,height:1.85,name:'検品台',color:'#b6a27a'}
};
let atlas=null,workers=null,artTime=0,lastTime=null;
if(typeof Image!=='undefined'){atlas=new Image();atlas.src=ATLAS_URL;workers=new Image();workers.src=new URL('./assets/worker-atlas.png',import.meta.url).href;}
export function sceneViewport(width,height,s,{zoom=1,pan={x:0,y:0}}={}){
  const slope=.65,u=Math.min(width/(s.width+s.height+1.2),height/((s.width+s.height)*slope+4.6))*zoom;
  return {w:width,h:height,u,slope,ox:width*.5-(s.width-s.height)*u*.5+pan.x,oy:height*.52-(s.width+s.height)*u*slope*.44+pan.y};
}
export function machineSpriteBounds(v,m){const a=sprites[m.kind],p=project(v,m.x+.5,m.y+.5),w=a.width*v.u,h=a.height*v.u;return {x:p.x-w/2,y:p.y-h+v.u*.42,w,h};}
export function drawFactory(ctx,canvas,s,{zoom=1,pan={x:0,y:0},selected=null,placing=null,placementCells=[],time=0,animate=true}={}){
  const r=canvas.getBoundingClientRect(),dpr=Math.min(typeof devicePixelRatio==='number'?devicePixelRatio:1,2),W=r.width,H=r.height;
  if(canvas.width!==Math.round(W*dpr)||canvas.height!==Math.round(H*dpr)){canvas.width=Math.round(W*dpr);canvas.height=Math.round(H*dpr);}
  ctx.setTransform(dpr,0,0,dpr,0,0);
  if(animate&&lastTime!==null)artTime+=Math.max(0,Math.min(time-lastTime,100));lastTime=time;
  const t=artTime,v=sceneViewport(W,H,s,{zoom,pan}),u=v.u,p=(x,y,z=0)=>project(v,x,y,z),hits=[];
  const poly=(ps,fill,stroke=null,lineWidth=.65)=>{ctx.beginPath();ps.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));ctx.closePath();ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lineWidth;ctx.stroke();}};
  const tile=(x,y,w,d,z,fill,stroke)=>poly([p(x,y,z),p(x+w,y,z),p(x+w,y+d,z),p(x,y+d,z)],fill,stroke);
  const box=(x,y,w,d,h,front,top,side,z=0)=>{poly([p(x+w,y,z),p(x+w,y+d,z),p(x+w,y+d,z+h),p(x+w,y,z+h)],side);poly([p(x,y+d,z),p(x+w,y+d,z),p(x+w,y+d,z+h),p(x,y+d,z+h)],front);tile(x,y,w,d,z+h,top);};
  const line=(ps,color,width=1)=>{ctx.beginPath();ps.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.stroke();};
  const ellipse=(q,rx,ry,color)=>{ctx.beginPath();ctx.ellipse(q.x,q.y,rx,ry,0,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();};
  const label=(text,x,y,color='#e5dbc0',background='#19252aef',size=10)=>{ctx.font=`600 ${size}px system-ui`;ctx.textAlign='center';const w=ctx.measureText(text).width+13,h=size+10;ctx.fillStyle=background;ctx.beginPath();ctx.roundRect(x-w/2,y-h/2,w,h,5);ctx.fill();ctx.fillStyle=color;ctx.textBaseline='middle';ctx.fillText(text,x,y);ctx.textBaseline='alphabetic';return {x:x-w/2,y:y-h/2,w,h};};
  const bg=ctx.createLinearGradient(0,0,0,H);bg.addColorStop(0,'#34413f');bg.addColorStop(.7,'#24312f');bg.addColorStop(1,'#172328');ctx.fillStyle=bg;ctx.fillRect(0,0,W,H);
  // Soft ground shadow, plinth and street establish the miniature's scale.
  ellipse(p(s.width/2,s.height/2,-.45),u*(s.width+s.height)*.48,u*(s.width+s.height)*.25,'#07131665');
  box(-.6,-.6,s.width+1.2,s.height+2.1,.25,'#33413f','#53594c','#263a3b',-.5);
  tile(-.6,s.height+.35,s.width+1.2,1.1,-.23,'#293132');
  for(let x=0;x<s.width;x+=1.5)tile(x,s.height+.91,.7,.045,-.22,'#b7ae8c');
  box(0,0,s.width,s.height,.23,'#777b6b','#9b9a82','#5e675d',-.23);
  for(let x=0;x<s.width;x++)for(let y=0;y<s.height;y++){
    const n=((x*17+y*31)%7);tile(x,y,.995,.995,0,['#939686','#979a89','#a0a18f','#95988b','#9e9f8d','#a2a18e','#92968a'][n],'#747d705c');
    for(let k=0;k<3;k++){const q=p(x+.18+((x+y+k*3)%7)*.1,y+.2+k*.21,.002);ellipse(q,.4,.25,'#dcd6b83b');}
  }
  // Corrugated rear walls and sunlit windows remain beyond the usable grid.
  box(-.16,-.16,s.width+.16,.16,2.35,'#797e6f','#bec2a6','#4b5c57');
  box(-.16,0,.16,s.height,2.35,'#65746e','#a2aa90','#465957');
  for(let x=.2;x<s.width;x+=.45)line([p(x,-.02,.15),p(x,-.02,2.25)],'#434f4838',.7);
  for(let y=.2;y<s.height;y+=.45)line([p(-.015,y,.15),p(-.015,y,2.25)],'#bcc5a02b',.7);
  for(let x=.35;x<s.width-1;x+=2.2){
    const a=p(x,-.025,.95),b=p(x+1.6,-.025,.95),c=p(x+1.6,-.025,2.04),d=p(x,-.025,2.04);
    const g=ctx.createLinearGradient(d.x,d.y,b.x,b.y);g.addColorStop(0,'#f5e9bb');g.addColorStop(.55,'#c9d9c1');g.addColorStop(1,'#8fafa6');poly([a,b,c,d],g,'#384b48',Math.max(2,u*.07));
    line([p(x+.8,-.04,.98),p(x+.8,-.04,2.04)],'#617269',2);line([p(x,-.04,1.5),p(x+1.6,-.04,1.5)],'#617269',1.5);
    poly([p(x,.02,.02),p(x+1.65,.02,.02),p(x+3.3,3.5,.02),p(x+1.6,3.5,.02)],'#fff1b319');
  }
  for(let y=.6;y<s.height-1;y+=2.1){
    poly([p(-.025,y,1),p(-.025,y+1.5,1),p(-.025,y+1.5,2),p(-.025,y,2)],'#b2c6b0','#3c5350',2);
    line([p(-.035,y+.75,1),p(-.035,y+.75,2)],'#63766c',1.8);
  }
  for(let x=0;x<=s.width;x+=2.2)box(x,-.11,.11,.15,2.5,'#43534f','#9ba98c','#354643');
  for(let y=1;y<s.height;y+=2.1)box(-.12,y,.13,.13,2.5,'#465954','#9ba98c','#334846');
  line([p(0,-.04,.5),p(s.width,-.04,.5)],'#334746',u*.045);
  // Materials and outbound locations are reserved model cells, not decorative obstacles.
  const pallet=(x,y)=>{for(let k=0;k<3;k++)box(x+.04+k*.21,y+.03,.17,.73,.12,'#806043','#b39362','#6b5037');};
  pallet(.06,.05);for(let k=0;k<5;k++)box(.12,.1+k*.12,.6,.08,.18,'#6c7d7b','#d1d5c1','#455f62',.12);
  pallet(.07,s.height-.88);
  const finished=s.orders.reduce((n,o)=>n+(o.shipped?0:o.done),0);
  for(let k=0;k<Math.min(5,finished);k++)box(.15,s.height-.8,.5,.5,.055,'#89928b','#d2d5c4','#6f7a76',.12+k*.06);
  // Floor safety marks and sparse chips keep the room readable.
  line([p(.96,.1,.01),p(.96,s.height-.2,.01)],'#d7bb68',u*.045);
  line([p(1.05,s.height-.55,.01),p(s.width-.2,s.height-.55,.01)],'#dcc173',u*.045);
  if(placing&&!placing.draining)for(const cell of placementCells)tile(cell.x+.05,cell.y+.05,.9,.9,.025,'#e4d58543','#e7dca3');
  const chosen=s.machines.find(m=>m.id===selected);
  if(chosen&&!placing){
    const m=chosen;tile(m.x-.07,m.y-.07,1.14,1.14,.035,'#ffd27722','#ffdf8c');
    const w=s.workers.find(w=>w.job?.machine===m.id);
    if(w?.job.phase==='walk'){ctx.save();ctx.setLineDash([4,4]);line([{x:w.x,y:w.y},...w.job.path].map(q=>p(q.x+.45,q.y+.45,.04)),'#fff0ac',2);ctx.restore();}
  }
  function machine(m){
    const a=sprites[m.kind],r=machineSpriteBounds(v,m),worker=s.workers.find(w=>w.job?.machine===m.id),active=worker?.job.phase==='work';
    tile(m.x+.08,m.y+.08,.92,.86,.02,'#4356509f','#5f6e5b');ellipse(p(m.x+.6,m.y+.6,.01),u*.82,u*.37,'#192b3560');
    if(atlas?.complete&&atlas.naturalWidth){
      ctx.save();
      // Irregular trim excludes the neighbouring silhouette near the atlas row boundary.
      ctx.beginPath();ctx.rect(r.x,r.y,r.w,r.h);ctx.clip();
      if(m.kind==='cut'){const qx=r.x+(300-65)/570*r.w,qy=r.y+(670-28)/660*r.h;ctx.beginPath();ctx.moveTo(r.x,r.y);ctx.lineTo(r.x+r.w,r.y);ctx.lineTo(r.x+r.w,r.y+r.h);ctx.lineTo(qx,r.y+r.h);ctx.lineTo(qx,qy);ctx.lineTo(r.x,qy);ctx.closePath();ctx.clip();}
      if(m.kind==='lathe'){const qx=r.x+(300-35)/660*r.w,qy=r.y+(700-672)/568*r.h;ctx.beginPath();ctx.moveTo(r.x,r.y);ctx.lineTo(qx,r.y);ctx.lineTo(qx,qy);ctx.lineTo(r.x+r.w,qy);ctx.lineTo(r.x+r.w,r.y+r.h);ctx.lineTo(r.x,r.y+r.h);ctx.closePath();ctx.clip();}
      ctx.drawImage(atlas,...a.crop,r.x,r.y,r.w,r.h);ctx.restore();
    }else{
      box(m.x+.08,m.y+.1,.84,.76,.65,a.color,'#a7ad91','#344a48');
      box(m.x+.2,m.y+.2,.56,.5,.12,'#9daea8','#d4d7c4','#7c9189',.65);
      if(m.kind==='drill')box(m.x+.45,m.y+.15,.18,.2,1.4,'#507b7b','#a5b6a2','#345559',.2);
      if(m.kind==='lathe')box(m.x+.1,m.y+.18,.2,.6,.45,'#79866b','#bdc5a3','#4e6358',.65);
    }
    for(let i=1;i<m.level;i++)box(m.x+.12+i*.2,m.y+.82,.12,.07,.16,'#cc9b38','#ffe098','#987431',.1);
    // Effects describe only actual assigned work. Paused images retain the same phase.
    if(active){
      const q=p(m.x+.53,m.y+.7,.83);ellipse(q,u*.24,u*.12,'#ffd16b19');
      if(m.kind==='cut'||m.kind==='lathe')for(let k=0;k<5;k++){const phase=(t/140+k*.19)%1,angle=k*1.7;line([{x:q.x,y:q.y},{x:q.x+Math.cos(angle)*u*.35*phase,y:q.y+u*.4*phase}],phase<.75?'#f5d48c':'#c09552',1);}
      else if(m.kind==='drill')line([p(m.x+.53,m.y+.58,.83),p(m.x+.53,m.y+.58,.66+Math.sin(t/130)*.07)],'#d7dfce',1.5);
      else ellipse(p(m.x+.68,m.y+.25,1.05),u*.045,u*.045,'#c9ecc1');
    }
    const lp=p(m.x+.5,m.y+.45,.03),isSelected=m.id===selected;
    const text=isSelected?`${a.name} · Lv.${m.level}`:`${a.name} ${m.level>1?'Lv.'+m.level:''}`;
    const lb=label(text,lp.x,r.y-9,isSelected?'#ffdc8c':'#e8e2cc',isSelected?'#473b24f5':'#1b2a2de3',Math.max(9,Math.min(11,u*.38)));
    const hull=[{x:r.x+r.w*.2,y:r.y},{x:r.x+r.w*.8,y:r.y},{x:r.x+r.w,y:r.y+r.h*.25},{x:r.x+r.w,y:r.y+r.h*.85},{x:r.x+r.w*.5,y:r.y+r.h},{x:r.x,y:r.y+r.h*.8},{x:r.x,y:r.y+r.h*.25}];
    hits.push({id:m.id,hull,label:lb});
  }
  function worker(w){
    const q=p(w.x+.45,w.y+.45),walk=w.job?.phase==='walk',work=w.job?.phase==='work',phase=walk?Math.sin(t/110+w.id):0,lean=work?Math.sin(t/210+w.id)*.025:0;
    ellipse({x:q.x,y:q.y+u*.06},u*.17,u*.075,'#1d303366');
    if(workers?.complete&&workers.naturalWidth){
      const destination=w.job?.path?.[0],back=destination&&(destination.x-w.x+destination.y-w.y)<0;
      const crop=work?[835,640,290,600]:walk?[210,640,260,600]:back?[815,14,250,612]:[200,14,260,610];
      const h=u*1.5,ww=h*crop[2]/crop[3],bob=walk?Math.abs(phase)*u*.025:work?Math.sin(t/220)*u*.012:0;
      ctx.save();ctx.translate(q.x,q.y-bob+u*.04);if(back){ctx.scale(-1,1);}ctx.drawImage(workers,...crop,-ww*.5,-h,ww,h);ctx.restore();
      if(selected&&w.job?.machine===selected)label(w.name,q.x,q.y+u*.3,'#f5deb0','#263331de',9);
      return;
    }
    const torso=p(w.x+.45,w.y+.45,.51),head=p(w.x+.45+lean,w.y+.45,.83);
    line([{x:torso.x-u*.045,y:torso.y+u*.15},{x:q.x-u*.07+phase*u*.07,y:q.y-u*.03}], '#263a4c',u*.105);
    line([{x:torso.x+u*.06,y:torso.y+u*.15},{x:q.x+u*.08-phase*u*.07,y:q.y-u*.015}], '#1e3041',u*.105);
    line([{x:q.x-u*.1+phase*u*.07,y:q.y},{x:q.x-u*.01+phase*u*.07,y:q.y}], '#192323',u*.075);
    line([{x:q.x+u*.04-phase*u*.07,y:q.y+.02*u},{x:q.x+u*.15-phase*u*.07,y:q.y+.02*u}], '#152222',u*.075);
    ctx.fillStyle=['#3e586c','#455d6a','#385466'][w.id];ctx.beginPath();ctx.roundRect(torso.x-u*.13,torso.y-u*.15,u*.26,u*.37,u*.055);ctx.fill();
    line([{x:torso.x-u*.1,y:torso.y-u*.08},{x:torso.x-u*.17,y:torso.y+u*.12+phase*u*.04}], '#536e7c',u*.075);
    line([{x:torso.x+u*.1,y:torso.y-u*.08},{x:torso.x+u*.19,y:torso.y+u*.1-phase*u*.04}], '#2b4658',u*.075);
    ellipse({x:head.x,y:head.y+u*.045},u*.105,u*.12,'#d4b58d');
    ellipse(head,u*.12,u*.07,'#233d53');line([{x:head.x-u*.1,y:head.y+u*.025},{x:head.x+u*.14,y:head.y+u*.025}],'#365467',u*.04);
    if(walk)box(w.x+.49,w.y+.55,.23,.19,.12,'#89968e','#d1d8c8','#6a7c79',.43);
    if(selected&&w.job?.machine===selected)label(w.name,q.x,q.y+u*.3,'#f5deb0','#263331de',9);
  }
  // Interleave people and machines by their floor depth so crossing routes occlude correctly.
  const entities=[...s.machines.map(m=>({depth:m.x+m.y+.8,type:'machine',value:m})),...s.workers.map(w=>({depth:w.x+w.y+.9,type:'worker',value:w}))].sort((a,b)=>a.depth-b.depth);
  entities.forEach(e=>e.type==='machine'?machine(e.value):worker(e.value));
  // Front loading apron: understated crates rather than nonfunctional machinery.
  for(let k=0;k<3;k++)box(s.width-1.5+k*.3,s.height+.15,.26,.5,.24,'#9b7951','#c7a474','#775e41');
  const glow=ctx.createRadialGradient(W*.25,H*.14,0,W*.25,H*.14,W*.85);glow.addColorStop(0,'#ffe4a513');glow.addColorStop(1,'#ffe4a500');ctx.fillStyle=glow;ctx.fillRect(0,0,W,H);
  return {viewport:v,hitTargets:hits};
}
