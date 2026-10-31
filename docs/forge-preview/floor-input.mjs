// The midpoint before a pinch stays under the new midpoint, even on a panned floor.
export function changeCamera(camera,from,to,ratio,width,height){
  const zoom=Math.max(.7,Math.min(2,camera.zoom*ratio)),scale=zoom/camera.zoom;
  const offset=(old,start,end,center,limit)=>{
    const value=end-center-(start-center-old)*scale;
    return Math.max(-limit,Math.min(limit,value));
  };
  return {zoom,pan:{
    x:offset(camera.pan.x,from.x,to.x,width/2,width*.55*zoom),
    y:offset(camera.pan.y,from.y,to.y,height/2,Math.min(height*.52,width*.47*zoom))
  }};
}

const distance=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
const middle=(a,b)=>({x:(a.x+b.x)/2,y:(a.y+b.y)/2});

// The whole contact sequence loses its tap as soon as it becomes a drag or a pinch.
// Lifting one finger rebases the remaining finger at its current position.
export function floorGesture(change,tap){
  const points=new Map();
  let start=null;
  function down(id,p){
    points.set(id,p);
    start=points.size===1?p:null;
  }
  function move(id,p){
    const old=points.get(id);
    if(!old)return;
    points.set(id,p);
    if(points.size===1){
      if(start&&distance(start,p)<8)return;
      change(start||old,p,1);start=null;
    }else if(points.size===2){
      const other=[...points].find(([key])=>key!==id)[1];
      const before=distance(old,other),after=distance(p,other);
      change(middle(old,other),middle(p,other),before>=4&&after>=4?after/before:1);
    }
  }
  function up(id,p){
    if(!points.has(id))return;
    const select=points.size===1&&start&&distance(start,p)<8;
    if(!select&&distance(points.get(id),p)>0)move(id,p);
    points.delete(id);start=null;
    if(select)tap(p);
  }
  function cancel(id){if(points.delete(id))start=null;}
  return {down,move,up,cancel,reset(){points.clear();start=null;}};
}
