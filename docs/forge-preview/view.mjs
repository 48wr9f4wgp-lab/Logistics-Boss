// Canvas geometry shared by painting and picking; all coordinates are CSS pixels.
export function project(view, x, y, z = 0) {
  return {x: view.ox + (x-y)*view.u, y: view.oy + (x+y)*view.u*.5-z*view.u};
}

export function machineHull(view, m) {
  const x=m.x+.06, y=m.y+.08, w=.88, d=.8;
  const h={cut:1.05,drill:1.25,lathe:1.05,inspect:1.01}[m.kind];
  return [[x,y,h],[x+w,y,h],[x+w,y,0],[x+w,y+d,0],[x,y+d,0],[x,y+d,h]]
    .map(([a,b,z])=>project(view,a,b,z));
}

function edgeDistance(p, a, b) {
  const dx=b.x-a.x,dy=b.y-a.y;
  const t=Math.max(0,Math.min(1,((p.x-a.x)*dx+(p.y-a.y)*dy)/(dx*dx+dy*dy||1)));
  return Math.hypot(p.x-a.x-t*dx,p.y-a.y-t*dy);
}
function distance(p, polygon) {
  let inside=false,nearest=Infinity;
  for(let i=0,j=polygon.length-1;i<polygon.length;j=i++) {
    const a=polygon[j],b=polygon[i];
    if((a.y>p.y)!==(b.y>p.y)&&p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x)inside=!inside;
    nearest=Math.min(nearest,edgeDistance(p,a,b));
  }
  return inside?0:nearest;
}
export function pickMachine(p, targets, tolerance=6) {
  // Targets are in paint order. A true foreground hit wins over a nearby object.
  let nearest=null,best=tolerance;
  for(const target of [...targets].reverse()) {
    const r=target.label;
    const label=r?[{x:r.x,y:r.y},{x:r.x+r.w,y:r.y},{x:r.x+r.w,y:r.y+r.h},{x:r.x,y:r.y+r.h}]:null;
    const d=Math.min(distance(p,target.hull),label?distance(p,label):Infinity);
    if(d<.001)return target.id;
    if(d<best){best=d;nearest=target.id;}
  }
  return nearest;
}
