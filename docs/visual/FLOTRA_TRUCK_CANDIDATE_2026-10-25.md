# Stationary outbound truck candidate

Date: 2026-10-25 JST / scope: campaign presentation / status: Draft, not deployed

Actual TARGET and campaign CURRENT were viewed before changing placement.
The truck uses the original CC0 GLB, four shared low-poly wheels and an apron
beside the authoritative outbound endpoint. No simulated vehicle or new
shipping/economy/save behavior is introduced. A missing body leaves the
existing outbound pad available.

- Before: run 40030535576, artifact 12535337574.
- Revised native candidate: `a8e776cde49d16cb58e761495afa9a59315f230f`,
  run 40146000560, artifact 12580172617.
- Exact candidate Web export: same commit/run, artifact 12580162620.
- 1,069 targeted assertions: route clearance, four wheels, three phone sizes,
  four camera turns, caption separation and complete save byte equality.
- Viewed 390×844 and 375×567 normal-camera PNGs. Initial caption occlusion was
  corrected; the revised screenshots show the label clear of the vehicle.
- `flotra_outbound_before_2026-10-25.png` and
  `flotra_outbound_candidate_2026-10-25.png` show the actual native scenes.

Native screenshots do not establish WebGL performance or physical iPhone
behavior. Existing renderer thresholds, ABBA order and genuine BFCache
restoration requirements remain enforced. The historical frozen manifest and
failed runs are retained. `FLOTRA_TRUCK_ARTIFACTS_2026-10-25.json` records this
prospective source/export pair; qualification on the final PR head is pending.
PR161 remains separate and unmerged. The public development URL has not changed.
