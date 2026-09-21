# FLOTRA — Game Design Document

Status: **Pre-GO / VERTICAL_SLICE — Core Experience v2 rework**
Official title: **FLOTRA（フロトラ）**
Former title / migration alias: `LOGISTICS BOSS`
Last synchronized: 2026-09-21 JST (PR132 baseline / capacity-repair candidate)
Canonical project rules: `ゲーム開発共通ルール_v2.4.txt`, `プロジェクト適用範囲_v2.4.txt`, `ゲーム開発チャット引き継ぎルール_v2.4.txt`. The old repo Master filename is not current authority.

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

## 1.1 Growth-first title decision, 2026-09-21

The user's 実行 after the video audit authorizes a bounded growth-first development revision. This supersedes the old mandatory Rank1 Logistics Rating8/all-four-Projects gate and the requirement to read analysis before each meaningful purchase. It does not supersede the manager role, real logistics, Zone-first physical choices, iPhone target or release approval boundaries.

Primary player reward: a growing working warehouse, not the completion of an analysis checklist. Ordinary shipments and earned cash support basic growth; contracts are optional acceleration/challenge. Equipment should reveal a change in how work is done. Analysis supports optimization, not a mandatory pause between investments. Exact numbers below are testable balance hypotheses, not a human fun acceptance.

## 1.2 Capacity repair candidate, 2026-09-21

Scope: **title-local / source-only development candidate**, authorized by the user's 実行 after the audit. The existing engineering preview remains PR132 / schema10. This candidate is not a merged or deployed build and has no human fun or device acceptance. See `CAPACITY_REPAIR_CHANGE_PACKET.md` for the bounded repair and diagnosis scope; see state documents for commit-specific verification.

Candidate changes:
- Add cumulative independent packing cells (maximum 3) and automatic dispatch lanes (maximum 2), with real waiting-cargo reservation, processing and physical equipment. These additions coexist with the existing STORAGE/PACKING mode pairs; they do not implement all deferred Rank2 Zone pairs.
- Candidate prices: packing cells ¥12,000 / ¥18,000 / ¥27,000; dispatch lanes ¥16,000 / ¥24,000. These are balance hypotheses, not locked prices or evidence of satisfying long-term growth.
- Allow one draft covering all three authoritative staffing pools, followed by one atomic application and the existing 30-second cooldown. Each pool keeps at least one worker. Cancel, invalid/stale-plan rejection and same-tab reselection must preserve correct draft/live-state separation. Active jobs keep their cargo and task; displayed current activity follows that task until completion.
- Save candidate schema11 adds cumulative equipment ownership/counters while preserving schema10 progression, money, staffing and cargo without free machinery. Candidate migration and recovery require their own verification; prior schema10 checks do not cover them.
- Restore route visibility and related input clarity without changing the art direction. The recovered routes are not proof that every motion segment already follows an aisle.

The reported 300-second comparison with equal output is **not a diagnosis of insufficient arrivals or orders**. The controlled diagnostic below supports a packing/dispatch constraint under its declared workload; **workload growth is not adopted**. Buying all five candidate additions is not a player goal or evidence that the early growth ceiling is solved. After the first packing cell, including when no dispatch lane is owned, the candidate objective leads to optional field inspection; staffing changes and additional purchases remain choices, not a mandatory completion checklist.

## 1.3 Capacity diagnosis, 2026-09-21

Evidence: `godot/tests/capacity_flow_report.gd`, first run provisionally on Godot4.5.1, then reproduced on the matching **4.7.2** engine. The exact-engine import and60headless checks passed; see CAPACITY_VERIFICATION_2026-09-21.json. The fixture holds workload and initial state constant, warms up for one complete 255-second cycle, then measures three complete cycles (765 seconds). Arrival/order multipliers exist only in the diagnostic, not in production progression. This is deterministic simulation evidence, not human pacing, fun or iPhone acceptance.

The original 300-second result was reproduced: all four equipment configurations shipped **86** parcels. With the full-cycle measurement:

| Controlled configuration | Shipments in 765 measured seconds | Interpretation within this fixture |
| --- | ---: | --- |
| Baseline equipment and staffing | 253 | Reference |
| First packing cell only | 253 | Work advances to the dispatch backlog; final output alone hides the packing effect |
| First packing cell + first dispatch lane | 276 | 92 shipments in each measured cycle; sustained output benefit from automated dispatch |
| First packing cell + staffing RECEIVING/PICKING/SHIPPING = 1/2/2 | 276 | Staffing also resolves the exposed dispatch constraint; a dispatch-lane purchase is not required |
| All 3 cells + all 2 lanes | 276 | No further output benefit demonstrated over the first pair |
| Baseline with arrivals ×2 only | 255 | Doubling arrivals alone does not reproduce the pair's benefit |
| Baseline with orders ×2 only | 255 | Doubling orders alone does not reproduce the pair's benefit |
| Baseline without a packing cell, with tested staffing changes | 253 | Staffing alone does not resolve the initial packing constraint |

Measured conclusion: packing and dispatch are consecutive constraints in the tested initial state. A cell can move the backlog downstream; either a dispatch lane or staffing RECEIVING/PICKING/SHIPPING = 1/2/2 then improves completed flow. The lane purchase is optional. Keep production arrivals/orders unchanged. Further growth beyond this initial packing/dispatch improvement, and whether the improvement is visible and enjoyable in ordinary play, remain unproven. This result is scoped to its workload and engine and must not become a universal equipment or staffing recommendation. See current state/evidence documents for subsequent 4.7.2 verification.

## 2. Canonical Core Loop

**Ship and earn → choose where to invest → see real equipment and work change → expand the warehouse → add working automation → reinvest.**

Optional mastery loop: observe a physical symptom → inspect its Zone → change equipment/staffing → compare observational results → address the next constraint. New investments do not wait for measurement completion.

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

**ordinary operating profit (plus optional contracts) → cash → physical capacity and automation → larger facility → increased working scale → another meaningful investment**

Rank1 player-visible growth spine:

**ordinary shipments + 2 distinct structural investments + earned expansion cash → explicitly expand into Rank2 → choose unfinished projects, a second forklift or a working conveyor.**

Current development balance hypotheses:
- Initial funds: ¥5,000; no automatic money or rating grant.
- First expansion: any 2 of the 4 distinct Rank1 projects, at least 20 total actual shipments, ¥8,000.
- No Logistics Rating or contract-completion gate for first expansion; no auto-promotion.
- Rack Wing ¥2,500; Second Packing Bench ¥4,500; one Worker Hire ¥3,500; first Forklift ¥8,000.
- Expansion permanently enlarges the floor from 15.8×11.8 to 19×13.4 world units, adds 4 storage capacity and brings the existing Rank2 crew to at least five.
- Unfinished structural projects remain buyable in Rank2 except a hire already covered by the five-worker crew or a bench superseded by advanced packing. Installed assets are never taken away to force repurchase.
- Additional forklift: ¥10,000, Rank2 + first forklift; a real second vehicle reserves and carries up to two inbound parcels per 4.8-second roundtrip.
- Transfer conveyor: ¥9,000, Rank2; PICKING to PACKING, at most four in-flight parcels, 2.4 seconds travel; replaces half the picker task time with actual independent transport and backpressure. It does not magically increase packing or final dispatch capacity.
- PR132 automation scope: first forklift plus one additional forklift, one conveyor path. The separate bounded capacity candidate is listed in §1.2. No unlimited vehicle upgrades or freeform layout editor in this slice.

The old all4 / Rating8 / ¥10,000 gate is **SUPERSEDED for current FLOTRA development**. Old tests/saves remain historical compatibility evidence, not active product requirements.

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
- legacy BALANCED / INBOUND / SHIP policy controls are hidden from the Core Experience v2 player path while direct Zone staffing owns authoritative Rank 2 work assignment;
- do not expose a player-facing control unless it has an authoritative gameplay effect in the current simulation.

A player should not need prior knowledge of the implementation to discover where equipment decisions live.

### Rank 1 FTUE

Fresh-save onboarding is event-driven and should teach by play rather than by a long checklist.

The first step must establish the overall Rank 1 purpose before teaching a local intervention:

**出荷で稼ぐ → 設備を2種類増やす → 出荷20件と拡張費を満たす → 倉庫拡張**

The first guided intervention may point the player toward a stressed Zone, but it must not solve the equipment decision for them. The implementation may mark the actual stressed Zone as **ここをタップ** so the player learns the warehouse interaction surface; it must not identify which equipment is the correct answer. After the initial guided intervention, the simulation should be allowed to produce the next bottleneck naturally.

The guide may finish after an authoritative measurement result, but it never blocks other investments or expansion while the observation runs.

### Warehouse Expansion

Rank 1 ends with a visible **Warehouse Expansion** strategic project in Management.

The gate states the two-investment count, actual shipment count and money, with the benefit shown before confirming. It does not require every possible starting purchase. Expansion is an explicit paid action and immediately changes the floor, capacity and crew. A text-only rank promotion is insufficient.

### Purchase reveal and notification hierarchy
Confirmed construction closes the large Zone sheet and returns to the actual warehouse. A cancellable three-second camera emphasis can show the real installation; it never blocks tapping or starts another automatic purchase. Ordinary shipment earnings stay beside funds, not over machinery or controls. Important results retain the PR130 control-clearance behavior. Ownership/status and reason-for-unavailability remain explicit.

### Save compatibility
Runtime schema10 adds new automation ownership/work counters and purchase-book values. Read schemas1-9. Preserve money, owned investments, staffing, completed work and existing contract state. Do not grant new machinery during migration. Preserve the original nominal book values of pre-revision forklifts/expansions instead of silently devaluing them. Save in-flight cargo into durable waiting queues without changing live state or inventing completed shipments; animation and partial task time restart on load. Old schema9 executables cannot load schema10, so do not silently revert a deployed schema10 build or delete saves.

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
- 効果混在;
- 要再判断.

Investment judgment must use the authoritative metric that matches the intervention where available, rather than shipment rate alone.

Examples:
- STORAGE capacity investment may be judged from rack/storage pressure;
- PACKING investment may be judged from packing queue pressure;
- receiving automation may be judged from inbound queue pressure;
- shipment rate / revenue remain important outcome metrics but are not the sole definition of success for every intervention.

The HUD must show the target investment and basis used for the verdict. These are before/after observations, not proof of isolated causation. If another investment, staffing move or expansion falls in the before/after window, label the result **複数変更を含む参考値**. Never require the player to stop investing for 25 seconds to produce a cleaner metric.

Result hierarchy:
1. judgment + authoritative basis;
2. shipment / revenue context;
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

The deployed PR132 baseline implements two Rank 2 equipment-mode pairs (the cumulative additions in §1.2 are separate candidate scope):

#### STORAGE
- **Fast Pick Rack**
  - storage contribution: +12;
  - pick task duration ×0.75;
  - weakness: 4 fewer storage slots than High Density Rack.
- **High Density Rack**
  - storage contribution: +16;
  - pick task duration ×1.14;
  - weakness: slower pick processing.

Historical paired-scenario evidence from the earlier v2 slice (not a capacity-candidate rerun):
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

Historical paired-scenario evidence from the earlier v2 slice (not a capacity-candidate rerun):
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

The paired INBOUND, PICKING, and SHIPPING v2 equipment modes remain deferred until this slice passes playtest. The candidate automatic dispatch lanes in §1.2 are bounded cumulative additions, not completion of the SHIPPING mode pair.

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

In the deployed PR132 baseline, a staffing action moves **one Worker from a source staffed flow to the inspected target flow**. The candidate in §1.2 replaces that editing path with one warehouse-wide draft and atomic application; it preserves the minimum counts, cooldown and current-task continuity.

Locked safety rules:
- every staffed flow keeps at least 1 Worker;
- a reassignment starts the existing 30-second observation cooldown;
- current allocation is readable in the Zone Panel;
- Deployed PR132 Management shows an executive staffing overview; the §1.2 candidate adds the staffing draft workspace there;
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
- introduced with schema9 and retained in the deployed schema10 progression

Historical Rank3 research found that scheduled inbound cadence materially increased shipments in its tested post-routing scenario. That result does not diagnose the separate Rank2 capacity candidate. AGV / sorter / ASRS-style candidates are not automatically added unless measurement proves product value.

## 9. Save / Recovery

Deployed PR132 runtime save schema: **v10**. Source-only capacity candidate: **v11, not deployed** (see §1.2).

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
- schema v9 persists Rank 1 v2 project ownership plus direct Zone staffing;
- schema v10 retains schemas1–9 and adds working automation ownership/counters and purchase book values as described in §5;
- candidate schema v11 must additionally preserve cumulative cells/lanes and normalize in-flight cargo into durable waiting state without changing the live run or inventing shipments. Schema11 verification is separate from the historical schema10 baseline.

Once a newer schema has written a save, do not assume an older executable can read it. Use compatible forward repair or reviewed recovery; never erase player data to make a migration check pass.

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

Historical baseline implementation evidence (not a capacity-candidate rerun):
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

For the growth-first Vertical Slice:
- Rank 1 Management and its navigation make ordinary growth and Warehouse Expansion legible; contracts are explicitly optional;
- the primary Rank 1 HUD exposes a persistent NEXT objective showing distinct investments, actual shipments and expansion cash;
- tapping that NEXT objective opens the relevant growth/expansion surface;
- Overview contains tappable controls that open each physical warehouse Zone;
- Rank 1 Warehouse Expansion keeps all four structural Project routes visible until completion;
- Warehouse Expansion states the two-investment / 20-shipment / ¥8,000 gate; Logistics Rating and contract completion do not block it;
- Staffing remains a separate OPERATIONS layer for Rank 2;
- full Assets history may be deferred if it does not block the Core Experience test.

Normal Zone equipment is not purchased from Management. Management may navigate the player to the relevant Zone but must not recreate a hidden equipment store.

Facility-level Rank Expansion remains in Management because it is a strategic project.

### 11.6 Mobile requirements

- no horizontal overflow;
- touch drag/scroll works on iPhone Web and later native iOS;
- all primary decisions use touch-sized targets;
- warehouse Zone labels themselves communicate tap affordance;
- Rank 1 primary HUD shows a concise persistent growth objective without covering the warehouse;
- Rank 1 Management makes growth/expansion discoverable, with five tappable Zone routes, the four structural Project routes, optional contracts and the Warehouse Expansion gate within the normal portrait scroll surface;
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

PASS first requires that, without coaching, the player can explain the Rank 1 purpose approximately as:

> “I earn money by shipping, add two kinds of equipment or staffing improvements, then use my shipment progress and earned cash to expand the warehouse. Contracts are optional.”

The optional optimization loop should be describable approximately as follows. Reading a measurement is never a prerequisite for the next investment:

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
- non-authoritative legacy logistics-policy controls are not shown on the v2 player path;
- player-facing Worker counts / labels describe authoritative current activity or direct staffing, not stale compatibility roles;
- RP is absent from the primary HUD;
- Director reports symptoms, not solutions;
- the player can identify what physically changed after an investment;
- the player can identify what operationally changed after an investment.

### Capacity-candidate acceptance (not yet a result)

- cumulative equipment has real cargo processing and a readable physical change;
- at least one non-fork investment demonstrates sustained operational benefit under an explicit, appropriate workload, with limitations reported;
- comparisons isolate arrivals, orders, workers and equipment before a workload change is selected;
- staffing drafts apply atomically, cancel safely, survive same-tab reselection and keep current-task display consistent;
- schema10→11 compatibility, cargo/cash conservation and relevant regression tests pass for the candidate itself;
- after the first packing cell, even with no dispatch lane, the objective opens optional field inspection rather than urging another purchase or all five additions; staffing and automatic dispatch remain alternative responses. Further useful growth remains an open design question until supported by operational and human evidence.

Fresh human playtest evidence outranks static screenshot-difference claims for reward/growth recognition. Historical test results and a user's early positive reaction do not constitute full acceptance of the current candidate.
## 16. Current Non-goals

Not required for the current Pre-GO VERTICAL_SLICE:
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

## 18. Current Gate — growth-first capacity repair / VERTICAL_SLICE

ACTIVE_PHASE: **VERTICAL_SLICE**

Platform / state:
- DEVELOPMENT_TARGET: iPhone / iOS
- PRODUCTION_DECISION: UNDECIDED
- RELEASE_APPROVAL: NOT_REQUESTED
- PRIMARY_INPUT: touch

### Current work and next gate, 2026-09-21

Baseline: PR132 ordinary-shipment growth and working automation, merged into main and delivered to the existing engineering preview as recorded in `HANDOFF.md`. Runtime schema10 remains the deployed baseline. `GROWTH_FIRST_SLICE_CHANGE_PACKET.md` retains that change's feature/evidence history; its old pre-integration deployment-wait state is superseded.

Active development packet: `CAPACITY_REPAIR_CHANGE_PACKET.md`, with source-only schema11 scope in §1.2. The provisional 4.5.1 diagnostic in §1.3 identifies consecutive packing/dispatch constraints under the tested workload; production workload growth is not adopted. Next: complete matching 4.7.2 candidate verification, repair/CI integration and ordinary-play validation of the first cell followed by either staffing or automatic dispatch. Candidate checks, human iPhone play, save continuity and performance each need their own evidence; no candidate PASS follows from the historical tests below. Further useful growth beyond that initial packing/dispatch improvement remains unresolved.

The latest reported user reaction includes **「面白くなってきた」**, alongside insufficient equipment variety/early ceiling and staffing/route clarity requests. This is useful early feedback, not an end-to-end fun or device acceptance. The human gate is understandable, visible growth through ordinary operation with useful investment choices; mandatory contracts/Rating do not return.

### Historical reason FLOTRA returned from DEVICE_VALIDATION

Repeated iPhone Web play exposed a Core Experience failure:
- equipment/facility change was not clear enough during ordinary play;
- Management was hard to parse;
- action → consequence was unclear;
- play drifted toward repeated equipment-upgrade clicking;
- meaningful equipment/decision variety was exhausted too quickly.

This is a targeted return to VERTICAL_SLICE, not a full technical reset.

Existing simulation, save/recovery, CI, export smoke, and reusable visual work remain valid assets unless superseded by v2.

### Historical human iPhone Web evidence (PR117–122, not the current gate)

#### 2026-09-19 — discoverability / navigation FAIL

Observed without coaching:
- the player could not tell which parts of the warehouse were tappable or what each visible control changed;
- Management showed `設備Project 0/4` without an obvious actionable route to those Projects;
- the bottom BALANCED / INBOUND / SHIP controls were interpreted as staffing changes.

PR #117 corrected that discoverability layer.

#### 2026-09-19 / 2026-09-20 — Zone action touch

The subsequent iPhone Web test exposed a narrower Zone Panel touch-input failure. PR #119 added the raw touch fallback. The user then confirmed the repaired preview → ghost → explicit commit path **passed on the real iPhone Web preview**.

#### 2026-09-20 — Core purpose FAIL

After the input path worked, normal play still produced the human reaction:

**「何するゲームかよく分からん」**

Audit finding:
- contracts, rewards and Logistics Rating already existed in the authoritative Domain;
- the failure was not absence of a contract system;
- contracts / Rating / structural Projects / Warehouse Expansion were not presented as one understandable growth spine;
- audit also found misleading Rank 1 Worker copy, non-authoritative policy controls, shipment-only investment verdicts and an in-flight inventory preservation gap.

PR #121 repaired those consistency issues and added a fresh natural-progression gate. Verified natural run:
- fresh canonical starting cash;
- no direct cash or Rating injection;
- Rank 2 reached in **144.9 simulated seconds**;
- 5 contracts completed;
- 46 authoritative shipments;
- Logistics Rating 10;
- all 4 Rank 1 Projects purchased;
- explicit Warehouse Expansion used for Rank 2.

PR #122 connected the then-current systems visibly (the mandatory contract/Rating presentation below was superseded by PR132):
- persistent Rank 1 NEXT objective;
- current contract progress on the main HUD;
- Rank 2 Project / Rating / expansion-cash requirements shown together;
- contract/progression controls first in Rank 1 Management;
- Warehouse Expansion explains that contracts raise Logistics Rating;
- FTUE teaches contract → Rating → Project → warehouse expansion.

Historical routing decision at PR122 (superseded next gate):
- remain in **VERTICAL_SLICE**;
- do not add new contract types, penalties, deferred equipment or Rank 3 content;
- next gate is a human iPhone Web **purpose / growth-spine retest**.

### Preserved v2 foundation

Historical foundation packet: `VERTICAL_SLICE_V2_CHANGE_PACKET.md`. It does not override the growth-first decision or the dated capacity candidate.

The reusable v2 foundation contains:
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

PR121/122 evidence above remains historical to those builds and the former progression gate. PR132 supersedes their mandatory contract/Rating growth path; the capacity candidate extends the bounded slice as specified in §1.2. Rank3 redesign and the remaining Rank2 equipment-mode pairs are still outside this candidate. The current gate is the dated repair/diagnosis and subsequent ordinary-growth human validation stated at the start of this section.

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
