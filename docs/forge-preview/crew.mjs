import {paintCrewBust} from './miniature-art.mjs?v=0.15';
// Screen-space figure painting in a local, ground-facing frame. Units are tile units.
const TAU=Math.PI*2;
const uniforms=[
  {cloth:'#326684',shade:'#203f58',light:'#83a9b5',cap:'#ecc362'},
  {cloth:'#ab6c48',shade:'#684334',light:'#e5ad77',cap:'#d2d1b9'},
  {cloth:'#3b847b',shade:'#244f51',light:'#8fb6a0',cap:'#ebbb5b'}
];

function facing(w,visual) {
  const walking=visual.phase==='pickup'||visual.phase==='carry';
  const next=walking?w.job.path[0]:null;
  const dx=next?next.x-w.x:0,dy=next?next.y-w.y:0;
  const length=Math.hypot(dx,dy);
  if(length>.001)return [dx/length,dy/length];
  if(visual.machine)return [0,-1]; // All stations are operated from their +y side.
  return w.id===1?[0,1]:[1,0];
}

export function drawCrewMember(g,w,visual,opt,contact) {
  const {ctx,v,p}=g,foot=p(w.x+.45,w.y+.45),u=v.u;
  const [dx,dy]=facing(w,visual),horizontal=dx-dy,depth=dx+dy;
  const near=dx-dy>=0?1:-1,back=depth<0,look=Math.sign(horizontal)||1;
  const carry=visual.phase==='carry',work=visual.phase==='work',walk=carry||visual.phase==='pickup';
  // Feet alternate with real distance travelled. Reloading at the same place restores the pose.
  const stride=walk&&!opt.reducedMotion?Math.sin((w.x+w.y)*Math.PI*2+w.id*2):0;
  const sway=walk?Math.abs(stride)*.036:0,stance=work ? .24 : 0;
  const lean=work ? .13 : carry ? .06 : .018;
  const colors=uniforms[w.id%uniforms.length];
  const local=(side,ahead,z)=>[
    -depth*side+horizontal*ahead,
    .5*(horizontal*side+depth*ahead)-z
  ];
  const target=q=>[(q.x-foot.x)/u,(q.y-foot.y)/u];
  const ellipse=(x,y,rx,ry,color,tilt=0)=>{
    ctx.fillStyle=color;ctx.beginPath();ctx.ellipse(x,y,rx,ry,tilt,0,TAU);ctx.fill();
  };
  const stroke=(points,color,width)=>{
    ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';
    ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.stroke();
  };
  function fabric(from,to,base,light,shade,radius){
    const vx=to[0]-from[0],vy=to[1]-from[1],len=Math.hypot(vx,vy)||1;
    let nx=-vy/len,ny=vx/len;
    if(nx+ny*.4<0){nx=-nx;ny=-ny;}
    const gradient=ctx.createLinearGradient(from[0]-nx*radius,from[1]-ny*radius,from[0]+nx*radius,from[1]+ny*radius);
    gradient.addColorStop(0,light);gradient.addColorStop(.40,base);gradient.addColorStop(1,shade);
    return gradient;
  }
  function footfall(side){
    const step=stride*side,ground=local(side*.115,stance+step*.18+.035,0);
    const planted=Math.max(0,-step);
    ellipse(ground[0]+.017,ground[1]+.015,.115,.045,'rgba(39,51,47,'+(.43-planted*.24)+')',horizontal*depth*.22);
  }
  function leg(side){
    const step=stride*side;
    const hip=local(side*.095,stance,.40+sway),knee=local(side*.105,stance+step*.095+.025,.21+Math.max(0,step)*.03);
    const ankle=local(side*.115,stance+step*.18,.074+Math.max(0,-step)*.065);
    const toe=local(side*.115,stance+step*.18+.11,.04+Math.max(0,-step)*.065);
    stroke([hip,knee,ankle],side===near?'#374c53':'#283e48',.125);
    stroke([hip,knee],side===near?'#617378':'#4a6068',.078);
    const leather=ctx.createLinearGradient(0,ankle[1]-.055,0,toe[1]+.04);
    leather.addColorStop(0,'#8b785c');leather.addColorStop(.46,'#594f43');leather.addColorStop(1,'#343a3a');
    stroke([ankle,toe],leather,.114);
  }
  const getHand=side=>{
    if(work&&contact)return target(side===1?contact.right:contact.left);
    if(carry)return local(side*.22,stance+.27,.47+sway);
    return local(side*.205,stance+stride*side*-.19+.045,.39+sway);
  };
  function arm(side){
    const shoulder=local(side*.14,stance+lean,.69+sway),hand=getHand(side);
    const elbow=work?[shoulder[0]+(hand[0]-shoulder[0])*.52-look*.042,shoulder[1]+(hand[1]-shoulder[1])*.48+.115]:
      local(side*.205,stance+(carry ? .11 : -stride*side*.095),.48+sway);
    stroke([shoulder,elbow,hand],colors.shade,.126);
    stroke([shoulder,elbow],fabric(shoulder,elbow,colors.cloth,colors.light,colors.shade,.06),.12);
    const cuff=[elbow[0]+(hand[0]-elbow[0])*.82,elbow[1]+(hand[1]-elbow[1])*.82];
    stroke([elbow,cuff],fabric(elbow,cuff,colors.cloth,colors.light,colors.shade,.048),.098);
    stroke([cuff,hand],colors.shade,.082);
    ellipse(hand[0],hand[1],.052,.048,'#dbaf85');
  }
  function torso(){
    const hip=local(0,stance,.37+sway),top=local(0,stance+lean,.71+sway);
    const cx=top[0],cy=top[1],hx=hip[0],hy=hip[1];
    const coat=ctx.createLinearGradient(cx-.19,cy,cx+.17,hy);
    coat.addColorStop(0,colors.light);coat.addColorStop(.42,colors.cloth);coat.addColorStop(1,colors.shade);
    ctx.beginPath();ctx.moveTo(cx-.12,cy-.025);
    ctx.bezierCurveTo(cx-.195,cy+.004,cx-.205,cy+.085,hx-.145,hy-.015);
    ctx.quadraticCurveTo(hx,hy+.055,hx+.145,hy);
    ctx.bezierCurveTo(hx+.17,hy-.09,cx+.21,cy+.045,cx+.115,cy-.02);
    ctx.quadraticCurveTo(cx,cy-.055,cx-.12,cy-.025);ctx.fillStyle=coat;ctx.fill();
    stroke([[hx-.127,hy-.026],[hx+.126,hy-.014]],colors.shade,.026);
    if(back){
      stroke([[cx-.12,cy+.075],[cx,cy+.095],[cx+.125,cy+.075]],colors.light,.021);
      stroke([[cx,cy+.12],[hx,hy-.06]],colors.cloth,.018);
      stroke([[hx-.10,hy-.082],[hx-.04,hy-.074]],colors.light,.018);
    }else{
      const center=cx+look*.045;
      stroke([[center-.065,cy],[center,cy+.07],[center+.045,cy+.012]],'#e2d9b8',.031);
      stroke([[center,cy+.074],[hx+look*.045,hy-.04]],colors.shade,.018);
      stroke([[cx-look*.10,cy+.13],[cx-look*.025,cy+.14]],colors.light,.035);
    }
    for(let i=1;i<w.skill;i++)stroke([[cx-.12+i*.035,cy+.11],[cx-.12+i*.035,cy+.15]],'#f0d7a0',.018);
  }
  function head(){
    const [x,y]=local(0,stance+lean+(work ? .058 : 0),.86+sway-(work ? .025 : 0));
    const skin=ctx.createLinearGradient(x-.12,y,x+.12,y+.09);
    skin.addColorStop(0,'#ffe0ae');skin.addColorStop(.5,'#d6a67f');skin.addColorStop(1,'#a77559');
    ellipse(x,y+.015,.125,.14,skin);
    ctx.beginPath();ctx.moveTo(x-look*.112,y-.047);ctx.lineTo(x+look*(back ? .062 : -.015),y-.045);
    ctx.quadraticCurveTo(x+look*(back ? .065 : -.005),y+.041,x-look*.015,y+.085);
    ctx.quadraticCurveTo(x-look*.145,y+.085,x-look*.112,y-.047);ctx.fillStyle='#675346';ctx.fill();
    ellipse(x-look*.045,y+.040,.030,.040,'#c69571');
    ellipse(x+look*.115,y+.034,.029,.033,'#dcaf81');
    if(!back)ellipse(x+look*.08,y+.009,.014,.014,'#594f49');
    const cap=ctx.createLinearGradient(x-.15,y-.14,x+.14,y);
    cap.addColorStop(0,'#fff0c6');cap.addColorStop(.45,colors.cap);cap.addColorStop(1,w.id===1?'#899999':'#b37d3c');
    ctx.fillStyle=cap;ctx.beginPath();ctx.ellipse(x,y-.052,.165,.138,-.10,Math.PI,TAU);ctx.fill();
    ellipse(x+look*.024,y-.047,.191,.049,cap,look*(back?-.10:.10));
    stroke([[x-.084,y-.14],[x-.027,y-.168],[x+.02,y-.166]],'#fff1c888',.02);
    if(back)stroke([[x-.089,y+.038],[x+.045,y+.052]],'#6a574b',.028);
  }
  function carriedPart(){
    const a=getHand(-1),b=getHand(1),mx=(a[0]+b[0])/2,my=(a[1]+b[1])/2-.02;
    // Keep a broad three-quarter silhouette at either isometric heading.
    const d=look*.20,outline=[[mx-.25,my-d*.39],[mx+.12,my-d*.70],[mx+.25,my+d*.39],[mx-.12,my+d*.70]];
    if(visual.part.product==='shaft'){
      const from=[mx-.29,my-look*.064],to=[mx+.29,my+look*.064];
      stroke([from,to],'#536e7a',.111);
      stroke([[from[0],from[1]-.027],[to[0],to[1]-.027]],'#d9e8e0',.046);
      ellipse(to[0],to[1],.035,.054,'#82969c',-.18);
    }else{
      const steel=ctx.createLinearGradient(mx-.2,my-.11,mx+.2,my+.12);
      steel.addColorStop(0,'#f3f0d5');steel.addColorStop(.46,'#c6d7d3');steel.addColorStop(1,'#86a7ac');
      ctx.beginPath();outline.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();
      ctx.fillStyle=steel;ctx.fill();ctx.strokeStyle='#4a6773';ctx.lineWidth=.029;ctx.stroke();
      if(visual.part.stage>=2)for(const side of [-1,1])ellipse(mx+side*.12,my+side*d*.19,.024,.015,'#415f69');
    }
  }
  g.softShadow(w.x+.49+stance*dx,w.y+.45+stance*dy,.31,.14,.40);
  ctx.save();ctx.translate(foot.x,foot.y);ctx.scale(u,u);
  footfall(-near);footfall(near);leg(-near);leg(near);
  arm(-near);
  if(carry&&back)carriedPart();
  if(opt.art?.crew){
    paintCrewBust(ctx,opt.art.crew,w.id,dx,dy,work,stance,sway);
    const shoulder=local(-.10,stance+lean,.63+sway);
    for(let i=1;i<w.skill;i++){
      const x=shoulder[0]+(i-1)*.036;
      stroke([[x,shoulder[1]],[x+.016,shoulder[1]-.035]],'#f0d7a0',.018);
    }
  }else{torso();head();}
  if(carry&&!back)carriedPart();
  arm(near);ctx.restore();
}
