export const ROUTING_MODES = ['balanced', 'express', 'consolidated'];

export const ROUTING_PACKAGES = Object.freeze({
  balanced: Object.freeze({
    id: 'balanced',
    label: 'Balanced Parcel',
    shortLabel: 'BALANCED',
    dispatchInterval: 4.2,
    minBatch: 1,
    batchSize: 1,
    revenueMultiplier: 1,
    summary: '標準間隔・標準単価',
  }),
  express: Object.freeze({
    id: 'express',
    label: 'Express Dispatch',
    shortLabel: 'EXPRESS',
    dispatchInterval: 1.8,
    minBatch: 1,
    batchSize: 1,
    revenueMultiplier: 0.82,
    summary: '高速出荷・単価 -18%',
  }),
  consolidated: Object.freeze({
    id: 'consolidated',
    label: 'Consolidated Linehaul',
    shortLabel: 'LINEHAUL',
    dispatchInterval: 7.5,
    minBatch: 3,
    batchSize: 3,
    revenueMultiplier: 1.22,
    summary: '3箱集約・単価 +22%',
  }),
});

export function routingPackage(mode) {
  return ROUTING_PACKAGES[mode] || ROUTING_PACKAGES.balanced;
}

export function routingRevenue(baseValue, mode) {
  const base = Math.max(0, Number(baseValue) || 0);
  return Math.round(base * routingPackage(mode).revenueMultiplier);
}

export function isRoutingMode(mode) {
  return ROUTING_MODES.includes(mode);
}
