import {
  CAPITAL_INVESTMENTS,
  commercialTierForAssets,
  currentUnitRevenue,
  formatInvestmentEffect,
  investedCapital,
  investmentLevel,
  nextInvestmentCost,
  totalAssetValue,
} from './capital-model.js';

const yen = (value) => `¥${Math.round(value || 0).toLocaleString('ja-JP')}`;

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
      <div><small>CAPITAL EXPANSION</small><strong>設備投資</strong></div>
      <span id="capitalTier" class="capitalTier">Local Depot</span>
    </div>
    <div class="capitalStats">
      <div class="capitalStat"><span>現金</span><b id="capitalCash">¥0</b></div>
      <div class="capitalStat"><span>設備資産</span><b id="capitalInvested">¥0</b></div>
      <div class="capitalStat"><span>総資産</span><b id="capitalAssets">¥0</b></div>
      <div class="capitalStat"><span>出荷売上/分</span><b id="capitalRevenue">¥0</b></div>
    </div>
    <div id="capitalGrid" class="capitalGrid"></div>
    <div id="capitalReport" class="capitalReport" hidden></div>
    <div id="capitalHint" class="capitalHint"></div>`;

  const firstSectionLabel = [...dock.querySelectorAll('.sectionLabel')][0];
  if (firstSectionLabel) firstSectionLabel.before(panel);
  else dock.prepend(panel);

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
  for (const [key, def] of Object.entries(CAPITAL_INVESTMENTS)) {
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
    while (shipmentHistory.length && gameClock - shipmentHistory[0].at > 60) shipmentHistory.shift();
  }

  function revenuePerMinute() {
    pruneRevenue();
    if (!shipmentHistory.length) return 0;
    const windowSeconds = Math.max(10, Math.min(60, gameClock - shipmentHistory[0].at + 1));
    const total = shipmentHistory.reduce((sum, row) => sum + row.value, 0);
    return Math.round(total * (60 / windowSeconds));
  }

  function metricSnapshot() {
    const c = sim.counts();
    const capacity = Math.max(1, sim.rackCapacity());
    return {
      throughput: sim.state.metrics?.perMinute || 0,
      revenue: revenuePerMinute(),
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
      return `<strong>${report.label} · 効果測定中</strong><p>設備導入前後を25秒観測。出荷量だけでなく、売上・滞留・棚使用率まで比較する。</p><div class="capitalReportGrid"><span>観測 ${Math.min(25, Math.floor(report.elapsed))}/25秒</span><span>投資 ${yen(report.cost)}</span></div>`;
    }
    const d = report.delta;
    const roi = d.revenue > 0 ? `${(report.cost / d.revenue).toFixed(1)}分` : '測定不能';
    return `<strong>${report.label} · INVESTMENT RESULT</strong><p>買った設備が本当に効いたかを実測。プラスだけでなく悪化もそのまま表示する。</p><div class="capitalReportGrid"><span>出荷 ${signed(d.throughput, '/分')}</span><span>売上 ${signed(d.revenue, '円/分')}</span><span>注文待ち ${signed(d.orders, '件')}</span><span>入荷待ち ${signed(d.inbound, '箱')}</span><span>棚使用 ${signed(d.rackPoints, 'pt')}</span><span>回収目安 ${roi}</span></div>`;
  }

  function buyInvestment(key) {
    const def = CAPITAL_INVESTMENTS[key];
    if (!def) return;
    const level = investmentLevel(sim.state.upgrades, key);
    if (level >= def.costs.length) return;
    const cost = nextInvestmentCost(sim.state.upgrades, key);
    if (sim.state.money < cost) return;

    const before = metricSnapshot();
    sim.state.money -= cost;
    sim.state.upgrades[def.upgrade] = level + 1;
    // Reuse the simulation's existing dirty/save path without changing the player's policy.
    sim.setPolicy(sim.state.policy);
    pendingReport = {
      key,
      label: `${def.label} Lv.${level + 1}`,
      cost,
      elapsed: 0,
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
    const unitRevenue = currentUnitRevenue(sim.state.upgrades);
    const baseValue = Number(event.value) || 120;
    const bonus = Math.max(0, unitRevenue - baseValue);
    if (bonus > 0) sim.state.money += bonus;
    event.value = unitRevenue;
    event.text = `出荷 +${yen(unitRevenue)}`;
    shipmentHistory.push({ at: gameClock, value: unitRevenue });
    pruneRevenue();
  });

  function updateReport(dt) {
    if (!pendingReport) return;
    pendingReport.elapsed += dt;
    if (pendingReport.elapsed < 25) return;
    const after = metricSnapshot();
    const before = pendingReport.before;
    latestReport = {
      ...pendingReport,
      ready: true,
      after,
      delta: {
        throughput: after.throughput - before.throughput,
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
      const cost = nextInvestmentCost(sim.state.upgrades, key);
      const ready = !maxed && sim.state.money >= cost;
      button.dataset.ready = ready ? 'true' : 'false';
      button.dataset.max = maxed ? 'true' : 'false';
      button.disabled = maxed || !ready;
      button.innerHTML = `<span class="capitalLevel">Lv.${level}/${def.costs.length}</span><strong>${def.label}</strong><span>${def.emphasis}</span><em>${maxed ? '最大設備' : formatInvestmentEffect(key, level + 1)}</em><b>${maxed ? 'MAX' : yen(cost)}</b>`;
      button.title = def.effect;
    }

    const report = pendingReport || latestReport;
    nodes.report.hidden = !report;
    if (report) nodes.report.innerHTML = reportHtml(report);

    const nextTier = (() => {
      const index = Math.max(0, [
        'Local Depot', 'Mechanized Depot', 'High-Throughput Warehouse', 'Regional Fulfillment', 'Automated DC', 'Mega Logistics',
      ].indexOf(tier.label));
      const tiers = [8000, 40000, 200000, 1000000, 5000000];
      return tiers[index] ?? null;
    })();
    nodes.hint.textContent = nextTier == null
      ? '最大商圏。次の拡張は複数拠点・大型物流網へ。'
      : `設備資産 ${yen(nextTier)} で取扱単価が上昇。何を先に買うかは自由。`;
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
