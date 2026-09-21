# FLOTRA: input emulation regression repair

Scope: title-local / VERTICAL_SLICE / 2026-09-21
Base main: 7e6839d207f309aca3272bc9226d6bef7186b784
PR: #128, fix/engine-touch-emulation
Status: REPRODUCED AND TARGETED FIX AUTOMATED PASS; NOT DEPLOYED.
Human post-PR126 input retest: FAILED. Human post-PR128 retest: NOT PERFORMED.
Production decision: UNDECIDED. Production release approval: NOT_REQUESTED.

## Evidence
The user reports that no controls could be pressed after the approved PR126 preview deployment. Keep that report as a human FAIL, regardless of earlier CI passes. Exact device event traces are not available; the reproduced engine failure matches the report but does not prove it is the only device issue.

Godot 4.7.2 core/input/input.cpp dispatches a device=-1 emulated mouse event recursively before the originating ScreenTouch when emulate_mouse_from_touch is enabled. The PR126 router claims this as a real mouse pointer (-2); the following touch is marked as a second finger. Mouse release is suppressed while the touch is blocked, and touch release clears only the blocked index. The pointer stays -2, blocking subsequent actions.

The prior composed smoke used Viewport.push_input and manually sent mouse events after touch release. It bypassed this engine emulation stage. New tests use Input.parse_input_event with emulation explicitly enabled.

### RED: unchanged app code
Commit f62b8280115c20728830e92d82ef05c2285b8797 added only this note, the regression and its CI step. No app-code changes.
Mobile Interaction Clarity #9, run 35547911847: FAILED at the new engine test, while the old composed test passed.
Downloaded artifact 10617505498, clarity-engine-touch.log:
- Engine touch down: pointer=-2 blocked={ 0: true }
- Engine touch up: pointer=-2 sheet=false
- failures=3: touch ownership, released pointer, actual Management opening.
This is an observed regression, not merely a source-reading hypothesis.

### GREEN: bounded forward fix
Code commit 9f0a1d0d9a6d4fa11a094c8eb1741cde87f3de56 adds 22 lines to the existing router. It identifies engine-emulated mouse before pointer acquisition. It consumes that event on raw-owned UI surfaces while leaving unrelated canvas input untouched. No global input setting is disabled and no other app logic changes.
- Mobile Interaction Clarity #10, run 35547981638: SUCCESS, including the new engine-parser regression and existing composed tests/captures.
- Rendered Visual Capture #104, run 35547981574: SUCCESS.
- Godot CI #306 and iOS Export Smoke #116 were still running at this documentation snapshot. Check live results before integration; do not infer success.
- Android Export Smoke #118 is historical reference only, not an active production target.

New engine-parser coverage: repeated open/close taps, cancellation without acceptance, exactly one contract acceptance, no-spend equipment preview, separate construction, Zone Panel close, and genuine mouse compatibility. Existing composed tests still cover drag, multitouch, clipping, changing offers, Rank2 renovation and staffing. Fixture money/rating are not natural-progression or fun evidence.

## Recovery / delivery
WORKING_HEAD: this PR branch, resolve its latest head including documentation.
VERIFIED_BASELINE: code 9f0a1d0d9a6d4fa11a094c8eb1741cde87f3de56 for the scoped passing checks above.
RECOVERY_STATE: PR128 not merged; main and preview unchanged; no local user data reset or save-schema change. User/other-machine WIP is unknown and must be protected.
The preceding preview approval was specific to PR126. Do not deploy this repair without a new scoped approval. Successful CI is not physical iPhone/Safari acceptance.

## Separate product direction (PROPOSAL, NOT IMPLEMENTED)
The user wants faster visible warehouse expansion and accumulating forklifts/conveyors, rather than analysis, one-off hiring and repeated reassignment dominating play. The current title intent already says warehouse growth is the primary reward; the limited v2 slice and mandatory contract-rating gate need reevaluation against that intent.

Proposed experience: start with a visibly small/manual depot, add capacity, install the first working forklift, connect a real conveyor, expand floor area, then add vehicles or parallel lines. Each investment changes both the physical scene and authoritative logistics. Analysis supports optional optimization instead of being required reading before every purchase.

Provisional first-session target: within the first five minutes, a player should experience meaningful automation and an unmistakable expansion, with smaller visible changes between major milestones. This is a test target, not an implemented timing or guaranteed outcome. Do not enforce a single prescribed purchase sequence.

Proposed contract role: accelerate growth or offer an optional challenge, rather than be the only route past the first warehouse gate. This would explicitly revise the current Rank1 requirement of 4/4 projects + Rating8 + 10000 cash. Do not silently change it in the input repair.

New conveyors must actually carry the simulated flow; more forklifts must actually take work. Do not fake activity, grant injected money in ordinary play, or merely multiply anonymous stat upgrades. Retain Zone-first physical purchasing, explicit purchase confirmation, the non-manual player role, save safety and iPhone-only target.

NEXT: finish regression review and obtain approval for the input repair, then verify the human input path. Prepare a separate bounded growth-first slice/GDD revision, not all late-game equipment or Rank3 at once. Exact prices, unlocks, vehicle counts, conveyor behavior and timing remain proposals.
