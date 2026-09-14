from pathlib import Path


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)


path = Path('docs/index.html')
h = path.read_text()
h = replace_once(h, '  <link rel="stylesheet" href="./readability.css" />', '  <link rel="stylesheet" href="./readability.css" />\n  <link rel="stylesheet" href="./ux.css" />', 'ux css link')
for old, new in [
    ('<div class="metric research"><span>研究</span>', '<div class="metric research"><span>研究RP</span>'),
    ('<div class="metric"><span>出荷</span><strong id="shipped">', '<div class="metric"><span>累計出荷</span><strong id="shipped">'),
    ('<div class="metric"><span>注文</span><strong id="orders">', '<div class="metric"><span>注文待ち</span><strong id="orders">'),
    ('<div class="metric"><span>搬入口</span><strong id="inbound">', '<div class="metric"><span>入荷待ち</span><strong id="inbound">'),
    ('<div class="metric"><span>棚</span><strong id="rack">', '<div class="metric"><span>棚使用</span><strong id="rack">'),
    ('<div class="metric"><span>処理速度</span><strong id="throughput">', '<div class="metric"><span>出荷ペース</span><strong id="throughput">'),
    ('aria-label="分析パネルを縮小" aria-expanded="true">−</button>', 'aria-label="案内を開く" aria-expanded="false">開く</button>'),
]:
    h = h.replace(old, new)
h = replace_once(h, '      <div id="directorRecommendation">—</div>\n      <div class="contractArea">', '      <div id="directorRecommendation">—</div>\n      <div id="directorActionRow">\n        <span id="ftueStep" hidden></span>\n        <button id="directorAction" type="button" hidden></button>\n      </div>\n      <div class="contractArea">', 'director action markup')
for old, new in [
    ('<button class="facilityChoice" type="button" data-facility="secondInbound"><strong>第2搬入口</strong><span>受入容量を拡張</span>', '<button class="facilityChoice" type="button" data-facility="secondInbound"><strong>第2搬入口</strong><span>入荷待ち上限 +6 / 入荷22%増</span>'),
    ('<button class="facilityChoice" type="button" data-facility="fastPickRack"><strong>高速ピックラック</strong><span>高速回転型</span>', '<button class="facilityChoice" type="button" data-facility="fastPickRack"><strong>高速ピックラック</strong><span>保管+4 / ピック25%速</span>'),
    ('<button class="facilityChoice" type="button" data-facility="highDensityRack"><strong>高密度ラック</strong><span>大量保管型</span>', '<button class="facilityChoice" type="button" data-facility="highDensityRack"><strong>高密度ラック</strong><span>保管+12 / ピック14%遅</span>'),
    ('<button class="facilityChoice" type="button" data-facility="secondPack"><strong>第2梱包ライン</strong><span>同時梱包を2箱へ</span>', '<button class="facilityChoice" type="button" data-facility="secondPack"><strong>第2梱包ライン</strong><span>同時梱包 1→2箱</span>'),
    ('<button class="upgrade" type="button" data-upgrade="worker"><span class="upgradeName">スタッフ追加</span>', '<button class="upgrade" type="button" data-upgrade="worker"><span class="upgradeName">スタッフ追加</span><small class="upgradeEffect">同時作業員 +1</small>'),
    ('<button class="upgrade" type="button" data-upgrade="speed"><span class="upgradeName">歩行速度</span>', '<button class="upgrade" type="button" data-upgrade="speed"><span class="upgradeName">歩行速度</span><small class="upgradeEffect">全員の移動 +16%</small>'),
    ('<button class="upgrade" type="button" data-upgrade="rack"><span class="upgradeName">棚拡張</span>', '<button class="upgrade" type="button" data-upgrade="rack"><span class="upgradeName">棚拡張</span><small class="upgradeEffect">保管枠 +4箱</small>'),
    ('<button class="upgrade" type="button" data-upgrade="pack"><span class="upgradeName">梱包設備</span>', '<button class="upgrade" type="button" data-upgrade="pack"><span class="upgradeName">梱包設備</span><small class="upgradeEffect">梱包時間 -18%</small>'),
    ('<button class="upgrade" type="button" data-upgrade="conveyor"><span class="upgradeName">自動搬送</span>', '<button class="upgrade" type="button" data-upgrade="conveyor"><span class="upgradeName">自動搬送</span><small class="upgradeEffect">入荷→棚を自動化</small>'),
    ('<button class="upgrade perk" type="button" data-perk="smartDispatch"><span class="upgradeName">スマート配車</span>', '<button class="upgrade perk" type="button" data-perk="smartDispatch"><span class="upgradeName">スマート配車</span><small class="upgradeEffect">混雑に合わせ自動配分</small>'),
    ('<button class="upgrade perk" type="button" data-perk="bulkPack"><span class="upgradeName">標準化梱包</span>', '<button class="upgrade perk" type="button" data-perk="bulkPack"><span class="upgradeName">標準化梱包</span><small class="upgradeEffect">梱包時間 -15%</small>'),
    ('<button class="upgrade perk" type="button" data-perk="contractBonus"><span class="upgradeName">高単価契約</span>', '<button class="upgrade perk" type="button" data-perk="contractBonus"><span class="upgradeName">高単価契約</span><small class="upgradeEffect">契約報酬 +25%</small>'),
]:
    h = h.replace(old, new)
path.write_text(h)

css = '''/* Rank 1 UX / FTUE Pass 1 */
#insightToggle{width:auto;min-width:44px;padding:0 9px;font-size:10px}
#directorActionRow{display:flex;align-items:center;justify-content:space-between;gap:7px;margin-top:6px}
#directorActionRow:has(#directorAction[hidden]):has(#ftueStep[hidden]){display:none}
#ftueStep{flex:0 0 auto;padding:3px 6px;border-radius:999px;border:1px solid rgba(101,211,255,.28);background:rgba(68,157,201,.12);color:#aeeaff;font-size:8px;font-weight:900;letter-spacing:.06em}
#directorAction{appearance:none;-webkit-appearance:none;margin-left:auto;min-height:30px;padding:0 10px;border-radius:9px;border:1px solid rgba(101,211,255,.46);background:rgba(65,164,211,.18);color:#d7f5ff;font-size:10px;font-weight:900}
#directorAction:active{transform:scale(.98)}
#insightPanel.compact{width:min(270px,calc(100vw - 16px))}
#insightPanel.compact #directorActionRow{margin-top:5px}
#commandDock:not(.compact){max-height:min(52dvh,470px)}
.upgradeEffect{display:block;margin:-1px 0 5px;color:#8fa0ac;font-size:8px;line-height:1.15;white-space:normal}
.upgrade{min-height:66px}.facilityChoice{min-height:70px}
#celebration{top:30%;width:min(72vw,340px);padding:12px 16px;border-radius:17px}
#celebration strong{font-size:18px}#celebration span{font-size:12px}
@media (max-width:500px){.metric span{font-size:8px}.metric strong{font-size:13px}}
'''
Path('docs/ux.css').write_text(css)

path = Path('docs/src/ui.js')
u = path.read_text()
u = replace_once(u, "    directorRecommendation: document.getElementById('directorRecommendation'),\n    severityBadge: document.getElementById('severityBadge'),", "    directorRecommendation: document.getElementById('directorRecommendation'),\n    directorAction: document.getElementById('directorAction'),\n    ftueStep: document.getElementById('ftueStep'),\n    severityBadge: document.getElementById('severityBadge'),", 'director action refs')
old = "  function setInsightCompact(compact) {\n    insightCompact = Boolean(compact);\n    el.insightPanel.classList.toggle('compact', insightCompact);\n    el.insightToggle.textContent = insightCompact ? '＋' : '−';\n    el.insightToggle.setAttribute('aria-expanded', String(!insightCompact));\n    el.insightToggle.setAttribute('aria-label', insightCompact ? '分析パネルを展開' : '分析パネルを縮小');\n  }"
new = "  function updateInsightToggle() {\n    const hasOffers = !sim.state.activeContract && (sim.state.contractOffers || []).length > 0;\n    el.insightToggle.textContent = insightCompact ? (hasOffers ? '契約' : '開く') : '閉じる';\n    el.insightToggle.setAttribute('aria-expanded', String(!insightCompact));\n    el.insightToggle.setAttribute('aria-label', insightCompact ? (hasOffers ? '契約を選ぶ' : '案内を開く') : '案内を閉じる');\n  }\n\n  function setInsightCompact(compact) {\n    insightCompact = Boolean(compact);\n    el.insightPanel.classList.toggle('compact', insightCompact);\n    updateInsightToggle();\n  }"
u = replace_once(u, old, new, 'insight toggle language')
u = replace_once(u, "        try { navigator.vibrate?.(18); } catch {}\n        setDockCompact(true);", "        try { navigator.vibrate?.(18); } catch {}", 'sticky upgrade panel')
u = replace_once(u, "      try { navigator.vibrate?.([18, 25, 24]); } catch {}\n      setDockCompact(true);", "      try { navigator.vibrate?.([18, 25, 24]); } catch {}", 'sticky facility panel')
u = replace_once(u, "        try { navigator.vibrate?.(18); } catch {}\n        setDockCompact(true);", "        try { navigator.vibrate?.(18); } catch {}", 'sticky research panel')
u = replace_once(u, "  el.insightToggle.addEventListener('click', () => { setInsightCompact(!insightCompact); render(); });", "  el.insightToggle.addEventListener('click', () => { setInsightCompact(!insightCompact); render(); });\n  el.directorAction.addEventListener('click', () => {\n    const action = el.directorAction.dataset.action || '';\n    if (action === 'contract') setInsightCompact(false);\n    else if (action === 'management') setDockCompact(false);\n    else if (action.startsWith('policy:')) { sim.setPolicy(action.slice(7)); try { navigator.vibrate?.(10); } catch {} }\n    render();\n  });", 'director action handler')
u = u.replace("      celebrate('MILESTONE', event.text);\n", '')
u = u.replace("el.contractBody.innerHTML = offers.length ? '<div class=\"contractDesc\">＋を押して契約を選択</div>' : '';", "el.contractBody.innerHTML = offers.length ? '<div class=\"contractDesc\">契約を1つ選ぶ</div>' : '';")
u = u.replace("el.contractTitle.textContent = offers.length ? `契約 ${offers.length}件` : '次の契約を準備中';", "el.contractTitle.textContent = offers.length ? `契約を選ぶ（${offers.length}件）` : '次の契約を準備中';")
u = u.replace("    el.rack.textContent = `${c.rack} / ${sim.rackCapacity()}`;", "    el.rack.textContent = `${c.rack}/${sim.rackCapacity()}箱`;")
old = "    const offerCount = (s.contractOffers || []).length;\n    const stableSummary = s.activeContract ? `安定稼働 · ${s.activeContract.title}` : `安定稼働 · 契約${offerCount}件`;\n    el.directorLabel.textContent = d.severity === 0 && insightCompact ? stableSummary : d.label;\n    el.directorDetail.textContent = d.detail;\n    el.directorRecommendation.textContent = `→ ${d.recommendation}`;\n    el.severityBadge.textContent = d.severity === 0 ? 'OK' : d.severity === 1 ? '注意' : d.severity === 2 ? '混雑' : '危険';\n    el.severityBadge.dataset.level = String(d.severity);"
new = "    const offerCount = (s.contractOffers || []).length;\n    const capacity = sim.rackCapacity();\n    const inboundCap = sim.inboundMax();\n    const human = {\n      inbound: { label: '搬入口に荷物がたまっている', detail: `未処理 ${c.inbound}箱 / 上限${inboundCap}箱`, recommendation: '入荷を棚へ流すため、入庫を優先', action: 'policy:inbound', actionLabel: '入庫優先にする' },\n      rack: { label: '棚がほぼ満杯', detail: `棚を ${c.rack}/${capacity}箱 使用 · 空き${Math.max(0, capacity - c.rack)}箱`, recommendation: '棚を空けるため、出庫を優先', action: 'policy:ship', actionLabel: '出庫優先にする' },\n      orders: { label: '注文がたまっている', detail: `未処理注文 ${s.ordersOpen}件`, recommendation: '注文を減らすため、出庫を優先', action: 'policy:ship', actionLabel: '出庫優先にする' },\n      packed: { label: '出荷待ちがたまっている', detail: `出荷待ち ${c.packed}箱`, recommendation: '梱包済み荷物を先に出す', action: 'policy:ship', actionLabel: '出庫優先にする' },\n    };\n    let label = d.label;\n    let detail = d.detail;\n    let recommendation = d.recommendation;\n    let action = '';\n    let actionLabel = '';\n    if (d.severity > 0 && human[d.key]) ({ label, detail, recommendation, action, actionLabel } = human[d.key]);\n    else if (s.facilityRank < 2) {\n      const remainingRating = Math.max(0, (nextTarget || 8) - s.logisticsRating);\n      const approxContracts = Math.ceil(remainingRating / 2);\n      if (!s.activeContract && offerCount > 0) {\n        label = 'まず契約を選ぼう'; detail = '契約達成で「物流評価」が +2'; recommendation = `物流評価${nextTarget || 8}で Warehouse 解禁`; action = 'contract'; actionLabel = '契約を選ぶ';\n      } else if (s.activeContract) {\n        label = `契約: ${s.activeContract.title}`; detail = `進行 ${contractProgressText(s.activeContract)} · 評価${s.logisticsRating}/${nextTarget || 8}`; recommendation = '詰まりが出たら、ここに出る推奨方針へ切り替える'; action = `policy:${s.activeContract.kind === 'inbound' ? 'inbound' : s.activeContract.kind === 'ship' ? 'ship' : 'balanced'}`; actionLabel = s.activeContract.kind === 'inbound' ? '入庫優先にする' : s.activeContract.kind === 'ship' ? '出庫優先にする' : 'バランスにする';\n      } else { label = '次の契約を待っています'; detail = `物流評価 ${s.logisticsRating}/${nextTarget || 8}`; recommendation = `Warehouseまであと約${approxContracts}契約`; }\n    } else if (d.severity === 0) { label = '次は物流設備を選ぶ'; detail = 'Warehouse解禁済み'; recommendation = '管理から、第2搬入口・ラック方針・第2梱包ラインへ投資'; action = 'management'; actionLabel = '設備を見る'; }\n    let step = '';\n    if (s.facilityRank < 2) step = s.completedContracts === 0 && !s.activeContract ? 'STEP 1/3' : s.completedContracts === 0 ? 'STEP 2/3' : 'STEP 3/3';\n    el.ftueStep.hidden = !step;\n    el.ftueStep.textContent = step;\n    el.directorAction.hidden = !actionLabel;\n    el.directorAction.textContent = actionLabel;\n    el.directorAction.dataset.action = action;\n    el.directorLabel.textContent = label;\n    el.directorDetail.textContent = detail;\n    el.directorRecommendation.textContent = `次に: ${recommendation}`;\n    el.severityBadge.textContent = d.severity === 0 ? '安定' : d.severity === 1 ? '注意' : d.severity === 2 ? '混雑' : '詰まり';\n    el.severityBadge.dataset.level = String(d.severity);"
u = replace_once(u, old, new, 'plain-language actionable director')
u = replace_once(u, "    renderContracts();\n  }", "    renderContracts();\n    updateInsightToggle();\n  }", 'refresh insight toggle')
path.write_text(u)

path = Path('GDD_LOGISTICS_BOSS.md')
gdd = path.read_text()
if '## Rank 1 UX / FTUE Pass 1 LOCK' not in gdd:
    gdd += '\n\n## Rank 1 UX / FTUE Pass 1 LOCK\n\nRank 1 must teach the game before adding more progression. The always-visible Director is the primary action translator: show the problem in plain Japanese, show a concrete current count, explain why it matters, and offer one contextual action button. Rank 1 FTUE communicates three steps: choose a contract, react to the Director, then repeat contracts until Logistics Rating 8 unlocks Warehouse.\n\nUX rules:\n- Use player-language labels such as 棚使用, 注文待ち, 入荷待ち, and 出荷ペース instead of abstract capacity terminology where possible.\n- Management stays open after buying an upgrade, facility, or research item; only the player closes it.\n- Milestones use non-blocking toast feedback. Large center-screen celebration is reserved for contract completion and Facility Rank up.\n- Contract selection must be labeled explicitly; do not use an unlabeled plus icon as the primary affordance.\n- Upgrade cards must state their practical effect, not only their name and level.\n'
    path.write_text(gdd)
