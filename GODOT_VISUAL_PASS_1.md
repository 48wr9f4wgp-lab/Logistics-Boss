# LOGISTICS BOSS — Godot Visual Pass 1

Status: Active implementation spec
Visual North Star: `VISUAL_NORTH_STAR_GODOT.md`

## Objective

Move the Godot vertical slice from functional grey-box presentation toward the adopted final-vision screenshot without changing the core simulation.

## Pass 1 scope

1. **Readable mobile UI**
   - Preserve the four primary metrics: funds, research RP, ship rate, orders.
   - Keep Bottleneck Director visible without covering the warehouse.
   - Keep the bottom control dock compact and thumb reachable.
   - Web preview must never show broken CJK glyphs. Web may use English fallback copy; native iOS keeps Japanese copy.

2. **Camera composition**
   - Warehouse remains the visual hero.
   - Default camera is a tighter high-angle management-sim view with reduced perspective distortion.
   - One-finger orbit and pinch zoom remain available.

3. **Warehouse layout**
   - Clearly readable zones: inbound, storage, pack, outbound.
   - Racks gain multiple aisles / visible upgrade growth.
   - Add visual-only forklift, AGV, truck dock and conveyors to establish the final facility fantasy.
   - Simulation-owned workers and parcel counts remain the source of moving logistics activity.

4. **Lighting / palette**
   - Dark navy warehouse shell.
   - Cool blue ambient/rim lighting.
   - Warm work lights over operational zones.
   - Orange rack beams and yellow safety markings.
   - Cyan/mint signage accents.

## Non-goals

- No economy rebalance.
- No new upgrade type.
- No new rank/progression system.
- No replacement of simulation event ownership.
- No claim that the North Star image has been fully reached.

## Acceptance gates

- Godot 4.7.2 project import passes.
- Domain simulation smoke passes.
- Full `main.tscn` runtime smoke passes with no script/runtime error.
- Web export passes.
- Existing legacy/static QA and capital pacing stay green.
- iPhone preview shows readable labels, no broken glyphs, and a materially denser/clearer warehouse composition.
