import {estimateOrder} from './estimate.mjs?v=0.25';

self.onmessage=({data:{state,scenarios}})=>{
  self.postMessage(scenarios.map(scenario=>estimateOrder(state,scenario)));
};
