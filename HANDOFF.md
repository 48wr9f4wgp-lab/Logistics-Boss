# LOGISTICS BOSS — Development Handoff

Updated: 2026-09-15 JST

## Canonical product

- Repository: `48wr9f4wgp-lab/Logistics-Boss`
- Canonical branch: `main`
- Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
- Portrait reference: 390×844
- Final targets: native iOS / Android
- Godot Web export: Engineering Preview only
- Preview: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`
- `/docs/**` Three.js implementation is legacy reference only. Do not add production gameplay there.
- Project-wide rules follow `GAME_DEV_MASTER_RULES`; game-specific locked specifications override general rules.

## Core product loop

`物流を観察 → ボトルネック発見 → 投資 / 運用判断 → 作業員・設備が自律反応 → 出荷量 / 収益 / 詰まりが変化 → 結果測定 → より大きな再投資`

The player is the logistics-center owner / operations manager. Manual carrying or forklift driving is not the core loop.

Every major investment must create:
1. visible 3D change;
2. real logistics behavior change;
3. measurable Before / After;
4. potential to move the bottleneck downstream.

Economy mutation belongs to Domain. UI / 3D presentation must never invent shipment revenue.

## Current architecture

- `godot/main.gd` — composition root / save wiring; runtime uses workload-aware Rank 2 simulation and HUD.
- `godot/domain/warehouse_sim.gd` — authoritative Rank 1/2 economy, parcel flow, workers, contracts, structural effects.
- `godot/domain/workload_warehouse_sim.gd` — workload-wave extension and schema-v4 state.
- `godot/domain/workload_wave_model.gd` — deterministic forecast / peak cycle.
- `godot/domain/capital_catalog.gd` — Rank 1 investments.
- `godot/domain/flow_measurement.gd` — 25-second Before / After measurement.
- `godot/domain/progression_system.gd` — contracts and Rank 2 staffing.
- `godot/domain/rank2_facility_catalog.gd` — six Rank 2 structural choices.
- `godot/view/warehouse_view.gd` — base 3D warehouse / workers / parcels / touch camera.
- `godot/view/forklift_automation_view.gd` — event-driven forklift visual.
- `godot/view/rank2_facility_view.gd` — visible Rank 2 structures.
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — presentation layers; do not add pass files casually.
- `godot/ui/game_hud_ja.gd` — canonical Japanese mobile HUD.
- `godot/ui/game_hud_waves.gd` — workload forecast / peak UI.
- `godot/persistence/save_store.gd` — local JSON save / backup.

## Rank 1 baseline

- Start cash ¥5,000; 3 workers; rack 8.
- Inbound 2.8s; orders 3.0s; packing 3.0s.
- Shipment ¥500; RP +1 every 5 real shipments.
- Worker ¥3,500; Rack ¥2,500; Speed ¥4,000; Packing ¥4,500; Forklift ¥20,000.
- 5m no-investment baseline: 79 shipments = 15.8/min; dominant inbound.
- Forklift affordability when saving: about 119 simulated seconds / 30 shipments.
- Representative 120s effect: Worker 31→41, Speed 31→36, Forklift 31→39. Forklift moves pressure from inbound toward packing.

Intended early causal chain:
`inbound pressure → Forklift → packing pressure → Packing improvement → stable flow`

## Rank 1 → Rank 2 progression

Progression spine:
`contract → cash / RP / Logistics Rating → facility rank → structural decisions`

- Three deterministic contract offers; one active contract.
- Completion gives cash, RP and +2 Logistics Rating.
- Logistics Rating 8 promotes Small Depot → Rank 2 Warehouse.
- Four successful contracts are sufficient for the Rank 2 gate.

Rank 2 entry:
- crew minimum 5;
- Rank 1 BALANCE / INBOUND / SHIP buttons disappear;
- role staffing with 30s reassignment lock;
- Receiving 3/1/1, Balanced 2/2/1, Picking 1/3/1, Dock 2/1/2, Shipping 1/2/2;
- repeatable Worker / Rack / Speed / Packing cards hidden at Rank 2; legacy effects remain;
- Forklift remains purchasable if not already owned.

## Rank 2 structural layer

Three mutually-exclusive one-of-two zones are real Domain choices, saved state, mobile actions and visible 3D structures.

### Intake
- Double Dock — ¥12,000; inbound capacity +6; arrival interval ×0.78.
- Buffer Yard — ¥10,000; inbound capacity +14.

### Storage
- Fast Pick Rack — ¥13,000; storage +4; PICK ×0.75.
- High Density Rack — ¥12,000; storage +12; PICK ×1.14.

### Packing
- Parallel Pack Line — ¥14,000; two simultaneous jobs; each ×1.10 duration.
- Fast Pack Cell — ¥13,000; one job; duration ×0.58.

Each purchase starts the Before / After measurement. Rank 2 base order interval is 2.2s before workload modifiers.

## Rank 2 workload waves

Cycle is deterministic and forecastable:
1. 35s inbound forecast
2. 50s inbound surge
3. 35s order forecast
4. 50s order surge
5. 35s dispatch forecast
6. 50s dispatch window

The 35s warning exceeds the 30s staffing lock, so good play is proactive.

Measured full-cycle strategy over 510 simulated seconds:
- adaptive forecast-driven staffing: 198 shipments / ¥99,000;
- fixed Shipping: 195 / ¥97,500;
- fixed Balanced: 169 / ¥84,500.

All five staffing presets have at least one measured niche. “Always Shipping” is no longer the sole economic answer.

## Rank 3 scouting — completed measurement

Rank 3 is **not implemented in production yet**. Current code only has readiness/scouting tests. Never claim Rank 3 complete from these tests.

### Storage-path readiness

Under the mature workload cycle, with Buffer Yard + Fast Pack Cell and adaptive staffing:

Fast Pick Rack:
- 191 shipments / ¥95,500 / 22.5/min
- avg orders 9.77
- PICK starts 185
- pick-starved 268.3s

High Density Rack:
- 199 shipments / ¥99,500 / 23.4/min
- avg orders 8.49
- PICK starts 193
- pick-starved 168.4s

High Density wins by +8 shipments / +¥4,000. It does not need AGV as a rescue patch.

### Internal intervention scout

Test-only sensitivity candidates were measured on both storage branches:
- PICK -15%
- PICK -30% / AMR-style travel reduction
- independent rack→pack retrieval every 4.5s
- SHIP -15%
- SHIP -30% / sorter-style acceleration
- STORE -30%
- combined STORE + PICK -30%
- real inbound+order cross-dock bypass to packing every 4.5s

Result: **all produced 0 authoritative shipment delta and 0 revenue delta** in the 510s mature scenario. They move queue/WIP shape but do not raise end-to-end throughput. Cross-dock is therefore not selected as the first Rank 3 module.

### Intake growth scout

The decisive measured constraint is peak inbound acceptance. `WarehouseSim._spawn_flow()` only accepts an arrival when the inbound queue is below the current limit; mature Buffer Yard scenarios hit that cap.

Test-only Receiving Annex sensitivity: +14 inbound capacity.

Fast Pick:
- control: 169 accepted inbound / 191 shipments / ¥95,500 / 22.5/min / avg orders 9.77
- Annex: 183 accepted inbound / 205 shipments / ¥102,500 / 24.1/min / avg orders 7.78
- delta: **+14 real shipments / +¥7,000**

High Density:
- control: 177 accepted inbound / 199 shipments / ¥99,500 / 23.4/min / avg orders 8.49 / ending orders 18
- Annex: 189 accepted inbound / 211 shipments / ¥105,500 / 24.8/min / avg orders 5.71 / ending orders 9
- delta: **+12 real shipments / +¥6,000**

Annex + cross-dock gives no shipment gain beyond Annex alone and worsens the High Density end-state backlog.

### Rank 3 product decision

**Receiving Annex / Overflow Intake Expansion is selected as the first production Rank 3 vertical-slice candidate.**

Why:
- first tested intervention that raises authoritative shipments and revenue on both storage branches;
- captures peak arrivals that were previously not accepted;
- preserves the prior storage decision: High Density remains ahead after Annex (211 vs 205 shipments);
- creates a visible facility-growth opportunity suitable for Warehouse → Fulfillment Center;
- added volume can create a later downstream bottleneck, giving AGV / sorter / ASRS a measured reason to exist instead of feature-count ambition.

The test value **+14 capacity is not final production balance**. Cost and capacity must be tuned from affordability / pacing measurements before lock.

## Save / QA state

- Production save schema: v4.
- schema 1/2/3 migrate forward.
- workload clock / phase survives save/load.
- Rank 2 rank, contracts, staffing and all six facility choices persist.
- storage-capacity effects are not double-applied on reload.

CI now gates:
- parse/import
- Domain simulation smoke
- economy pacing
- Rank 2 readiness / entry / facility / zone / frontier tests
- workload-wave smoke and pacing
- Rank 3 readiness scout
- Rank 3 intervention scout
- Rank 3 intake-growth scout
- Rank 2 UI / visual smoke
- Japanese font glyph smoke
- visual readability
- full-scene runtime
- Web Engineering Preview export / artifact

PR #39 branch CI is green through all gates, including the two new Rank 3 scouts, runtime and Web export.

## Real-device state

Previously verified on iPhone Web Preview:
- embedded Japanese font fixes glyph corruption;
- touch orbit sensitivity and smoothing acceptable;
- pinch stable;
- warehouse cutaway / max zoom-out readable;
- management scrollbar / overlay collisions addressed.

Still worth fresh iPhone verification on the latest combined production build:
- workload forecast / peak banner hierarchy;
- Rank 2 zone UI and six 3D structures.

Web Preview verification is not native iOS / Android certification.

## Rank 3 boundary and readiness intent

Rank 3 production still needs a real domain state, save migration, gameplay effect, UI and visible facility growth.

Current readiness intent:
- all 3 Rank 2 zones selected;
- 8 completed contracts;
- at least 6 shipments/minute.

## Next exact task

1. Merge PR #39 measurement infrastructure after green CI.
2. Implement a real Rank 3 / Fulfillment Center foundation without overloading `warehouse_sim.gd`; prefer a focused layer extending `WorkloadWarehouseSim` if clean.
3. Add save schema v5 migration and real Rank 3 promotion state; do not fake progression with a badge.
4. Implement Receiving Annex as an authoritative Rank 3 structural purchase/effect, with cost/capacity tuned by pacing rather than blindly locking the +14 scout value.
5. Add visible 3D Annex growth, Japanese mobile management UI and Before / After feedback. Do not add `visual_pass_4` just to place it.
6. Verify build → automated tests → full runtime → Web export → iPhone Preview. Only then treat the Rank 3 vertical slice as functional.
7. Re-measure the new downstream bottleneck before deciding whether AGV, sorter, ASRS or another automation is next.
