import { readFileSync } from 'node:fs';

const assert = (condition, message) => { if (!condition) throw new Error(message); };
const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

const uiSource = read('../src/ui.js');
const mainSource = read('../src/main.js');
const indexSource = read('../index.html');

assert(!uiSource.includes('lastDirectorSeverity'), 'Director open/closed state must not track severity history');
assert(!mainSource.includes('bindInsightStability'), 'main must not bind a second Director state authority');
assert(!mainSource.includes('insightStability.update'), 'frame loop must not repair Director state after render');
assert(!uiSource.includes('STEP 1/3'), 'legacy prescribed FTUE must not be rendered by ui.js');
assert(!uiSource.includes('directorAction'), 'Director must not expose a one-tap prescribed solution');
assert(!uiSource.includes('MutationObserver'), 'ui.js must not use a second DOM observer as state authority');
assert(!indexSource.includes('./src/ftue2.js'), 'legacy FTUE post-processing script must not be loaded');
assert(!indexSource.includes('id="directorAction"'), 'legacy Director action element must not exist');
assert(!indexSource.includes('id="ftueStep"'), 'legacy FTUE step element must not exist');

class FakeClassList {
  constructor() { this.values = new Set(); }
  add(...names) { names.forEach((name) => this.values.add(name)); }
  remove(...names) { names.forEach((name) => this.values.delete(name)); }
  contains(name) { return this.values.has(name); }
  toggle(name, force) {
    const next = force === undefined ? !this.values.has(name) : Boolean(force);
    if (next) this.values.add(name); else this.values.delete(name);
    return next;
  }
}

class FakeElement {
  constructor(id = '') {
    this.id = id;
    this.textContent = '';
    this.innerHTML = '';
    this.hidden = false;
    this.disabled = false;
    this.dataset = {};
    this.style = {};
    this.classList = new FakeClassList();
    this.attributes = new Map();
    this.listeners = new Map();
    this.children = [];
    this.offsetWidth = 0;
    this.title = '';
  }
  addEventListener(type, handler) {
    const handlers = this.listeners.get(type) || [];
    handlers.push(handler);
    this.listeners.set(type, handlers);
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  getAttribute(name) { return this.attributes.get(name); }
  appendChild(child) { this.children.push(child); return child; }
  querySelector() { return null; }
  click() { for (const handler of this.listeners.get('click') || []) handler({ currentTarget: this }); }
}

const nodes = new Map();
const node = (id) => {
  if (!nodes.has(id)) nodes.set(id, new FakeElement(id));
  return nodes.get(id);
};

globalThis.document = {
  getElementById: node,
  querySelectorAll: () => [],
  createElement: () => new FakeElement(),
  addEventListener: () => {},
};

globalThis.localStorage = { removeItem() {} };
globalThis.confirm = () => true;

const sim = {
  state: {
    money: 5000,
    research: 0,
    facilityRank: 1,
    logisticsRating: 0,
    shipped: 0,
    ordersOpen: 0,
    status: '安定',
    director: { severity: 0, key: 'stable', label: '安定', detail: '安定運転', recommendation: '観察を続ける' },
    contractOffers: [],
    activeContract: null,
    completedContracts: 0,
    timeScale: 1,
    metrics: { perMinute: 0 },
    workers: [],
    facilities: {},
    upgrades: {},
    perks: {},
    staffingCooldown: 0,
    staffingPlan: 'balanced',
    policy: 'balanced',
  },
  facilityInfo: {},
  upgradeInfo: {},
  perkInfo: {},
  counts: () => ({ inbound: 0, rack: 0, packed: 0 }),
  nextRankTarget: () => 8,
  facilityRankName: () => 'Depot',
  rackCapacity: () => 12,
  inboundMax: () => 12,
  staffingSummary: () => ({ store: 1, pick: 1, ship: 1 }),
  fulfillmentReadiness: () => ({ zones: 0, contracts: 0, throughput: 0, score: 0, ready: false }),
  decisionImpact: () => null,
  onEvent: () => {},
  setPolicy: () => {},
  setTimeScale: () => {},
};

const sceneView = { resetCamera() {}, setFlowMode() {} };
const { bindUi } = await import('../src/ui.js');
const ui = bindUi(sim, sceneView);
const panel = node('insightPanel');
const toggle = node('insightToggle');

function expectDirector(compact, label, context) {
  assert(panel.classList.contains('compact') === compact, `${context}: panel compact state changed unexpectedly`);
  assert(toggle.textContent === label, `${context}: expected toggle label ${label}, got ${toggle.textContent}`);
  assert(toggle.getAttribute('aria-expanded') === String(!compact), `${context}: aria-expanded drifted from panel state`);
  assert(node('directorLabel').textContent !== 'STEP 1/3', `${context}: legacy FTUE leaked into Director label`);
}

sim.state.contractOffers = [{ id: 'optional-1', title: '任意契約', desc: 'test', reward: { cash: 100, research: 0, rating: 0 } }];
ui.render();
expectDirector(true, '契約', 'initial collapsed state');

const severities = [3, 0, 2, 1, 0, 3, 0, 1, 2, 0];
for (const severity of severities) {
  sim.state.director = severity === 0
    ? { severity, key: 'stable', label: '安定', detail: '安定運転', recommendation: '観察を続ける' }
    : { severity, key: 'inbound', label: '搬入口', detail: '混雑', recommendation: '受入側を確認' };
  ui.render();
  expectDirector(true, '契約', `collapsed severity ${severity}`);
}

toggle.click();
expectDirector(false, '閉じる', 'user opened panel');
for (const severity of severities) {
  sim.state.director = severity === 0
    ? { severity, key: 'stable', label: '安定', detail: '安定運転', recommendation: '観察を続ける' }
    : { severity, key: 'orders', label: '注文', detail: '混雑', recommendation: '注文処理を確認' };
  ui.render();
  expectDirector(false, '閉じる', `open severity ${severity}`);
}

toggle.click();
expectDirector(true, '契約', 'user closed panel');
sim.state.contractOffers = [];
ui.render();
expectDirector(true, '開く', 'label changed without opening panel');
sim.state.contractOffers = [{ id: 'optional-2', title: '任意契約2', desc: 'test', reward: { cash: 100, research: 0, rating: 0 } }];
ui.render();
expectDirector(true, '契約', 'contract label changed without opening panel');

console.log('Director stability / legacy FTUE exclusion smoke OK');
