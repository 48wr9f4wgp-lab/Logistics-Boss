# FLOTRA compact phone preparation

## Improvement

The previous preparation sheet placed three full explanation cards far below the opening summary. On a short phone this meant scrolling down to choose an operating mode, then back to the start action. Preparation now shows all three full-size choices first; selected mode has a visible ● marker. Conditions, detailed tradeoffs, cargo breakdown and layout adjustment expand from one disclosure. The start button is pinned outside the scroll area and remains reachable while reading or after layout editing.

Body text remains at least 18 CSS pixels and actions at least 56 pixels high. The existing full operation cards in the warehouse upgrades tab are preserved. Short landscape retains scroll access and the pinned action rather than compressing text or touch targets.

## Preservation

This is a presentation-only change in `growth_hud.gd`. Economy, cargo simulation, six milestones, equipment, operation semantics, save schema 3 and its migrations are unchanged. Choosing a mode remains an immediate free change; opening details remains read-only; confirmed layout applies and canceled layout does not. PR151's Web cancellation bridge, camera controls, pause and comfort preferences are unchanged. The two legacy game directories are untouched.

The footer uses the same guarded button factory. Its node lives outside the rebuilding scroll content; availability updates from the same authoritative preparation plan. A details toggle increments the input epoch so geometry changes cannot complete an older held action.

## Verification

- Official Godot 4.7.2: preparation 814 checks, old-save migration 173 checks; focused canceled-touch, camera and phone geometry suites passed
- Initial-fold assertions require all three full mode targets inside the 375×567 scroll viewport before any scrolling
- Pinned footer geometry is checked through details expansion, scrolling, resizing, mode changes and layout return
- The actual pinned Start is canceled through the Web cancellation ordering, then a fresh touch must accept exactly once
- Expanded/collapsed details must leave gameplay state unchanged
- Browser preparation adds explicit above-fold, pinned-action and actual CDP `touchCancel` assertions; the full existing quickstart/fresh/mature replay journeys are retained

Final exact-head CI and publication verification are recorded in the pull request. Chromium CSS emulation is distinct from physical iPhone/Safari validation.

## Reproduce

Use the existing `flotra-campaign/test.sh`, `export_web.sh` and `tests/release/browser_preparation_journey.cjs` commands in the prior preparation release guide. Browser selection via `FLOTRA_PREPARATION_CASES` can run `quickstart-375x567,fresh-375x567,mature-375x567`; CI retains both viewport jobs and all ten existing regression jobs. Export retains `persistentPaths: []` and `canvasResizePolicy: 0`.
