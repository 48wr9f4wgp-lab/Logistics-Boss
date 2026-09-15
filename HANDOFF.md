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

- `godot/main.gd` — composition root / save wiring; current Rank 3 branch runtime uses `Rank3WarehouseSim` and `Rank3GameHud`.
- `godot/domain/warehouse_sim.gd` — authoritative Rank 1/2 economy, parcel flow, workers, contracts, structural effects.
- `godot/domain/workload_warehouse_sim.gd` — Rank 2 workload-wave extension and schema-v4 state.
- `godot/domain/rank3_warehouse_sim.gd` — focused Rank 3 Fulfillment Center layer, schema-v5 migration, promotion gate and Receiving Annex state/effect.
- `godot/domain/workload_wave_model.gd` — deterministic forecast / peak cycle.
- `godot/domain/capital_catalog.gd` — Rank 1 investments.
- `godot/domain/flow_measurement.gd` — 25-second Before / After measurement.
- `godot/domain/progression_system.gd` — contracts and Rank 2 staffing.
- `godot/domain/rank2_facility_catalog.gd` — six Rank 2 structural choices.
- `godot/view/warehouse_view.gd` — base 3D warehouse / workers / parcels / touch camera.
- `godot/view/forklift_automation_view.gd` — event-driven forklift visual.
- `godot/view/rank2_facility_view.gd` — visible Rank 2 structures.
- `godot/view/rank3_receiving_annex_view.gd` — visible Fulfillment Center marker and purchased Receiving Annex expansion.
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — presentation layers; do not add pass files casually.
- `godot/ui/game_hud_ja.gd` — Japanese mobile HUD foundation.
- `godot/ui/game_hud_waves.gd` — workload forecast / peak UI.
- `godot/ui/game_hud_rank3.gd` — Rank 3 readiness and Receiving Annex management.
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

## Rank 3 scouting decision

PR #39 measured the mature late-Rank-2 workload before production Rank 3 implementation.

Internal-process sensitivity candidates — PICK assist, AMR-style PICK acceleration, autonomous rack→pack retrieval, SHIP acceleration/sorter, STORE acceleration, combined STORE+PICK acceleration and real cross-dock — all produced **0 authoritative shipment and revenue delta** in the mature 510s scenario. They moved WIP location but did not increase end-to-end output.

The decisive measured constraint was peak inbound acceptance. A +14 Receiving Annex sensitivity increased real accepted arrivals, shipments and revenue on both storage branches:
- Fast Pick: 191→205 shipments, +¥7,000.
- High Density: 199→211 shipments, +¥6,000.

Therefore **Receiving Annex / Overflow Intake Expansion** was selected as the first production Rank 3 step. AGV / sorter / ASRS / cross-dock remain deferred until post-Annex measurements create a real downstream constraint.

## Rank 3 Fulfillment Center vertical slice — implemented on PR #40 branch

Rank 3 is now a real gameplay layer on the feature branch; it is not a release-complete game or RC.

Promotion gate:
- all 3 Rank 2 expansion zones committed;
- 8 completed contracts;
- at least 6 recent shipments/minute.

When the live gate is satisfied, the Domain promotes Warehouse → **Rank 3 Fulfillment Center** and emits a real `rank_up` event. The promotion creates visible facility evolution; it is not a badge-only gate.

### Receiving Annex

Production implementation:
- player-facing name: `受入増設棟`;
- one-time Rank 3 structural investment;
- price: **¥24,000** for this vertical slice;
- authoritative effect: inbound acceptance capacity **+14**;
- purchase charges Domain money once;
- starts the standard 25s Before / After measurement;
- state persists in save schema v5;
- visible 3D receiving expansion appears only after ownership;
- Japanese management UI exposes readiness before Rank 3 and the purchase after promotion.

The ¥24,000 price is accepted for the current vertical slice, not permanently frozen against later economy balancing. At late-Rank-2 / Rank-3 flow the facility produces roughly ¥11k–¥12k gross shipment revenue per simulated minute, so the purchase is a short-term capital goal rather than a dead-end wait.

### Production pacing measurement

`godot/tests/rank3_receiving_annex_pacing_report.gd` runs the actual production `Rank3WarehouseSim` for 510 simulated seconds with forecast-driven staffing, Buffer Yard + Fast Pack Cell, and both storage branches.

Fast Pick Rack:
- control: 169 accepted inbound / 191 shipments / ¥95,500 / 22.5/min;
- Annex: 183 accepted inbound / 205 shipments / ¥102,500 / 24.1/min;
- delta: **+14 shipments / +¥7,000 / +7.3% throughput**;
- ending bottleneck: orders.

High Density Rack:
- control: 177 accepted inbound / 199 shipments / ¥99,500 / 23.4/min;
- Annex: 189 accepted inbound / 211 shipments / ¥105,500 / 24.8/min;
- delta: **+12 shipments / +¥6,000 / +6.0% throughput**;
- ending orders improve 18→9;
- ending bottleneck: orders.

Acceptance gate requires >5% throughput gain on both storage branches. Current implementation passes.

Important next-design implication: after Annex, the visible end-state pressure moves toward **orders / downstream processing**, so the next Rank 3 module must be selected from a fresh post-Annex frontier. Do not automatically add AGV merely because it is thematically attractive.

## Save / QA state

Current Rank 3 branch save schema: **v5**.
- schemas 1/2/3/4 migrate forward;
- schema-v4 Rank 2 saves do not invent Rank 3 or Annex ownership;
- Rank 3 facility rank persists;
- Receiving Annex ownership/effect persists;
- +14 capacity does not double-apply on reload;
- workload clock / phase survives the inherited schema-v4 layer.

PR #40 CI gates include and are green for:
- parse/import;
- Domain simulation smoke;
- economy pacing;
- Rank 2 readiness / entry / facility / zone / frontier;
- workload-wave smoke / pacing;
- Rank 3 readiness scout;
- Rank 3 intervention scout;
- Rank 3 intake-growth scout;
- Rank 3 Receiving Annex domain smoke;
- Rank 3 production pacing report;
- Rank 2 UI / visual regression;
- Rank 3 UI smoke;
- Rank 3 visual smoke;
- Japanese font glyph smoke;
- warehouse readability smoke;
- full-scene runtime;
- Web Engineering Preview export / artifact.

Green PR run: `34954021712` at branch head `59c1061a66a71955a5c733e3202a67100874f8be` before this handoff-only update.

## Real-device state

Previously verified on iPhone Web Preview:
- embedded Japanese font fixes glyph corruption;
- touch orbit sensitivity and smoothing acceptable;
- pinch stable;
- warehouse cutaway / max zoom-out readable;
- management scrollbar / overlay collisions addressed.

Still requires fresh iPhone Preview verification after PR #40 is merged/published:
- Rank 3 readiness panel hierarchy;
- Fulfillment Center promotion marker;
- Receiving Annex footprint/readability on portrait viewport;
- Annex purchase feedback / Before-After banner;
- existing workload banner and Rank 2 zone UI in the combined build.

Web Preview verification is not native iOS / Android certification.

## Next exact task

1. Re-run PR #40 CI after this handoff update; merge only if all gates remain green.
2. Publish the merged Web Engineering Preview and verify Rank 3 UI / Annex visually on iPhone. Do not call visual polish complete before device feedback.
3. Build a deterministic **post-Annex Rank 3 frontier** that measures where the new 6–7% volume gain accumulates under both storage branches and workload phases.
4. Select the next Rank 3 investment only from that measured pressure. Candidate families may include AMR/AGV, sorter, ASRS/retrieval or demand/dispatch improvements, but prior zero-delta scouts are not sufficient evidence after Annex changes the flow.
5. Keep each next investment tied to visible facility growth, real Domain behavior and Before / After measurement.
6. After the Rank 3 loop has at least one meaningful downstream follow-up decision, move toward FTUE / retention / presentation / audio-haptics / analytics / performance / QA passes before any release-candidate claim.
