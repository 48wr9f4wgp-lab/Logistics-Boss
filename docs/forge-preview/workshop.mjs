import {project, machineHull} from './view.mjs?v=0.9';

// Original, dependency-free workshop art. This layer only reads simulation state.
// The static building is cached; all moving objects share one depth-sorted pass.
const caches = new WeakMap();
const TAU = Math.PI * 2;
const names = {cut:'切断機', drill:'ボール盤', lathe:'旋盤', inspect:'検品台'};
const noise = n => { const f=Math.sin(n*127.1+311.7)*43758.5453; return f-Math.floor(f); };

// The remaining path consists of worker -> pickup -> service. The pickup cell is
// removed when reached, and a shortest pickup -> service path cannot revisit it.
// Derive the picture from those existing facts; do not add state to saved jobs.
export function workerVisualState(state,worker) {
  const idle={phase:'idle',part:null,machine:null},job=worker?.job;
  if(!job||!['walk','work'].includes(job.phase)||!Array.isArray(job.path))return idle;
  const part=state.parts?.find(p=>p.id===job.part);
  const machine=state.machines?.find(m=>m.id===job.machine);
  if(!part||!machine)return idle;
  const phase=job.phase==='work'?'work':job.path.some(p=>p.x===part.x&&p.y===part.y)?'pickup':'carry';
  return {phase,part,machine};
}

function painter(ctx, v) {
  const p=(x,y,z=0)=>project(v,x,y,z);
  function poly(points, fill, stroke=null, width=.6) {
    ctx.beginPath();
    points.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));
    ctx.closePath();
    if(fill){ctx.fillStyle=fill;ctx.fill();}
    if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=width;ctx.stroke();}
  }
  function face(coords, fill, stroke=null, width=.6) {
    poly(coords.map(q=>p(...q)),fill,stroke,width);
  }
  function line(coords, color, width=1, dash=[]) {
    ctx.beginPath();
    coords.forEach((q,i)=>{const a=p(...q);i?ctx.lineTo(a.x,a.y):ctx.moveTo(a.x,a.y);});
    ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';
    ctx.setLineDash(dash);ctx.stroke();ctx.setLineDash([]);
  }
  function box(x,y,w,d,h,front,top,side,z=0,edge=null) {
    face([[x,y+d,z],[x+w,y+d,z],[x+w,y+d,z+h],[x,y+d,z+h]],front,edge);
    face([[x+w,y,z],[x+w,y+d,z],[x+w,y+d,z+h],[x+w,y,z+h]],side,edge);
    face([[x,y,z+h],[x+w,y,z+h],[x+w,y+d,z+h],[x,y+d,z+h]],top,edge);
  }
  function disk(x,y,z,r,plane,fill,stroke=null,angle=0,spokes=0) {
    const pts=[];
    for(let i=0;i<32;i++){
      const a=i*TAU/32,ca=Math.cos(a)*r,sa=Math.sin(a)*r;
      pts.push(p(x+(plane==='yz'?0:ca),y+(plane==='xz'?0:plane==='xy'?sa:ca),z+(plane==='xy'?0:sa)));
    }
    poly(pts,fill,stroke,Math.max(.6,v.u*.022));
    if(spokes){
      for(let i=0;i<spokes;i++){
        const a=angle+i*TAU/spokes,ca=Math.cos(a)*r*.8,sa=Math.sin(a)*r*.8;
        line([[x,y,z],[x+(plane==='yz'?0:ca),y+(plane==='xz'?0:plane==='xy'?sa:ca),z+(plane==='xy'?0:sa)]],stroke||'#ced4cf',Math.max(.7,v.u*.025));
      }
    }
  }
  function shadow(x,y,w,d,alpha=.18) {
    // Broad cast shadow, a smaller darker contact, and a narrow lit-side edge.
    face([[x-.07,y+.03,.004],[x+w+.26,y+.06,.004],[x+w+.42,y+d+.27,.004],[x+.12,y+d+.29,.004]],'rgba(21,42,33,'+(alpha*.65)+')');
    face([[x-.02,y+.04,.005],[x+w+.17,y+.06,.005],[x+w+.26,y+d+.18,.005],[x+.12,y+d+.19,.005]],'rgba(12,28,23,'+(alpha*.75)+')');
    face([[x+.04,y+.05,.006],[x+w+.04,y+.05,.006],[x+w+.08,y+d+.07,.006],[x+.04,y+d+.07,.006]],'rgba(9,24,20,'+(alpha*.7)+')');
    const a=p(x+w*.5,y+d*.5,.008);
    ctx.fillStyle='rgba(9,23,22,'+(alpha*.45)+')';
    ctx.beginPath();ctx.ellipse(a.x,a.y,v.u*w*.73,v.u*d*.35,0,0,TAU);ctx.fill();
  }
  function dot(x,y,z,r,fill,stroke=null) {
    const q=p(x,y,z);ctx.beginPath();ctx.arc(q.x,q.y,r*v.u,0,TAU);
    ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=.7;ctx.stroke();}
  }
  return {ctx,v,p,poly,face,line,box,disk,shadow,dot};
}

function pallet(g,x,y,w=.82,d=.64,z=0) {
  const {box}=g;
  box(x,y,w,.12,.1,'#77563b','#b08959','#624833',z);
  box(x,y+d-.12,w,.12,.1,'#77563b','#aa8355','#624833',z);
  for(let n=0;n<4;n++)box(x,y+n*d/4,w,d/4-.025,.055,'#8c6b45','#bc9865','#6a5139',z+.1);
}

function floorPaint(g,s) {
  const {v,p,poly,face,line,box}=g,{width:w,height:h}=s,ctx=g.ctx;
  const bg=ctx.createLinearGradient(0,0,0,v.h);
  bg.addColorStop(0,'#30443f');bg.addColorStop(.56,'#283a36');bg.addColorStop(1,'#1b2b2b');
  ctx.fillStyle=bg;ctx.fillRect(0,0,v.w,v.h);
  const halo=ctx.createRadialGradient(v.w*.36,v.h*.34,5,v.w*.47,v.h*.5,Math.max(v.w,v.h)*.65);
  halo.addColorStop(0,'#9caf7f22');halo.addColorStop(1,'#17262500');
  ctx.fillStyle=halo;ctx.fillRect(0,0,v.w,v.h);
  const middle=p(w*.5,h*.5);
  ctx.save();ctx.filter='blur(12px)';ctx.fillStyle='#0d191b88';
  ctx.beginPath();ctx.ellipse(middle.x+5,middle.y+v.u*1.1,v.u*(w+h)*.48,v.u*(w+h)*.24,0,0,TAU);ctx.fill();ctx.restore();
  box(-.9,-.55,w+1.7,h+2.65,.13,'#293c35','#4c5a4c','#25372f',-.25);
  box(-.8,h+.32,w+1.45,1.53,.035,'#2a3632','#35413b','#2d3933',-.1);
  // Road seams and painted loading bays.
  for(let x=-.2;x<w+.2;x+=1.65)face([[x,h+1.52,-.055],[x+.8,h+1.52,-.055],[x+.8,h+1.56,-.055],[x,h+1.56,-.055]],'#d5c69488');
  line([[-.65,h+.4,-.052],[w+.53,h+.4,-.052]],'#b9c4a52b',.7);
  box(-.13,-.13,w+.26,h+.26,.25,'#75816c','#929a82','#56644f',-.25);
  // Warm concrete, subdued joints rather than a checkerboard.
  const colors=['#afb29a','#b0b29b','#adb09a','#acaf98','#b2b49d'];
  for(let x=0;x<w;x++)for(let y=0;y<h;y++){
    face([[x,y,0],[x+1,y,0],[x+1,y+1,0],[x,y+1,0]],colors[Math.floor(noise(x*93+y)*colors.length)]);
    line([[x,y+.995,.002],[x+.995,y+.995,.002],[x+.995,y,.002]],'#77857550',.55);
  }
  // Deterministic fine aggregate, cached and clipped to the usable slab.
  ctx.save();
  const slab=[p(0,0),p(w,0),p(w,h),p(0,h)];
  ctx.beginPath();slab.forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));ctx.closePath();ctx.clip();
  for(let i=0;i<720;i++){
    const q=p(noise(i+4)*w,noise(i+804)*h);
    ctx.fillStyle=i%3?'#3f58431c':'#f3ecd427';ctx.fillRect(q.x,q.y,noise(i+9)*1.6+.3,.6);
  }
  for(let n=0;n<8;n++){
    const q=p(1+noise(n+41)*(w-1.7),.5+noise(n+742)*(h-1));
    ctx.fillStyle='#344d3a0a';ctx.beginPath();ctx.ellipse(q.x,q.y,v.u*(.12+noise(n)*.23),v.u*.075,-.4,0,TAU);ctx.fill();
  }
  const warm=p(0,0),cool=p(w,h);
  const ambient=ctx.createLinearGradient(warm.x,warm.y,cool.x,cool.y);
  ambient.addColorStop(0,'#fff0c51b');ambient.addColorStop(.5,'#d5ddba00');ambient.addColorStop(1,'#224e451b');
  ctx.fillStyle=ambient;ctx.fillRect(0,0,v.w,v.h);
  ctx.restore();
  // Wall contacts have a broad falloff; empty floor stays fully usable.
  face([[0,0,.003],[w,0,.003],[w,.16,.003],[0,.16,.003]],'#294a3e23');
  face([[0,.16,.003],[w,.16,.003],[w,.36,.003],[0,.36,.003]],'#294a3e0e');
  face([[0,0,.004],[.15,0,.004],[.15,h,.004],[0,h,.004]],'#294a3e25');
  face([[.15,0,.004],[.32,0,.004],[.32,h,.004],[.15,h,.004]],'#294a3e0e');
  // Service aisle: only this existing free edge is marked.
  for(let y=.18;y<h-.1;y+=.72)face([[.87,y,.004],[.91,y,.004],[.91,y+.39,.004],[.87,y+.39,.004]],'#ddbb61aa');
  line([[0,h-.02,.01],[w,h-.02,.01]],'#dbc577',Math.max(1,v.u*.045));
  for(let x=0;x<w;x+=.48){
    face([[x,h-.17,.012],[x+.11,h-.17,.012],[x+.25,h-.025,.012],[x+.14,h-.025,.012]],'#4d594755');
  }
}

function building(g,s) {
  const {v,p,face,line,box,disk,dot}=g,{width:w,height:h}=s,ctx=g.ctx;
  // Corrugated rear wall, a low return wall, and exposed steel frame.
  box(-.13,-.2,w+.26,.2,1.8,'#d2d0b5','#e5dfc3','#8a9781',0);
  box(-.13,-.005,w+.26,.035,.42,'#607d70','#779583','#425f54',0);
  for(let x=.04;x<w;x+=.14)line([[x,-.001,.44],[x,-.001,1.74]],'#828e713d',.7);
  line([[0,.032,.45],[w,.032,.45]],'#e1d8b2',.9);
  box(-.17,0,.17,h,.5,'#758974','#a6b095','#536f60',0);
  box(-.2,0,.2,Math.min(h,3.2),1.65,'#b8c2a5','#d9d9ba','#6b8973',0);
  // Tall rear windows and the angled, translucent left window.
  for(let x=.38;x<w-.6;x+=2.1){
    const ww=Math.min(1.48,w-x-.32);
    face([[x,.014,.73],[x+ww,.014,.73],[x+ww,.014,1.48],[x,.014,1.48]],'#54756a','#546f63',1.8);
    face([[x+.035,.018,.79],[x+ww-.035,.018,.79],[x+ww-.035,.018,1.44],[x+.035,.018,1.44]],'#adc6aa');
    face([[x+.06,.02,1.03],[x+ww-.05,.02,.83],[x+ww-.05,.02,1.43],[x+.06,.02,1.43]],'#d7d9b984');
    line([[x+ww*.5,.028,.76],[x+ww*.5,.028,1.45]],'#536f5c',Math.max(1,v.u*.043));
    line([[x,.028,1.1],[x+ww,.028,1.1]],'#66826c',Math.max(.8,v.u*.035));
    box(x-.025,.02,ww+.05,.11,.045,'#788c72','#e2dcbb','#62795f',.7);
  }
  face([[.012,.46,.73],[.012,2.58,.73],[.012,2.58,1.37],[.012,.46,1.37]],'#648477','#5b7667',1.5);
  face([[.018,.5,.79],[.018,2.54,.79],[.018,2.54,1.32],[.018,.5,1.32]],'#a8c1a2');
  for(let y=.51;y<2.6;y+=.67)line([[.027,y,.75],[.027,y,1.34]],'#617b66',Math.max(1,v.u*.035));
  line([[.027,.5,1.04],[.027,2.54,1.04]],'#6b896f',1);
  for(let x=0;x<w+.1;x+=2){
    box(x-.045,-.015,.09,.085,1.86,'#4f6859','#b5b794','#374e41',0);
    box(x-.07,-.025,.14,.11,.06,'#506951','#bfbd96','#354936',1.79);
  }
  box(-.15,-.11,w+.3,.16,.11,'#60725b','#c3c4a1','#3e5746',1.79);
  // Wall-mounted conduit, switch box and industrial clock.
  line([[.2,.07,.59],[w-.3,.07,.59],[w-.3,.07,.22]],'#425b4a',Math.max(1,v.u*.037));
  box(w-.82,.06,.37,.11,.36,'#80917b','#aeb49a','#5a735f',.64);
  for(let n=0;n<3;n++)line([[w-.77,.181,.73+n*.06],[w-.53,.181,.73+n*.06]],'#4c6652',.65);
  dot(w-.49,.182,.69,.026,'#b8693e');
  disk(w-1.1,.06,1.55,.13,'xz','#ebdfb9','#5c7058');
  line([[w-1.1,.067,1.55],[w-1.1,.067,1.63]],'#53614c',.8);
  line([[w-1.1,.067,1.55],[w-1.025,.067,1.51]],'#53614c',.8);
  // Fixed afternoon light. Broad panes and mullion shadows read at phone scale;
  // there is no invented day/night clock or moving atmosphere.
  ctx.save();ctx.beginPath();
  [p(0,0),p(w,0),p(w,h),p(0,h)].forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));
  ctx.closePath();ctx.clip();
  for(let x=.43;x<w-1.1;x+=2.1){
    face([[x-.05,.16,.006],[x+1.43,.16,.006],[x+2.18,2.64,.006],[x+.76,2.64,.006]],'#fff0ba13');
    face([[x,.2,.007],[x+1.38,.2,.007],[x+2.12,2.55,.007],[x+.82,2.55,.007]],'#fff0bc35');
    face([[x+.64,.2,.009],[x+.74,.2,.009],[x+1.48,2.55,.009],[x+1.38,2.55,.009]],'#46694b25');
    face([[x+.38,1.28,.009],[x+1.73,1.28,.009],[x+1.77,1.4,.009],[x+.42,1.4,.009]],'#46694b20');
  }
  ctx.restore();
  // A wall sign is part of the building, never a floating interface label.
  const a=p(w*.51,.09,1.9);
  ctx.save();ctx.translate(a.x,a.y);ctx.transform(.89,.445,0,1,0,0);
  ctx.fillStyle='#233e33';ctx.fillRect(-v.u*1.05,-v.u*.32,v.u*2.1,v.u*.4);
  ctx.strokeStyle='#a6b18a';ctx.lineWidth=.65;ctx.strokeRect(-v.u*1.05,-v.u*.32,v.u*2.1,v.u*.4);
  ctx.fillStyle='#f3dfad';ctx.font='700 '+Math.max(6,v.u*.25)+'px system-ui';ctx.textAlign='center';
  ctx.fillText('マチコバ！',0,-v.u*.055,v.u*1.9);ctx.restore();
}

function exterior(g,s) {
  const {box,line,disk,shadow,dot,face}=g,{width:w,height:h}=s;
  // Every decorative object is outside the placeable machine cells.
  shadow(-.87,3.7,.58,1.4,.16);
  box(-.81,3.7,.55,1.25,.95,'#455e4e','#799077','#304b3d',0);
  for(let z=.08;z<.91;z+=.18){
    face([[-.79,4.965,z],[-.28,4.965,z],[-.28,4.965,z+.13],[-.79,4.965,z+.13]],'#6a8369','#3b5644',.7);
    line([[-.65,4.976,z+.07],[-.43,4.976,z+.07]],'#c5c5a0',1.2);
  }
  box(-.76,3.85,.42,.24,.09,'#a3764c','#d2b27b','#82603f',.96);
  line([[-.72,4.2,1],[-.36,4.4,1]],'#d5d6b8',1.7);
  // Small service cart beyond the rear right corner.
  shadow(w+.16,.1,.39,1.0,.14);
  for(const yy of [.15,.85])for(const xx of [w+.2,w+.58])box(xx,yy,.045,.045,.8,'#596c55','#a6b18c','#43543e',0);
  for(const z of [.1,.48,.84])box(w+.15,.1,.5,.9,.05,'#6a795d','#a0a78a','#4d6249',z);
  for(let n=0;n<3;n++)box(w+.2,.2+n*.23,.35,.15,.22,'#947746','#bfa174','#76623d',.53);
  // A plant and a hose reel add scale without obstructing the production floor.
  box(-.67,-.38,.3,.3,.32,'#956c45','#b58e5d','#735033',0);
  for(let n=0;n<7;n++){
    const yy=-.24+Math.sin(n*2.4)*.12,xx=-.52+Math.cos(n*2.4)*.13;
    line([[-.51,-.21,.3],[xx,yy,.58+noise(n)*.25]],'#4b6844',2);
    dot(xx,yy,.61+noise(n)*.25,.065,n%2?'#88a36b':'#618653');
  }
  disk(w+.37,1.38,.43,.24,'xz','#385b48','#a08b52');
  disk(w+.37,1.385,.43,.16,'xz','#2c4939','#788763',0,5);
  line([[w+.39,1.4,.38],[w+.55,1.6,.08],[w+.3,1.85,.03],[w+.09,1.78,.03]],'#4b5940',2.3);
  // Edge bollards, rain gutter and a carefully worn doorstep.
  for(const x of [-.16,w+.16]){
    box(x,h+.05,.09,.09,.55,'#a28c48','#f0d27a','#7c713a',-.05);
    box(x-.004,h+.046,.098,.098,.13,'#4d5541','#637057','#3a4734',.2);
  }
  line([[w+.18,-.09,1.72],[w+.18,-.09,.18],[w+.37,.13,.02]],'#506a50',2.3);
}

function drawStatic(ctx,s,v) {
  const g=painter(ctx,v);
  floorPaint(g,s);building(g,s);exterior(g,s);
}

function staticScene(ctx,s,v) {
  const dpr=Math.max(1,Math.min(2,ctx.getTransform().a||1));
  const key=[v.w,v.h,v.u,v.ox,v.oy,s.width,s.height,dpr].join(':');
  let cached=caches.get(ctx);
  if(!cached||cached.key!==key){
    const surface=typeof OffscreenCanvas!=='undefined'?new OffscreenCanvas(Math.ceil(v.w*dpr),Math.ceil(v.h*dpr)):document.createElement('canvas');
    surface.width=Math.ceil(v.w*dpr);surface.height=Math.ceil(v.h*dpr);
    const c=surface.getContext('2d');c.setTransform(dpr,0,0,dpr,0,0);drawStatic(c,s,v);
    cached={key,surface};caches.set(ctx,cached);
  }
  ctx.drawImage(cached.surface,0,0,v.w,v.h);
}

function details(g,m,palette) {
  const {box,line,dot}=g,x=m.x,y=m.y;
  box(x+.09,y+.09,.82,.78,.105,'#334a43','#687a68','#293d35',.01);
  for(const dx of [.13,.78])for(const dy of [.15,.74]){
    box(x+dx,y+dy,.08,.08,.07,'#36473d','#bac1a7','#2c3c31',.11);
    dot(x+dx+.04,y+dy+.04,.185,.015,'#e2dcc0');
  }
  // Small nicks expose steel, rather than a uniform plastic surface.
  line([[x+.22,y+.895,.19],[x+.32,y+.895,.19]],'#b7c0a2',.6);
  if(m.level>1){
    for(let n=0;n<m.level-1;n++)box(x+.19+n*.17,y+.885,.12,.022,.044,'#b49348','#efd88a','#8f783b',.15);
  }
  if(m.level===3)line([[x+.11,y+.12,.13],[x+.88,y+.12,.13],[x+.88,y+.85,.13]],palette.light,.9);
}

function workpiece(g,part,x,y,z,scale=1) {
  if(!part)return;
  const {box,line,disk}=g;
  if(part.product==='shaft'){
    line([[x,y+.07*scale,z+.04*scale],[x+.34*scale,y+.07*scale,z+.04*scale]],'#718d91',Math.max(1.8,g.v.u*.095*scale));
    line([[x,y+.055*scale,z+.06*scale],[x+.34*scale,y+.055*scale,z+.06*scale]],'#e3e9e0',Math.max(.65,g.v.u*.033*scale));
    disk(x+.34*scale,y+.07*scale,z+.04*scale,.045*scale,'yz','#b6c9c3','#e3e5d8');
    if(part.stage>0)line([[x+.25*scale,y+.025*scale,z+.06*scale],[x+.25*scale,y+.11*scale,z+.06*scale]],'#738f8d',.6);
  }else{
    box(x,y,.3*scale,.19*scale,.04*scale,'#829c9d','#d9e1d8','#5f7f83',z);
    line([[x+.015*scale,y+.03*scale,z+.045*scale],[x+.285*scale,y+.03*scale,z+.045*scale]],'#f3efdc',Math.max(.7,g.v.u*.025));
    if(part.stage>=2){
      for(const dx of [.06,.24])disk(x+dx*scale,y+.095*scale,z+.043*scale,.025*scale,'xy','#425e60','#9eb8ad');
    }
  }
}

function saw(g,m,active,t,part) {
  const {box,line,disk,face,dot}=g,x=m.x,y=m.y,l=m.level;
  details(g,m,{light:'#e7c37a'});
  // Cast pedestal, machined bed, rail and clamped stock.
  box(x+.14,y+.19,.65,.55,.43,'#bd8245','#edc078','#875b33',.14);
  box(x+.12,y+.15,.73,.65,.075,'#849896','#e1e4d7','#526d68',.58);
  face([[x+.14,y+.17,.656],[x+.33,y+.17,.656],[x+.7,y+.78,.656],[x+.5,y+.78,.656]],'#fff6d776');
  face([[x+.14,y+.75,.28],[x+.25,y+.75,.28],[x+.25,y+.75,.54],[x+.14,y+.75,.54]],'#eec08937');
  line([[x+.17,y+.747,.25],[x+.17,y+.747,.52],[x+.76,y+.747,.52]],'#f2ca8b',.75);
  for(let n=0;n<4;n++)line([[x+.27+n*.08,y+.75,.3],[x+.27+n*.08,y+.75,.43]],'#805b39',.8);
  for(let n=0;n<4;n++)line([[x+.2+n*.14,y+.22,.659],[x+.2+n*.14,y+.7,.659]],'#6a7e70',.7);
  workpiece(g,part,x+.2,y+.31,.66,1.45);
  box(x+.3,y+.55,.2,.08,.11,'#475e50','#8fa28b','#30493b',.66);
  line([[x+.4,y+.62,.72],[x+.4,y+.81,.72]],'#d7d5b6',1.6);
  disk(x+.4,y+.82,.72,.075,'xz','#4c6452','#b7bea0',0,3);
  box(x+.61,y+.21,.11,.19,.31,'#ac743a','#e9b866','#81562c',.64);
  const angle=active?t*.018:0;
  // Circular abrasive wheel, bright rim and fan slots.
  disk(x+.58,y+.49,.83,.205,'yz','#596b61','#d5d8bd',angle,8);
  disk(x+.59,y+.49,.83,.126,'yz','#89978a','#cbd1b7',angle+.2,5);
  dot(x+.6,y+.49,.83,.034,'#d6dbbf');
  face([[x+.55,y+.28,.85],[x+.55,y+.33,1.035],[x+.55,y+.55,1.035],[x+.55,y+.68,.91]],'#d19b4e','#f5d58f',.8);
  line([[x+.554,y+.35,1.018],[x+.554,y+.52,1.018]],'#ffe7af',Math.max(.7,g.v.u*.035));
  line([[x+.59,y+.31,.97],[x+.84,y+.37,1.0]],'#4b5845',2.1);
  if(l>=2){
    face([[x+.16,y+.69,.67],[x+.55,y+.69,.67],[x+.55,y+.69,.87],[x+.16,y+.69,.87]],'#b0d9c04b','#d4d8ad',.9);
    box(x+.69,y+.65,.12,.15,.2,'#4b6656','#8f9c77','#304a3a',.66);
    dot(x+.76,y+.81,.78,.025,'#d9b263');
  }
  if(l===3){
    box(x+.13,y+.2,.09,.38,.25,'#d2be83','#f1dca4','#8d8055',.66);
    box(x+.21,y+.2,.13,.15,.28,'#59765d','#9bad81','#3c5842',.65);
    face([[x+.22,y+.356,.76],[x+.32,y+.356,.76],[x+.32,y+.356,.88],[x+.22,y+.356,.88]],'#315b4f');
    dot(x+.28,y+.365,.71,.021,'#8fd0a3');
  }
}

function drill(g,m,active,t,part) {
  const {box,line,disk,face,dot}=g,x=m.x,y=m.y,l=m.level;
  details(g,m,{light:'#a7c8ab'});
  box(x+.34,y+.14,.21,.22,.95,'#4f8591','#9fc5c5','#305764',.17);
  // Chrome column, saddle and a slotted work table.
  box(x+.39,y+.37,.07,.08,.78,'#9fb8b5','#f0f0dc','#597d7b',.18);
  face([[x+.412,y+.453,.2],[x+.44,y+.453,.2],[x+.44,y+.453,1.02],[x+.412,y+.453,1.02]],'#edf3dc8c');
  line([[x+.4,y+.38,.22],[x+.4,y+.38,1.03]],'#e8eee0',.85);
  box(x+.19,y+.35,.53,.42,.085,'#6e8c8a','#d2dcd1','#3d6468',.55);
  face([[x+.22,y+.37,.637],[x+.35,y+.37,.637],[x+.64,y+.75,.637],[x+.5,y+.75,.637]],'#fbf6dc88');
  for(let n=0;n<3;n++)line([[x+.24+n*.15,y+.41,.641],[x+.24+n*.15,y+.71,.641]],'#57705c',.75);
  workpiece(g,part,x+.34,y+.5,.64,.75);
  // Belt cover with bevelled top; vertical spindle genuinely follows work state.
  box(x+.23,y+.12,.43,.34,.2,'#49828f','#9fc9ca','#2c5663',1.04);
  face([[x+.23,y+.12,1.24],[x+.66,y+.12,1.24],[x+.61,y+.41,1.25],[x+.27,y+.41,1.25]],'#b0cfcb');
  face([[x+.28,y+.15,1.248],[x+.4,y+.15,1.248],[x+.5,y+.4,1.25],[x+.36,y+.4,1.25]],'#e0e9d845');
  line([[x+.25,y+.46,1.235],[x+.64,y+.46,1.235]],'#d8e3d4',.85);
  for(let n=0;n<4;n++)line([[x+.3+n*.075,y+.465,1.09],[x+.3+n*.075,y+.465,1.17]],'#295565',.75);
  const z=.78+(active?Math.sin(t*.006)*.045:0);
  box(x+.4,y+.43,.09,.09,.2,'#a1bab6','#f0f1dc','#668b86',z);
  line([[x+.445,y+.475,z-.095],[x+.445,y+.475,z+.04]],'#d9e2cf',Math.max(1.3,g.v.u*.05));
  line([[x+.445,y+.475,z-.095],[x+.445,y+.475,z-.13]],'#4d6f5c',1);
  disk(x+.7,y+.32,.99,.13,'yz','#4c6955','#c4cdab',active?Math.sin(t*.006)*.13:0,3);
  dot(x+.705,y+.32,.99,.033,'#ced3b5');
  line([[x+.26,y+.48,.9],[x+.26,y+.73,.9]],'#78997e',1.4);
  dot(x+.26,y+.74,.9,.034,'#354e3d');
  if(l>=2){
    face([[x+.3,y+.59,.72],[x+.59,y+.59,.72],[x+.59,y+.59,1.02],[x+.3,y+.59,1.02]],'#bad5b94b','#d0d6ac',.8);
    box(x+.14,y+.24,.11,.14,.29,'#8e9c6b','#c7ca97','#63784b',.74);
    dot(x+.2,y+.39,.88,.025,'#e6bf69');
  }
  if(l===3){
    box(x+.68,y+.17,.16,.25,.3,'#597d65','#aabd95','#365a44',.68);
    face([[x+.69,y+.43,.78],[x+.82,y+.43,.78],[x+.82,y+.43,.94],[x+.69,y+.43,.94]],'#234b3e');
    line([[x+.72,y+.435,.86],[x+.78,y+.435,.86]],'#a2d5ab',.8);
  }
}

function lathe(g,m,active,t,part) {
  const {box,line,disk,face,dot}=g,x=m.x,y=m.y,l=m.level;
  details(g,m,{light:'#b9c8a4'});
  box(x+.12,y+.16,.76,.63,.4,'#5c7e94','#a9bec8','#35556c',.17);
  face([[x+.14,y+.795,.2],[x+.22,y+.795,.2],[x+.22,y+.795,.55],[x+.14,y+.795,.55]],'#afc7d043');
  face([[x+.17,y+.795,.24],[x+.79,y+.795,.24],[x+.79,y+.795,.49],[x+.17,y+.795,.49]],'#53758b','#9aafb9',.7);
  line([[x+.51,y+.8,.26],[x+.51,y+.8,.47]],'#304e65',.8);
  for(let n=0;n<4;n++)line([[x+.22,y+.802,.29+n*.038],[x+.37,y+.802,.29+n*.038]],'#2c4b60',.65);
  for(const dx of [.44,.57])line([[x+dx,y+.805,.37],[x+dx+.03,y+.805,.37]],'#c0cbb0',1.1);
  box(x+.16,y+.22,.68,.45,.05,'#829a9b','#cbd4c8','#4b6d77',.58);
  face([[x+.18,y+.24,.632],[x+.43,y+.24,.632],[x+.78,y+.64,.632],[x+.55,y+.64,.632]],'#f8f4da73');
  for(const dy of [.31,.52])box(x+.2,y+dy,.62,.045,.055,'#a6bcb6','#f2efdc','#6c9290',.63);
  box(x+.13,y+.19,.21,.46,.4,'#62879f','#afc4cd','#3c5d76',.63);
  line([[x+.15,y+.65,1.01],[x+.31,y+.65,1.01]],'#e0e6d7',.85);
  for(let n=0;n<4;n++)line([[x+.18,y+.662,.72+n*.055],[x+.28,y+.662,.72+n*.055]],'#315940',.7);
  disk(x+.36,y+.44,.86,.14,'yz','#839b89','#d8dfc3',active?t*.025:0,3);
  workpiece(g,part,x+.36,y+.363,.82,1.1);
  box(x+.7,y+.29,.13,.29,.2,'#708fa2','#b4c7ce','#4a6b80',.68);
  const slide=active?Math.sin(t*.0018)*.08:0;
  box(x+.48+slide,y+.52,.18,.12,.15,'#506f56','#9aac87','#34503a',.68);
  line([[x+.56+slide,y+.55,.83],[x+.56+slide,y+.46,.87]],'#b5c2a4',1.7);
  disk(x+.58+slide,y+.7,.74,.1,'xz','#486447','#b7c4a1',active?t*.003:0,4);
  dot(x+.24,y+.677,.92,.024,'#d4a15d');
  if(l>=2){
    face([[x+.35,y+.26,.68],[x+.74,y+.26,.68],[x+.74,y+.26,1.02],[x+.35,y+.26,1.02]],'#b9d7bd44','#bccc9e',1);
    line([[x+.34,y+.26,1.03],[x+.75,y+.26,1.03]],'#cbd3ac',1.2);
  }
  if(l===3){
    box(x+.73,y+.13,.15,.13,.31,'#bec49b','#e4e3bb','#8c9a70',.7);
    face([[x+.75,y+.265,.83],[x+.86,y+.265,.83],[x+.86,y+.265,.97],[x+.75,y+.265,.97]],'#315547');
    dot(x+.77,y+.27,.77,.019,'#b6db9c');dot(x+.83,y+.27,.77,.019,'#dca56b');
  }
}

function inspection(g,m,active,t,part) {
  const {box,line,face,disk,dot}=g,x=m.x,y=m.y,l=m.level;
  details(g,m,{light:'#d7cb9e'});
  for(const dx of [.15,.75])for(const dy of [.14,.68])box(x+dx,y+dy,.075,.075,.54,'#728b87','#c0cbbc','#425e60',.13);
  box(x+.12,y+.13,.75,.66,.085,'#b19563','#e4cca1','#8c7147',.68);
  for(let n=0;n<3;n++)line([[x+.14,y+.22+n*.19,.769],[x+.42,y+.235+n*.19,.769],[x+.83,y+.22+n*.19,.769]],'#9a764b4a',Math.max(.6,g.v.u*.025));
  face([[x+.14,y+.15,.768],[x+.31,y+.15,.768],[x+.7,y+.77,.768],[x+.5,y+.77,.768]],'#fff2ca24');
  box(x+.16,y+.58,.65,.18,.17,'#879c91','#c4ccae','#5c7769',.49);
  line([[x+.37,y+.765,.58],[x+.59,y+.765,.58]],'#ced0a4',1.1);
  face([[x+.24,y+.28,.77],[x+.57,y+.28,.77],[x+.57,y+.6,.77],[x+.24,y+.6,.77]],'#476f5b','#6f9377',.7);
  workpiece(g,part,x+.29,y+.33,.775,.75);
  // Caliper, clipboard, articulated lamp and bright but local task lighting.
  line([[x+.32,y+.52,.82],[x+.54,y+.52,.82]],'#d7dec4',1);
  line([[x+.33,y+.49,.82],[x+.33,y+.55,.82]],'#d7dec4',1);
  face([[x+.64,y+.35,.774],[x+.8,y+.35,.774],[x+.8,y+.58,.774],[x+.64,y+.58,.774]],'#e1d9b2');
  for(let n=0;n<3;n++)line([[x+.67,y+.39+n*.045,.778],[x+.77,y+.39+n*.045,.778]],'#9b9f7b',.6);
  line([[x+.2,y+.19,.77],[x+.2,y+.19,.99],[x+.4,y+.35,1.01]],'#3e6050',Math.max(1.2,g.v.u*.047));
  box(x+.33,y+.3,.18,.12,.06,'#759579','#a2b68c','#4e7155',.94);
  face([[x+.34,y+.31,.938],[x+.5,y+.31,.938],[x+.5,y+.41,.938],[x+.34,y+.41,.938]],active?'#fff2b8':'#bec9a3');
  if(active)face([[x+.26,y+.26,.779],[x+.56,y+.26,.779],[x+.63,y+.6,.779],[x+.23,y+.6,.779]],'#ffe8a31a');
  if(l>=2){
    box(x+.62,y+.15,.04,.04,.14,'#6d8466','#acb998','#425b44',.77);
    face([[x+.52,y+.19,.86],[x+.82,y+.19,.86],[x+.82,y+.19,1.01],[x+.52,y+.19,1.01]],'#315749','#a1b68a',1);
    line([[x+.57,y+.2,.92],[x+.64,y+.2,.96],[x+.69,y+.2,.91],[x+.77,y+.2,.95]],'#b6d6a5',.8);
  }
  if(l===3){
    box(x+.18,y+.37,.045,.23,.16,'#91a383','#dce0b9','#607c59',.77);
    box(x+.22,y+.37,.22,.035,.035,'#a4b694','#eef0ca','#6a855e',.895);
    dot(x+.42,y+.39,.88,.024,'#344f38');
  }
}

function machine(g,m,worker,opt,part) {
  const active=worker?.job?.phase==='work';
  const moving=active&&opt.running&&!opt.reducedMotion;
  const t=moving?opt.time:0;
  g.shadow(m.x+.11,m.y+.12,.86,.76,.24);
  if(m.kind!=='inspect'){
    // A little old oil and curled swarf anchor each machine to the floor.
    g.disk(m.x+.83,m.y+.8,.009,.2,'xy','#334a3930');
    const seed=m.x*11+m.y*17;
    for(let n=0;n<5;n++){
      const x=m.x+.2+noise(seed+n)*.8,y=m.y+.91+noise(seed+n+50)*.12;
      const length=.025+noise(seed+n+9)*.045;
      g.line([[x,y,.016],[x+length*.5,y+.018,.022],[x+length,y+.005,.018]],n%2?'#d8d9b6':'#718a7e',.6);
    }
  }
  ({cut:saw,drill,lathe,inspect:inspection}[m.kind])(g,m,active,t,active?part:null);
  // Status is truthful even while the user has paused the clock.
  const z={cut:.95,drill:1.2,lathe:.99,inspect:.98}[m.kind];
  g.dot(m.x+.85,m.y+.2,z,.036,active?'#c4df91':worker?'#e6c67d':'#657c60','#3f5947');
  if(moving&&m.kind==='cut'){
    // A bounded handful of tiny trails; no particles while stopped.
    for(let n=0;n<4;n++){
      const f=(opt.time*.002+n*.27)%1;
      const x=m.x+.59+f*.21,y=m.y+.58+f*.23,z=.73-f*.19;
      g.line([[x,y,z],[x+.035,y+.025,z-.018]],n%2?'#ffdea0':'#f4ba68',Math.max(.7,g.v.u*.025));
    }
  }
}

function worker(g,w,opt,visual) {
  const {ctx,v,p,box,line,dot}=g;
  const walking=visual.phase==='pickup'||visual.phase==='carry',working=visual.phase==='work';
  const moving=opt.running&&!opt.reducedMotion;
  const t=moving?opt.time:0,phase=walking&&moving?Math.sin(t*.014+w.id*1.8):0;
  const foot=p(w.x+.45,w.y+.45);
  ctx.fillStyle='#233b2b25';ctx.beginPath();ctx.ellipse(foot.x+2,foot.y+2,v.u*.27,v.u*.115,0,0,TAU);ctx.fill();
  ctx.fillStyle='#203b2d50';ctx.beginPath();ctx.ellipse(foot.x+.5,foot.y+.8,v.u*.17,v.u*.07,0,0,TAU);ctx.fill();
  const colors=[['#587985','#b2c2b4'],['#987b50','#d6b781'],['#4e7b64','#b4c597']][w.id%3];
  // Stable workwear silhouettes with two independently stepping legs.
  const bob=walking&&moving?Math.abs(phase)*.025:0,x=w.x,y=w.y;
  // Only the upper-body pose leans within the worker's service cell. Logical
  // position, path and hit geometry remain exactly where the model put them.
  const lean=working?-.2:0;
  for(const [dx,sign] of [[.35,-1],[.49,1]]){
    box(x+dx,y+.35+phase*.048*sign,.085,.11,.27,colors[0],colors[1],'#344d3f',.055+bob);
    box(x+dx-.025,y+.37+phase*.048*sign,.13,.14,.065,'#34463a','#64725b','#24392b',.015);
  }
  box(x+.31,y+.29+lean,.29,.22,.31,colors[0],colors[1],'#364f40',.29+bob);
  dot(x+.33,y+.32+lean,.55+bob,.06,colors[1]);
  dot(x+.58,y+.32+lean,.55+bob,.06,colors[0]);
  // Belt, chest pocket and pale shirt/collar.
  line([[x+.32,y+.515+lean,.33+bob],[x+.59,y+.515+lean,.33+bob]],'#2d4937',Math.max(.7,v.u*.033));
  box(x+.45,y+.515+lean,.075,.015,.065,'#a0b29b','#c4ceac','#6d8869',.49+bob);
  line([[x+.4,y+.405+lean,.6+bob],[x+.48,y+.405+lean,.6+bob]],'#e3d6b2',Math.max(.9,v.u*.04));
  dot(x+.445,y+.405+lean,.69+bob,.11,'#d7b98a');
  // Brimmed shop caps, never floating emoji.
  const head=p(x+.445,y+.405+lean,.76+bob);
  ctx.fillStyle=w.id===1?'#d7ccab':'#e1bb67';ctx.beginPath();ctx.ellipse(head.x,head.y,v.u*.123,v.u*.072,-.15,0,TAU);ctx.fill();
  line([[x+.39,y+.43+lean,.76+bob],[x+.57,y+.46+lean,.76+bob]],w.id===1?'#bbbda0':'#cfa858',Math.max(1.3,v.u*.055));
  line([[x+.385,y+.395+lean,.78+bob],[x+.48,y+.395+lean,.78+bob]],w.id===1?'#f2e7c5':'#f1d38b',.7);
  if(visual.phase==='carry'){
    line([[x+.31,y+.34,.55+bob],[x+.32,y+.56,.44+bob],[x+.4,y+.6,.44+bob]],colors[0],Math.max(1.6,v.u*.07));
    line([[x+.57,y+.35,.55+bob],[x+.67,y+.52,.44+bob]],colors[1],Math.max(1.5,v.u*.065));
    workpiece(g,visual.part,x+.36,y+.5,.42+bob,1.12);
    dot(x+.37,y+.57,.43+bob,.034,'#dfc39a');dot(x+.68,y+.55,.43+bob,.034,'#dfc39a');
  }else if(working){
    const m=visual.machine;
    const handZ={cut:.66,drill:.64,lathe:.72,inspect:.7}[m.kind]||.66;
    const motion=moving?Math.sin(t*.006+w.id)*.018:0;
    // Short bent arms reach the near edge of the assigned machine; the worker
    // never stretches across the gap from the centre of the service cell.
    for(const [side,color] of [[-.1,colors[1]],[.12,colors[0]]]){
      const shoulder=[x+.45+side,y+.34+lean,.55];
      const hand=[m.x+.46+side,m.y+.98+motion,handZ];
      const elbow=[shoulder[0]+(side<0?-.045:.045),y+.07,.57+motion];
      line([shoulder,elbow,hand],color,Math.max(1.3,v.u*.06));
      dot(...hand,.035,'#dfc39a');
    }
  }else{
    const swing=walking?phase*.045:0;
    line([[x+.31,y+.33,.55+bob],[x+.26,y+.43+swing,.34+bob]],colors[1],Math.max(1.8,v.u*.075));
    line([[x+.58,y+.34,.55+bob],[x+.63,y+.43-swing,.34+bob]],colors[0],Math.max(1.8,v.u*.075));
    dot(x+.26,y+.43+swing,.33+bob,.036,'#dfc39a');dot(x+.63,y+.43-swing,.33+bob,.036,'#dfc39a');
  }
  // Actual skill progression is visible as stitched marks, without a noisy label.
  for(let n=1;n<w.skill;n++)line([[x+.34+n*.045,y+.518+lean,.5+bob],[x+.34+n*.045,y+.518+lean,.54+bob]],'#ebd89b',.7);
}

function materials(g,s,visuals) {
  const {box,line}=g;
  pallet(g,.08,.13,.7,.65);
  const removed=new Set(visuals.filter(v=>v.phase==='carry'||v.phase==='work').map(v=>v.part.id));
  const incoming=s.parts.filter(p=>!p.done&&p.stage===0&&p.x===0&&p.y===0&&!removed.has(p.id));
  // These are compact stacks of actual incoming orders, never decorative stock.
  const plates=incoming.filter(p=>p.product==='plate'),shafts=incoming.filter(p=>p.product==='shaft');
  const plateLayers=Math.min(4,Math.ceil(plates.length/5));
  for(let i=0;i<plateLayers;i++){
    box(.13,.18,.58,.45,.046,'#819b9b','#d1dbcd','#5c7b77',.16+i*.05);
    line([[.15,.27,.209+i*.05],[.67,.27,.209+i*.05]],'#edf0da',.8);
  }
  for(let i=0;i<Math.min(4,Math.ceil(shafts.length/4));i++)workpiece(g,shafts[0],.14,.2+i*.1,.17+plateLayers*.05,1.5);
  pallet(g,.08,s.height-.86,.72,.68);
  const ready=s.orders.reduce((n,o)=>n+(!o.shipped?o.done:0),0);
  for(let i=0;i<Math.min(6,Math.ceil(ready/3));i++){
    const x=.12+(i%2)*.32,y=s.height-.8+(Math.floor(i/2)%2)*.29,z=.16+Math.floor(i/4)*.27;
    box(x,y,.28,.25,.25,'#a58d5a','#d5c291','#7f7149',z);
    box(x+.12,y,.035,.25,.006,'#d7cba0','#e7dab0','#bfb184',z+.252);
  }
}

function truck(g,s) {
  const {box,line,disk,face,shadow,dot}=g,x=s.width-2.6,y=s.height+.54;
  shadow(x+.02,y+.03,2.15,.7,.22);
  box(x+.05,y+.08,2.15,.62,.16,'#4d6651','#74866a','#334b38',.13);
  // Small cream kei truck with an open steel bed.
  box(x+.06,y+.1,1.38,.59,.13,'#b5c2a3','#dbe1bf','#829778',.31);
  box(x+.06,y+.1,1.38,.055,.24,'#b6c4a3','#e0e4c3','#7c9575',.35);
  box(x+.06,y+.65,1.38,.055,.24,'#bec9a6','#e6e7c5','#879a77',.35);
  box(x+.06,y+.12,.06,.51,.24,'#b4c1a0','#e1e6c4','#809773',.35);
  for(let n=0;n<5;n++)line([[x+.17+n*.24,y+.708,.38],[x+.17+n*.24,y+.708,.53]],'#899e7b',.65);
  box(x+1.5,y+.09,.58,.62,.38,'#c7c59a','#e9dfb4','#999f75',.33);
  box(x+1.55,y+.11,.43,.55,.22,'#9fb5a0','#dde1bd','#637f6b',.69);
  face([[x+1.99,y+.17,.72],[x+1.99,y+.58,.72],[x+1.95,y+.58,.86],[x+1.95,y+.17,.86]],'#426c5a','#9bb99a',.7);
  face([[x+1.57,y+.672,.73],[x+1.91,y+.672,.73],[x+1.91,y+.672,.86],[x+1.57,y+.672,.86]],'#5c8271');
  line([[x+1.82,y+.684,.57],[x+1.94,y+.684,.57]],'#7e9777',1);
  box(x+2.08,y+.09,.1,.63,.12,'#aeb799','#d5d8b7','#7a8f6d',.32);
  for(const yy of [y+.14,y+.59])dot(x+2.184,yy,.52,.045,'#efe0a1');
  for(const xx of [x+.4,x+1.77]){
    disk(xx,y+.71,.23,.17,'xz','#2b3c2c','#1d3223');
    disk(xx,y+.72,.23,.082,'xz','#91a180','#c6cbae',.1,4);
  }
  line([[x+1.5,y+.71,.37],[x+2.03,y+.71,.37]],'#7f9672',.7);
}

function floorSelection(g,s,opt) {
  const {line,face}=g,m=s.machines.find(m=>m.id===opt.selected);
  if(m&&!opt.placing){
    line([[m.x-.06,m.y-.06,.02],[m.x+1.05,m.y-.06,.02],[m.x+1.05,m.y+1.03,.02],[m.x-.06,m.y+1.03,.02],[m.x-.06,m.y-.06,.02]],'#f5d78c',Math.max(1.4,g.v.u*.065));
    face([[m.x+.02,m.y+.02,.014],[m.x+.98,m.y+.02,.014],[m.x+.98,m.y+.98,.014],[m.x+.02,m.y+.98,.014]],'#f4ce7717');
    const w=s.workers.find(w=>w.job?.machine===m.id);
    if(w?.job.phase==='walk')line([[w.x+.45,w.y+.45,.025],...w.job.path.map(q=>[q.x+.45,q.y+.45,.025])],'#f1e8a8',Math.max(1.3,g.v.u*.05),[3,4]);
  }
  if(opt.placing&&!opt.placing.draining){
    for(const {x,y} of opt.placementCells||[]){
      face([[x+.06,y+.06,.015],[x+.94,y+.06,.015],[x+.94,y+.94,.015],[x+.06,y+.94,.015]],'#b9d87e32','#dfedaa',.85);
    }
  }
}

function badge(g,m,worker,selected) {
  const {ctx,v,p}=g;
  const height={cut:1.1,drill:1.36,lathe:1.15,inspect:1.12}[m.kind];
  const q=p(m.x+.5,m.y+.42,height),font=Math.max(9,Math.min(11,v.u*.39));
  const text=names[m.kind]+' · Lv.'+m.level;
  ctx.font='600 '+font+'px system-ui';const width=ctx.measureText(text).width+18;
  const r={x:q.x-width/2,y:q.y-font-5,w:width,h:font+10};
  ctx.fillStyle=selected?'#f0d193':'#203e33eb';
  ctx.beginPath();ctx.roundRect(r.x,r.y,r.w,r.h,5);ctx.fill();
  ctx.strokeStyle=selected?'#fff0b9':'#bed0a93d';ctx.lineWidth=.7;ctx.stroke();
  ctx.fillStyle=selected?'#304333':worker?.job?.phase==='work'?'#e0e9b9':'#e3e3c7';
  ctx.textAlign='center';ctx.fillText(text,q.x,q.y+1);
  return r;
}

export function drawWorkshop(ctx,state,viewport,options={}) {
  const opt={time:0,running:false,reducedMotion:false,selected:null,placing:null,placementCells:[],showLabels:false,...options};
  if(viewport.w<=0||viewport.h<=0||viewport.u<=0)return [];
  ctx.save();
  staticScene(ctx,state,viewport);
  const g=painter(ctx,viewport);
  floorSelection(g,state,opt);
  const entities=[
    ...state.machines.map(m=>({depth:m.x+m.y+.9,type:'machine',m})),
    ...state.workers.map(w=>({depth:w.x+w.y+.94,type:'worker',w}))
  ].sort((a,b)=>a.depth-b.depth||Number(a.type==='worker')-Number(b.type==='worker'));
  const visuals=state.workers.map(w=>workerVisualState(state,w));
  materials(g,state,visuals);
  const targets=[],labels=[];
  for(const entity of entities){
    if(entity.type==='worker')worker(g,entity.w,opt,visuals[state.workers.indexOf(entity.w)]);
    else{
      const m=entity.m,w=state.workers.find(w=>w.job?.machine===m.id);
      const part=w?state.parts.find(p=>p.id===w.job.part):null;
      machine(g,m,w,opt,part);
      const target={id:m.id,hull:machineHull(viewport,m)};
      targets.push(target);
      if((opt.showLabels||m.id===opt.selected)&&!opt.placing)labels.push({target,m,w});
    }
  }
  truck(g,state);
  // Nameplates are an intentional optional overlay; the machinery stays visible.
  for(const {target,m,w} of labels)target.label=badge(g,m,w,m.id===opt.selected);
  ctx.restore();
  return targets;
}
