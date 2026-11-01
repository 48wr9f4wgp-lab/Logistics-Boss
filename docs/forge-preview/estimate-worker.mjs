import {estimateOrder} from './estimate.mjs?v=0.22';

self.onmessage=({data:{state,scenarios}})=>{
  self.postMessage(scenarios.map(scenario=>estimateOrder(state,scenario)));
};
