/* One existing campaign namespace. Godot filesystem persistence remains disabled. */
(function (root) {
  'use strict';
  const PRIMARY = 'flotra.campaign.release.v1';
  const BACKUP = PRIMARY + '.backup';
  const ARCHIVE = PRIMARY + '.pre-v4';
  const MAX = 2800000;
  function validEnvelope(text) {
    if (typeof text !== 'string' || !text.length || text.length > MAX) return false;
    try {
      const value = JSON.parse(text);
      return value && Object.keys(value).every(key => ['format','version','payload','sha256','pre_v4_sha256'].includes(key)) &&
        value.format === 'flotra-campaign' && value.version === 1 &&
        typeof value.payload === 'string' && typeof value.sha256 === 'string' &&
        (value.pre_v4_sha256 === undefined || (typeof value.pre_v4_sha256 === 'string' && /^[0-9a-f]{64}$/.test(value.pre_v4_sha256)));
    } catch (_) { return false; }
  }
  let observed;
  let ownsWriter = false;
  let releaseWriter = null;
  let generation = 0;
  let pendingGeneration = null;
  function acquireWriter() {
    if (ownsWriter || pendingGeneration === generation) return;
    if (!(root.navigator && root.navigator.locks)) return;
    const requestedGeneration = generation;
    pendingGeneration = requestedGeneration;
    try {
      root.navigator.locks.request(PRIMARY + '.writer', {mode:'exclusive',ifAvailable:true}, lock => {
        if (pendingGeneration === requestedGeneration) pendingGeneration = null;
        // Admission can finish after pagehide. Never revive that stale page.
        if (!lock || requestedGeneration !== generation) return;
        ownsWriter = true;
        return new Promise(resolve => { releaseWriter = resolve; });
      }).catch(() => {
        if (requestedGeneration === generation) ownsWriter = false;
        if (pendingGeneration === requestedGeneration) pendingGeneration = null;
      });
    } catch (_) { pendingGeneration = null; ownsWriter = false; }
  }
  acquireWriter();
  if (root.addEventListener) root.addEventListener('pageshow', event => { if (event.persisted) acquireWriter(); });
  if (root.addEventListener) root.addEventListener('pagehide', () => {
    generation += 1;
    ownsWriter = false;
    const release = releaseWriter;
    releaseWriter = null;
    if (release) release();
  });
  function snapshot() {
    return {primary:root.localStorage.getItem(PRIMARY), backup:root.localStorage.getItem(BACKUP), archive:root.localStorage.getItem(ARCHIVE)};
  }
  function unchanged() {
    const current = snapshot();
    return observed !== undefined && ['primary','backup','archive'].every(key => current[key] === observed[key]);
  }
  root.FlotraCampaignStore = Object.freeze({
    read() {
      try {
        observed = snapshot();
        return {ok:true, primary:observed.primary || '', backup:observed.backup || '', archive:observed.archive || '',
          primary_exists:observed.primary !== null, backup_exists:observed.backup !== null, archive_exists:observed.archive !== null};
      } catch (_) { observed = undefined; return {ok:false,reason:'storage_unavailable'}; }
    },
    write(text, protection = {}) {
      if (!ownsWriter) return {ok:false,reason:'writer_unavailable'};
      if (!validEnvelope(text)) return {ok:false,reason:'invalid_envelope'};
      try {
        if (!unchanged()) return {ok:false,reason:'concurrent_change'};
        const previous = observed.primary;
        const backup = observed.backup;
        const archive = observed.archive;
        const source = protection.archiveSource || '';
        // Domain/checksum validation belongs to the engine. Exact read/validated
        // archive text is required here as well, so an unreviewed archive is never
        // silently adopted. Compare every slot, not just the primary.
        if (previous !== null && !validEnvelope(previous)) return {ok:false,reason:'existing_unrecognized'};
        if (backup !== null && !validEnvelope(backup)) return {ok:false,reason:'backup_unrecognized'};
        if (archive !== null && (!validEnvelope(archive) || protection.validatedArchive !== archive)) return {ok:false,reason:'archive_unrecognized'};
        if (previous === null && backup !== null) return {ok:false,reason:'backup_requires_recovery'};
        if (previous === null && archive !== null) return {ok:false,reason:'archive_requires_recovery'};
        if (source && (!validEnvelope(source) || (source !== previous && source !== backup))) return {ok:false,reason:'archive_source_conflict'};
        if (archive !== null && source && archive !== source) return {ok:false,reason:'archive_conflict'};
        const binding = JSON.parse(text).pre_v4_sha256 || '';
        if ((archive !== null || source) && (!binding || binding !== protection.archiveDigest)) return {ok:false,reason:'archive_conflict'};
        if (binding && archive === null && !source) return {ok:false,reason:'archive_conflict'};
        for (const slot of [previous, backup]) {
          const priorBinding = slot === null ? '' : (JSON.parse(slot).pre_v4_sha256 || '');
          if (priorBinding && priorBinding !== binding) return {ok:false,reason:'archive_conflict'};
        }
        if (archive === null && source) {
          if (!unchanged()) return {ok:false,reason:'concurrent_change'};
          try { root.localStorage.setItem(ARCHIVE, source); }
          catch (_) { return {ok:false,reason:'archive_write_failed'}; }
          observed.archive = source;
          if (!unchanged()) return {ok:false,reason:'concurrent_change'};
        }
        if (previous !== null) {
          if (!unchanged()) return {ok:false,reason:'concurrent_change'};
          root.localStorage.setItem(BACKUP, previous);
          observed.backup = previous;
        }
        if (!unchanged()) return {ok:false,reason:'concurrent_change'};
        root.localStorage.setItem(PRIMARY, text);
        observed.primary = text;
        if (!unchanged()) return {ok:false,reason:'concurrent_change'};
        return {ok:true};
      } catch (_) { return {ok:false,reason:'storage_write_failed'}; }
    }
  });
})(window);
