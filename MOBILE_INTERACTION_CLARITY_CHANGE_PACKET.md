# FLOTRA: mobile interaction clarity repair

Scope: title-local / VERTICAL_SLICE / 2026-09-20
Base main: f39c3304426d06ae09b49d06865f7a7c00c72e9b
Implementation: PR #126 / fix/mobile-interaction-clarity
Status: AUTOMATED_VALIDATION_PASS / HUMAN_IPHONE_RETEST_PENDING
Production decision: UNDECIDED. Release approval: NOT_REQUESTED.

## Human evidence and goal
The post-PR124 human iPhone Web retest FAILED in this chat. The user could not distinguish buttons from information, could not tell whether a tap registered, and could not find equipment purchasing. The third supplied screenshot contains missing Japanese glyphs. This supersedes the previous retest-pending assumption, not the prior automated regression results.

The observed saved state has Rank1 projects 4/4, rating 0/8 and sufficient expansion money. Installed equipment was mistaken for another purchase action. Contract navigation was visually buried. The late-created session-resume Label matched the missing-glyph surface and had no explicit Japanese font; HUD._ready's earlier traversal could not cover it.

Goal: make the current state, available action and authoritative result legible. This is the UI foundation repair, not proof that the game is enjoyable.

## Implemented boundary
- One explicitly composed presentation component; no additional HUD inheritance layer.
- One composed raw gesture owner. The two legacy routers are disabled only there; standalone legacy regression fixtures remain unchanged.
- Shared bundled Japanese theme on Control roots beneath the CanvasLayer, including future direct Control children. Existing font overrides remain covered.
- Contract descriptions are noninteractive labels. Separate explicit start buttons accept through existing Domain handlers and return to warehouse observation with live progress.
- Persistent Management sections: contracts / field / expansion / settings. Field navigation is no longer beneath the contract list.
- Installed Rank1 equipment and hired staff become readable status, not disabled purchase buttons. Zone-first equipment preview -> explicit commitment remains unchanged.
- The primary action routes to contracts, unfinished equipment or expansion according to authoritative readiness. Expansion navigation does not spend money.
- The Director remains symptom-only. No equipment answer is prescribed.

## Non-goals / preserved scope
No economy or contract-condition changes, no new equipment, no Rank3 redesign, no save/schema change, no account/analytics SDK, no production release. Test/capture resource injection is restricted to explicit diagnostic fixtures and is NOT natural-progression evidence. Existing natural-progression regressions remain separate.

## Implementation findings corrected before verification
1. A project.godot custom theme attempted to load the TTF before a clean editor import. That setting was reverted. The theme is now bound at runtime after import.
2. MobileGameHud is a CanvasLayer, not a Control. Theme inheritance is attached to its Control roots, not an invalid CanvasLayer.theme property.
3. The compact contract cards did not necessarily scroll the first button offscreen. The clipping test now creates fixture-only overflow and asserts that the point is inside the viewport but outside the scroll clip before testing rejection.

## Verified code baseline
Commit: cea981657140c84a0a27db8cdb475ee3ecece2d6
Engine/config: existing Godot 4.7.2 Standard / GL Compatibility / 390x844 portrait.

- FLOTRA Mobile Interaction Clarity #6: SUCCESS; run 35515354686.
- FLOTRA Godot CI #302: SUCCESS; run 35515354738.
- FLOTRA iOS Export Smoke #113: SUCCESS; run 35515354641. Export evidence only, not a native-device run.
- FLOTRA Rendered Visual Capture #100: SUCCESS; run 35515354667.
- FLOTRA Android Export Smoke #114: SUCCESS; run 35515354665. Historical technical reference only, not an active production target.

Integrated smoke uses real ScreenTouch/ScreenDrag/Mouse events in the composed HUD/Zone/presenter/router setup. Result: failures=0.
Verified cases:
- visible held-press state and one activation after touch + synthetic mouse;
- synthetic mouse cannot accept during a touch held longer than 450ms;
- cancel, multitouch, 12px button-origin scroll and changed contract identity do not activate;
- clipped button rejection, with the test point still inside the viewport;
- late-added resume Label resolves to the bundled Japanese font;
- resume and primary action do not overlap;
- contract / field section touch navigation and actual Zone opening;
- projects4/4 rating0 routes to contracts and shows installed status;
- actual contract acceptance returns to warehouse with persistent progress;
- expansion-ready navigation does not spend money;
- Rank1 equipment preview is no-spend, then explicit construction changes ownership;
- both Rank2 STORAGE/PACKING choices support preview, build and renovation through the composed router;
- Rank2 staffing touch moves one Worker.

## Visual evidence
Artifact: flotra-mobile-clarity-evidence / 10607285012 / run 35515354686.
Artifact SHA256: 7c73239b341d152bbe827b44c71913ebf6bea365cc9c0bc4efc46e5b037bc61a.
The actual main scene, not an isolated HUD, produced these 390x844 images:
- clarity_fresh.png
- clarity_completed_equipment.png
- clarity_contracts.png
- clarity_field.png
- clarity_installed_storage.png

All five were downloaded and opened in this chat. CURRENT verified_access=YES for these captures only. The resume Japanese is readable; contract start buttons and persistent tabs are visible; installed storage/staff appear as status; observed primary surfaces do not overlap. These are software-rendered diagnostic snapshots, not iPhone Safari, human comprehension, performance, or TARGET-art-quality acceptance.

## Working state / recovery
Main remains f39c3304426d06ae09b49d06865f7a7c00c72e9b.
Working branch contains verified code cea9816 plus this documentation-only evidence update.
PR #126 is not merged at the time of this record.
No user save was reset. No save migration is needed. No main force-push or overwrite occurred.
The existing public engineering preview has NOT been updated and still represents the older baseline. No App Store/TestFlight/signing/release operation was performed.
For branch review, this packet is the current change evidence; main DEV_STATUS/HANDOFF still describe the previous published baseline and must be synchronized when integration/publishing occurs.

## NEXT
Obtain explicit approval to integrate PR #126 and replace the existing engineering preview at the same destination. Before integration, recheck main and PR state for conflicts; retain the verified code baseline and existing saves. Do not create a new public destination.
After the corrected preview is available, verify the short iPhone UI path without an instruction checklist. Only after the foundation passes should the Core Purpose / visible-growth / enjoyment human retest resume. Native physical-iPhone testing remains separately deferred pending Mac/Xcode.
