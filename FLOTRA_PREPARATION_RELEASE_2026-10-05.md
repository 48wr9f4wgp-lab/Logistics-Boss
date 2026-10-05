# FLOTRA job preparation and replay comparison

## Player flow

Every available job retains its direct-start button and gains an optional preparation route. The preparation sheet shows the selected job, manifest, reward, current layout and the three existing free operating modes. Opening preparation does not accept a job or spend money.

The existing layout editor returns to the selected preparation after either canceling a preview or confirming a placement. Mode selections and confirmed placements are real changes and remain applied when the preparation sheet closes; the sheet explicitly explains this. The final start button revalidates availability before accepting exactly the selected job.

Completed jobs retain direct replay and next-job actions. An additional adjust-and-replay action opens preparation for that same job. The saved best time is visible without expanding historical records.

## Honest comparisons and growth copy

The model retains a session-only summary for each completed job. A later completion of the same job can compare game-time duration, average units per minute, aggregate aisle wait, operating mode and final layout. Equipment changes and time spent relocating during a job are explicitly disclosed. Runs using different physical operating profiles are not compared.

Detailed prior-run summaries are never added to the save payload. On reload, the interface explains that another same-job completion in the current launch is needed; historical best time and completion records remain saved as before. Save schema 3, migration validators, economy, rewards, existing transport modes and cargo rules are unchanged.

Legacy jobs retain their first-completion-only reward semantics in preparation. Four purchased wings are not described as leaving room for more expansion. Completing six milestones is distinguished from owning every available improvement. A fully equipped warehouse points to route, layout and operating comparisons rather than nonexistent purchases.

## Canceled-touch repair

The Godot 4.7.2 Web loader maps `touchcancel` to an ordinary touch release. A passive capture listener now notifies the game before the loader queues that release. The handler flushes earlier buffered starts, invalidates held HUD actions and cancels world pointer ownership. The normal engine release still runs to clear input state.

This ordering also covers several start/cancel pairs before a rendered frame. A new touch immediately afterward is allowed; there is no blanket delay, disabled touch emulation or swallowed browser event. The camera controls and precise layout editor retain their existing guards.

## Verification and release gates

The dedicated native suites exercise preparation, mode and layout changes, direct starts, same-job replays, numeric comparisons, legacy reward copy, saved-best feedback, reload boundaries, mature growth copy and phone control geometry. Cancellation tests exercise native cancellation and the Web loader's lost-cancel ordering across both mouse/touch emulation settings, including genuine mouse recovery, camera controls and confirmed layout actions.

The aggregate includes both new suites alongside the existing domain, save, old-campaign, operation, readability, foreground-clock and camera regressions. Independent historical-save adversarial checks remain pinned to commit `0a5a71ee3e88100373fcb77aae685bd4f52a7c24`.

Local verification on official Godot 4.7.2 passed all 33 native aggregate suites and the JavaScript storage/loader/viewport checks. Focused counts were 777 preparation checks, 48 cancellation checks, 5,175 camera checks and 27,630 independent historical-save/transport adversarial checks. The viewport bridge passed 104 explicit DOM-mock checks; those mocks are distinct from actual browser evidence.

The browser preparation suite runs the actual exported WebGL application in isolated profiles at 375×567 and 390×844 CSS pixels, DPR 3. It drives real CDP touch input and uses read-only game metrics. Its rapid cancellation check controls animation-frame scheduling to verify several input pairs before the next engine callback; normal unsuspended cancellation and fresh-input recovery are checked separately.

All six local browser cases passed with zero browser errors: direct quickstart plus fresh and fully upgraded preparation at both sizes. The tested PCK SHA-256 is `e22fd39d98467c0fb29061fb38a9c1f610993e7afff38fdd08061896184b6d7f`. The reproducible evidence contract and measured comparison values are recorded in `docs/guides/FLOTRA_PREPARATION_BROWSER_QA.md`.

The GitHub workflow adds two preparation viewport jobs to the existing eight jobs. The same six cases run in parallel by viewport, with no assertions removed. All ten jobs must pass for the exact candidate before merge. Publication additionally requires successful Pages deployment and byte identity for the live HTML, PCK, engine JS/WASM and both bridges over verified HTTPS.

Chromium emulation and Linux Godot checks do not establish physical iPhone or Safari compatibility. The Web export retains `persistentPaths: []` and `canvasResizePolicy: 0`.

## Reproduction

```sh
GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/test.sh
GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/tests/release/run_experience_adversarial.sh
GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/export_web.sh
mkdir -p build/preparation-fixtures
FLOTRA_GROWTH_FIXTURES="$PWD/build/preparation-fixtures" \
  /path/to/Godot_v4.7.2 --headless --path flotra-campaign \
  --script res://tests/release/growth_browser_fixtures.gd
python3 -m http.server 8830 --bind 127.0.0.1 --directory docs/godot-jobs-preview
# In another terminal with Playwright/Chromium installed:
xvfb-run -a node flotra-campaign/tests/release/browser_preparation_journey.cjs \
  http://127.0.0.1:8830/ build/preparation-browser-journey build/preparation-fixtures
```
