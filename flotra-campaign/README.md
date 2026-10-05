# FLOTRA campaign

Self-contained, portrait-first Godot 4.7.2 campaign. This project is independent of the legacy `godot/` game and its saves. The public URL evolves the existing `docs/godot-jobs-preview/` trial.

## Play

Deliver a small order, collect a reward, and grow into a four-wing automated warehouse. Six short milestones introduce expansion, staff, courier robots, larger shelving and automatic packing. Every growth job pays again. There is no timer failure or entry fee; a zero-cash player can always work toward the next improvement. Standard speed is 2×, with 1× and 4× available from the top-left 操作 menu.

The starter crew is three. Four connected northward wings add 32 real pallet bays and side service aisles; six people and four robot carriers can work together. Shelf location remains a free, reversible capacity/travel choice. After the growth steps, paid parcel/storage routes and an optional 288-unit dispatch remain available. See `FLOTRA_GROWTH_RELEASE_2026-10-04.md` at repository root.

Existing campaign saves retain their money, equipment, records and in-flight cargo. An unfinished old job continues with its original physical rules; the new growth profile begins with a new growth job. Old best-time records remain inspectable.

## Run and test

Open `project.godot` with Godot 4.7.2, or run `godot --path flotra-campaign` from repository root. First import assets with `godot --headless --editor --path flotra-campaign --import`.

Run the suites with `bash flotra-campaign/test.sh`. Tests cover the finite campaign, conservation, purchases, exact in-flight save/resume, malformed input, storage isolation, and phone-size UI/input behavior. Rendering and physical device verification are separate.

## Save isolation

Web loader must retain `persistentPaths: []`: it never mounts the legacy `/userfs` IndexedDB database. Campaign saves use only localStorage keys `flotra.campaign.release.v1` and `.backup`, guarded by a browser-exclusive Web Lock and strict schema/domain validation. New saves use payload schema 3; valid schema-1 and schema-2 campaign progress is explicitly migrated after validation by the preserved original models. Unsupported or unavailable storage is visibly reported; gameplay does not pretend it saved. Corrupt, foreign, future-version or conflicting saves are not overwritten automatically. Native builds use the dedicated `FLOTRA-campaign-release-v1` user directory.

The game saves every five seconds during play and on successful committed actions and pause/focus changes. Resume begins paused. Browser refresh may therefore lose up to the most recent unsaved few seconds; do not close if the save status reports a failure.

## Verification boundary

Linux native rendering and engine-input tests at 375×667, 390×844 and 430×932 do not establish physical iPhone/Safari compatibility or performance. Browser storage tests are distinct from WebGL gameplay tests. Keep those remaining limits explicit in release notes.

## Final readability and scoring

The final pass adds readable screen-space location labels, tighter phone framing, live medal targets, explicit prerequisite/holding explanations and precise replay records. Inclusive medal thresholds use centisecond precision. Valid older boundary badges are corrected on import without changing operational progress. See `FLOTRA_FINISH_PASS_2026-10-03.md` at repository root.

## CSS-pixel phone correction

The October 4 correction fixes a Web-only DPR mismatch: the HUD now lays out in the canvas's actual safe-area CSS rectangle while its drawing buffer remains full-resolution. Body and world labels are 18 CSS pixels or larger and touch controls are 56 CSS pixels. Reading screens scroll at full height; placement has a pinned action and a compact short-landscape layout. See `FLOTRA_PHONE_READABILITY_2026-10-04.md`.

Use `bash flotra-campaign/export_web.sh` to rebuild the export with its checked-in shell and viewport/storage bridges. The browser regression runs the actual committed WebGL2 export at 375/390/430 CSS widths and DPR 1/2/3, including toolbar-height changes, orientation, DPR changes, synthetic safe areas and real touch events. This Chromium emulation is distinct from physical iPhone/Safari verification.

## Growth verification

Growth adds independent balance, old-save migration, native-storage backup, touch-scroll, geometry and mature-renderer regressions. `browser_growth_geometry.cjs` exercises the current growth export across CSS widths/DPRs; `browser_growth_journey.cjs` verifies the first earned expansion, zero-wallet recovery, old in-flight migration and mature WebGL performance.

## Player-experience polish

The 操作 menu remembers speed, optional menu auto-pause and reduced walking animation. Backgrounding or reloading leaves the warehouse paused until explicit resume. First-job and next/replay actions are immediately reachable; affordable equipment comes before folded future/owned equipment. Between jobs, three free operating choices provide balanced, real three-parcel-cart and pallet-priority workflows. Equipment previews show capacities and tradeoffs; queued layout changes can be cancelled before physical movement begins. See `FLOTRA_EXPERIENCE_RELEASE_2026-10-04.md` and the Japanese player guide under `docs/guides/`.

## Camera controls

Drag the warehouse with one finger or the mouse to pan. Pinch or use the mouse wheel / plus-minus buttons to zoom from whole-warehouse scale up to 3×. The visible 左90° / 右90° buttons change the camera bearing; 全体 restores the original whole-warehouse view. Camera state is session-only and never mutates campaign saves, money, equipment, cargo or the foreground clock. The layout editor retains its own precise equipment framing and restores the overview camera when closed.

The 56px camera row occupies a reserved strip above the bottom HUD, not the scene's callouts. Short landscape puts it in the header. Menus, HUD crossings, canceled touch, focus loss and resize cancel any held camera input. See `FLOTRA_CAMERA_RELEASE_2026-10-04.md` for verification and boundaries.

## Optional preparation and replay comparison

Each available job can still start immediately, or open a preparation sheet showing its manifest, reward, current layout and the three existing free operating modes. Confirmed mode/layout choices persist normally; merely opening preparation or canceling an uncommitted layout preview never accepts a job. Completed jobs offer direct replay and an adjust-and-replay route back to the same job.

Results compare the previous completion of the same job during the current launch: game-time duration, throughput, aggregate aisle wait, operating mode and final layout. Equipment and relocation differences are disclosed. Detailed comparison state is session-only; schema 3 and saved historical best times are unchanged. A reload never invents a previous operating setup from incomplete saved records.

Web touch cancellation has a separate DOM-capture notification because the Godot loader otherwise maps cancellation to a normal release. Earlier buffered starts are processed before invalidating held UI/world gestures, including several rapid start/cancel pairs before one rendered frame. Normal release cleanup and fresh input remain available.

## Compact phone preparation

The three full-size free operating choices appear together before long explanations, including on a 375×567 CSS-pixel phone. Detailed conditions, operating tradeoffs and reversible layout adjustment expand on demand. Start stays pinned below the scroll area. The details disclosure is session-only; selecting a mode still commits through the original guarded scene action. See `FLOTRA_COMPACT_PREPARATION_2026-10-05.md`.

## Save-size safety

Before any storage write, campaign saving rejects a serialized Variant payload above the existing 2,000,000-byte reader limit and retains the previous primary/backup with explicit Japanese unsaved feedback. The envelope, checksum, migrations and save schedule are unchanged. Browser quota remains a separate possible failure below this bound. See `FLOTRA_SAVE_SIZE_GUARD_2026-10-05.md`.
