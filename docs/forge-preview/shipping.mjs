import {shippingFrames} from './art/shipping-frames-v016.mjs';

export const departureDuration=2400;
const clamp=value=>Math.max(0,Math.min(1,value));
const ease=value=>value*value*(3-2*value);

// An illustration of one committed shipment. No clocks, orders or cash are modified here.
export function departurePose(width,load,elapsed,reducedMotion=false){
  const parked=width*.28;
  const idle={x:parked,alpha:1,cargo:null};
  if(!load||elapsed>=departureDuration)return idle;
  const cargo=load.product+'-'+(load.qty>6?2:1);
  if(reducedMotion)return {...idle,cargo};
  const t=Math.max(0,elapsed);
  if(t<1550){
    const progress=ease(clamp((t-320)/1230));
    return {x:parked+(width-1.76-parked)*progress,
      alpha:1-ease(clamp((t-1230)/320)),cargo};
  }
  const arriving=ease(clamp((t-1600)/800));
  return {x:.12+(parked-.12)*arriving,alpha:ease(clamp((t-1600)/280)),cargo:null};
}

export function paintCargo(g,image,key,x,y,z=0,scale=1){
  const [sx,sy,sw,sh,left,top,width,height]=shippingFrames[key];
  const origin=g.p(x,y,z),u=g.v.u*scale;
  g.ctx.drawImage(image,sx,sy,sw,sh,origin.x+left*u,origin.y+top*u,width*u,height*u);
}
