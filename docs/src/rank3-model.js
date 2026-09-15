import { investedCapital } from './capital-model.js';

export const RANK3_ASSET_TARGET = 200000;
export const RANK3_THROUGHPUT_TARGET = 6;
export const RANK3_NAME = 'Fulfillment Center';

const ZONE_GROUPS = ['intakeStrategy', 'rackStrategy', 'packStrategy'];

export function rank3ReadinessFromState(state, facilityInfo = {}) {
  const facilities = state?.facilities || {};
  const zones = ZONE_GROUPS.filter((group) => Object.keys(facilityInfo).some((key) => facilityInfo[key]?.group === group && facilities[key])).length;
  const assets = investedCapital(state?.upgrades || {});
  const throughput = Math.max(0, Number(state?.metrics?.perMinute) || 0);
  const conditions = {
    zones: zones >= 3,
    assets: assets >= RANK3_ASSET_TARGET,
    throughput: throughput >= RANK3_THROUGHPUT_TARGET,
  };
  const score = Number(conditions.zones) + Number(conditions.assets) + Number(conditions.throughput);
  return {
    zones,
    assets,
    throughput,
    conditions,
    score,
    ready: score === 3,
  };
}
