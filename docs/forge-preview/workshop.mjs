import {project, machineHull} from './view.mjs?v=0.13';

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
    const near=[[x,y+d,z],[x+w,y+d,z],[x+w,y+d,z+h],[x,y+d,z+h]];
    const end=[[x+w,y,z],[x+w,y+d,z],[x+w,y+d,z+h],[x+w,y,z+h]];
    face(near,front,edge);face(end,side,edge);
    face([[x,y,z+h],[x+w,y,z+h],[x+w,y+d,z+h],[x,y+d,z+h]],top,edge);
    if(w>.28&&d>.18&&h>.15){
      face(near,wash(near[3],near[1],[[0,'#fff2cc1e'],[.44,'#eacca300'],[1,'#1e324333']]));
      face(end,wash(end[3],end[1],[[0,'#f3d9bc0e'],[1,'#102d3b3d']]));
      line([[x,y+d,z+h],[x+w,y+d,z+h],[x+w,y,z+h]],'#fff1d475',Math.max(.55,v.u*.025));
    }
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
  function wash(from,to,stops) {
    const a=p(...from),b=p(...to),gradient=ctx.createLinearGradient(a.x,a.y,b.x,b.y);
    for(const [offset,color] of stops)gradient.addColorStop(offset,color);
    return gradient;
  }
  // Turned parts have a continuous specular band around a rounded metal body.
  function upright(x,y,z,r,h,stops,cap) {
    const a=p(x,y,z+h),b=p(x,y,z),rx=v.u*r*Math.SQRT2,ry=rx*.5;
    const sheen=ctx.createLinearGradient(a.x-rx,0,a.x+rx,0);
    for(const [offset,color] of stops)sheen.addColorStop(offset,color);
    ctx.fillStyle=sheen;ctx.beginPath();ctx.moveTo(a.x-rx,a.y);ctx.lineTo(b.x-rx,b.y);
    ctx.ellipse(b.x,b.y,rx,ry,0,Math.PI,0,true);ctx.lineTo(a.x+rx,a.y);ctx.closePath();ctx.fill();
    ctx.fillStyle=cap;ctx.beginPath();ctx.ellipse(a.x,a.y,rx,ry,0,0,TAU);ctx.fill();
  }
  function softShadow(x,y,rx,ry,alpha) {
    const q=p(x,y,.01);ctx.save();ctx.translate(q.x,q.y);ctx.scale(rx*v.u,ry*v.u);
    const ramp=ctx.createRadialGradient(0,0,0,0,0,1);
    ramp.addColorStop(0,'rgba(20,36,44,'+alpha+')');ramp.addColorStop(.55,'rgba(28,41,44,'+alpha*.58+')');ramp.addColorStop(1,'rgba(28,41,44,0)');
    ctx.fillStyle=ramp;ctx.fillRect(-1,-1,2,2);ctx.restore();
  }
  function shadow(x,y,w,d,alpha=.18) {
    softShadow(x+w*.76+.13,y+d*.49,w*1.28,d*.86,alpha*1.25);
    face([[x,y,.006],[x+w,y,.006],[x+w+.48,y+d+.19,.006],[x+.36,y+d+.18,.006]],'rgba(25,48,56,'+(alpha*.68)+')');
    softShadow(x+w*.5,y+d*.55,w*.84,d*.48,alpha*1.55);
  }
  function dot(x,y,z,r,fill,stroke=null) {
    const q=p(x,y,z);ctx.beginPath();ctx.arc(q.x,q.y,r*v.u,0,TAU);
    ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=.7;ctx.stroke();}
  }
  return {ctx,v,p,poly,face,line,box,disk,shadow,softShadow,dot,wash,upright};
}

function pallet(g,x,y,w=.82,d=.64,z=0) {
  const {box}=g;
  box(x,y,w,.12,.1,'#77563b','#b08959','#624833',z);
  box(x,y+d-.12,w,.12,.1,'#77563b','#aa8355','#624833',z);
  for(let n=0;n<4;n++)box(x,y+n*d/4,w,d/4-.025,.055,'#8c6b45','#bc9865','#6a5139',z+.1);
}

function floorPaint(g,s) {
  const {v,p,poly,face,line,box}=g,{width:w,height:h}=s,ctx=g.ctx;
  // The camera looks across a static workbench. Keep the area around the model transparent.
  const middle=p(w*.5,h*.5);
  ctx.save();ctx.filter='blur(11px)';ctx.fillStyle='#112120a8';
  ctx.beginPath();ctx.ellipse(middle.x+5,middle.y+v.u*1.1,v.u*(w+h)*.48,v.u*(w+h)*.24,0,0,TAU);ctx.fill();ctx.restore();
  // A walnut model base, brass reveal and a dark asphalt loading apron.
  const base=[-.57,-.89,w+1.04,h+2.76];
  box(...base,.46,'#82553b','#ac7950','#503c32',-.72);
  for(let i=0;i<4;i++){
    const z=-.65+i*.085;
    line([[base[0],h+1.87,z],[w+.47,h+1.87,z]],i%2?'#edbb773a':'#392c2850',.75);
  }
  box(...base,.055,'#c6a16b','#e6c48c','#9a784c',-.29);
  box(...base,.13,'#364445','#556263','#2e3a3d',-.235);
  box(-.53,h+.28,w+.96,1.54,.035,'#364448','#49565a','#364449',-.1);
  // Road seams and painted loading bays.
  for(let x=-.2;x<w+.2;x+=1.65)face([[x,h+1.52,-.055],[x+.8,h+1.52,-.055],[x+.8,h+1.56,-.055],[x,h+1.56,-.055]],'#d5c69488');
  line([[-.65,h+.4,-.052],[w+.53,h+.4,-.052]],'#b9c4a52b',.7);
  box(-.13,-.13,w+.26,h+.26,.25,'#75816c','#929a82','#56644f',-.25);
  // Warm concrete, subdued joints rather than a checkerboard.
  const colors=['#b8b7a6','#bcb9a5','#bab8a8','#b7b5a5','#c1bdaa'];
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
  for(let i=0;i<28;i++){
    const x=noise(980+i)*w,y=noise(1080+i)*h,center=p(x,y);
    ctx.save();ctx.translate(center.x,center.y);ctx.scale(v.u*(.25+noise(i+27)*.8),v.u*.37);
    const stain=ctx.createRadialGradient(0,0,0,0,0,1);
    stain.addColorStop(0,i%3?'#54656b13':'#f6dfaf29');stain.addColorStop(1,'#68777800');
    ctx.fillStyle=stain;ctx.fillRect(-1,-1,2,2);ctx.restore();
  }
  const warm=p(0,0),cool=p(w,h);
  const ambient=ctx.createLinearGradient(warm.x,warm.y,cool.x,cool.y);
  ambient.addColorStop(0,'#ffe0ab4a');ambient.addColorStop(.5,'#f0e4ca06');ambient.addColorStop(1,'#31536638');
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

// North-light roof bays are built on the rear wall, outside all work cells.
function roofBays(g,s) {
  const {v,p,face,line,ctx}=g;
  const count=Math.round(s.width/2.7),span=s.width/count;
  const back=-.95,front=.05,eave=1.87,peak=2.83;
  for(let i=0;i<count;i++){
    const a=i*span,b=a+span;
    const roof=g.wash([a,back,eave],[b,front,peak],[[0,'#32545b'],[.48,'#537778'],[1,'#87a49b']]);
    face([[a,back,eave],[b,back,peak],[b,front,peak],[a,front,eave]],roof,'#283f40',v.u*.035);
    for(let j=1;j<11;j++){
      const f=j/11,x=a+f*span,z=eave+f*(peak-eave);
      line([[x,back,z+.018],[x,front,z+.018]],j%3?'#bad0b348':'#284951a0',Math.max(.65,v.u*.028));
    }
    // Glass clerestory, warm lit panes towards the skyline and deep steel mullions.
    const glass=g.wash([a,front,eave],[b,front,peak],[[0,'#bd835a'],[.45,'#ffdf96'],[1,'#f8f3cf']]);
    face([[a,front,eave],[b,front,eave],[b,front,peak]],glass);
    for(let j=1;j<6;j++){
      const f=j/6,x=a+f*span,z=eave+f*(peak-eave);
      line([[x,front+.008,eave],[x,front+.008,z]],'#52645b',Math.max(.8,v.u*.043));
    }
    line([[a,front+.02,eave],[b,front+.02,peak],[b,front+.02,eave]],'#493e35',Math.max(1.6,v.u*.085));
    line([[a,front+.023,eave+.035],[b,front+.023,peak+.035]],'#d9b388',Math.max(.7,v.u*.033));
    line([[a,front,eave],[b,front,eave]],'#815b46',Math.max(1,v.u*.07));
    const endColor=i===count-1?'#526765':'#8faca3';
    face([[b,back,eave],[b,front,eave],[b,front,peak],[b,back,peak]],endColor,'#364c4c',.6);
    for(let y=back+.15;y<front;y+=.21)line([[b+.004,y,eave+.08],[b+.004,y,peak-.06]],'#c7d2b786',.9);
    // Enamel bell suspended from a cantilever. Local light is painted on the slab.
    const x=a+span*.64,y=.64,z=1.54;
    line([[x,front,1.82],[x,y,1.86],[x,y,z+.13]],'#3c4642',Math.max(.9,v.u*.045));
    const at=p(x,y,z),r=v.u*.215;
    ctx.save();ctx.translate(at.x,at.y);ctx.scale(r,r);
    const metal=ctx.createLinearGradient(-1,0,1,0);
    metal.addColorStop(0,'#afbd91');metal.addColorStop(.36,'#698b76');metal.addColorStop(1,'#28483f');
    ctx.fillStyle=metal;ctx.beginPath();ctx.moveTo(-1,0);ctx.bezierCurveTo(-.9,-.35,-.57,-.43,-.33,-.82);
    ctx.lineTo(.32,-.82);ctx.bezierCurveTo(.52,-.44,.83,-.4,1,0);ctx.closePath();ctx.fill();
    ctx.fillStyle='#ffdfa1';ctx.beginPath();ctx.ellipse(0,.02,.97,.27,0,0,TAU);ctx.fill();ctx.restore();
  }
}

function loadingDoor(g,s) {
  const {box,face,line}=g;
  const x=s.width-1.51,y=.098,w=1.15;
  const shutter=g.wash([x,y,1.58],[x+w,y,.04],[[0,'#759a9b'],[.55,'#54767a'],[1,'#344e54']]);
  face([[x,y,.055],[x+w,y,.055],[x+w,y,1.59],[x,y,1.59]],shutter);
  for(let z=.13;z<1.57;z+=.13){
    line([[x,y+.004,z],[x+w,y+.004,z]],'#c5ceaf70',Math.max(.65,g.v.u*.028));
    line([[x,y+.004,z-.033],[x+w,y+.004,z-.033]],'#203f4c70',.7);
  }
  for(const xx of [x-.05,x+w])box(xx,y,.055,.07,1.64,'#805b46','#dfb485','#554b42');
  box(x-.1,y-.015,w+.2,.19,.13,'#546b69','#98a59a','#35494b',1.56);
  for(const xx of [x+.2,x+w-.32])box(xx,y+.031,.13,.027,.035,'#d4cfb6','#eef1d5','#737b6c',.41);
}

function building(g,s) {
  const {v,p,face,line,box,disk,dot,wash}=g,{width:w,height:h}=s,ctx=g.ctx;
  // Corrugated rear wall, a low return wall, and exposed steel frame.
  box(-.13,-.2,w+.26,.2,1.8,'#d2d0b5','#e5dfc3','#8a9781',0);
  box(-.13,-.005,w+.26,.035,.42,'#477d79','#84aea1','#325b5d',0);
  for(let x=.04;x<w;x+=.14)line([[x,-.001,.44],[x,-.001,1.74]],'#828e713d',.7);
  line([[0,.032,.45],[w,.032,.45]],'#e1d8b2',.9);
  box(-.17,0,.17,h,.5,'#758974','#a6b095','#536f60',0);
  box(-.2,0,.2,Math.min(h,3.2),1.65,'#b8c2a5','#d9d9ba','#6b8973',0);
  // Tall rear windows and the angled, translucent left window.
  for(let x=.38;x<w-.6;x+=2.1){
    const ww=Math.min(1.48,w-x-.32);
    face([[x,.014,.73],[x+ww,.014,.73],[x+ww,.014,1.48],[x,.014,1.48]],'#54756a','#546f63',1.8);
    face([[x+.035,.018,.79],[x+ww-.035,.018,.79],[x+ww-.035,.018,1.44],[x+.035,.018,1.44]],wash([x,.02,1.46],[x+ww,.02,.75],[[0,'#fff1bd'],[.40,'#ebd39c'],[.56,'#acbab0'],[1,'#779999']]));
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
  loadingDoor(g,s);
  // Fixed afternoon light. Broad panes and mullion shadows read at phone scale;
  // there is no invented day/night clock or moving atmosphere.
  ctx.save();ctx.beginPath();
  [p(0,0),p(w,0),p(w,h),p(0,h)].forEach((q,i)=>i?ctx.lineTo(q.x,q.y):ctx.moveTo(q.x,q.y));
  ctx.closePath();ctx.clip();
  for(let x=.43;x<w-1.1;x+=2.1){
    face([[x-.05,.16,.006],[x+1.43,.16,.006],[x+3.61,2.11,.006],[x+2.19,2.11,.006]],'#fff0ba13');
    face([[x,.2,.007],[x+1.38,.2,.007],[x+3.55,2.05,.007],[x+2.17,2.05,.007]],'#ffe3a762');
    face([[x+.64,.2,.009],[x+.74,.2,.009],[x+2.91,2.05,.009],[x+2.81,2.05,.009]],'#3c566d42');
    face([[x+1.05,1.06,.009],[x+2.41,1.06,.009],[x+2.54,1.18,.009],[x+1.18,1.18,.009]],'#46694b20');
  }
  ctx.restore();
  // A wall sign is part of the building, never a floating interface label.
  roofBays(g,s);
  const a=p(w*.51,.16,1.82);
  ctx.save();ctx.translate(a.x,a.y);ctx.transform(.89,.445,0,1,0,0);
  ctx.fillStyle='#233e33';ctx.fillRect(-v.u*1.15,-v.u*.32,v.u*2.3,v.u*.45);
  ctx.strokeStyle='#a6b18a';ctx.lineWidth=.65;ctx.strokeRect(-v.u*1.15,-v.u*.32,v.u*2.3,v.u*.45);
  ctx.fillStyle='#f3dfad';ctx.font='700 '+Math.max(6,v.u*.30)+'px system-ui';ctx.textAlign='center';
  ctx.fillText('マチコバ！',0,-v.u*.055,v.u*1.9);ctx.restore();
}

function toolWall(g) {
  const {box,face,line,dot}=g;
  box(-.18,3.18,.18,1.66,1.38,'#66827a','#b6c5ae','#4d716e');
  const x=.028,y=3.27,z=.54;
  face([[x,y,z],[x,y+1.46,z],[x,y+1.46,z+.67],[x,y,z+.67]],'#876b4d','#443f38',1.15);
  for(let row=0;row<5;row++)for(let col=0;col<10;col++)
    dot(x+.004,y+.07+col*.145,z+.065+row*.13,.012,'#473f37');
  for(let i=0;i<4;i++){
    const yy=y+.18+i*.29,height=.29+(i%3)*.065;
    line([[x+.02,yy,1.13],[x+.02,yy-.025,1.13-height]],'#e3ddbd',Math.max(.95,g.v.u*.051));
    if(i<2){
      line([[x+.02,yy-.068,1.18],[x+.02,yy-.047,1.11],[x+.02,yy+.035,1.10],[x+.02,yy+.066,1.18]],'#e5ddbc',1.1);
    }else{
      line([[x+.025,yy-.025,1.07-height],[x+.025,yy-.01,1.20-height]],i===2?'#c86743':'#5c9f9f',Math.max(1.5,g.v.u*.090));
    }
  }
  // Incoming electrical supply along the fascia, clear of the workers' paths.
  for(const h of [1.30,1.37])line([[.02,3.17,h],[.02,4.74,h],[.02,4.8,h-.09]],'#a6b6ac',1.1);
}

function extractor(g,s) {
  const {box,line,face}=g,x=s.width-2.05,y=-1.01;
  // The extractor sits behind the roof line and is naturally occluded by the building.
  box(x-.26,y-.18,.50,.43,2.37,'#778581','#b9c6b1','#4c6465');
  const steel=[[0,'#5f7679'],[.25,'#c6ccc1'],[.42,'#e4dbc0'],[.55,'#8eaaa5'],[1,'#4a666d']];
  g.upright(x,y,2.28,.175,.91,steel,'#a9bab7');
  for(const z of [2.48,2.92,3.13])g.upright(x,y,z,.186,.035,steel,'#c2cbc0');
  face([[x-.22,y+.16,3.25],[x+.23,y+.16,3.25],[x+.23,y+.16,3.31],[x-.22,y+.16,3.31]],'#687f80');
  box(x-.22,y-.17,.45,.34,.045,'#839897','#c8cfc0','#637779',3.30);
  for(const xx of [x-.11,x+.13])line([[xx,y+.1,3.16],[xx,y+.1,3.31]],'#51676a',.85);
}

function exterior(g,s) {
  const {box,line,disk,shadow,dot,face}=g,{width:w,height:h}=s;
  // Every decorative object is outside the placeable machine cells.
  shadow(-.87,3.7,.58,1.4,.16);
  box(-.81,3.7,.55,1.25,.92,'#a35d40','#526665','#88472f',.04);
  for(let z=.08;z<.91;z+=.18){
    face([[-.79,4.965,z],[-.28,4.965,z],[-.28,4.965,z+.13],[-.79,4.965,z+.13]],'#ae694c','#643f34',.7);
    line([[-.65,4.976,z+.07],[-.43,4.976,z+.07]],'#c5c5a0',1.2);
  }
  for(let y=3.78;y<4.93;y+=.22)line([[-.25,y,.76],[-.25,y+.14,.76]],'#bd9676',.85);
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
  line([[w+.18,-.09,1.78],[w+.18,-.09,.18],[w+.37,.13,.02]],'#506a50',2.3);
}

function drawStatic(ctx,s,v) {
  const g=painter(ctx,v);
  floorPaint(g,s);extractor(g,s);building(g,s);toolWall(g);exterior(g,s);
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
  const ochre=g.wash([x+.14,y+.74,.57],[x+.79,y+.74,.12],[[0,'#eda447'],[.35,'#c97236'],[1,'#894429']]);
  box(x+.12,y+.17,.7,.58,.43,ochre,'#efb770','#803e30',.14);
  face([[x+.17,y+.754,.22],[x+.69,y+.754,.22],[x+.69,y+.754,.48],[x+.17,y+.754,.48]],'#914e30','#efad67',.65);
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
  // Cut-off wheel and a heavy enamel guard, built in the blade's own plane.
  const feed=active?(1+Math.sin(t*.004))*.045:0;
  const cx=x+.59,cy=y+.46,cz=.96-feed,r=.285;
  disk(cx,cy,cz,r,'yz','#344a54','#e1e3d0',angle,8);
  disk(cx+.012,cy,cz,r*.72,'yz','#718994','#cad6ce',angle+.25,5);
  const guard=[];
  for(let n=0;n<=10;n++){
    const a=n*Math.PI/10;
    guard.push([cx+.025,cy+Math.cos(a)*r*1.15,cz+Math.sin(a)*r*1.15]);
  }
  for(let n=10;n>=0;n--){
    const a=n*Math.PI/10;
    guard.push([cx+.025,cy+Math.cos(a)*r*.62,cz+Math.sin(a)*r*.62]);
  }
  face(guard,g.wash([cx,cy,cz+r],[cx,cy,cz],[[0,'#ffd28a'],[.34,'#ed8f47'],[1,'#a8472b']]),'#773e2d',.85);
  line(guard.slice(1,10),'#ffd693',Math.max(.8,g.v.u*.035));
  dot(cx+.04,cy,cz,.048,'#e9e4cd','#354751');
  line([[x+.55,y+.29,1.02],[x+.66,y+.11,1.18],[x+.81,y+.13,1.19]],'#344c51',Math.max(1.7,g.v.u*.075));
  line([[x+.68,y+.11,1.2],[x+.8,y+.13,1.21]],'#b6c2b3',.85);
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
  g.upright(x+.44,y+.28,.17,.15,.17,[[0,'#305461'],[.4,'#73a69d'],[1,'#325665']],'#82aea8');
  g.upright(x+.44,y+.28,.32,.087,.91,[[0,'#496975'],[.29,'#c8d8d2'],[.45,'#fffae4'],[.59,'#9eb7b7'],[1,'#375762']],'#dfdfcc');
  box(x+.19,y+.35,.53,.42,.085,'#6e8c8a','#d2dcd1','#3d6468',.55);
  face([[x+.22,y+.37,.637],[x+.35,y+.37,.637],[x+.64,y+.75,.637],[x+.5,y+.75,.637]],'#fbf6dc88');
  for(let n=0;n<3;n++)line([[x+.24+n*.15,y+.41,.641],[x+.24+n*.15,y+.71,.641]],'#57705c',.75);
  workpiece(g,part,x+.34,y+.5,.64,.75);
  // Belt cover with bevelled top; vertical spindle genuinely follows work state.
  const head=g.wash([x+.15,y+.55,1.39],[x+.63,y+.55,1.13],[[0,'#82c6bb'],[.28,'#388f94'],[1,'#196170']]);
  box(x+.18,y+.08,.51,.52,.21,head,'#8acbc3','#285864',1.15);
  box(x+.21,y+.1,.45,.47,.055,'#4d9698','#a3d3c6','#39717c',1.36);
  line([[x+.21,y+.60,1.355],[x+.65,y+.60,1.355]],'#def3cf',.9);
  for(let n=0;n<4;n++)line([[x+.27+n*.082,y+.603,1.2],[x+.27+n*.082,y+.603,1.29]],'#24515e',.9);
  g.upright(x+.46,y+.48,.96,.066,.18,[[0,'#526b74'],[.38,'#e7e6cf'],[1,'#617a80']],'#bfc6b8');
  const z=active ? .81+Math.sin(t*.006)*.085 : .86;
  box(x+.4,y+.43,.09,.09,.2,'#a1bab6','#f0f1dc','#668b86',z);
  line([[x+.445,y+.475,z-.095],[x+.445,y+.475,z+.04]],'#d9e2cf',Math.max(1.3,g.v.u*.05));
  line([[x+.445,y+.475,z-.095],[x+.445,y+.475,z-.13]],'#4d6f5c',1);
  for(let n=0;n<3;n++){
    const a=(active?Math.sin(t*.006)*.13:0)+n*TAU/3;
    const tip=[x+.74,y+.35+Math.cos(a)*.20,1.12+Math.sin(a)*.20];
    line([[x+.74,y+.35,1.12],tip],'#d1dbce',Math.max(.85,g.v.u*.045));
    dot(...tip,.045,'#3b4e52');
  }
  dot(x+.74,y+.35,1.12,.045,'#e5dbc0');
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
  box(x+.10,y+.15,.80,.66,.42,g.wash([x,y+.81,.6],[x+.85,y+.81,.17],[[0,'#668eb1'],[.45,'#476e98'],[1,'#2d4a66']]),'#afc4d2','#2d4e69',.17);
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
  disk(x+.36,y+.44,.86,.165,'yz','#435f6c','#ebead2',active?t*.025:0,3);
  for(const dy of [.69,.74])line([[x+.2,y+dy,.63],[x+.85,y+dy,.63]],'#c6d5ca',1.2);
  g.upright(x+.78,y+.19,.6,.10,.14,[[0,'#3d5868'],[.4,'#a7b6aa'],[1,'#446076']],'#c1c9b7');
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
  box(x+.10,y+.11,.8,.70,.095,'#a8754b',g.wash([x+.09,y+.12,.78],[x+.84,y+.78,.78],[[0,'#f7d699'],[.50,'#dbb479'],[1,'#c59461']]),'#875a41',.68);
  box(x+.19,y+.25,.35,.18,.24,'#427b76','#9aaea0','#2b5559',.21);
  line([[x+.19,y+.43,.36],[x+.53,y+.43,.36]],'#c4b99a',.8);
  for(let n=0;n<3;n++)line([[x+.14,y+.22+n*.19,.769],[x+.42,y+.235+n*.19,.769],[x+.83,y+.22+n*.19,.769]],'#9a764b4a',Math.max(.6,g.v.u*.025));
  face([[x+.14,y+.15,.768],[x+.31,y+.15,.768],[x+.7,y+.77,.768],[x+.5,y+.77,.768]],'#fff2ca24');
  box(x+.16,y+.58,.65,.18,.17,'#879c91','#c4ccae','#5c7769',.49);
  line([[x+.37,y+.765,.58],[x+.59,y+.765,.58]],'#ced0a4',1.1);
  face([[x+.24,y+.28,.77],[x+.57,y+.28,.77],[x+.57,y+.6,.77],[x+.24,y+.6,.77]],'#405b63','#779397',.7);
  workpiece(g,part,x+.29,y+.33,.775,.75);
  // Caliper, clipboard, articulated lamp and bright but local task lighting.
  line([[x+.32,y+.52,.82],[x+.54,y+.52,.82]],'#d7dec4',1);
  line([[x+.33,y+.49,.82],[x+.33,y+.55,.82]],'#d7dec4',1);
  face([[x+.64,y+.35,.774],[x+.8,y+.35,.774],[x+.8,y+.58,.774],[x+.64,y+.58,.774]],'#e1d9b2');
  for(let n=0;n<3;n++)line([[x+.67,y+.39+n*.045,.778],[x+.77,y+.39+n*.045,.778]],'#9b9f7b',.6);
  line([[x+.2,y+.19,.78],[x+.13,y+.19,1.10],[x+.44,y+.31,1.24]],'#344b51',Math.max(1.4,g.v.u*.055));
  dot(x+.13,y+.19,1.10,.047,'#d2b980','#405459');
  const shade=g.p(x+.44,y+.32,1.15),radius=g.v.u*.143;
  g.ctx.fillStyle='#326356';g.ctx.beginPath();g.ctx.arc(shade.x,shade.y,radius,Math.PI,TAU);g.ctx.fill();
  g.ctx.fillStyle=active?'#ffefac':'#d8cba2';g.ctx.beginPath();g.ctx.ellipse(shade.x,shade.y,radius,radius*.27,0,0,TAU);g.ctx.fill();
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
      const x=m.x+.59+f*.35,y=m.y+.58+f*.18,z=.71-f*.19;
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
  g.softShadow(w.x+.59,w.y+.45,.37,.16,.38);
  ctx.fillStyle='#233b2b25';ctx.beginPath();ctx.ellipse(foot.x+2,foot.y+2,v.u*.27,v.u*.115,0,0,TAU);ctx.fill();
  ctx.fillStyle='#203b2d50';ctx.beginPath();ctx.ellipse(foot.x+.5,foot.y+.8,v.u*.17,v.u*.07,0,0,TAU);ctx.fill();
  const colors=[['#31627c','#86a5ae'],['#aa6741','#e5ac71'],['#397b70','#8eb89d']][w.id%3];
  // Stable workwear silhouettes with two independently stepping legs.
  const bob=walking&&moving?Math.abs(phase)*.025:0,x=w.x,y=w.y;
  // Only the upper-body pose leans within the worker's service cell. Logical
  // position, path and hit geometry remain exactly where the model put them.
  const lean=working?-.2:0;
  for(const [dx,sign] of [[.35,-1],[.49,1]]){
    box(x+dx,y+.35+phase*.048*sign,.085,.11,.27,colors[0],colors[1],'#344d3f',.055+bob);
    box(x+dx-.025,y+.37+phase*.048*sign,.13,.14,.065,'#34463a','#64725b','#24392b',.015);
  }
  box(x+.29,y+.28+lean,.32,.25,.33,colors[0],colors[1],'#314755',.29+bob);
  g.face([[x+.34,y+.534+lean,.60+bob],[x+.44,y+.534+lean,.52+bob],[x+.46,y+.534+lean,.59+bob]],'#e7d8ac');
  line([[x+.46,y+.535+lean,.36+bob],[x+.46,y+.535+lean,.52+bob]],'#a4b8a5',.65);
  dot(x+.33,y+.32+lean,.55+bob,.06,colors[1]);
  dot(x+.58,y+.32+lean,.55+bob,.06,colors[0]);
  // Belt, chest pocket and pale shirt/collar.
  line([[x+.32,y+.515+lean,.33+bob],[x+.59,y+.515+lean,.33+bob]],'#2d4937',Math.max(.7,v.u*.033));
  box(x+.45,y+.515+lean,.075,.015,.065,'#a0b29b','#c4ceac','#6d8869',.49+bob);
  line([[x+.4,y+.405+lean,.6+bob],[x+.48,y+.405+lean,.6+bob]],'#e3d6b2',Math.max(.9,v.u*.04));
  const head=p(x+.445,y+.405+lean,.745+bob),r=v.u*.141;
  ctx.save();ctx.translate(head.x,head.y);
  const skin=ctx.createLinearGradient(-r,0,r,r);
  skin.addColorStop(0,'#f6d4a1');skin.addColorStop(.54,'#ddac80');skin.addColorStop(1,'#966b56');
  ctx.fillStyle=skin;ctx.beginPath();ctx.ellipse(0,r*.57,r*.72,r*.88,0,0,TAU);ctx.fill();
  ctx.fillStyle='#594f4a';ctx.beginPath();ctx.ellipse(r*.5,r*.48,r*.21,r*.37,-.18,0,TAU);ctx.fill();
  const cap=ctx.createLinearGradient(-r,-r,r,r*.5);
  cap.addColorStop(0,w.id===1?'#ffefd0':'#ffe9a2');
  cap.addColorStop(.5,w.id===1?'#d1d2bc':'#f0b853');
  cap.addColorStop(1,w.id===1?'#8d9e9e':'#b5793c');
  ctx.fillStyle=cap;ctx.beginPath();ctx.ellipse(0,0,r,r*.79,-.12,Math.PI,TAU);ctx.fill();
  ctx.beginPath();ctx.ellipse(0,0,r*1.11,r*.34,-.12,0,TAU);ctx.fill();
  ctx.restore();
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

// Accent the miniature's people and tools at phone scale. Keep the floor anchor
// fixed and use the very same projection for the painted body and the touch hull.
function objectView(v,x,y,scale) {
  const u=v.u*scale,delta=v.u-u;
  return {...v,u,ox:v.ox+(x-y)*delta,oy:v.oy+(x+y)*.5*delta};
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
  box(x+1.5,y+.09,.58,.62,.38,'#d9dac3','#fbedd0','#a6b6ad',.33);
  box(x+1.5,y+.093,.58,.62,.10,'#4f8582','#9fb6a4','#426967',.35);
  box(x+1.55,y+.11,.43,.55,.22,'#9fb5a0','#dde1bd','#637f6b',.69);
  face([[x+1.99,y+.17,.72],[x+1.99,y+.58,.72],[x+1.95,y+.58,.86],[x+1.95,y+.17,.86]],'#355966','#bed6c9',.7);
  face([[x+1.57,y+.672,.73],[x+1.91,y+.672,.73],[x+1.91,y+.672,.86],[x+1.57,y+.672,.86]],'#496d78');
  line([[x+1.82,y+.684,.57],[x+1.94,y+.684,.57]],'#7e9777',1);
  box(x+2.08,y+.09,.1,.63,.12,'#aeb799','#d5d8b7','#7a8f6d',.32);
  for(const yy of [y+.14,y+.59])dot(x+2.184,yy,.52,.045,'#efe0a1');
  // Mirrors, cab door pressing, wiper and radiator grille on the short nose.
  line([[x+1.95,y+.70,.71],[x+1.98,y+.84,.76],[x+1.89,y+.86,.77]],'#4a6062',1.1);
  box(x+1.86,y+.83,.095,.08,.085,'#3d5055','#9baea7','#364c50',.73);
  line([[x+1.55,y+.718,.66],[x+1.55,y+.718,.445],[x+1.97,y+.718,.445],[x+1.97,y+.718,.66]],'#768c88',.8);
  line([[x+2.001,y+.23,.73],[x+2.001,y+.47,.79]],'#253f48',.95);
  for(const z of [.42,.46,.50])line([[x+2.087,y+.24,z],[x+2.087,y+.55,z]],'#51646a',.8);
  box(x+2.095,y+.3,.018,.18,.07,'#bfa455','#efcc75','#efcc75',.345);
  for(const xx of [x+.4,x+1.77]){
    disk(xx,y+.71,.23,.17,'xz','#2d373b','#233034');
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
  const height={cut:1.32,drill:1.5,lathe:1.15,inspect:1.34}[m.kind];
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
  ctx.clearRect(0,0,viewport.w,viewport.h);
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
    if(entity.type==='worker'){
      const w=entity.w,portrait=painter(ctx,objectView(viewport,w.x+.45,w.y+.45,1.16));
      worker(portrait,w,opt,visuals[state.workers.indexOf(w)]);
    }
    else{
      const m=entity.m,w=state.workers.find(w=>w.job?.machine===m.id);
      const part=w?state.parts.find(p=>p.id===w.job.part):null;
      const local=objectView(viewport,m.x+.5,m.y+.5,1.13);
      const tool=painter(ctx,local);
      machine(tool,m,w,opt,part);
      const target={id:m.id,hull:machineHull(local,m)};
      targets.push(target);
      if((opt.showLabels||m.id===opt.selected)&&!opt.placing)labels.push({target,m,w,tool});
    }
  }
  truck(g,state);
  // Nameplates are an intentional optional overlay; the machinery stays visible.
  for(const {target,m,w,tool} of labels)target.label=badge(tool,m,w,m.id===opt.selected);
  ctx.restore();
  return targets;
}
