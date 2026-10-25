'use strict';
// Serialized into the browser by waitForFunction. Observe real events only.
function historyReturnObserved({ expectedURL, beforeRealm, beforePageShows }) {
  const harness = window.__writerHarness?.data;
  if (location.href !== expectedURL || !harness) return false;
  const shown = harness.lifecycle.filter(event => event.type === 'pageshow' && event.trusted).length;
  return shown > (harness.realm === beforeRealm ? beforePageShows : 0);
}
module.exports = { historyReturnObserved };
