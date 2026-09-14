export const CAPITAL_INVESTMENTS = {
  rack: {
    key: 'rack',
    upgrade: 'rack',
    label: 'ラック棟増設',
    short: '保管',
    costs: [1000, 4500, 30000, 250000],
    unlockAssets: 0,
    effect: '棚容量 +4箱 / 3Dラック棟を増設',
    emphasis: '容量を増やして入荷停止を減らす',
  },
  pack: {
    key: 'pack',
    upgrade: 'pack',
    label: '梱包モジュール',
    short: '梱包',
    costs: [1600, 7000, 50000, 400000, 4000000],
    unlockAssets: 0,
    effect: '梱包時間 -18% / 梱包設備を増設',
    emphasis: '注文処理を高速化する',
  },
  speed: {
    key: 'speed',
    upgrade: 'speed',
    label: '動線・搬送改善',
    short: '移動',
    costs: [2000, 8500, 60000, 500000, 5000000],
    unlockAssets: 0,
    effect: '作業員移動 +16% / 搬送レーンを追加',
    emphasis: '工程間の移動ロスを削る',
  },
  conveyor: {
    key: 'conveyor',
    upgrade: 'conveyor',
    label: 'コンベアSpine',
    short: '自動搬送',
    costs: [3500, 18000, 120000, 1000000],
    unlockAssets: 0,
    effect: '搬入口→棚を自動搬送 / 上位ほど間隔短縮',
    emphasis: '人手搬送そのものを設備へ置き換える',
  },
  workforce: {
    key: 'workforce',
    upgrade: 'worker',
    label: '現場チーム増員',
    short: '人員',
    costs: [3500, 15000, 70000, 350000, 1800000],
    unlockAssets: 2500,
    effect: '作業員 +1人 / 3Dスタッフを追加',
    emphasis: '人手で複数工程の詰まりを柔軟に吸収する',
  },
  forklift: {
    key: 'forklift',
    upgrade: 'forklift',
    label: 'フォークリフト隊',
    short: 'パレット搬送',
    costs: [15000, 120000, 900000, 8000000],
    unlockAssets: 8000,
    effect: '複数箱を搬入口→棚へまとめて自動搬送 / 3D車両を増備',
    emphasis: '入荷ヤードをパレット単位で一気に捌く',
  },
  agv: {
    key: 'agv',
    upgrade: 'agv',
    label: 'AGVピック隊',
    short: '自動ピック',
    costs: [40000, 320000, 2500000, 20000000],
    unlockAssets: 40000,
    effect: '棚→梱包を自動搬送 / 3D AGVを増備',
    emphasis: '棚から梱包までのピック搬送を無人化する',
  },
  sorter: {
    key: 'sorter',
    upgrade: 'sorter',
    label: '自動ソーター',
    short: '自動仕分け',
    costs: [90000, 750000, 6000000, 48000000],
    unlockAssets: 200000,
    effect: '梱包済み→出荷口を自動仕分け / 3Dソーターを増設',
    emphasis: '出荷口の人手処理を機械仕分けへ置き換える',
  },
  hall: {
    key: 'hall',
    upgrade: 'hall',
    label: '物流ホール拡張',
    short: '敷地',
    costs: [300000, 2500000, 20000000],
    unlockAssets: 200000,
    effect: '保管容量 +8箱 / 入荷上限 +4箱 / 3Dホール棟を増設',
    emphasis: '建物そのものを拡張し、受入・保管余力を増やす',
  },
  truckDock: {
    key: 'truckDock',
    upgrade: 'truckDock',
    label: 'トラックドック',
    short: '幹線入荷',
    costs: [650000, 5000000, 40000000],
    unlockAssets: 500000,
    effect: '連続入荷をトラック波動へ変更 / ドック・トラックを3D表示',
    emphasis: 'まとまった荷量を受け、ドック能力と倉庫内処理の差を経営する',
  },
};

export const COMMERCIAL_TIERS = [
  { minAssets: 0, label: 'Local Depot', saleValue: 120 },
  { minAssets: 8000, label: 'Mechanized Depot', saleValue: 200 },
  { minAssets: 40000, label: 'High-Throughput Warehouse', saleValue: 500 },
  { minAssets: 200000, label: 'Regional Fulfillment', saleValue: 1200 },
  { minAssets: 1000000, label: 'Automated DC', saleValue: 3000 },
  { minAssets: 5000000, label: 'Mega Logistics', saleValue: 8000 },
  { minAssets: 25000000, label: 'National Hub', saleValue: 18000 },
  { minAssets: 75000000, label: 'Automated Mega Hub', saleValue: 40000 },
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

export function investmentUnlocked(upgrades = {}, key) {
  const def = CAPITAL_INVESTMENTS[key];
  if (!def) return false;
  return investedCapital(upgrades) >= (def.unlockAssets || 0);
}

export function commercialTierForAssets(assets) {
  let tier = COMMERCIAL_TIERS[0];
  for (const candidate of COMMERCIAL_TIERS) {
    if (assets >= candidate.minAssets) tier = candidate;
    else break;
  }
  return tier;
}

export function nextCommercialTierForAssets(assets) {
  return COMMERCIAL_TIERS.find((candidate) => candidate.minAssets > assets) || null;
}

export function currentUnitRevenue(upgrades = {}) {
  return commercialTierForAssets(investedCapital(upgrades)).saleValue;
}

export function totalAssetValue(money, upgrades = {}) {
  return Math.max(0, Number(money) || 0) + investedCapital(upgrades);
}

export function forkliftIntervalForLevel(level) {
  if (!level) return Infinity;
  return Math.max(3.2, 8.2 - Math.max(1, level) * 1.25);
}

export function forkliftBatchForLevel(level) {
  if (!level) return 0;
  return level >= 3 ? 3 : 2;
}

export function agvIntervalForLevel(level) {
  if (!level) return Infinity;
  return Math.max(2.2, 6.4 - Math.max(1, level) * 1.05);
}

export function agvBatchForLevel(level) {
  if (!level) return 0;
  return level >= 4 ? 2 : 1;
}

export function sorterIntervalForLevel(level) {
  if (!level) return Infinity;
  return Math.max(1.6, 4.8 - Math.max(1, level) * 0.8);
}

export function truckWaveSizeForLevel(level) {
  if (!level) return 0;
  return [0, 10, 12, 15][Math.min(3, Math.max(1, Math.floor(level)))] || 10;
}

export function truckWaveIntervalForLevel(level) {
  if (!level) return Infinity;
  return [Infinity, 28, 24, 20][Math.min(3, Math.max(1, Math.floor(level)))] || 28;
}

export function truckUnloadIntervalForLevel(level) {
  if (!level) return Infinity;
  return [Infinity, 0.75, 0.55, 0.4][Math.min(3, Math.max(1, Math.floor(level)))] || 0.75;
}

export function formatInvestmentEffect(key, nextLevel) {
  const level = Math.max(1, Number(nextLevel) || 1);
  if (key === 'rack') return `棚容量 +${level * 4}箱`;
  if (key === 'pack') return `基準比 約${Math.round((1 - Math.pow(0.82, level)) * 100)}%短縮`;
  if (key === 'speed') return `移動速度 +${level * 16}%`;
  if (key === 'conveyor') return level === 1 ? '自動搬送を解禁' : `自動搬送 Lv.${level}`;
  if (key === 'workforce') return `作業員 +${level}人`;
  if (key === 'forklift') return `${forkliftBatchForLevel(level)}箱まとめ搬送 / 約${forkliftIntervalForLevel(level).toFixed(1)}秒`;
  if (key === 'agv') return `${agvBatchForLevel(level)}箱自動ピック / 約${agvIntervalForLevel(level).toFixed(1)}秒`;
  if (key === 'sorter') return `自動出荷 1箱 / 約${sorterIntervalForLevel(level).toFixed(1)}秒`;
  if (key === 'hall') return `ホール +${level}棟 / 保管 +${level * 8}箱 / 入荷上限 +${level * 4}箱`;
  if (key === 'truckDock') return `${truckWaveSizeForLevel(level)}箱/便 · 約${truckWaveIntervalForLevel(level)}秒周期 · 荷下ろし${truckUnloadIntervalForLevel(level).toFixed(2)}秒/箱`;
  return '';
}
