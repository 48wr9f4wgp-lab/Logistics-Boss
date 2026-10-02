# FLOTRA: clear first-play decisions and investment feedback

Base: `b79e718524976815e1bd5a1682cbf332b31b0753` (published PR140)

Status: local review candidate. No branch push, pull request, merge, or deployment has been made for this batch.

## Changes

- The start guide advances after the real Zone Panel opens, whether reached through the warehouse, primary goal, or management/project navigation
- Guidance uses the current Japanese warehouse labels and distinguishes equipment preview from direct hiring
- Failed hiring, construction, renovation, and staffing actions keep a readable message across refreshes. Short notices use a pinned footer and real reading time; long preview details remain in the scrolling content; close, zone changes, retry, success, and preview transitions clear or refresh it appropriately
- Every existing investment event now starts observation feedback. The countdown uses authoritative simulation time, pauses with the warehouse, and ends only on the Domain's matching result event
- Repeated investments of the same kind are tracked independently. Overlapping results retain their existing attribution caveat; another purchase does not replace an unread completed result
- Measurement banners grow upward, keeping the speed/management dock and camera/route buttons clear at 375, 390, and 430px widths

No Domain, economy, save-schema, balance, warehouse geometry/material, or asset changes.

## Verification

Godot `4.7.2.stable.official.ed1daf0bf` (official download), isolated XDG test profiles throughout.

- 68 existing unique checks pass on the published baseline
- The initial composed-main journey test reproduces 69 failing assertions on that baseline, despite those 68 tests passing
- Final candidate: 70 unique checks, including the new composed-main journey and action-feedback regressions. Exact final result and source hashes are in the accompanying evidence
- Journey coverage includes real engine-parsed touch input, preview/commit routes, pause and 4x simulation time, repeated same-kind investments, hidden and unread results, clearance, and notification lifecycle
- Action failures are checked against complete authoritative save snapshots to ensure no money, ownership, workers, or measurements are changed by rejection
- Native engine captures cover guide, inspection, failure, preview, measurement, and result at 375×667, 390×844, and 430×932
- Parse/import, full-scene startup, release Web export, and clean-patch application are independently gated in the evidence

Final pixel QA found that increasing all footer copy to 12px could clip a confirmation button. The fixed version enlarges and pins short active notices only; long preview detail stays inside the scrolling content so the full build button remains visible. The original failure is retained, and the final journey checks confirmation-center reachability through the actual production input router.

## Local rendering observations

Three interleaved before/after runs of 180 frames each, paused investment state, native Linux llvmpipe software renderer:

- Median of run p50 frame times: 31.228ms before, 30.895ms after
- Median of run p95 frame times: 48.043ms before, 45.115ms after
- 796 → 806 draw calls; 50,804 → 51,210 primitives while the new status banner is visible

This is a small local diagnostic with scheduling noise, not a statistically conclusive performance or device claim. Existing approved warehouse art is unchanged.

## Remaining limits

- No iPhone/iPad/Safari or Android hardware QA
- No WebGL2 gameplay claim from the cloud browser; native engine pixels and release export are the verified routes
- Android/iOS native CI and remote checks have not run for this unpublished candidate
- Results and pending observations are presentation state. Existing save persistence rules remain unchanged

## Publication effects to approve together

Publishing would create a new branch and draft PR for this patch, run applicable branch/PR CI, then require the authorized review/merge workflow. Merging changes under `godot/**` to `main` triggers the existing Godot preview workflow, updates `docs/godot-preview`, and publishes the Pages preview. Existing Android/iOS export-smoke workflows may also run on the PR/main changes. No new workflow, analytics recipient, permission, credential, or external service is introduced.

## Reproduce

`GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash godot/tools/run_polish_checks.sh player_journey_smoke zone_action_feedback_smoke`

`GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 bash godot/tools/capture_playflow.sh /absolute/output`

Capture requires a graphical display and uses disposable profiles. Test fixtures seed money/rank where stated; they are not evidence of natural earnings or progression pacing.
