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

- `godot/main.gd` — composition root / save wiring
- `godot/domain/warehouse_sim.gd` — authoritative economy, parcel flow, tasks, progression and Rank 2 structural effects
- `godot/domain/capital_catalog.gd` — Rank 1 investment catalog / costs / limits
- `godot/domain/flow_measurement.gd` — 25-second Before / After measurement
- `godot/domain/progression_system.gd` — deterministic contracts and Rank 2 staffing definitions
- `godot/domain/rank2_facility_catalog.gd` — six Rank 2 zone choices / costs / player-facing effect copy
- `godot/view/warehouse_view.gd` — base 3D warehouse / workers / parcels / touch camera
- `godot/view/forklift_automation_view.gd` — event-driven forklift visual
- `godot/view/rank2_facility_view.gd` — visible 3D structures for all six Rank 2 facility choices
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — current presentation layers; do not add pass files casually
- `godot/ui/game_hud_ja.gd` — canonical Japanese mobile HUD / contracts / staffing / expansion zones
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

Progression spine is implemented in canonical Godot:

`contract → cash / RP / Logistics Rating → facility rank → structural decisions`

Rank 1:
- three deterministic contract choices are exposed in management;
- only one contract can be active;
- contract completion awards cash, RP and +2 Logistics Rating;
- Logistics Rating 8 promotes Small Depot → Rank 2 Warehouse;
- four successful contracts are sufficient for the Rank 2 gate.

Current contract set:
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
- Double Dock — cost ¥12,000; inbound capacity +6; arrival interval ×0.78 (about 22% faster). Higher potential intake but can overload downstream.
- Buffer Yard — cost ¥10,000; inbound capacity +14; arrival cadence unchanged. Stronger surge absorption without creating extra source pressure.

### Zone B — Storage
- Fast Pick Rack — cost ¥13,000; storage +4; PICK task duration ×0.75.
- High Density Rack — cost ¥12,000; storage +12; PICK task duration ×1.14.

### Zone C — Packing
- Parallel Pack Line — cost ¥14,000; two simultaneous packing jobs; each job ×1.10 duration.
- Fast Pack Cell — cost ¥13,000; one job at a time; job duration ×0.58.

Each zone locks after one choice. Progress is shown as `拡張ゾーン x / 3`, not `MAX`.
Each structural purchase starts the same 25-second Before / After flow measurement used by capital upgrades.

Rank 2 demand context is intentionally higher than Rank 1: order interval 2.2s. This prevents the mature Rank 1 ~20/min demand ceiling from making structural investments meaningless.

## Rank 2 deterministic measurements

`godot/tests/rank2_zone_pacing_report.gd` runs every facility choice for 180 simulated seconds.

Current measured results from the green PR gate:
- Double Dock: 50 shipments / 16.7 per min; avg inbound 17.46; capacity 20; dominant inbound.
- Buffer Yard: 50 / 16.7; avg inbound 15.80; capacity 28; dominant inbound.
- Fast Pick Rack: 59 / 19.7; avg packing queue 12.65; capacity 12; dominant packing.
- High Density Rack: 59 / 19.7; avg packing queue 11.77; capacity 20; dominant packing.
- Parallel Pack Line: 59 / 19.7; avg outbound queue 16.04; 2 concurrent packs; dominant outbound.
- Fast Pack Cell: 59 / 19.7; avg outbound queue 16.47; single fast pack; dominant outbound.

Interpretation:
- the six facilities all preserve real flow and visibly change system state;
- Intake choices primarily trade source rate against surge capacity;
- Storage choices trade pick speed against inventory capacity;
- Packing choices trade concurrency against per-box latency;
- in the current stressed scenarios, several pairs intentionally converge on the same shipment rate because the bottleneck moves to another stage. The Director must expose that downstream bottleneck rather than pretending every purchase directly raises revenue.

Do not tune choices solely to force different shipment counts. Preserve meaningful trade-offs and verify them in context-specific scenarios.

## Save / QA state

- Save schema: v3
- v1 and v2 migrate safely to v3
- Rank 2 rank, contracts, staffing and all six facility choices persist
- storage-capacity facility effects are not double-applied on reload

CI gates now include:
- parse/import
- domain simulation smoke
- economy pacing report
- Rank 2 readiness scout
- Rank 2 entry smoke
- Rank 2 facility smoke
- Rank 2 zone pacing report
- Rank 2 facility UI smoke
- Rank 2 facility visual smoke
- Japanese font glyph smoke
- warehouse visual readability smoke
- full-scene runtime smoke
- Web Engineering Preview export

## Real-device findings already addressed

Verified on iPhone Web Preview:
- embedded Japanese font fixes Web glyph corruption;
- touch orbit sensitivity and camera smoothing are acceptable;
- pinch zoom is stable;
- roof trusses / roof lights / overhead utility bars no longer obscure the warehouse;
- foreground left wall no longer blocks the cutaway view;
- MAX zoom-out provides a readable warehouse overview;
- management horizontal scrollbar removed;
- shipment / measurement overlays no longer cover investment cards.

The new Rank 2 zone UI and six new 3D structures still require fresh iPhone visual verification after Preview publication. Web Preview verification is not native iOS / Android certification.

## Rank 3 boundary

Rank 3 remains a readiness gate only until real Fulfillment Center gameplay exists. Never claim Rank 3 complete from a gate alone.

Current readiness intent:
- all 3 Rank 2 zones selected;
- 8 completed contracts;
- at least 6 shipments/minute.

## Next exact task

After the Rank 2 structural PR is green and merged:
1. verify the new Rank 2 management section and all six facility structures on iPhone Web Preview;
2. add context-specific trade-off tests proving when each side of a zone is strategically valid, not merely different on paper;
3. measure the post-3-zone bottleneck and decide the next system from evidence;
4. do not add AGV automatically: current packing scenarios already push the bottleneck to outbound, so AGV must earn its place through measured value;
5. only then define the real Rank 3 / Fulfillment Center vertical slice.
