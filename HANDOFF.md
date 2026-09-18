# FLOTRA — Development Handoff

Last updated: 2026-09-18 JST

## 1. Product / canonical intent

FLOTRA（フロトラ） is a portrait mobile 3D logistics-management / automation-observer game. The player is the logistics-center owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

**Observe logistics → identify bottleneck → invest / change operations → autonomous workers/equipment react → throughput / revenue / congestion change → measure result → reinvest at larger scale.**

Canonical Meta Loop:

**contract / operating profit → cash + RP + Logistics Rating → larger facility rank → structural investment → new bottleneck → new operating decision → larger profit.**

Domain owns logistics, money, routing, contracts, progression, and measurement verdicts. UI / View must never invent shipments, revenue, ownership, or progression outcomes.

Official title: **FLOTRA（フロトラ）**\nFormer title / migration alias: **LOGISTICS BOSS**\n\nCurrent release label: **Code RC Candidate**. It is **not Native RC**.

## 2. Repository / current GitHub state

Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`

Latest verified presentation/native-prep baseline:
- PR #86 — `Polish final worker parcel and equipment surfaces`
- merge commit: `0c500b686198ba5785a0aac6a9fd5f37b1ac10d9`
- Godot CI #216: **success**
- iOS Export Smoke #47: **success**
- Android Export Smoke #28: **success**
- Rendered Visual Capture #14: **success**
- current Rank 1 / 2 / 3 rendered captures: **human inspected / pass**

Latest product feature merge before presentation/native-prep work:
- PR #76 — `Restore session context for returning players`
- merge commit: `2cfc8c65ca482e8597df9565c4c172bba1aede3d`

Recent QA/product milestones:
- PR #69: authoritative physical queue density for packing/open-order pressure
- PR #70: immediate Rank 2 physical silhouette upgrade
- PR #71: in-world investment / rank-up feedback
- PR #72: Domain-authoritative measurement verdict shared by HUD / audio-haptics / 3D feedback
- PR #73: measurement result → next-decision CTA
- PR #74: real Core Loop E2E smoke
- PR #75: real Meta Loop E2E through Rank 3 using earned operating cash
- PR #76: returning-session resume brief + `session_resume` local instrumentation
- PR #78: synthetic Android APK export route + package / manifest / ARM64 / signature / zip-alignment verification
- PR #79: premium warehouse material / lighting hierarchy
- PR #80: Domain-driven worker / forklift liveness
- PR #81: stronger Rank 3 facility-scale silhouette
- PR #82: CI-rendered Rank 1 / 2 / 3 visual-capture artifact path
- PR #83: rendered-capture-driven Rank framing / Annex / routing composition fixes
- PR #84: 2× MSAA + restrained HUD depth
- PR #85: final 3D depth-lighting balance
- PR #86: final worker / parcel / equipment surface finish

Always re-check GitHub before editing; this document is a handoff snapshot, not a substitute for repository state.

## 3. Technology / targets

- Engine: Godot 4.7.2 Standard
- Language: GDScript
- Renderer: GL Compatibility
- Reference viewport: 390×844 portrait
- Final targets: native iOS + Android
- Godot Web / GitHub Pages: engineering preview only
- Source-controlled export preset: Web only
- iOS smoke route: ephemeral export preset on GitHub-hosted macOS/Xcode
- Android smoke route: ephemeral export preset on GitHub-hosted Linux with JDK 17 / Android SDK 35 and synthetic CI signing

External services currently used:
- GitHub repository
- GitHub Actions
- GitHub Pages engineering preview

Not connected / not active:
- backend / database / accounts
- cloud save
- external analytics upload / crash provider
- IAP / ads
- App Store / Google Play submission

## 4. Canonical product state

### Rank 1 — Small Depot

Initial state: ¥5,000 / 3 workers / rack capacity 8.

Flow:
Inbound → Store → Rack → Pick → Pack → Ship.

Controls:
- BALANCED / INBOUND / SHIP
- pause / 1× / 2× / 4×

Capital:
- Worker
- Rack
- Worker Speed
- Packing
- Forklift Automation

Forklift automation is Domain-authoritative logistics behavior, not fake animation.

Fresh-save FTUE teaches:
observe → identify bottleneck → change operations → open Management → invest → read measured result.

### Rank 2 — Warehouse

Promotion gate: Logistics Rating 8.
Minimum crew: 5.

Staffing presets:
- Receiving 3/1/1
- Balanced 2/2/1
- Picking 1/3/1
- Dock 2/1/2
- Shipping 1/2/2

Reassignment lock: 30 simulated seconds.

Expansion:
- Zone A Intake: Double Dock / Buffer Yard
- Zone B Storage: Fast Pick Rack / High Density Rack
- Zone C Packing: Parallel Pack / Fast Pack Cell

Deterministic forecast/surge workload waves make staffing an anticipatory management decision.

Rank 2 promotion itself now changes the physical facility silhouette via a permanent operations spine, before optional zone purchases.

### Rank 3 — Fulfillment Center

Promotion gate:
- all 3 Rank 2 expansion zones
- equipment assets >= ¥200,000
- live throughput >= 6 shipments/minute

Contracts are optional and are not a Rank 3 gate.

Receiving Annex:
- ¥24,000
- inbound acceptance +14
- visible 3D
- measured
- persisted

Carrier Routing:
- Balanced Parcel: batch 1 / 3.0s / ¥500 per parcel
- Express Dispatch: batch 1 / 1.65s / ¥410 per parcel
- Consolidated Linehaul: batch 4 / 6.8s / ¥620 per parcel

Route / batch / value are frozen at SHIP task start.

High-frequency inbound carrier program:
- Annex required
- ¥30,000
- scheduled inbound interval ×0.85
- visible / persisted / Domain-authoritative

Unvalidated AGV / sorter / ASRS systems must not be added without measured product value.

## 5. Measurement / feedback / continuation UX

Major investments use a 25s Before / 25s After measurement window.

Domain-authoritative verdicts:
- 改善
- 横ばい
- 要再判断

The same verdict drives:
- HUD result copy / color / interpretation
- audio + haptic feedback
- in-world 3D result pulse

Investment/rank-up feedback is short-lived emissive geometry; no dynamic-light or particle-heavy effect was added.

Measurement results can elevate the existing Management button to `次の判断` when another decision is needed. Improved + stable operation remains visually quiet.

Returning sessions now receive a short resume brief derived only from restored Domain state:
- Rank 1: active contract / next rating milestone
- Rank 2: Rank 3 zone / asset / throughput progress
- Rank 3: current bottleneck + existing next growth candidate

Fresh saves / active FTUE do not receive the returning-player brief.

No daily reward, fake login timer, offline-income system, or artificial retention mechanic has been added.

## 6. Save / instrumentation / runtime services

Save schema: v7.

Persistence:
- primary local JSON + backup
- semantic-invalid primary can fall back to backup
- autosave every 10s
- save on close / pause
- FTUE marker persisted separately from economy save

Instrumentation:
- provider-neutral local event layer
- no external upload
- Core / Meta Loop events, FTUE, investments, measurement results, rank-up, session start/suspend/resume are instrumented

Runtime services:
- procedural gameplay feedback audio baseline
- native haptic hooks via `Input.vibrate_handheld`
- FPS health sampling

## 7. QA state

The repository has automated coverage for:
- parse/import
- Domain simulation
- economy pacing
- flow measurement
- Rank 1 / Rank 2 / Rank 3 progression
- workload waves
- Rank 2 facilities / Rank 3 Annex / routing / inbound carrier
- Core Loop E2E
- Meta Loop E2E through Rank 3
- runtime startup
- FTUE
- release HUD / mobile management scroll
- touch orbit + pinch
- save recovery / migration
- release-candidate soak
- Japanese font glyphs
- visual readability
- Web engineering export
- unsigned iOS Xcode-project export smoke
- synthetic Android APK export smoke

Core Loop E2E uses real simulation and real 25-second measurement completion.

Meta Loop E2E uses real shipment contracts and operating profit; it does not inject test cash to fund Rank 2 / Rank 3 growth.

Android Export Smoke #7 verified on the PR #78 head:
- APK export succeeds with Godot 4.7.2
- synthetic package ID is present in the APK
- normal app launch path is present through the generated manifest (`MAIN` / `LAUNCHER` via Godot launcher alias)
- ARM64 native payload is present
- APK debug signature verifies
- zip alignment verifies

This is a technical synthetic export proof, not a production Play candidate.

## 8. Visual implementation state

Canonical visual implementation spec:
- `ART_BIBLE_FLOTRA.md`

Canonical North Star asset:
- `docs/visual/logistics_boss_visual_north_star_2026-09-16.png`

Visual priorities:
Flow readability → Interaction clarity → Bottleneck readability → Visible progression → Stable performance → Premium lighting/materials → Decorative density.

Must preserve:
- open-top / cutaway warehouse
- readable Inbound → Storage → Picking → Packing → Shipping flow
- dark navy / cyan / amber / warm-work-light palette
- visible bottleneck pressure
- autonomous workers / forklift / cargo
- physical Rank growth
- restrained portrait HUD

Current validation state:
- Rank 1 / 2 / 3 are rendered automatically at 390×844 by the Rendered Visual Capture workflow;
- the current post-PR86 captures were human inspected and passed for composition, lighting, HUD balance, Rank progression, parcel/worker/equipment surface finish, and absence of the earlier Rank 3 foreground obstruction;
- this confirms the current CI-rendered presentation baseline, **not** native-device safe area, display scaling, thermal performance, audio, haptics, or real-device touch behavior.

A physical iPhone visual/device pass is still mandatory before Native RC.

## 9. Native export routes — proven synthetic paths

### iOS

Current proven route:
- GitHub-hosted macOS + Xcode
- Godot 4.7.2 + templates
- synthetic CI-only identifiers for automatic smoke
- ephemeral iOS export preset
- unsigned Xcode project export
- Xcode project / framework / PCK payload validation
- `flotra-ios-xcode-smoke` artifact path

PR #86 / iOS Export Smoke #47 artifact was downloaded and manually inspected:
- iOS arm64 `libgodot.a` present
- MoltenVK XCFramework present
- non-empty `LogisticsBoss.pck` present
- `PrivacyInfo.xcprivacy` present
- deployment target 15.0
- portrait-only orientation
- full-screen mode
- synthetic Team ID / Bundle ID correctly injected

Prepared next gate:
- `.github/workflows/ios-device-project-candidate.yml`
- manual-only `workflow_dispatch`
- accepts the confirmed real Apple Team ID + final Bundle ID
- generates and validates an **unsigned** real-identifier Xcode-project artifact
- does not import certificates, sign, install, or distribute anything

Production Apple identifiers / certificates / provisioning profiles are not committed. Signed-device work remains blocked until the account owner supplies/authorizes the signing route.

### Android

Current proven route:
- GitHub-hosted Linux
- Godot 4.7.2 + templates
- JDK 17
- Android SDK 35 toolchain
- synthetic CI-only package ID
- ephemeral Android export preset
- ephemeral debug keystore
- ARM64 APK export
- APK package / launcher manifest / native payload / signature / zip-alignment validation
- short-lived `flotra-android-apk-smoke` artifact

The normal app path uses `package/show_in_app_library=true`. `package/show_as_launcher_app` remains false; that setting is not used to turn this game into an Android home/launcher application.

Production Android package identity, production keystore, release signing, Play AAB candidate, and physical-device QA remain unproven.

## 10. Remaining blockers before Native RC

These are now the primary blockers; do not invent or bypass them.

### iOS
- final Apple Developer Team ID
- final Bundle Identifier
- authorized signing/provisioning material
- signed iOS build / TestFlight candidate
- physical iPhone native QA

### Android
- final package ID
- authorized production release keystore / alias / password through secure export-time inputs
- production-signed APK / AAB candidate; Google Play delivery route still needs the release AAB path
- physical Android QA

Required physical-device pass includes:
- cold launch
- fresh FTUE
- existing schema-v7 load
- kill/relaunch save survival
- background/resume
- safe-area / Dynamic Island / Android navigation clearance
- orbit / pinch at edges and max zoom-out
- Management touch scrolling / no horizontal drift
- audio policy behavior
- haptic behavior
- Rank 1 → 2 → 3 reachability
- all routing modes after save/reload
- 10+ minute mature Rank 3 representative session
- no sustained sub-30 FPS on target device
- current visual inspection against the Art Bible / North Star

Do **not** call the build Native RC until both native platform gates pass.

## 11. External actions requiring explicit user approval

Do not perform without explicit approval:
- Apple / Google developer account purchase or paid renewal
- production signing-key generation / rotation on the user's behalf
- App Store submission
- Google Play submission
- TestFlight / Play external distribution where it creates external impact
- IAP / ads / monetization activation
- external analytics/crash-provider contract or data upload

## 12. Important files

Canonical / design:
- `GAME_DEV_MASTER_RULES.md`
- `GDD_FLOTRA.md`
- `ART_BIBLE_FLOTRA.md`
- `docs/visual/README.md`
- `docs/visual/logistics_boss_visual_north_star_2026-09-16.png`

Runtime:
- `godot/main.gd`
- `godot/domain/warehouse_sim.gd`
- `godot/domain/workload_warehouse_sim.gd`
- `godot/domain/rank3_warehouse_sim.gd`
- `godot/domain/rank3_inbound_carrier_sim.gd`
- `godot/domain/flow_measurement.gd`
- `godot/view/`
- `godot/ui/`
- `godot/persistence/save_store.gd`
- `godot/feedback/game_feel.gd`
- `godot/telemetry/analytics_service.gd`
- `godot/telemetry/runtime_health.gd`

Release / QA:
- `.github/workflows/godot-ci.yml`
- `.github/workflows/godot-preview-pages.yml`
- `.github/workflows/ios-export-smoke.yml`
- `.github/workflows/ios-device-project-candidate.yml`
- `.github/workflows/android-export-smoke.yml`
- `godot/tools/native_release_inputs.py`
- `godot/tools/prepare_ios_export.py`
- `godot/tools/prepare_android_export.py`
- `NATIVE_RELEASE_CHECKLIST.md`
- `DEV_STATUS.json`

## 13. Development rules for the next chat

- Re-check GitHub before editing.
- `main` is canonical baseline; do not infer unpushed/local state.
- Meaningful changes should use branch → PR → CI → merge.
- Do not repeatedly poll the same CI run.
- If CI fails, inspect the failed log once, diagnose, then fix.
- Never say fixed / complete without validation.
- Boot / input / progression blockers outrank polish.
- Do not add fake logistics or fake advanced machinery.
- Do not grow visual-pass layer numbers indefinitely; consolidate presentation responsibilities.
- Public release, Store submission, paid services, signing-material actions, and other external/irreversible operations require explicit approval.

## 14. Immediate next task

Code-level product / QA work and the visual baseline are substantially converged. The current priority is **iPhone native-device gating**, not another presentation or feature pass.

Immediate sequence:
1. obtain the confirmed Apple Developer Team ID and final iOS Bundle Identifier;
2. run the manual `iOS Device Project Candidate` workflow to produce a real-identifier **unsigned** Xcode-project artifact;
3. only after explicit authorization, configure a secure Apple signing/provisioning route and produce an installable signed candidate;
4. run physical iPhone QA: cold launch, fresh FTUE, schema-v7 load, background/resume, kill/relaunch save, Safe Area / Dynamic Island, edge orbit/pinch, Management touch scroll, audio/haptics, Rank 1→2→3, routing after reload, current visual inspection, and 10+ minute mature Rank 3 performance;
5. fix only native-specific defects and rerun regression;
6. complete the equivalent Android production-signing / device gate before declaring Native RC.

Do not infer or invent the Team ID, Bundle ID, certificates, or provisioning material.
