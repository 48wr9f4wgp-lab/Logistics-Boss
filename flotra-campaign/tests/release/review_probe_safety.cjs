'use strict';
// A QA page must use only its QA namespace, including reads and writer locks.
// Pass one or more HTML files. This does not open a browser or touch real storage.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const QA='flotra.campaign.qa.20261003',PRIMARY='flotra.campaign.release.v1',BACKUP=PRIMARY+'.backup';
async function verify(file){
  const html=fs.readFileSync(file,'utf8');
  const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(match=>match[1]);
  assert(scripts.length,'inline helper scripts exist');
  const allowed=new Set([QA,QA+'.backup']), access=[], locks=[];
  const data=new Map([[PRIMARY,'genuine-primary-sentinel'],[BACKUP,'genuine-backup-sentinel'],['unrelated-legacy','unchanged']]);
  const elements={};
  const ctx={
    isSecureContext:true,
    document:{getElementById:id=>elements[id]??=( {} ),createElement:()=>({getContext:()=>null})},
    navigator:{locks:{request:async(name,opts,callback)=>{locks.push(name);assert.equal(name,QA+'.writer');assert.equal(opts.mode,'exclusive');assert.equal(opts.ifAvailable,true);await callback({name});}}},
    localStorage:{
      getItem:key=>{access.push(['read',key]);return data.get(key)??null;},
      setItem:(key,value)=>{access.push(['write',key]);data.set(key,value);},
    },
    addEventListener:()=>{},
  };
  ctx.window=ctx;vm.runInNewContext(scripts.join('\n'),ctx);
  await new Promise(resolve=>setImmediate(resolve));
  // Opening the page already performs a read. Exercise two commits plus reload-read.
  assert(ctx.FlotraCampaignStore.read().ok);
  assert(access.every(([,key])=>allowed.has(key)), 'helper reads non-QA state on open: '+JSON.stringify(access.filter(([,key])=>!allowed.has(key))));
  const envelope=n=>JSON.stringify({format:'flotra-campaign',version:1,payload:'probe-'+n,sha256:'probe'});
  assert(ctx.FlotraCampaignStore.write(envelope(1)).ok);
  assert(ctx.FlotraCampaignStore.write(envelope(2)).ok);
  assert.equal(ctx.FlotraCampaignStore.read().primary,envelope(2));
  assert(access.every(([,key])=>allowed.has(key)), 'helper read/wrote a non-QA key: '+JSON.stringify(access.filter(([,key])=>!allowed.has(key))));
  assert.equal(data.get(PRIMARY),'genuine-primary-sentinel');assert.equal(data.get(BACKUP),'genuine-backup-sentinel');assert.equal(data.get('unrelated-legacy'),'unchanged');
  assert.equal(data.get(QA+'.backup'),envelope(1));
  assert.equal(locks.length,1);
  return {file,ok:true,accessed_keys:[...new Set(access.map(([,key])=>key))],lock:locks[0]};
}
(async()=>{let failed=false;const results=[];for(const file of process.argv.slice(2)){try{results.push(await verify(file));}catch(error){failed=true;results.push({file,ok:false,error:error.message});}}console.log(JSON.stringify({suite:'qa_page_isolation',results},null,2));if(failed)process.exitCode=1;})();
