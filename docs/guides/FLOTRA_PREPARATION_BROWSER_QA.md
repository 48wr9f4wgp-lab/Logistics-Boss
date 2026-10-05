# Preparation journey browser verification

`flotra-campaign/tests/release/browser_preparation_journey.cjs` is a separate actual-browser gate for the optional preparation journey. It loads the exported Godot game in isolated Chromium profiles at **375 × 567** and **390 × 844 CSS pixels, DPR 3**. This is cloud Chromium/WebGL emulation, not physical iPhone or Safari verification.

## Reproduce

1. Export with the official Godot 4.7.2 binary and matching templates.
2. Generate isolated, validated, domain-earned fixtures with `FLOTRA_GROWTH_FIXTURES=/absolute/fixtures godot --headless --path flotra-campaign --script res://tests/release/growth_browser_fixtures.gd`.
3. Serve `docs/godot-jobs-preview` on localhost with correct JavaScript/WASM MIME types, for example with `python3 -m http.server --directory docs/godot-jobs-preview 8830`. This export uses non-threaded Web templates; COOP/COEP headers are not required.
4. Run:

```sh
CHROMIUM_EXECUTABLE=/usr/bin/chromium \
node flotra-campaign/tests/release/browser_preparation_journey.cjs \
  http://127.0.0.1:8830/ /absolute/evidence /absolute/fixtures \
  /absolute/export
```

Playwright and Chromium must be installed. `FLOTRA_PREPARATION_CASES` optionally selects a comma-separated subset, for example `fresh-375x567,mature-390x844`. The default matrix is six cases: direct quickstart, fresh preparation, and fully upgraded preparation at both viewports. The optional exported-directory argument records and rechecks the exact HTML/PCK/JS/WASM/storage/viewport hashes. The harness and imported fixture are hashed separately.

## What the gate checks

- Direct first-job quickstart remains available without entering preparation
- Opening preparation does not accept work, advance cargo/time, or spend funds
- All three existing transport modes remain selectable and free
- Layout candidate cancellation discards the uncommitted choice; applying remains free and returns to the same selected job
- Applied choices remain after closing preparation, while closing/reloading never starts the selected job
- The layout Apply button remains a pinned, readable 56-pixel target outside scrolling content
- An explicitly started job can be paused and reloaded without phantom resumption, changed cargo, reset time, or a duplicate reward
- A second completion compares with the actual prior completion of that same job in this session; elapsed time, throughput, operating modes, attempts, and saved best are independently asserted
- Reload retains saved best and rewards while clearing the session-only detailed comparison, with visible explanatory copy
- Fully upgraded copy acknowledges the finite catalog rather than promising further expansion purchases
- Canceled real browser touches do not activate a button, and fresh touch/camera input still works

## Cancellation timing

The suite runs two distinct tests:

1. A deterministic pre-frame burst uses a **test-only requestAnimationFrame callback gate** in the isolated browser context. The original animation callbacks are held while CDP delivers three genuine `touchStart` / `touchCancel` pairs. The harness asserts all six DOM events are trusted and no wrapped animation callback ran during the burst. It then restores the original scheduler and releases queued callbacks. This is controlled scheduling, not a claim about natural device timing.
2. An ordinary, unsuspended held touch crosses live rendering frames and is canceled through CDP. Fresh speed selection and camera rotation/reset must then work.

The gate does not call Godot mutation methods or edit diagnostic/game state. UI geometry, results, performance and campaign metrics are read-only. The only save import is an earned fixture installed at first load in a new isolated mature-test profile; no existing player storage is opened or modified.

## Evidence

The suite writes `preparation-journey.json`, per-case screenshots, exact browser renderer information, trusted cancellation traces, result snapshots and hashes. A failed case writes its last visible UI metrics and a failure screenshot. `status: passed` is emitted only after all selected cases and the export immutability check pass.

## Verified run: 5 October 2026 UTC

The final local matrix passed **6/6 cases**, with **zero browser JavaScript/console errors**, from 4 October 23:49:48 UTC to 5 October 00:05:50 UTC. Both sizes exercised fresh and fully upgraded warehouses plus direct quickstart. The renderer was Headless Chromium 154 with ANGLE/Vulkan SwiftShader; these results do not establish physical-phone frame rate or Safari behavior.

The two viewport sizes produced identical same-job measurements:

| Isolated warehouse and job | Previous: parcel mode | Replay: balanced mode | Saved best after reload | Rewards after two runs |
| --- | ---: | ---: | ---: | ---: |
| Fresh, `growth_1`, `clear_aisle` | 26.65 s | 34.20 s | 26.65 s | 280 |
| Fully upgraded, `route_pick`, `clear_aisle` | 51.55 s | 51.20 s | 51.20 s | 600 |

These are observations for the specified job, layout and equipment, not a claim that either mode is universally better. The displayed comparisons, throughput, attempt count, persisted best, and exactly-once rewards matched the read-only engine metrics. Reload preserved progress and rewards, stayed paused, and correctly explained that detailed comparison requires two completions in the current session.

Each of the four full journeys passed the controlled six-event trusted-touch burst with zero animation callbacks during the burst, ordinary unsuspended cancellation, and subsequent fresh speed/camera input. Screenshots were visually inspected at both phone sizes; the preparation controls, complete-catalog wording, result comparison and saved-best text remain readable.

Exact tested bytes:

- PCK: `e22fd39d98467c0fb29061fb38a9c1f610993e7afff38fdd08061896184b6d7f`
- Viewport bridge: `9eed4614bd5e6f0b96ea5c347ce1ae7a5b018e3860aa48a39909abe8d7e72bea`
- Browser harness: `33fa90859b2ec02cf4369c5bf8d6baea31eb661df10789b786edc64122396090`

Generated evidence is retained in `build/recovery-evidence/browser-preparation/`: `preparation-journey.json`, `browser.log`, and 14 screenshots. The JSON records all six export hashes, the fixture/harness hashes, per-case renderer information, cancellation event traces and comparison results. The export hashes were checked again at the end of the successful run.
