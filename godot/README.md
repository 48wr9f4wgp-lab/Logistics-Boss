# FLOTRA — Godot Vertical Slice

This folder is the migration candidate for the production game. The current Web build under `/docs` remains the reference/rollback baseline until the Godot slice passes the migration gate in `TECH_DECISION_GODOT_MIGRATION_2026-09-15.md`.

## Target

- Godot 4.x
- GDScript
- GL Compatibility renderer for Web/mobile compatibility
- portrait-first mobile UI
- deterministic domain simulation separated from 3D presentation

## Run

Open `godot/project.godot` in Godot and run the project.

The current slice already contains:

- deterministic inbound/order generation;
- autonomous worker store/pick/ship tasks;
- a real packing stage;
- shipment-only revenue;
- policy switching: balanced / inbound / outbound;
- pause / 1x / 2x / 4x;
- worker, rack, worker-speed, and packing investments;
- visible low-poly facility/worker/parcel changes;
- touch orbit + pinch zoom;
- versioned Godot save file with backup fallback.

## Headless smoke

When a Godot executable is available:

```bash
godot --headless --path godot --script tests/sim_smoke.gd
```

The smoke checks real shipment completion, revenue ownership, rack-capacity investment, and policy state.

## Verification status

Code is scaffolded in-repo, but this environment does not currently provide a Godot executable. Do not mark the slice visually complete until it has been opened in Godot, the smoke has run headlessly, and the Web export has been tested on iPhone.
