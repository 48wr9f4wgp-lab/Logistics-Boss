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

Web loader must retain `persistentPaths: []`: it never mounts the legacy `/userfs` IndexedDB database. Candidate saves use only localStorage keys `flotra.campaign.dispatch.v5` and `.backup`, guarded by browser-exclusive Web Locks and strict schema5/domain validation. Native writes use `campaign-dispatch-v5.json` and `.backup.json` in the unchanged `FLOTRA-campaign-release-v1` user directory. When both new slots are absent, valid campaign schemas1/2/3 can be read from the old release slots using preserved original validators. Old primary/backup are never overwritten. Schema4, unknown formats, unsafe recovery and concurrent/uncertain writes visibly stop progress instead of starting a fresh warehouse. See the dispatch candidate section below for rollback limits.

During play, the game captures an immutable checkpoint every five seconds of foreground progression. Automatic validation and writing are spread over the next three rendered frames; all shape/domain checks remain required. Before additional foreground progression would exceed one second after capture, remaining work is completed synchronously. This can add up to that progression allowance to the existing five-second unsaved window; it is not a wall-clock write guarantee when a browser suspends callbacks, terminates abruptly, or refuses storage.

Successful committed actions, pause/focus changes and exit notifications cancel any older pending checkpoint and synchronously save the current state. Generation checks prevent an older checkpoint from writing afterward. The status remains `自動保存中` until the actual commit succeeds; only then does it say `自動保存済み`. Resume begins paused. An interrupted browser can still return to the last successful checkpoint, so do not close while saving or when the status reports a failure. New/old storage locks and observed-slot checks still run immediately before every write.

## Verification boundary

Linux native rendering and engine-input tests at 375×667, 390×844 and 430×932 do not establish physical iPhone/Safari compatibility or performance. Browser storage tests are distinct from WebGL gameplay tests. Keep those remaining limits explicit in release notes.

## Final readability and scoring

The final pass adds readable screen-space location labels, tighter phone framing, live medal targets, explicit prerequisite/holding explanations and precise replay records. Inclusive medal thresholds use centisecond precision. The historical schema3 importer corrected valid older boundary badges; the schema5 candidate instead preserves valid imported history exactly. See `FLOTRA_FINISH_PASS_2026-10-03.md` at repository root.

## CSS-pixel phone correction

The October 4 correction fixes a Web-only DPR mismatch: the HUD now lays out in the canvas's actual safe-area CSS rectangle while its drawing buffer remains full-resolution. Body and world labels are 18 CSS pixels or larger and touch controls are 56 CSS pixels. Reading screens scroll at full height; placement has a pinned action and a compact short-landscape layout. See `FLOTRA_PHONE_READABILITY_2026-10-04.md`.

Use `bash flotra-campaign/export_web.sh` to rebuild the export with its checked-in shell and viewport/storage bridges. The browser regression runs the actual committed WebGL2 export at 375/390/430 CSS widths and DPR 1/2/3, including toolbar-height changes, orientation, DPR changes, synthetic safe areas and real touch events. This Chromium emulation is distinct from physical iPhone/Safari verification.

## Growth verification

Growth adds independent balance, old-save migration, native-storage backup, touch-scroll, geometry and mature-renderer regressions. `browser_growth_geometry.cjs` exercises the current growth export across CSS widths/DPRs; `browser_growth_journey.cjs` verifies the first earned expansion, zero-wallet recovery, old in-flight migration and mature WebGL performance.

## Player-experience polish

The 操作 menu remembers speed, optional menu auto-pause and reduced walking animation. Backgrounding or reloading leaves the warehouse paused until explicit resume. First-job and next/replay actions are immediately reachable; affordable equipment comes first, while unlocked choices that still need funds stay visible with exact shortfalls; only progression/prerequisite-locked and owned equipment is folded. Between jobs, three free operating choices provide balanced, real three-parcel-cart and pallet-priority workflows. Equipment previews show capacities and tradeoffs; queued layout changes can be cancelled before physical movement begins. See `FLOTRA_EXPERIENCE_RELEASE_2026-10-04.md` and the Japanese player guide under `docs/guides/`.

## Camera controls

Drag the warehouse with one finger or the mouse to pan. Pinch or use the mouse wheel / plus-minus buttons to zoom from whole-warehouse scale up to 3×. The visible 左90° / 右90° buttons change the camera bearing; 全体 restores the original whole-warehouse view. Camera state is session-only and never mutates campaign saves, money, equipment, cargo or the foreground clock. The layout editor retains its own precise equipment framing and restores the overview camera when closed.

The 56px camera row occupies a reserved strip above the bottom HUD, not the scene's callouts. Short landscape puts it in the header. Menus, HUD crossings, canceled touch, focus loss and resize cancel any held camera input. See `FLOTRA_CAMERA_RELEASE_2026-10-04.md` for verification and boundaries.

## Optional preparation and replay comparison

Each available job can still start immediately, or open a preparation sheet showing its manifest, reward, current layout and the three existing free operating modes. Confirmed mode/layout choices persist normally; merely opening preparation or canceling an uncommitted layout preview never accepts a job. Completed jobs offer direct replay and an adjust-and-replay route back to the same job.

Results compare the previous completion of the same job during the current launch: game-time duration, throughput, aggregate aisle wait, operating mode and final layout. Equipment and relocation differences are disclosed. Detailed comparison state is session-only; saved historical best times are unchanged. The schema5 candidate additionally stores the dispatch selection and discloses known dispatch differences in session comparisons. A reload never invents a previous operating setup from incomplete saved records.

Web touch cancellation has a separate DOM-capture notification because the Godot loader otherwise maps cancellation to a normal release. Earlier buffered starts are processed before invalidating held UI/world gestures, including several rapid start/cancel pairs before one rendered frame. Normal release cleanup and fresh input remain available.

## Compact phone preparation

The three full-size free operating choices appear together before long explanations, including on a 375×567 CSS-pixel phone. Detailed conditions, operating tradeoffs and reversible layout adjustment expand on demand. Start stays pinned below the scroll area. The details disclosure is session-only; selecting a mode still commits through the original guarded scene action. See `FLOTRA_COMPACT_PREPARATION_2026-10-05.md`.

## Save-size safety

Before any storage write, campaign saving rejects a serialized Variant payload above the existing 2,000,000-byte reader limit and retains the previous primary/backup with explicit Japanese unsaved feedback. The envelope, checksum, migrations and save schedule are unchanged. Browser quota remains a separate possible failure below this bound. See `FLOTRA_SAVE_SIZE_GUARD_2026-10-05.md`.

## Visible next equipment choices

Unlocked equipment stays visible even before it is affordable, ordered by price after currently affordable choices. Existing free operation controls keep their prior scroll depth. During a job, the same cards explain that purchases wait until completion. No prices, effects, simulation rules or persistence change. See `FLOTRA_UPGRADE_VISIBILITY_2026-10-06.md` and the focused `upgrade_visibility.gd` / `browser_upgrade_visibility.cjs` regressions.

## Combined warehouse and equipment polish

The warehouse material pass uses subdued empty-floor markings, truthful live lane colors, neutral racks and carton-counted stored pallets, with 2× MSAA on the unchanged-size 3D viewport. The source is exported together with visible next equipment choices. Geometry, pallet/save parity and material-state regressions run in the aggregate suite using earned mature fixtures; existing browser performance limits remain unchanged. See `FLOTRA_COMBINED_POLISH_2026-10-06.md` for scope, gates and verification boundaries.


## Dispatch board candidate (schema5)

The candidate adds a 300-cost picking dispatch board, unlocked after growth_4
and ownership of crew_6, robot_4 and auto_pack. Purchase keeps six reservations.
Between jobs, owners can choose six or twelve for free. A paused unfinished
job still locks the choice. These are shelf/in-transit/packing work reservations,
not twelve new physical storage cells; more work can increase aisle congestion.
All existing jobs and equipment prices remain unchanged.

A new route_parcel_120 becomes available after growth_4, before buying the board.
It offers20 six-unit pick manifests at0.5-second intervals, first arrival at0.5s,
reward300. The medal thresholds reuse the existing parcel route's180/320 seconds.
Same-job comparisons disclose the chosen effective dispatch window when both
runs have recorded it.

The new entry point writes only schema5 envelopes to the dedicated Web keys
flotra.campaign.dispatch.v5 and .backup, or native campaign-dispatch-v5.json and
.backup.json in the unchanged campaign user directory. If both new slots are
absent, validated legacy1/2/3 saves can be read with frozen original validators;
old primary and backup remain unchanged. Schema4 and unknown formats stop safely.
Existing v5 data never silently falls back to an older campaign. Corrupt-backup
recovery and concurrent/uncertain writes stop progress and mutations rather than
starting a fresh warehouse. Returning to the old executable uses the retained
old checkpoint and cannot carry newer purchases/progress backward.

This is a local source candidate. See FLOTRA_DISPATCH_CANDIDATE_2026-10-07.md
for the checked scope and remaining publication gates.
