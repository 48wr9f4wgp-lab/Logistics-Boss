# FLOTRA — Rank 3 Fulfillment Center

Status: Context Lock / implementation target / 2026-09-15
Authority: title-specific Rank 3 design. Current `main` remains authoritative for implemented behavior until this spec is merged and implemented.

## 1. Product problem

Rank 2 already lets the player build a Warehouse, choose structural zones, change staffing, buy automation, expand property and observe bottlenecks. Rank 3 must add a **new operating decision layer**, not just larger prices, more cards or another copy of the same warehouse.

The core fantasy remains:

`observe → identify constraint → choose operating/capital response → visible 3D change → measure consequences → new constraint → reinvest`

Rank 3 must preserve the warehouse as the primary visual object and must not become a menu-only empire layer.

## 2. 2026 benchmark refresh

Fresh public-store/community evidence was reviewed before locking this direction.

### Idle Factory Tycoon
Sources:
- https://apps.apple.com/us/app/idle-factory-tycoon-business/id1303389751
- https://play.google.com/store/apps/details?id=com.fluffyfairygames.idlefactorytycoon

Useful principle:
- multiple production stations create a readable capacity chain;
- automation reduces repetitive manual operation;
- investment remains the main progression verb.

Avoid copying:
- late progression that is mainly another factory with larger numbers;
- automation that removes the need to inspect constraints.

### Idle Miner Tycoon
Sources:
- https://apps.apple.com/am/app/idle-miner-tycoon-mine-gold/id1116645064
- https://playwanderer.online/game-reviews/idle-miner-tycoon
- https://www.reddit.com/r/IdleMinerTycoon/comments/1u9m55u/planning_for_the_long_run_how_should_i_progress/

Useful principle:
- the shaft / elevator / warehouse chain makes the weakest link legible;
- assigning automation/management to a stage creates meaningful allocation decisions;
- overview information that exposes the weakest link is strategically valuable.

Important warning:
- scaling the same balancing task across too many mines eventually turns readable bottleneck play into repetitive spreadsheet-style management;
- adding many independent systems without UI consolidation increases cognitive load.

Rank 3 therefore stays inside **one fulfillment center**. Multi-center/campus gameplay remains deferred.

### Idle Supermarket Tycoon / Supermarket Tycoon 3D
Sources:
- https://apps.apple.com/jp/app/idle-supermarket-tycoon-shop/id1442064951
- https://play.google.com/store/apps/details?id=com.codigames.market.idle.tycoon
- https://apps.apple.com/us/app/supermarket-tycoon-3d/id6739697316

Useful principle:
- visible departments/floors make expansion feel physical rather than numeric;
- staff and facility upgrades can solve one bottleneck while exposing another;
- player reviews explicitly notice when checkout capacity outgrows stocking capacity, which validates bottleneck-shifting as a source of management gameplay.

Important warning:
- economy stalls and inactive/serial floors make expansion feel like waiting instead of running a larger business.

### Airport Master — Plane Tycoon
Source:
- https://apps.apple.com/us/app/airport-master-plane-tycoon/id1621508593

Useful principle:
- employees, flights, shops and security create different operational surfaces inside one readable facility;
- expansion works best when the visible facility gains new functions, not only higher output.

### Logistics Empire — Truck Manager
Source:
- https://apps.apple.com/jp/app/logistics-empire-truck-manager/id6502345395

Useful principle:
- the long-term fantasy can escalate from a small operation toward a logistics network.

Constraint for FLOTRA:
- network/campus scale is a later meta layer. Rank 3 must first prove that one center can become deeper without becoming cluttered.

## 3. Rank 3 unlock — freedom progression

The existing `Fulfillment Center readiness` contract requirement is stale and conflicts with the title rule that contracts are optional.

Rank 3 readiness becomes three path-agnostic conditions:

1. **Structural design:** all 3 Rank 2 facility zones have a chosen strategy.
2. **Capital scale:** equipment assets ≥ **¥200,000**.
3. **Operational proof:** measured throughput ≥ **6 shipments/minute**.

Contracts are never required for Rank 3. They remain optional sources of reward/research/rating.

The player is not told which equipment to buy. Any capital path that reaches the asset threshold is valid.

## 4. Rank 3 core addition — Carrier Routing Layer

Rank 3 introduces a fulfillment-center outbound routing layer. The goal is to add a new tradeoff after packing rather than duplicating existing intake/rack/pack upgrades.

The initial vertical slice has three **Carrier Routing Packages**. The player may switch packages; there is no permanent correct answer.

### Balanced Parcel
- neutral dispatch cadence;
- neutral shipment value;
- default reference state;
- safest when no single outbound pressure dominates.

### Express Dispatch
- higher outbound dispatch frequency / faster clearance;
- lower margin per shipment because express capacity is expensive;
- good when packed output is the bottleneck;
- can move the bottleneck back toward packing, picking or inbound supply.

### Consolidated Linehaul
- dispatch waits for a small batch before releasing freight;
- higher margin per shipment / batch efficiency;
- intentionally allows packed inventory to accumulate;
- good when the center has spare outbound buffer and wants better margin;
- can create a visible outbound queue and expose storage/packing interactions.

Exact multipliers/cadence are balance variables, not locked until measured in the vertical slice.

## 5. 3D requirement

Rank 3 must visibly change the center.

Initial 3D scope:
- one new **Routing Hub** near outbound;
- three readable carrier lanes/gates representing Balanced / Express / Consolidated routes;
- the selected routing package is visible through active lane lighting/signage and movement cadence;
- shipment activity must animate from real dispatch events, not a decorative loop only.

Do not add a second map, second warehouse or campus at Rank 3.

## 6. Simulation requirement

The routing package must change authoritative simulation behavior, not only a UI multiplier.

Minimum vertical-slice contract:
- routing mode is saved/loaded;
- dispatch cadence and/or dispatch gating changes real packed→shipment flow;
- shipment revenue uses the active route economics inside the simulation domain;
- existing worker/sorter behavior cannot bypass the selected routing rule;
- route switching cannot duplicate shipments or revenue;
- recovery remains possible under congestion; no hard fail state.

## 7. Measurement requirement

Route switching starts a short operational observation window.

Before/After must include at minimum:
- shipments/minute;
- packed queue;
- open orders;
- revenue/minute.

A route can show a negative result. The UI diagnoses consequences but must not label one package as the correct answer.

## 8. Mobile UX

Rank 3 must not add another permanent top-level HUD cluster.

Rules:
- keep the warehouse visually primary;
- expose routing selection inside the existing management sheet;
- show current route in one compact operational summary line;
- no modal tutorial rail;
- no Director button that chooses a route for the player;
- FLOW mode may highlight the active outbound lane, but must remain optional.

## 9. Success Definition

Rank 3 vertical slice is successful only if all are true:

1. A player can reach Rank 3 without completing any contract.
2. All three routing packages produce materially different real outcomes.
3. Switching package visibly changes the 3D outbound operation.
4. At least one package can improve one metric while worsening another.
5. The active bottleneck can move after a route change.
6. Before/After reports the consequence without prescribing a solution.
7. Save/load preserves Rank 3 and routing state.
8. Existing Rank 1, Rank 2, Capital v2, Director, HUD stability and pacing regressions remain green.
9. iPhone layout/interaction is device-verified before calling Rank 3 complete.

## 10. Non-goals for this slice

Deferred:
- multiple fulfillment centers;
- world map / region network;
- free-form route drawing;
- individual customer destinations;
- complex carrier contracts;
- prestige/reset;
- offline income;
- monetization systems.

These can be reconsidered only after the one-center Rank 3 loop proves readable and fun.

## 11. Implementation order

1. Remove mandatory-contract readiness and lock the new 3-condition Rank 3 gate.
2. Add Rank 3 state/persistence and promotion.
3. Add authoritative carrier-routing dispatch behavior.
4. Add routing management UI.
5. Add real-event-driven 3D Routing Hub/gates.
6. Add Before/After route measurement.
7. Add automated regression covering optional-contract unlock, route tradeoffs, no duplicate revenue and save/load.
8. Deploy to Pages.
9. Perform focused iPhone verification.
