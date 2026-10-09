'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { verify, readPinnedManifest } = require('./source_export_contract.cjs');
const hash = p => crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flotra-source-export-contract-'));
  const m = {kind:'flotra-source-export-pair-v1',godot:'4.7.2.stable.official.ed1daf0bf',controlCommit:'a'.repeat(40),candidateCommit:'b'.repeat(40),controlQualification:{status:'pass',rule:'prospective_generated_scene_ids_only; committed PCK remains browser subject'},variants:{}};
  for (const label of ['A','B']) {
    const source = path.join(root,label,'source');const web = path.join(root,label,'web');
    fs.mkdirSync(path.join(source,'flotra-campaign'),{recursive:true});fs.mkdirSync(web,{recursive:true});
    fs.writeFileSync(path.join(source,'flotra-campaign/project.godot'),label);
    const names=['index.html','index.js','index.wasm','index.pck','campaign-viewport.js','dispatch-storage.js'];
    for(const n of names)fs.writeFileSync(path.join(web,n),n==='index.html'?'<script src="campaign-viewport.js"></script><script src="dispatch-storage.js"></script><script src="index.js"></script>':label+n);
    const assets=Object.fromEntries(names.map(n=>[n,hash(path.join(web,n))]));
    m.variants[label]={commit:label==='A'?m.controlCommit:m.candidateCommit,sourceDirectory:source,exportDirectory:web,sourceSHA256:{'flotra-campaign/project.godot':hash(path.join(source,'flotra-campaign/project.godot'))},assetsSHA256:{...assets},allExportAssetsSHA256:{...assets}};
  }
  m.controlQualification.checks={runtimeSourcesMatchManifest:true};
  m.controlQualification.sceneChecks={exactApprovedSceneSet:true};
  m.controlQualification.actual={...m.variants.A.assetsSHA256};
  m.harnessSHA256={'flotra-campaign/tests/release/source_export_contract.cjs':hash(path.join(__dirname,'source_export_contract.cjs'))};
  return {root,m,check:()=>verify(m,m.controlCommit,m.candidateCommit,m.variants.A.exportDirectory,m.variants.B.exportDirectory)};
}
function scenario(name,mutate,rejected=true){test(name,()=>{const f=fixture();try{mutate(f);if(rejected)assert.throws(f.check);else f.check();}finally{fs.rmSync(f.root,{recursive:true,force:true});}});}
scenario('Exact attested pair accepted',()=>{},false);
scenario('Changed candidate PCK rejected',f=>fs.appendFileSync(path.join(f.m.variants.B.exportDirectory,'index.pck'),'mutation'));
scenario('Control/candidate pack substitution rejected',f=>fs.copyFileSync(path.join(f.m.variants.A.exportDirectory,'index.pck'),path.join(f.m.variants.B.exportDirectory,'index.pck')));
scenario('Changed source after export rejected',f=>fs.appendFileSync(path.join(f.m.variants.B.sourceDirectory,'flotra-campaign/project.godot'),'mutation'));
scenario('Added unmanifested project file rejected',f=>fs.writeFileSync(path.join(f.m.variants.A.sourceDirectory,'flotra-campaign/new.gd'),'new'));
scenario('Unexpected export asset rejected',f=>fs.writeFileSync(path.join(f.m.variants.B.exportDirectory,'stale.js'),'stale'));
scenario('Wrong immutable candidate ref rejected',f=>{f.m.variants.B.commit='c'.repeat(40);});
scenario('Unqualified rebuilt control rejected',f=>{f.m.controlQualification.status='mismatch_requires_review';});
scenario('Broadened scene tolerance rejected',f=>{f.m.controlQualification.rule='ignore_all_scene_differences';});
scenario('Missing scene control result rejected',f=>{delete f.m.controlQualification;});
test('Wrong served directory rejected',()=>{const f=fixture();try{assert.throws(()=>verify(f.m,f.m.controlCommit,f.m.candidateCommit,f.m.variants.B.exportDirectory,f.m.variants.A.exportDirectory));}finally{fs.rmSync(f.root,{recursive:true,force:true});}});

scenario('Control report for a different PCK rejected',f=>{f.m.controlQualification.actual['index.pck']='0'.repeat(64);});
scenario('Failed bounded scene check rejected',f=>{f.m.controlQualification.sceneChecks['resource:unexpected']=false;});
scenario('Changed comparison harness rejected',f=>{f.m.harnessSHA256['flotra-campaign/tests/release/source_export_contract.cjs']='0'.repeat(64);});

function pinnedScenario(name, action) {
  test(name, () => {
    const f=fixture();
    try {
      const file=path.join(f.root,'prospective-manifest.json');
      fs.writeFileSync(file,JSON.stringify(f.m));
      const expected=hash(file); // immutable export-step output, before fixture execution
      action(f,file,expected);
    } finally { fs.rmSync(f.root,{recursive:true,force:true}); }
  });
}
pinnedScenario('Pinned manifest is accepted before and after an unchanged run',(f,file,expected)=>{
  assert.deepEqual(readPinnedManifest(file,expected),f.m); f.check();
  assert.deepEqual(readPinnedManifest(file,expected),f.m);
});
pinnedScenario('Missing or malformed export-step digest fails closed',(f,file)=>{
  for(const expected of [undefined,'','not-a-sha','0'.repeat(63)]) assert.throws(()=>readPinnedManifest(file,expected));
});
pinnedScenario('PCK plus matching manifest rewrite before first read is rejected',(f,file,expected)=>{
  const pack=path.join(f.m.variants.B.exportDirectory,'index.pck');
  fs.writeFileSync(pack,'different generated pack');
  f.m.variants.B.assetsSHA256['index.pck']=hash(pack);
  f.m.variants.B.allExportAssetsSHA256['index.pck']=hash(pack);
  fs.writeFileSync(file,JSON.stringify(f.m));
  f.check(); // Old mutable-manifest contract alone would accept this pair.
  assert.throws(()=>readPinnedManifest(file,expected),/Manifest changed after export step/);
});
pinnedScenario('Manifest-only rewrite after first read is rejected',(f,file,expected)=>{
  readPinnedManifest(file,expected); f.check();
  fs.appendFileSync(file,'\n');
  assert.throws(()=>readPinnedManifest(file,expected),/Manifest changed after export step/);
});
pinnedScenario('PCK and manifest rewrite after first read is rejected',(f,file,expected)=>{
  readPinnedManifest(file,expected);
  const pack=path.join(f.m.variants.B.exportDirectory,'index.pck');
  fs.appendFileSync(pack,'changed during measurement');
  f.m.variants.B.assetsSHA256['index.pck']=hash(pack);
  f.m.variants.B.allExportAssetsSHA256['index.pck']=hash(pack);
  fs.writeFileSync(file,JSON.stringify(f.m));
  assert.throws(()=>readPinnedManifest(file,expected),/Manifest changed after export step/);
});
