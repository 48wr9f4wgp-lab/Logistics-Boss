import test from 'node:test';
import assert from 'node:assert/strict';
import {floorGesture,changeCamera} from '../../docs/forge-preview/floor-input.mjs';
import {departurePose,departureDuration} from '../../docs/forge-preview/shipping.mjs';

const p=(x,y)=>({x,y});
function input(){
  const changes=[],taps=[];
  const g=floorGesture((a,b,z)=>changes.push([a,b,z]),a=>taps.push(a));
  return {g,changes,taps};
}
test('a tap survives touch jitter, but a drag returning to its starting point cannot select',()=>{
  const {g,changes,taps}=input();
  g.down(1,p(50,60));g.move(1,p(53,62));g.up(1,p(52,62));
  assert.deepEqual(taps,[p(52,62)]);assert.deepEqual(changes,[]);
  g.down(1,p(30,20));g.move(1,p(48,20));g.move(1,p(30,20));g.up(1,p(30,20));
  assert.equal(taps.length,1);assert.equal(changes.length,2);
});
test('multiple fingers zoom around their midpoint and the final finger can pan without a tap',()=>{
  const {g,changes,taps}=input();
  g.down(1,p(80,100));g.down(2,p(120,100));g.move(2,p(140,100));
  assert.deepEqual(changes[0],[p(100,100),p(110,100),1.5]);
  g.up(2,p(140,100));g.move(1,p(84,102));g.up(1,p(84,102));
  assert.deepEqual(changes[1],[p(80,100),p(84,102),1]);assert.equal(taps.length,0);
  g.down(3,p(25,25));g.up(3,p(25,25));assert.deepEqual(taps,[p(25,25)]);
});
test('pointer cancellation, a third finger and duplicate lost-capture events never buy or select',()=>{
  const {g,taps}=input();
  g.down(1,p(1,1));g.down(2,p(1,1));g.down(3,p(3,3));g.move(2,p(2,2));
  g.cancel(2);g.cancel(2);g.up(3,p(3,3));g.up(1,p(1,1));g.down(4,p(3,3));g.reset();g.up(4,p(3,3));
  assert.equal(taps.length,0);
});
test('the zoom anchor survives pan, zoom limits and the return gesture',()=>{
  let c={zoom:1,pan:p(13,-8)};
  const before=structuredClone(c),from=p(180,210),to=p(191,225),center=p(195,300);
  const world={x:(from.x-center.x-c.pan.x)/c.zoom,y:(from.y-center.y-c.pan.y)/c.zoom};
  c=changeCamera(c,from,to,5,390,600);
  assert.equal(c.zoom,2);assert.equal(center.x+c.pan.x+world.x*c.zoom,to.x);assert.equal(center.y+c.pan.y+world.y*c.zoom,to.y);
  assert.deepEqual(changeCamera(c,to,from,.5,390,600),before);
  assert.equal(changeCamera(c,to,to,.01,390,600).zoom,.7);
});
test('dispatch depicts only the dispatched load and settles without affecting the model clock',()=>{
  const box=Object.freeze({product:'plate',qty:12}),shaft=Object.freeze({product:'shaft',qty:6});
  for(const w of [8,10]){
    const idle=departurePose(w,null,0);
    assert.equal(departurePose(w,box,260).cargo,'plate-2');
    assert.equal(departurePose(w,shaft,500).cargo,'shaft-1');
    assert.ok(departurePose(w,box,1100).x>idle.x);
    assert.equal(departurePose(w,box,1750).cargo,null);
    assert.deepEqual(departurePose(w,box,departureDuration),idle);
    assert.deepEqual(departurePose(w,box,500,true),departurePose(w,box,2100,true));
  }
});
