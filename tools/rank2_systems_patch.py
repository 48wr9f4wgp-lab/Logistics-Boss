from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)

# ---------------- sim.js ----------------
p = Path('docs/src/sim.js')
s = p.read_text()

s = replace_once(s,
"const PERK_INFO = {\n  smartDispatch: { label: 'スマート配車', cost: 2, max: 3, desc: '混雑度に応じて仕事選択を自動補正' },\n  bulkPack: { label: '標準化梱包', cost: 2, max: 3, desc: '梱包時間 -15%' },\n  contractBonus: { label: '高単価契約', cost: 3, max: 2, desc: '契約報酬 +25%' },\n};\n\nconst FACILITY_INFO = {\n  secondInbound: { label: '第2搬入口', cost: 2400, rank: 2, desc: '受入容量+6 / 入荷間隔を22%短縮' },\n  fastPickRack: { label: '高速ピックラック', cost: 2800, rank: 2, group: 'rackStrategy', desc: '棚容量+4 / ピッキング移動+25%' },\n  highDensityRack: { label: '高密度ラック', cost: 2800, rank: 2, group: 'rackStrategy', desc: '棚容量+12 / ピッキング移動-14%' },\n  secondPack: { label: '第2梱包ライン', cost: 3200, rank: 2, desc: '同時梱包数 1→2' },\n};",
"const PERK_INFO = {\n  smartDispatch: { label: 'スマート配車', cost: 4, max: 1, desc: '担当内で混雑度に応じて仕事選択を自動補正' },\n  bulkPack: { label: '標準化梱包', cost: 4, max: 1, desc: '梱包時間 -15%' },\n  contractBonus: { label: '高単価契約', cost: 5, max: 1, desc: '契約報酬 +25%' },\n};\n\nconst FACILITY_INFO = {\n  secondInbound: { label: 'ダブルドック', cost: 2400, rank: 2, group: 'intakeStrategy', zone: 'A', desc: '入荷上限+6 / 入荷22%増。稼げるが内部が詰まりやすい' },\n  bufferYard: { label: '受入バッファ', cost: 2200, rank: 2, group: 'intakeStrategy', zone: 'A', desc: '入荷上限+14。処理速度は増えないがピークに強い' },\n  fastPickRack: { label: '高速ピックラック', cost: 2800, rank: 2, group: 'rackStrategy', zone: 'B', desc: '保管+4 / ピック25%速。高速回転向け' },\n  highDensityRack: { label: '高密度ラック', cost: 2800, rank: 2, group: 'rackStrategy', zone: 'B', desc: '保管+12 / ピック14%遅。大量在庫向け' },\n  secondPack: { label: '並列梱包ライン', cost: 3200, rank: 2, group: 'packStrategy', zone: 'C', desc: '同時2箱 / 1箱あたり10%遅。波に強い' },\n  fastPackCell: { label: '高速梱包セル', cost: 3000, rank: 2, group: 'packStrategy', zone: 'C', desc: '同時1箱 / 梱包42%速。少量高速向け' },\n};",
'perk and facility definitions')

s = s.replace("    role: null,\n", "")
s = replace_once(s,
"    facing: 0,\n  };\n}",
"    facing: 0,\n    role: 'store',\n  };\n}",
'worker role')

s = s.replace("    schema_version: 2,", "    schema_version: 3,", 1)
s = replace_once(s,
"    facilities: { secondInbound: false, fastPickRack: false, highDensityRack: false, secondPack: false },\n    shipped: 0,",
"    facilities: { secondInbound: false, bufferYard: false, fastPickRack: false, highDensityRack: false, secondPack: false, fastPackCell: false },\n    staffingPlan: 'balanced',\n    staffingCooldown: 0,\n    shipped: 0,",
'new facility state')

s = replace_once(s,
"  function workerCount() {\n    return BASE.workerCount + state.upgrades.worker;\n  }",
"  function workerCount() {\n    const rankBonus = state.facilityRank >= 2 ? 2 : 0;\n    return BASE.workerCount + rankBonus + state.upgrades.worker;\n  }",
'rank 2 staff bonus')

s = replace_once(s,
"function inboundMax() {\n  return BASE.inboundMax + (state.facilities.secondInbound ? 6 : 0);\n}\n\nfunction inboundInterval() {\n  return BASE.inboundInterval * (state.facilities.secondInbound ? 0.78 : 1);\n}\n\nfunction packCapacity() {\n  return 1 + (state.facilities.secondPack ? 1 : 0);\n}",
"function inboundMax() {\n  if (state.facilities.bufferYard) return BASE.inboundMax + 14;\n  return BASE.inboundMax + (state.facilities.secondInbound ? 6 : 0);\n}\n\nfunction inboundInterval() {\n  return BASE.inboundInterval * (state.facilities.secondInbound ? 0.78 : 1);\n}\n\nfunction packCapacity() {\n  return state.facilities.secondPack ? 2 : 1;\n}",
'facility throughput functions')

s = replace_once(s,
"    const perkFactor = Math.pow(0.85, state.perks.bulkPack);\n    return BASE.packTime * upgradeFactor * perkFactor;",
"    const perkFactor = Math.pow(0.85, state.perks.bulkPack);\n    const facilityFactor = state.facilities.fastPackCell ? 0.58 : state.facilities.secondPack ? 1.10 : 1;\n    return BASE.packTime * upgradeFactor * perkFactor * facilityFactor;",
'pack tradeoff')

s = replace_once(s,
"  function ensureWorkers() {\n    while (state.workers.length < workerCount()) {\n      const index = state.workers.length;\n      state.workers.push(createWorker(nextWorkerId++, index));\n      emit('worker_hired', { text: 'スタッフが増えた' });\n    }\n  }",
"  function staffingSequence(plan) {\n    if (plan === 'receiving') return ['store', 'pick', 'ship', 'store', 'store', 'pick', 'store', 'ship'];\n    if (plan === 'shipping') return ['store', 'pick', 'ship', 'ship', 'pick', 'ship', 'pick', 'store'];\n    return ['store', 'pick', 'ship', 'store', 'pick', 'ship', 'store', 'pick'];\n  }\n\n  function applyStaffingPlan() {\n    const sequence = staffingSequence(state.staffingPlan);\n    state.workers.forEach((worker, index) => { worker.role = sequence[index % sequence.length]; });\n  }\n\n  function staffingSummary() {\n    const result = { store: 0, pick: 0, ship: 0, total: state.workers.length };\n    for (const worker of state.workers) result[worker.role] = (result[worker.role] || 0) + 1;\n    return result;\n  }\n\n  function setStaffingPlan(plan) {\n    if (state.facilityRank < 2) return { ok: false, reason: 'Warehouseで解禁' };\n    if (!['balanced', 'receiving', 'shipping'].includes(plan)) return { ok: false, reason: '不明な配属' };\n    if (state.staffingCooldown > 0) return { ok: false, reason: `配置替え中 ${Math.ceil(state.staffingCooldown)}秒` };\n    if (state.staffingPlan === plan) return { ok: false, reason: '現在の配属です' };\n    state.staffingPlan = plan;\n    state.staffingCooldown = 30;\n    applyStaffingPlan();\n    emit('staffing', { text: plan === 'receiving' ? '人員配置: 受入強化' : plan === 'shipping' ? '人員配置: 出荷強化' : '人員配置: 均衡' });\n    markDirty();\n    return { ok: true };\n  }\n\n  function ensureWorkers() {\n    while (state.workers.length < workerCount()) {\n      const index = state.workers.length;\n      state.workers.push(createWorker(nextWorkerId++, index));\n      emit('worker_hired', { text: 'スタッフが増えた' });\n    }\n    applyStaffingPlan();\n  }",
'staffing system')

s = replace_once(s,
"  function policyWeights() {\n    if (state.policy === 'inbound') return { store: 1.8, pick: 0.72, ship: 1.05 };",
"  function policyWeights() {\n    if (state.facilityRank >= 2) return { store: 1, pick: 1, ship: 1 };\n    if (state.policy === 'inbound') return { store: 1.8, pick: 0.72, ship: 1.05 };",
'rank 2 ignores twitch policy')

s = replace_once(s,
"    options.sort((a, b) => b.score - a.score);\n    const selected = options[0];",
"    const eligible = state.facilityRank >= 2 ? options.filter((option) => option.kind === worker.role) : options;\n    eligible.sort((a, b) => b.score - a.score);\n    const selected = eligible[0];",
'role constrained tasks')

s = replace_once(s,
"    state.facilityRank = 2;\n    emit('rank_up', { rank: 2, name: facilityRankName(2), text: '施設ランクUP: Warehouse' });",
"    state.facilityRank = 2;\n    ensureWorkers();\n    applyStaffingPlan();\n    emit('rank_up', { rank: 2, name: facilityRankName(2), text: '施設ランクUP: Warehouse / 5人編成を解禁' });",
'rank up crew')

s = replace_once(s,
"    simClock += scaled;\n    updateSpawners(scaled);",
"    simClock += scaled;\n    state.staffingCooldown = Math.max(0, state.staffingCooldown - scaled);\n    updateSpawners(scaled);",
'staffing cooldown tick')

s = replace_once(s,
"  if (def.group === 'rackStrategy') {\n    const other = type === 'fastPickRack' ? 'highDensityRack' : 'fastPickRack';\n    if (state.facilities[other]) return { ok: false, reason: 'ラック方針は選択済み' };\n  }",
"  if (def.group) {\n    const chosen = Object.keys(FACILITY_INFO).find((key) => key !== type && FACILITY_INFO[key].group === def.group && state.facilities[key]);\n    if (chosen) return { ok: false, reason: `区画${def.zone}は選択済み` };\n  }",
'generic mutually exclusive zones')

s = replace_once(s,
"  function hydrate(snapshot) {\n    if (!snapshot || ![1, 2].includes(snapshot.schema_version)) return;",
"  function hydrate(snapshot) {\n    if (!snapshot || ![1, 2, 3].includes(snapshot.schema_version)) return;",
'save versions')

s = replace_once(s,
"  if (snapshot.schema_version === 2) {\n    if (Number.isFinite(snapshot.logisticsRating)) state.logisticsRating = Math.max(0, Math.floor(snapshot.logisticsRating));\n    if (Number.isFinite(snapshot.facilityRank)) state.facilityRank = clamp(Math.floor(snapshot.facilityRank), 1, 2);\n    if (snapshot.facilities && typeof snapshot.facilities === 'object') {\n      for (const key of Object.keys(FACILITY_INFO)) state.facilities[key] = Boolean(snapshot.facilities[key]);\n    }\n  } else {",
"  if (snapshot.schema_version >= 2) {\n    if (Number.isFinite(snapshot.logisticsRating)) state.logisticsRating = Math.max(0, Math.floor(snapshot.logisticsRating));\n    if (Number.isFinite(snapshot.facilityRank)) state.facilityRank = clamp(Math.floor(snapshot.facilityRank), 1, 2);\n    if (snapshot.facilities && typeof snapshot.facilities === 'object') {\n      for (const key of Object.keys(FACILITY_INFO)) state.facilities[key] = Boolean(snapshot.facilities[key]);\n    }\n    if (snapshot.schema_version >= 3 && ['balanced', 'receiving', 'shipping'].includes(snapshot.staffingPlan)) state.staffingPlan = snapshot.staffingPlan;\n  } else {",
'migrate v2/v3')

s = replace_once(s,
"      schema_version: 2,\n    money: state.money,",
"      schema_version: 3,\n    money: state.money,",
'serialize schema')
s = replace_once(s,
"    facilities: { ...state.facilities },\n    shipped: state.shipped,",
"    facilities: { ...state.facilities },\n    staffingPlan: state.staffingPlan,\n    shipped: state.shipped,",
'serialize staffing')

s = replace_once(s,
"  state.facilities = { secondInbound: false, fastPickRack: false, highDensityRack: false, secondPack: false };\n  state.shipped = 0;",
"  state.facilities = { secondInbound: false, bufferYard: false, fastPickRack: false, highDensityRack: false, secondPack: false, fastPackCell: false };\n  state.staffingPlan = 'balanced';\n  state.staffingCooldown = 0;\n  state.shipped = 0;",
'reset new state')

s = replace_once(s,
"    facilityCost,\n    upgradeCost,",
"    facilityCost,\n    staffingSummary,\n    setStaffingPlan,\n    upgradeCost,",
'export staffing')

p.write_text(s)

# ---------------- index.html ----------------
p = Path('docs/index.html')
h = p.read_text()

priority_start = h.index('        <div class="priorityStrip" aria-label="細かい優先度">')
priority_end = h.index('        <div class="speedRow" aria-label="時間速度">', priority_start)
staffing = '''        <section id="staffingPanel" class="staffingPanel" aria-label="人員配置">
          <div class="staffingHead"><div><small>CREW PLAN</small><strong>5人をどこへ厚く置くか</strong></div><span id="staffingLock">Rank 2で解禁</span></div>
          <div class="staffingCounts"><span>入荷 <b id="crewStore">1</b></span><span>ピック <b id="crewPick">1</b></span><span>出荷 <b id="crewShip">1</b></span></div>
          <div class="staffingChoices">
            <button type="button" data-staffing-plan="receiving"><strong>受入強化</strong><small>入荷側に厚く配置</small></button>
            <button type="button" data-staffing-plan="balanced"><strong>均衡</strong><small>全工程へ均等配置</small></button>
            <button type="button" data-staffing-plan="shipping"><strong>出荷強化</strong><small>ピック・出荷側へ厚く配置</small></button>
          </div>
        </section>

'''
h = h[:priority_start] + staffing + h[priority_end:]

facility_start = h.index('<div class="facilityStrip" aria-label="施設開発">')
facility_end = h.index('\n\n<div class="sectionLabel">設備</div>', facility_start)
zone_markup = '''<div class="facilityZones" aria-label="拡張区画">
  <section class="facilityZone" data-zone="A"><div class="zoneHead"><strong>区画A · 荷受け</strong><span>どちらか1つ</span></div><div class="zoneChoices">
    <button class="facilityChoice" type="button" data-facility="secondInbound"><strong>ダブルドック</strong><span>上限+6 / 入荷22%増<br>高収益・高負荷</span><small data-facility-cost>¥2,400</small></button>
    <button class="facilityChoice" type="button" data-facility="bufferYard"><strong>受入バッファ</strong><span>上限+14 / 入荷量は据置<br>ピーク耐性型</span><small data-facility-cost>¥2,200</small></button>
  </div></section>
  <section class="facilityZone" data-zone="B"><div class="zoneHead"><strong>区画B · 保管</strong><span>どちらか1つ</span></div><div class="zoneChoices">
    <button class="facilityChoice" type="button" data-facility="fastPickRack"><strong>高速ピックラック</strong><span>保管+4 / ピック25%速<br>高速回転型</span><small data-facility-cost>¥2,800</small></button>
    <button class="facilityChoice" type="button" data-facility="highDensityRack"><strong>高密度ラック</strong><span>保管+12 / ピック14%遅<br>大量在庫型</span><small data-facility-cost>¥2,800</small></button>
  </div></section>
  <section class="facilityZone" data-zone="C"><div class="zoneHead"><strong>区画C · 梱包</strong><span>どちらか1つ</span></div><div class="zoneChoices">
    <button class="facilityChoice" type="button" data-facility="secondPack"><strong>並列梱包ライン</strong><span>同時2箱 / 各10%遅<br>波への耐性型</span><small data-facility-cost>¥3,200</small></button>
    <button class="facilityChoice" type="button" data-facility="fastPackCell"><strong>高速梱包セル</strong><span>同時1箱 / 42%速<br>少量高速型</span><small data-facility-cost>¥3,000</small></button>
  </div></section>
</div>'''
h = h[:facility_start] + zone_markup + h[facility_end:]

equip_start = h.index('<div class="sectionLabel">設備</div>')
equip_end = h.index('        <div class="sectionLabel">研究</div>', equip_start)
h = h[:equip_start] + '''<div class="legacyNotice">数値Lvアップは廃止。Rank 2以降は人員配置と拡張区画で物流構造を変える。</div>\n\n''' + h[equip_end:]

p.write_text(h)

# ---------------- ux.css ----------------
p = Path('docs/ux.css')
css = p.read_text()
css += r'''

/* Rank 2 Systems Pass */
#app.rank2 .miniPolicies{display:none}
#app.rank2 .dockMini{justify-content:flex-end}
.staffingPanel{margin-top:8px;padding:8px;border-radius:12px;border:1px solid rgba(101,211,255,.14);background:rgba(43,83,105,.08)}
.staffingHead{display:flex;align-items:flex-start;justify-content:space-between;gap:8px}.staffingHead small{display:block;color:#82919c;font-size:8px;letter-spacing:.12em}.staffingHead strong{display:block;margin-top:2px;font-size:11px}.staffingHead>span{font-size:9px;color:#93a6b4}
.staffingCounts{display:flex;gap:6px;margin-top:7px}.staffingCounts span{flex:1;padding:5px 6px;border-radius:8px;background:rgba(255,255,255,.04);color:#9cabb5;font-size:9px}.staffingCounts b{float:right;color:#f3f7fa;font-size:11px}
.staffingChoices{display:grid;grid-template-columns:repeat(3,1fr);gap:5px;margin-top:7px}.staffingChoices button{min-height:48px;padding:6px;border:1px solid rgba(255,255,255,.11);border-radius:10px;background:rgba(255,255,255,.045);color:#eaf0f4;text-align:left}.staffingChoices button strong{display:block;font-size:9px}.staffingChoices button small{display:block;margin-top:3px;color:#8fa0ac;font-size:8px;line-height:1.2}.staffingChoices button.active{border-color:rgba(101,211,255,.5);background:rgba(65,164,211,.17)}.staffingChoices button:disabled{opacity:.38}
.facilityZones{display:grid;gap:7px;margin-top:7px}.facilityZone{padding:7px;border-radius:12px;border:1px solid rgba(255,255,255,.08);background:rgba(255,255,255,.025)}.zoneHead{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:6px}.zoneHead strong{font-size:10px}.zoneHead span{font-size:8px;color:#8798a4}.zoneChoices{display:grid;grid-template-columns:1fr 1fr;gap:6px}.zoneChoices .facilityChoice{min-height:82px;min-width:0;display:block}.facilityChoice.chosenOther{opacity:.34;filter:saturate(.5)}
.legacyNotice{margin:8px 0;padding:7px 8px;border-radius:9px;background:rgba(255,255,255,.035);color:#8fa0aa;font-size:9px;line-height:1.35}
#app.rank2 #directorActionRow #directorAction{display:none}
'''
p.write_text(css)

# ---------------- ui.js ----------------
p = Path('docs/src/ui.js')
u = p.read_text()

u = replace_once(u,
"  const priorityButtons = [...document.querySelectorAll('[data-priority-kind]')];",
"  const staffingPlanButtons = [...document.querySelectorAll('[data-staffing-plan]')];",
'query staffing buttons')

u = replace_once(u,
"    celebrationReward: document.getElementById('celebrationReward'),\n  };",
"    celebrationReward: document.getElementById('celebrationReward'),\n    staffingLock: document.getElementById('staffingLock'),\n    crewStore: document.getElementById('crewStore'),\n    crewPick: document.getElementById('crewPick'),\n    crewShip: document.getElementById('crewShip'),\n  };",
'staffing refs')

start = u.index('  priorityButtons.forEach((button) => {')
end = u.index('  speedButtons.forEach((button) => {', start)
replacement = '''  staffingPlanButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const result = sim.setStaffingPlan(button.dataset.staffingPlan);
      if (!result.ok) toast(result.reason, 'warn');
      else { toast('人員配置を変更。しばらく観察しよう', 'good'); try { navigator.vibrate?.(14); } catch {} }
      render();
    });
  });

'''
u = u[:start] + replacement + u[end:]

# Director actions are Rank 1 teaching only.
u = u.replace("    if (action === 'contract') setInsightCompact(false);", "    if (sim.state.facilityRank >= 2) return;\n    if (action === 'contract') setInsightCompact(false);")

# Replace rank/progress display.
u = replace_once(u,
"  el.logisticsRating.textContent = nextTarget == null ? `物流評価 ${s.logisticsRating} · MAX` : `物流評価 ${s.logisticsRating} / ${nextTarget}`;\n  el.facilityProgressBar.style.width = `${nextTarget == null ? 100 : Math.min(100, (s.logisticsRating / nextTarget) * 100)}%`;",
"  const zoneGroups = ['intakeStrategy', 'rackStrategy', 'packStrategy'];\n  const chosenZones = zoneGroups.filter((group) => Object.keys(sim.facilityInfo).some((key) => sim.facilityInfo[key].group === group && s.facilities[key])).length;\n  el.logisticsRating.textContent = nextTarget == null ? `拡張区画 ${chosenZones} / 3` : `物流評価 ${s.logisticsRating} / ${nextTarget}`;\n  el.facilityProgressBar.style.width = `${nextTarget == null ? (chosenZones / 3) * 100 : Math.min(100, (s.logisticsRating / nextTarget) * 100)}%`;\n  document.getElementById('app')?.classList.toggle('rank2', s.facilityRank >= 2);",
'rank2 zone progress')

# Replace director branch for Rank 2 with diagnosis-only behavior.
old = "    if (d.severity > 0 && human[d.key]) ({ label, detail, recommendation, action, actionLabel } = human[d.key]);\n    else if (s.facilityRank < 2) {"
new = "    if (d.severity > 0 && human[d.key]) {\n      ({ label, detail, recommendation, action, actionLabel } = human[d.key]);\n      if (s.facilityRank >= 2) {\n        action = ''; actionLabel = '';\n        const diagnose = { inbound: '受入量が棚入れ能力を上回っています', rack: '保管量が下流の処理能力を上回っています', orders: '注文到着がピック・梱包能力を上回っています', packed: '梱包完了が出荷能力を上回っています' };\n        recommendation = diagnose[d.key] || 'どの工程へ人員・区画能力を寄せるか判断してください';\n      }\n    } else if (s.facilityRank < 2) {"
u = replace_once(u, old, new, 'rank2 diagnosis')

u = replace_once(u,
"    } else if (d.severity === 0) { label = '次は物流設備を選ぶ'; detail = 'Warehouse解禁済み'; recommendation = '管理から、第2搬入口・ラック方針・第2梱包ラインへ投資'; action = 'management'; actionLabel = '設備を見る'; }",
"    } else if (d.severity === 0) {\n      const crew = sim.staffingSummary();\n      label = chosenZones < 3 ? `Warehouse設計 · 区画${chosenZones}/3` : 'Warehouse安定運転';\n      detail = `人員 入荷${crew.store} / ピック${crew.pick} / 出荷${crew.ship}`;\n      recommendation = chosenZones < 3 ? '未決定区画を選び、物流の性格を作る' : 'FLOWを観察し、次の自動化段階に備える';\n      action = ''; actionLabel = '';\n    }",
'rank2 stable director')

# Replace old priority render block with staffing render.
start = u.index("    document.querySelectorAll('[data-priority]').forEach((row) => {")
end = u.index('    facilityButtons.forEach((button) => {', start)
staff_render = '''    const crew = sim.staffingSummary();
    el.crewStore.textContent = String(crew.store);
    el.crewPick.textContent = String(crew.pick);
    el.crewShip.textContent = String(crew.ship);
    el.staffingLock.textContent = s.facilityRank < 2 ? 'Rank 2で解禁' : s.staffingCooldown > 0 ? `配置替え ${Math.ceil(s.staffingCooldown)}秒` : '変更可能';
    staffingPlanButtons.forEach((button) => {
      button.classList.toggle('active', button.dataset.staffingPlan === s.staffingPlan);
      button.disabled = s.facilityRank < 2 || s.staffingCooldown > 0;
    });

'''
u = u[:start] + staff_render + u[end:]

# Generic zone conflict logic.
u = replace_once(u,
"    const conflicting = def.group === 'rackStrategy' && !built && (s.facilities.fastPickRack || s.facilities.highDensityRack);",
"    const selectedInGroup = def.group ? Object.keys(sim.facilityInfo).find((key) => sim.facilityInfo[key].group === def.group && s.facilities[key]) : null;\n    const conflicting = Boolean(selectedInGroup && selectedInGroup !== type);",
'facility group conflict ui')
u = u.replace("    button.classList.toggle('locked', locked);", "    button.classList.toggle('locked', locked);\n    button.classList.toggle('chosenOther', conflicting);")

# One-time research reads as unlock rather than repeated level.
old = "      if (levelNode) levelNode.textContent = `Lv.${level}/${def.max}`;"
new = "      if (levelNode) levelNode.textContent = def.max === 1 ? (level ? '解禁済み' : '未研究') : `Lv.${level}/${def.max}`;"
u = u.replace(old, new)

p.write_text(u)

# ---------------- scene.js ----------------
p = Path('docs/src/scene.js')
sc = p.read_text()
sc = replace_once(sc,
"const secondPackFacility = packStation({ x: 4.15, z: 1.45 });\nsecondPackFacility.scale.setScalar(0.82);\nsecondPackFacility.visible = false;\nscene.add(secondPackFacility);",
"const bufferYardFacility = rackBank(-4.7, 2.65, 0x63c8ff);\nbufferYardFacility.scale.setScalar(0.72);\nbufferYardFacility.visible = false;\nscene.add(bufferYardFacility);\nconst secondPackFacility = packStation({ x: 4.15, z: 1.45 });\nsecondPackFacility.scale.setScalar(0.82);\nsecondPackFacility.visible = false;\nscene.add(secondPackFacility);\nconst fastPackCellFacility = packStation({ x: 4.15, z: 1.45 });\nfastPackCellFacility.scale.setScalar(0.68);\nfastPackCellFacility.userData.base.material.color.setHex(0x3c8f88);\nfastPackCellFacility.visible = false;\nscene.add(fastPackCellFacility);",
'new facility visuals')
sc = replace_once(sc,
"  secondInboundFacility.visible = Boolean(facilities.secondInbound);\n  secondPackFacility.visible = Boolean(facilities.secondPack);",
"  secondInboundFacility.visible = Boolean(facilities.secondInbound);\n  bufferYardFacility.visible = Boolean(facilities.bufferYard);\n  secondPackFacility.visible = Boolean(facilities.secondPack);\n  fastPackCellFacility.visible = Boolean(facilities.fastPackCell);",
'facility visibility')
p.write_text(sc)

# ---------------- progression smoke ----------------
Path('docs/tests/progression-smoke.mjs').write_text(r'''import { createSimulation } from '../src/sim.js';

const assert = (condition, message) => { if (!condition) throw new Error(message); };

const fresh = createSimulation(null);
assert(fresh.state.schema_version === 3, 'fresh save must use schema v3');
assert(fresh.state.facilityRank === 1, 'fresh game must start at Rank 1');
assert(fresh.state.workers.length === 3, 'Rank 1 starts with three workers');
assert(!fresh.setStaffingPlan('receiving').ok, 'Rank 1 cannot change crew plan');
assert(!fresh.purchaseFacility('bufferYard').ok, 'Rank 1 cannot build Rank 2 facilities');

const migrated = createSimulation({
  schema_version: 2,
  money: 20000,
  research: 20,
  logisticsRating: 8,
  facilityRank: 2,
  facilities: { secondInbound: false, fastPickRack: false, highDensityRack: false, secondPack: false },
  shipped: 100,
  completedContracts: 4,
  milestoneAwarded: 100,
  policy: 'balanced',
  priorities: { store: 3, pick: 3, ship: 4 },
  upgrades: {},
  perks: {},
});
assert(migrated.state.schema_version === 3, 'runtime must migrate to schema v3');
assert(migrated.state.facilityRank === 2, 'v2 Warehouse must stay Rank 2');
assert(migrated.state.workers.length === 5, 'Rank 2 grants five-person base crew');
let crew = migrated.staffingSummary();
assert(crew.store === 2 && crew.pick === 2 && crew.ship === 1, 'balanced five-person crew must be 2/2/1');
assert(migrated.setStaffingPlan('shipping').ok, 'Rank 2 can choose a staffing plan');
crew = migrated.staffingSummary();
assert(crew.store === 1 && crew.pick === 2 && crew.ship === 2, 'shipping plan must move crew downstream');
assert(!migrated.setStaffingPlan('receiving').ok, 'crew reassignment must have a cooldown');

migrated.state.staffingCooldown = 0;
assert(migrated.purchaseFacility('bufferYard').ok, 'buffer yard must be buildable');
assert(migrated.inboundMax() === 24, 'buffer yard must raise inbound capacity to 24');
assert(!migrated.purchaseFacility('secondInbound').ok, 'intake zone must be mutually exclusive');
assert(migrated.purchaseFacility('fastPickRack').ok, 'fast rack must be buildable');
assert(!migrated.purchaseFacility('highDensityRack').ok, 'storage zone must be mutually exclusive');
const basePackTime = createSimulation({ ...migrated.serialize(), facilities: { ...migrated.state.facilities, fastPickRack: true, bufferYard: true, secondPack: false, fastPackCell: false } }).packTime();
assert(migrated.purchaseFacility('fastPackCell').ok, 'fast pack cell must be buildable');
assert(migrated.packCapacity() === 1, 'fast cell stays single-lane');
assert(migrated.packTime() < basePackTime, 'fast cell must materially reduce packing time');
assert(!migrated.purchaseFacility('secondPack').ok, 'packing zone must be mutually exclusive');

const roundTrip = createSimulation(migrated.serialize());
assert(roundTrip.state.schema_version === 3, 'serialized save must remain schema v3');
assert(roundTrip.state.staffingPlan === 'shipping', 'staffing plan must persist');
assert(roundTrip.state.facilities.bufferYard, 'new facility choice must persist');
assert(roundTrip.state.facilities.fastPackCell, 'packing choice must persist');
assert(roundTrip.staffingSummary().total >= 5, 'Rank 2 crew must survive save/load');

console.log('Rank 2 Systems Pass smoke OK');
''')

# ---------------- GDD ----------------
p = Path('GDD_LOGISTICS_BOSS.md')
g = p.read_text()
if '## Rank 2 Systems Pass Phase 1 LOCK' not in g:
    g += '''\n\n## Rank 2 Systems Pass Phase 1 LOCK\n\nRank 2 is no longer a numeric upgrade layer. It is the first structural logistics-design layer. Repeated task-priority +/- controls and repeatable equipment-level buttons are removed from the management UI. Legacy save effects remain compatible but are not the product-facing progression model.\n\nRank 2 rules:\n- Rank-up grants a five-person base crew. Workers receive structural roles: receiving/store, pick, or ship.\n- The player chooses one staffing plan (Receiving / Balanced / Shipping). Reassignment has a 30 simulated-second lock so it is a strategic intervention, not a twitch button.\n- Rank 1 policy buttons remain an FTUE tool; Rank 2 task dispatch is driven by crew roles and the policy weighting becomes neutral.\n- Three fixed expansion zones are available. Each zone is one-of-two and cannot be filled with both choices.\n  - Zone A Intake: Double Dock (more arrival throughput, higher downstream pressure) vs Buffer Yard (more surge capacity, no arrival-rate gain).\n  - Zone B Storage: Fast Pick Rack (less capacity, faster picks) vs High Density Rack (more capacity, slower picks).\n  - Zone C Packing: Parallel Pack Line (two concurrent packs, slower each) vs Fast Pack Cell (one concurrent pack, much faster each).\n- All six choices must change simulation behavior; new choices must also be visible in the 3D warehouse.\n- Director remains prescriptive during Rank 1 FTUE, but at Rank 2 it becomes diagnostic: it exposes which stage is imbalanced and does not provide a one-tap fix.\n- Rank 2 progress is shown as Expansion Zones 0/3 through 3/3, never as a misleading MAX label.\n- Research unlocks in this phase are one-time decisions rather than repeatable levels.\n\nSuccess: after entering Warehouse, the player should spend more time observing the consequences of crew/zone decisions than pressing upgrade buttons.\n'''
    p.write_text(g)

print('Rank 2 systems patch applied')
