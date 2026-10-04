# FLOTRA phone readability correction

## Root cause

The previous campaign disabled Godot content scaling at runtime. The exported Web loader still created a high-DPI canvas: on a 390×844 CSS-pixel phone at DPR 3, its backing buffer was 1170×2532 pixels. The HUD laid itself out in those device pixels instead of CSS pixels. A 16-unit button label therefore occupied only 5.33 CSS pixels and a 48-unit target only 16 CSS pixels. Native 375-pixel screenshots did not cover this browser path.

The defect was reproduced in actual Chromium WebGL2 rendering with fresh isolated browser profiles, not inferred solely from source or raster mockups.

## Correction

- The web wrapper owns the canvas's CSS rectangle, reserves notch/home-indicator insets, and follows the visible browser height
- The drawing buffer remains full DPR; the UI's logical coordinate space matches the actual CSS rectangle rather than a fixed 390×844 design canvas
- Godot canvas-item scaling maps both rendering and real browser input consistently; no DPR cap or artificial font-only compensation
- Readable 18px body/button/world text, 20–24px primary headings, and 56px touch controls
- Clearer live view with fewer simultaneous rows, larger warehouse space, full-height reading sheets, and a pinned placement action outside the editor's scroll area
- Portrait layouts remain usable at 375×567, 375×667, 390×844 and 430×932; short landscape uses a header-safe reading layout

## Scope and preservation

The six contracts, actual upgrades, replay scoring and PR145/146 save format are unchanged. `campaign-storage.js` is byte-identical to the prior release. The loader retains `persistentPaths: []`; the original `/godot-preview/`, its assets and its user data are untouched. Campaign localStorage remains isolated with the same backup and exclusive writer lock.

`?phone_qa=1` enables read-only geometry diagnostics for browser regression. It exposes no gameplay, save, reset or import commands. Browser tests use new isolated contexts and act through real browser touch events.

## Reproduce

- Source regression: `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/test.sh`
- Export: `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/export_web.sh` with matching official Web templates installed
- Serve `docs/`, then run `node flotra-campaign/tests/release/browser_phone_geometry.cjs http://127.0.0.1:8812/godot-jobs-preview/ build/browser-phone`
- The browser suite needs Playwright 1.62.1 and Chromium; CI runs it separately against the committed export

## Verification boundary

Checks distinguish actual Chromium WebGL2 rendering and browser touch, headless Godot domain/input suites, compiled-PCK regression, and native rendered captures. Synthetic safe-area insets and Chromium phone emulation are not a physical iPhone/Safari test. Physical-device performance remains unverified.
