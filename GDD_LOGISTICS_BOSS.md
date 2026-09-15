# LOGISTICS BOSS — Game Design Document

Status: **Code RC Candidate**
Last synchronized: 2026-09-16 JST
Canonical project rule: `GAME_DEV_MASTER_RULES.md`

This document supersedes the earlier Web/PWA-first and Three.js vertical-slice assumptions. The production implementation is Godot-native-first, with Web used only as an engineering preview.

## 1. Product Context Lock

- Product: LOGISTICS BOSS
- Genre: portrait 3D logistics management / automation observer
- Player role: logistics-center owner / operations manager
- Final platforms: native iOS + Android
- Engineering preview: Godot Web export / GitHub Pages
- Engine: Godot 4.7.2 Standard
- Language: GDScript
- Renderer: GL Compatibility
- Reference viewport: 390×844 portrait
- Input: tap, single-finger orbit, pinch zoom; no virtual joystick
- Session target: roughly 5–15 minutes per active session
- Online requirement: none for current product
- Account/backend/cloud save: none
- Monetization: not activated; decision remains outside current RC scope
- Analytics: provider-neutral local instrumentation only; no external transmission

## 2. Canonical Core Loop

**Observe logistics → identify bottleneck → invest / change operations → autonomous workers and equipment react → throughput / revenue / congestion change → measure result → reinvest at larger scale.**

The player is not asked to manually carry parcels, drive forklifts or perform worker-level actions.

The product succeeds only if the player can understand:
- what is entering
- where inventory is accumulating
- which stage is constraining flow
- what changed after an operational decision
- why the next investment matters

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

Initial state:
- cash ¥5,000
- 3 workers
- rack capacity 8

Authoritative flow:

Inbound → Store → Rack → Pick → Pack → Ship

Player controls:
- BALANCED
- INBOUND
- SHIP
- Pause / 1× / 2× / 4×

Capital:
- Worker
- Rack
- Worker Speed
- Packing
- Forklift Automation

Forklift Automation is a real Domain logistics behavior, not a decorative animation.

### Rank 1 FTUE

Fresh-save FTUE teaches:
1. observe the facility
2. notice a bottleneck
3. change operating policy
4. open management
5. make an investment
6. read the measured result

FTUE is non-blocking and persists completion separately so experienced saves are not forced through onboarding again.

## 6. Bottleneck / Measurement UX

The player-facing Director exposes the dominant constraint with concrete language.

Current bottleneck families:
- inbound congestion
- rack/storage pressure
- packing congestion
- outbound backlog
- open-order backlog
- stable operation

Major capital measurement window:
- Before: 25 seconds
- After: 25 seconds

Investment result classification:
- 改善
- 横ばい
- 要再判断

Result hierarchy:
1. judgment + shipment delta
2. operational context
3. next action / interpretation

At higher ranks the game should diagnose rather than simply provide a one-tap answer.

## 7. Rank 2 — Warehouse

Rank 2 begins at Logistics Rating 8.

Minimum base crew after promotion: 5 workers.

Staffing presets:
- Receiving 3/1/1
- Balanced 2/2/1
- Picking 1/3/1
- Dock 2/1/2
- Shipping 1/2/2

Reassignment lock: 30 simulated seconds.

This lock makes staffing a strategic intervention rather than a twitch control.

### Rank 2 fixed expansion zones

One choice per zone.

Zone A — Intake:
- Double Dock: higher inbound acceptance / faster arrivals, creates downstream pressure
- Buffer Yard: larger surge capacity without the same arrival-rate gain

Zone B — Storage:
- Fast Pick Rack: lower capacity, faster picks
- High Density Rack: higher capacity, slower picks

Zone C — Packing:
- Parallel Pack: two parallel jobs with slower individual duration
- Fast Pack Cell: one job with much faster duration

All choices must affect Domain behavior and visible 3D geometry.

### Rank 2 workload waves

Deterministic cycle:
- inbound forecast
- inbound surge
- order forecast
- order surge
- dispatch forecast
- dispatch window

The forecast duration is longer than the staffing lock so anticipatory staffing is possible.

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
- schema-v7 persistence

Research showed that scheduled inbound cadence is the first post-routing lever that materially increases shipments. AGV / sorter / ASRS-style candidates are not automatically added unless measurement proves product value.

## 9. Save / Recovery

Current save schema: v7.

Persistence:
- local JSON under `user://`
- primary save
- backup save
- semantic-invalid primary fallback to backup
- autosave every 10 seconds
- save on close / application pause

Save compatibility is a release requirement. Existing valid progression must not be destroyed by ordinary upgrades.

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

## 11. Management UI

Management is a fixed mobile sheet with a vertically scrollable content body.

Requirements:
- header and bottom dock remain reachable
- no horizontal overflow
- touch drag must scroll through controls on iOS/Web and native targets
- multi-line controls reserve sufficient height
- historical Rank 2 choices are compacted at Rank 3 so current decisions stay prominent
- all Rank 3 routing and capital actions remain reachable

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

Native RC target includes no sustained sub-30 FPS behavior during a representative mature Rank 3 scene on target devices.

Provider-neutral analytics records major gameplay events locally. No external analytics provider or data upload is active.

## 15. Current Acceptance Criteria

Code-level acceptance:
- runtime startup is stable
- workers continue executing valid tasks autonomously
- money and shipment count only advance through authoritative delivery
- progression cannot enter a deadlocked no-action state during normal tested paths
- Rank 1 → Rank 2 → Rank 3 can be exercised in simulation
- all Rank 2 facility choices and Rank 3 capital/routing systems have authoritative effects
- save/reload retains mature state
- backup recovery works
- mobile management content is readable and scrollable
- camera can frame the warehouse at useful overview and close distances
- embedded Japanese font is used
- no critical interaction requires hover
- engineering Web export builds successfully

Native acceptance additionally requires:
- signed iOS and Android builds
- cold launch on physical devices
- safe-area verification
- background/resume
- save after app kill/relaunch
- touch input at screen edges
- audio/haptic verification
- sustained Rank 3 performance check

## 16. Current Non-goals

Not required for this RC candidate:
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
- native iOS / Android final targets
- Godot Web as engineering preview only
- local `user://` persistence
- GitHub main as canonical repository baseline

The previous Three.js / PWA-first implementation direction is superseded and must not be restored as the production game path.

## 18. Release Gate

Current label: **Code RC Candidate**, pending RC audit CI.

Do not call the build **Native RC** until:
1. final iOS/Android identifiers are supplied
2. native export presets are finalized
3. signed builds exist
4. physical iPhone and Android QA passes
5. safe area, lifecycle, save, audio, haptics and performance are verified

Store submission and monetization activation remain separate external actions requiring explicit approval.
