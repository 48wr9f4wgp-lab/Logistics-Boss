# FLOTRA — Development Handoff

Last updated: 2026-09-18 JST

## 0. Core Experience v2 reset — 2026-09-18

Repeated iPhone Web playtest invalidated the prior assumption that FLOTRA only needed native-device polish before GREENLIGHT.

Observed product failures:
- facility/equipment growth was not legible enough during ordinary play;
- Management was difficult to parse and action → consequence was unclear;
- play drifted toward repeatedly buying available upgrades;
- meaningful equipment/decision variety became repetitive too quickly.

Therefore FLOTRA has deliberately moved **DEVICE_VALIDATION → VERTICAL_SLICE** for a targeted **Core Experience v2** rework.

Canonical implementation packet:
- `VERTICAL_SLICE_V2_CHANGE_PACKET.md`

Core Experience v2 locks:
- 3D warehouse is the primary game board;
- normal equipment decisions start from warehouse Zones;
- Director shows symptoms/evidence, not the answer;
- Management becomes an executive dashboard;
- major equipment has visible geometry + authoritative effect + strength + weakness + measurement;
- Rank 2 Zone equipment is replaceable by paid renovation;
- current slice = full Rank 1 v2 + Rank 2 STORAGE/PACKING only;
- do not add the remaining Rank 2 Zones or redesign Rank 3 until the slice passes playtest.

Existing simulation/save/CI/export evidence is preserved. It is not sufficient proof that the v2 Core Experience works.

### Interaction Skeleton — DONE

PR #107 — `Add Vertical Slice v2 interaction skeleton`
- merge commit: `185aeed749d1c390c14dc46934055e8fa1173b50`
- Godot CI #265: **success**
- iOS Export Smoke #86: **success**
- Rendered Visual Capture #63: **success**
- Android Export Smoke #77: **success** (historical technical reference only)
- dedicated v2 interaction skeleton smoke: **success**
- fresh Rank 1 portrait render: **human inspected / pass**

Verified player-facing v2 shell:
- five physical 3D Zone targets: INBOUND / STORAGE / PICKING / PACKING / SHIPPING;
- touch/raycast Zone selection;
- lower-sheet Zone Panel with authoritative evidence and separate OPERATIONS / CAPITAL hierarchy;
- Director reports symptoms/evidence and no longer prescribes the equipment answer;
- RP is hidden from the primary mobile HUD;
- mobile Management is an Overview/dashboard shell;
- legacy repeated upgrades, Rank 2 Zone purchase buttons, and old staffing presets are hidden from the player-facing mobile Management path;
- all five Zone labels are readable in the default 390×844 portrait capture after evidence-driven scale/framing corrections.

This is **Interaction Skeleton evidence only**. Rank 1 v2 structural projects, direct Zone staffing, Rank 2 renovation, and the new event-driven onboarding are not yet implemented.


## 1. Product / canonical intent

FLOTRA（フロトラ） is a portrait mobile 3D logistics-management / automation-observer game. The player is the logistics-center owner / operations manager, not a manual parcel carrier or forklift driver.

Canonical Core Loop:

**Observe logistics → identify bottleneck → invest / change operations → autonomous workers/equipment react → throughput / revenue / congestion change → measure result → reinvest at larger scale.**

Canonical Meta Loop:

**contract / operating profit → cash + RP + Logistics Rating → larger facility rank → structural investment → new bottleneck → new operating decision → larger profit.**

Domain owns logistics, money, routing, contracts, progression, and measurement verdicts. UI / View must never invent shipments, revenue, ownership, or progression outcomes.

Official title: **FLOTRA（フロトラ）**
Former title / migration alias: **LOGISTICS BOSS**

## 1.1 Platform / state

- ACTIVE_PHASE: **VERTICAL_SLICE**
- DEVELOPMENT_TARGET: **iPhone / iOS**
- PRODUCTION_DECISION: **UNDECIDED**
- RELEASE_APPROVAL: **NOT_REQUESTED**
- PRIMARY_INPUT: **touch**
- REAL_DEVICE_ACCESS: **AVAILABLE — user's iPhone / repeated testing available**
- MAC_XCODE_ACCESS_PATH: **BLOCKED — no Mac currently available**
- Native physical-iPhone lane: **DEFERRED BY USER until Mac/Xcode access returns**
- Status label: **PRE-GO / VERTICAL_SLICE v2 REWORK**

The current active phase is VERTICAL_SLICE because real iPhone Web play exposed a Core Experience failure. Native physical-iPhone DEVICE_VALIDATION remains deferred while Mac/Xcode access is unavailable and will resume only after the v2 slice passes its own playtest/CI/visual checks. The native blocker remains acknowledged and is not treated as a passed gate. See `DEVICE_VALIDATION_ACCESS.md`.

## 2. Repository / current GitHub state

Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`

Current verified main baseline:
- PR #107 — `Add Vertical Slice v2 interaction skeleton`
- merge commit: `185aeed749d1c390c14dc46934055e8fa1173b50`
- Godot CI #265: **success**
- iOS Export Smoke #86: **success**
- Android Export Smoke #77: **success** (historical technical evidence only; Android remains out of active Pre-GO scope)
- Rendered Visual Capture #63: **success**
- fresh Rank 1 390×844 capture: **human inspected / pass**
- all five Zone labels readable in the default portrait frame
- v2 Zone Panel / Director / mobile Management shell covered by dedicated automated smoke
- legacy technical/save/progression evidence from PRs #97–#103 remains preserved where not superseded by Core Experience v2

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
- PR #95: aggregate high-speed shipment toasts
- PR #96: make the warehouse the portrait visual hero; compact HUD/measurement stack + closer framing
- PR #97: progression/resource dead-end audit across zero-cash Rank 1/2/3 recovery paths
- PR #99: FTUE remains active until the authoritative measurement result; Core Loop is not declared learned at purchase time
- PR #101: exhaustive 510s Rank 2 staffing frontier exposed and fixed an always-Shipping near-dominant non-decision; final adaptive frontier = 212 shipments vs best fixed 202
- PR #103: fresh rendered-capture audit found Rank 2 growth too subtle; widened the persistent operations mezzanine/crown and added rear service modules so Rank 2 reads as a larger facility while Rank 3 remains the larger step
- PR #107: Core Experience v2 Interaction Skeleton — five 3D Zone targets, Zone Panel, symptom-only Director, Management dashboard shell, RP removed from primary HUD, legacy mobile purchase/preset controls hidden; CI #265 / iOS #86 / Render #63 passed and fresh portrait capture human-inspected

Always re-check GitHub before editing; this document is a handoff snapshot, not a substitute for repository state.

## 3. Technology / targets

- Engine: Godot 4.7.2 Standard
- Language: GDScript
- Renderer: GL Compatibility
- Reference viewport: 390×844 portrait
- Active development target: native iPhone / iOS
- Android: not an active production target Pre-GO; retain existing smoke evidence only and defer any active Android work until PRODUCTION_DECISION=GO plus a separate PLATFORM_EXPANSION_DECISION
- Godot Web / GitHub Pages: engineering preview only
- Source-controlled export preset: Web only
- iOS smoke route: ephemeral export preset on GitHub-hosted macOS/Xcode
- Android smoke route: historical technical evidence only; not an active Pre-GO production route

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

## 4. Preserved legacy implementation baseline

The implementation details below describe the preserved pre-v2 baseline. Where they conflict with Core Experience v2, `VERTICAL_SLICE_V2_CHANGE_PACKET.md` and the synchronized `GDD_FLOTRA.md` take precedence. Do not delete useful legacy Domain/save/Rank 3 code merely because it is outside the v2 slice.

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
observe → identify bottleneck → change operations → open Management → invest → remain in the guide through the real measurement window → read the authoritative measured verdict → continue to the next decision.

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
  - Fast Pick Rack: storage +12, PICK 25% faster
  - High Density Rack: storage +16, PICK 14% slower
- Zone C Packing: Parallel Pack / Fast Pack Cell

Deterministic forecast/surge workload waves make staffing an anticipatory management decision.

Rank 2 promotion itself now changes the physical facility silhouette via a permanent widened operations spine with rear service modules, before optional zone purchases. This was strengthened in PR #103 after fresh 390×844 captures showed the earlier thin rear-crown delta was too subtle at a glance.

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
- Rendered Visual Capture #53 after PR #103 was downloaded and human inspected;
- Rank 2 now shows a materially stronger persistent rear facility mass/crown than Rank 1, while Rank 3 still reads as the larger facility-scale step;
- no new foreground obstruction or HUD regression was observed in the fresh Rank 1 / 2 / 3 captures;
- this confirms the current CI-rendered presentation baseline, **not** native-device safe area, display scaling, thermal performance, audio, haptics, or real-device touch behavior.

A physical iPhone visual/device pass is mandatory before GREENLIGHT.

## 9. Pre-GO technical export evidence — not release enablement

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

Prepared but **not active as the current Pre-GO gate**:
- `.github/workflows/ios-device-project-candidate.yml`
- manual-only `workflow_dispatch`
- can validate a supplied Team ID / Bundle ID without signing or distribution

For DEVICE_VALIDATION, do not require final production identifiers. Use only the minimum development signing / provisioning route needed to reach a representative physical iPhone, if such signing is required. Production Apple identifiers / certificates / provisioning operations remain deferred until after GREENLIGHT unless a minimal technical spike is necessary to reach the device.

### Android

Existing Android export smoke is retained as **historical technical evidence only**. Android is not an active production target during Pre-GO. Do not spend active implementation / signing / device-QA effort on Android until PRODUCTION_DECISION=GO and a separate PLATFORM_EXPANSION_DECISION authorizes it.

## 10. DEVICE_VALIDATION blockers and exit evidence

Current blockers:
- REAL_DEVICE_ACCESS is available, but the exact representative iPhone model / iOS version is still unrecorded
- MAC_XCODE_ACCESS_PATH is blocked because no Mac is currently available
- an installable **development** iOS build path to the representative iPhone is not yet verified

These are DEVICE_VALIDATION blockers. Final production Team ID / Bundle ID, production signing, TestFlight, App Store Connect, Store assets, and Android production work are **not** blockers for this phase.

Required physical-iPhone evidence across multiple sessions includes:
- cold launch
- fresh FTUE
- existing schema-v7 load
- kill / relaunch save survival
- suspend / resume / interruption recovery
- Safe Area / Dynamic Island / readability
- orbit / pinch at edges and max zoom-out
- Management touch scrolling / no horizontal drift
- audio policy behavior
- haptic behavior
- Core Loop comprehension speed
- reward / growth recognition
- Rank 1 → Rank 2 → Rank 3 reachability
- all routing modes after save / reload
- 10+ minute mature Rank 3 representative session
- FPS / frame pacing
- thermal / battery tendency
- no sustained sub-30 FPS during representative mature Rank 3
- current visual inspection against the Art Bible / North Star
- no progression dead-end / resource dead-end

After sufficient evidence, enter **GREENLIGHT** and record **GO / HOLD / KILL**. PRODUCTION_DECISION remains UNDECIDED until that decision.

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

FLOTRA remains in **ACTIVE_PHASE = VERTICAL_SLICE** for Core Experience v2.

### LAST VERIFIED DONE

**Interaction Skeleton — DONE / PR #107**

Verified:
- five 3D Zone targets and touch/raycast selection;
- Zone Panel lower-sheet shell;
- symptom-only Director;
- Management Overview/dashboard shell;
- RP hidden from primary mobile HUD;
- legacy repeated upgrade / Rank 2 facility purchase / staffing preset controls hidden from the player-facing mobile path;
- Godot CI #265 / iOS Export Smoke #86 / Rendered Visual Capture #63 green;
- fresh 390×844 Rank 1 render human-inspected with all five Zone labels readable.

The legacy Management-first FTUE is intentionally hidden on the production mobile v2 path. The old non-mobile FTUE/Core Loop smoke remains only as regression evidence for preserved technical behavior until the new Rank 1 v2 onboarding replaces it.

### NEXT — Rank 1 v2

Implement as the next small, reviewable PR:

1. **Rack Wing** — visible storage expansion with authoritative capacity effect;
2. **Second Packing Bench** — visible parallel packing project with authoritative packing effect;
3. **Worker Hire** — one meaningful additional worker, avoiding repeated hire-button spam;
4. **Forklift Project** — keep authoritative inbound→storage automation and make its project/visual consequence fit the Zone-first flow;
5. **event-driven Zone-first onboarding** — observe symptom → tap Zone → act → watch logistics → read measured result;
6. **Warehouse Expansion** — a visible strategic project that grows Small Depot into Rank 2.

Acceptance focus:
- first meaningful improvement must not require Management as an equipment store;
- every Rank 1 project must visibly change the warehouse or logistics behavior;
- onboarding must not reveal the equipment answer;
- preserve authoritative simulation, schema-v7 save compatibility, and current v2 Interaction Skeleton behavior.

**STOP / SCOPE CONDITION:** do not start Rank 2 STORAGE/PACKING renovation, deferred INBOUND/PICKING/SHIPPING v2 equipment, Rank 3 redesign, or advanced sorter/ASRS/cross-dock content until Rank 1 v2 is coherent and testable.

After Rank 1 v2 is implemented and verified, continue with direct Zone staffing, then Rank 2 STORAGE/PACKING renovation pairs, construction preview/reward feedback, and iPhone Web playtest.

Return to DEVICE_VALIDATION only after the complete v2 slice is end-to-end playable, CI/save regressions are green, fresh visual evidence is inspected, and iPhone Web play no longer reproduces the Management-clicker failure mode.

Native representative-iPhone evidence remains required before GREENLIGHT.

Do not start RELEASE_ENABLEMENT, production signing, App Store Connect/TestFlight production work, Store assets, or active Android production work before PRODUCTION_DECISION=GO.
