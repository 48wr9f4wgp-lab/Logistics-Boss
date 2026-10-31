import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {frames} from '../../docs/forge-preview/art/machine-frames-v015.mjs';
import {crewFrames} from '../../docs/forge-preview/art/crew-frames-v015.mjs';
import {machinePose} from '../../docs/forge-preview/miniature-art.mjs';

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
  bounds('machines-v015.webp',Object.values(frames));
  assert.equal(crewFrames.length,3*4*2);
  bounds('crew-v015.webp',crewFrames);
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
