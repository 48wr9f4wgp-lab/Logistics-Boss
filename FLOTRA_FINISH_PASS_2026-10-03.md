# FLOTRA final readability and playability pass

This completes the bounded six-contract campaign presentation and replay scoring. Physical-device testing is deferred until after completion; it is not a blocker for this release.

## Finished presentation

- Warehouse framing uses the actual L-shaped building and gives it more phone-screen space
- Overlapping miniature world text is replaced by three fixed-pixel location captions; editing shows the selected equipment and proposed position
- The live display shows elapsed time and the current gold/silver target
- Contract cards name missing prerequisites and explain the actual required bulk holding time
- An idle or full-floor holding state shows when the next stored pallet becomes eligible for dispatch
- Results clearly distinguish first completion, the six-contract ending and replay, retain the earned medal, and show records to the simulation's centisecond precision

## Correct scoring and preserved saves

Accumulated floating-point noise previously misclassified some finishes exactly on a medal threshold. Scores and live targets now compare the same centisecond precision as the displayed result. The first tick past a deadline still misses that medal.

Existing campaign saves remain schema-compatible. The importer accepts badges awarded by the old precise-boundary calculation, validates the entire state, then corrects only derived medal fields. Shipments, money, upgrades, routes, timings and accepted work are unchanged. Arbitrary forged badges are still rejected. The original main game's saves and assets remain untouched.

## Verification

Independent full-scene playthrough covered every branch, all upgrades, ending, replay, pause/cancel, repeated input, save/reload and exact continuation. Separate engine-input checks cover equipment picking and placement previews at 375×667, 390×844 and 430×932. Native captures show the composed final view, and the compiled web PCK is tested independently of source.

Browser storage behavior was verified on the published isolated QA page in PR145. Its bridge and namespace are unchanged in this pass. The cloud browser lacks WebGL2, so it cannot provide browser-gameplay evidence. No physical iPhone/Safari gameplay or performance claim is made.
