#!/usr/bin/env node
'use strict';
// Execute the exact exported Godot sizing/input functions with a mocked DOM.
// This proves loader policy/input math, not browser or WebGL rendering.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const exported = process.argv[2] || path.resolve(__dirname, '../../../docs/godot-jobs-preview/index.js');
const source = fs.readFileSync(exported, 'utf8');
function extract(name, next) {
  const start = source.indexOf(`var ${name}=`);
  const end = source.indexOf(`;var ${next}=`, start);
  assert.ok(start >= 0 && end > start, `${name}: known exported Godot function boundary`);
  return source.slice(start, end);
}
const displayCode = extract('GodotDisplayScreen', 'GodotInputGamepads');
const inputCode = extract('GodotInput', 'GodotDisplayVK');
let checks = 0;
for (const [width, height] of [[375, 567], [375, 667], [390, 844], [430, 932]]) {
  for (const dpr of [1, 2, 3]) {
    for (const [x, y, insetWidth, insetHeight] of [[0, 0, 0, 0], [12, 47, 24, 81]]) {
      const rect = { x, y, width: width - insetWidth, height: height - insetHeight };
      const canvas = { width: Math.round(rect.width * dpr), height: Math.round(rect.height * dpr), style: { width: `${rect.width}px`, height: `${rect.height}px`, left: `${x}px`, top: `${y}px` } };
      const context = { window: { innerWidth: width, innerHeight: height, devicePixelRatio: dpr }, document: {}, GodotConfig: { canvas, canvas_resize_policy: 0 }, _emscripten_webgl_get_current_context: () => 0, GL: { getContext: () => null } };
      vm.createContext(context);
      vm.runInContext(displayCode + ';' + inputCode, context);
      const before = JSON.stringify(canvas);
      context.GodotDisplayScreen.updateSize();
      assert.equal(JSON.stringify(canvas), before, 'Policy 0 preserves bridge-owned CSS and backing geometry');
      for (const [cx, cy] of [[0, 0], [rect.width / 2, rect.height / 2], [rect.width - 1, rect.height - 1]]) {
        const p = context.GodotInput.computePosition({ clientX: rect.x + cx, clientY: rect.y + cy }, rect);
        assert.ok(Math.abs(p[0] / dpr - cx) < 1e-7 && Math.abs(p[1] / dpr - cy) < 1e-7, 'Pointer positions map back to CSS logical coordinates including safe-area origin');
        checks++;
      }
      // Policy 0 notices a browser bridge resize and leaves the new buffer intact.
      canvas.height -= 120 * dpr;
      context.GodotDisplayScreen.updateSize();
      assert.equal(canvas.height, (rect.height - 120) * dpr);
      assert.equal(context.GodotDisplayScreen.desired_size[1], canvas.height);
      checks += 3;
    }
  }
}
console.log(`REVIEW_WEB_LOADER_GEOMETRY ${checks} checks passed (mocked DOM, exact exported loader)`);
