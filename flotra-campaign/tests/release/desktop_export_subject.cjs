'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const path = require('node:path');
const source = require('./source_export_contract.cjs');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function candidateSubject(env) {
  const file = env.FLOTRA_SOURCE_EXPORT_PROVENANCE;
  const expected = env.FLOTRA_SOURCE_EXPORT_MANIFEST_SHA256;
  const manifest = source.readPinnedManifest(file, expected);
  const verify = () => {
    source.readPinnedManifest(file, expected);
    source.verify(manifest, env.CONTROL_SHA, env.FLOTRA_CANDIDATE_SHA,
      manifest.variants.A.exportDirectory, env.FLOTRA_DESKTOP_EXPORT_DIRECTORY);
  };
  verify();
  const assets = manifest.variants.B.allExportAssetsSHA256;
  assert.ok(assets['writer-away.html'], 'Lifecycle document must be attested before fixture generation');
  return { verify, assets, required: Object.keys(manifest.variants.B.assetsSHA256),
    report: { kind: 'prospective-candidate-source-export', commit: manifest.candidateCommit,
      manifestSHA256: expected, assetsSHA256: assets,
      directory: path.resolve(env.FLOTRA_DESKTOP_EXPORT_DIRECTORY) } };
}

// Passive CDP observation only: no routing, response replacement or cache changes.
// Own bounded inspector buffers avoid Playwright's smaller body-cache eviction
// for the official 38MiB WASM. Bytes come from the SAME session/request ID.
async function observeAssets(page, baseURL, expected, expectedPackFailure = false) {
  const session = await page.context().newCDPSession(page);
  const base = new URL('.', baseURL);
  const pending = [], errors = [], loaded = {}, requests = new Map();
  let injectedPackFailures = 0;
  session.on('Network.responseReceived', ({ requestId, response }) => {
    const url = new URL(response.url);
    const name = url.pathname === base.pathname ? 'index.html' : url.pathname.slice(base.pathname.length);
    if (url.origin === base.origin && url.pathname.startsWith(base.pathname) && Object.hasOwn(expected, name)) {
      requests.set(requestId, { name, status: response.status });
    }
  });
  session.on('Network.loadingFailed', ({ requestId, errorText }) => {
    if (requests.has(requestId)) errors.push(new Error('Attested response failed: ' + errorText));
    requests.delete(requestId);
  });
  session.on('Network.loadingFinished', ({ requestId }) => {
    const response = requests.get(requestId);
    if (!response) return;
    requests.delete(requestId);
    pending.push((async () => {
      const { name, status } = response;
      const body = await session.send('Network.getResponseBody', { requestId });
      const actual = hash(Buffer.from(body.body, body.base64Encoded ? 'base64' : 'utf8'));
      if (expectedPackFailure && name === 'index.pck') {
        assert.equal(status, 503, 'Only the explicit PCK 503 fault is expected');
        assert.equal(actual, hash('Synthetic CI unavailable pack'), 'Exact injected PCK failure body');
        injectedPackFailures++;
        return;
      }
      // CDP may retain status 304 after cache revalidation. The returned full
      // cached body must still match the pinned bytes; missing bodies fail.
      assert.ok((status >= 200 && status < 300) || status === 304, 'Attested asset HTTP success: ' + name);
      assert.equal(actual, expected[name], 'Actual desktop response bytes: ' + name);
      loaded[name] = actual;
    })().catch(error => { errors.push(error); }));
  });
  await session.send('Network.enable', { maxTotalBufferSize: 128 * 1024 * 1024, maxResourceBufferSize: 64 * 1024 * 1024 });
  return async (required = []) => {
    await Promise.all(pending);
    if (errors.length) throw errors[0];
    if (expectedPackFailure) assert.equal(injectedPackFailures, 4, 'Observe all four explicit PCK failure attempts');
    for (const name of required) assert.equal(loaded[name], expected[name], 'Desktop actually loaded: ' + name);
    return { ...loaded };
  };
}
module.exports = { candidateSubject, observeAssets };
