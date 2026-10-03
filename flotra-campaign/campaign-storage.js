/* Explicit, isolated keys. Godot filesystem persistence remains disabled. */
(function (root) {
  'use strict';
  const PRIMARY = 'flotra.campaign.release.v1';
  const BACKUP = 'flotra.campaign.release.v1.backup';
  const MAX = 2800000;
  function validEnvelope(text) {
    if (typeof text !== 'string' || !text.length || text.length > MAX) return false;
    try {
      const value = JSON.parse(text);
      return value.format === 'flotra-campaign' && value.version === 1 &&
        typeof value.payload === 'string' && typeof value.sha256 === 'string';
    } catch (_) { return false; }
  }
  let observed = undefined;
  let ownsWriter = false;
  let releaseWriter = null;
  // A real cross-tab exclusive lock, held for this page's lifetime.
  // Fail closed when unavailable, rather than risk silently replacing another tab.
  function acquireWriter() {
  if (root.navigator && root.navigator.locks) {
    try { root.navigator.locks.request(PRIMARY + '.writer', {mode:'exclusive',ifAvailable:true}, lock => {
      if (!lock) return;
      ownsWriter = true;
      return new Promise(resolve => { releaseWriter = resolve; });
    }).catch(() => { ownsWriter = false; }); } catch (_) { ownsWriter = false; }
  }
  }
  acquireWriter();
  if (root.addEventListener) root.addEventListener('pageshow', event => { if (event.persisted) acquireWriter(); });
  if (root.addEventListener) root.addEventListener('pagehide', () => {
    ownsWriter = false;
    if (releaseWriter) releaseWriter();
  });
  root.FlotraCampaignStore = Object.freeze({
    read() {
      try { observed = root.localStorage.getItem(PRIMARY); return {ok:true,primary:observed||'',backup:root.localStorage.getItem(BACKUP)||''}; }
      catch (_) { return {ok:false,reason:'storage_unavailable'}; }
    },
    write(text) {
      if (!ownsWriter) return {ok:false,reason:'writer_unavailable'};
      if (!validEnvelope(text)) return {ok:false,reason:'invalid_envelope'};
      try {
        const previous = root.localStorage.getItem(PRIMARY);
        const backup = root.localStorage.getItem(BACKUP);
        if (observed === undefined || previous !== observed) return {ok:false,reason:'concurrent_change'};
        // The engine must have validated a restored save before calling write.
        // This additional guard prevents replacing foreign/future JSON envelopes.
        if (previous && !validEnvelope(previous)) return {ok:false,reason:'existing_unrecognized'};
        if (backup && !validEnvelope(backup)) return {ok:false,reason:'backup_unrecognized'};
        if (!previous && backup) return {ok:false,reason:'backup_requires_recovery'};
        if (previous) root.localStorage.setItem(BACKUP, previous);
        root.localStorage.setItem(PRIMARY,text);
        observed = text;
        return {ok:true};
      } catch (_) { return {ok:false,reason:'storage_write_failed'}; }
    }
  });
})(window);
