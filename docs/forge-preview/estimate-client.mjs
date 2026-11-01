// Keep continuous touch input responsive. At most one snapshot runs and only
// the most recently requested view can receive a result.
export function createEstimator(makeWorker=()=>new Worker(new URL('./estimate-worker.mjs?v=0.21',import.meta.url),{type:'module'})){
  let worker=null,pending=null,active=null,version=0;
  function cancel(){
    version++;pending=null;active=null;
    worker?.terminate();worker=null;
  }
  function run(){
    if(!pending||active)return;
    const job=pending;pending=null;active=job;
    function finish(rows){
      if(active!==job)return;
      active=null;
      if(job.version===version)job.show(rows);
      run();
    }
    function failed(){
      if(active!==job)return;
      worker?.terminate();worker=null;finish(null);
    }
    try{
      worker??=makeWorker();
      worker.onmessage=event=>finish(event.data);
      worker.onerror=event=>{event.preventDefault();failed();};
      worker.onmessageerror=failed;
      worker.postMessage({state:job.state,scenarios:job.scenarios});
    }catch{failed();}
  }
  return {cancel,request(state,scenarios,show){
    pending={state,scenarios,show,version:++version};
    run();
  }};
}
