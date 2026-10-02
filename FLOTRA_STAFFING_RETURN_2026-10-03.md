# FLOTRA staffing return and focus cancellation — verified local candidate

## Status and scope

- Baseline: `298c0f9ac423c4a6faa7cb420d65428ca37adf40`, the published PR141 build
- Seven-file local working-tree patch; no commit, push, PR, merge or deployment
- Runtime changes are limited to three presentation/input scripts
- No economy, staffing domain/cooldown, save schema, persistence, Android or camera implementation changes
- Verification engine: `4.7.2.stable.official.ed1daf0bf`; SHA256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`

## Changes

1. Management reopening now resets the staffing draft from authoritative assignments on the sheet's opening `visibility_changed` boundary. This covers ordinary dock/header reopening and explicit navigation. Same-session staffing-tab taps preserve the draft and selection. Closing or cancelling still does not apply a draft.
2. The existing raw UI gesture router's cancellation branch also accepts `NOTIFICATION_WM_WINDOW_FOCUS_OUT`.
3. The existing world Zone selector's cancellation branch accepts the same window notification. Interrupted releases cannot revive a cancelled action or select a Zone.
4. Dedicated actual-main staffing and focus regressions are included in the existing CI regression group.

Only three runtime files change: `mobile_interaction_clarity.gd`, `mobile_ui_gesture_router.gd`, and `zone_interaction_view.gd`. Their bytes match the recovered pre-clock-fix runtime that produced the visual comparisons.

## Focus-test timing defect and correction

The original focus test used `SceneTreeTimer` to wait out the router's real-time mouse suppression interval. A timer created after a long frame could count time spent earlier in that frame and wake before `Time.get_ticks_msec()` reached the router's deadline. One Web-export PCK run consequently failed its fresh-mouse recovery assertion at 430×932 after repeated window/application notifications.

The failure was investigated rather than accepted after a successful retry. A controlled 80 ms frame stall reproduced it: the preserved packed diagnostic resumed 72 ms before the deadline and rejected the premature down. An independent new source diagnostic resumed 52 ms early and reproduced the same single assertion failure. Replacing the test wait with `while Time.get_ticks_msec() <= _router._suppress_until: await process_frame` passed the controlled case, returned after the actual deadline, and preserved all assertions. No runtime suppression or input behavior was weakened.

The final focus-test SHA256 is `413f8f104ad148465762f3a686291c744d73862466ed04e7e226278b6917ac6f`. The former seven-file patch SHA256 `64ec2427133c98593683bc658fbcc3a6eac81f172a8501fbacf384d3827993a4` is historical evidence, not the identity of this corrected candidate.

## Fresh verification

All tests used disposable XDG data/config/cache profiles with `FLOTRA_POLISH_ISOLATED=1`; no player profile was loaded.

- **75/75 source regression scripts passed**, through the canonical `godot/tools/run_polish_checks.sh`
- **166 Godot/CI source files** remained byte-identical across this run
- Actual-main staffing: **819 checks, 0 failures**, at 375×667, 390×844, 430×932
- Actual-main focus: **678 checks, 0 failures**, at the same three sizes
- Fresh Web release export and parse/import passed
- Tests loaded from the freshly exported PCK: runtime startup passed; staffing **819/0**; focus **678/0**
- Native release input-validator self-test passed
- Independent copied-project review: staffing **819/0**, focus **678/0**, cross-scope **672/0**; no blocking findings
- Identical final regressions on unchanged baseline: staffing **84 expected assertion failures** and focus **36 expected assertion failures**, with no parse/load/script errors
- `git diff --check` passed

`release_services_smoke` emits an exit warning for eight ObjectDB instances. The identical warning was reproduced by a fresh baseline run; it is not introduced by this patch. That test otherwise passes. The logs retain the warning.

## Visual evidence

The evidence bundle preserves **24 original PNGs**: baseline and candidate at 375×667, 390×844 and 430×932, with staffing draft/reopened states and focus held/after-release states. Candidate runtime bytes are unchanged from those captures. At every size, baseline staffing reopening retains the uncommitted draft while the candidate restores current assignments; baseline interrupted contract release activates the contract while the candidate leaves it unaccepted.

The two 390-wide side-by-side comparison PNGs are convenience views of these originals. No new art or visual-design change is included.

## Reproduction and evidence

The delivered bundle contains the complete tracked source tree, exact seven-file patch, fresh Web build, per-test logs, source/engine hash manifests, baseline controls, independent review, original packed failure and controlled timing diagnostics, and the 24 original captures.

With Godot 4.7.2 available, from the bundled `source/` directory:

`GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash godot/tools/run_polish_checks.sh $(cat ../evidence/final/test-names.txt)`

Import the project with that engine before the first local run. The log manifest identifies this corrected candidate; older runs are separately labelled historical evidence and are not counted as final-package verification.

## Limits

These are native Linux engine tests, an exported Web PCK exercised in the native headless engine, and Linux GL Compatibility/llvmpipe captures. Lifecycle notifications and pointer input are synthetic. They do not establish physical iPhone/Safari notification delivery, browser gameplay, touch feel, performance, or player-fun outcomes. The known dropped-release camera behavior is outside this patch. Publication remains a separate approval step.
