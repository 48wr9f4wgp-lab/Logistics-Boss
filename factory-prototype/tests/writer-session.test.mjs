import assert from 'node:assert/strict';
import test from 'node:test';
import {writerSession} from '../../docs/forge-preview/writer-session.mjs';
function manager(){
  const queue=[];
  const locks={request(key,options,work){
    return new Promise((resolve,reject)=>{
      queue.push({signal:options.signal,grant:()=>resolve(work()),fail:reject});
      options.signal.addEventListener('abort',()=>reject(new Error('aborted')),{once:true});
    });
  }};
  return {queue,locks};
}
test('one request per visible period; late grants cannot write after suspension',async()=>{
  const {queue,locks}=manager();let grants=0,errors=0;
  const seat=writerSession(locks,'factory',()=>grants++,()=>errors++);
  seat.enter();seat.enter();assert.equal(queue.length,1);
  seat.leave();seat.enter();queue[0].grant();assert.equal(grants,0);
  queue[1].grant();assert.equal(grants,1);seat.leave();seat.leave();
  seat.enter();queue[2].grant();seat.leave();await new Promise(r=>setTimeout(r,0));
  assert.equal(grants,2);assert.equal(errors,0);
});
test('a failed current request is reported and can be retried',async()=>{
  const {queue,locks}=manager();let grants=0,errors=0;
  const seat=writerSession(locks,'factory',()=>grants++,()=>errors++);
  seat.enter();queue[0].fail(new Error('unavailable'));await new Promise(r=>setTimeout(r,0));
  assert.equal(errors,1);seat.enter();queue[1].grant();assert.equal(grants,1);seat.leave();
});
test('when Web Locks are unavailable resume still runs validation once per visible period',()=>{
  let grants=0;const seat=writerSession(null,'factory',()=>grants++,assert.fail);
  seat.enter();seat.enter();seat.leave();seat.enter();assert.equal(grants,2);
});
