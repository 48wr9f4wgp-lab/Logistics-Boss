#!/usr/bin/env node
'use strict';
// Run the checked-in startup script with a small DOM fixture. This verifies
// Japanese loading/error copy, not graphics support or an actual browser.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(path.resolve(__dirname, '../../web-shell.html'), 'utf8');
assert.match(source, /<html lang="ja">/);
assert.match(source, /id="status-label" role="status">倉庫を読み込んでいます/);
assert.match(source, /#status-label\s*\{[^}]*18px/s);
assert.match(source, /body\s*\{[^}]*18px/s);
assert.match(source, /#status-notice\s*\{[^}]*font-size:\s*18px/s);
assert.ok(!source.includes('Your browser does not support'));
const script = source.slice(source.indexOf('const GODOT_CONFIG ='), source.lastIndexOf('</script>'))
  .replace('$GODOT_CONFIG', '{}').replace('$GODOT_THREADS_ENABLED', 'false');
function element() {
  const item = { style: {}, children: [], removed: false,
    appendChild(child) { this.children.push(child); },
    removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
    remove() { this.removed = true; },
    removeAttribute() {},
  };
  Object.defineProperty(item, 'lastChild', { get() { return this.children.at(-1); } });
  return item;
}
async function run(missing, fail) {
  const elements = Object.fromEntries(['status', 'status-progress', 'status-notice', 'status-label'].map(id => [id, element()]));
  const errors = [];
  class Engine {
    static getMissingFeatures() { return missing; }
    startGame() { return fail ? Promise.reject(new Error('PRIVATE_ENGINE_CODE')) : Promise.resolve(); }
  }
  const context = { Engine,
    document: { getElementById: id => elements[id], createTextNode: text => ({ text }), createElement: () => ({ text: '\n' }) },
    console: { error: (...args) => errors.push(args) },
    navigator: {}, window: { FlotraDispatchStore: {ready:()=>Promise.resolve({ok:true}),cancelStartup(){}}, location: { reload() { throw new Error('unexpected reload'); } } }, setTimeout,
  };
  vm.runInNewContext(script, context);
  await new Promise(resolve => setImmediate(resolve));
  const notice = elements['status-notice'].children.map(child => child.text).join('');
  if (fail || missing.length) {
    assert.match(notice, /ブラウザー/);
    assert.ok(!notice.includes('PRIVATE_ENGINE_CODE'));
    assert.ok(!notice.includes('WebGL2'));
    assert.equal(elements['status-notice'].style.display, 'block');
    assert.equal(elements['status-label'].style.display, 'none');
    assert.ok(errors.length);
  } else {
    assert.equal(elements.status.removed, true);
  }
}
(async () => {
  await run([], false);
  await run([], true);
  await run(['WebGL2'], false);
  console.log('REVIEW_COPY_SHELL PASS (Japanese loading, network failure, unsupported browser; mocked DOM)');
})().catch(error => { console.error(error); process.exitCode = 1; });
