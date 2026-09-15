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
- `godot/domain/warehouse_sim.gd` — authoritative economy, parcel flow, tasks, progression
- `godot/domain/capital_catalog.gd` — investment catalog / costs / limits
- `godot/domain/flow_measurement.gd` — 25-second Before / After measurement
- `godot/domain/progression_system.gd` — deterministic contracts and Rank 2 staffing definitions
- `godot/view/warehouse_view.gd` — base 3D warehouse / workers / parcels / touch camera
- `godot/view/forklift_automation_view.gd` — event-driven forklift visual
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` — current presentation layers; do not add pass files casually
- `godot/ui/game_hud_ja.gd` — canonical Japanese mobile HUD
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

Intended early causal chain is therefore:
`inbound pressure → Forklift → packing pressure → Packing improvement → stable flow`

## Rank 2 readiness measurement

`godot/tests/rank2_readiness_scout.gd` is the evidence gate for the next progression layer.

After Forklift + one Packing improvement, sustained 5-minute operation measured:
- 101 shipments = 20.2/min
- inbound dominant for 2969 / 3000 samples
- average inbound queue 11.07
- average packing queue 0.12
- average outbound queue 0.13
- average open orders 0.09
- average rack utilization 0.836
- worker busy ratio 0.885

Marginal 120s upgrades from that state:
- next Packing: 38→38
- Rack: 38→38, though inbound queue improves materially
- Speed: 38→39
- Worker: 38→38

Conclusion: the mature Rank 1 operation is effectively capped by the 3.0s order cadence (~20/min). Blindly adding another numeric upgrade or AGV would recreate a low-value purchase. The correct next step is structural progression / new operating context.

## Rank 1 → Rank 2 progression foundation

Current implementation on the Rank 2 entry feature branch establishes the locked GDD spine:

`contract → cash / RP / Logistics Rating → facility rank → structural decisions`

Rank 1:
- three deterministic contract choices are exposed in management;
- only one contract can be active;
- contract completion awards cash, RP and +2 Logistics Rating;
- Logistics Rating 8 promotes Small Depot → Rank 2 Warehouse;
- four successful contracts are therefore sufficient for the Rank 2 gate;
- contract progress, target and remaining time are visible in the mobile management sheet.

Current contract set:
- `速配 8件` — 8 real shipments within 75s; reward ¥2,500 / +1 RP / Rating +2
- `搬入口クリーン` — inbound ≤6 for 24s within 90s; reward ¥2,200 / +1 RP / Rating +2
- `高効率運転` — ≥12 shipments/min for 20s within 90s; reward ¥2,600 / +1 RP / Rating +2

These values are the current Godot tuning baseline and remain subject to measured pacing review.

Rank 2 Warehouse entry:
- base crew becomes at least 5 workers;
- Rank 1 BALANCE / INBOUND / SHIP policy buttons disappear because Rank 2 dispatch is role-based;
- staffing becomes a low-frequency structural decision;
- reassignment lock: 30 simulated seconds;
- presets:
  - Receiving: 3 / 1 / 1
  - Balanced: 2 / 2 / 1
  - Picking: 1 / 3 / 1
  - Dock: 2 / 1 / 2
  - Shipping: 1 / 2 / 2
- workers at Rank 2 only accept tasks matching their assigned role;
- repeatable Worker / Rack / Speed / Packing cards are hidden at Rank 2; legacy purchased effects remain supported;
- Forklift remains a distinct major automation purchase if it has not been bought.

## Locked Rank 2 structural layer — next implementation

Rank 2 is not a numeric upgrade screen. Implement three fixed one-of-two expansion zones with real simulation behavior and visible 3D changes:

### Zone A — Intake
- Double Dock: higher arrival throughput, more downstream pressure
- Buffer Yard: larger surge buffer, no arrival-rate gain

### Zone B — Storage
- Fast Pick Rack: less capacity, faster picks
- High Density Rack: more capacity, slower picks

### Zone C — Packing
- Parallel Pack Line: two concurrent packs, each somewhat slower
- Fast Pack Cell: one concurrent pack, substantially faster

Each zone is mutually exclusive. Rank 2 progress must read `Expansion Zones 0/3 → 3/3`, never `MAX`.

The Director remains prescriptive only for Rank 1 FTUE. At Rank 2 it diagnoses imbalance but must not provide a one-tap solution.

Rank 3 readiness is a gate only until true Fulfillment Center gameplay exists:
- all 3 Rank 2 zones selected;
- 8 completed contracts;
- at least 6 shipments/minute.

Do not claim Rank 3 gameplay complete merely because readiness is met.

## Save / QA state

- Save schema: v3
- v1 and v2 migrate safely to v3
- legacy saves default to Rank 1 / Rating 0 rather than inventing progression
- current cash, existing upgrades and Forklift state remain preserved during migration
- Rank 2 rank, contract counts and staffing state persist in v3

CI gates include:
- parse/import
- domain simulation smoke
- economy pacing report
- Rank 2 readiness scout
- Rank 2 entry smoke
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
- MAX zoom-out now provides a readable warehouse overview;
- management horizontal scrollbar removed;
- shipment / measurement overlays no longer cover investment cards.

This is Web Preview device verification, not native iOS / Android certification.

## Next exact task

After Rank 2 entry PR is green and merged:
1. implement Zone A / B / C domain choices with mutual exclusivity and save persistence;
2. make all six choices produce real measurable logistics trade-offs;
3. make each selected choice visibly alter the 3D warehouse;
4. add `Expansion Zones x/3` and post-choice measurement in the Rank 2 management UI;
5. run deterministic balance scenarios so each choice has a valid operating context and none is a fake best answer;
6. only after that measurement decide whether AGV is the next valuable automation layer.
