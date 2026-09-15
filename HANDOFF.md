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

Project-wide rules follow `GAME_DEV_MASTER_RULES`; title-specific locked GDD/specifications override general rules.

## Core product loop

`物流を観察 → ボトルネック発見 → 投資 / 運用判断 → 作業員・設備が自律反応 → 出荷量 / 収益 / 詰まりが変化 → 結果測定 → より大きな再投資`

The player is the logistics-center owner / operations manager. Manual box carrying or forklift driving is not the core loop.

Every major investment must satisfy all four:
1. visible 3D change;
2. real logistics behavior change;
3. measurable Before / After;
4. potential to move the bottleneck downstream.

## Current production architecture

- `godot/main.gd` — composition root / save wiring; canonical runtime currently uses workload-aware Rank 2 simulation and HUD
- `godot/domain/warehouse_sim.gd` — authoritative base economy, parcel flow, tasks, progression and Rank 2 structural effects
- `godot/domain/workload_warehouse_sim.gd` — Rank 2 workload-wave extension, schema-v4 state and source-cadence modifiers
- `godot/domain/workload_wave_model.gd` — deterministic forecast / peak cycle definition
- `godot/domain/capital_catalog.gd` — Rank 1 investment catalog / costs / limits
- `godot/domain/flow_measurement.gd` — 25-second Before / After measurement
- `godot/domain/progression_system.gd` — deterministic contracts and Rank 2 staffing definitions
- `godot/domain/rank2_facility_catalog.gd` — six Rank 2 zone choices / costs / player-facing effect copy
- `godot/view/warehouse_view.gd` — base 3D warehouse / workers / parcels / touch camera
- `godot/view/forklift_automation_view.gd` — event-driven forklift visual
- `godot/view/rank2_facility_view.gd` — visible 3D structures for all six Rank 2 facility choices
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — current presentation layers; do not add pass files casually
- `godot/ui/game_hud_ja.gd` — Japanese mobile HUD / contracts / staffing / expansion zones
- `godot/ui/game_hud_waves.gd` — Rank 2 workload forecast / peak banner and dispatch-window progress
- `godot/persistence/save_store.gd` — local JSON save / backup

Economy mutation belongs to the Domain. UI and 3D presentation must never create shipment revenue.

## Current Rank 1 simulation baseline

- Start cash: ¥5,000
- Workers: 3
- Rack capacity: 8
- Inbound interval: 2.8s
- Order interval: 3.0s
- Base shipment value: ¥500
- RP: +1 every 5 real shipments
- Packing base duration: 3.0s
- Worker investment first cost: ¥3,500
- Rack: ¥2,500
- Worker speed: ¥4,000
- Packing: ¥4,500
- Forklift Automation: ¥20,000 one-time

Measured baseline:
- 5 minutes no investment: 79 shipments = 15.8/min
- ending dominant bottleneck: inbound
- Forklift affordability when saving: about 119 simulated seconds / 30 shipments

Representative 120s upgrade comparison after warm-up:
- Worker: 31→41 shipments; bottleneck moves toward packing
- Speed: 31→36
- Forklift: 31→39; inbound queue materially drops; bottleneck moves toward packing
- Rack: reduces inbound pressure but does not guarantee more shipments
- Packing while inbound is dominant: no shipment gain

Intended early causal chain:
`inbound pressure → Forklift → packing pressure → Packing improvement → stable flow`

## Rank 1 → Rank 2 progression

Progression spine:
`contract → cash / RP / Logistics Rating → facility rank → structural decisions`

Rank 1:
- three deterministic contract choices;
- one active contract at a time;
- completion awards cash, RP and +2 Logistics Rating;
- Logistics Rating 8 promotes Small Depot → Rank 2 Warehouse;
- four successful contracts are sufficient for the Rank 2 gate.

Current contracts:
- `速配 8件` — 8 real shipments within 75s; reward ¥2,500 / +1 RP / Rating +2
- `搬入口クリーン` — inbound ≤6 for 24s within 90s; reward ¥2,200 / +1 RP / Rating +2
- `高効率運転` — ≥12 shipments/min for 20s within 90s; reward ¥2,600 / +1 RP / Rating +2

Rank 2 Warehouse entry:
- base crew becomes at least 5 workers;
- Rank 1 BALANCE / INBOUND / SHIP policy buttons disappear;
- staffing becomes role-based with a 30-second reassignment lock;
- presets: Receiving 3/1/1, Balanced 2/2/1, Picking 1/3/1, Dock 2/1/2, Shipping 1/2/2;
- workers only accept tasks matching their assigned Rank 2 role;
- repeatable Worker / Rack / Speed / Packing cards are hidden at Rank 2; already-purchased legacy effects remain active;
- Forklift remains available if not already purchased.

## Rank 2 structural layer

Three mutually-exclusive one-of-two expansion zones are implemented as real Domain choices, mobile management actions, save state and visible 3D structures.

### Zone A — Intake
- Double Dock — ¥12,000; inbound capacity +6; arrival interval ×0.78.
- Buffer Yard — ¥10,000; inbound capacity +14; arrival cadence unchanged.

### Zone B — Storage
- Fast Pick Rack — ¥13,000; storage +4; PICK duration ×0.75.
- High Density Rack — ¥12,000; storage +12; PICK duration ×1.14.

### Zone C — Packing
- Parallel Pack Line — ¥14,000; two simultaneous packing jobs; each job ×1.10 duration.
- Fast Pack Cell — ¥13,000; one job at a time; job duration ×0.58.

Each zone locks after one choice. Each structural purchase starts the 25-second Before / After flow measurement.
Rank 2 base demand uses a 2.2s order interval before workload-wave modifiers.

## Rank 2 structural measurements

`godot/tests/rank2_zone_pacing_report.gd` verifies each structural option for 180 simulated seconds.
Representative measured results before workload waves:
- Double Dock / Buffer Yard: 16.7 shipments/min under intake-stressed context; dominant inbound.
- Fast Pick Rack / High Density Rack: 19.7/min; bottleneck moves to packing.
- Parallel Pack / Fast Pack Cell: 19.7/min; bottleneck moves to outbound.

`godot/tests/rank2_post_zone_frontier.gd` measures all 8 completed facility combinations × all 5 staffing presets (40 scenarios).
Steady-state result before workload waves:
- Shipping 1/2/2 won 8 / 8 completed combinations;
- fastest build: Double Dock + Fast Pick Rack + Fast Pack Cell = 29.5 shipments/min;
- High Density builds retained order/PICK pressure.

That dominant-strategy result is why AGV was deliberately postponed and workload variation was implemented first.

## Rank 2 workload-wave layer

Implemented in `WorkloadWaveModel` / `WorkloadWarehouseSim`.
The system is deterministic and forecastable, not random punishment.

Cycle:
1. 35s inbound forecast
2. 50s inbound surge
3. 35s order forecast
4. 50s order surge
5. 35s dispatch forecast
6. 50s dispatch window

Operational intent:
- inbound surge batches new arrivals and reduces simultaneous order pressure;
- order surge batches demand and eases inbound arrivals;
- dispatch phase suppresses new flow enough to make staged outbound work meaningful;
- the 35-second warnings are longer than the 30-second staffing reassignment lock, so the player can act before the peak rather than react after it.

The mobile HUD shows current phase, current/next workload, remaining time and dispatch-window shipment progress.

### Measured staffing niches

`godot/tests/workload_wave_pacing_report.gd` validates both flow-oriented and capacity-oriented facility profiles plus a low-stock replenishment case.
All five Rank 2 presets have at least one measured niche:
- Receiving — wins dedicated low-stock replenishment / heavy inbound context;
- Balanced — wins representative inbound-surge queue control;
- Picking — wins order-surge backlog control;
- Dock — wins one flow-profile dispatch context through end-state clearance tie-breaking;
- Shipping — wins the capacity-profile dispatch window.

Measured replenishment case (12s, empty rack / heavy inbound / no orders):
- Receiving: avg inbound 13.85, ending inbound 14, rack stock 10;
- Balanced: avg 16.15, ending 18, rack 7;
- Picking / Shipping: avg 18.45, ending 22, rack 4.

### Full-cycle strategy comparison

Two full workload cycles = 510 simulated seconds, representative flow facility profile:
- forecast-driven adaptive staffing: **198 shipments / ¥99,000**;
- fixed Shipping: **195 / ¥97,500**;
- fixed Balanced: **169 / ¥84,500**.

Adaptive strategy switches at forecasts using the real 30s staffing lock and clears staged packed work to zero by the end of dispatch.
This is the acceptance criterion that matters: the workload system removes “always Shipping” as the sole economic answer while preserving authoritative real shipments and revenue.

Do not use an equal-weight sum of all queues as the only optimization target. Packed, ready-to-ship WIP intentionally accumulated ahead of dispatch is different from harmful inbound/order backlog. Validate cycle output, revenue, backlog location and end-of-window clearance together.

## Save / QA state

- Save schema: v4
- schema 1/2/3 saves migrate forward; legacy Rank 2 saves enter a safe forecast window rather than a surprise peak
- workload clock / phase survives schema-v4 save/load
- Rank 2 rank, contracts, staffing and all six facility choices persist
- storage-capacity facility effects are not double-applied on reload

CI gates include:
- parse/import
- domain simulation smoke
- economy pacing report
- Rank 2 readiness scout
- Rank 2 entry smoke
- Rank 2 facility smoke
- Rank 2 zone pacing report
- Rank 2 post-zone operating frontier
- Rank 2 workload-wave smoke
- Rank 2 workload-wave pacing report
- Rank 2 facility UI smoke
- Rank 2 facility visual smoke
- Japanese font glyph smoke
- warehouse visual readability smoke
- full-scene runtime smoke
- Web Engineering Preview export / artifact

PR #37 branch CI is green through all gates including runtime and Web export.

## Real-device findings

Previously verified on iPhone Web Preview:
- embedded Japanese font fixes Web glyph corruption;
- touch orbit sensitivity and camera smoothing are acceptable;
- pinch zoom is stable;
- warehouse cutaway / max zoom-out readability is acceptable;
- management scrollbar and overlay collisions were addressed.

Still requiring fresh iPhone Preview verification after workload-wave publication:
- workload forecast / peak banner readability and hierarchy;
- Rank 2 zone UI and six 3D facility structures in the latest combined build.

Web Preview verification is not native iOS / Android certification.

## Rank 3 boundary

Rank 3 remains a readiness gate until real Fulfillment Center gameplay exists. Never claim Rank 3 complete from a gate alone.

Current readiness intent:
- all 3 Rank 2 zones selected;
- 8 completed contracts;
- at least 6 shipments/minute.

## Next exact task

1. Merge and publish the green Rank 2 workload-wave build, then visually verify the workload banner / Rank 2 structural UI on iPhone Preview when device feedback is available.
2. Define the real Rank 3 / Fulfillment Center vertical slice from measured late-Rank-2 pressure, not feature-count ambition.
3. Re-measure High Density/PICK pressure under the workload-wave model and decide whether AGV belongs in that slice as a genuine counterplay tool.
4. Rank 3 must add a new operational decision / growth step and visible facility evolution; do not ship a readiness badge as fake progression.
5. After the Rank 3 slice is functional, proceed to FTUE / retention / presentation / audio-haptics / analytics / performance / QA passes before any release-candidate claim.
