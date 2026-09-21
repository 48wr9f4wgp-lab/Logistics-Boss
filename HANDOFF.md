# FLOTRA: Development Handoff

Last synchronized: 2026-09-21 JST
Scope: title-local / current restart state after approved PR #128 integration.

Historical evidence remains in Git. The prior PR126 handoff is available at commit `7e6839d207f309aca3272bc9226d6bef7186b784`, blob `9b71ca5f9d04847ca58d9ca5465f3a667f551080`. The complete pre-PR126 handoff remains in `docs/history/HANDOFF_pre_PR126_2026-09-20.md`, original blob `c226c842d6b5e0faf6b5fe3e7e00af931e31dab0`. Their historical milestones are not current input-acceptance evidence.

## 1. Current state

- Official title: **FLOTRA (フロトラ)**; migration alias: LOGISTICS BOSS.
- Repository: `48wr9f4wgp-lab/Logistics-Boss`; canonical branch: `main`.
- COMPLEXITY_PROFILE: **LITE**.
- ACTIVE_PHASE: **VERTICAL_SLICE**.
- DEVELOPMENT_TARGET: **iPhone / iOS**; portrait, touch-first, reference viewport 390x844.
- PRODUCTION_DECISION: **UNDECIDED**.
- RELEASE_APPROVAL: **NOT_REQUESTED** for production/App Store/TestFlight.
- REAL_DEVICE_ACCESS: user's iPhone; exact representative device/OS not recorded in title canonical.
- MAC_XCODE_ACCESS_PATH: **BLOCKED_NO_MAC_AVAILABLE**; native physical-iPhone lane **DEFERRED_BY_USER_UNTIL_MAC_AVAILABLE**.
- Runtime save schema: **v9**, unchanged.
- Latest human input evidence: **FAIL after PR126**, user reported nothing could be pressed.
- Human input acceptance after PR128: **PENDING**, not passed.
- Core Experience / enjoyment: **NOT PASSED**. The user also requests faster visible expansion and accumulating functional automation.

The user explicitly replied **「実行」** to the request to integrate PR128 and replace the same trial URL. This authorizes this exact input repair, required integration/state synchronization and the existing engineering preview only. It does not authorize new destinations, Store/TestFlight, fees, SDK activation, data reset, or silently changing growth/economy rules. The prior 「反映」 approval covered PR126, not production release.

## 2. WORKING_HEAD / VERIFIED_BASELINE / RECOVERY_STATE

### WORKING_HEAD

Synchronization input: main `d642a4b06ea5220d41e0212f94883f2deff78298`, the published Web files following PR128 code merge `e892e56ef75d6e7e0d491eb8ccb04e555f5abb6b`. Status: **PARTIAL**.

The containing documentation synchronization advances main without changing game or preview bytes. Resolve live main SHA at restart; do not conflate this input reference with a permanently latest head.

### VERIFIED_BASELINE

PR #128: **Repair engine mouse-before-touch input lock**.
- Tested code: `9f0a1d0d9a6d4fa11a094c8eb1741cde87f3de56`.
- Approved PR head: `e9ac90c3cb3aef1f5b6e5bf04a4e1dc9f36d0871`; one later documentation-only commit relative to tested code, compared before integration.
- Squash merge: `e892e56ef75d6e7e0d491eb8ccb04e555f5abb6b`, with expected-head guard.
- Branch-code checks: Mobile Interaction Clarity #10 (`35547981638`), Godot CI #306 (`35547981567`), iOS Export Smoke #116 (`35547981548`), Rendered Visual Capture #104 (`35547981574`): **SUCCESS**.
- Historical Android Export Smoke #118 (`35547981800`): **SUCCESS**, not active production scope.
- Main-merge Mobile Interaction Clarity #12 (`35548966977`): **SUCCESS**, including composed input, engine-generated mouse/touch regression and actual-main capture.
- These are automated/export checks, not physical-iPhone or enjoyment acceptance.

Engineering preview:
- Godot Preview Pages #97, run `35548966966`: **SUCCESS**.
- Published-files commit: `d642a4b06ea5220d41e0212f94883f2deff78298`.
- Pages build/deployment #273, run `35548992216`: **SUCCESS**; build and deploy jobs checked.
- Same destination: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`.
- Downloaded actual Pages artifact `10617173408` and matched its ZIP SHA256: `3c518b27d44d3425c8b018939ad436acab46ba5a30e4bb9b10afec00b4aeb496`.
- Extracted `godot-preview/index.pck`: **1,936,860 bytes**, matching the export HTML; SHA256 `568ac1b0245afdcbd1a4550bf03f6f3acc455177577519ce964604fe0b0f9572`.
- Direct live HTTP inspection unavailable: container DNS failed and web-tool access failed. A local Chromium replay attempt was blocked at navigation by the environment and is **NOT** a runtime test pass. No restriction bypass attempted.

### RECOVERY_STATE

- PR126 and PR128 merged; repair branches retained.
- No game-code edits beyond the approved PR128 were introduced during integration.
- No user-data reset, save-schema change, automatic rollback or destructive sync.
- External-machine uncommitted/unpushed state is unknown; protect before any later sync/reset.
- Pre-PR128 code `4e2318464d21e7c53767fbd8e1a85b7095d2614a` and preview `9aa0500a5f4fdd65a823c87e618895ba110ab88a` are recovery references only: their human input test FAILED.
- Prefer reviewed forward fixes over blindly restoring a failed preview.

## 3. Human evidence and repair

After PR124 the user could not identify actions, equipment routes or the next step. The supplied resume message showed missing Japanese glyphs; the saved state was equipment4/4, rating0/8 and sufficient cash. PR126 addressed late font coverage, explicit contract start buttons, persistent navigation, installed statuses and a composed raw gesture router.

After PR126 deployment the user reported **「何も押せなかった」**. Earlier automated results did not override this FAIL.

PR128 first added a regression without changing app code: commit `f62b8280115c20728830e92d82ef05c2285b8797`, Clarity #9 (`35547911847`). The old Viewport-injected test passed, while the new `Input.parse_input_event` path failed three assertions. Logs showed a mouse pointer stuck at -2 after touch, blocking Management opening.

The bounded 22-line router fix recognizes engine-emulated mouse events before they acquire real-mouse ownership. No Domain, economy, equipment, save or UI-layout changes. The same engine-parser regression then passed, alongside existing cancellation/drag/multitouch/clipping/preview/commit and Rank2 tests. This reproduced engine failure matches the user's symptom; it is not a captured device trace or proof that no other iPhone issues remain.

PR126's presentation improvements remain included: bundled Japanese font on Control roots, contract descriptions separate from start actions, contracts/field/expansion/settings navigation, accepted-contract progress, installed equipment as status, and explicit Zone preview before construction.

## 4. LAST VERIFIED DONE / BLOCKED / NEXT

**LAST VERIFIED DONE:** approved PR128 integrated; existing engineering preview exported, deployed, and its downloaded Pages artifact integrity verified. Canonical state updated without changing gameplay or save data.

**BLOCKED:** human iPhone repeated-tap acceptance after PR128. Native Mac/Xcode remains a separate later blocker.

**NEXT:** refresh the same preview without resetting saves. Check a short sequence only: open Management, close it, reopen it, then start one contract. Verify subsequent normal taps still work and contract state changes. Do not request a long checklist or explain around a remaining input failure.

- Any continued input failure: remain VERTICAL_SLICE, preserve build/device evidence and repair the actual input path; no blind repeat of the old tests.
- If input works: record input PASS for that build only. It is not a Core Experience/fun PASS.
- Separately prepare the bounded growth-first design revision below. Do not ask the user to validate the old slow loop at length before addressing their product feedback.

## 5. Locked implementation and separate design review

Unchanged by this input release:
- Logistics owner/manager role; no manual parcel carrying or forklift driving.
- 3D warehouse primary board; Zone-first equipment inspection/purchase.
- Director reports symptoms/evidence, not the correct equipment answer.
- Management is an executive dashboard, not the normal equipment store.
- Major equipment has visible identity, authoritative effects, readable trade-offs and measured consequences.
- Warehouse growth remains the primary reward fantasy.
- Rank1 projects: Rack Wing, Second Packing Bench, one Worker Hire, Forklift Project.
- Current Rank1 -> 2 gate: explicit Warehouse Expansion with projects4/4, Rating8 and cash10,000; no silent auto-promotion.
- Rank2 direct staffing: RECEIVING/PICKING/SHIPPING, initial2/2/1, floor1, 30-second observation cooldown. No fake PACKING Worker allocation.
- Slice equipment: STORAGE Fast Pick Rack <-> High Density Rack; PACKING Parallel Pack Line <-> Fast Pack Cell. Paid renovation, no refund; current tested renovation price75%.
- Other Rank2 v2 zones and Rank3 new content remain deferred. Web is engineering only; no new platforms, backend/cloud/account/IAP/ads/external analytics or release enablement.

**Product feedback recorded, exact revision NOT IMPLEMENTED/LOCKED:** the user wants visible warehouse expansion and increasing forklift/conveyor automation at a better tempo, rather than analysis and staffing changes dominating the experience. The proposal in `INPUT_EMULATION_REPAIR_2026-09-21.md` targets meaningful automation and unmistakable expansion within the first five minutes, smaller visible changes between milestones, real transported work rather than decorative machinery, and analysis as an optimization aid. The proposed removal of mandatory contract-rating progression needs an explicit GDD/decision delta; contracts as optional acceleration, prices, counts, conveyor behavior and exact pacing are still proposals. Do not implement all late-game systems or change saves under this input approval.

## 6. Canonical / files in scope

Project-wide: the three installed v2.4 canonical rule files.
Title: `GDD_FLOTRA.md`, `ART_BIBLE_FLOTRA.md`, `DEV_STATUS.json`, `HANDOFF.md`, `VERTICAL_SLICE_V2_CHANGE_PACKET.md`, `MOBILE_INTERACTION_CLARITY_CHANGE_PACKET.md`, `INPUT_EMULATION_REPAIR_2026-09-21.md`.

Input: `godot/ui/mobile_ui_gesture_router.gd`, `godot/tests/mobile_engine_touch_smoke.gd`, composed clarity smoke/capture, `godot/main.gd` and relevant mobile HUD/Zone code.

This handoff's approval, deployment and NEXT supersede the older change packets' pre-integration status only; their tested scope and product proposals are not silently rewritten.

## 7. Visual canonical

CURRENT is the PR128 engineering preview with the retained PR126 presentation. Main-merge captures were generated by CI, but no new visual-quality or iPhone-rendering PASS is claimed during integration. Prior PR126 captures remain historical references, not TARGET guarantees.

TARGET-DIRECTION remains the title Art Bible/GDD: open-top portrait cutaway warehouse, dark navy industrial base, cyan technology and amber safety accents, warm task lighting and readable flow. Reopen actual current/target images before new art/layout/motion decisions. New chat verified_access resets to NO.
