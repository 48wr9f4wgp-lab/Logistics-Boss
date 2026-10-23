# FLOTRA 3D asset export pilot (2026-10-23)

Status: **separate Draft trial only**. Do not merge to main, alter the existing
PR161 automation trial, publish Web, or call it iPhone-qualified before checks.

## What's real
- `godot/assets/models/flotra_delivery_truck_demo.glb`: **original hand-built** (not Meshy-generated) static truck body/cab visualization.
- glTF 2.0 binary (GLB), six opaque materials, 276 triangles, no texture images,
  collision, lights, skeleton, animation, or game-state authority.
- One visual-only model at the existing outbound dock (Godot node name
  `DeliveryTruckVisual`; anchor `(6,0,4.25)`).
- Old `TruckBody` and `TruckCab` primitives stay in scene as fallback, hidden only
  when this model instantiates successfully. Existing wheel/stripe/marker visuals,
  cargo counts, jobs, economy, UI, touch and save schema stay unchanged.
- Automated smoke `ai_truck_asset_smoke.gd` checks import, material/triangle
  budget, position, old-shell visibility, and save isolation.

## Using an actual Meshy free-plan model next
1. In Meshy web, choose **Meshy 6 Lite** before generating and export **GLB**.
   Free downloads are limited to ten per month for Lite; other model versions
   may present a paywall. API calls are not free.
2. Use an original/reference image that you have permission to use. For a
   replacement, produce a small *parked delivery-truck body/cab shell only*.
   Keep its wheels excluded while existing VisualPass2 owns them, or revise
   both layers together in a separate reviewed change.
3. Align a Godot-friendly **Y-up, meter-based** model with the existing model:
   local origin `(6,0,4.25)` external dock anchor, cab faces **-X**; model
   local bounds roughly X -2.08..1.35, Y 0.03..1.83, Z -0.81..0.81.
   Confirm scale/axis in Godot; most AI exports need preparation.
4. Replace the GLB on this **trial branch**, then run Godot 4.7.2 import,
   targeted smoke, full existing regressions and real iPhone GPU/touch test.
   Relax exact geometry assertions only after documenting the new measured
   budget; never bypass functional gates.
5. **License:** this original demo is CC0-1.0. If replacing with a Meshy Free
   model, free outputs are CC BY 4.0 and require visible attribution to Meshy
   in the game/project page, including modifications. Verify uploaded
   references and any third-party intellectual-property restrictions.
   Source: https://help.meshy.ai/ja/articles/15696428-what-is-included-on-the-free-plan

## Safety/quality boundaries
This visual prototype does not add operational machinery, vehicle motion,
additional deliveries, earned funds, analytics or monetization. It leaves
PR161, Pages, deployment aliases, and the public save origin untouched.
A CI-green run only establishes desktop/engine behavior, not whether the
image is readable or the framerate acceptable on a physical iPhone.

## Fallback validation follow-up (2026-10-23)

The installer now rejects empty scenes, non-3D roots, mesh-less scenes and hidden
geometry before hiding either legacy shell; rejected instances are freed.
`ai_truck_asset_smoke` exercises seven missing/invalid/hidden cases, accepts a
visible mesh at the root, and runs a malformed PackedScene in an isolated child.
The child must exit successfully with the two exact expected ResourceLoader
errors and no script errors/leaks. The ordinary CI error gate is unchanged.
This probes runtime resource failure, not corruption of the GLB import pipeline.

Local Godot 4.7.2 checks passed for the asset/fallback, workbench, save preservation
and review, mobile input, world/window input, packing, presentation cache, routes,
warehouse/HUD cohesion, player journey, zone feedback, save status, simulation,
growth-first/UI and capacity growth. `staffing_return_journey_smoke` produced
save-byte assertions locally on both unchanged PR165 `64816a8` and the candidate;
this remains an unresolved environment/baseline discrepancy pending fresh CI.
Do not report all local regressions green or bypass this gate.

The repository PNG `docs/visual/logistics_boss_visual_north_star_2026-09-16.png`
has a readable PNG header but fails full Pillow decoding (broken data stream).
No target-image acceptance or art redesign is claimed. Physical iPhone validation,
fixed-condition rendered A/B comparison and visual acceptance remain pending.
