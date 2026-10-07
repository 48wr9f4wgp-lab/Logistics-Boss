# Dispatch candidate: local Web integration

Status: detailed v3 functional verification and the separately exported final artifact smoke both passed. The complete final project input set is frozen. This is an unpublished candidate, not performance/CI qualification or physical-phone certification.

## Exact artifact

- Implementation base: PR155, `3a4b6e7c45aadf175268993aa8004c2969c5a136`
- Standard export: `flotra-campaign/export_web.sh`, Godot `4.7.2.stable.official.ed1daf0bf`, matching `4.7.2.stable/web_nothreads_release.zip`
- Final frozen local build: `../flotra-dispatch-web-build-final`
- Detailed14-case test artifact: `../flotra-dispatch-web-build-v3`
- Final PCK SHA256: `571193f366e0389050d0ce0045127b21cb6e380e9bfd66c10bf7df4b4b0d2afc`
- Template ZIP SHA256: `d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0`
- Exported JS and WASM are byte-identical to the verified base publication. The candidate uses a new PCK and its own dispatch-storage bridge. This was a full standard export, not a pack-only substitution.
- `FLOTRA_DISPATCH_ARTIFACTS_2026-10-07.json` records current runtime/export-source hashes and exact final output hashes. Browser-resolved asset hashes matched that output. Runtime source hashes were unchanged through export and verification.

Test-only browser/fixture adaptations were developed separately and do not change production runtime behavior, but the all-resources export includes compiled test scripts, so these edits can change PCK bytes. The detailed14-check results below apply specifically to build-v3. Its runtime manifest excluded the changing test files; it is not complete input provenance for a later pack. The test edits are now frozen, and a final standard export has recorded complete project-input provenance and passed the bounded boot/hash/schema5-preservation smoke below. No assumption about PCK identity was used.

## Real-browser results

Fresh, disposable cloud Chromium contexts at 390×844 and 375×667 CSS pixels, DPR2. All saves were independently earned synthetic fixtures, never the user's save data. Interactions used trusted browser touch and ordinary wheel scrolling; the existing opt-in geometry/state diagnostics were read-only.

1. The actual exported engine loaded earned legacy schema3, wallet350 and all ten earlier upgrades. Loading did not create a new slot or change either old slot.
2. Actual board purchase charged300 once, retained6, and wrote schema5 to `flotra.campaign.dispatch.v5`. The first write created no fabricated backup; subsequent checkpoints used the dedicated `.backup`. Both old release keys stayed byte-identical throughout.
3. Real controls switched6→12→6→12 free, retaining wallet50.
4. The new120-parcel job ran in the actual Web engine. Both selectors stayed disabled during the paused unfinished job; touching6 could not change the saved checkpoint.
5. Reload resumed paused with exact money, equipment, progress, clock, results, layout and selected12. A real preference action then re-saved the imported state. Native decoding proved every Variant byte was identical apart from that intentional preference change, including all120 cargo records, carried cargo IDs and a live packing timer. The final checkpoint was at15.2 simulation seconds, wallet50, selected12.
6. A concurrent second tab could read the existing v5 state but its write was refused. After the narrow fix below, the refusal immediately showed a protection sheet and stopped progression; all storage slots stayed unchanged. The original tab remained able to save.
7. Purchase and free12 selection worked at375×667 with readable56px controls. Captured explanations identify the congestion tradeoff and do not claim more physical storage or universal speed improvement.
8. Unknown schema4 in the old source visibly stopped without writing. Existing invalid v5 never fell back to the old warehouse. Recovery from a valid v5 backup remained read-only and visibly protected.
9. The final browser loaded `dispatch-storage.js`, not the old bridge; loader `persistentPaths` was empty, canvas resize policy was0, and the disposable origin's IndexedDB list stayed empty.

The final focused run recorded14 checks, zero page errors and clean browser exit0. Its final JSON, browser identity, synthetic checkpoints, console output and screenshots are under `../flotra-dispatch-web-evidence`.

## Final complete-input freeze and smoke

After the adapting worker confirmed all source/test edits were frozen, the entire stable project was standard-exported to the new `../flotra-dispatch-web-build-final` folder. The manifest now separates:

- `sourceSHA256`:65 runtime/export inputs, unchanged from the detailed v3 verification
- `fullProjectSourceSHA256`: all189 project files outside `.godot`, including tests, fixture generators, JavaScript helpers, test.sh, README and import descriptors
- `generatedGodotCacheSHA256`:21 post-export generated-cache entries for provenance
- Engine/template hashes, the standard export command and all11 output asset hashes

All189 project file hashes were unchanged before/after export. The final strict helper check verified the complete file-name set and every content hash again after the browser smoke. All11 final output files were then compared directly with v3 and were byte-identical, including the PCK; this is an observed result of the fresh export, not an assumption that test edits cannot affect it.

The bounded actual-browser run on the final directory passed four checks with zero page errors and clean exit0:

1. Booted the existing schema5 in-flight fixture, choosing it over divergent older release slots
2. Used real1x→2x UI actions while paused to save, producing exactly the original complete schema5 envelope again, while both legacy slots stayed byte-identical
3. Reloaded still paused with unchanged complete save, money, clock, equipment and cargo progress
4. Matched browser-resolved output hashes, loaded the new storage bridge, and confirmed empty persistent paths and IndexedDB

Final-artifact evidence: `../flotra-dispatch-final-evidence/final-pack-smoke.json`, `final-export-provenance.json`, `full-project-inputs-before-export.json`, `full-input-validation.log`, `export-final.log`, and final screenshots. The four-check smoke is separate from the earlier detailed14-check run. The historical immutable performance control and all unqualified-until-comparison/CI boundaries remain unchanged.

## Integration defect fixed

The real two-tab case exposed that Web `writer_unavailable` previously warned but allowed continued unsaved play. Local corrections:

- `prototype/dispatch_save.gd`: Web writer and legacy-writer refusal now enter terminal protection. The message does not assume another tab is the only possible cause; missing/refused Web Locks also fail safely.
- `prototype/growth_main.gd`: after a save enters protection, immediately reuse the existing stop/mutation guard and show the protection sheet, including while already paused.
- `tests/release/dispatch_scene_safety.gd`: focused mock cases verify both Web refusal reasons, immediate protection, stopped progress and rejection of later mutations. Passed in an isolated native profile.

Oversize/quota warnings are unchanged. Native `native_writer_unavailable` remains distinct: it blocks saving with native-specific guidance and does not delete a possibly stale lock. It is not claimed to have the same terminal-stop behavior as Web Locks.

Godot also generated the previously absent `.gd.uid` sidecars for dispatch comparison, save-migration and scene-safety tests. No simulation, renderer, scoring or old-job behavior was changed by this Web fix.

## Qualification boundaries

- No commit, push, PR, public asset change, CI or deployment was performed in this verification task.
- No PR153/156 integration, failed graphics rebuild or performance sweep was run.
- `FLOTRA_DISPATCH_ARTIFACTS_2026-10-07.json` is explicitly unqualified pending the fixed comparison and CI. Historical performance control remains `deaeb376c1265b0bb3ffe933ac1975f8db5f1048`, whose timestamp predates PR155. Its original six asset hashes were verified directly from that exact commit's blobs; the control was not rebuilt, replaced or requalified here.
- Browser emulation does not establish physical iPhone/Safari compatibility, smoothness or universally faster12-window dispatch. The existing small parcel-route regression remains a disclosed conditional tradeoff.

## Evidence and replay

- `final-web-integration.json`: final14-check report and browser identity
- `compare-states.log`: final native byte comparison of actual browser saves
- `application-source-v3.json`: runtime/export source snapshot
- `revised-build-hashes.json`: final output hashes
- `purchase-375.png`, `owned-twelve-375.png`, `dispatch-explanation-375.png`
- `paused-390.png`, `reloaded-locked-390.png`, `reloaded-warehouse-390.png`
- `second-tab-protected-390.png`, `unknown4-legacy-375.png`, `existing-v5-no-fallback-375.png`, `v5-backup-read-only-375.png`

The evidence directory includes the exact incremental test scripts that produced the final run, plus `verify_dispatch_web.py`, a standalone replay assembled from those verified fragments (Python syntax checked). Run it with the export directory, a new evidence output directory and the synthetic-fixture directory. It requires Python Playwright and Chromium and starts its own localhost server; `FLOTRA_DISPATCH_BROWSER_PORT` can select a free port. `make_fixtures.gd` and `compare_states.gd` record native fixture construction and byte comparison. Earlier exploratory harness failures are retained in raw logs and are not counted as passing tests; the final revision's complete run passed.
