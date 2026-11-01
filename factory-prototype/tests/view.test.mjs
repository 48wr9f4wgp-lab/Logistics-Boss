import {roomFrames} from '../../docs/forge-preview/art/room-frames-v017.mjs';
import {frameWorkshop} from '../../docs/forge-preview/view.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {project,machineHull,pickMachine} from '../../docs/forge-preview/view.mjs';

const view={u:30,ox:180,oy:90};
const drill={id:'drill',kind:'drill',x:3,y:1};
const target=(m,v=view)=>({id:m.id,hull:machineHull(v,m)});

test('raised top and front faces select the machine even outside its floor cell',()=>{
  const top=project(view,3.5,1.5,1.2),front=project(view,3.5,1.85,.6);
  // The old floor-only inverse projection maps this visible top to a different tile.
  const a=(top.x-view.ox)/view.u,b=(top.y-view.oy)/(view.u*.5);
  assert.notDeepEqual([Math.floor((a+b)/2),Math.floor((b-a)/2)],[3,1]);
  assert.equal(pickMachine(top,[target(drill)],0),'drill');
  assert.equal(pickMachine(front,[target(drill)],0),'drill');
});

test('picking follows zoom and pan without selecting the old screen position',()=>{
  const moved={u:55,ox:80,oy:220},t=target(drill,moved);
  assert.equal(pickMachine(project(moved,3.5,1.5,.5),[t]),'drill');
  assert.equal(pickMachine(project(view,3.5,1.5,.5),[t]),null);
});

test('labels and overlapping bodies use the foreground paint order',()=>{
  const back={...target(drill),label:{x:240,y:90,w:50,h:18}};
  const front={...target(drill),id:'front'};
  assert.equal(pickMachine(project(view,3.5,1.5,.6),[back,front]),'front');
  assert.equal(pickMachine({x:285,y:95},[back,front]),'drill');
});

test('small edge tolerance does not override a real hit or select distant floor',()=>{
  const a={id:'a',hull:[{x:0,y:0},{x:10,y:0},{x:10,y:10},{x:0,y:10}]};
  const b={id:'b',hull:a.hull.map(p=>({x:p.x+15,y:p.y}))};
  assert.equal(pickMachine({x:11,y:5},[a,b]),'a');
  assert.equal(pickMachine({x:9,y:5},[a,b]),'a');
  assert.equal(pickMachine({x:32,y:5},[a,b]),null);
  assert.equal(pickMachine({x:5,y:5},[]),null);
});

test('visible nameplates select their machine above foreground machine bodies',()=>{
  const back={id:'back',hull:[{x:0,y:0},{x:10,y:0},{x:10,y:10},{x:0,y:10}],label:{x:20,y:20,w:20,h:12}};
  const front={id:'front',hull:[{x:20,y:20},{x:50,y:20},{x:50,y:50},{x:20,y:50}]};
  assert.equal(pickMachine({x:25,y:25},[back,front]),'back');
  assert.equal(pickMachine({x:41,y:25},[back,front]),'front','label tolerance cannot steal a real body hit');
  front.label={x:24,y:22,w:20,h:12};
  assert.equal(pickMachine({x:28,y:26},[back,front]),'front','last painted label wins');
});


test('the overview fits the physical plinth and rooftop in both rooms at phone sizes',()=>{
  for(const room of [8,10])for(const [w,h] of [[320,305],[390,623],[844,190]]){
    const v=frameWorkshop(w,h,room),[x,y,width,height]=roomFrames['room-'+room];
    assert.ok(v.u>0);
    assert.ok(v.ox+x*v.u>=5.99&&v.ox+(x+width)*v.u<=w-5.99);
    assert.ok(v.oy+y*v.u>=24.99&&v.oy+(y+height)*v.u<=h-24.99);
    const zoomed=frameWorkshop(w,h,room,2,{x:23,y:-14});
    assert.equal(zoomed.u,2*v.u);
    assert.ok(Math.abs(zoomed.ox-(w/2+2*(v.ox-w/2)+23))<1e-9);
    assert.ok(Math.abs(zoomed.oy-(h/2+2*(v.oy-h/2)-14))<1e-9);
  }
});
