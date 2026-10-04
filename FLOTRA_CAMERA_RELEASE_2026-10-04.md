# FLOTRA camera controls — 2026-10-04

## Player-facing change

The warehouse can now be explored instead of remaining locked to a single overview.

- Drag with one finger or the mouse to pan
- Pinch, use the wheel, or tap `＋` / `−` to zoom between 1× and 3×
- Tap `左90°` / `右90°` to see the warehouse from any of four bearings
- Tap `全体` to restore the original bearing, zoom and position
- Briefly tap a shelf or packing bench to open the existing placement editor

The camera row stays visible during ordinary play, with 18px text and touch targets at least 56px high/wide. It uses a reserved strip above the bottom actions. Short landscape moves it into the header; safe-area widths adapt spacing without shrinking touch targets. Reading sheets retain their own touch scrolling. The editor keeps its precise equipment/candidate framing; closing it restores the player's overview camera.

Camera state belongs only to the current session. It is not stored in campaign saves and does not change money, progress, equipment, cargo, operating modes, reward timing, selected speed or the foreground clock. Reload returns to the overview while the existing save/resume behavior remains intact.

## Why the view was fixed

The previous camera fit unconditionally used one isometric bearing and the full warehouse bounds. Its pointer handler supported equipment selection only. The new view separates overview pan/zoom/bearing from editor framing and reapplies that state after viewport or warehouse geometry changes.

Pan bounds include the actual main hall, annex, all purchased wings and service connectors. A rounded pan envelope prevents the empty diagonal corners of an isometric bounding rectangle from swallowing the whole view. Zoom is bounded; rotation recenters the current zoom; reset is always one visible tap away. There is no inertia or automatic orbit.

Offscreen overview captions are hidden instead of attaching misleading labels to the screen edge. Visible captions remain screen-space 18px text, independent of zoom. Selected/candidate editor captions keep their previous behavior.

## Interruption and input safety

- A drag remains a drag even if it returns to its starting point; it cannot select equipment on release
- Multi-touch identities survive finger release/replacement without becoming a tap
- Emulated mouse/touch duplicates are ignored by the world input handler
- A canceled pointer, missing mouse release, focus loss, application pause, resize, sheet opening or crossing into HUD space cancels the held gesture
- A gesture begun on a HUD button or scroll sheet cannot start a camera gesture halfway through
- The existing dismissal epochs and fresh-press checks still guard the camera buttons

Godot 4.7.2 Web mouse motion does not forward the browser's `buttons` bitmask. A read-only, passive DOM observation supplies that missing evidence so a genuinely missed mouse release cannot keep panning on hover. This bridge does not synthesize input, capture pointers, prevent browser defaults or access game/storage state. Its DOM-mock regression covers unknown state, touch isolation, hover recovery, pointer cancellation and blur.

## Verification

The independent native camera suite passed **5,175 checks with zero failures** on official Godot 4.7.2. It uses real root-viewport input dispatch and disposable test profiles. Coverage includes:

- Mouse/touch parity, wheel, pinch, keyboard activation, five visible camera buttons, zoom bounds and exact reset
- Canceled touch, three-to-two-to-one fingers, UI crossing in both directions, lost release, focus/pause, resize and held-button interruption
- Editor framing and return to the prior camera
- Exact exported game-state equality before/after camera operations
- Fresh and fully earned four-wing warehouses, four bearings, all eight cardinal/diagonal pan extremes
- 351×567 safe-area width, 375×567, 375×667, 390×844, 430×932 and 568×320

At the worst tested zoom/pan/bearing, actual projected floor still occupied **9.53%** of the viewport. Every whole-warehouse reset included all real floor corners. Adjacent checks also passed: existing equipment input (1,038), phone readability (6,021), growth view/geometry (210,573), and control comfort.

`browser_camera_controls.cjs` drives the actual exported WebGL app through headed Chromium touch/mouse input. CI runs the four phone sizes at DPR 1/2/3, alongside the existing phone geometry, old-save, earned-growth, operation and mature-performance suites. It checks quarter-turns/reset, pan/pinch, touch cancellation, real tab focus, resizing, UI gesture isolation, all four wings, callout geometry and unchanged campaign state. Browser fixtures are earned through public domain actions and loaded only into isolated test contexts. Diagnostics are opt-in and read-only.

The old slow-frame regression's mouse helper was also corrected to preserve a held button mask immediately before its synthetic release. Previously it injected a no-button hover between mouse-down and mouse-up, which the new lost-release guard rightly canceled. All 14 original slow-frame assertions, guard intervals and epoch checks remain intact and passed again.

The final release gate requires the full native aggregate and all browser CI jobs to pass for the exact committed export. Publication additionally verifies the merge/Pages workflow and default-verified-HTTPS byte identity for the HTML, PCK, JS, WASM and two bridge files. The loader retains `persistentPaths: []` and `canvasResizePolicy: 0`.

### Reproduce

```sh
GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/test.sh
GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/export_web.sh
# Build earned-state fixtures as in .github/workflows/flotra-campaign.yml,
# serve docs/godot-jobs-preview locally, then:
xvfb-run -a node flotra-campaign/tests/release/browser_camera_controls.cjs \
  http://127.0.0.1:8826/ build/camera-browser build/camera-fixtures
```

Chromium CSS/DPR emulation and Linux native checks are not physical iPhone/Safari verification. No claim is made about physical-device GPU performance. There is no browser certificate-warning bypass in the publication verification.
