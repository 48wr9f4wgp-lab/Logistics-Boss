# FLOTRA: Development Handoff

Last synchronized: 2026-09-20 JST
Scope: title-local / current restart state after PR #126 integration.

The complete prior handoff is preserved byte-for-byte in `docs/history/HANDOFF_pre_PR126_2026-09-20.md` (original blob `c226c842d6b5e0faf6b5fe3e7e00af931e31dab0`). Its milestones and historical evidence remain available, but its PR #124 current-state/NEXT statements are superseded by this file. No design, code, or save data was discarded by this documentation synchronization.

## 1. Current state

- Official title: **FLOTRA (フロトラ)**; migration alias: LOGISTICS BOSS.
- Repository: `48wr9f4wgp-lab/Logistics-Boss`; canonical branch: `main`.
- COMPLEXITY_PROFILE: **LITE**.
- ACTIVE_PHASE: **VERTICAL_SLICE**.
- DEVELOPMENT_TARGET: **iPhone / iOS**; portrait, touch-first, reference viewport 390x844.
- PRODUCTION_DECISION: **UNDECIDED**.
- RELEASE_APPROVAL: **NOT_REQUESTED** for production/App Store/TestFlight.
- REAL_DEVICE_ACCESS: user's iPhone, repeated Web testing available; exact representative device/OS not yet recorded in title canonical.
- MAC_XCODE_ACCESS_PATH: **BLOCKED_NO_MAC_AVAILABLE**.
- Native physical-iPhone lane: **DEFERRED_BY_USER_UNTIL_MAC_AVAILABLE**.
- Runtime save schema: **v9**, unchanged by PR #126.

Engineering-preview permission is separate from production release permission. In this chat the user explicitly replied **「反映」** to the request to integrate PR #126 and replace the same existing trial URL. This authorizes that exact repair, integration/state synchronization, and existing preview replacement only. It does not authorize a new public destination, Store/TestFlight distribution, fees, SDK activation, or data reset.

## 2. WORKING_HEAD / VERIFIED_BASELINE / RECOVERY_STATE

### WORKING_HEAD

Latest shared main content at this synchronization input:
- commit: `9aa0500a5f4fdd65a823c87e618895ba110ab88a`;
- role: publish Web engineering preview after PR #126;
- parent/code merge: `4e2318464d21e7c53767fbd8e1a85b7095d2614a`;
- validation_status: **PARTIAL** (automated code and deployment evidence, human iPhone acceptance pending).

The documentation commit containing this handoff advances main without changing game or preview content. Resolve the actual live main SHA on restart rather than treating the synchronization-input SHA above as an immutable latest head.

### VERIFIED_BASELINE

PR #126: **Make mobile actions legible and fix late Japanese font coverage**.
- Tested branch code: `cea981657140c84a0a27db8cdb475ee3ecece2d6`.
- Approved PR head: `efea195745a4ea181783cb721744eab19a841083`; the one additional commit only records evidence in the change packet.
- Squash merge to main: `4e2318464d21e7c53767fbd8e1a85b7095d2614a`.
- Mobile Interaction Clarity #6, run `35515354686`: **SUCCESS**; integrated ScreenTouch checks reported failures=0.
- Godot CI #302, run `35515354738`: **SUCCESS**.
- iOS Export Smoke #113, run `35515354641`: **SUCCESS**, unsigned technical evidence, not native-device acceptance.
- Rendered Visual Capture #100, run `35515354667`: **SUCCESS**.
- Android Export Smoke #114, run `35515354665`: **SUCCESS**, historical technical reference only; Android remains outside active Pre-GO scope.
- Actual main-scene 390x844 evidence: fresh, completed-equipment/resume, contracts, field, installed storage; artifact `10607285012`. These were inspected during implementation. A new chat must reopen actual images before making new visual judgments.

Engineering preview:
- export/publish workflow **Godot Preview Pages #96**, run `35515872829`: **SUCCESS**;
- published files commit: `9aa0500a5f4fdd65a823c87e618895ba110ab88a`;
- GitHub Pages **build and deployment #270**, run `35515899408`: **SUCCESS**, for the published-files commit;
- destination unchanged: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`;
- direct HTTP/runtime inspection from this integration environment was unavailable. Deployment success is not human Safari/runtime or fun acceptance.

### RECOVERY_STATE

- PR #126: merged; repair branch retained, not deleted.
- No user save reset or save-schema change was performed.
- This integration session created no game-code WIP or local game commits.
- User/other implementation-machine uncommitted or unpushed state cannot be inferred from GitHub; protect it before any later reset/sync.
- Prior engineering-preview files are recoverable at `82f2097b6d57e6bacb1a88946a8d65e4604355f9`; prior code baseline is PR #124 merge `6a3bfc173e3113368d8929cbe312f0e06aaff3de`.
- No rollback was executed. Prefer a reviewed forward fix or deliberate revert of the scoped repair; do not blindly reset main or delete user data.

## 3. Human evidence and implemented repair

The post-PR #124 iPhone Web test **FAILED**. The user could not tell whether buttons registered, where equipment was bought, or what action to take. The third supplied screenshot also showed missing Japanese glyphs in the resume message. The observed saved state was Rank 1 equipment 4/4, Logistics Rating 0/8, with sufficient expansion money. This is not evidence of missing Rank 1 equipment.

PR #126 implements the bounded input/text/navigation repair:
- shared bundled Japanese theme on actual Control roots beneath CanvasLayer, including late-created surfaces;
- one composed raw gesture owner, visible held-press feedback, clipping checks, cancellation, multitouch/scroll rejection, held-touch and synthetic-mouse protection;
- persistent Management tabs: contracts / field / expansion / settings;
- contract descriptions separated from explicit **「この契約を開始」** actions;
- authoritative contract acceptance returns to the warehouse with persistent live progress;
- readiness-aware main action routes to contracts, unfinished equipment, or expansion;
- installed Rank 1 equipment/staff becomes status rather than a disabled purchase affordance;
- existing Zone-first equipment preview then explicit construction/renovation retained;
- expansion navigation itself does not spend money.

No Domain/economy/contract-condition changes, new equipment, Rank 3 redesign, account/backend/analytics SDK changes, or save-format changes are part of this repair.

## 4. LAST VERIFIED DONE / BLOCKED / NEXT

**LAST VERIFIED DONE:** PR #126 merged with an expected-head guard; its Web export was committed and the same GitHub Pages engineering-preview destination deployed successfully. State synchronization records the earlier human FAIL and leaves new human acceptance pending.

**BLOCKED:** short human iPhone Web UI foundation/clarity retest after PR #126. Native Mac/Xcode access is a separate later blocker, not grounds to declare the current UI passed.

**NEXT:** open the current engineering preview on the iPhone without resetting the save. First verify that Japanese is readable, a normal press has clear feedback, contracts/field/expansion are findable, contracts actually start and show progress, equipment preview/commit remains distinct, and button-origin scrolling does not activate actions. Do not coach a long playthrough merely to force success.

- Any basic text/input/navigation failure: remain VERTICAL_SLICE and fix that layer only.
- Foundation passes: resume Core Purpose / Growth Spine testing on the same build. Record whether the player independently understands what to do and recognizes how decisions affect warehouse growth.
- Human comprehension, Core Experience, and enjoyment remain **NOT PASSED** until observed. Automated fixtures with injected funds/rating are UI tests, not natural-progression/fun evidence.

## 5. Locked product and scope

- Player is the logistics-center owner/operations manager, not a manual parcel carrier or forklift driver.
- 3D warehouse is the primary board.
- Observe flow -> notice symptom -> inspect Zone -> choose OPERATIONS/CAPITAL response -> visible physical and authoritative logistics change -> measure -> next constraint.
- Director reports symptoms/evidence, not the correct equipment answer.
- Management is an executive dashboard, not the normal equipment store.
- Major equipment requires visible identity, actual Domain effect, readable trade-offs, and measured consequences.
- Warehouse growth is the primary reward fantasy.
- Rank 1: Rack Wing / Second Packing Bench / one Worker Hire / Forklift Project.
- Rank 1 -> 2 requires explicit Warehouse Expansion: 4/4 projects, Logistics Rating 8, and 10,000 cash; no silent auto-promotion.
- Rank 2 staffing: RECEIVING (INBOUND/STORAGE), PICKING, SHIPPING; start 2/2/1, one-worker floor, 30-second observation cooldown; no fake PACKING Worker allocation.
- Slice equipment: STORAGE Fast Pick Rack <-> High Density Rack; PACKING Parallel Pack Line <-> Fast Pack Cell; paid renovation, no refund. Current tested price is 75% of target fresh-build cost.
- Other Rank 2 v2 Zones and Rank 3 redesign/new content remain deferred until the slice passes.
- Web is engineering/prototype/diagnostic only. No active Android production, backend/account/cloud save/IAP/ads/external analytics or release enablement is authorized.

## 6. Canonical files / next edit scope

Project-wide: the three installed v2.4 project canonical rule files.
Title-local: `GDD_FLOTRA.md`, `ART_BIBLE_FLOTRA.md`, `DEV_STATUS.json`, this `HANDOFF.md`, `VERTICAL_SLICE_V2_CHANGE_PACKET.md`, and `MOBILE_INTERACTION_CLARITY_CHANGE_PACKET.md`.

Relevant implementation: `godot/main.gd`, `godot/ui/mobile_interaction_clarity.gd`, `godot/ui/mobile_ui_gesture_router.gd`, `godot/ui/mobile_theme.tres`, existing HUD/Zone components, `godot/ui/session_resume_brief.gd`, and composed mobile-clarity smoke/capture tests.

The change packet's pre-integration approval-wait statements are historical as of its recorded branch head. The explicit approval and deployment evidence in sections 1-2 above supersede that delivery status, not its implementation acceptance criteria.

## 7. Visual canonical

- CURRENT: PR #126 actual-main captures and deployed engineering preview; not a guarantee of TARGET quality.
- TARGET-DIRECTION: open-top portrait cutaway warehouse, dark navy industrial base, cyan tech accents, amber safety accents, warm local task lighting, readable logistics flow, per title Art Bible/GDD.
- Target imagery and current imagery are not interchangeable. On a new chat reset verified_access to NO and reopen the actual relevant image before layout/art/motion judgment. Missing target imagery blocks only dependent visual decisions.
