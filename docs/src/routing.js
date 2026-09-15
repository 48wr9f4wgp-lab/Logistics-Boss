import { ROUTING_MODES, routingPackage } from './routing-model.js';

const yen = (value) => `¥${Math.round(Number(value) || 0).toLocaleString('ja-JP')}`;
const round1 = (value) => Math.round((Number(value) || 0) * 10) / 10;

function ensureStyles() {
  if (document.querySelector('link[data-carrier-routing]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = './routing.css';
  link.dataset.carrierRouting = '1';
  document.head.appendChild(link);
}

export function bindCarrierRouting(sim) {
  ensureStyles();

  const dock = document.getElementById('dockExpanded');
  if (!dock) return { update() {}, render() {}, snapshot() { return null; } };

  const panel = document.createElement('section');
  panel.id = 'carrierRoutingPanel';
  panel.className = 'carrierRoutingPanel';
  panel.hidden = true;
  panel.innerHTML = `
    <div class="routingHead">
      <div><small>FULFILLMENT ROUTING</small><strong>Carrier Routing</strong></div>
      <span id="routingBadge" class="routingBadge">BALANCED</span>
    </div>
    <div id="routingCurrent" class="routingCurrent">Balanced Parcel</div>
    <div id="routingChoices" class="routingChoices" aria-label="配送ルート"></div>
    <div id="routingReport" class="routingReport" hidden></div>
    <small class="routingHint">出荷速度と1箱あたりの収益が変わる。結果を見て運用方針を切り替える。</small>`;

  const nextStage = document.getElementById('nextStagePanel');
  if (nextStage) nextStage.insertAdjacentElement('afterend', panel);
  else dock.appendChild(panel);

  const nodes = {
    badge: panel.querySelector('#routingBadge'),
    current: panel.querySelector('#routingCurrent'),
    choices: panel.querySelector('#routingChoices'),
    report: panel.querySelector('#routingReport'),
  };

  const buttons = new Map();
  for (const mode of ROUTING_MODES) {
    const def = routingPackage(mode);
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'routingChoice';
    button.dataset.routingMode = mode;
    button.innerHTML = `<strong>${def.label}</strong><span>${def.summary}</span>`;
    nodes.choices.appendChild(button);
    buttons.set(mode, button);
  }

  let gameClock = 0;
  let renderTimer = 0;
  const shipmentHistory = [];
  let pendingReport = null;
  let latestReport = null;

  function pruneHistory() {
    while (shipmentHistory.length && gameClock - shipmentHistory[0].at > 120) shipmentHistory.shift();
  }

  function flowBetween(startAt, endAt, minimumWindow = 1) {
    pruneHistory();
    const start = Math.max(0, Number(startAt) || 0);
    const end = Math.max(start, Number(endAt) || 0);
    const elapsed = Math.max(minimumWindow, end - start);
    const rows = shipmentHistory.filter((row) => row.at >= start && row.at <= end);
    const revenue = rows.reduce((sum, row) => sum + row.value, 0);
    return {
      seconds: elapsed,
      throughput: round1(rows.length * 60 / elapsed),
      revenuePerMinute: Math.round(revenue * 60 / elapsed),
    };
  }

  function recentFlow(seconds = 25) {
    const span = Math.max(1, Number(seconds) || 25);
    return flowBetween(Math.max(0, gameClock - span), gameClock, Math.min(10, span));
  }

  function metricSnapshot(flow = null) {
    const measured = flow || recentFlow(25);
    const counts = sim.counts();
    return {
      throughput: measured.throughput,
      packed: counts.packed || 0,
      orders: sim.state.ordersOpen || 0,
      revenuePerMinute: measured.revenuePerMinute,
    };
  }

  function signed(value, suffix = '') {
    const rounded = Math.round((Number(value) || 0) * 10) / 10;
    return `${rounded > 0 ? '+' : ''}${rounded}${suffix}`;
  }

  function reportHtml(report) {
    if (!report.ready) {
      return `<strong>${report.label} · 効果測定中</strong><p>切替前の直近運転と、切替後25秒を同じ基準で比較する。</p><div class="routingReportGrid"><span>観測 ${Math.min(25, Math.floor(report.elapsed))}/25秒</span><span>出荷待ち ${sim.counts().packed}箱</span></div>`;
    }
    const before = report.before;
    const after = report.after;
    const d = report.delta;
    return `<strong>${report.label} · ROUTING RESULT</strong><p>改善も悪化もそのまま表示する。どのルートを使うかは運用方針次第。</p><div class="routingCompare"><span>出荷 <b>${before.throughput}→${after.throughput}/分</b><em>${signed(d.throughput, '/分')}</em></span><span>売上 <b>${yen(before.revenuePerMinute)}→${yen(after.revenuePerMinute)}/分</b><em>${signed(d.revenuePerMinute, '円/分')}</em></span><span>出荷待ち <b>${before.packed}→${after.packed}箱</b><em>${signed(d.packed, '箱')}</em></span><span>注文待ち <b>${before.orders}→${after.orders}件</b><em>${signed(d.orders, '件')}</em></span></div>`;
  }

  function switchRoute(mode) {
    if (sim.state.facilityRank < 3 || sim.state.routingMode === mode) return;
    const before = metricSnapshot(recentFlow(25));
    const result = sim.setRoutingMode(mode);
    if (!result.ok) return;
    const def = routingPackage(mode);
    pendingReport = {
      mode,
      label: def.label,
      elapsed: 0,
      startAt: gameClock,
      before,
      ready: false,
    };
    latestReport = null;
    try { navigator.vibrate?.([14, 18, 20]); } catch {}
    render();
  }

  for (const [mode, button] of buttons) button.addEventListener('click', () => switchRoute(mode));

  sim.onEvent((event) => {
    if (event.type === 'shipment') {
      shipmentHistory.push({ at: Number(event.at) || gameClock, value: Math.max(0, Number(event.value) || 0) });
      pruneHistory();
    }
    if (event.type === 'route_change' || event.type === 'rank_up') render();
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
        packed: after.packed - before.packed,
        orders: after.orders - before.orders,
        revenuePerMinute: after.revenuePerMinute - before.revenuePerMinute,
      },
    };
    pendingReport = null;
  }

  function render() {
    const active = sim.state.facilityRank >= 3;
    panel.hidden = !active;
    if (!active) return;
    const mode = sim.state.routingMode || 'balanced';
    const def = routingPackage(mode);
    nodes.badge.textContent = def.shortLabel;
    nodes.badge.dataset.mode = mode;
    nodes.current.textContent = `${def.label} · ${def.summary} · 現在 ${sim.state.metrics.perMinute || 0}/分 · ${yen(sim.state.metrics.revenuePerMinute || 0)}/分`;
    for (const [key, button] of buttons) {
      const selected = key === mode;
      button.classList.toggle('active', selected);
      button.setAttribute('aria-pressed', String(selected));
      button.disabled = selected;
    }
    const report = pendingReport || latestReport;
    nodes.report.hidden = !report;
    if (report) nodes.report.innerHTML = reportHtml(report);
  }

  function update(realDt) {
    const gameDt = Math.max(0, Number(realDt) || 0) * Math.max(0, sim.state.timeScale || 0);
    gameClock += gameDt;
    updateReport(gameDt);
    renderTimer += Math.max(0, Number(realDt) || 0);
    if (renderTimer >= 0.2) {
      renderTimer = 0;
      render();
    }
  }

  function snapshot() {
    return {
      active: sim.state.facilityRank >= 3,
      mode: sim.state.routingMode,
      current: metricSnapshot(recentFlow(25)),
      report: pendingReport || latestReport,
    };
  }

  window.__logisticsBossRouting = { snapshot };
  render();
  return { update, render, snapshot };
}
