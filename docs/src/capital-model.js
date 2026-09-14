export const CAPITAL_INVESTMENTS = {
  rack: {
    key: 'rack',
    upgrade: 'rack',
    label: 'ラック棟増設',
    short: '保管',
    costs: [1000, 4500, 30000, 250000],
    effect: '棚容量 +4箱 / 3Dラック棟を増設',
    emphasis: '容量を増やして入荷停止を減らす',
  },
  pack: {
    key: 'pack',
    upgrade: 'pack',
    label: '梱包モジュール',
    short: '梱包',
    costs: [1600, 7000, 50000, 400000, 4000000],
    effect: '梱包時間 -18% / 梱包設備を増設',
    emphasis: '注文処理を高速化する',
  },
  speed: {
    key: 'speed',
    upgrade: 'speed',
    label: '動線・搬送改善',
    short: '移動',
    costs: [2000, 8500, 60000, 500000, 5000000],
    effect: '作業員移動 +16% / 搬送レーンを追加',
    emphasis: '工程間の移動ロスを削る',
  },
  conveyor: {
    key: 'conveyor',
    upgrade: 'conveyor',
    label: 'コンベアSpine',
    short: '自動搬送',
    costs: [3500, 18000, 120000, 1000000],
    effect: '搬入口→棚を自動搬送 / 上位ほど間隔短縮',
    emphasis: '人手搬送そのものを設備へ置き換える',
  },
};

export const COMMERCIAL_TIERS = [
  { minAssets: 0, label: 'Local Depot', saleValue: 120 },
  { minAssets: 8000, label: 'Mechanized Depot', saleValue: 200 },
  { minAssets: 40000, label: 'High-Throughput Warehouse', saleValue: 500 },
  { minAssets: 200000, label: 'Regional Fulfillment', saleValue: 1200 },
  { minAssets: 1000000, label: 'Automated DC', saleValue: 3000 },
  { minAssets: 5000000, label: 'Mega Logistics', saleValue: 8000 },
];

export function investmentLevel(upgrades, key) {
  const def = CAPITAL_INVESTMENTS[key];
  if (!def) return 0;
  return Math.max(0, Math.min(def.costs.length, Math.floor(Number(upgrades?.[def.upgrade] || 0))));
}

export function nextInvestmentCost(upgrades, key) {
  const def = CAPITAL_INVESTMENTS[key];
  if (!def) return Infinity;
  const level = investmentLevel(upgrades, key);
  return def.costs[level] ?? Infinity;
}

export function investedCapital(upgrades = {}) {
  let total = 0;
  for (const [key, def] of Object.entries(CAPITAL_INVESTMENTS)) {
    const level = investmentLevel(upgrades, key);
    for (let i = 0; i < level; i += 1) total += def.costs[i];
  }
  return total;
}

export function commercialTierForAssets(assets) {
  let tier = COMMERCIAL_TIERS[0];
  for (const candidate of COMMERCIAL_TIERS) {
    if (assets >= candidate.minAssets) tier = candidate;
    else break;
  }
  return tier;
}

export function currentUnitRevenue(upgrades = {}) {
  return commercialTierForAssets(investedCapital(upgrades)).saleValue;
}

export function totalAssetValue(money, upgrades = {}) {
  return Math.max(0, Number(money) || 0) + investedCapital(upgrades);
}

export function formatInvestmentEffect(key, nextLevel) {
  const level = Math.max(1, Number(nextLevel) || 1);
  if (key === 'rack') return `棚容量 +${level * 4}箱`;
  if (key === 'pack') return `基準比 約${Math.round((1 - Math.pow(0.82, level)) * 100)}%短縮`;
  if (key === 'speed') return `移動速度 +${level * 16}%`;
  if (key === 'conveyor') return level === 1 ? '自動搬送を解禁' : `自動搬送 Lv.${level}`;
  return '';
}
