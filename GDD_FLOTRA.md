# FLOTRA — Game Design Document

Status: **Pre-GO / VERTICAL_SLICE — Core Experience v2 rework**
Official title: **FLOTRA（フロトラ）**
Former title / migration alias: `LOGISTICS BOSS`
Last synchronized: 2026-09-18 JST
Canonical project rule: `GAME_DEV_MASTER_RULES.md`

This document supersedes the earlier Web/PWA-first and Three.js vertical-slice assumptions. The production implementation is Godot-native-first, with Web used only as an engineering preview.

## 1. Product Context Lock

- Product: FLOTRA
- Genre: portrait 3D logistics management / automation observer
- Player role: logistics-center owner / operations manager
- Development target: iPhone / iOS
- Android: not an active production target Pre-GO; evaluate only after PRODUCTION_DECISION=GO via a separate PLATFORM_EXPANSION_DECISION
- Engineering preview: Godot Web export / GitHub Pages
- Engine: Godot 4.7.2 Standard
- Language: GDScript
- Renderer: GL Compatibility
- Reference viewport: 390×844 portrait
- Input: tap, single-finger orbit, pinch zoom; no virtual joystick
- Session target: roughly 5–15 minutes per active session
- Online requirement: none for current product
- Account/backend/cloud save: none
- Monetization: not activated; outside the current Pre-GO VERTICAL_SLICE v2 scope
- Analytics: provider-neutral local instrumentation only; no external transmission

## 2. Canonical Core Loop

**Observe warehouse flow → notice a physical symptom → inspect the relevant Zone → choose an operational or capital response → the facility physically changes → authoritative logistics react → measure the outcome → discover the next constraint.**

The player is not asked to manually carry parcels, drive forklifts or perform worker-level actions.

Core Experience v2 is locked around these principles:
- the **3D warehouse is the primary game board**;
- normal equipment decisions begin from a physical Zone, not from Management;
- the Bottleneck Director reports symptoms/evidence, not the answer;
- a major investment must have visible geometry, authoritative logistics effect, a readable strength, a readable weakness/trade-off, and a measurable result;
- solving one bottleneck should credibly be able to expose another;
- repeated anonymous stat-level purchase loops are not the target product pattern.

The product succeeds only if the player can understand:
- what is entering;
- where inventory or work is accumulating;
- which stage is constraining flow;
- what changed physically after a decision;
- what changed operationally after a decision;
- why the next intervention matters.

A normal play session must not collapse into **open Management → buy whatever is available → repeat**.
## 3. Meta Loop

The long-term progression spine is:

**contract / operating profit → cash + RP + logistics rating → larger facility rank → structural investment → new bottleneck → new operating decision → larger profit**

Growth must be visible in both the authoritative simulation and the 3D facility.

A major investment should normally provide:
1. visible 3D change
2. authoritative logistics effect
3. measurable before/after result
4. a credible chance that solving one bottleneck exposes another

Numeric-only purchases without physical or operational meaning are not the target product pattern.

## 4. Domain Authority

The Domain simulation owns:
- queues
- worker tasks
- shipments
- shipment value
- money
- routing
- contracts
- progression
- capital ownership
- facility rank

UI and View layers may display or animate state but must never manufacture shipment revenue, money or fake logistics outcomes.

## 5. Rank 1 — Small Depot

Rank 1 is the complete onboarding chapter for Core Experience v2.

Initial state remains intentionally compact:
- cash: current balance baseline may be tuned during the slice;
- 3 workers;
- small storage;
- one packing station;
- one shipping path;
- no forklift automation.

Authoritative flow:

Inbound → Store → Rack → Pick → Pack → Ship

### Rank 1 structural projects

The visible v2 path uses memorable physical projects instead of repeated stat-level upgrades:

- **Rack Wing** — visible storage expansion;
- **Second Packing Bench** — visible parallel packing capacity;
- **Worker Hire** — one additional worker whose value comes from assignment;
- **Forklift** — real inbound-to-storage automation that changes who performs the work.

Repeated player-facing Speed Lv / Packing Lv purchase chains are superseded for the v2 slice.

### Rank 1 interaction model

The first meaningful improvement must be reachable from the warehouse itself:
1. observe the facility;
2. notice a physical symptom;
3. tap the relevant Zone;
4. inspect evidence;
5. choose an operational or capital response;
6. preview the physical change;
7. commit;
8. watch logistics react;
9. read the measured result.

Management is not the normal equipment store.

Discoverability is part of the Core Experience contract, not optional polish:
- every top-level warehouse Zone must visually advertise that it is tappable;
- a stressed Zone may show its pressure state together with the tap affordance;
- Management Overview must provide direct Zone navigation rather than only passive text;
- a blocked Rank 1 Warehouse Expansion must expose the unfinished structural Projects and route each one to the relevant Zone;
- completing a Project changes its route to a visible completed state instead of making the item silently disappear;
- Rank 1 does not show the legacy logistics-policy controls as the primary obvious intervention;
- Rank 2+ logistics-policy controls must state their meaning explicitly: 均等運用 / 入荷優先 / 出荷優先.

A player should not need prior knowledge of the implementation to discover where equipment decisions live.

### Rank 1 FTUE

Fresh-save onboarding is event-driven and should teach by play rather than by a long checklist.

The first guided event may point the player toward a stressed Zone, but it must not solve the decision for them. The implementation may mark the actual stressed Zone as **ここをタップ** so the player learns the warehouse interaction surface; it must not identify which equipment is the correct answer. After the initial guided intervention, the simulation should be allowed to produce the next bottleneck naturally.

FTUE completion still waits for the authoritative measurement result.

### Warehouse Expansion

Rank 1 ends with a visible **Warehouse Expansion** strategic project in Management.

The project requires evidence that the Small Depot has been meaningfully developed and can sustain a minimum operating level. Exact cash/throughput thresholds remain balance parameters for the v2 slice.

Completing Warehouse Expansion must visibly enlarge/restructure the facility into Rank 2. A text-only Rank promotion is insufficient.
## 6. Bottleneck / Measurement UX

The player-facing Director reports the dominant symptom with concise evidence.

Examples:
- PACKING high load;
- 14 waiting;
- sustained for 42 seconds.

The Director must **not** say which equipment to buy or provide a one-tap solution.

Current symptom families may continue to derive from authoritative Domain state:
- inbound congestion;
- rack/storage pressure;
- picking/open-order pressure;
- packing congestion;
- outbound backlog;
- stable operation.

Major capital measurement window remains:
- Before: 25 seconds;
- After: 25 seconds.

Investment result classification:
- 改善;
- 横ばい;
- 要再判断.

Result hierarchy:
1. judgment + shipment delta;
2. operational context;
3. explanation of what changed.

The result may help the player understand consequences, but should not prescribe the next purchase.
## 7. Rank 2 — Warehouse

Rank 2 is the chapter where the player chooses **how** each Zone operates.

### Locked target Zone structure

The long-term Rank 2 target is five operational Zones:

- INBOUND: Double Dock ⇄ Buffer Yard
- STORAGE: Fast Pick Rack ⇄ High Density Rack
- PICKING: Zone Picking ⇄ Batch Picking
- PACKING: Parallel Pack Line ⇄ Fast Pack Cell
- SHIPPING: Extra Dispatch Lane ⇄ Consolidation Stage

Each pair must represent a real trade-off rather than a stronger/weaker ladder.

### Renovation

Rank 2 equipment is **not a permanent one-time branch**.

Locked rules:
- one equipment mode per Zone is active at a time;
- the active mode may be replaced by paid renovation;
- renovation changes both physical geometry and authoritative Domain behavior;
- renovation runs the normal Before/After measurement again;
- no full-refund flip loop.

Exact renovation cost and downtime are balance hypotheses, not locked values.

### Vertical Slice v2 implementation scope

Only two Rank 2 Zones are implemented in the current slice:

#### STORAGE
- **Fast Pick Rack**
  - storage contribution: +12;
  - pick task duration ×0.75;
  - weakness: 4 fewer storage slots than High Density Rack.
- **High Density Rack**
  - storage contribution: +16;
  - pick task duration ×1.14;
  - weakness: slower pick processing.

Verified paired scenarios:
- order backlog: Fast Pick **18** picks vs High Density **12**;
- storage-pressure absorption: Fast Pick **4** boxes vs High Density **8**.

#### PACKING
- **Parallel Pack Line**
  - 2 concurrent jobs;
  - per-job duration ×1.10;
  - strength: long-queue throughput.
- **Fast Pack Cell**
  - 1 concurrent job;
  - per-job duration ×0.58;
  - strength: single-job latency.
- a Rank 2 PACKING system supersedes the Rank 1 Second Packing Bench behavior; Fast Pack Cell therefore retains its intended one-job weakness.

Verified paired scenarios:
- 200-box / 180-second long queue: Parallel **106** completions vs Fast Cell **102**;
- single-job latency: Parallel **3.35s** vs Fast Cell **1.75s**.

For each pair:
- A must have at least one tested scenario where it is preferable;
- B must have at least one tested scenario where it is preferable;
- neither option may be universally dominant across the paired scenarios.

Current Vertical Slice renovation implementation:
- first build uses the full catalog price;
- A ⇄ B renovation costs **75% of the target equipment fresh-build price**;
- renovation gives no refund;
- only one mode per Zone is active;
- STORAGE capacity contribution is replaced rather than stacked;
- downsizing STORAGE never deletes existing inventory; temporary over-capacity drains naturally;
- renovation physically replaces the active 3D equipment;
- renovation starts a new authoritative Before/After measurement;
- 75% is the current tested implementation value and remains tunable after human playtest rather than a permanent economy constant.

INBOUND, PICKING, and SHIPPING v2 equipment remain deferred until this slice passes playtest.

### Staffing

The previous player-facing five-preset model is superseded for Core Experience v2.

The player-facing model is **direct Zone reassignment** over the authoritative Worker task system.

Staffed flows:
- **RECEIVING** — covers INBOUND → STORAGE work;
- **PICKING** — covers order picking;
- **SHIPPING** — covers dispatch work.

PACKING is equipment-processed in the current simulation and therefore has **no direct Worker allocation**. Do not fake a staffing control for it.

Rank 2 starts at:
- RECEIVING: 2;
- PICKING: 2;
- SHIPPING: 1.

A staffing action moves **one Worker from a source staffed flow to the inspected target flow**.

Locked safety rules:
- every staffed flow keeps at least 1 Worker;
- a reassignment starts the existing 30-second observation cooldown;
- current allocation is readable in the Zone Panel;
- Management shows an executive staffing overview only;
- legacy preset names remain compatibility/migration data and are not player-facing v2 controls.

Staffing remains an **OPERATIONS** layer distinct from CAPITAL equipment.

### Existing workload systems

Forecast/surge workload logic is reusable technical content, but it is not allowed to force the UI back into a preset-selection game. Expose it only where it creates a readable operational decision.
## 8. Rank 3 — Fulfillment Center

Canonical Rank 3 gate:
- all 3 Rank 2 expansion zones complete
- equipment assets >= ¥200,000
- live throughput >= 6 shipments/min

Contracts are optional and are **not** a Rank 3 gate.

### Receiving Annex

- one-time capital
- cost ¥24,000
- inbound acceptance +14
- visible 3D expansion
- measured Before/After
- save/load supported

### Carrier Routing

Balanced Parcel:
- batch 1
- dispatch 3.0 seconds
- ¥500 per parcel

Express Dispatch:
- batch 1
- dispatch 1.65 seconds
- ¥410 per parcel

Consolidated Linehaul:
- threshold / batch 4
- dispatch 6.8 seconds
- ¥620 per parcel

Routing state is Domain-authoritative. A SHIP task freezes route, batch and value at task start so changing mode cannot reprice in-flight shipments.

### High-frequency inbound carrier program

- one-time capital
- requires Receiving Annex
- cost ¥30,000
- scheduled inbound interval ×0.85
- counted in equipment assets
- visible 3D state
- persistence preserved through current runtime schema v9

Research showed that scheduled inbound cadence is the first post-routing lever that materially increases shipments. AGV / sorter / ASRS-style candidates are not automatically added unless measurement proves product value.

## 9. Save / Recovery

Current runtime save schema: **v9**.

Persistence:
- local JSON under `user://`
- primary save
- backup save
- semantic-invalid primary fallback to backup
- autosave every 10 seconds
- save on close / application pause

Save compatibility is a release requirement. Existing valid progression must not be destroyed by ordinary upgrades.

Migration baseline:
- schema v7 and earlier legacy progression remains loadable through the layered migration path;
- schema v8 Rank 1 v2 project state remains valid;
- schema v8 named staffing presets migrate into equivalent schema v9 direct Zone counts;
- schema v9 persists Rank 1 v2 project ownership plus direct Zone staffing.

## 10. Camera / Mobile UX

The facility must remain the main visual focus.

Requirements:
- single-finger orbit
- pinch zoom
- bounded drag/pinch input to avoid jumpy motion
- portrait camera preserves useful horizontal field of view
- maximum zoom-out must show the operation as a readable whole
- close zoom must not become tunnel-like
- no critical interaction depends on hover

The verified mobile implementation uses a dedicated mobile warehouse-view subclass with smoothed position/FOV behavior.

## 11. Management / Zone UI

### 11.1 Primary warehouse screen

The 3D warehouse is the default play surface and should retain the majority of the portrait viewport.

Primary HUD should be limited to high-frequency state such as:
- cash;
- shipment rate;
- open orders;
- facility Rank.

RP is hidden from the primary HUD until it has a clear player-facing decision role.

### 11.2 Zone interaction

The warehouse uses readable operational Zones:
- INBOUND;
- STORAGE;
- PICKING;
- PACKING;
- SHIPPING.

The player taps a Zone in the warehouse to inspect and intervene.

Do not require precision tapping on tiny individual machines.

### 11.3 Zone Panel

The Zone Panel is a bottom sheet occupying roughly **35–42%** of the portrait viewport so the selected Zone and adjacent flow remain visible.

Information hierarchy:
1. Zone name + current state;
2. operational evidence;
3. current equipment;
4. **OPERATIONS** actions;
5. **CAPITAL** choices.

Each equipment card must show:
- equipment name;
- primary strength;
- explicit weakness/trade-off;
- cost.

Do not label a choice as recommended.

### 11.4 Equipment preview and commitment

Normal structural equipment uses:

**equipment card → preview → ghost/planned geometry → explicit build/renovate confirmation → physical construction/change**

Verified implementation:
- Rank 1 and Rank 2 capital actions use a two-step preview → explicit commit flow;
- Rank 2 preview shows equipment name, strength, weakness/trade-off, and real build/renovation cost;
- first preview tap does **not** spend cash;
- preview draws semi-transparent planned equipment geometry directly in the selected warehouse Zone;
- covered Rank 1 structural previews: Rack Wing, Second Packing Bench, Forklift Project;
- covered Rank 2 previews: Fast Pick Rack, High Density Rack, Parallel Pack Line, Fast Pack Cell;
- selecting another equipment choice replaces the old ghost;
- switching Zones or closing the Zone Panel clears stale preview geometry;
- successful authoritative commit clears the ghost, activates the real equipment geometry, and produces a short selected-Zone construction emphasis;
- build/renovation continues into authoritative Before/After measurement;
- short action feedback is held long enough to read;
- fresh 390×844 `rank2_preview.png` evidence was human-inspected with the STORAGE Zone Panel open, High Density Rack ghost visible, and the warehouse still readable behind the decision surface.

Cash must not be converted into an invisible stat change from a single ambiguous button press.

The presentation contract is now implementation-complete for Vertical Slice v2. Human iPhone Web playtest evidence is still required before declaring the Core Experience rework successful.

### 11.5 Management Dashboard

Management becomes an executive dashboard rather than the normal equipment store.

Target information architecture:
- **Overview**
- **Contracts**
- **Assets**
- **Staffing**

For Vertical Slice v2:
- Overview and Staffing are required;
- Overview contains tappable controls that open each physical warehouse Zone;
- Rank 1 Warehouse Expansion keeps all four structural Project routes visible until completion;
- Contracts may retain existing functionality with minimal restructuring;
- full Assets history may be deferred if it does not block the Core Experience test.

Normal Zone equipment is not purchased from Management. Management may navigate the player to the relevant Zone but must not recreate a hidden equipment store.

Facility-level Rank Expansion remains in Management because it is a strategic project.

### 11.6 Mobile requirements

- no horizontal overflow;
- touch drag/scroll works on iPhone Web and later native iOS;
- all primary decisions use touch-sized targets;
- warehouse Zone labels themselves communicate tap affordance;
- Rank 1 Management shows five tappable Zone routes plus the four structural Project routes within the normal portrait scroll surface;
- warehouse remains visible during normal Zone decisions;
- no critical interaction depends on hover.
## 12. Art Direction

Visual north star:
- dark navy industrial base
- cyan technology accents
- amber/orange safety accents
- warm local lighting
- stylized premium mobile readability
- open-top / cutaway logistics center

Do not obstruct the operation with decorative roof/truss geometry that hides the flow.

Facility growth should visibly change the scene, not merely update text.

## 13. Game Feel

Current baseline:
- procedural short feedback tones
- shipment feedback
- stronger investment / contract / rank-up feedback
- native haptic hooks using `Input.vibrate_handheld`
- shipment haptics throttled to prevent spam

Native audio/haptic quality is not considered verified until signed physical-device testing.

## 14. Performance / Telemetry

Runtime health tracks:
- average FPS
- minimum FPS
- low-FPS seconds / ratio

DEVICE_VALIDATION target includes no sustained sub-30 FPS behavior during a representative mature Rank 3 scene on the representative physical iPhone. Thermal/frame-pacing evidence is required before GREENLIGHT.

Provider-neutral analytics records major gameplay events locally. No external analytics provider or data upload is active.

## 15. Current Acceptance Criteria — Vertical Slice v2

### Code / simulation baseline

The rework must preserve:
- runtime startup stability;
- authoritative shipment/revenue behavior;
- worker task continuity;
- save/recovery integrity;
- real measurement windows;
- Web engineering export;
- existing iOS export smoke unless unrelated infrastructure changes.

### Core Experience PASS

The slice fails if a normal playtest still feels like:

**open Management → buy whatever is available → repeat**

PASS requires that a player can describe the session approximately as:

> “I saw where the warehouse was backing up, changed that part of the facility, then the pressure moved and I had to deal with the next problem.”

### Rank 1

- first meaningful improvement is reachable without Management acting as an equipment store;
- physical congestion is readable in the warehouse;
- Zone interaction leads to a relevant action;
- Rack Wing / Second Packing Bench / Worker / Forklift have legible physical and operational consequences;
- Forklift visibly changes logistics behavior;
- Rank 1 → Rank 2 visibly enlarges/restructures the facility.

### Rank 2 STORAGE / PACKING

For each implemented Zone:
- both options are understandable;
- both have distinct physical identities;
- both have authoritative trade-offs;
- both have a tested winning scenario;
- paid renovation A ⇄ B works;
- renovation persists safely.

### UI / reward legibility

- Zone Panel hierarchy is readable at 390×844;
- warehouse remains visible while making a Zone decision;
- tappable warehouse Zones are discoverable without external explanation;
- Management Overview is understandable without unrelated purchase clutter;
- Management can route directly to each Zone;
- Rank 1 blocked Expansion visibly identifies unfinished Project routes;
- normal Zone equipment is not bought from Management;
- Rank 1 does not present ambiguous logistics-policy controls as the primary intervention;
- Rank 2+ policy controls are labelled by their actual operational meaning;
- RP is absent from the primary HUD;
- Director reports symptoms, not solutions;
- the player can identify what physically changed after an investment;
- the player can identify what operationally changed after an investment.

Fresh human playtest evidence outranks static screenshot-difference claims for reward/growth recognition.
## 16. Current Non-goals

Not required for the current Pre-GO DEVICE_VALIDATION:
- free-placement factory building editor
- multiplayer
- cloud save
- account system
- multiple product SKUs
- staff mood/needs simulation
- ad/IAP activation
- external analytics provider
- live-service backend

These can be reconsidered only if they improve marketability, retention or monetization after the core product proves itself.

## 17. Technology Decision

Production implementation:
- Godot 4.7.2 Standard
- GDScript
- GL Compatibility
- active development target: iPhone / iOS
- Android is deferred until PRODUCTION_DECISION=GO and a separate PLATFORM_EXPANSION_DECISION
- Godot Web as engineering preview only
- local `user://` persistence
- GitHub main as canonical repository baseline

The previous Three.js / PWA-first implementation direction is superseded and must not be restored as the production game path.

## 18. Current Gate — VERTICAL_SLICE v2 REWORK

ACTIVE_PHASE: **VERTICAL_SLICE**

Platform / state:
- DEVELOPMENT_TARGET: iPhone / iOS
- PRODUCTION_DECISION: UNDECIDED
- RELEASE_APPROVAL: NOT_REQUESTED
- PRIMARY_INPUT: touch

### Why FLOTRA returned from DEVICE_VALIDATION

Repeated iPhone Web play exposed a Core Experience failure:
- equipment/facility change was not clear enough during ordinary play;
- Management was hard to parse;
- action → consequence was unclear;
- play drifted toward repeated equipment-upgrade clicking;
- meaningful equipment/decision variety was exhausted too quickly.

This is a targeted return to VERTICAL_SLICE, not a full technical reset.

Existing simulation, save/recovery, CI, export smoke, and reusable visual work remain valid assets unless superseded by v2.

### Human iPhone Web retest — 2026-09-19

Result: **FAIL — discoverability / navigation**

Observed without coaching:
- the player could not tell which parts of the warehouse were tappable or what each visible control changed;
- Management showed `設備Project 0/4` without an obvious actionable route to those Projects;
- the bottom BALANCED / INBOUND / SHIP logistics-policy controls were interpreted as staffing changes;
- equipment consequence / ghost / deeper decision quality could not be fairly judged because the player did not reliably reach the intended equipment decision surface.

Routing decision:
- remain in **VERTICAL_SLICE**;
- fix the smallest failing layer only;
- do not add more equipment or Rank 3 content to mask the failure.

PR #117 implements that discoverability-only correction. Human iPhone Web retest remains required.

### Current implementation scope

Canonical implementation packet:
- VERTICAL_SLICE_V2_CHANGE_PACKET.md

The implemented slice now contains:
- full Rank 1 v2 path;
- 3D Zone interaction;
- Zone Panel;
- symptom-only Director;
- Management Dashboard role change;
- direct player-facing staffing;
- Rank 2 STORAGE pair + renovation;
- Rank 2 PACKING pair + renovation;
- physical planned-equipment ghost preview;
- explicit preview → commit → real-geometry transition;
- selected-Zone construction/reward emphasis;
- authoritative Before/After measurement.

The planned feature scope is complete for Vertical Slice v2, and PR #117 adds the targeted discoverability correction found by the 2026-09-19 human retest. The slice explicitly does not implement the remaining Rank 2 Zones or redesign Rank 3.

**Current gate:** repeat the human iPhone Web Core Experience playtest, starting with discoverability. Do not add deferred content merely because implementation work is otherwise complete.

### Return to DEVICE_VALIDATION

Return to DEVICE_VALIDATION only after:
- the v2 slice is playable end-to-end;
- CI/save regressions are green;
- fresh visual evidence is inspected;
- iPhone Web playtest no longer reproduces the Management-clicker failure mode;
- equipment/facility consequences are legible during ordinary play.

Returning to DEVICE_VALIDATION does not enter GREENLIGHT.

Native representative-iPhone evidence remains required before GREENLIGHT.

Only if PRODUCTION_DECISION=GO:
- enter FUNCTIONAL_BUILD / RELEASE_ENABLEMENT as appropriate;
- finalize production Bundle ID / App ID decisions;
- build out production signing / provisioning;
- prepare App Store Connect / TestFlight production workflow;
- evaluate Android separately through PLATFORM_EXPANSION_DECISION.

GREENLIGHT remains a production-investment decision, not App Store release approval.