// Hold the writer lock only while this page is in use. Abort a pending request
// when leaving so an old callback cannot start a second writer on resume.
export function writerSession(locks,key,onGrant,onError){
  let request=null,release=null;
  return {
    enter(){
      if(request)return;
      const next=new AbortController();request=next;
      if(!locks){onGrant();return;}
      locks.request(key,{signal:next.signal},async()=>{
        if(request!==next)return;
        const held=new Promise(resolve=>{release=resolve;});
        onGrant();await held;
      }).catch(error=>{
        if(request!==next)return;
        request=null;release=null;onError(error);
      });
    },
    leave(){
      if(!request)return;
      const old=request;request=null;old.abort();
      release?.();release=null;
    }
  };
}
