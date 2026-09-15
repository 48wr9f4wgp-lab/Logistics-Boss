# LOGISTICS BOSS — Development Handoff

Last updated: 2026-09-15 JST

## 1. Product / Canonical Loop

LOGISTICS BOSS is a portrait mobile 3D logistics-management game. The player is the owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

**Observe logistics → identify bottleneck → invest / change operations → workers and equipment react autonomously → throughput / revenue / congestion change → measure results → reinvest at larger scale.**

Economic state, shipment creation, money, queues, routing, and progression are Domain-authoritative. UI / View must never generate shipment revenue or fake logistics state.

Current stage: **RC candidate preparation**. Not Native RC yet.

## 2. Repository / Current Sprint

Repository: `48wr9f4wgp-lab/Logistics-Boss`

Canonical branch: `main`

Production-readiness branch: `rc/production-readiness-sprint`

Open PR: **#54 Production readiness sprint: game feel, telemetry, recovery and RC QA**

PR target:
- consolidate remaining product-quality work into one sprint
- stop one-fix-at-a-time PR churn
- reach a code-level RC candidate before native signing/device QA

## 3. Technology / Platform

- Godot 4.7.2 Standard
- GDScript
- GL Compatibility
- portrait 390×844 reference
- touch orbit / pinch zoom
- final targets: native iOS + Android
- Godot Web export: engineering preview only

Engineering preview:

`https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`

No production backend / DB / auth / cloud save / IAP / ads / external analytics / crash provider is connected.

## 4. Current Save Schema

Current schema: **v7**.

v7 includes:
- Rank 3 Carrier Routing
- Receiving Annex ownership
- High-frequency inbound carrier program ownership

Persistence:
- `godot/persistence/save_store.gd`
- primary JSON save
- previous committed save retained as `.bak`
- production-readiness sprint adds fallback to backup when primary JSON is syntactically valid but semantically unloadable (for example unsupported schema)

## 5. Rank 1

Core flow:
Inbound → Store → Rack → Pick → Pack → Ship.

Initial state:
- ¥5,000
- 3 workers
- rack capacity 8

Rank 1 controls:
- Balance
- Inbound
- Ship
- Pause / 1× / 2× / 4×

Capital:
- worker
- rack
- worker speed
- packing
- forklift automation

Fresh-save FTUE teaches:
1. observe bottleneck
2. change operating policy
3. open management
4. invest and read Before/After measurement

FTUE completion is persisted separately and experienced saves are not forced through it again.

## 6. Rank 2 Warehouse

Rank 2 begins at Logistics Rating 8 and grants a five-person base crew.

Staffing presets:
- Receiving 3/1/1
- Balanced 2/2/1
- Picking 1/3/1
- Dock 2/1/2
- Shipping 1/2/2

Reassignment lock: 30 simulated seconds.

Fixed expansion zones, one-of-two per zone:

Zone A Intake:
- Double Dock
- Buffer Yard

Zone B Storage:
- Fast Pick Rack
- High Density Rack

Zone C Packing:
- Parallel Pack
- Fast Pack Cell

Workload waves are deterministic and forecastable:
- inbound forecast / surge
- order forecast / surge
- dispatch forecast / window

## 7. Rank 3 Fulfillment Center

Canonical Rank 3 gate:
- all 3 Rank 2 zones
- equipment assets >= ¥200,000
- live throughput >= 6 shipments/min

Contracts are optional and are not a Rank 3 gate.

### Receiving Annex
- one-time
- ¥24,000
- inbound acceptance +14
- 25s Before/After
- save/load
- visible 3D

### Carrier Routing
Balanced Parcel:
- batch 1
- dispatch 3.0s
- ¥500 / parcel

Express Dispatch:
- batch 1
- dispatch 1.65s
- ¥410 / parcel

Consolidated Linehaul:
- batch 4
- dispatch 6.8s
- ¥620 / parcel

Routing state is Domain-authoritative and frozen into SHIP tasks at task start so route changes cannot reprice in-flight shipments.

### High-frequency inbound carrier program
- one-time
- requires Receiving Annex
- ¥30,000
- scheduled inbound interval ×0.85
- counted in equipment assets
- schema v7 persistence
- visible 3D state on Receiving Annex

Research showed scheduled inbound cadence is the first post-routing lever that materially increases shipments; prior AGV / sorter / ASRS-style candidates did not automatically earn production adoption.

## 8. Measurement / Player Feedback

Canonical capital measurement: 25s Before / 25s After.

Investment result UI now classifies:
- 改善
- 横ばい
- 要再判断

Display hierarchy:
1. judgment + shipment delta
2. operational context
3. next action

Release HUD adds compact actionable bottleneck guidance without adding another permanent HUD layer.

## 9. Production-Readiness Services in PR #54

### Game feel
`godot/feedback/game_feel.gd`

- procedural short feedback tones; no external audio asset dependency
- native haptic hooks through `Input.vibrate_handheld`
- shipment haptics throttled to avoid high-throughput vibration spam
- stronger feedback for investment / contract / Rank Up

### Analytics foundation
`godot/telemetry/analytics_service.gd`

Provider-neutral local event layer. It does **not** transmit user data externally.

Instrumented events include:
- session start / suspend
- FTUE step / complete / skip
- policy and staffing changes
- contracts
- investments
- routing
- facility rank-up
- investment measurement results
- sampled shipment milestones

An external analytics provider can be attached later through a callable provider adapter after explicit approval.

### Runtime health
`godot/telemetry/runtime_health.gd`

Samples:
- average FPS
- minimum FPS
- low-FPS seconds / ratio

Physical-device performance remains unverified until native builds exist.

## 10. RC QA Added in PR #54

New coverage:
- `release_services_smoke.gd`
- `release_hud_smoke.gd`
- `mobile_input_smoke.gd`
- `save_recovery_smoke.gd`
- `release_candidate_soak.gd`

Soak targets:
- fresh Rank 1 autonomous shipping
- save / restore and resumed shipping
- synthetic mature Rank 3
- Balanced / Express / Consolidated routes
- non-negative queues/economy
- schema-v7 late-game save / restore
- resumed Rank 3 shipping after restore

Existing CI still includes Rank 1/2/3 Domain, pacing, UI, 3D, font, full-scene runtime, and Web export coverage.

## 11. Native Release Blockers

See `NATIVE_RELEASE_CHECKLIST.md`.

Do not guess production identifiers.

Required before final export presets / signed builds:

### iOS
- Apple Developer Team ID
- final Bundle Identifier
- Xcode signing/provisioning

### Android
- final package identifier
- release keystore / alias
- signing credentials outside repository

Final Native RC also requires a physical iPhone and Android pass for:
- cold launch
- FTUE
- save/relaunch
- background/resume
- Safe Area
- touch orbit/pinch
- audio/haptics
- sustained performance

## 12. External Actions Requiring Explicit Approval

Do not perform automatically:
- App Store / Google Play submission
- paid developer-account purchase
- external analytics/crash provider activation
- IAP / ads / monetization activation
- production signing-key operations

## 13. Immediate Next Gate

1. Let PR #54 CI finish.
2. If failed, inspect exact failing step once and repair the consolidated branch.
3. When green, merge PR #54.
4. Verify Web Preview regression once.
5. Then collect native identifiers/signing inputs and move to signed iOS/Android builds.

Do not call this Native RC until physical-device native verification is complete.
