function ensureStyles() {
  if (document.querySelector('link[data-ergonomics-pass]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = './ergonomics.css';
  link.dataset.ergonomicsPass = '1';
  document.head.appendChild(link);
}

const yen = (value) => `¥${Math.round(Math.abs(Number(value) || 0)).toLocaleString('ja-JP')}`;
const signed = (value, suffix = '') => {
  const n = Math.round(Number(value) || 0);
  return `${n > 0 ? '+' : ''}${n}${suffix}`;
};

export function bindErgonomics(sim, capital) {
  ensureStyles();

  const app = document.getElementById('app');
  const dock = document.getElementById('commandDock');
  const dockExpanded = document.getElementById('dockExpanded');
  const dockToggle = document.getElementById('dockToggle');
  const observe = document.getElementById('observeBtn');
  const capitalPanel = document.getElementById('capitalPanel');
  const capitalReport = document.getElementById('capitalReport');
  if (!app || !dock || !dockToggle) return { update() {} };

  // Capital is the primary management loop. Keep it first when the sheet opens.
  if (dockExpanded && capitalPanel && dockExpanded.firstElementChild !== capitalPanel) dockExpanded.prepend(capitalPanel);

  const handle = document.createElement('div');
  handle.className = 'sheetHandle';
  handle.setAttribute('role', 'button');
  handle.setAttribute('aria-label', '管理パネルを閉じる');
  handle.tabIndex = 0;
  dock.prepend(handle);

  // Keep this outside capitalReport because capital.js refreshes the report body every 250 ms.
  const observeAction = document.createElement('button');
  observeAction.type = 'button';
  observeAction.className = 'capitalObserveAction';
  observeAction.hidden = true;
  observeAction.addEventListener('click', () => {
    closeSheet();
    try { navigator.vibrate?.(10); } catch {}
  });
  if (capitalReport) capitalReport.insertAdjacentElement('afterend', observeAction);

  const pulse = document.createElement('div');
  pulse.id = 'investmentPulse';
  pulse.setAttribute('role', 'status');
  pulse.setAttribute('aria-live', 'polite');
  pulse.innerHTML = '<strong></strong><span></span>';
  app.appendChild(pulse);
  const pulseTitle = pulse.querySelector('strong');
  const pulseDetail = pulse.querySelector('span');

  let updateTimer = 0;
  let pointerStartY = null;
  let readySignature = '';
  let readyShownAt = 0;

  const dockIsCompact = () => dock.classList.contains('compact');

  function closeSheet() {
    if (!dockIsCompact()) dockToggle.click();
  }

  function syncDockSemantics() {
    const compact = dockIsCompact();
    const affordable = Boolean(document.querySelector('.capitalBuy[data-ready="true"]'));
    dockToggle.textContent = compact ? '投資' : '閉じる';
    dockToggle.dataset.afford = compact && affordable ? 'true' : 'false';
    dockToggle.setAttribute('aria-label', compact
      ? (affordable ? '設備投資を開く。購入できる設備があります' : '設備投資を開く')
      : '管理パネルを閉じる');
    if (observe) {
      observe.textContent = '観察';
      observe.setAttribute('aria-label', 'UIを隠して倉庫を観察');
    }
  }

  function reportSignature(report) {
    if (!report) return '';
    return `${report.key || ''}|${report.label || ''}|${report.cost || 0}`;
  }

  function syncObserveAction(report) {
    const show = Boolean(report && capitalReport && !capitalReport.hidden && !dockIsCompact());
    observeAction.hidden = !show;
    if (!show) return;
    observeAction.textContent = report.ready ? '結果を見ながら倉庫を観察' : '倉庫を観察しながら測定';
  }

  function updatePulse(report) {
    if (!report || !dockIsCompact()) {
      pulse.classList.remove('show');
      return;
    }

    const signature = reportSignature(report);
    if (!report.ready) {
      pulse.dataset.tone = 'normal';
      pulseTitle.textContent = `${report.label} · 効果測定中`;
      pulseDetail.textContent = `観測 ${Math.min(25, Math.floor(report.elapsed || 0))}/25秒 · 倉庫の流れをそのまま観察`;
      pulse.classList.add('show');
      return;
    }

    if (readySignature !== signature) {
      readySignature = signature;
      readyShownAt = performance.now();
      try { navigator.vibrate?.([12, 35, 20]); } catch {}
    }

    if (performance.now() - readyShownAt > 12000) {
      pulse.classList.remove('show');
      return;
    }

    const d = report.delta || {};
    const positive = (Number(d.revenue) || 0) > 0 || (Number(d.throughput) || 0) > 0;
    const negative = (Number(d.revenue) || 0) < 0 && (Number(d.throughput) || 0) <= 0;
    pulse.dataset.tone = negative ? 'bad' : positive ? 'good' : 'normal';
    pulseTitle.textContent = `${report.label} · 投資結果`;
    const revenue = `${Number(d.revenue) > 0 ? '+' : Number(d.revenue) < 0 ? '-' : ''}${yen(d.revenue)}/分`;
    pulseDetail.textContent = `売上 ${revenue} · 出荷 ${signed(d.throughput, '/分')} · 注文 ${signed(d.orders, '件')}`;
    pulse.classList.add('show');
  }

  function sync() {
    syncDockSemantics();
    const snapshot = capital?.snapshot?.() || window.__logisticsBossCapital?.snapshot?.();
    const report = snapshot?.report || null;
    syncObserveAction(report);
    updatePulse(report);
  }

  handle.addEventListener('click', closeSheet);
  handle.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      closeSheet();
    }
  });
  handle.addEventListener('pointerdown', (event) => {
    pointerStartY = event.clientY;
    handle.setPointerCapture?.(event.pointerId);
  });
  handle.addEventListener('pointerup', (event) => {
    if (pointerStartY != null && event.clientY - pointerStartY > 24) closeSheet();
    pointerStartY = null;
  });
  handle.addEventListener('pointercancel', () => { pointerStartY = null; });
  dockToggle.addEventListener('click', () => setTimeout(syncDockSemantics, 0));

  const observer = new MutationObserver(() => syncDockSemantics());
  observer.observe(dock, { attributes: true, attributeFilter: ['class'] });

  function update(dt) {
    updateTimer += Math.max(0, Number(dt) || 0);
    if (updateTimer < 0.1) return;
    updateTimer = 0;
    sync();
  }

  sync();
  return { update };
}
