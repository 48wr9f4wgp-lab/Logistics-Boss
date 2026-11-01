import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {frames} from '../../docs/forge-preview/art/machine-frames-v017.mjs';
import {crewFrames} from '../../docs/forge-preview/art/crew-frames-v017.mjs';
import {stationFrames} from '../../docs/forge-preview/art/station-frames-v017.mjs';
import {createArtLoader,crewFacing,machinePose,partFrame} from '../../docs/forge-preview/miniature-art.mjs';

function bounds(file,rects){
  const bytes=readFileSync(new URL('../../docs/forge-preview/art/'+file,import.meta.url));
  assert.equal(bytes.toString('ascii',12,16),'VP8X');
  const w=1+bytes.readUIntLE(24,3),h=1+bytes.readUIntLE(27,3);
  for(const [x,y,width,height,...target] of rects){
    assert.ok(width>0&&height>0&&x>=0&&y>=0&&x+width<=w&&y+height<=h);
    assert.ok(target.length===4&&target.every(Number.isFinite)&&target[2]>0&&target[3]>0);
  }
}
test('every machine variant, cast shadow, motion phase and crew bust lands inside its shipped atlas',()=>{
  for(const k of ['cut','drill','lathe','inspect']){
    for(let f=0;f<=24;f++)assert.ok(frames[k+'-F'+f]);
    for(let l=1;l<=3;l++)assert.ok(frames[k+'-L'+l]);
    assert.ok(frames[k+'-shadow']);
  }
  bounds('machines-v017.webp',Object.values(frames));
  assert.equal(crewFrames.length,3*4*2);
  bounds('crew-v017.webp',crewFrames);
});
test('hand and mechanism share one sample of the motion cycle, including across its wrap',()=>{
  for(const k of ['cut','drill','lathe','inspect']){
    assert.deepEqual(machinePose(k,false,876),{frame:0,phase:0});
    const seen=new Set();
    for(let t=0;t<3000;t+=8){
      const v=machinePose(k,true,t);
      assert.equal(v.phase,(v.frame-1)*Math.PI*2/24);
      seen.add(v.frame);
    }
    assert.equal(seen.size,24);
  }
});

test('finished plate holes and turned shaft profiles follow their actual saved stage',()=>{
  for(const product of ['plate','shaft']){
    const keys=[0,1,2].map(stage=>partFrame(JSON.parse(JSON.stringify({product,stage}))));
    assert.equal(new Set(keys).size,3);
    for(const key of keys)assert.ok(stationFrames[key]);
  }
  for(const kind of ['cut','drill','lathe','inspect'])assert.ok(stationFrames[kind]);
  for(const [index,[x,y]] of [[1,0],[0,1],[-1,0],[0,-1]].entries()){
    assert.equal(crewFacing(x,y),index);
    for(const working of [0,1])assert.ok(stationFrames['shadow-'+index+'-'+working]);
  }
  bounds('station-v017.webp',Object.values(stationFrames));
});

test('late room loads cannot overwrite an expanded factory and a missing station atlas is optional',async()=>{
  const loads=new Map();
  class Asset {
    decode(){return new Promise((resolve,reject)=>loads.set(this.src.split('/').pop(),{image:this,resolve,reject}));}
  }
  const loader=createArtLoader(Asset),art=loader(8);
  assert.equal(loader(10),art);
  const expanded=loads.get('room-10-v017.webp');
  expanded.resolve();
  loads.get('room-8-v017.webp').resolve();
  loads.get('station-v017.webp').reject(new Error('offline'));
  loads.get('machines-v017.webp').resolve();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(art.roomWidth,10);
  assert.equal(art.room,expanded.image);
  assert.equal(art.station,null);
  assert.equal(art.machines,loads.get('machines-v017.webp').image);
});
