# FLOTRA campaign

Self-contained, portrait-first Godot 4.7.2 campaign. This project is independent of the legacy `godot/` game and its saves. The public URL evolves the existing `docs/godot-jobs-preview/` trial.

## Play

Accept a finite contract, arrange the shelf and packing bench, deliver every box, and spend first-completion rewards on real upgrades. Six contracts form the campaign; after the introduction, bulk-storage and small-order branches are both available. Cleared jobs remain replayable for medals and best times. Replays do not mint extra rewards.

The starting crew is three. Upgrades can add two staff, double shelf capacity, improve packing handling, and add two physical pallet bays. Shelf position still trades four pallet bays for shorter pick travel. There is no single universally best layout.

## Run and test

Open `project.godot` with Godot 4.7.2, or run `godot --path flotra-campaign` from repository root. First import assets with `godot --headless --editor --path flotra-campaign --import`.

Run the suites with `bash flotra-campaign/test.sh`. Tests cover the finite campaign, conservation, purchases, exact in-flight save/resume, malformed input, storage isolation, and phone-size UI/input behavior. Rendering and physical device verification are separate.

## Save isolation

Web loader must retain `persistentPaths: []`: it never mounts the legacy `/userfs` IndexedDB database. Campaign saves use only localStorage keys `flotra.campaign.release.v1` and `.backup`, guarded by a browser-exclusive Web Lock and strict schema/domain validation. Unsupported or unavailable storage is visibly reported; gameplay does not pretend it saved. Corrupt, foreign, future-version or conflicting saves are not overwritten automatically. Native builds use the dedicated `FLOTRA-campaign-release-v1` user directory.

The game saves every five seconds during play and on successful committed actions and pause/focus changes. Resume begins paused. Browser refresh may therefore lose up to the most recent unsaved few seconds; do not close if the save status reports a failure.

## Verification boundary

Linux native rendering and engine-input tests at 375×667, 390×844 and 430×932 do not establish physical iPhone/Safari compatibility or performance. Browser storage tests are distinct from WebGL gameplay tests. Keep those remaining limits explicit in release notes.

## Final readability and scoring

The final pass adds readable screen-space location labels, tighter phone framing, live medal targets, explicit prerequisite/holding explanations and precise replay records. Inclusive medal thresholds use centisecond precision. Valid older boundary badges are corrected on import without changing operational progress. See `FLOTRA_FINISH_PASS_2026-10-03.md` at repository root.
