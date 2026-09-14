import {
  CAPITAL_INVESTMENTS,
  commercialTierForAssets,
  currentUnitRevenue,
  formatInvestmentEffect,
  investedCapital,
  investmentLevel,
  investmentUnlocked,
  nextCommercialTierForAssets,
  nextInvestmentCost,
  totalAssetValue,
} from './capital-model.js';

const yen = (value) => `¥${Math.round(value || 0).toLocaleString('ja-JP')}`;
const round1 = (value) => Math.round((Number(value) || 0) * 10) / 10;

function ensureStyles() {
  if (document.querySelector('link[data-capital-expansion]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = './capital.css';
  link.dataset.capitalExpansion = '1';
  document.head.appendChild(link);
}

export function bindCapitalExpansion(sim) {
  ensureStyles();

  const dock = document.getElementById('dockExpanded');
  if (!dock) return { update() {}, snapshot() { return null; } };

  const panel = document.createElement('section');
  panel.id = 'capitalPanel';
  panel.className = 'capitalPanel';
  panel.innerHTML = `
    <div class="capitalHead">
      <div><small>CAPITAL EXPANSION</small><strong>事業投資</strong></div>
      <span id="capitalTier" class="capitalTier">Local Depot</span>
    </div>
    <div class="capitalStats">
      <div class="capitalStat"><span>現金</span><b id="capitalCash">¥0</b></div>
      <div class="capitalStat"><span>投資総額</span><b id="capitalInvested">¥0</b></div>
      <div class="capitalStat"><span>総資産</span><b id="capitalAssets">¥0</b></div>
      <div class="capitalStat"><span>出荷売上/分</span><b id="capitalRevenue">¥0</b></div>
    </div>
    <div id="capitalGrid" class="capitalGrid"></div>
    <div id="capitalReport" class="capitalReport" hidden></div>
    <div id="capitalHint" class="capitalHint"></div>`;

  dock.prepend(panel);

  const nodes = {
    tier: panel.querySelector('#capitalTier'),
    cash: panel.querySelector('#capitalCash'),
    invested: panel.querySelector('#capitalInvested'),
    assets: panel.querySelector('#capitalAssets'),
    revenue: panel.querySelector('#capitalRevenue'),
    grid: panel.querySelector('#capitalGrid'),
    report: panel.querySelector('#capitalReport'),
    hint: panel.querySelector('#capitalHint'),
  };

  const buttons = new Map();
  for (const [key] of Object.entries(CAPITAL_INVESTMENTS)) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'capitalBuy';
    button.dataset.capitalKey = key;
    nodes.grid.appendChild(button);
    buttons.set(key, button);
  }

  let gameClock = 0;
  let renderTimer = 0;
  const shipmentHistory = [];
  let pendingReport = null;
  let latestReport = null;

  function pruneRevenue() {
    while (shipmentHistory.length && gameClock - shipmentHistory[0].at > 120) shipmentHistory.shift();
  }

  function flowBetween(startAt, endAt, minimumWindow = 1) {
    pruneRevenue();
    const start = Math.max(0, Number(startAt) || 0);
    const end = Math.max(start, Number(endAt) || 0);
    const elapsed = Math.max(minimumWindow, end - start);
    const rows = shipmentHistory.filter((row) => row.at >= start && row.at <= end);
    const total = rows.reduce((sum, row) => sum + row.value, 0);
    return {
      seconds: elapsed,
      count: rows.length,
      throughput: round1(rows.length * 60 / elapsed),
      revenue: Math.round(total * 60 / elapsed),
    };
  }

  function recentFlow(seconds = 60) {
    const span = Math.max(1, Number(seconds) || 60);
    const start = Math.max(0, gameClock - span);
    return flowBetween(start, gameClock, Math.min(10, span));
  }

  function revenuePerMinute() {
    return recentFlow(60).revenue;
  }

  function metricSnapshot(flow = null) {
    const c = sim.counts();
    const capacity = Math.max(1, sim.rackCapacity());
    const measuredFlow = flow || recentFlow(60);
    return {
      throughput: measuredFlow.throughput,
      revenue: measuredFlow.revenue,
      flowSeconds: measuredFlow.seconds,
      orders: sim.state.ordersOpen || 0,
      inbound: c.inbound || 0,
      rackRatio: c.rack / capacity,
    };
  }

  function signed(value, suffix = '') {
    const rounded = Math.round(value);
    return `${rounded > 0 ? '+' : ''}${rounded}${suffix}`;
  }

  function reportHtml(report) {
    if (!report.ready) {
      return `<strong>${report.label} · 効果測定中</strong><p>直前の運転状態と、導入後25秒を同じ基準で比較する。追加投資すると測定は新しい投資からやり直す。</p><div class="capitalReportGrid"><span>観測 ${Math.min(25, Math.floor(report.elapsed))}/25秒</span><span>投資 ${yen(report.cost)}</span></div>`;
    }
    const d = report.delta;
    const roi = d.revenue > 0 ? `${(report.cost / d.revenue).toFixed(1)}分` : '測定不能';
    return `<strong>${report.label} · INVESTMENT RESULT</strong><p>導入前の直近運転と導入後25秒を比較。投資によって詰まりが別工程へ移った場合も、その悪化を隠さず表示する。</p><div class="capitalReportGrid"><span>出荷 ${signed(d.throughput, '/分')}</span><span>売上 ${signed(d.revenue, '円/分')}</span><span>注文待ち ${signed(d.orders, '件')}</span><span>入荷待ち ${signed(d.inbound, '箱')}</span><span>棚使用 ${signed(d.rackPoints, 'pt')}</span><span>回収目安 ${roi}</span></div>`;
  }

  function buyInvestment(key) {
    const def = CAPITAL_INVESTMENTS[key];
    if (!def || !investmentUnlocked(sim.state.upgrades, key)) return;
    const level = investmentLevel(sim.state.upgrades, key);
    if (level >= def.costs.length) return;
    const cost = nextInvestmentCost(sim.state.upgrades, key);
    if (sim.state.money < cost) return;

    const beforeFlow = recentFlow(25);
    const before = metricSnapshot(beforeFlow);
    const result = sim.purchaseCapitalUpgrade(def.upgrade, cost);
    if (!result.ok) return;
    pendingReport = {
      key,
      label: `${def.label} Lv.${result.level}`,
      cost: result.cost,
      elapsed: 0,
      startAt: gameClock,
      before,
      ready: false,
    };
    latestReport = null;
    try { navigator.vibrate?.([18, 22, 28]); } catch {}
    render();
  }

  for (const [key, button] of buttons) button.addEventListener('click', () => buyInvestment(key));

  sim.onEvent((event) => {
    if (event.type !== 'shipment') return;
    const value = Math.max(0, Number(event.value) || currentUnitRevenue(sim.state.upgrades));
    shipmentHistory.push({ at: gameClock, value });
    pruneRevenue();
  });

  function updateReport(dt) {
    if (!pendingReport) return;
    pendingReport.elapsed += dt;
    if (pendingReport.elapsed < 25) return;
    const afterFlow = flowBetween(pendingReport.startAt, pendingReport.startAt + 25, 25);
    const after = metricSnapshot(afterFlow);
    const before = pendingReport.before;
    latestReport = {
      ...pendingReport,
      elapsed: 25,
      ready: true,
      after,
      delta: {
        throughput: round1(after.throughput - before.throughput),
        revenue: after.revenue - before.revenue,
        orders: after.orders - before.orders,
        inbound: after.inbound - before.inbound,
        rackPoints: (after.rackRatio - before.rackRatio) * 100,
      },
    };
    pendingReport = null;
  }

  function render() {
    const invested = investedCapital(sim.state.upgrades);
    const assets = totalAssetValue(sim.state.money, sim.state.upgrades);
    const tier = commercialTierForAssets(invested);
    nodes.cash.textContent = yen(sim.state.money);
    nodes.invested.textContent = yen(invested);
    nodes.assets.textContent = yen(assets);
    nodes.revenue.textContent = `${yen(revenuePerMinute())}/分`;
    nodes.tier.textContent = `${tier.label} · 1箱 ${yen(tier.saleValue)}`;

    for (const [key, button] of buttons) {
      const def = CAPITAL_INVESTMENTS[key];
      const level = investmentLevel(sim.state.upgrades, key);
      const maxed = level >= def.costs.length;
      const unlocked = investmentUnlocked(sim.state.upgrades, key);
      const cost = nextInvestmentCost(sim.state.upgrades, key);
      const ready = unlocked && !maxed && sim.state.money >= cost;
      button.dataset.ready = ready ? 'true' : 'false';
      button.dataset.max = maxed ? 'true' : 'false';
      button.dataset.locked = unlocked ? 'false' : 'true';
      button.disabled = maxed || !ready;
      if (!unlocked) {
        button.innerHTML = `<span class="capitalLevel">CAPITAL</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>投資総額 ${yen(def.unlockAssets)} で解禁</em><b>LOCKED</b>`;
      } else {
        const currentEffect = level > 0 ? formatInvestmentEffect(key, level) : '未導入';
        const nextEffect = maxed ? null : formatInvestmentEffect(key, level + 1);
        const effectLine = maxed ? `現在 ${currentEffect} / 最大段階` : `現在 ${currentEffect} → 次 ${nextEffect}`;
        button.innerHTML = `<span class="capitalLevel">Lv.${level}/${def.costs.length}</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>${effectLine}</em><b>${maxed ? 'MAX' : yen(cost)}</b>`;
      }
      button.title = def.effect;
    }

    const report = pendingReport || latestReport;
    nodes.report.hidden = !report;
    if (report) nodes.report.innerHTML = reportHtml(report);

    const nextTier = nextCommercialTierForAssets(invested);
    nodes.hint.textContent = nextTier == null
      ? '最大商圏。次の拡張は複数拠点・大型物流網へ。'
      : `投資総額 ${yen(nextTier.minAssets)} で ${nextTier.label} 商圏へ。何を先に買うかは自由。`;
  }

  function update(realDt) {
    const gameDt = Math.max(0, realDt) * Math.max(0, sim.state.timeScale || 0);
    gameClock += gameDt;
    updateReport(gameDt);
    renderTimer += realDt;
    if (renderTimer >= 0.25) {
      renderTimer = 0;
      render();
    }
  }

  function snapshot() {
    return {
      invested: investedCapital(sim.state.upgrades),
      assets: totalAssetValue(sim.state.money, sim.state.upgrades),
      revenuePerMinute: revenuePerMinute(),
      unitRevenue: currentUnitRevenue(sim.state.upgrades),
      report: pendingReport || latestReport,
    };
  }

  window.__logisticsBossCapital = { snapshot };
  render();
  return { update, snapshot };
}
