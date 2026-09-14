from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)

# index.html
p = Path('docs/index.html')
s = p.read_text()
s = replace_once(s,
'''        <div class="miniPolicies" aria-label="作業方針">
          <button type="button" data-policy="balanced">バランス</button>
          <button type="button" data-policy="inbound">入庫</button>
          <button type="button" data-policy="ship">出庫</button>
        </div>
        <button id="quickSpeedBtn" class="quickSpeed" type="button" aria-label="時間速度を切り替え">1×</button>''',
'''        <div class="miniPolicies" aria-label="作業方針">
          <button type="button" data-policy="balanced">バランス</button>
          <button type="button" data-policy="inbound">入庫</button>
          <button type="button" data-policy="ship">出庫</button>
        </div>
        <div id="opsMiniSummary" class="opsMiniSummary" aria-live="polite">
          <strong id="opsCrew">人員 —</strong><span id="opsWeakness">弱点 —</span><span id="opsNext">NEXT —</span>
        </div>
        <button id="quickSpeedBtn" class="quickSpeed" type="button" aria-label="時間速度を切り替え">1×</button>''', 'mini ops summary')
s = replace_once(s,
'''          <div class="staffingChoices">
            <button type="button" data-staffing-plan="receiving"><strong>受入強化</strong><small>入荷側に厚く配置</small></button>
            <button type="button" data-staffing-plan="balanced"><strong>均衡</strong><small>全工程へ均等配置</small></button>
            <button type="button" data-staffing-plan="shipping"><strong>出荷強化</strong><small>ピック・出荷側へ厚く配置</small></button>
          </div>''',
'''          <div class="staffingChoices">
            <button type="button" data-staffing-plan="receiving"><strong>受入 3·1·1</strong><small>入荷を最優先</small></button>
            <button type="button" data-staffing-plan="balanced"><strong>均衡 2·2·1</strong><small>標準編成</small></button>
            <button type="button" data-staffing-plan="picking"><strong>ピック 1·3·1</strong><small>棚→梱包を最優先</small></button>
            <button type="button" data-staffing-plan="dock"><strong>両端 2·1·2</strong><small>入荷と出荷を厚く</small></button>
            <button type="button" data-staffing-plan="shipping"><strong>出荷 1·2·2</strong><small>下流を厚く</small></button>
          </div>''', 'five staffing plans')
s = replace_once(s,
'''</div>

<div class="legacyNotice">数値Lvアップは廃止。Rank 2以降は人員配置と拡張区画で物流構造を変える。</div>''',
'''</div>
<div id="facilityImpact" class="facilityImpact" hidden></div>
<div id="nextStagePanel" class="nextStagePanel" aria-label="次の施設段階">
  <div class="nextStageHead"><small>NEXT STAGE</small><strong>Fulfillment Center</strong></div>
  <div class="nextStageGoals"><span id="goalZones">区画 0/3</span><span id="goalContracts">契約 0/8</span><span id="goalThroughput">出荷 0/6分</span></div>
  <div class="nextStageBar"><i id="nextStageBar"></i></div>
  <small id="nextStageHint">3条件を満たすと自動化設計の準備完了</small>
</div>

<div class="legacyNotice">数値Lvアップは廃止。Rank 2以降は人員配置と拡張区画で物流構造を変える。</div>''', 'impact and next stage')
p.write_text(s)

# sim.js
p = Path('docs/src/sim.js')
s = p.read_text()
s = replace_once(s,
'''    metrics: { perMinute: 0 },
  };''',
'''    metrics: { perMinute: 0 },
    decisionImpact: null,
  };''', 'decision impact state')
s = replace_once(s,
'''  function staffingSequence(plan) {
    if (plan === 'receiving') return ['store', 'pick', 'ship', 'store', 'store', 'pick', 'store', 'ship'];
    if (plan === 'shipping') return ['store', 'pick', 'ship', 'ship', 'pick', 'ship', 'pick', 'store'];
    return ['store', 'pick', 'ship', 'store', 'pick', 'ship', 'store', 'pick'];
  }''',
'''  function staffingSequence(plan) {
    if (plan === 'receiving') return ['store', 'pick', 'ship', 'store', 'store', 'pick', 'store', 'ship'];
    if (plan === 'picking') return ['store', 'pick', 'ship', 'pick', 'pick', 'store', 'ship', 'pick'];
    if (plan === 'dock') return ['store', 'pick', 'ship', 'store', 'ship', 'pick', 'store', 'ship'];
    if (plan === 'shipping') return ['store', 'pick', 'ship', 'ship', 'pick', 'ship', 'pick', 'store'];
    return ['store', 'pick', 'ship', 'store', 'pick', 'ship', 'store', 'pick'];
  }''', 'staffing sequences')
s = replace_once(s,
'''    if (!['balanced', 'receiving', 'shipping'].includes(plan)) return { ok: false, reason: '不明な配属' };''',
'''    if (!['balanced', 'receiving', 'picking', 'dock', 'shipping'].includes(plan)) return { ok: false, reason: '不明な配属' };''', 'staffing validation')
s = replace_once(s,
'''    emit('staffing', { text: plan === 'receiving' ? '人員配置: 受入強化' : plan === 'shipping' ? '人員配置: 出荷強化' : '人員配置: 均衡' });''',
'''    const labels = { receiving: '受入強化 3·1·1', balanced: '均衡 2·2·1', picking: 'ピック強化 1·3·1', dock: '両端強化 2·1·2', shipping: '出荷強化 1·2·2' };
    emit('staffing', { text: `人員配置: ${labels[plan] || plan}` });''', 'staffing label')
s = replace_once(s,
'''  function update(realDt) {
    const scaled = clamp(realDt, 0, 0.05) * state.timeScale;''',
'''  function updateDecisionImpact(dt) {
    if (!state.decisionImpact) return;
    state.decisionImpact.elapsed += dt;
  }

  function fulfillmentReadiness() {
    const groups = ['intakeStrategy', 'rackStrategy', 'packStrategy'];
    const zones = groups.filter((group) => Object.keys(FACILITY_INFO).some((key) => FACILITY_INFO[key].group === group && state.facilities[key])).length;
    const contracts = Math.min(8, state.completedContracts);
    const throughput = Math.min(6, state.metrics.perMinute);
    const conditions = { zones: zones >= 3, contracts: state.completedContracts >= 8, throughput: state.metrics.perMinute >= 6 };
    const score = Number(conditions.zones) + Number(conditions.contracts) + Number(conditions.throughput);
    return { zones, contracts, throughput, conditions, score, ready: score === 3 };
  }

  function decisionImpact() {
    const impact = state.decisionImpact;
    if (!impact) return null;
    const c = counts();
    const rackRatio = c.rack / Math.max(1, rackCapacity());
    return {
      ...impact,
      ready: impact.elapsed >= 20,
      current: { throughput: state.metrics.perMinute, rackRatio, inbound: c.inbound, orders: state.ordersOpen },
      delta: {
        throughput: state.metrics.perMinute - impact.before.throughput,
        rackPoints: Math.round((rackRatio - impact.before.rackRatio) * 100),
        inbound: c.inbound - impact.before.inbound,
        orders: state.ordersOpen - impact.before.orders,
      },
    };
  }

  function update(realDt) {
    const scaled = clamp(realDt, 0, 0.05) * state.timeScale;''', 'readiness helpers')
s = replace_once(s,
'''    simClock += scaled;
    state.staffingCooldown = Math.max(0, state.staffingCooldown - scaled);''',
'''    simClock += scaled;
    state.staffingCooldown = Math.max(0, state.staffingCooldown - scaled);
    updateDecisionImpact(scaled);''', 'impact timer')
s = replace_once(s,
'''  const cost = facilityCost(type);
  if (state.money < cost) return { ok: false, reason: '資金不足' };
  state.money -= cost;
  state.facilities[type] = true;''',
'''  const cost = facilityCost(type);
  if (state.money < cost) return { ok: false, reason: '資金不足' };
  const beforeCounts = counts();
  const before = {
    throughput: state.metrics.perMinute,
    rackRatio: beforeCounts.rack / Math.max(1, rackCapacity()),
    inbound: beforeCounts.inbound,
    orders: state.ordersOpen,
  };
  state.money -= cost;
  state.facilities[type] = true;
  state.decisionImpact = { type, label: def.label, elapsed: 0, before };''', 'impact baseline')
s = replace_once(s,
'''    if (snapshot.schema_version >= 3 && ['balanced', 'receiving', 'shipping'].includes(snapshot.staffingPlan)) state.staffingPlan = snapshot.staffingPlan;''',
'''    if (snapshot.schema_version >= 3 && ['balanced', 'receiving', 'picking', 'dock', 'shipping'].includes(snapshot.staffingPlan)) state.staffingPlan = snapshot.staffingPlan;''', 'hydrate staffing plans')
s = replace_once(s,
'''    state.activeContract = null;
    state.workers.splice(0);''',
'''    state.activeContract = null;
    state.decisionImpact = null;
    state.workers.splice(0);''', 'reset impact')
s = replace_once(s,
'''    staffingSummary,
    setStaffingPlan,
    setTimeScale,''',
'''    staffingSummary,
    setStaffingPlan,
    fulfillmentReadiness,
    decisionImpact,
    setTimeScale,''', 'return phase2 helpers')
p.write_text(s)

# ui.js
p = Path('docs/src/ui.js')
s = p.read_text()
s = replace_once(s,
'''    crewShip: document.getElementById('crewShip'),
  };''',
'''    crewShip: document.getElementById('crewShip'),
    opsCrew: document.getElementById('opsCrew'),
    opsWeakness: document.getElementById('opsWeakness'),
    opsNext: document.getElementById('opsNext'),
    facilityImpact: document.getElementById('facilityImpact'),
    goalZones: document.getElementById('goalZones'),
    goalContracts: document.getElementById('goalContracts'),
    goalThroughput: document.getElementById('goalThroughput'),
    nextStageBar: document.getElementById('nextStageBar'),
    nextStageHint: document.getElementById('nextStageHint'),
  };''', 'ui refs')
s = replace_once(s,
'''    const crew = sim.staffingSummary();
    el.crewStore.textContent = String(crew.store);''',
'''    const crew = sim.staffingSummary();
    const weaknessNames = { inbound: '荷受け', rack: '保管', orders: '注文処理', packed: '出荷口', stable: 'なし' };
    const readiness = sim.fulfillmentReadiness();
    if (el.opsCrew) el.opsCrew.textContent = s.facilityRank >= 2 ? `人員 ${crew.store}·${crew.pick}·${crew.ship}` : '人員 方針運転';
    if (el.opsWeakness) el.opsWeakness.textContent = `弱点 ${weaknessNames[d.key] || d.label}`;
    if (el.opsNext) el.opsNext.textContent = s.facilityRank >= 2 ? `NEXT ${readiness.score}/3` : `NEXT RANK 2`;
    if (el.goalZones) el.goalZones.textContent = `区画 ${readiness.zones}/3`;
    if (el.goalContracts) el.goalContracts.textContent = `契約 ${Math.min(s.completedContracts, 8)}/8`;
    if (el.goalThroughput) el.goalThroughput.textContent = `出荷 ${Math.min(s.metrics.perMinute, 6)}/6分`;
    if (el.nextStageBar) el.nextStageBar.style.width = `${(readiness.score / 3) * 100}%`;
    if (el.nextStageHint) el.nextStageHint.textContent = readiness.ready ? '自動化設計の準備完了 · 次はコンベア/ソーターへ' : '3条件を満たすと自動化設計の準備完了';

    const impact = sim.decisionImpact();
    if (el.facilityImpact) {
      el.facilityImpact.hidden = !impact;
      if (impact) {
        if (!impact.ready) {
          el.facilityImpact.textContent = `${impact.label}の効果を観測中… ${Math.min(20, Math.floor(impact.elapsed))}/20秒`;
        } else {
          const signed = (n, suffix = '') => `${n > 0 ? '+' : ''}${n}${suffix}`;
          el.facilityImpact.innerHTML = `<strong>${impact.label} · 実測</strong><span>出荷 ${signed(impact.delta.throughput, '/分')}</span><span>棚使用 ${signed(impact.delta.rackPoints, 'pt')}</span><span>入荷待ち ${signed(impact.delta.inbound, '箱')}</span><span>注文 ${signed(impact.delta.orders, '件')}</span>`;
        }
      }
    }

    el.crewStore.textContent = String(crew.store);''', 'render phase2 summary')
p.write_text(s)

# ux.css
p = Path('docs/ux.css')
s = p.read_text()
s += '''\n\n/* Rank 2 Systems Pass 2 */\n#app.rank2 .dockMini{justify-content:stretch;gap:5px}\n.opsMiniSummary{display:none;min-width:0;flex:1;align-items:center;gap:6px;padding:0 7px;border-radius:10px;background:rgba(255,255,255,.025);overflow:hidden}\n#app.rank2 .opsMiniSummary{display:flex}\n.opsMiniSummary strong,.opsMiniSummary span{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.opsMiniSummary strong{font-size:9px;color:#edf6fa}.opsMiniSummary span{font-size:8px;color:#8fa3af}.opsMiniSummary #opsNext{color:#72d8ff;font-weight:900}\n#app.rank2 .quickSpeed,#app.rank2 .miniUtility{flex:0 0 auto}\n.staffingChoices{grid-template-columns:repeat(5,minmax(0,1fr))}.staffingChoices button{min-height:54px}.staffingChoices button strong{font-size:8px}.staffingChoices button small{font-size:7px}\n.facilityImpact{display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-top:7px;padding:8px;border-radius:11px;border:1px solid rgba(94,220,154,.24);background:rgba(58,149,101,.08);color:#a8b8c2;font-size:8px}.facilityImpact[hidden]{display:none}.facilityImpact strong{grid-column:1/-1;color:#c8ffe0;font-size:10px}.facilityImpact span{padding:5px;border-radius:7px;background:rgba(255,255,255,.035);text-align:center}\n.nextStagePanel{margin-top:8px;padding:8px;border-radius:12px;border:1px solid rgba(101,211,255,.16);background:rgba(33,74,97,.08)}.nextStageHead{display:flex;align-items:end;justify-content:space-between}.nextStageHead small{font-size:7px;letter-spacing:.12em;color:#7f95a2}.nextStageHead strong{font-size:11px;color:#d8f5ff}.nextStageGoals{display:flex;gap:5px;margin-top:7px}.nextStageGoals span{flex:1;padding:5px;border-radius:7px;background:rgba(255,255,255,.035);font-size:8px;color:#a6b4bd;text-align:center}.nextStageBar{height:4px;margin-top:7px;border-radius:999px;background:rgba(255,255,255,.06);overflow:hidden}.nextStageBar i{display:block;height:100%;width:0;background:#63d3ff;transition:width .3s}.nextStagePanel>small{display:block;margin-top:6px;color:#81939f;font-size:8px}\n@media (max-width:500px){.staffingChoices{grid-template-columns:repeat(3,1fr)}.opsMiniSummary span:nth-of-type(1){display:none}.facilityImpact{grid-template-columns:repeat(2,1fr)}}\n'''
p.write_text(s)

# progression smoke test: replace whole file with focused regression checks
Path('docs/tests/progression-smoke.mjs').write_text(r'''import { createSimulation } from '../src/sim.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 3, 'fresh save must use schema v3');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(!fresh.setStaffingPlan('picking').ok, 'Rank 1 must not reassign Warehouse crew');

const migrated = createSimulation({
  schema_version: 2,
  money: 20000,
  research: 0,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: {},
  shipped: 0,
  completedContracts: 4,
  milestoneAwarded: 0,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {},
  perks: {},
});
assert(migrated.state.facilityRank === 2, 'schema v2 Warehouse must migrate');
assert(migrated.state.schema_version === 3, 'migrated runtime must use schema v3');
assert(migrated.state.workers.length === 5, 'Warehouse must use five-person crew');
assert(migrated.setStaffingPlan('picking').ok, 'picking plan must be selectable');
let crew = migrated.staffingSummary();
assert(crew.store === 1 && crew.pick === 3 && crew.ship === 1, 'picking plan must be 1/3/1');
migrated.state.staffingCooldown = 0;
assert(migrated.setStaffingPlan('dock').ok, 'dock plan must be selectable');
crew = migrated.staffingSummary();
assert(crew.store === 2 && crew.pick === 1 && crew.ship === 2, 'dock plan must be 2/1/2');

migrated.state.money = 20000;
assert(migrated.purchaseFacility('bufferYard').ok, 'buffer yard must be buildable');
assert(!migrated.purchaseFacility('secondInbound').ok, 'zone A choice must be exclusive');
assert(migrated.purchaseFacility('fastPickRack').ok, 'zone B choice must be buildable');
assert(migrated.purchaseFacility('fastPackCell').ok, 'zone C choice must be buildable');
assert(migrated.decisionImpact()?.type === 'fastPackCell', 'facility purchase must start impact observation');
const ready = migrated.fulfillmentReadiness();
assert(ready.zones === 3, 'three selected zones must count toward Fulfillment readiness');
assert(ready.score >= 1, 'zone completion must contribute to readiness');

const roundTrip = createSimulation(migrated.serialize());
assert(roundTrip.state.staffingPlan === 'dock', 'staffing plan must survive save/load');
assert(roundTrip.state.facilities.bufferYard, 'facility choice must survive save/load');
assert(roundTrip.fulfillmentReadiness().zones === 3, 'readiness zone count must survive save/load');
console.log('Progression Spine / Rank 2 Systems smoke OK');
''')

# QA contract
p = Path('.github/workflows/qa.yml')
s = p.read_text()
anchor = '''      - name: Rank 1 UX FTUE contract\n'''
block = '''      - name: Rank 2 Systems Pass 2 contract\n        shell: bash\n        run: |\n          set -euo pipefail\n          grep -Fq 'id="opsMiniSummary"' docs/index.html\n          grep -Fq 'data-staffing-plan="picking"' docs/index.html\n          grep -Fq 'data-staffing-plan="dock"' docs/index.html\n          grep -Fq 'id="facilityImpact"' docs/index.html\n          grep -Fq 'Fulfillment Center' docs/index.html\n          grep -Fq 'function fulfillmentReadiness()' docs/src/sim.js\n          grep -Fq 'function decisionImpact()' docs/src/sim.js\n          grep -Fq 'decisionImpact = { type' docs/src/sim.js\n          grep -Fq 'opsMiniSummary' docs/src/ui.js\n          grep -Fq 'nextStageBar' docs/src/ui.js\n          node docs/tests/progression-smoke.mjs\n          ! test -f .github/workflows/rank2-systems-pass2-apply.yml\n          ! test -f .github/rank2-systems-pass2-trigger.txt\n          ! test -f tools/rank2_systems_pass2_patch.py\n          echo "Rank 2 Systems Pass 2 contract OK"\n\n'''
if block not in s:
    if anchor not in s: raise SystemExit('missing qa anchor')
    s = s.replace(anchor, block + anchor, 1)
p.write_text(s)

# GDD lock
p = Path('GDD_LOGISTICS_BOSS.md')
s = p.read_text()
lock = '''\n\n## Rank 2 Systems Pass — Phase 2 LOCK (2026-09-14)\n\n- Rank 2 compact dock must show the current crew split, current weakest process, and progress toward the next automation stage; empty chrome is not acceptable.\n- Warehouse staffing remains a low-frequency strategic choice. Five presets expose exact 5-person allocations: 3/1/1, 2/2/1, 1/3/1, 2/1/2, 1/2/2. Reassignment keeps a 30-second observation lock.\n- Every Rank 2 zone decision starts a 20-second observation window and reports measured throughput, rack utilization, inbound queue, and open-order deltas.\n- The next visible goal is Fulfillment Center readiness: all 3 expansion zones chosen, 8 completed contracts, and at least 6 shipments/minute. This is a readiness gate only; Rank 3 gameplay is not claimed complete until conveyor/sorter gameplay exists.\n- Director continues to diagnose rather than provide a one-tap solution at Rank 2+.\n'''
if 'Rank 2 Systems Pass — Phase 2 LOCK' not in s:
    s += lock
p.write_text(s)
