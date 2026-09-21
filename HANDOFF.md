# FLOTRA: Development Handoff

Last synchronized: 2026-09-21 JST
Scope: title-local / current restart state after approved PR #130 integration.

Historical evidence remains in Git. The pre-PR130 snapshot is available at commit `0307bf9dfdf122f07774b1b503643f52ad8d039f`, handoff blob `f8134a11a62ceb350cc9593c71c69d401177f2ed`. The complete pre-PR126 handoff remains in `docs/history/HANDOFF_pre_PR126_2026-09-20.md`, original blob `c226c842d6b5e0faf6b5fe3e7e00af931e31dab0`. Historical failures and automated evidence remain valid for their recorded scope; they do not replace the latest human report below.

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
- Latest human report after PR128: **「使いやすくなった！ あとはポップアップが被って見えないくらい」**. Positive basic-usability/navigation evidence; remaining issue is popup obstruction.
- IMG_2615.jpeg shows Management/expansion open with a shipment +¥500 toast covering tabs. PR128 build attribution is inferred from the deployment/test sequence; the image has no build ID and is not an exhaustive gesture test.
- Human notification-clearance recheck after PR130: **PENDING**, not passed.
- Core Experience / enjoyment: **NOT PASSED**. The user also requests faster visible expansion and accumulating functional automation.

The user explicitly replied **「反映しよう」** to the request to integrate PR130 and replace the same trial URL. This authorizes the tested notification repair, required integration/state synchronization and the existing engineering preview only. It does not authorize new destinations, Store/TestFlight, fees, SDK activation, data reset, or silently changing growth/economy rules. Earlier approvals for PR126/PR128 remain historical, not production release approval.

## 2. WORKING_HEAD / VERIFIED_BASELINE / RECOVERY_STATE

### WORKING_HEAD

Synchronization input: main `86bf3ba109c08994dae8063a9bdf3c37cada1d66`, the published Web files following PR130 code merge `4a398a417aa53b1deee009cb344bce273e2035db`. Status: **PARTIAL**.

The containing documentation synchronization advances main without changing game or preview bytes. Resolve live main SHA at restart; do not conflate this input reference with a permanently latest head.

### VERIFIED_BASELINE

PR #130: **Keep mobile controls clear of shipment notifications**.
- Approved and tested PR head: `619ebff77a4446587739b6ae1f8bd3fcb2a57be0`.
- Squash merge: `4a398a417aa53b1deee009cb344bce273e2035db`, with expected-head guard.
- Checks rechecked immediately before integration: Mobile Interaction Clarity #15 (`35555431030`), Godot CI #311 (`35555431033`), iOS Export Smoke #120 (`35555431035`), Rendered Visual Capture #109 (`35555431046`): **SUCCESS**.
- Historical Android Export Smoke #123 (`35555431022`): **SUCCESS**, not active production scope.
- Clarity includes existing composed/engine-generated input and notification tests at 390x844, 375x667 and 430x932; live earnings compared with a reference simulation; no routine-shipment backlog; deferred current important-feedback timers; Zone/reset coverage; passive overlays ignore taps.
- Implementation evidence: actual-main `notification_management_clear.png`, artifact `10619779432`, was reopened and inspected during implementation. A new visual judgment requires reopening the image, not relying on this note.
- These are automated/export checks and implementation capture evidence, not PR130 physical-iPhone or enjoyment acceptance.

Engineering preview:
- Published-files commit: `86bf3ba109c08994dae8063a9bdf3c37cada1d66`.
- Comparison against the PR130 merge confirms one direct descendant commit changing only `docs/godot-preview/index.html` and `index.pck`.
- Pages build/deployment #276, run `35558380778`: **SUCCESS**, associated with this published-files commit.
- Same destination: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`.
- Downloaded actual Pages artifact `10620554995` and matched its ZIP SHA256: `37302145b34dade3c97d64bef030c118e6a56a9f01d1f4d4c8c7762c7bccd1d5`.
- Extracted `godot-preview/index.pck`: **1,944,592 bytes**, matching export HTML; SHA256 `347aece2a365854084d54d806fc90c2bd8be5fdbfcf80adff073734337ceccc1`.
- Live Pages inspection via the web tool was inaccessible; a container request for raw source also failed DNS. No browser-runtime or physical-iPhone PASS is claimed. Deployment/artifact integrity is a separate scope.

### RECOVERY_STATE

- PR126, PR128 and PR130 merged; repair branches retained.
- No game-code edits beyond the approved PR130 were introduced during integration.
- No user-data reset, save-schema change, automatic rollback or destructive sync.
- External-machine uncommitted/unpushed state is unknown; protect before any later sync/reset.
- Pre-PR130 code `e892e56ef75d6e7e0d491eb8ccb04e555f5abb6b` and preview `d642a4b06ea5220d41e0212f94883f2deff78298` have positive basic-usability evidence but known popup obstruction. They are recovery references, not a comprehensively accepted product baseline.
- Prefer reviewed forward fixes; no automatic revert or data deletion.

## 3. Human evidence and repair

After PR124 the user could not identify actions, equipment routes or the next step. The supplied resume message showed missing Japanese glyphs; the saved state was equipment4/4, rating0/8 and sufficient cash. PR126 addressed late font coverage, explicit contract start buttons, persistent navigation, installed statuses and a composed raw gesture router.

After PR126 deployment the user reported **「何も押せなかった」**. Earlier automated results did not override this FAIL.

PR128 first added a regression without changing app code: commit `f62b8280115c20728830e92d82ef05c2285b8797`, Clarity #9 (`35547911847`). The old Viewport-injected test passed, while the new `Input.parse_input_event` path failed three assertions. Logs showed a mouse pointer stuck at -2 after touch, blocking Management opening.

The bounded 22-line router fix recognizes engine-emulated mouse events before they acquire real-mouse ownership. No Domain, economy, equipment, save or UI-layout changes. The same engine-parser regression then passed, alongside existing cancellation/drag/multitouch/clipping/preview/commit and Rank2 tests. The later user report confirms improved usability/basic navigation; it does not prove every gesture or native-device acceptance.

PR126's presentation improvements remain included: bundled Japanese font on Control roots, contract descriptions separate from start actions, contracts/field/expansion/settings navigation, accepted-contract progress, installed equipment as status, and explicit Zone preview before construction.

PR130 addresses the remaining shipment-toast obstruction. It discards routine shipment notifications while Management, Zone controls or reset confirmation is open, without altering actual shipments or cash. Currently held important toast/measurement feedback waits with its display timers preserved and resumes after controls close. It does not add a full notification history or queue; do not claim every earlier important event is retained. Passive overlays ignore taps. The input router and Domain/economy/progression/save rules are unchanged.

RED: tests-only `e7fc11ba4c099ad43accc633b5f7416d7d573b9c`, Clarity #13 (`35555278883`) exposed the obstruction. App fix `bab6f1d86375ab28b21c6e97deba0b7abc498333`; final head `619ebff77a4446587739b6ae1f8bd3fcb2a57be0` corrects resized-window test coordinates without removing assertions. Clarity #15 passes. This verifies the bounded fix, not the user's new device result.

## 4. LAST VERIFIED DONE / BLOCKED / NEXT

**LAST VERIFIED DONE:** approved PR130 integrated; the same engineering preview deployed; downloaded Pages artifact integrity verified. Canonical state records the positive post-PR128 report and the narrower pending notification recheck.

**BLOCKED:** PR130 human notification-clearance acceptance is pending. No new blocker to preparing the separate next design task. Native Mac/Xcode remains a separate later blocker.

**NEXT:** a brief iPhone check that shipment notifications no longer cover Management tabs or Zone purchase controls. Refresh the same page without resetting saves. Do not repeat the earlier no-input diagnosis as the current state or request another lengthy checklist.

Next product task remains a separate bounded growth-first design/GDD revision below. Basic usability improvement is not a Core Experience/fun PASS. Do not require a long replay of the old loop before addressing the user's growth feedback.

## 5. Locked implementation and separate design review

Unchanged by this notification release:
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

**Product feedback recorded, exact revision NOT IMPLEMENTED/LOCKED:** the user wants visible warehouse expansion and increasing forklift/conveyor automation at a better tempo, rather than analysis and staffing changes dominating the experience. The proposal in `INPUT_EMULATION_REPAIR_2026-09-21.md` targets meaningful automation and unmistakable expansion within the first five minutes, smaller visible changes between milestones, real transported work rather than decorative machinery, and analysis as an optimization aid. The proposed removal of mandatory contract-rating progression needs an explicit GDD/decision delta; contracts as optional acceleration, prices, counts, conveyor behavior and exact pacing are still proposals. Do not implement all late-game systems or change saves under this notification approval.

## 6. Canonical / files in scope

Project-wide: the three installed v2.4 canonical rule files.
Title: `GDD_FLOTRA.md`, `ART_BIBLE_FLOTRA.md`, `DEV_STATUS.json`, `HANDOFF.md`, `VERTICAL_SLICE_V2_CHANGE_PACKET.md`, `MOBILE_INTERACTION_CLARITY_CHANGE_PACKET.md`, `INPUT_EMULATION_REPAIR_2026-09-21.md`.

Notification repair: `godot/ui/game_hud_feedback.gd`, `godot/tests/mobile_notification_clearance_smoke.gd`, `.github/workflows/mobile-interaction-clarity.yml`; evidence in PR130 and its verification comment `5754761670`.
Input baseline: `godot/ui/mobile_ui_gesture_router.gd`, `godot/tests/mobile_engine_touch_smoke.gd`, composed clarity smoke/capture, `godot/main.gd` and relevant mobile HUD/Zone code.

This handoff's approval, deployment and NEXT supersede earlier approval-wait/current-state statements only. The tested scope and separate product proposals are not silently rewritten.

## 7. Visual canonical

CURRENT is the PR130 engineering preview, retaining PR128 input and PR126 presentation. Its notification-clearance capture was inspected during implementation; no new iPhone-rendering PASS is claimed during integration. The user's IMG_2615.jpeg is pre-PR130 human evidence of popup obstruction, not the new build or TARGET.

TARGET-DIRECTION remains the title Art Bible/GDD: open-top portrait cutaway warehouse, dark navy industrial base, cyan technology and amber safety accents, warm task lighting and readable flow. Reopen actual current/target images before new art/layout/motion decisions. New chat verified_access resets to NO.
