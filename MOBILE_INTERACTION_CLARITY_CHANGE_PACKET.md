# FLOTRA: mobile interaction clarity repair

Scope: title-local / VERTICAL_SLICE / 2026-09-20
Base: main f39c3304426d06ae09b49d06865f7a7c00c72e9b
Status: IMPLEMENTING; human acceptance NOT PASSED
Production decision: UNDECIDED. Release approval: NOT_REQUESTED.

## Evidence and goal
The post-PR124 human iPhone Web retest FAILS. The user cannot distinguish buttons from information, cannot tell whether a tap registered, and cannot find equipment purchasing. The supplied third screenshot also contains missing Japanese glyphs. This supersedes the previous retest-pending assumption, not the existing automated regression results.

The observed saved state has Rank1 projects 4/4, rating 0/8 and sufficient expansion money. Installed equipment is being mistaken for another purchase action. The contract route is visually buried. Static HUD font traversal also misses controls attached later by main (including the session-resume surface).

Goal: make the current state, available action, and authoritative result legible. Fix input/text/navigation before judging fun or adding content.

## Implementation boundary
- Add one explicitly bound presentation component for the existing mobile HUD and Zone Panel, not another HUD inheritance layer.
- Add one raw UI gesture owner in the composed scene; disable the two legacy raw routers there. Preserve standalone legacy component tests. New integration tests MUST exercise the composed path.
- Add project-wide bundled Japanese font defaults, including dynamically attached controls.
- Make contract descriptions noninteractive labels with separate explicit start buttons; show active contract progress on the warehouse.
- Add persistent Management sections (contracts / field / expansion) instead of hiding navigation beneath the contract list.
- Installed Rank1 equipment becomes readable status, not a disabled purchase button. Keep Zone-first purchasing and preview -> commit.
- Keep the Director symptom-only. Do not prescribe which equipment solves a bottleneck.

## Non-goals
No economy/contract-condition changes, no new equipment, no Rank3 redesign, no save/schema change, no artificial resources or fake success, no account/analytics SDK, no production release or new deployment destination.

## Acceptance
1. All late-added Japanese labels resolve to the bundled font.
2. ScreenTouch press has a visible state; release triggers one action; synthetic mouse does not trigger a second action.
3. Cancel, movement past the scroll threshold, clipped controls and overlay-covered controls cannot activate a purchase.
4. Contract acceptance visibly enters an authoritative active state and returns to warehouse observation.
5. At projects 4/4 and rating 0, the main CTA leads directly to contracts, and installed equipment is not offered for purchase again.
6. At expansion readiness, the CTA opens expansion confirmation rather than spending immediately.
7. Equipment preview remains no-spend; the separate commit gesture changes Domain ownership and physical-preview signals.
8. Existing Godot / save / progression / iOS-export / visual regressions remain required.

## Files / validation / recovery
Files: godot/main.gd; godot/project.godot; new shared theme, mobile presentation, input router, integrated smoke/capture; dedicated CI job.
Run import, integrated touch/navigation/installed-state tests, existing CI, software-rendered 390x844 captures. Native iPhone and human comprehension remain unverified until tested.
Work is isolated on fix/mobile-interaction-clarity. No local user data is reset. Rollback is the base commit; persistent data format is unchanged. Main and the existing playable preview are not changed by creating this branch.
