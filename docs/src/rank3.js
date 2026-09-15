import {
  RANK3_ASSET_TARGET,
  RANK3_THROUGHPUT_TARGET,
  rank3ReadinessFromState,
} from './rank3-model.js';

export { RANK3_ASSET_TARGET, RANK3_THROUGHPUT_TARGET, rank3ReadinessFromState } from './rank3-model.js';

function formatAssets(value) {
  return `¥${Math.max(0, Math.floor(Number(value) || 0)).toLocaleString('ja-JP')}`;
}

export function bindRank3Readiness(sim) {
  const el = {
    opsNext: document.getElementById('rank3OpsNext'),
    zones: document.getElementById('rank3GoalZones'),
    assets: document.getElementById('rank3GoalAssets'),
    throughput: document.getElementById('rank3GoalThroughput'),
    bar: document.getElementById('rank3StageBar'),
    hint: document.getElementById('rank3StageHint'),
  };
  let timer = 0;
  let lastSignature = '';

  function snapshot() {
    return rank3ReadinessFromState(sim.state, sim.facilityInfo);
  }

  function render() {
    const r = snapshot();
    const rank3Active = sim.state.facilityRank >= 3;
    const signature = [r.zones, r.assets, r.throughput, r.score, r.ready, sim.state.facilityRank].join('|');
    if (signature === lastSignature) return r;
    lastSignature = signature;

    if (el.opsNext) el.opsNext.textContent = rank3Active ? 'RANK 3' : sim.state.facilityRank >= 2 ? `NEXT ${r.score}/3` : 'NEXT RANK 2';
    if (el.zones) el.zones.textContent = `区画 ${r.zones}/3`;
    if (el.assets) el.assets.textContent = `設備 ${formatAssets(Math.min(r.assets, RANK3_ASSET_TARGET))}/${formatAssets(RANK3_ASSET_TARGET)}`;
    if (el.throughput) el.throughput.textContent = `出荷 ${Math.min(r.throughput, RANK3_THROUGHPUT_TARGET)}/${RANK3_THROUGHPUT_TARGET}分`;
    if (el.bar) el.bar.style.width = `${rank3Active ? 100 : (r.score / 3) * 100}%`;
    if (el.hint) {
      el.hint.textContent = rank3Active
        ? 'Fulfillment Center 稼働中 · Carrier Routingを準備中'
        : r.ready
          ? 'Fulfillment Center 昇格条件クリア · 契約は不要'
          : '区画・設備資産・実出荷の3条件でFulfillment Centerへ';
    }
    return r;
  }

  function update(dt) {
    timer += Math.max(0, Number(dt) || 0);
    if (timer < 0.2) return;
    timer = 0;
    render();
  }

  render();
  return { update, render, snapshot };
}
