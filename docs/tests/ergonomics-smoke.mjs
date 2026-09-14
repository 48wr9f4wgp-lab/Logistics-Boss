import { readFileSync } from 'node:fs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

const main = read('../src/main.js');
const js = read('../src/ergonomics.js');
const css = read('../ergonomics.css');

assert(main.includes("bindErgonomics"), 'main must bind the ergonomics layer');
assert(main.includes('ergonomics.update(dt)'), 'ergonomics layer must update during the frame loop');
assert(js.includes("compact ? '投資' : '閉じる'"), 'thumb-zone entry must use a clear investment label');
assert(js.includes('capitalObserveAction'), 'investment report must offer an explicit observation action');
assert(js.includes('investmentPulse'), 'investment measurement must survive while management is collapsed');
assert(js.includes('navigator.vibrate'), 'ergonomic layer must provide tactile confirmation where available');
assert(css.includes('#commandDock.compact #observeBtn{display:none}'), 'secondary observation control must stay out of the compact primary row');
assert(css.includes('min-height:48px') || css.includes('min-height:46px'), 'frequent controls must use comfortable mobile touch heights');
assert(css.includes('#rank1Guide{display:none!important}'), 'persistent prescriptive guide must not occupy the play surface');
assert(css.includes('.capitalObserveAction'), 'investment observation action must be styled as a full touch target');
assert(css.includes('env(safe-area-inset-bottom)'), 'bottom controls must respect the iPhone safe area');

console.log('UX / Ergonomics smoke OK');
