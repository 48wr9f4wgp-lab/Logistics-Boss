import { readFileSync, readdirSync } from 'node:fs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

const html = read('../index.html');
const ui = read('../src/ui.js');
const ergonomics = read('../src/ergonomics.js');

const hudStart = html.indexOf('<header id="topHud"');
const hudEnd = html.indexOf('</header>', hudStart);
assert(hudStart >= 0 && hudEnd > hudStart, 'top HUD must exist');
const hud = html.slice(hudStart, hudEnd);

const moneyPos = hud.indexOf('id="money"');
const researchPos = hud.indexOf('id="research"');
const throughputPos = hud.indexOf('id="throughput"');
const ordersPos = hud.indexOf('id="orders"');
const shippedPos = hud.indexOf('id="shipped"');
assert(moneyPos < researchPos && researchPos < throughputPos && throughputPos < ordersPos,
  'visible primary HUD order must be money, research, throughput, orders');
assert(ordersPos < shippedPos, 'cumulative shipped must not occupy the visible throughput slot');
assert(hud.includes('<span>出荷ペース</span><strong id="throughput">0/分</strong>'),
  'throughput must have a dedicated semantic HUD element');

assert(ui.includes('el.shipped.textContent = s.shipped.toLocaleString'),
  'ui.js must own cumulative shipped rendering');
assert(ui.includes('el.throughput.textContent = `${s.metrics.perMinute}/分`;'),
  'ui.js must own throughput rendering');
assert(!ergonomics.includes('syncPrimaryMetrics'),
  'ergonomics layer must not rewrite primary HUD metrics');
assert(!ergonomics.includes("topHud.querySelectorAll('.metric')"),
  'ergonomics layer must not target HUD cards by positional index');
assert(!ergonomics.includes('metrics[2]'),
  'ergonomics layer must not repurpose the third HUD metric');

const srcDir = new URL('../src/', import.meta.url);
const sources = readdirSync(srcDir)
  .filter((name) => name.endsWith('.js'))
  .map((name) => [name, read(`../src/${name}`)]);
const competingThroughputWriters = sources.filter(([name, source]) =>
  name !== 'ui.js' && (
    source.includes("getElementById('throughput')") ||
    source.includes('getElementById("throughput")') ||
    source.includes("querySelectorAll('.metric')") && source.includes('perMinute')
  )
);
assert(competingThroughputWriters.length === 0,
  `throughput HUD has competing writers: ${competingThroughputWriters.map(([name]) => name).join(', ')}`);

console.log('HUD metric stability smoke OK');
