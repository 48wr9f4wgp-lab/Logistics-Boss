# FLOTRA: input emulation regression repair

Scope: title-local / VERTICAL_SLICE / 2026-09-21
Base main: 7e6839d207f309aca3272bc9226d6bef7186b784
Status: REPRODUCTION IN PROGRESS. Human post-PR126 input retest FAILED.
Production decision: UNDECIDED. Production release approval: NOT_REQUESTED.

## Evidence and hypothesis
The user reports that no controls could be pressed after the approved PR126 preview deployment. Keep that report as a human FAIL, regardless of earlier CI passes. Exact device event traces are not available.

Godot 4.7.2 core/input/input.cpp dispatches a device=-1 emulated mouse event recursively before the originating ScreenTouch when emulate_mouse_from_touch is enabled. The composed router currently treats this mouse as a real pointer (-2); the following touch is then marked as a second finger. Mouse release is suppressed while the touch is blocked, and touch release clears only the blocked index. The pointer can stay -2, preventing subsequent actions.

The prior composed smoke used Viewport.push_input and manually sent mouse events after touch release. It did not exercise this engine emulation stage. New tests must use Input.parse_input_event with emulation explicitly enabled. First run the new regression against unchanged app code, then apply the bounded fix and rerun it.

## Goal and acceptance
- A finger remains the owner when an emulated mouse press arrives first.
- Engine-parsed repeated taps open/close controls; no stuck pointer.
- Cancel remains no-op; touch/emulated mouse accepts exactly one contract.
- Equipment preview costs nothing; a separate commit gesture changes Domain ownership once.
- Genuine mouse, existing drag/multitouch/clipping, Rank2 actions and save regressions remain intact.

## Scope / recovery
Only router, new regression and its CI step. No economy, equipment, save, art or progression changes. No user-data reset. Main and deployed preview remain unchanged until separately approved; the prior approval was specific to PR126. A test fixture is not human Safari/native acceptance. Do not claim the user-device root cause proven without device confirmation.

## Separate product feedback (proposal, not implemented)
The user wants faster visible warehouse expansion and accumulating forklifts/conveyors, not a loop dominated by analysis, one-off hiring and reassignment. Reframe the next design pass around visible scale and automation. Analysis should support optional optimization; basic growth should not feel like mandatory contract-rating paperwork. Changing the Rank1 gate and introducing real conveyor flow require an explicit title-local design revision and bounded new slice, not silent content growth inside this input repair. Preserve Zone-first physical purchases, Domain-authoritative throughput, and the no-manual-parcel-carrying role. Exact timings, prices, conveyor behavior and unlock conditions remain proposals.
