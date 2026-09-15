# LOGISTICS BOSS — Development Handoff

Last updated: 2026-09-15 JST

## 1. Product / Canonical Loop

LOGISTICS BOSS is a portrait mobile 3D logistics-management game. The player is the owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

Observe logistics → identify bottleneck → invest / change operations → workers and equipment react autonomously → throughput / revenue / congestion change → measure results → reinvest at larger scale.

Economic state, shipment creation, money, queues, routing, and progression are Domain-authoritative. UI / View must never generate shipment revenue or fake logistics state.

Current stage: Vertical Slice / Functional Build expansion. Not Release Candidate.

## 2. Repository / Branch / PR

Repository: `48wr9f4wgp-lab/Logistics-Boss`

Canonical branch: `main`

Feature branch: `feature/rank3-carrier-routing-domain`

PR: `#44 Rank 3 Carrier Routing vertical slice`

GitHub state verified before this handoff refresh:

- `main`: `b433f3e538f0bc696b1f09e10d6372a96a3460cc`
  - preview-bot commit only
- latest functional main before PR #44: `b84e798050087e3e4516a6e6f23823d080c96c2b`
- latest verified feature code before this handoff refresh: `a83e2b7f4749b11a26484cc002602ffe89eff7af`
- PR #44 mergeability: clean / mergeable
- PR CI run `34965362629` / run #106: success
  - Parse/import
  - Rank 1/2 regressions
  - Rank 3 Receiving Annex regressions
  - open-orders measurement smoke
  - Carrier Routing smoke
  - Carrier Routing pacing
  - Rank 3 UI smoke
  - Rank 3 visual smoke
  - Full Scene Runtime
  - Web export
  - Preview artifact upload

If this file is later read from `main`, first re-check GitHub because PR #44 may already have been merged and preview bot may have advanced `main`.

## 3. Technology / Platform

- Godot 4.7.2 Standard
- GDScript
- GL Compatibility
- portrait, 390×844 reference
- touch orbit / pinch zoom
- final targets: native iOS + Android
- Godot Web export: engineering preview only

Engineering preview:

`https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`

No production backend / DB / auth / cloud save / IAP / analytics / crash reporting yet.

Persistence is local JSON through `godot/persistence/save_store.gd`.

## 4. Current Save Schema

Current Rank 3 schema: **v6**.

v6 adds persistent Carrier Routing state:

- `active_routing_mode`

Migration behavior:

- v5 Rank 3 saves preserve Receiving Annex ownership
- pre-v6 saves default Carrier Routing safely to `Balanced Parcel`
- existing schema migration smoke remains green

## 5. Rank 3 Gate — Current Canonical

Rank 3 / Fulfillment Center requirements:

- Rank 2 expansion zones: 3 / 3
- equipment asset value: >= ¥200,000
- live throughput: >= 6 shipments/min

Contracts are **optional** and are not a Rank 3 gate.

`godot/ui/game_hud_rank3.gd` was fixed in PR #44 so late Rank 2 now shows:

- 拡張ゾーン x/3
- 設備資産 ¥x / ¥200,000
- 出荷ペース x / 6.0分

The stale mandatory `契約 x/8` unlock display is removed.

## 6. Receiving Annex

Still implemented and authoritative.

- one-time Rank 3 investment
- cost: ¥24,000
- inbound acceptance capacity: +14
- 25s Before / After measurement
- Save / Load
- visible 3D

Prior research remains valid:

- universal receiving holding buffer was rejected because it only improved Fast Pick path and was redundant for High Density path
- AGV / AMR / Sorter / ASRS / Cross-dock were not adopted as automatic next upgrades because measured shipment delta was 0 in prior scouts

## 7. open_orders Measurement — Completed in PR #44

`godot/domain/flow_measurement.gd`

Current behavior:

- retains backward-compatible optional `orders` in `record_state()`
- adds dedicated `record_orders(at, dt, orders)` sampling
- calculates authoritative `open_orders` average
- exposes `open_orders_sampled_seconds`
- includes `open_orders` delta in Before / After results

`godot/domain/rank3_warehouse_sim.gd` records authoritative Domain `open_orders` every active simulation tick.

Focused test:

`godot/tests/flow_measurement_open_orders_smoke.gd`

It verifies:

- non-zero seeded backlog baseline
- non-zero after-window
- correct backlog delta
- legacy `record_state(..., orders)` compatibility

## 8. Carrier Routing — Implemented in PR #44

Domain file:

`godot/domain/rank3_warehouse_sim.gd`

Authoritative state:

`active_routing_mode`

Routes:

### Balanced Parcel

- route key: `balanced`
- batch: 1 parcel
- dispatch duration: 3.0s before worker-speed scaling
- value: ¥500 / parcel
- reference / neutral state

### Express Dispatch

- route key: `express`
- batch: 1 parcel
- dispatch duration: 1.65s before worker-speed scaling
- value: ¥410 / parcel
- tradeoff: faster outbound clearance, lower margin

### Consolidated Linehaul

- route key: `consolidated`
- batch threshold: 4 parcels
- dispatch duration: 6.8s before worker-speed scaling
- value: ¥620 / parcel
- tradeoff: higher parcel value / batch efficiency, but packed inventory waits until the batch threshold

Public APIs:

- `routing_modes()`
- `routing_profile(mode)`
- `routing_summary()`
- `set_routing_mode(next_mode)`

Route changes start a 25s Before / After measurement.

### Important shipment-authority behavior

Rank 3 SHIP tasks freeze at task start:

- routing mode
- batch size
- unit value

This prevents an in-flight shipment from being repriced if the player switches route before task completion.

Consolidated dispatch reserves all 4 packed parcels at task start.

Completion updates authoritative Domain exactly once:

- shipped count
- money
- shipment timestamps
- RP crossings
- measurement shipment count

Focused smoke verifies no duplicate revenue / shipment and that routing can move a bottleneck from outbound to another queue.

## 9. Carrier Routing UI

File:

`godot/ui/game_hud_rank3.gd`

Carrier Routing is inside the existing Rank 3 management sheet, not a new permanent top-level HUD cluster.

Current controls:

- compact current-route summary
- 3-option `OptionButton`
  - Balanced Parcel
  - Express Dispatch
  - Consolidated Linehaul

Rank 2 hides routing controls.

Route selection calls Domain `set_routing_mode()`.

`routing_changed` displays 25s measurement feedback.

Focused coverage:

`godot/tests/rank3_ui_smoke.gd`

## 10. Carrier Routing 3D Presentation

New file:

`godot/view/rank3_routing_hub_view.gd`

Wired in:

`godot/main.gd`

Visible route states:

- `RoutingHub_Balanced`
  - standard two-lane treatment / neutral carrier
- `RoutingHub_Express`
  - cyan fast lane / arrows / compact express carrier
- `RoutingHub_Consolidated`
  - amber batch lanes / four staged pallets / larger carrier

The routing hub is an explicit responsibility-specific View file; do not create `visual_pass_4`, `visual_pass_5`, etc.

Focused coverage:

`godot/tests/rank3_visual_smoke.gd`

The automated visual smoke confirms each route creates a distinct 3D state. **This is not a substitute for final iPhone visual review.**

## 11. Routing Pacing / Tradeoff Regression

Focused report:

`godot/tests/rank3_carrier_routing_pacing_report.gd`

Deterministic assertions currently green:

- Express clears a sustained packed backlog faster than Balanced
- Express revenue per parcel is lower than Balanced
- Consolidated revenue per parcel is higher than Balanced
- Consolidated provides batch efficiency when enough packed inventory exists
- Consolidated creates higher packed-inventory pressure under slow trickle supply
- route revenue equals authoritative shipped parcels × route unit value; no duplicate revenue

This test is meant to protect the tradeoff shape, not declare the final economy permanently balanced.

## 12. Key Tests Added / Strengthened in PR #44

- `godot/tests/flow_measurement_open_orders_smoke.gd`
- `godot/tests/rank3_carrier_routing_smoke.gd`
- `godot/tests/rank3_carrier_routing_pacing_report.gd`
- `godot/tests/rank3_ui_smoke.gd` strengthened
- `godot/tests/rank3_visual_smoke.gd` strengthened
- `godot/tests/rank3_receiving_annex_smoke.gd` updated for schema v6

`.github/workflows/godot-ci.yml` now gates the new routing / measurement tests.

## 13. Existing Architecture That Must Remain

Runtime / composition:

- `godot/main.gd`

Domain:

- `godot/domain/warehouse_sim.gd`
- `godot/domain/workload_warehouse_sim.gd`
- `godot/domain/rank3_warehouse_sim.gd`
- `godot/domain/flow_measurement.gd`
- `godot/domain/capital_catalog.gd`
- `godot/domain/rank2_facility_catalog.gd`
- `godot/domain/progression_system.gd`
- `godot/domain/workload_wave_model.gd`

View:

- `godot/view/warehouse_view.gd`
- `godot/view/forklift_automation_view.gd`
- `godot/view/rank2_facility_view.gd`
- `godot/view/rank3_receiving_annex_view.gd`
- `godot/view/rank3_routing_hub_view.gd`
- existing visual pass 2 / 3 / composition-fix only

UI:

- `godot/ui/game_hud_ja.gd`
- `godot/ui/game_hud_waves.gd`
- `godot/ui/game_hud_rank3.gd`

Embedded Japanese font:

- `godot/assets/fonts/MPLUS1p-Regular.ttf`

Persistence:

- `godot/persistence/save_store.gd`

## 14. Visual Direction

North Star:

- Dark Navy Industrial
- Cyan Tech Accent
- Amber / Orange Safety Accent
- warm local lights
- stylized premium mobile
- warehouse remains the screen focal point

Confirmed prior device improvements that must not regress:

- open-top / cutaway visibility
- no obstructive roof / ceiling truss
- reduced left foreground wall obstruction
- wider max zoom-out
- smoother / less sensitive touch orbit
- stable pinch
- small shipment toast
- bottom safe-area fixes
- embedded Japanese font

Do not return to SystemFont dependency for Japanese.

## 15. Explicit Rejections / Avoid

Do not:

- move production gameplay back to Three.js `/docs`
- add gameplay to `/docs`
- make manual forklift driving the core loop
- make manual parcel carrying the core loop
- generate money or shipment state from UI / View
- add fake automation animation disconnected from Domain
- add AGV / Sorter / ASRS / Cross-dock without measured gameplay value
- restore mandatory Rank 3 contracts
- restore obstructive roof / truss
- create endless visual_pass_N files
- call unverified behavior fixed / complete

## 16. CI / Release Flow

Required sequence:

branch → PR → CI green → merge to `main` → post-merge main CI green → Pages engineering preview success.

Do not treat Web preview as native iOS / Android release validation.

## 17. Immediate Next Action

First re-check GitHub state.

If PR #44 is still open:

1. confirm latest-head CI green
2. mark PR ready
3. merge only while green / clean
4. confirm `main` CI green
5. confirm GitHub Pages preview workflow success
6. verify preview availability

If PR #44 is already merged:

- do not reimplement Carrier Routing
- verify post-merge CI / preview state first
- next product-quality gate is iPhone real-device review of Carrier Routing UI / 3D readability and touch ergonomics
- after device review, continue Rank 3 design based on measured bottleneck frontier rather than adding themed automation blindly

## 18. Completion Language

Carrier Routing can be called **automated-verified Vertical Slice** only after latest PR CI + post-merge CI are green.

Do not call final UI / 3D product quality complete until iPhone real-device verification is performed.
