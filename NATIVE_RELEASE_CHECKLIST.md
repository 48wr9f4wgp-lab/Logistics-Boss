# FLOTRA — iPhone Device Validation / Deferred Release Enablement Checklist

Status: **Pre-GO / ACTIVE_PHASE = DEVICE_VALIDATION**
Development target: **iPhone / iOS**
PRODUCTION_DECISION: **UNDECIDED**
RELEASE_APPROVAL: **NOT_REQUESTED**
Engine: Godot 4.7.2 Standard / GDScript / GL Compatibility
Reference viewport: portrait 390×844

This filename is retained for compatibility with existing references. The current gate is **DEVICE_VALIDATION**, not Native RC or App Store release enablement.

## 1. Current gate

Purpose: evaluate **FLOTRA itself on a representative physical iPhone** and collect enough evidence for GREENLIGHT.

Current required state:
- REAL_DEVICE_ACCESS: **AVAILABLE — user's iPhone**
- MAC_XCODE_ACCESS_PATH: **BLOCKED — no Mac currently available**
- physical iPhone development build: **NOT YET VERIFIED — blocked on Mac/Xcode access**

Pre-GO does **not** require:
- final production Bundle ID / App ID
- production certificate / provisioning operations
- App Store Connect setup
- TestFlight production workflow
- Store assets
- production analytics / crash SDK
- production IAP / Ads integration
- active Android production work

If development signing / provisioning is necessary to reach the user's iPhone, use only the minimum viable path required for DEVICE_VALIDATION. The current minimum path is documented in `DEVICE_VALIDATION_ACCESS.md`: temporary Mac/Xcode access → Xcode Personal Team → unique non-final development Bundle ID → automatic signing → physical iPhone.

## 2. Verified technical baseline

Already prepared / verified:
- authoritative Domain simulation separated from UI / View
- schema-v7 local save with primary + backup recovery
- startup / FTUE / Rank 1 / Rank 2 / Rank 3 automated regressions
- long-running Rank 1 / Rank 3 soak and save/resume coverage
- touch orbit + pinch zoom
- portrait overview framing regression coverage
- Rank 3 management touch-scroll regression coverage
- procedural gameplay feedback audio baseline
- native haptic hooks through `Input.vibrate_handheld`
- provider-neutral local analytics; no external data transmission
- runtime FPS health sampling
- current Rank 1 / 2 / 3 rendered baseline human-inspected
- synthetic unsigned iOS Xcode-project export path proven
- synthetic Android export proof retained as historical technical evidence only

The synthetic export proofs reduce technical uncertainty. They are **not** production signing or release-readiness evidence.

## 3. DEVICE_VALIDATION prerequisites

Record before claiming DEVICE_VALIDATION is underway on hardware:

### REAL_DEVICE_ACCESS
Confirmed:
- ownership / access path: user's own iPhone
- repeated sessions: available

Still record at test start:
- exact iPhone model
- iOS version
- exact development-build install result

### MAC_XCODE_ACCESS_PATH
Current state: **BLOCKED — no Mac currently available**.

The existing GitHub-hosted macOS workflow proves Xcode-project generation but does not pair/install to the user's iPhone. The next unblock is temporary access to a Mac capable of current Xcode. Do not purchase hardware or paid membership solely to clear this blocker without explicit approval.

Do not infer these fields from chat metadata or old assumptions. Record actual reachable paths.

## 4. Development-build rule

DEVICE_VALIDATION needs an installable iPhone development build, not a production release candidate.

Allowed Pre-GO when needed:
- development signing / provisioning
- temporary/non-final development identifier where technically valid
- limited build/export spike needed to reach the device

Not required Pre-GO:
- final production Bundle ID
- production distribution certificate
- production release CI/CD
- TestFlight production operation

If the only viable route requires cost, contract, paid developer enrollment, external distribution, or another external-impact action, stop before that action and obtain explicit user approval.

## 5. Physical iPhone validation matrix

Run across **multiple sessions**. Do not treat a single boot as DEVICE_VALIDATION exit evidence.

### Core experience
- Core Loop is understood without developer explanation
- bottleneck → intervention → reaction → measurement is readable
- the logistics flow itself feels satisfying
- the small-depot → large-logistics-center growth promise is perceived
- reward / growth changes are recognized
- no normal-path progression dead-end or resource dead-end

### Touch / UI
- tap actions are reliable
- single-finger orbit feels controlled
- pinch zoom feels controlled
- edge gestures do not conflict badly with iOS
- maximum zoom-out remains readable
- Safe Area / Dynamic Island clearance
- text and controls are readable at actual phone size
- Management sheet scroll reaches all actions
- no horizontal drift / clipping

### Lifecycle / save
- cold launch
- fresh-save FTUE
- existing schema-v7 save load
- save survives app kill / relaunch
- suspend / resume
- interruption recovery

### Audio / haptics
- audio starts under normal platform policy
- meaningful haptics fire
- shipment events do not create haptic spam

### Progression / mature state
- Rank 1 → Rank 2 → Rank 3 controls remain reachable
- all routing modes remain playable after save / reload
- representative mature Rank 3 session runs for 10+ minutes

### Performance / device health
- FPS / frame pacing observed on the representative iPhone
- no sustained sub-30 FPS in representative mature Rank 3
- thermal tendency observed
- battery tendency noted where practical

### Visual
- current runtime presentation checked against `ART_BIBLE_FLOTRA.md`
- current runtime presentation checked against the canonical North Star
- visual hierarchy remains readable on the physical device

## 6. DEVICE_VALIDATION exit → GREENLIGHT

When the above evidence is sufficient, move to **GREENLIGHT** and record:
- riskiest assumption
- observation / measurement method
- GO condition
- HOLD condition
- additional validation budget / time limit
- physical-device / playtest evidence
- market evidence when needed
- technical risk
- remaining production cost / content volume
- known blockers
- decision owner / source
- decision date

GREENLIGHT must record exactly one:
- **GO**
- **HOLD**
- **KILL**

This sets `PRODUCTION_DECISION`. It does **not** approve App Store release.

## 7. Prepared but deferred release infrastructure

The repository already contains technical scaffolding that may be useful later:
- `godot/native_release_inputs.example.env`
- `godot/tools/native_release_inputs.py`
- `godot/tools/prepare_ios_export.py`
- `.github/workflows/ios-export-smoke.yml`
- `.github/workflows/ios-device-project-candidate.yml`
- `.github/workflows/android-export-smoke.yml`

Current policy:
- keep these assets stable
- use synthetic export workflows as technical evidence
- do not make the real-identifier iOS candidate workflow the active NEXT
- do not fill production identifiers merely for consistency
- do not activate Android production work Pre-GO

Existing `LOGISTICS_BOSS_*` environment-variable names and `LogisticsBoss` internal output paths are compatibility identifiers and do not need renaming solely to match the FLOTRA product title.

## 8. POST-GO only: Release Enablement

Only if `PRODUCTION_DECISION=GO`:
1. enter FUNCTIONAL_BUILD / RELEASE_ENABLEMENT as appropriate
2. finalize production Bundle ID / App ID decisions
3. configure authorized production signing / provisioning
4. prepare App Store Connect / TestFlight production workflow
5. define the release-candidate scope
6. complete polish / QA / RELEASE_CANDIDATE gates
7. evaluate Android separately via `PLATFORM_EXPANSION_DECISION`

Android is not automatically activated by GO.

## 9. External actions requiring explicit approval

Do not perform without explicit user approval:
- paid Apple / Google developer-account purchase or renewal
- production signing-key generation / rotation
- Apple certificate / provisioning import when it creates production or external impact
- TestFlight / App Store distribution
- Google Play distribution
- IAP / ads / monetization activation
- external analytics / crash-provider contract or data upload
- any other irreversible / external-impact release action

## 10. Current blocker definition

FLOTRA is **not a Release Candidate**.

Current blockers for DEVICE_VALIDATION are:
1. REAL_DEVICE_ACCESS not recorded
2. MAC_XCODE_ACCESS_PATH not recorded
3. physical-iPhone development-build path not verified
4. physical iPhone multi-session evidence not collected

After those are resolved, proceed to **GREENLIGHT**, not RELEASE_ENABLEMENT.
