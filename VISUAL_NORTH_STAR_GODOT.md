# LOGISTICS BOSS — Godot Visual North Star

Status: **CANONICAL / APPROVED**
Approved: 2026-09-15
Applies to: Godot production direction

## Canonical visual target

The user-approved final-vision image generated on 2026-09-15 is the visual North Star for the Godot version of LOGISTICS BOSS.

This is not a loose mood-board reference. When visual decisions conflict, prefer the direction described here unless a later title-specific Art Bible or explicit user decision overrides it.

## Product-facing target

The finished game should read immediately as a premium mobile logistics-management game, not as a web dashboard placed over a 3D scene.

Core visual promise:

- 3D warehouse is the hero.
- Players should see goods physically move through inbound, storage, picking, packing, conveyors/automation and outbound.
- Investments must visibly transform the warehouse.
- UI should be high-contrast, compact and readable on iPhone without covering the facility.
- The game should feel operational, busy and satisfying even while the player is only observing.

## Art direction

### Environment

- Isometric / elevated 3D camera.
- Dark navy industrial shell with warm practical lights.
- Clean grey floors, yellow safety lines and subtle grid/route cues.
- Blue/cyan tech accents for UI and facility signage.
- Orange/yellow accents for racks, safety zones and logistics machinery.
- Realistic-enough logistics readability with stylized proportions; avoid toy-like emptiness.
- Dense but organized facility composition: racks, pallets, cartons, workstations, conveyors, forklifts/AGVs, dock doors and trucks.

### Characters

- Stylized workers with simple silhouettes and strong role readability.
- PPE and role-color differences should be visible at gameplay scale.
- Workers should look like employees in a functioning operation, not abstract capsules.
- Carrying, packing, forklift and dock-loading actions should be visually readable.

### Machines and automation

- Equipment must have strong silhouettes and visible motion states.
- Conveyors, forklift, AGV, sorter, AS/RS, truck dock and routing systems should visually communicate what they are doing.
- New capital investment should change the scene materially, not only change numbers.

## UI direction

### Top HUD

Four compact primary metrics:

- 資金
- 研究RP
- 出荷ペース
- 注文待ち

Use strong numeric hierarchy and icons. Avoid tiny explanatory copy.

### Bottleneck Director

Compact operational status card below the primary HUD.

Target language pattern:

- status pill, e.g. `安定`
- concise diagnosis, e.g. `Warehouse安定運転`
- optional contracts remain visually secondary.

Director is an analyst, not a mandatory instruction engine.

### Bottom controls

Persistent mobile control strip should be compact and thumb-readable.

Reference structure:

- 入庫 / operational view
- 出庫 / logistics view
- FLOW
- speed control
- 投資

Exact labels may change as UX matures, but visual weight and simplicity should remain.

### Feedback

Use short, satisfying world-space or HUD feedback such as:

`出荷 +¥7320`

Feedback should reinforce cause and effect without covering the scene.

## Lighting and polish

- Cool warehouse ambience + warm task lighting.
- Soft glow on important signs and UI edges.
- Clear contact shadows and depth separation.
- Avoid flat full-bright prototype lighting.
- Important moving goods and machines should remain readable against the floor.
- VFX should support logistics flow rather than become decorative noise.

## Mobile readability rules

- No mojibake or missing glyphs.
- Japanese body copy must remain readable at normal iPhone viewing distance.
- Do not use 9–10 px-equivalent text for critical information.
- Avoid large modal panels covering most of the warehouse for routine decisions.
- Prefer hierarchy, tabs/categories and progressive disclosure over dense card walls.
- HUD + controls should leave the majority of the screen to the 3D operation.

## Implementation priorities for the Godot rebuild

1. Fix Japanese font rendering first.
2. Rebuild warehouse composition and camera toward this target.
3. Replace capsule prototype workers with readable stylized workers.
4. Add lighting/material pass before adding more meta systems.
5. Rebuild HUD and bottom control strip around the North Star hierarchy.
6. Make each investment visibly alter the 3D facility.
7. Add motion/VFX/audio/haptics only after the core visual hierarchy is stable.

## Acceptance test

A Godot milestone is visually on-target only if an iPhone screenshot can be compared to the approved North Star and clearly satisfies all of the following:

- warehouse is visually dominant;
- logistics stages are identifiable without reading a manual;
- Japanese UI is immediately legible;
- workers/machines/goods visibly communicate activity;
- capital growth can be seen in the environment;
- the screen looks like a commercial mobile game rather than an engine prototype.

The current Godot vertical slice should be treated as functional scaffolding, not the target visual quality.
