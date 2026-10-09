'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const { historyReturnObserved } = require('./desktop_history_return.cjs');
const target = 'http://127.0.0.1:8895/?phone_qa=1';
const args = { expectedURL: target, beforeRealm: 'old', beforePageShows: 1 };
const show = (persisted, trusted = true) => ({ type: 'pageshow', persisted, trusted });
function observed(realm, lifecycle, href = target) {
  return vm.runInNewContext('(' + historyReturnObserved.toString() + ')', {
    location: { href }, window: { __writerHarness: { data: { realm, lifecycle } } },
  })(args);
}
test('Original initial pageshow is not a completed history traversal', () => assert.equal(observed('old', [show(false)]), false));
test('New trusted pageshow in restored heap completes traversal observation', () => assert.equal(observed('old', [show(false), show(true)]), true));
test('Untrusted event never completes traversal observation', () => assert.equal(observed('old', [show(false), show(true, false)]), false));
test('Wrong URL does not complete traversal even with a pageshow', () => assert.equal(observed('old', [show(false), show(true)], target + 'away'), false));
test('New document initial pageshow permits fallback assertions, not BFCache qualification', () => assert.equal(observed('new', [show(false)]), true));
test('New realm without a trusted pageshow is not ready', () => assert.equal(observed('new', [show(false, false)]), false));
