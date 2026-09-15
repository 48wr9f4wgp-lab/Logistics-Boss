# LOGISTICS BOSS — Development Handoff

Last updated: 2026-09-16 JST

## 1. Product / Canonical Loop

LOGISTICS BOSS is a portrait mobile 3D logistics-management game. The player is the owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

**Observe logistics → identify bottleneck → invest / change operations → workers and equipment react autonomously → throughput / revenue / congestion change → measure results → reinvest at larger scale.**

Economic state, shipment creation, money, queues, routing, and progression are Domain-authoritative. UI / View must never generate shipment revenue or fake logistics state.

Current stage: **code-level RC candidate audit**. Not Native RC yet.

## 2. Repository / Technology

Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
Reference viewport: portrait 390×844
Final targets: native iOS + Android
Godot Web export: engineering preview only

Preview:
`https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`

No production backend / DB / auth / cloud save / IAP / ads / external analytics / crash provider is connected.

## 3. Current Verified State

Merged production-readiness work:
- PR #54: game feel, provider-neutral analytics, runtime health, save recovery, soak tests, release checklist
- PR #55: first mobile sheet/camera correction
- PR #56: Rank 3 management layout and close-zoom framing correction
- PR #57: reliable iOS/Web touch scrolling and true portrait overview framing

Real iPhone Safari verification after PR #57 confirmed:
- runtime launches correctly
- warehouse can be viewed as an operational whole at max zoom-out
- Rank 3 management UI is readable
- management content scrolls vertically on touch
- no right-edge overflow in the verified management state

These results close the previous Web/mobile P0 UX blockers. They do **not** replace native iOS/Android QA.

## 4. Save / Lifecycle

Current save schema: **v7**.

Persistence:
- `godot/persistence/save_store.gd`
- primary JSON save plus backup recovery
- semantic-invalid primary can fall back to backup
- autosave every 10 seconds
- save on close / application pause

FTUE completion is persisted separately so experienced saves are not forced through onboarding again.

## 5. Rank 1 — Small Depot

Initial state:
- ¥5,000
- 3 workers
- rack capacity 8

Flow:
Inbound → Store → Rack → Pick → Pack → Ship

Controls:
- BALANCED / INBOUND / SHIP
- Pause / 1× / 2× / 4×

Capital:
- worker
- rack
- worker speed
- packing
- forklift automation

Fresh-save FTUE teaches:
1. observe a bottleneck
2. change operating policy
3. open management
4. invest
5. read measured Before/After result

## 6. Rank 2 — Warehouse

Rank 2 begins at Logistics Rating 8 and grants a five-person base crew.

Staffing presets:
- Receiving 3/1/1
- Balanced 2/2/1
- Picking 1/3/1
- Dock 2/1/2
- Shipping 1/2/2

Reassignment lock: 30 simulated seconds.

Fixed one-of-two expansion zones:
- Zone A Intake: Double Dock / Buffer Yard
- Zone B Storage: Fast Pick Rack / High Density Rack
- Zone C Packing: Parallel Pack / Fast Pack Cell

Deterministic workload waves create forecast → surge / window cycles so the player can reposition staff before pressure arrives.

## 7. Rank 3 — Fulfillment Center

Canonical Rank 3 gate:
- all 3 Rank 2 expansion zones
- equipment assets >= ¥200,000
- live throughput >= 6 shipments/min

Contracts are optional and are **not** a Rank 3 gate.

### Receiving Annex
- one-time
- ¥24,000
- inbound acceptance +14
- visible 3D
- measured Before/After
- schema-v7 persistence

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

Routing is Domain-authoritative and frozen into SHIP tasks at task start.

### High-frequency inbound carrier program
- one-time
- requires Receiving Annex
- ¥30,000
- scheduled inbound interval ×0.85
- counted in equipment assets
- visible 3D state
- schema-v7 persistence

## 8. Measurement / Game Feel / Telemetry

Canonical major-capital measurement: 25s Before / 25s After.

Investment result UI classifies:
- 改善
- 横ばい
- 要再判断

Game feel:
- procedural feedback audio baseline
- `Input.vibrate_handheld` hooks for native haptics
- shipment feedback throttled to avoid spam

Telemetry:
- provider-neutral local event layer only
- no external transmission
- events cover session, FTUE, policy/staffing, contracts, investments, routing, rank-up, measurement results and sampled shipment milestones

Runtime health samples average FPS, minimum FPS and low-FPS ratio. Native performance remains unverified until physical-device builds exist.

## 9. RC QA Coverage

CI covers:
- parse/import
- Rank 1/2/3 Domain smoke and pacing
- Rank 2/3 UI and 3D smoke
- runtime startup
- FTUE core loop
- release services
- mobile input / camera framing
- management touch scrolling
- save recovery
- long-running Rank 1 / Rank 3 soak
- Japanese font glyphs
- visual readability
- full-scene runtime
- Web engineering-preview export

The RC audit additionally guards release project settings and prevents fake native production presets from being committed before real identifiers are supplied.

## 10. Current Native Blockers

See `NATIVE_RELEASE_CHECKLIST.md`.

Required before final native export presets / signed builds:

### iOS
- Apple Developer Team ID
- final Bundle Identifier
- Xcode signing/provisioning

### Android
- final application package identifier
- release keystore
- key alias
- signing credentials stored outside source control

Final Native RC requires at least one physical iPhone and one physical Android pass for cold launch, FTUE, save/relaunch, background/resume, safe areas, touch orbit/pinch, audio/haptics and sustained Rank 3 performance.

## 11. External Actions Requiring Explicit Approval

Do not perform automatically:
- App Store submission
- Google Play submission
- paid developer-account purchase or renewal
- external analytics/crash provider activation or data upload
- IAP / ads / monetization activation
- production signing-key generation/rotation on behalf of the user

## 12. Immediate Next Gate

1. Keep the code-level RC audit branch green.
2. Merge only after CI passes.
3. Do one Web Preview regression check if the audit changes runtime code or UI.
4. Then collect native identifiers/signing inputs.
5. Create native export presets and signed builds.
6. Run physical iPhone + Android QA.
7. Only then declare **Native RC**.
