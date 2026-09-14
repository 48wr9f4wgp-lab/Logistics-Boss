# Logistics Boss — Capital Expansion Loop v1

Status: LOCK for implementation / 2026-09-14
Priority: This title-specific spec overrides older progression details where they conflict.

## Product direction
Logistics Boss is not a button-upgrade idle game and not a prescribed puzzle path.
The central fantasy is to grow a tiny manual depot into a visually massive logistics operation by repeatedly reinvesting profits into equipment that changes the real flow of goods.

Core loop:

observe flow → identify constraint → invest capital → equipment visibly changes → throughput / revenue changes → measure result → reinvest at a larger scale

The player may choose which constraint to attack first. The game shows state and measured consequences; it does not prescribe a single correct purchase order.

## Capital principles
1. Money should escalate aggressively over the lifetime of the facility.
2. Major equipment purchases must change both simulation behavior and the 3D facility.
3. Every major purchase must expose before/after operational evidence.
4. Equipment should create or reveal the next bottleneck rather than permanently solving logistics.
5. Cash is not the reward by itself; the reward is watching a larger, faster logistics system emerge.
6. Early investments are reachable within minutes. Later investments should reach hundreds of thousands, millions, and eventually much higher tiers.
7. Rank progression remains a macro unlock system, but capital investment is available as an ongoing loop rather than a one-time rank reward.

## Capital Expansion v1 equipment
The first implementation intentionally reuses existing deterministic simulation systems so every purchase has real operational impact.

- Rack Wing: +4 storage capacity per level and visible rack expansion.
- Packing Module: -18% packing time per level and visible packing equipment.
- Handling / Route Improvement: +16% worker movement speed per level and visible lane expansion.
- Conveyor Spine: automatic inbound-to-rack movement, faster at higher levels, and visible conveyor modules.

Costs are strongly nonlinear. The first tier is reachable quickly; later tiers require accumulated capital.

## Commercial scale
Equipment assets also represent the size and credibility of the operation. Higher equipment-asset thresholds unlock larger commercial contracts and therefore higher revenue per shipped parcel.

This is not a passive multiplier detached from the world: the same investments also increase physical capacity / throughput. Revenue escalation therefore combines higher operational volume with a larger commercial scale.

Commercial tiers in v1:
- Local Depot
- Mechanized Depot
- High-Throughput Warehouse
- Regional Fulfillment
- Automated DC
- Mega Logistics

## Investment result report
After an equipment purchase, observe for 25 simulation seconds and compare against the pre-purchase state.

Report at minimum:
- shipments per minute
- shipment revenue per minute
- open orders
- inbound queue
- rack utilization
- rough payback time when the measured revenue delta is positive

Negative outcomes are shown as negative. The report must not fake improvement.

## UX rule
The investment panel may explain what an item does and show measured results, but must not say which equipment the player should buy next.

## Success gate
Capital Expansion v1 succeeds if the player can feel all four of these in the first session:
1. I earned enough to buy a meaningful machine.
2. The warehouse visibly changed when I bought it.
3. I can see whether the purchase actually helped.
4. The improved facility makes me want a much more expensive next investment.

## Deferred
- free-form conveyor drawing
- forklifts / AGV fleets
- automatic sorter network
- AS/RS warehouse
- multi-building logistics campus
- truck yard / scheduled waves
- property expansion
- second logistics center

These are the next layers once the capital loop itself proves fun.
