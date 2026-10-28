# Campaign truck body import candidate

Date: 2026-10-24 / scope: FLOTRA title-local / status: stationary-display candidate; not merged

- Original CC0-1.0 hand-built body/cab from PR165, not AI/Meshy output.
- Identical GLB bytes to `godot/assets/models/flotra_delivery_truck_demo.glb`.
- 276 triangles, six opaque material surfaces, no textures, lights, physics or animation.
- `truck_body_asset.gd` returns a visible-geometry Node3D or null and frees invalid instances.
- The campaign now installs a separate stationary display beside the outbound endpoint.
- Four shared low-poly wheels are supplied by `outbound_truck_display.gd`.
- The original GLB remains body/cab only; no legacy placement coordinates are copied.
- TARGET and pre-change campaign CURRENT were actually viewed before placement.
- Actual candidate normal-phone native captures were viewed at `a8e776c`;
  caption occlusion was corrected after the first capture.
- 1,069 route/camera/caption/save assertions pass. Browser qualification and
  physical iPhone/performance gates remain separate and pending.
- Prices, domain, schema5 storage keys, public export and PR161 remain unchanged at this candidate stage.
- `truck_body_import.gd` must run under a disposable XDG profile whose absolute prefix
  is passed as `FLOTRA_REVIEW_USER_ROOT`; it never writes the owner's saves.
