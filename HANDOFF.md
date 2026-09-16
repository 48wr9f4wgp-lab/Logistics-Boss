# LOGISTICS BOSS — Development Handoff

Last updated: 2026-09-16 JST

## 1. Product / Canonical Loop

LOGISTICS BOSS is a portrait mobile 3D logistics-management game. The player is the logistics-center owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

**Observe logistics → identify bottleneck → invest / change operations → workers and equipment react autonomously → throughput / revenue / congestion change → measure results → reinvest at larger scale.**

Economic state, shipment creation, money, queues, routing, capital ownership, and progression are Domain-authoritative. UI / View must never generate shipment revenue or fake logistics state.

Current release label: **Code RC Candidate**. It is **not Native RC** yet.

## 2. Repository / Current Branches

Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Current working branch: `rc/macless-ios-export-ci`
Open PR: **#60 — Mac-less iOS export CI: generate and verify unsigned Xcode project**
PR base: `main`
PR is open and mergeable, but **must not be merged while iOS Export Smoke is red**.

GitHub state at handoff time:
- `main` HEAD: `a19203ed8011d41270ada32219f94c0f185f068e` (`Publish Godot web engineering preview`), parent is PR #59 merge `c82046f81c4a7ec0331833bb7de95494d56ced1a`
- working branch code HEAD before this handoff-doc update: `c8b2cb35d87b6a19f883403058baeb9ad1333398`
- latest normal Godot CI on that code HEAD: run #155, **success**
- latest iOS Export Smoke on that code HEAD: run #9, **failure**

Always re-check GitHub before continuing because this file is a snapshot, not a substitute for repository state.

## 3. Technology / Runtime / External Services

Engine: Godot 4.7.2 Standard
Language: GDScript
Renderer: GL Compatibility
Reference viewport: 390×844 portrait
Final targets: native iOS + Android
Godot Web export: engineering preview only

Production runtime settings include mobile ETC2/ASTC import support (`textures/vram_compression/import_etc2_astc=true`) so Apple/mobile exports have compatible compressed textures.

External services currently used:
- GitHub repository
- GitHub Actions
- GitHub Pages engineering preview

Not connected / not active:
- backend
- database
- auth/accounts
- cloud save
- external analytics provider or upload
- crash provider
- IAP
- ads
- App Store submission
- Google Play submission

## 4. Important Files

Core / composition:
- `godot/main.gd`
- `godot/scenes/main.tscn`
- `godot/project.godot`
- `godot/export_presets.cfg`

Domain:
- `godot/domain/warehouse_sim.gd`
- `godot/domain/workload_warehouse_sim.gd`
- `godot/domain/rank3_warehouse_sim.gd`
- `godot/domain/rank3_inbound_carrier_sim.gd`
- `godot/domain/flow_measurement.gd`
- `godot/domain/capital_catalog.gd`
- `godot/domain/rank2_facility_catalog.gd`
- `godot/domain/progression_system.gd`
- `godot/domain/workload_wave_model.gd`

View / 3D:
- `godot/view/warehouse_view.gd`
- `godot/view/warehouse_view_mobile.gd`
- `godot/view/forklift_automation_view.gd`
- `godot/view/rank2_facility_view.gd`
- `godot/view/rank3_receiving_annex_view.gd`
- `godot/view/rank3_routing_hub_view.gd`
- `godot/view/visual_pass_2.gd`
- `godot/view/visual_pass_3.gd`
- `godot/view/visual_composition_fix.gd`

UI / FTUE:
- `godot/ui/game_hud.gd`
- `godot/ui/game_hud_ja.gd`
- `godot/ui/game_hud_waves.gd`
- `godot/ui/game_hud_rank3.gd`
- `godot/ui/game_hud_ftue.gd`
- `godot/ui/game_hud_feedback.gd`
- `godot/ui/game_hud_release.gd`
- `godot/ui/game_hud_mobile.gd`
- `godot/ui/ftue_coach.gd`

Persistence / feedback / telemetry:
- `godot/persistence/save_store.gd`
- `godot/feedback/game_feel.gd`
- `godot/telemetry/analytics_service.gd`
- `godot/telemetry/runtime_health.gd`

Release / CI:
- `.github/workflows/godot-ci.yml`
- `.github/workflows/godot-preview-pages.yml`
- `.github/workflows/ios-export-smoke.yml` **(PR #60, in progress / red at handoff)**
- `godot/tools/native_release_inputs.py`
- `godot/tools/prepare_ios_export.py` **(PR #60)**
- `godot/native_release_inputs.example.env`
- `NATIVE_RELEASE_CHECKLIST.md`
- `HANDOFF.md`
- `DEV_STATUS.json`
- `GDD_LOGISTICS_BOSS.md`
- `GAME_DEV_MASTER_RULES.md`

## 5. Implemented Product State

### Rank 1 — Small Depot
Initial state: ¥5,000 / 3 workers / rack 8.
Flow: Inbound → Store → Rack → Pick → Pack → Ship.
Controls: BALANCED / INBOUND / SHIP / Pause / 1× / 2× / 4×.
Capital: Worker / Rack / Worker Speed / Packing / Forklift Automation.
Forklift automation is real Domain logistics behavior, not cosmetic animation.

### FTUE
Fresh-save onboarding teaches the core loop: observe bottleneck → change policy → open management → invest → read measured result. Completion is persisted separately from economy save data so experienced saves are not forced through FTUE again.

### Rank 2 — Warehouse
Promotion at Logistics Rating 8, minimum five-person crew.
Staffing presets:
- Receiving 3/1/1
- Balanced 2/2/1
- Picking 1/3/1
- Dock 2/1/2
- Shipping 1/2/2

Reassignment lock: 30 simulated seconds.
Expansion zones:
- Zone A: Double Dock / Buffer Yard
- Zone B: Fast Pick Rack / High Density Rack
- Zone C: Parallel Pack / Fast Pack Cell

Deterministic workload waves provide forecast → surge/window cycles so anticipatory staffing is possible.

### Rank 3 — Fulfillment Center
Gate:
- all 3 Rank 2 expansion zones
- equipment assets >= ¥200,000
- live throughput >= 6 shipments/min

Contracts are optional, not a gate.

Receiving Annex: ¥24,000, inbound acceptance +14, visible 3D, measured, persisted.

Carrier Routing:
- Balanced Parcel: batch 1 / 3.0s / ¥500 per parcel
- Express Dispatch: batch 1 / 1.65s / ¥410 per parcel
- Consolidated Linehaul: batch 4 / 6.8s / ¥620 per parcel

Routing is Domain-authoritative and frozen into SHIP tasks at task start.

High-frequency inbound carrier program:
- requires Annex
- ¥30,000
- scheduled inbound interval ×0.85
- equipment asset
- visible 3D
- schema-v7 persistence

### Measurement / feedback
Major capital uses 25s Before / 25s After. Result classification: 改善 / 横ばい / 要再判断. HUD shows shipment delta, operational context and next action.

### Save / recovery
Save schema v7. Primary + backup recovery; semantic-invalid primary can fall back to backup. Autosave every 10s; save on close/pause. FTUE marker is separate.

### Production-readiness baseline
Implemented:
- procedural feedback audio baseline
- native haptic hooks through `Input.vibrate_handheld`
- provider-neutral local analytics/event layer, no external transmission
- runtime FPS health sampling
- startup smoke
- save recovery smoke
- Rank 1 / Rank 3 soak and save/resume coverage
- mobile orbit/pinch regression coverage
- mobile management scrolling regression coverage

## 6. Verified UI / Mobile State

Real iPhone Safari engineering-preview verification after PR #57 confirmed:
- runtime launches
- max zoom-out frames the warehouse as an operational whole
- Rank 3 management layout is readable
- management content scrolls vertically by touch
- prior right-edge overflow / overlap blockers are closed

This is Web/Safari verification only. It does not prove native iOS or Android behavior.

Visual direction:
- dark navy industrial base
- cyan technology accent
- amber/orange safety accent
- warm local lighting
- stylized premium mobile readability
- open-top / cutaway facility
- warehouse operation remains the visual focus
- do not restore roof/truss geometry that obstructs logistics flow

## 7. PR #60 — Current Work: Mac-less iOS Export CI

Goal: prove the first iOS native-export gate on GitHub-hosted macOS/Xcode without a local Mac and without inventing production Apple identifiers.

Files changed by PR #60 before this HANDOFF update:
- `.github/workflows/ios-export-smoke.yml`
- `NATIVE_RELEASE_CHECKLIST.md`
- `godot/project.godot`
- `godot/tools/prepare_ios_export.py`

Implemented on the branch:
- ephemeral iOS export-preset generator
- validates Team ID / Bundle ID via existing validator
- refuses duplicate iOS target in base preset
- keeps committed `godot/export_presets.cfg` Web-only
- synthetic CI-only Team ID / Bundle ID
- macOS-14 runner + Xcode + Godot 4.7.2 export templates
- macOS parse/import of the real project
- unsigned project-only iOS export
- payload validation and intended Artifact upload
- mobile ETC2/ASTC texture-import setting in `godot/project.godot`

Production identifiers, certificates, provisioning profiles and signing secrets are **not** committed.

## 8. Exact Current Failure — iOS Export Smoke #9

Normal Godot CI #155 is green.

`Logistics Boss iOS Export Smoke` run #9 is red at the payload-validation step, **after Godot successfully generated the iOS Xcode project payload**.

Observed generated files include:
- `ios-build/LogisticsBoss.xcodeproj/project.pbxproj`
- `ios-build/LogisticsBoss/LogisticsBoss-Info.plist`
- `ios-build/LogisticsBoss.xcframework/Info.plist`
- `ios-build/LogisticsBoss.xcframework/ios-arm64/libgodot.a`
- `ios-build/MoltenVK.xcframework/Info.plist`
- `ios-build/LogisticsBoss.pck`

The validator currently searches specifically for a file named `data.pck`, so it reports:

`Missing non-empty data.pck in generated iOS payload`

But Godot generated the project pack as **`ios-build/LogisticsBoss.pck`**. Therefore the immediate failure is the smoke-test filename assumption, not evidence that the iOS Xcode project failed to generate.

There is also a Godot warning during export:
`Property not found: application/boot_splash/fullsize`
This is currently a warning, not the run #9 failure. Do not hide it; assess later if it becomes relevant to native launch-screen quality.

GitHub Actions also emits a Node 20 deprecation warning for `actions/checkout@v4` being forced onto Node 24. This is not the run #9 failure.

## 9. Immediate Next Task

**First re-check GitHub / PR #60 / current branch before editing.** Do not assume this snapshot is still current.

If state is unchanged, fix `.github/workflows/ios-export-smoke.yml` so PCK validation accepts the actual project-pack output instead of requiring the literal filename `data.pck`.

Likely safe condition: require at least one non-empty `*.pck` in `ios-build`, and preferably assert/print the actual path (`ios-build/LogisticsBoss.pck` on run #9). Keep the checks for `.xcodeproj`, Info.plist, `libgodot.a`, MoltenVK, and engine/script errors.

Then:
1. commit the CI fix to `rc/macless-ios-export-ci`
2. let PR CI start
3. check each new CI run at most once per conversation turn; do **not** poll in a loop
4. if iOS smoke fails, fetch the failed job log once, diagnose, fix
5. if normal Godot CI and iOS Export Smoke are both green, verify Artifact exists
6. only then merge PR #60

## 10. PR #60 Completion Conditions

PR #60 is complete only when:
- normal Godot CI is green
- iOS Export Smoke is green
- macOS parse/import passes
- unsigned iOS Xcode project payload is generated
- required Xcode/framework/PCK files are validated
- `logistics-boss-ios-xcode-smoke` Artifact uploads successfully
- no production Apple identifier/signing secret is committed
- committed `godot/export_presets.cfg` remains Web-only
- PR #60 is merged to `main`

Do not call the route proven until the green smoke + Artifact are actually observed.

## 11. Native Release Inputs / Secrets

The repository provides:
- `godot/native_release_inputs.example.env`
- `godot/tools/native_release_inputs.py`

Expected variable names:

### iOS
- `LOGISTICS_BOSS_IOS_TEAM_ID`
- `LOGISTICS_BOSS_IOS_BUNDLE_ID`

### Android
- `LOGISTICS_BOSS_ANDROID_PACKAGE`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

Do not place actual passwords, private keys, certificates or keystore secrets in chat, source control, HANDOFF, or committed env files.

`godot/export_presets.cfg` is intentionally Web-only in source control. Native production presets should be produced only from confirmed real identifiers, preferably ephemerally at build time.

## 12. Remaining Native / Release Work — Priority Order

P0 — Finish PR #60 and prove unsigned macOS CI export.

P0 — Obtain/confirm real iOS Apple Developer Team ID and final Bundle Identifier. Do not invent them.

P0 — Establish authorized Apple signing/provisioning in CI and produce signed iOS build/TestFlight candidate. No paid account purchase or Store action without explicit user approval.

P0 — Physical iPhone native QA: cold launch, fresh FTUE, schema-v7 save/load, kill/relaunch, background/resume, Safe Area/Dynamic Island, touch orbit/pinch, management scroll, audio, haptics, Rank 1→2→3, routing modes, sustained Rank 3 performance.

P0 — Confirm final Android package ID and signing inputs; add Android native export route and signed APK/AAB candidate.

P0 — Physical Android QA equivalent to iOS native gate.

P1 — Fix native-specific issues discovered by physical-device QA and repeat build → test → regression until clean.

P1 — Declare **Native RC** only after both platform gates pass.

P2 — Store metadata/assets/privacy/support/price/distribution preparation, TestFlight/Play internal testing, Store submission. These are external release actions and require explicit approval where applicable.

## 13. Important Design Decisions / Reasons

- **Godot native-first, Web preview only:** final product is native mobile; the old Three.js/PWA-first direction is superseded.
- **Domain-authoritative economy/logistics:** prevents UI animation from manufacturing shipment/revenue state and keeps testing meaningful.
- **Major capital must be visible + authoritative + measurable:** avoids numeric-only upgrades and keeps the management fantasy legible.
- **Rank 2 staffing lock + deterministic forecasts:** makes staffing anticipatory management rather than twitch micromanagement.
- **Rank 3 carrier program chosen after simulation research:** increased scheduled inbound cadence materially increased shipments; several AGV/sorter/ASRS-style or downstream candidates did not prove throughput value.
- **Native identifiers are never guessed:** Bundle/package IDs become durable external product identity; signing material is account-owned and secret-bearing.
- **Ephemeral native export presets:** keeps fake/secret production identity out of committed source while allowing CI export.
- **Mac-less first iOS gate:** GitHub-hosted macOS/Xcode is used to avoid forcing a Mac purchase before the route is technically proven.

## 14. Rejected / Avoided Changes

Do not restore or introduce without new evidence/approval:
- production Three.js `/docs` implementation or PWA-first path
- manual parcel carrying / manual forklift-driving core gameplay
- UI/View-generated money or shipments
- fake automation visuals disconnected from Domain behavior
- AGV / sorter / ASRS / cross-dock as automatic feature additions without measurement proving product value
- mandatory contracts as Rank 3 gate
- roof/truss geometry that obstructs warehouse flow
- SystemFont for Japanese; embedded Japanese font is required
- `visual_pass_4`, `visual_pass_5`, etc. layer proliferation; consolidate instead
- placeholder production Bundle IDs / Android package IDs
- signing secrets committed to repository
- declaring fixes complete without build/test/runtime verification

## 15. Build / Test / Deployment Rules

Canonical development loop:
**build → automated test → browser/device verify where applicable → regression**.

Main normal CI is broad and covers startup, Domain, Rank 2/3, FTUE, mobile input, save recovery, soak, visual/font/full-scene, release services and Web export.

Web engineering preview:
`https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`

Pages success is not equivalent to native success.

For CI investigation: never repeatedly poll when no state changes. Check once per user turn. If running, report/stop. If failed, fetch logs once and fix. If a new CI starts after a fix, check it once; if still running/queued, stop.

## 16. Local / Uncommitted State

No local working tree was available to this handoff update; development was performed directly against GitHub through repository actions. Therefore local/uncommitted files are **not inspectable**. Do not claim they are clean on an unknown local machine.

GitHub branch changes are committed. At the handoff snapshot, the known unfinished work is committed on `rc/macless-ios-export-ci` and represented by open PR #60; it is not merged to `main`.

## 17. Documentation State

`HANDOFF.md`: exists and was updated on `rc/macless-ios-export-ci` specifically for this PR #60 handoff.

`GDD_LOGISTICS_BOSS.md`: synchronized to Code RC / Godot-native direction on 2026-09-16.

`NATIVE_RELEASE_CHECKLIST.md`: updated by PR #60 with Mac-less iOS bootstrap flow, but its prose describes the intended smoke behavior; the actual smoke is still red until the PCK validation bug is fixed.

`DEV_STATUS.json`: exists but is stale relative to PR #60; it still describes native iOS as blocked on identifiers/signing/device QA and does not record the in-progress Mac-less export smoke. Trust current GitHub/CI state over it until refreshed.

## 18. Native RC Definition

Do not call LOGISTICS BOSS Native RC until all are true:
1. final iOS/Android identifiers confirmed
2. signed native builds produced
3. physical iPhone QA passes
4. physical Android QA passes
5. safe area / lifecycle / save / touch / audio / haptic behavior verified
6. representative Rank 3 performance has no sustained sub-30 FPS condition on target devices

Store submission is a later external action, not part of the Native RC definition.
