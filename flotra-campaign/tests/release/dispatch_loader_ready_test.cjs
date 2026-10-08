'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const base=path.resolve(__dirname,'../..');
const shell=fs.readFileSync(path.join(base,'web-shell.html'),'utf8').match(/<script>\s*([\s\S]*?)<\/script>/)[1].replace('$GODOT_CONFIG','{}').replace('$GODOT_THREADS_ENABLED','false');
const storage=fs.readFileSync(path.join(base,'dispatch-storage.js'),'utf8');
const tick=()=>new Promise(r=>setImmediate(r));
function boot(){const requests=[],nodes={},data=new Map(),timers=new Map();let starts=0,id=0;const events={};
 for(const name of ['status','status-progress','status-notice','status-label'])nodes[name]={style:{},textContent:'',children:[],appendChild(x){this.children.push(x)},remove(){this.removed=true},removeAttribute(){}};
 const window={navigator:{locks:{request:(name,options,callback)=>new Promise(resolve=>requests.push({name,callback,resolve}))}},localStorage:{getItem:k=>data.get(k)??null,setItem:()=>{throw Error('loader must never write')}},addEventListener:(k,f)=>events[k]=f,setTimeout:f=>{timers.set(++id,f);return id},clearTimeout:k=>timers.delete(k)};
 class Engine{static getMissingFeatures(){return []}startGame(){starts++;return Promise.resolve()}}
 const context={window,Engine,console,navigator:window.navigator,document:{getElementById:n=>nodes[n],createTextNode:text=>({text}),createElement:()=>({})}};vm.runInNewContext(storage,context);vm.runInNewContext(shell,context);
 return {nodes,requests,events,starts:()=>starts,grant:i=>requests[i].resolve(requests[i].callback({})),deny:i=>requests[i].resolve(requests[i].callback(null))};
}
(async()=>{const a=boot();await tick();assert.equal(a.starts(),0);assert.match(a.nodes['status-label'].textContent,/安全/);a.grant(0);await tick();assert.equal(a.starts(),0);a.grant(1);await tick();assert.equal(a.starts(),1);assert(a.nodes.status.removed);
 const b=boot();b.deny(0);await tick();assert.equal(b.starts(),0);assert.equal(b.nodes['status-notice'].style.display,'block');assert(b.nodes['status-notice'].children.some(x=>/別のFLOTRA/.test(x.text)));
 const c=boot();c.events.pagehide();await tick();assert.equal(c.starts(),0);assert(c.nodes['status-notice'].children.some(x=>/中断/.test(x.text)));
 console.log(JSON.stringify({suite:'actual_loader_ready_gate',checks:3,passed:true,scope:'exact shell inline script + exact storage bridge in synthetic DOM, no browser'}));})().catch(e=>{console.error(e);process.exitCode=1});
