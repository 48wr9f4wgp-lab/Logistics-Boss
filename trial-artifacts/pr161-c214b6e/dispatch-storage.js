/* Schema-5 storage. The old campaign keys are read-only migration sources. */
(function (root) {
  'use strict';
  const PRIMARY = 'flotra.campaign.dispatch.v5';
  const BACKUP = PRIMARY + '.backup';
  const OLD_PRIMARY = 'flotra.campaign.release.v1';
  const OLD_BACKUP = OLD_PRIMARY + '.backup';
  const MAX_TEXT = 2800000;
  const MAX_BYTES = 2000000;
  let observed;
  let ownsWriter = false;
  let ownsLegacyWriter = false;
  let releaseWriter = null;
  let releaseLegacyWriter = null;
  let legacyRequested = false;
  let generation = 0;
  const writerState = {new:'idle', legacy:'idle'};
  const acquisitions = {};
  const resolutions = {};
  let startup = null;
  let restoreHandler = null;
  // Ownership and readiness are distinct: a queued callback is not a refusal.
  function readiness(which) {
    const state = writerState[which];
    return {ok:state === 'held', state, writer:which};
  }
  function finish(which, state) {
    writerState[which] = state;
    if (resolutions[which]) resolutions[which](readiness(which));
    delete resolutions[which];
  }

  function validEnvelope(text) {
    if (typeof text !== 'string' || !text.length || text.length > MAX_TEXT) return false;
    try {
      const value = JSON.parse(text);
      if (!value || Array.isArray(value) || Object.keys(value).sort().join(',') !== 'format,payload,sha256,version' ||
          value.format !== 'flotra-campaign' || value.version !== 5 ||
          typeof value.payload !== 'string' || !value.payload.length ||
          !/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(value.payload) ||
          typeof value.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(value.sha256)) return false;
      const padding = value.payload.endsWith('==') ? 2 : (value.payload.endsWith('=') ? 1 : 0);
      return value.payload.length / 4 * 3 - padding <= MAX_BYTES;
    } catch (_) { return false; }
  }
  function acquire(which) {
    if (writerState[which] === 'pending' || writerState[which] === 'held') return acquisitions[which];
    const epoch = generation;
    writerState[which] = 'pending';
    acquisitions[which] = new Promise(resolve => { resolutions[which] = resolve; });
    if (!root.navigator || !root.navigator.locks) {
      finish(which, 'unavailable');
      return acquisitions[which];
    }
    const key = which === 'legacy' ? OLD_PRIMARY : PRIMARY;
    try {
      root.navigator.locks.request(key + '.writer', {mode:'exclusive', ifAvailable:true}, lock => {
        if (epoch !== generation) return;
        if (!lock) { finish(which, 'occupied'); return; }
        if (which === 'legacy') ownsLegacyWriter = true;
        else ownsWriter = true;
        finish(which, 'held');
        return new Promise(resolve => {
          if (which === 'legacy') releaseLegacyWriter = resolve;
          else releaseWriter = resolve;
        });
      }).catch(() => { if (epoch === generation) finish(which, 'unavailable'); });
    } catch (_) { finish(which, 'unavailable'); }
    return acquisitions[which];
  }
  function acquireLegacy() {
    if (legacyRequested) return acquisitions.legacy;
    legacyRequested = true;
    return acquire('legacy');
  }
  function releaseLegacy() {
    ownsLegacyWriter = false;
    if (releaseLegacyWriter) releaseLegacyWriter();
    releaseLegacyWriter = null;
  }
  function cancelAcquisition(state) {
    startup = null;
    generation += 1;
    ownsWriter = false;
    if (releaseWriter) releaseWriter();
    releaseWriter = null;
    releaseLegacy();
    legacyRequested = false;
    finish('new', state);
    finish('legacy', state);
  }
  function snapshot(includeLegacy) {
    const state = {primary:root.localStorage.getItem(PRIMARY), backup:root.localStorage.getItem(BACKUP)};
    if (includeLegacy) {
      state.legacyPrimary = root.localStorage.getItem(OLD_PRIMARY);
      state.legacyBackup = root.localStorage.getItem(OLD_BACKUP);
    }
    return state;
  }
  function same(a, b) {
    return Object.keys(a).every(key => a[key] === b[key]) && Object.keys(a).length === Object.keys(b).length;
  }
  acquire('new');
  if (root.addEventListener) root.addEventListener('pagehide', () => cancelAcquisition('cancelled'));
  if (root.addEventListener) root.addEventListener('pageshow', event => {
    if (!event.persisted) return;
    // A restored heap may hold an old checkpoint. Never reacquire and resume it.
    // Only an explicit page reload may load a new snapshot under fresh locks.
    cancelAcquisition('reload_required');
    if (restoreHandler) restoreHandler();
  });
  root.FlotraDispatchStore = Object.freeze({
    cancelStartup() { cancelAcquisition('cancelled'); },
    setRestoreHandler(handler) {
      restoreHandler = typeof handler === 'function' ? handler : null;
      if (restoreHandler && writerState.new === 'reload_required') restoreHandler();
    },
    // The loader calls this before Godot can load, mutate or save a warehouse.
    // Existing v5 data (including invalid/backup-only data) never needs the old
    // writer lock. Decoding and migration safety remain owned by the old reader.
    ready() {
      if (startup) return startup;
      startup = (async () => {
        const startupEpoch = generation;
        let timer;
        const timeout = new Promise(resolve => {
          timer = root.setTimeout(() => {
            cancelAcquisition('timeout');
            resolve({ok:false, state:'timeout'});
          }, 10000);
        });
        const granted = (async () => {
          const current = await acquisitions.new;
          if (!current.ok) return current;
          let pair;
          try { pair = snapshot(false); }
          catch (_) { return {ok:false, state:'storage_unavailable'}; }
          if (pair.primary === null && pair.backup === null) {
            const legacy = await acquireLegacy();
            if (!legacy.ok) return legacy;
          }
          return startupEpoch === generation && ownsWriter
            ? {ok:true, state:'held'} : {ok:false, state:'cancelled'};
        })();
        const result = await Promise.race([granted, timeout]);
        root.clearTimeout(timer);
        // A refused startup cannot retain a different writer lock indefinitely.
        if (!result.ok && result.state !== 'timeout' && result.state !== 'cancelled') cancelAcquisition(result.state);
        return result;
      })();
      return startup;
    },
    readiness() { return {current:readiness('new'), legacy:readiness('legacy')}; },
    read() {
      if (writerState.new === 'reload_required') return {ok:false,reason:'page_restore_required'};
      try {
        const current = snapshot(false);
        const legacy = current.primary === null && current.backup === null;
        observed = legacy ? snapshot(true) : current;
        if (legacy && (observed.primary !== null || observed.backup !== null || !same(current, snapshot(false)))) {
          observed = undefined;
          return {ok:false,reason:'concurrent_change'};
        }
        if (legacy) acquireLegacy();
        const primary = legacy ? observed.legacyPrimary : observed.primary;
        const backup = legacy ? observed.legacyBackup : observed.backup;
        return {ok:true, source:legacy ? 'legacy' : 'v5', primary:primary ?? '', backup:backup ?? '',
          primary_present:primary !== null, backup_present:backup !== null};
      } catch (_) { return {ok:false,reason:'storage_unavailable'}; }
    },
    write(text) {
      if (writerState.new === 'reload_required') return {ok:false,reason:'page_restore_required'};
      if (!ownsWriter) return {ok:false,reason:'writer_unavailable'};
      if (!observed) return {ok:false,reason:'load_required'};
      const migrating = 'legacyPrimary' in observed;
      if (migrating && !ownsLegacyWriter) return {ok:false,reason:'legacy_writer_unavailable'};
      if (!validEnvelope(text)) return {ok:false,reason:'invalid_envelope'};
      try {
        const current = snapshot(migrating);
        if (!same(observed, current)) return {ok:false,reason:'concurrent_change'};
        if (current.primary !== null && !validEnvelope(current.primary)) return {ok:false,reason:'existing_unrecognized'};
        if (current.backup !== null && !validEnvelope(current.backup)) return {ok:false,reason:'backup_unrecognized'};
        if (current.primary === null && current.backup !== null) return {ok:false,reason:'backup_requires_recovery'};
        if (current.primary !== null) {
          root.localStorage.setItem(BACKUP, current.primary);
          // If the primary write fails, a retry knows this was our own rotation.
          observed.backup = current.primary;
        }
        root.localStorage.setItem(PRIMARY, text);
        if (root.localStorage.getItem(PRIMARY) !== text) return {ok:false,reason:'write_uncertain'};
        observed = {primary:text, backup:current.primary !== null ? current.primary : null};
        releaseLegacy();
        return {ok:true,migrated:migrating};
      } catch (_) { return {ok:false,reason:'storage_write_failed'}; }
    }
  });
})(window);
