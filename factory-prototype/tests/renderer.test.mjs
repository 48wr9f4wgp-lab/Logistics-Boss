import test from 'node:test';
import assert from 'node:assert/strict';
import * as M from '../../docs/forge-preview/model.mjs';
import {project,pickMachine} from '../../docs/forge-preview/view.mjs';
import {drawFactory,sceneViewport,machineSpriteBounds} from '../../docs/forge-preview/renderer.mjs';

// Browser-independent drawing recorder: the rendering contract must remain read-only
// even with a missing asset, and frozen visual time must not move a paused job.
function surface(width=390,height=460){
  const calls=[];
  const ctx=new Proxy({}, {get(target,key){
    if(key==='measureText')return text=>({width:text.length*9});
    if(key==='createLinearGradient'||key==='createRadialGradient')return ()=>({addColorStop(){}});
    if(key in target)return target[key];
    return (...args)=>{for(const value of args)if(typeof value==='number')assert.ok(Number.isFinite(value),`${String(key)} received non-finite coordinate`);calls.push([key,...args]);};
  }});
  return {ctx,calls,canvas:{width,height,getBoundingClientRect:()=>({width,height})}};
}
function freeze(value){if(value&&typeof value==='object'){Object.values(value).forEach(freeze);Object.freeze(value);}return value;}
function workingFactory(){const s=M.fresh();s.cash=20000;assert.equal(M.purchase(s,'lathe',3,0),null);M.accept(s,'first');for(let i=0;i<350;i++)M.step(s,M.TICK);return s;}

test('drawing active and paused jobs is read-only, finite, and paused visual phase stays still',()=>{
  const s=freeze(workingFactory()),before=JSON.stringify(s),a=surface();
  drawFactory(a.ctx,a.canvas,s,{time:100,animate:true,selected:'m1'});
  const b=surface(),c=surface();
  drawFactory(b.ctx,b.canvas,s,{time:1000,animate:false,selected:'m1'});
  drawFactory(c.ctx,c.canvas,s,{time:2000,animate:false,selected:'m1'});
  assert.equal(JSON.stringify(s),before);
  assert.deepEqual(b.calls,c.calls,'paused renderer changed worker/effect coordinates');
  assert.ok(b.calls.length>0);
});

test('initial and expanded factories keep every equipment sprite in view, with body and label picking',()=>{
  for(const [width,height] of [[390,460],[375,300],[1000,600]])for(const expanded of [false,true]){
    const s=workingFactory();if(expanded)M.expand(s);
    const {ctx,canvas}=surface(width,height),{viewport,hitTargets}=drawFactory(ctx,canvas,s,{animate:false});
    assert.equal(hitTargets.length,s.machines.length);
    for(const m of s.machines){
      const r=machineSpriteBounds(viewport,m),target=hitTargets.find(t=>t.id===m.id);
      assert.ok(r.x>=0&&r.y>=0&&r.x+r.w<=width&&r.y+r.h<=height,`${m.kind} outside ${width}x${height}`);
      assert.equal(pickMachine({x:r.x+r.w/2,y:r.y+r.h/2},[target],0),m.id);
      assert.equal(pickMachine({x:target.label.x+target.label.w/2,y:target.label.y+target.label.h/2},[target],0),m.id);
    }
  }
});

test('floor coordinates round-trip through the steeper projection at every zoom and pan',()=>{
  const s=M.fresh();M.expand(s);
  for(const zoom of [.7,1,2]){
    const v=sceneViewport(390,460,s,{zoom,pan:{x:90,y:-50}});
    for(let x=0;x<s.width;x++)for(let y=0;y<s.height;y++){
      const q=project(v,x+.5,y+.5),a=(q.x-v.ox)/v.u,b=(q.y-v.oy)/(v.u*(v.slope??.5));
      assert.deepEqual([Math.floor((a+b)/2),Math.floor((b-a)/2)],[x,y]);
    }
  }
});
