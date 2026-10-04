# FLOTRA experience: independent native journey QA

## Result

The final independent suite passed on Godot **4.7.2.stable.official.ed1daf0bf** with exit code 0 on 2026-10-04:

- `experience_player_input_journey.gd`: **2,682 checks, zero failures**
- `experience_slow_frame_guard.gd`: **14 checks, zero failures**
- `experience_interruption_probe.gd`: all four interruption/recovery assertions passed

These tests run against the actual scene, HUD, domain, persistence and world classes. Player actions use native GUI touch, mouse and wheel event dispatch. Simulation time is advanced directly only while awaiting a completed delivery; rewards and purchases are never injected. Every run uses an isolated HOME/XDG user-data directory, and the save journey refuses to run outside its declared disposable profile.

## Covered player journey

1. Open a new warehouse, read the introduction, and reach the first work selector without silently starting an empty warehouse
2. Drag from the enabled first-job button without accepting it, then accept with a held touch spanning repeated HUD refreshes
3. Change speed, enable menu auto-pause and reduced motion, explicitly pause/resume, and verify that closing a menu preserves manual pause
4. Interrupt a held setting with focus loss; resume only through an explicit player action
5. Open the layout editor, choose an actual placement, queue a free move, and cancel it before movement starts without changing cargo, wallet or current placement
6. Finish the first paid job, verify repeated refreshes cannot award twice, buy the earned first wing, start the next milestone and replay it for exactly one recurring reward
7. Select all three free operating modes through their visible buttons without spending money
8. Reopen help, controls, work, results, expanded history, future/owned equipment and layout at 375×567, 390×844, 430×932 and 568×320
9. Verify visible HUD text is at least 18 logical pixels, buttons are at least 56×56, every scrollable action can be fully revealed, and the pinned layout action remains inside its body
10. Save actual in-flight cargo, destroy/recreate the scene, verify exact restoration including preferences and operating mode, and resume deliberately
11. Reach and read the complete Japanese save warning through settings after a simulated blocked-store status

## Regressions found and rechecked

- **Cancellation feedback was disconnected.** The scene checked `show_layout_cancel_result`, while the HUD implemented `show_cancel_layout_result`. The successful visible cancellation is now covered end to end
- **Resize preserved an in-flight settings press.** Holding the 4× action across a height change from 390×844 to 390×567 activated it on release. Resize now invalidates that press, while a fresh later click remains usable
- **Application focus-out did not pause the scene.** The HUD rejected its old press, but the scene handled only window-focus-out and application pause. Application focus-out now pauses the simulation too
- **A slow frame could outlive the click-through timer.** A deterministic 230ms CPU stall without yielding a frame followed by five queued click pairs verifies that both the inherited release and growth HUD/world reject input to newly exposed controls
- **A blocked press could become valid on a later release.** The strengthened regression holds an action down during the blocked dismissal frame, then releases after the next frame. The full gesture is now rejected, and a fresh subsequent press is accepted

The slow-frame suite also proves that ordinary actions and world selection recover on the next process frame once the elapsed-time guard is satisfied. It does not rely on machine load to reproduce the race.

## Reproduce

From the repository root, after the normal asset import:

```sh
GODOT=/path/to/Godot_v4.7.2 \
  bash flotra-campaign/tests/release/test_experience_review.sh
```

The runner includes all three independent suites and allocates a fresh disposable profile. The implementation work and the main aggregate test runner are owned separately; this review adds only new test files and this report.

## Verification boundary

This is native **headless engine input and layout-geometry evidence**. It does not establish rendered typography, browser DPR scaling, GPU performance, physical touch hardware or iPhone/Safari behavior. No screenshots or browser results are claimed here; those require the separate actual WebGL/browser and physical-device checks. The simulated save-warning case tests propagation and reachability, while corrupt-save and browser storage-lock behavior remain the responsibility of their dedicated suites.

## CI follow-up: test-harness clock alignment

The inherited `readability_input.gd` initially failed its first mouse selection on fast headless starts even though its helper awaited a 0.25-second `SceneTreeTimer`, a physics frame and six process frames. Instrumented native input showed the precise state at that press: **msLeft=55, frame=7, guardFrame=0, guarded=true**. The camera projection and viewport were correct; both press and release reached the world input gate and were rejected while 55ms of the real dismissal interval remained. Later mouse and touch selection worked once the wall-clock interval had expired.

This was a test clock mismatch, not a world-selection defect. A scene timer consumes frame delta, which on the initial headless frame can include startup time accrued before that timer was created. It therefore did not establish the monotonic interval required by the actual input guard.

- The input-test helper now waits for an actual 250ms monotonic deadline and the guard to clear, with a bounded 2.25-second failure deadline, then retains its original physics/layout settling
- Every same-frame mouse/touch dispatch, selection, caption, focus-loss and geometry assertion remains unchanged
- The native journey's manual-process helper likewise waits for a monotonic microsecond deadline before calling the scene; a synthetic process delta cannot substitute for real elapsed time in the foreground clock
- `readability_input.gd` passed **1,038 checks, zero failures in each of three fresh official Godot 4.7.2 processes**
- No game implementation changed for this follow-up

Diagnostic evidence is retained in `build/experience/readability-input-diagnostic.log`; repeated fresh-process results are in `build/experience/readability-input-monotonic.log`. The temporary diagnostic script was removed after identifying the cause.
