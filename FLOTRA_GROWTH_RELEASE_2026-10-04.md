# FLOTRA: quick, forgiving warehouse growth

## Player-facing change

New warehouses start with six short growth steps, rather than the previous long finite campaign. Deliveries never fail on a timer. Standard speed is 2×, with 1× and 4× available. Every growth job pays again, so spending all available funds never blocks the next job. Layout changes remain free. Four connected warehouse wings, staff, courier robots, larger shelving and automatic packing turn the starter warehouse into a working logistics center.

The first 12-unit delivery pays 140. Combined with the starting 100, that buys the first physical wing (150) and a fourth worker (90). The first delivery takes 32.25–47.85 simulation seconds across the four layouts, or about 16–24 seconds at the standard speed, before navigation. All six milestones remain completable with the starting three workers and no upgrades.

Growth is physical: four northward strips add 32 pallet bays, for 38 total with the default shelf location; new receiving/dispatch side aisles connect to the transport graph. Floor area is computed from the union of the rendered hall, annex, wing and connector rectangles (about 224㎡ initially and 573㎡ with four wings). Robot workers reserve real routes and carry real cargo, with faster travel and handling; automatic packing changes the processing duration. No output multiplier or disappearing cargo substitutes for these effects.

## Pacing and causality

Independent same-demand measurements:

- Parcel route: no robots 86.15s → two robots 64.65s → four robots 58.50s
- Large storage route: three wings 297.75s → four wings 279.05s
- The fourth-wing case actually uses all 38 bays, including every new wing, compared with a 30-bay peak before that purchase
- Starter crews complete all six milestones in 619.05–765.20 simulation seconds across all layouts; no mandatory purchase or optimal layout is required
- The optional 288-unit large route requires six milestones, three wings and two robots. Smaller paid jobs remain available to fund those improvements. Its minimum eligible setup finishes in 404.8–431.4s; the complete warehouse finishes in 276.4–287.75s

The release has a bounded destination: a four-wing automated logistics center. After reaching it, paid parcel/storage work and the large dispatch remain playable, with optional best-time records. Each round retains at most 288 physical units. Completed rounds are replaced only after all cargo ships; lifetime counts and per-job records are aggregated, so active entity/history storage does not grow with the number of rounds.

## Save continuity

The web storage bridge is unchanged. The existing localStorage keys, backup, exclusive writer lock and `persistentPaths: []` remain. The original `/godot-preview/` and its IndexedDB data are untouched.

Payload schema 2 adds an explicit legacy operating-profile flag. A schema-1 save is first validated by the original release model. Its wallet, purchases, results, last outcome and complete in-flight simulation fields are copied without resetting cargo, clocks, reservations, movement or pending relocation. An old in-flight job continues with its original contract parameters, walking speed and equipment rules; the new profile is applied when a new growth job is accepted. Existing records remain inspectable in Results.

The first migrated write keeps the previous validated schema-1 text as its backup. Unknown, corrupt, foreign, future-version or conflicting saves still block overwrite. The older application does not understand schema 2 and must not be used to downgrade saved progress.

Two narrowly scoped validator defects were covered: floating arrival clocks at exact tick boundaries may differ by up to 1e-6 without being corrupted; bulk release clocks must equal the recorded storage time plus the contract's holding duration. No migration normalization or broad permissive fallback was added.

## Phone and performance preservation

The CSS-pixel viewport bridge, full-DPR backing buffer, 18px minimum text, 56px controls, full-height sheets and pinned layout action remain. The next job is placed before the locked roadmap. Successful expansion reveals the new floor immediately. Passive cards and scroll-content buttons pass drag events to the scroll container, while the inherited held-touch, stale-press, focus-loss and dismissal guards remain active.

Presentation snapshots are shared read-only across the HUD and renderer within each mutation cycle. Static graph coordinates are cached by expansion revision; floor and route meshes rebuild only when topology changes. Robot meshes and material counts are bounded. Repeated box geometry is submitted through two colored MultiMeshes while retaining the original named nodes as transform/visibility sources. Rounded human geometry is reduced from 7,680 to 208 triangles per person without changing its bounds. The original lighting and shadows are retained. Reloaded and live-expanded warehouse geometry must match.

Full-height reading sheets stop hidden 3D drawing while the simulation and autosave rules continue unchanged. The warehouse returns immediately when the sheet closes. This does not change the canvas backing resolution, CSS layout, font sizes or touch geometry.

Measured software-renderer limits are explicit: a HUD-only diagnostic already takes about 117ms/frame on this cloud SwiftShader renderer, and the original phone release measures about 267ms/frame. It is not evidence of physical phone FPS. Final tests bound draw calls, CPU cost, stable paused node counts, and added 3D frame cost against a same-run covered-menu baseline. Native measured mature draw calls fall from 1,146 to 66; batching alone was not treated as a proven FPS improvement. The exported browser tests retain absolute frame-time measurements in their artifacts.

## Reproduce

Use official Godot 4.7.2:

- `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/test.sh`
- `GODOT=/path/to/Godot_v4.7.2 bash flotra-campaign/export_web.sh`
- Serve the exported directory, then run `node flotra-campaign/tests/release/browser_growth_geometry.cjs URL OUTPUT_DIR`
- Generate isolated fixtures with `FLOTRA_GROWTH_FIXTURES=/absolute/output godot --headless --path flotra-campaign --script res://tests/release/growth_browser_fixtures.gd`
- Run `node flotra-campaign/tests/release/browser_growth_journey.cjs URL OUTPUT_DIR FIXTURE_DIR`

The browser suite requires Playwright 1.62.1 and Chromium. It operates on fresh browser profiles and validated, domain-earned test fixtures, never the user's live saved warehouse. Chromium phone emulation and native llvmpipe rendering do not establish physical iPhone/Safari performance.
