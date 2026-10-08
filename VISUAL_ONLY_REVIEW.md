# FLOTRA visual-only local candidate — 2026-10-08

## Decision and scope
Prepared and frozen locally; not pushed, merged, released, or qualified by full aggregate/CI/browser performance. Candidate starts from exact PR158 head 6e3829793d771f25a828c0d169db6dcc77e525e3 (201 project blobs independently rechecked unchanged). Public source/control is a6f885e4f70ed3122fc1c776c3c6fa0661ca954a.

The optional close-inspection feature was an assistant-added extension and is explicitly deferred. Its HUD entry, signal, main handlers/telemetry, camera state/branches, and slot-selection override are absent. growth_main.gd and growth_hud.gd are byte-for-byte public source. The only product source difference from public is growth_view.gd: an actually purchased auto_pack machine and animation driven by the actual pack_jobs cargo ID and remaining work. No economy, capacity, route, obstacle, save schema, cargo or ordinary camera setting changes.

## Bounded geometry correction
The retained PR158 machine originally extended beyond the existing 1.6 × 1.0 physical packing footprint into the annex bulk traffic lane. The corrected horizontal scale is (0.64, 1, 0.49); height, color and gantry silhouette are retained. Its complete static bounds are X −0.7936…0.7936, Y 0.08…2.25, Z −0.4802…0.49245. Cargo alignment uses machine.to_local, preserving the actual parcel position. Lower support feet, rear-shifted pillar/inset and narrower side cabinet/screen preserve an open cargo bay. No simulation obstacle or route changes were made.

A real route_bulk run in annex packing placement exercised 11,805 worker-position samples. Conservative worker/cart envelopes overlapped the original plinth 3,105 times and the corrected machine envelope zero times. These are sampled overlaps, not 3,105 distinct collisions. One real six-cargo loaded worker had matching authoritative and rendered-node positions (3.6, 0, −6.1). These are native headless transform/geometry observations, not actual pixels.

## Focused evidence
- Final visual_growth_only: 356 checks, zero failures. Covers absence of inspection, real 240-cost purchase, ordinary view/camera reset, idle/active footprint, actual cargo alignment, every remaining tick of one actual packing cycle against all machine solids, pause, byte-exact active save/resume, real traffic and unowned reload.
- The same 356 checks pass when executed from the final exported index.pck, with an empty source directory. This verifies packed behavior under native Godot, not WebGL/browser execution.
- growth_view_smoke: 388,233 checks, zero failures; rerun after final geometry change. Geometry/cache/batch parity only; no GPU readback.
- visual_material_roles: 8,436 checks, zero failures; rerun after final geometry change.
- camera_interaction_review: 5,175 checks, zero failures; native root-input dispatch. Run before the final support-only geometry adjustment; camera/input source remained identical.
- growth_controls_comfort: PASS; same boundary as camera check.
- Export loader-contract tests: 9/9 pass. Script/shell syntax checks passed.
- 65 runtime hashes and exact 199-file project manifest recorded. Complete source manifest verification passed. Public main/HUD and normal browser harness Git blob hashes match exactly.

Early test-authoring parse/stale-node-reference failures and superseded intermediate results are retained under evidence/focused. The corrected assertions inspect the current slot after legitimate layout reconstruction; no product failure was suppressed. No full aggregate was run.

## Gate integrity and historical failure
PR158 remains failed: 11/12 CI jobs passed; normal A1/B1/B2/A2 passed, but optional inspection B1/B2 frame medians 483.3/483.4 ms exceeded 437.5 ms. Original summary, terminal jobs, combined evidence ZIP, and removed feature tests are retained under evidence/pr158-inspection-history. They are not relabeled as passing.

The ordinary browser journey and A-B-B-A wrapper are restored exactly to public versions, retaining every existing normal assertion, duration, threshold and comparison rule. test.sh replaces only inspection_relocation_guard with explicit visual_growth_only absence/normal-flow coverage; all other suites remain. Future CI points to FLOTRA_VISUAL_ONLY_ARTIFACTS_2026-10-08.json and no longer requests a gate for a removed entry. This is an explicit feature-scope change, not a threshold relaxation or a claim that inspection passed. Future exact-head checks still must run.

## Remaining uncertainty
No fresh screenshots were captured: installed Xorg could not establish display sockets. The local Chromium socket blocker was not retried; no user-computer setup or browser fallback was attempted. Smaller footprint visibility and final appearance need actual-pixel review. Existing historical screenshots must not be represented as this corrected candidate.

Static review noted a possible upper-tier queued/packed carton overlapping the solid sealing head. It existed in PR158 before this correction and has not been reproduced in a reachable gameplay state. It is an unverified inherited limitation, not a new proven blocker; no speculative redesign was made.

Next step: fresh normal-view purchase/actual-work visual proof and exact-candidate CI with unchanged normal gates. Full aggregate, pinned historical/adversarial checks, formal browser A-B-B-A, and physical-device verification have not run for this candidate.

## Artifacts
- source-vs-pr158.patch: text overlay against exact PR158 (binary export is separate)
- runtime-vs-public.patch: the single product source delta against public main
- FLOTRA_VISUAL_ONLY_ARTIFACTS_2026-10-08.json: exact source/runtime/export/workflow hashes and scope
- docs/godot-jobs-preview/: final Web export
- evidence/focused/: original logs, final logs, static manifest verification and native-display blocker
- evidence/superseded-before-cargo-clearance/: earlier export marked SUPERSEDED

The local folder is a reconstructed project plus candidate overlay/supporting evidence, not a complete repository checkout. Apply only the recorded changes to a verified exact-head checkout; do not infer removal of unrelated root files absent from this folder.
