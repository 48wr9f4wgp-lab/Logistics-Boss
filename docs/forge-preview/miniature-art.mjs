// The page keeps the current room only. Each WebP is independent so slow or failed
// artwork never blocks the simulation, picking, or an existing saved factory.
import {crewFrames} from './art/crew-frames-v015.mjs';
import {frames} from './art/machine-frames-v015.mjs';
import {roomFrames} from './art/room-frames-v015.mjs';

export function createArtLoader(){
  const art={machines:null,shipping:null,truck:null,crew:null,room:null,roomWidth:0};
  let requested=0;
  function load(file,accept){
    const picture=new Image();
    picture.src=new URL('./art/'+file,import.meta.url).href;
    picture.decode().then(()=>accept(picture)).catch(()=>{ /* Procedural art is available immediately. */ });
  }
  load('machines-v015.webp',image=>{art.machines=image;});
  load('crew-v015.webp',image=>{art.crew=image;});
  load('shipping-v016.webp',image=>{art.shipping=image;});
  load('truck-v015.webp',image=>{art.truck=image;});
  return width=>{
    if(requested!==width){
      requested=width;art.room=null;art.roomWidth=width;
      load('room-'+width+'-v015.webp',image=>{if(requested===width)art.room=image;});
    }
    return art;
  };
}

export function paintRoom(ctx,view,image,key,x=0,y=0,z=0) {
  const [left,top,width,height]=roomFrames[key],u=view.u;
  ctx.drawImage(image,view.ox+(x-y+left)*u,view.oy+((x+y)*.5+top-z)*u,width*u,height*u);
}

export function paintEquipment(g,m,image,key) {
  const [sx,sy,sw,sh,left,top,width,height]=frames[m.kind+'-'+key];
  const origin=g.p(m.x,m.y),u=g.v.u;
  g.ctx.drawImage(image,sx,sy,sw,sh,origin.x+left*u,origin.y+top*u,width*u,height*u);
}

export function machinePose(kind,active,time){
  if(!active)return {frame:0,phase:0};
  const rate=kind==='lathe' ? .0026 : .004;
  const step=Math.round((time*rate%(2*Math.PI))*24/(2*Math.PI))%24;
  return {frame:step+1,phase:step*(2*Math.PI)/24};
}

// Coordinates here are in the actor's translated and scaled ground frame.
export function paintCrewBust(ctx,image,id,dx,dy,working,stance,sway){
  const facing=Math.abs(dx)>=Math.abs(dy)?(dx>=0?0:2):(dy>=0?1:3);
  const [sx,sy,sw,sh,x,y,w,h]=crewFrames[(id*4+facing)*2+Number(working)];
  ctx.drawImage(image,sx,sy,sw,sh,x+(dx-dy)*stance,y+(dx+dy)*.5*stance-sway,w,h);
}
