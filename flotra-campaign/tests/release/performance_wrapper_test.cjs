'use strict';
// Mock orchestration checks, never performance measurements or timing retries.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const {spawnSync} = require('node:child_process');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'flotra-performance-wrapper-'));
const directory = path.join(root, 'flotra-campaign/tests/release');
fs.mkdirSync(directory, {recursive:true});
const wrapper = path.join(directory, 'browser_combined_performance.cjs');
fs.copyFileSync(path.join(__dirname, 'browser_combined_performance.cjs'), wrapper);
const assets = ['index.html','index.pck','index.js','index.wasm','campaign-viewport.js','campaign-storage.js'];
for (const build of ['A','B']) {
  fs.mkdirSync(path.join(root, build));
  for (const name of assets) fs.writeFileSync(path.join(root, build, name), `mock-${build}-${name}`);
}
const hashes = build => Object.fromEntries(assets.map(name => [name,crypto.createHash('sha256').update(fs.readFileSync(path.join(root,build,name))).digest('hex')]));
fs.mkdirSync(path.join(root,'fixtures'));
fs.writeFileSync(path.join(root,'fixtures/late.json'),'{}');
fs.writeFileSync(path.join(root,'test-manifest.json'), JSON.stringify({controlCommit:'control', comparisonCamera:'overview', sourceSHA256:{},controlAssetsSHA256:hashes('A'),candidateAssetsSHA256:hashes('B')}));
fs.writeFileSync(path.join(directory,'browser_growth_journey.cjs'), String.raw`
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const output=process.argv[3],label=path.basename(output),mode=process.env.WRAPPER_UNIT_MODE;
const names=['index.html','index.pck','index.js','index.wasm','campaign-viewport.js','campaign-storage.js'];
const fail=(mode==='control_failure'&&label==='A1')||(mode==='candidate_failure'&&label==='B2');
const camera={zoom:1,turn:0,panX:0,panY:0,touches:0,mouseDown:false,size:10,fitSize:10,floorPoints:[],callouts:[]};
if(label.startsWith('B')) {camera.framing='overview';camera.equipmentBounds=['shelf','packing'].map(id=>({id,corners:Array.from({length:8},()=>({x:10,y:20}))}));}
if(mode==='camera_mismatch'&&label==='B1')camera.panX=1;
if(mode==='missing_diagnostics'&&label==='B1'){delete camera.framing;delete camera.equipmentBounds;}
if(mode==='invalid_geometry'&&label==='B1')camera.equipmentBounds[0].corners.pop();
const test={name:'mature-performance',status:fail?'failed':'passed',environment:{visibility:'visible',dpr:3,vendor:'mock',renderer:mode==='renderer_mismatch'&&label==='B1'?'other':'mock'},chromiumVersion:'mock',initialState:{simTime:mode==='state_mismatch'&&label==='B1'?1:0,camera},performanceCamera:process.env.FLOTRA_PERFORMANCE_CAMERA,loadedAssets:Object.fromEntries(names.map(n=>[n,crypto.createHash('sha256').update(fs.readFileSync(path.join(process.env.FLOTRA_EXPORTED_DIRECTORY,n))).digest('hex')])),performance:{active:{processMedianMs:10,processP95Ms:20,rafMedianMs:16,rafP95Ms:30}}};
if(mode==='asset_mismatch'&&label==='B2')test.loadedAssets['index.pck']='bad';
fs.writeFileSync(path.join(output,'growth-journey.json'),JSON.stringify({tests:[test],error:fail?'mock gate failure':null}));process.exitCode=fail?1:0;
`);
const cases={healthy:'all_unchanged_gates_passed',control_failure:'inconclusive_unhealthy_control',candidate_failure:'candidate_failed',renderer_mismatch:'invalid_comparison',state_mismatch:'invalid_comparison',asset_mismatch:'invalid_comparison',camera_mismatch:'invalid_comparison',invalid_geometry:'invalid_comparison',missing_diagnostics:'invalid_comparison'};
const results=[];
for (const [mode, expected] of Object.entries(cases)) {
  const output=path.join(root,'results',mode);
  const run=spawnSync(process.execPath,[wrapper,'http://mock-control/','http://mock-candidate/',output,path.join(root,'fixtures'),path.join(root,'A'),path.join(root,'B'),'control','candidate'],{env:{...process.env,WRAPPER_UNIT_MODE:mode,FLOTRA_COMPARISON_MANIFEST:'test-manifest.json'},encoding:'utf8'});
  const result=JSON.parse(fs.readFileSync(path.join(output,'comparison.json'),'utf8'));
  assert.equal(result.classification,expected,mode);
  assert.equal(run.status,mode==='healthy'?0:1,mode);
  assert.deepEqual(result.results.map(row=>row.label),['A1','B1','B2','A2'],'Every result is retained without a measured retry');
  results.push({mode,classification:result.classification,exitCode:run.status});
}
console.log(JSON.stringify({suite:'performance_wrapper_mock_orchestration',cases:results}));
