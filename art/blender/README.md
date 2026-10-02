# FLOTRA packing workbench: Blender → Godot

Original low-poly static packing workbench, authored with Blender 4.3.2 and integrated into the base packing zone. It replaces the old three BoxMesh table/monitor/screen objects without adding a gameplay station. The existing conveyor, gantry, real packing jobs, waiting parcels, status lamps and interaction anchor remain unchanged.

## Files

- `packing_workbench.blend`: editable Blender source (one joined mesh with disconnected editable components)
- `build_packing_workbench.py`: reproducible procedural source, including named components before join
- `packing_workbench.spec.json`: generated asset budget/coordinate contract
- `../../godot/assets/models/packing_workbench.glb`: runtime asset
- The GLB's `.import` file and `packing_workbench_import.gd` configure deterministic Godot import; keep both

The `.blend` stays outside `godot/` so playing/exporting the game does not require Blender or an editor-side `.blend` import dependency. Only the 25 KB GLB ships as the runtime geometry.

## Art/geometry contract

- 304 triangles, 624 exported vertices, one mesh and one opaque material surface
- Vertex colors: navy, brushed steel, safety amber, restrained cyan; no textures
- No lights, animation, collider, cargo, gameplay script or dynamic status colors
- Meter scale, Godot Y-up / +Z work-facing side, origin at floor-center
- Width 2.35 m; worktop surface 1.032 m, below the existing real carton bottom at 1.04 m
- HMI glass faces the working side; no emissive or fake live data display
- Left supports and the lower shelf leave the full 12-parcel packing-backlog footprint clear
- Backface culling enabled
- No manual/automatic LOD for this single small instance. Complexity is far below the surrounding scene; revisit only if physical-device profiling justifies it

The imported material explicitly enables linear vertex-color albedo in a post-import script. Godot 4.7.2 retained COLOR_0 but defaulted its material flag off, making an uncorrected asset white. This is handled once during import, not every frame.

## Rebuild

From the repository root:

```bash
blender --background --factory-startup --python art/blender/build_packing_workbench.py
godot --headless --path godot --editor --quit
GODOT_BIN=godot bash godot/tools/run_polish_checks.sh blender_workbench_smoke packing_presentation_smoke
```

Use Godot **4.7.2** for parity with the project CI. Export is standard uncompressed glTF 2.0; no Draco or paid addon is used. This Blender installation prints an optional Draco-library warning at exporter initialization, but the resulting GLB has no compression extension and passes import/geometry validation.

A manual Blender edit can be exported to the same runtime GLB using only the workbench object, Y-up, normals, vertex colors and materials. Keep a single shared material and the triangle/clearance budget. Run the checks after editing.

## Verification

`blender_workbench_smoke.gd` checks resource sharing, material/mesh budget, orientation, flags, production-scene placement, removal of old primitives, every triangle's bounds against all capped backlog cartons/tapes with 5 mm tolerance, and save/schema immutability. It is part of the existing CI regression step.

For actual rendering (requires a graphical desktop):

```bash
GODOT_BIN=godot bash godot/tools/capture_blender_workbench.sh
```

This fixture instantiates the real main scene, uses isolated saves and controlled empty/busy states, captures 375/390/430-wide portrait frames plus an explicitly separate close inspection view, and measures 180 frames after 60 warmup frames. Domain simulation is paused; those frame timings do not measure sustained gameplay or phone performance. Baseline/final comparisons and final test results are in `FLOTRA_BLENDER_INTEGRATION_2026-10-02.md` and the delivery evidence.

## Provenance / license

All geometry, vertex colors and build code in this asset were created specifically for FLOTRA. No external models, textures, fonts or third-party asset packs were used in this new asset. The asset/source may be used, modified and redistributed under **CC0-1.0**: https://creativecommons.org/publicdomain/zero/1.0/

Blender itself is GPL software; using it to create this original asset does not make the exported model GPL. Existing FLOTRA code and the existing project font retain their own terms.
