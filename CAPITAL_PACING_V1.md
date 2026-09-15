# Logistics Boss — Capital Pacing v1

Status: measured balance baseline / 2026-09-15
Authority: title-specific economy continuation of `CAPITAL_EXPANSION_V2.md`.

## Goal

Capital progression must reward operational improvement and investment decisions without turning the mid-game into passive cash waiting or trivializing major equipment purchases.

This pass covers the equipment-asset bands from ¥8,000 through ¥1,000,000. It does not yet certify pacing above ¥1,000,000.

## Measurement method

The regression audit uses the real `sim.js` logistics flow rather than a spreadsheet-only estimate.

For each representative healthy Rank 2 operation:
- deterministic order generation is used for reproducibility;
- the simulation runs at 4× time scale;
- 120 simulated seconds are used as warm-up;
- the next 180 simulated seconds are sampled;
- actual `shipment` events determine throughput and revenue;
- bridge time is estimated from measured revenue/minute and remaining equipment assets to the next commercial milestone.

These values are regression heuristics for a healthy representative operation. They are not a promise that every player or every build path reaches a milestone in exactly the measured time.

## Problem found

Before this pass, representative healthy operations produced excessive waits between major capital milestones:

- ~¥44,600 → ¥200,000: 35.9 minutes.
- ~¥229,600 → ¥500,000: 24.1 minutes.
- ~¥499,600 → ¥1,000,000: 44.7 minutes.

The last case also exposed an audit defect: ¥499,600 had been labeled as the `500k` band even though it was still below the ¥500,000 commercial threshold. The corrected 500k scenario now begins at ¥569,600 and the audit explicitly asserts that every scenario is inside its named asset band.

## Balance rule

For the ¥8,000–¥1,000,000 range, a representative healthy operation should require **7–15 minutes** of measured operating revenue to bridge from its current commercial band to the next milestone.

- Above 15 minutes: risk of passive waiting becoming the dominant play pattern.
- Below 7 minutes: risk of making investment choices and major equipment prices feel disposable.

The equipment prices and unlock thresholds are intentionally unchanged in this pass. The capital scale fantasy remains intact; only commercial shipment value is tuned.

## Commercial tiers

| Equipment assets | Tier | Revenue / shipment |
| ---: | --- | ---: |
| ¥0 | Local Depot | ¥120 |
| ¥8,000 | Mechanized Depot | ¥450 |
| ¥40,000 | High-Throughput Warehouse | ¥1,500 |
| ¥200,000 | Regional Fulfillment | ¥2,600 |
| ¥500,000 | Distribution Hub | ¥4,200 |
| ¥1,000,000 | Automated DC | ¥6,000 |
| ¥5,000,000 | Mega Logistics | ¥8,000 |
| ¥25,000,000 | National Hub | ¥18,000 |
| ¥75,000,000 | Automated Mega Hub | ¥40,000 |

The ¥500,000 `Distribution Hub` tier is added so the transition from regional warehouse scale to million-yen automation has its own economic step instead of inheriting the ¥200,000 revenue curve.

## Final measured pacing

| Scenario | Equipment assets | Throughput | Revenue/min | Next milestone | Estimated bridge |
| --- | ---: | ---: | ---: | ---: | ---: |
| 8k band | ¥8,100 | 8.3/min | ¥3,750 | ¥40,000 | 8.5 min |
| 40k band | ¥44,600 | 8.7/min | ¥13,000 | ¥200,000 | 12.0 min |
| 200k band | ¥229,600 | 9.3/min | ¥24,267 | ¥500,000 | 11.1 min |
| 500k band | ¥569,600 | 13.7/min | ¥57,400 | ¥1,000,000 | 7.5 min |

All four representative bands remain inside the 7–15 minute target window.

## Regression gate

`docs/tests/capital-pacing-audit.mjs` must fail when:
- a scenario is not actually inside its named equipment-asset band;
- a representative healthy operation produces no real shipments;
- measured revenue is zero;
- the estimated capital bridge exceeds 15 minutes;
- the estimated capital bridge falls below 7 minutes.

`.github/workflows/capital-pacing.yml` runs the audit on pull requests and on pushes to `main`.

## Scope boundary / next audit

The next economy pass must separately measure the ¥1,000,000+ game before changing AS/RS, Mega Logistics, National Hub or Automated Mega Hub pacing. Do not extrapolate the 7–15 minute band mechanically to every late-game milestone: higher tiers may need longer strategic arcs, but waiting must still be justified by new decisions, visible facility growth and meaningful bottleneck changes.
