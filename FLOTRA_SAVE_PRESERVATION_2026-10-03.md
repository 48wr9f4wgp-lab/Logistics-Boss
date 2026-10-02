# FLOTRA: preserve unresolved saves and explain persistence status

Base: local UI-candidate snapshot `264844016fd1c6a8475419d7c77f63fcc38a61c2`.

Status: separate local review candidate. This batch has not been committed, pushed, proposed as a PR, merged, or deployed.

## Reproduced risk

On the baseline, two syntactically valid unsupported-version save files caused main to start a fresh ¥5,000 simulation without a warning. The first ten-second autosave replaced the primary; the second replaced the remaining backup. Both original files were lost. This was a pre-existing issue, not introduced by the preceding play-flow presentation changes.

The exact original probe and before/after logs are retained under `build/saveguard-evidence/original-reproduction/`. The probe uses synthetic schema 999 to represent data from a newer executable. It never reads a player's real profile.

## Changes

- `LogisticsSaveStore` now distinguishes load and save outcomes and latches write protection when existing data cannot safely be resumed
- The write boundary checks every ordinary save call, including direct callers and new store instances that did not load first
- Unresolved primary/backup files remain untouched; a newer-version primary, backup, or interrupted-write temporary file also blocks overwriting, even when another older copy can be read
- Corrupt data is parsed and type-checked before passing known fields to Domain conversion code. Malformed values do not trigger script errors or let a direct save bypass protection
- A usable current primary, ordinary usable backup fallback, and first-ever fresh profile remain writable. After corrupt-primary recovery, the first successful save preserves the usable backup rather than rotating corruption over it
- Protection does not silently disappear after a repeated read. The existing explicitly confirmed reset path clears it only after all requested removals succeed. No recovery/reset shortcut was added
- A passive warehouse notice explains protected/unsaved play, backup restoration, actual save failure, and an actual successful retry. Failures persist; brief success/recovery messages keep their reading time when hidden and do not repeat on ordinary autosaves
- Protected sessions also prevent both tutorial completion markers from being created or overwritten, including when protection begins later. Existing markers are still respected on startup; normal sessions still record completion
- Management, zone inspection, and reset confirmation hide the notice. The growth goal moves below it; the notice cannot intercept taps

No Domain, economy, balance, saved-payload schema, migration implementation, asset, geometry, or remote-service changes. Existing historical-version loading behavior is retained; no new migration was introduced.

## Verification completed during implementation

Official Godot `4.7.2.stable.official.ed1daf0bf`; disposable XDG data/config/cache profiles throughout.

- `save_preservation_smoke`: 312 assertions, zero failures
  - Fresh profile, valid primary, missing/corrupt primary with usable backup, corrupt backup with valid primary
  - Both corrupt/non-object/invalid-schema files, unsupported future copies, future temporary file, and orphan temporary files
  - Invalid known numeric, nested staffing, and contract field shapes
  - Direct saves before loading, repeated load/save attempts, new-store reentry, byte-for-byte source preservation
  - Explicit reset success/failure and actual read-only-directory write failure followed by successful retry
- `save_status_journey_smoke`: 309 assertions, zero failures, actual main at 375×667, 390×844, and 430×932
  - Autosave, application-pause, window-close handler, direct save, and scene reentry cannot overwrite protected files
  - Persistent notice, Management/Zone/Reset-Cancel occlusion, real engine-parsed goal/dock/close/cancel gestures
  - Backup reading time, real file-write failure, successful autosave retry, and no repeated save-notification spam
- Existing `save_recovery_smoke`, `runtime_startup_smoke`, and `player_journey_smoke` pass; the latter includes 368 assertions
- Independent review expanded to 2,820 assertions across 354 cases, including minimal historical schemas, known-field type mutations, nested contracts, unreadable files, and version combinations
- Native Linux captures covered 18 actual-main status states across the three portrait sizes, including actual isolated file-write failure and successful retry; pixel review found no layout blocker

The existing CI workflow's isolated diagnostic-gated step includes the new preservation and composed-main regressions. Godot's exit code alone is insufficient: expected malformed-save inputs must be handled without script/engine error diagnostics.

The final aggregate, import/startup, Web export, clean-patch application, and exact final source hashes are recorded separately in the final evidence packet; the focused counts above are not a substitute for those gates.

## Remaining limits

- This prevents unsafe replacement and reports status; it does not repair corrupt or unsupported data or claim the latest progress was recovered
- Both-unusable sessions may still show/play a fresh in-memory warehouse, clearly marked as unsaved. Existing files are retained for compatible recovery
- No iPhone/iPad/Safari or Android physical-device save-continuity, app-kill, storage-quota, or performance claim
- The notification tests invoke the real main handlers, but headless tests do not establish platform delivery of lifecycle events

## Reproduce

`GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash godot/tools/run_polish_checks.sh save_preservation_smoke save_preservation_review_smoke save_status_journey_smoke save_recovery_smoke runtime_startup_smoke player_journey_smoke`

All save fixtures require `FLOTRA_POLISH_ISOLATED=1` and a disposable profile. The shared fixture helper is `godot/tests/save_preservation_fixtures.gd`; it is test-only and never part of the runtime scene.
