# LOGISTICS BOSS — Development Handoff

Updated: 2026-09-15 JST

## Canonical product

- App: `LOGISTICS BOSS`
- Repository: `48wr9f4wgp-lab/Logistics-Boss`
- Canonical branch: `main`
- Current work branch: `feature/rank3-carrier-routing-domain`
- Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
- Portrait reference: 390×844
- Final targets: native iOS / Android
- Godot Web export: Engineering Preview only
- Preview: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`
- `/docs/**` Three.js implementation is legacy reference only. Do not add production gameplay there.
- Project-wide rules follow `GAME_DEV_MASTER_RULES`; game-specific locked specifications override general rules.

## Product goal / core loop

`物流を観察 → ボトルネック発見 → 投資 / 運用判断 → 作業員・設備が自律反応 → 出荷量 / 収益 / 詰まりが変化 → 結果測定 → より大きな再投資`

The player is the logistics-center owner / operations manager, not a manual carrier or forklift driver. Finished product quality includes FTUE, progression, save, UI/UX, 3D art direction, motion/VFX, audio, haptics, analytics, performance and QA. Current state is still development / vertical-slice maturation, not Release Candidate.

Every major investment should create:
1. visible 3D change;
2. real logistics behavior change;
3. measurable Before / After;
4. potential to move the bottleneck.

Economy mutation belongs to Domain. UI / 3D presentation must never invent money or shipments.

## Repository state verified 2026-09-15

- Latest `main` tip: `b433f3e538f0bc696b1f09e10d6372a96a3460cc` (`Publish Godot web engineering preview`, bot commit).
- Latest functional source merge immediately before it: `b84e798050087e3e4516a6e6f23823d080c96c2b` (`Align Rank 3 gate with optional-contract spec`, PR #43).
- PR #43 PR-CI run `34960152012`: completed / success.
- GitHub Pages build for `b433f3e...`: completed / success.
- Current work branch head before this HANDOFF update: `e63d312149f31a7d4c95d8564755c27f1b712f94` (`Measure open-order effects in flow comparisons`).
- Current work branch was created from `b84e798...`; it does not include the subsequent preview-artifact-only main commit unless merged/rebased later.
- No PR exists yet for `feature/rank3-carrier-routing-domain`.

## Architecture / important files

- `godot/main.gd` — composition root; instantiates Rank3 simulation, 3D views, HUD and save store; autosave every 10s.
- `godot/domain/warehouse_sim.gd` — authoritative Rank 1/2 economy, parcel flow, workers, contracts, facilities.
- `godot/domain/workload_warehouse_sim.gd` — deterministic Rank 2 workload waves, schema-v4 extension.
- `godot/domain/rank3_warehouse_sim.gd` — Rank 3 Fulfillment Center, schema-v5, Rank 3 gate, Receiving Annex.
- `godot/domain/flow_measurement.gd` — 25s Before/After metrics; currently modified on work branch for open-order measurement and is incomplete as described below.
- `godot/domain/capital_catalog.gd` — Rank 1 capital prices / max levels.
- `godot/domain/rank2_facility_catalog.gd` — six mutually-exclusive Rank 2 structural choices.
- `godot/domain/progression_system.gd` — contracts / Rank 2 staffing.
- `godot/domain/workload_wave_model.gd` — forecast / peak cycle.
- `godot/view/warehouse_view.gd` — base 3D warehouse, workers, parcels, touch orbit / pinch camera.
- `godot/view/forklift_automation_view.gd` — real-event-driven forklift visual.
- `godot/view/rank2_facility_view.gd` — Rank 2 facility visuals.
- `godot/view/rank3_receiving_annex_view.gd` — Fulfillment Center marker + Receiving Annex 3D expansion.
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — existing presentation layers; avoid adding more pass files without responsibility cleanup.
- `godot/ui/game_hud_ja.gd` — Japanese HUD base with embedded M PLUS 1p font.
- `godot/ui/game_hud_waves.gd` — Rank 2 workload-wave UI.
- `godot/ui/game_hud_rank3.gd` — Rank 3 readiness / Receiving Annex management UI.
- `godot/persistence/save_store.gd` — local JSON save / backup.
- `.github/workflows/godot-ci.yml` — parse, domain/pacing/scout/UI/visual/runtime/Web-export CI.
- `.github/workflows/godot-preview-pages.yml` — Engineering Preview publish flow.
- `RANK3_FULFILLMENT_CENTER.md` — title-specific Rank 3 design target; currently specifies Carrier Routing packages as the next operating layer.

## Implemented gameplay

### Rank 1
- Start cash ¥5,000, 3 workers, rack 8.
- Real flow: inbound → storage → pick → pack → ship.
- Shipment value ¥500; RP +1 every 5 real shipments.
- Policies BALANCED / INBOUND / SHIP; Pause / 1x / 2x / 4x.
- Investments: worker, rack, worker speed, packing, forklift.
- Forklift is authoritative automation, not fake animation.
- 25s Before/After measurement exists.

### Rank 2
- Logistics Rating 8 promotes to Warehouse.
- Crew minimum 5.
- Five staffing presets with 30 simulated-second reassignment lock.
- Three one-of-two structural zones:
  - Intake: Double Dock vs Buffer Yard.
  - Storage: Fast Pick Rack vs High Density Rack.
  - Packing: Parallel Pack Line vs Fast Pack Cell.
- All six choices affect authoritative simulation and visible 3D.
- Deterministic workload cycle creates forecasted inbound, order and dispatch pressure; good play is proactive staffing.
- Save/workload state persists through schema v4 inherited by Rank 3.

### Rank 3 currently on `main`
- `Rank3WarehouseSim` and `Rank3GameHud` are live runtime classes.
- Save schema v5.
- Receiving Annex (`受入増設棟`) exists as a one-time Rank 3 structural investment:
  - cost ¥24,000;
  - authoritative inbound acceptance +14;
  - Domain-owned cash mutation;
  - 25s Before/After measurement;
  - save/load persistence;
  - visible 3D expansion.
- PR #41 post-Annex frontier proved AMR/PICK acceleration/retrieval/sorter/STORE/ASRS-like/cross-dock candidates produced 0 authoritative shipment gain in the measured mature scenario.
- PR #42 receiving-orchestration scout measured:
  - Fast Pick + Annex: holding 0 = 205 shipments with 6 lost arrivals; holding 6 = 211 shipments, 0 lost, +6 shipments / +¥3,000 / +2.9%; >6 holding capacity unused.
  - High Density + Annex: already 0 arrival loss and 211 shipments; holding capacity produced no output gain.
  - Therefore a universal gate-staging / receiving-orchestration upgrade is not justified.
- PR #43 fixed the canonical Rank 3 gate so contracts are optional:
  - all 3 Rank 2 zones chosen;
  - equipment assets >= ¥200,000;
  - live throughput >= 6 shipments/minute.
  - authoritative equipment asset value is calculated from owned workers/upgrades/Forklift/Rank 2 facilities (+ Annex if owned).
  - smoke test proves promotion with `completed_contracts == 0`.

## Confirmed current bug / inconsistency

`godot/ui/game_hud_rank3.gd` is stale relative to PR #43. In late Rank 2 it still renders:
`RANK 3 解禁条件 ... 契約 x/8 ...`
using `contracts` / `contracts_required` keys that no longer exist in `rank3_readiness()`.
Because `.get()` defaults are used, CI did not fail and the UI can misleadingly show `契約 0/8` even though contracts are now optional.

This must be corrected before calling Rank 3 progression UX coherent. Desired UI is structural zones + equipment assets + throughput, not mandatory contracts.

## Current work branch — exact incomplete state

Branch: `feature/rank3-carrier-routing-domain`

Goal: begin the title-specific Rank 3 **Carrier Routing Layer** from `RANK3_FULFILLMENT_CENTER.md`:
- Balanced Parcel;
- Express Dispatch;
- Consolidated Linehaul;
- real dispatch/economy tradeoffs;
- route changes measured with shipments/min, packed queue, open orders, revenue/min;
- later add management UI + event-driven Routing Hub/gates in 3D.

Only one code change is currently committed on this branch before this handoff:
`godot/domain/flow_measurement.gd` at commit `e63d312149f31a7d4c95d8564755c27f1b712f94`.

That change adds an optional `orders` argument to `record_state()` and adds `open_orders` to Before/After metrics/deltas.

IMPORTANT: this is **not complete**. Existing `WarehouseSim.step()` still calls `record_state(...)` without passing `open_orders`, so the new metric currently samples the default `0`. It is not yet valid for Carrier Routing measurement. The branch has not been CI-validated and must not be merged in this state.

An attempted follow-up design to add a separate `record_orders()` sample path was started in-chat but was interrupted before the GitHub write completed. Repository verification shows branch head is still `e63d312...`; therefore that attempted follow-up is **not present** in GitHub and must not be assumed.

No Carrier Routing Domain state, routing mode, dispatch gating, revenue multiplier, save schema update, routing UI, Routing Hub view, tests, PR or Preview deployment has been implemented yet.

## Rank 3 design target / reason

`RANK3_FULFILLMENT_CENTER.md` defines the next operating layer as Carrier Routing rather than another generic speed upgrade. The intended tradeoff is:
- Balanced Parcel: neutral reference.
- Express Dispatch: faster outbound clearance, lower margin.
- Consolidated Linehaul: batched dispatch, higher margin, more packed-WIP risk.

Reason: prior scouts repeatedly showed that blindly speeding internal PICK/STORE/SHIP stages often moves WIP without increasing authoritative shipment/revenue output. Routing introduces a new decision surface after packing where throughput, queueing and margin can trade off instead of adding another cosmetic equipment tier.

Receiving Annex remains implemented code and should not be deleted merely to match the newer routing target; actual code is canonical until a deliberate migration changes it.

## UI / visual decisions locked from device verification

- Portrait mobile-first; 3D warehouse remains the hero.
- Dark navy industrial palette, cyan tech accent, amber/orange safety/logistics accent.
- Warehouse uses an open-top/cutaway presentation; roof/truss occlusion was removed after real-device feedback.
- Camera touch orbit sensitivity/smoothing and max zoom-out were tuned and accepted on iPhone.
- Left foreground wall occlusion was removed for overview readability.
- Embedded `MPLUS1p-Regular.ttf` is the cross-platform Japanese UI font; do not return to SystemFont for Web/Android portability.
- Management UI should not cover the warehouse unnecessarily; avoid new permanent top-level HUD clusters.
- `出荷 +¥500` toast was compacted and management overlay collisions addressed.
- Routing selection, when implemented, belongs in existing management UI with one compact current-route summary.

## Rejected / avoid

- Do not return production gameplay to legacy Three.js `/docs`.
- Do not make manual forklift driving / parcel carrying the core loop.
- Do not let UI or 3D code generate revenue or mutate authoritative economy.
- Do not fake automation with decorative motion disconnected from Domain events.
- Do not add AGV/AMR, sorter, ASRS/retrieval or cross-dock merely because they are thematic; measured mature scenarios produced zero end-to-end gain before/after Annex.
- Do not add a universal receiving-holding upgrade based on PR #42; High Density did not need it and Fast Pick gain was only 2.9%.
- Do not restore mandatory contracts to Rank 3; PR #43 explicitly removed that stale gate.
- Do not add `visual_pass_4/5/...` as patch layers instead of clarifying responsibilities.
- Do not call fixes complete without build/test/runtime verification and, for mobile UX, real-device confirmation.

## External services / data

- No production DB.
- No backend API.
- No auth/account system.
- No cloud save.
- No analytics/crash reporting currently wired.
- No IAP/store integration.
- No required environment variables or secrets for current game runtime.
- GitHub Actions + GitHub Pages are used for CI and Engineering Preview deployment.

## Build / test / deploy

CI uses Godot 4.7.2 and currently runs:
- `godot --headless --path godot --editor --quit`
- domain simulation smoke;
- economy pacing;
- Rank 2 readiness/entry/facility/zone/frontier tests;
- workload wave tests;
- Rank 3 readiness/intervention/intake/Receiving Annex/post-Annex/receiving-orchestration tests;
- Rank 2/3 UI and visual smoke;
- Japanese font smoke;
- warehouse readability smoke;
- full-scene headless runtime;
- Web Engineering Preview export;
- preview artifact upload.

Preview URL remains:
`https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`

Web is Engineering Preview only; final target remains native iOS/Android.

## Immediate next task

1. Re-read GitHub `main` and `feature/rank3-carrier-routing-domain` before writing code; do not trust chat state blindly.
2. Fix `godot/ui/game_hud_rank3.gd` so Rank 3 readiness shows `拡張ゾーン / 設備資産 / 出荷ペース` and no mandatory contract count. Extend `rank3_ui_smoke.gd` to assert that contract gating text is absent and asset threshold text/progress is present.
3. Repair the partial open-orders measurement work. Preferred minimal path: keep `FlowMeasurement.record_state(...)` backward-compatible or add a dedicated order sample API, but ensure `WarehouseSim.step()` actually records authoritative `open_orders`. Add a deterministic smoke assertion that open-order Before/After is non-zero when a seeded backlog exists.
4. Only after the above is green, implement Carrier Routing in `rank3_warehouse_sim.gd` with a new save schema (expected v6 unless a better migration design is justified): route mode state, switching API, authoritative SHIP gating/cadence/value, no duplicate shipment revenue, and route-change measurement.
5. Add deterministic tests proving all three route modes produce materially different outcomes and at least one throughput-vs-margin / queue tradeoff. Tune multipliers from measured results, not aesthetics.
6. Then add routing controls to `game_hud_rank3.gd` and an event-driven Routing Hub/gates view near outbound; wire through `main.gd` only after Domain tests are stable.
7. Run full CI → open PR for the feature branch → merge only when green → verify post-merge CI/Pages → perform iPhone verification before declaring Rank 3 routing visually complete.

Likely files for the immediate task:
- `godot/ui/game_hud_rank3.gd`
- `godot/tests/rank3_ui_smoke.gd`
- `godot/domain/flow_measurement.gd`
- `godot/domain/warehouse_sim.gd`
- later `godot/domain/rank3_warehouse_sim.gd`
- later new focused routing view/test files plus `godot/main.gd`
- `.github/workflows/godot-ci.yml` when new routing tests are added.

Completion criteria for the next implementation slice:
- Rank 3 readiness UI exactly matches optional-contract gate.
- Open-order measurement uses authoritative values, not defaults.
- Parse/domain/UI tests pass.
- Carrier routing Domain has three saved modes with real dispatch/revenue behavior.
- Route switching cannot duplicate shipments/revenue.
- All three modes show measured, meaningfully different consequences.
- Existing Rank 1/2/Receiving Annex regressions stay green.
- Full-scene runtime and Web export pass.
- UI/3D routing polish is not called complete until iPhone Preview is checked.
