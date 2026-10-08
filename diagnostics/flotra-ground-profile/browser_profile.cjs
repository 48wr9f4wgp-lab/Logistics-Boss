#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {chromium} = require('playwright');
const {PNG} = require('pngjs');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const quantile = (values,q) => {
  assert.ok(values.length > 0,'Nonempty timing sample');
  const sorted=[...values].sort((a,b)=>a-b);
  return sorted[Math.min(sorted.length-1,Math.floor(sorted.length*q))];
};
function summarize(raw,minimumSamples) {
  assert.ok(raw.frames.length >= minimumSamples,'Enough post-warmup RAF samples for the fixed phase');
  assert.ok(raw.frames.every(x=>Number.isFinite(x)&&x>0),'Valid RAF durations');
  assert.ok(raw.telemetry.length===raw.frames.length,'One telemetry sample per RAF sample');
  assert.ok(Number.isFinite(raw.elapsedMs)&&raw.elapsedMs>0,'Valid total sample duration');
  for(const metric of raw.telemetry)for(const key of ['processMs','drawCalls','primitives'])
    assert.ok(Number.isFinite(metric[key])&&metric[key]>=0,`Finite nonnegative ${key} telemetry`);
  return {samples:raw.frames.length,elapsedMs:raw.elapsedMs,
    rafMedianMs:quantile(raw.frames,.5),rafP95Ms:quantile(raw.frames,.95),
    processMedianMs:quantile(raw.telemetry.map(x=>x.processMs),.5),
    processP95Ms:quantile(raw.telemetry.map(x=>x.processMs),.95),
    drawCallsMin:Math.min(...raw.telemetry.map(x=>x.drawCalls)),
    drawCallsMax:Math.max(...raw.telemetry.map(x=>x.drawCalls)),
    primitivesMedian:quantile(raw.telemetry.map(x=>x.primitives),.5)};
}
function decision(near,normal) {
  const A=[near.A1,near.A2],B=[near.B1,near.B2];
  const minA=Math.min(...A.map(x=>x.rafMedianMs)),maxA=Math.max(...A.map(x=>x.rafMedianMs));
  const worstB=Math.max(...B.map(x=>x.rafMedianMs));
  const bracketDrift=(maxA-minA)/minA;
  const normalDrift=Math.abs(normal.B.rafMedianMs-normal.A.rafMedianMs)/Math.min(normal.A.rafMedianMs,normal.B.rafMedianMs);
  const variation=Math.max(bracketDrift,normalDrift);
  const conservativeGain=(minA-worstB)/minA;
  const requiredGain=Math.max(.05,2*variation);
  const p95Nonregression=Math.max(...B.map(x=>x.rafP95Ms))<=Math.min(...A.map(x=>x.rafP95Ms));
  const healthy=variation<=.10;
  const supports=healthy&&conservativeGain>=requiredGain&&p95Nonregression;
  return {outcome:!healthy?'inconclusive_control_variation':supports?'supports_ground_only_partition_experiment':'reject_partition_for_unproven_benefit',
    supportsFurtherPartitionExperiment:supports,bracketDrift,normalDrift,variation,
    conservativeGain,requiredGain,p95Nonregression,
    rule:'Predeclared: control variation≤10%; worstB median improves over bestA median by at leastmax(5%,2×variation); worstB p95≤bestA p95. These are diagnostic evidence criteria, not changed release gates.'};
}
// Fast deterministic checks can run without launching a browser.
if(process.argv[2]==='--self-test') {
  const p=(m,p95=m*1.1)=>({rafMedianMs:m,rafP95Ms:p95});
  assert.equal(decision({A1:p(100),A2:p(101),B1:p(90),B2:p(91)},{A:p(80),B:p(81)}).supportsFurtherPartitionExperiment,true);
  assert.equal(decision({A1:p(100),A2:p(102),B1:p(98),B2:p(97)},{A:p(80),B:p(81)}).supportsFurtherPartitionExperiment,false);
  assert.equal(decision({A1:p(100),A2:p(125),B1:p(70),B2:p(71)},{A:p(80),B:p(81)}).outcome,'inconclusive_control_variation');
  assert.equal(decision({A1:p(100,110),A2:p(101,111),B1:p(90,120),B2:p(90,120)},{A:p(80),B:p(81)}).supportsFurtherPartitionExperiment,false);
  assert.equal(decision({A1:p(100),A2:p(101),B1:p(80),B2:p(99)},{A:p(80),B:p(81)}).supportsFurtherPartitionExperiment,false);
  const raw={elapsedMs:600,frames:Array(35).fill(16),telemetry:Array.from({length:35},()=>({processMs:1,drawCalls:70,primitives:9000}))};
  assert.equal(summarize(raw,30).samples,35);
  for(const key of ['processMs','drawCalls','primitives'])for(const invalid of [NaN,-1,undefined]) {
    const copy={...raw,telemetry:raw.telemetry.map(x=>({...x}))};copy.telemetry[0][key]=invalid;
    assert.throws(()=>summarize(copy,30));
  }
  console.log('GROUND_PROFILE_DECISION_SELF_TEST_PASS (5 decision cases,1 valid sample,9 invalid-metric cases)');
  process.exit(0);
}
const url=new URL(process.argv[2]);url.searchParams.set('phone_qa','1');
const output=process.argv[3];assert.ok(output,'Evidence directory required');fs.mkdirSync(output,{recursive:true});
const report={scope:'One causal, paused, fixed-snapshot software-Chromium diagnostic. Best-case removal of fully offscreen ground cubes, not a production partition, release qualification, active-simulation measurement or device claim.',
  configuration:{viewport:{width:390,height:844},dpr:3,marginCssPixels:4,nearOrder:['A1','B1','B2','A2'],nearSampleMs:30000,normalSampleMs:15000,settleMs:2000,discardFirstFrames:5,
    controlVariationLimit:.10,minimumBenefit:.05,benefitNoiseMultiplier:2,p95Rule:'worstB≤bestA',retries:0},
  parity:[],phases:[],errors:[]};
const save=()=>fs.writeFileSync(path.join(output,'ground-profile.json'),JSON.stringify(report,null,2));
(async()=>{
  let browser;
  try {
    browser=await chromium.launch({headless:true});
    report.chromiumVersion=browser.version();
    assert.match(report.chromiumVersion,/^151\./,'Use the established Chromium151 environment; do not silently substitute');
    const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:3,isMobile:true,hasTouch:true});
    const page=await context.newPage();
    page.on('pageerror',e=>report.errors.push(e.message));
    page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
    await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:60000});
    await page.waitForFunction(()=>window.FlotraGroundProfileState?.ready,null,{timeout:120000});
    report.environment=await page.evaluate(()=>{
      const canvas=document.querySelector('#canvas'),gl=canvas.getContext('webgl2');
      const ext=gl.getExtension('WEBGL_debug_renderer_info');
      return {renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,
        vendor:ext?gl.getParameter(ext.UNMASKED_VENDOR_WEBGL):null,dpr:devicePixelRatio,
        width:innerWidth,height:innerHeight,canvasWidth:canvas.width,canvasHeight:canvas.height,
        canvasRect:canvas.getBoundingClientRect().toJSON(),engine:window.FlotraViewport?.engineMetrics,
        visibility:document.visibilityState};
    });
    const e=report.environment;
    assert.equal(e.dpr,3);assert.equal(e.width,390);assert.equal(e.height,844);
    assert.equal(e.canvasWidth,1170);assert.equal(e.canvasHeight,2532);
    assert.equal(e.engine.logicalWidth,390);assert.equal(e.engine.logicalHeight,844);
    assert.equal(e.visibility,'visible');assert.match(e.renderer,/SwiftShader/,'Established software renderer');
    const anchors=new Map();
    async function command(name) {
      const previous=await page.evaluate(()=>window.FlotraGroundProfileState.sequence);
      await page.evaluate(name=>window.FlotraGroundProfileInvoke(name),name);
      await page.waitForFunction(previous=>window.FlotraGroundProfileState.sequence>previous,previous,{timeout:10000});
      const state=await page.evaluate(()=>window.FlotraGroundProfileState);
      assert.deepEqual(state.failures,[],'Native diagnostic invariants');
      assert.equal(state.originalCount,383,'Pinned mature fixture has exactly383 ground instances');
      assert.ok(state.variant==='A'||state.variant==='B','Known actual variant');
      assert.equal(state.actualVisibleCount,state.variant==='A'?383:state.retainedCount,'Actual submitted count matches requested variant');
      if(name==='A'||name==='B')assert.equal(state.variant,name,'Variant command took effect');
      assert.deepEqual(state.invariants,state.anchor,'Exact camera/domain/quality/caster parity');
      assert.equal(state.invariants.paused,true);assert.equal(state.invariants.savingDisabled,true);
      if(anchors.has(state.view))assert.deepEqual(state.anchor,anchors.get(state.view),'View anchor returns exactly');
      else anchors.set(state.view,state.anchor);
      return state;
    }
    async function pixels(name) {
      await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      const file=path.join(output,name+'.png');
      const bytes=await page.locator('#canvas').screenshot({path:file});
      const png=PNG.sync.read(bytes);
      return {name,width:png.width,height:png.height,rgbaSha256:sha(png.data),data:png.data};
    }
    // No performance sampling begins unless both views pass exact A→B→A pixels.
    for(const view of ['normal','near']) {
      const initial=await command(view);
      if(view==='normal')assert.equal(initial.retainedCount,initial.originalCount,'Overview is a true no-culling negative control');
      else assert.ok(initial.retainedCount<initial.originalCount,'Near variant removes actual offscreen geometry');
      const captures=[];
      const parity={view,passed:false,captures:[]};report.parity.push(parity);save();
      for(const v of ['A','B','A']) {
        const state=await command(v);await page.waitForTimeout(1000);
        const frame=await pixels(`${view}-parity-${v}-${captures.length}`);
        captures.push({state,...frame});
        const {data,...record}=captures[captures.length-1];parity.captures.push(record);
        save();
      }
      assert.equal(captures[0].width,1170);assert.equal(captures[0].height,2532);
      for(const capture of captures.slice(1)) {
        assert.equal(capture.width,captures[0].width);assert.equal(capture.height,captures[0].height);
        assert.ok(capture.data.equals(captures[0].data),`${view}: exact full-DPR RGBA visual parity`);
      }
      parity.passed=true;save();
    }
    async function sample(label,variant,milliseconds) {
      const before=await command(variant);await page.waitForTimeout(2000);
      const phase={label,view:before.view,variant,before,status:'sampling'};
      report.phases.push(phase);save();
      const raw=await page.evaluate(ms=>new Promise(resolve=>{
        let start=performance.now(),last=start;const frames=[],telemetry=[];
        function frame(now) {
          frames.push(now-last);last=now;
          telemetry.push({...window.FlotraGroundProfileTelemetry});
          if(now-start<ms)requestAnimationFrame(frame);
          else resolve({elapsedMs:now-start,frames:frames.slice(5),telemetry:telemetry.slice(5)});
        }
        requestAnimationFrame(frame);
      }),milliseconds);
      phase.raw=raw;phase.status='sampled_unvalidated';save();
      const after=await command('status');
      phase.after=after;save();
      assert.deepEqual(after.invariants,before.invariants,'No state drift during timing');
      const summary=summarize(raw,milliseconds>=30000?30:15);
      phase.summary=summary;phase.status='validated';save();
      assert.deepEqual(report.errors,[],'No runtime errors');
      return summary;
    }
    const near={};
    await command('near');
    for(const label of ['A1','B1','B2','A2'])near[label]=await sample(label,label[0],30000);
    await command('normal');
    const normal={A:await sample('normal-A','A',15000),B:await sample('normal-B','B',15000)};
    const final=await command('A');
    assert.equal(final.actualVisibleCount,final.originalCount,'Original ground restored');
    report.decision=decision(near,normal);report.summary={near,normal};report.completed=true;
    console.log(JSON.stringify(report.decision,null,2));save();
  } catch(error) {
    report.completed=false;report.blocker=error.stack;save();throw error;
  } finally { if(browser)await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
