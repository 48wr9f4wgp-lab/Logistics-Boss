const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const root='/workspace/Logistics-Boss';
const output='/tmp/flotra-line-performance-optimized';fs.mkdirSync(output,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const sources=['flotra-campaign/prototype/growth_view.gd','flotra-campaign/prototype/growth_sim.gd','flotra-campaign/tests/release/browser_growth_journey.cjs'];
const report={scope:'Local dirty working-tree review; sequential ABBA on same Chromium, 390x844 DPR3, synthetic mature fixture. No physical-device claim.',baseline:'027cb20d0bcd34fde6f944f4b3e7e63e21dc9b09',sourceHashes:Object.fromEntries(sources.map(p=>[p,hash(path.join(root,p))])),fixtureHash:hash('/tmp/flotra-campaign-test.chp96q/growth-fixtures/late.json'),runs:[]};
for(const label of ['A1','B1','B2','A2']){
 const variant=label.startsWith('A')?'control':'candidate',directory=`/tmp/flotra-line-web/${variant}`;
 const out=path.join(output,label);fs.mkdirSync(out,{recursive:true});
 const run=spawnSync(process.execPath,[path.join(root,'flotra-campaign/tests/release/browser_growth_journey.cjs'),`http://127.0.0.1:8765/${variant}/`,out,'/tmp/flotra-campaign-test.chp96q/growth-fixtures'],{env:{...process.env,NODE_PATH:'/workspace/.flotra-tools/browser/node_modules',CHROMIUM_EXECUTABLE:'/usr/bin/chromium',FLOTRA_JOURNEY_CASES:'mature-performance',FLOTRA_EXPORTED_DIRECTORY:directory},encoding:'utf8',timeout:240000,maxBuffer:16*1024*1024});
 fs.writeFileSync(path.join(out,'run.log'),(run.stdout||'')+(run.stderr||''));
 const resultPath=path.join(out,'growth-journey.json');
 const result=fs.existsSync(resultPath)?JSON.parse(fs.readFileSync(resultPath)):null;
 report.runs.push({label,exitCode:run.status,signal:run.signal,error:run.error?.message||null,test:result?.tests?.[0]||null});
 fs.writeFileSync(path.join(output,'comparison.json'),JSON.stringify(report,null,2));
 console.log(label,run.status,result?.tests?.[0]?.status,result?.tests?.[0]?.performance||result?.tests?.[0]?.error);
 if(run.error||run.signal||!result?.tests?.[0])break;
}
