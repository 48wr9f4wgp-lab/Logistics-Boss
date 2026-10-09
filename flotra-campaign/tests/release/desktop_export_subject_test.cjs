'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const crypto = require('node:crypto');
const { observeAssets, candidateSubject } = require('./desktop_export_subject.cjs');
const hash = text => crypto.createHash('sha256').update(text).digest('hex');
async function fixture(expectedPackFailure = false) {
  const session = new EventEmitter(), bodies = new Map(); let sequence = 0;
  session.send = async (method, params) => {
    if (method === 'Network.enable') {
      assert.equal(params.maxResourceBufferSize, 64 * 1024 * 1024);
      return;
    }
    assert.equal(method, 'Network.getResponseBody');
    return { body: Buffer.from(bodies.get(params.requestId)).toString('base64'), base64Encoded: true };
  };
  const page = { context: () => ({ newCDPSession: async () => session }) };
  const assets = { 'index.html': hash('html'), 'index.pck': hash('pack'), 'writer-away.html': hash('away') };
  const flush = await observeAssets(page, 'http://127.0.0.1:8861/?phone_qa=1', assets, expectedPackFailure);
  const response = (name, body, ok = true, status = ok ? 200 : 503) => {
    const requestId = String(++sequence); bodies.set(requestId, body);
    session.emit('Network.responseReceived', { requestId, response: { url: new URL(name, 'http://127.0.0.1:8861/').href, status } });
    session.emit('Network.loadingFinished', { requestId });
  };
  return { session, assets, flush, response };
}
test('Real response bytes including root HTML and lifecycle page are checked', async () => {
  const f = await fixture(); f.response('/?phone_qa=1', 'html'); f.response('index.pck', 'pack'); f.response('writer-away.html?writer_navigation=1', 'away');
  assert.deepEqual(await f.flush(Object.keys(f.assets)), f.assets);
});
test('Wrong candidate pack response rejects even if local files are intact', async () => {
  const f = await fixture(); f.response('index.pck', 'old-public-pack'); await assert.rejects(f.flush());
});
test('Normal successful boot requires all six contract assets, not only observed ones', async () => {
  const f = await fixture(); f.response('/', 'html'); await assert.rejects(f.flush(['index.html', 'index.pck']));
});
test('HTTP error cannot qualify an attested asset', async () => {
  const f = await fixture(); f.response('index.pck', 'pack', false); await assert.rejects(f.flush());
});
test('The explicit engine rejection case verifies four exact PCK 503 responses', async () => {
  const f = await fixture(true); f.response('/', 'html');
  for (let i = 0; i < 4; i++) f.response('index.pck', 'Synthetic CI unavailable pack', false);
  assert.deepEqual(await f.flush(), { 'index.html': f.assets['index.html'] });
  await assert.rejects(f.flush(['index.pck'])); // Fault bytes never count as a good pack.
});
for (const [label, status, body] of [['wrong body', 503, 'other'], ['wrong status', 404, 'Synthetic CI unavailable pack'], ['unexpected success', 200, 'pack']]) {
  test('Fault case rejects ' + label, async () => {
    const f = await fixture(true);
    for (let i = 0; i < 4; i++) f.response('index.pck', body, status === 200, status);
    await assert.rejects(f.flush());
  });
}
test('Fault case does not waive other asset failures or missing retry attempts', async () => {
  const f = await fixture(true); await assert.rejects(f.flush());
  for (let i = 0; i < 4; i++) f.response('index.pck', 'Synthetic CI unavailable pack', false);
  f.response('index.html', 'wrong'); await assert.rejects(f.flush());
});
test('Other-origin assets cannot stand in for the tested origin', async () => {
  const f = await fixture(); f.response('http://localhost:9999/index.pck', 'pack'); await assert.rejects(f.flush(['index.pck']));
});
test('Later reload substitution remains rejected after an initial good response', async () => {
  const f = await fixture(); f.response('index.pck', 'pack'); await f.flush(['index.pck']);
  f.response('index.pck', 'changed'); await assert.rejects(f.flush(['index.pck']));
});
test('Candidate mode cannot silently fall back without pinned manifest digest', () => {
  assert.throws(() => candidateSubject({ FLOTRA_SOURCE_EXPORT_PROVENANCE: '/missing-manifest' }));
});
test('CDP loading failure remains a verification failure', async () => {
  const f = await fixture();
  f.session.emit('Network.responseReceived', { requestId: 'failed', response: { url: 'http://127.0.0.1:8861/index.pck', status: 200 } });
  f.session.emit('Network.loadingFailed', { requestId: 'failed', errorText: 'disconnected' });
  await assert.rejects(f.flush());
});
test('Unavailable response bytes are never accepted as verified', async () => {
  const f = await fixture();
  f.session.send = async () => { throw new Error('Inspector cache unavailable'); };
  f.response('index.pck', 'pack'); await assert.rejects(f.flush());
});
test('Text and binary CDP response encodings produce the same actual-byte hashes', async () => {
  const f = await fixture(), send = f.session.send;
  f.session.send = async (...args) => {
    const response = await send(...args);
    return { body: Buffer.from(response.body, 'base64').toString('utf8'), base64Encoded: false };
  };
  f.response('/', 'html'); assert.equal((await f.flush(['index.html']))['index.html'], f.assets['index.html']);
});

test('Cache-revalidated 304 requires the exact complete cached body', async () => {
  const f = await fixture(); f.response('index.pck', 'pack', false, 304);
  assert.equal((await f.flush(['index.pck']))['index.pck'], f.assets['index.pck']);
  f.response('index.pck', 'wrong-cache', false, 304); await assert.rejects(f.flush());
});
