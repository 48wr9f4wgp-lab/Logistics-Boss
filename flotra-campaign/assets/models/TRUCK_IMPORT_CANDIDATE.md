# Campaign truck body import candidate

Date: 2026-10-24 / scope: FLOTRA title-local / status: import-only candidate

- Original CC0-1.0 hand-built body/cab from PR165, not AI/Meshy output.
- Identical GLB bytes to `godot/assets/models/flotra_delivery_truck_demo.glb`.
- 276 triangles, six opaque material surfaces, no textures, lights, physics or animation.
- `truck_body_asset.gd` returns a visible-geometry Node3D or null and frees invalid instances.
- The campaign does not call this loader during normal play. Import is not visible integration.
- No wheels are present. Do not call it a finished vehicle or copy legacy placement coordinates.
- Runtime placement needs the actual TARGET image, campaign current captures, cargo/route
  clearance, wheels, camera coverage and phone/performance checks before adoption.
- Prices, domain, schema5 storage keys, public export and PR161 remain unchanged.
- `truck_body_import.gd` must run under a disposable XDG profile whose absolute prefix
  is passed as `FLOTRA_REVIEW_USER_ROOT`; it never writes the owner's saves.
