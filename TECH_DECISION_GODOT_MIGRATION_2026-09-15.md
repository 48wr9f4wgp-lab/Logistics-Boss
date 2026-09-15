# Logistics Boss — Godot Migration Decision Record

Date: 2026-09-15 JST  
Status: Accepted for vertical-slice migration  
Canonical repo: `48wr9f4wgp-lab/Logistics-Boss`

## Decision

Develop the next production vertical slice in Godot 4.x using GDScript while keeping the current Three.js/Web build as the behavioral and balancing reference implementation until the Godot slice wins the migration gate.

The Web build is not deleted or deprecated yet. It remains the rollback/reference baseline for simulation rules, pacing, Capital behavior, Rank 3 routing, and verified iPhone UX findings.

## Why now

The product has passed the point where most implementation risk is discovering the core loop. The core is now explicit:

`observe flow -> find bottleneck -> choose investment / operating decision -> autonomous logistics reacts -> measure result -> reinvest at larger scale`

The remaining work increasingly depends on game-engine strengths: scene hierarchy, animated autonomous agents, 3D facility growth, VFX/audio/haptics, mobile input, native packaging, and a game-native management UI. Continuing to expand DOM + Three.js raises coordination and presentation cost.

## Migration strategy

Do not port file-for-file.

The Godot version must preserve product behavior while rebuilding architecture around engine-native systems:

- Domain simulation is deterministic and renderer-independent.
- 3D presentation reacts to domain state/events; it does not own economy mutations.
- UI is rebuilt for mobile hierarchy instead of reproducing the current DOM layout.
- Save data is versioned separately from the Web save until an explicit migration is designed.
- Web remains deployable during the port.

## Vertical Slice Gate

Godot becomes the production baseline only after one slice proves all of the following:

1. `inbound -> storage -> pick -> pack -> outbound -> revenue` runs continuously.
2. Three or more autonomous workers visibly execute real simulation tasks.
3. Policy choice changes worker prioritization.
4. At least one natural bottleneck appears and can be improved by investment.
5. Investment causes both a real simulation change and a visible 3D change.
6. Money is awarded only from real outbound completion.
7. Mobile portrait UI keeps the warehouse visually dominant.
8. Touch camera + pause/1x/2x/4x are usable.
9. Save/load restores progression safely.
10. Web export is testable on iPhone before the old build is retired.

## Initial Godot architecture

- `godot/domain/warehouse_sim.gd` — authoritative logistics/economy state.
- `godot/view/warehouse_view.gd` — low-poly 3D facility, workers and parcel visualization.
- `godot/ui/game_hud.gd` — mobile HUD, policy, speed and upgrade controls.
- `godot/persistence/save_store.gd` — Godot-specific versioned persistence.
- `godot/main.gd` — composition root only.

## Non-goals for the first port slice

- Rank 2 structural zones.
- Capital v2 automation fleet.
- Truck waves.
- AS/RS.
- Rank 3 Carrier Routing.
- Store release or native iOS signing.
- Pixel-matching the current Web UI.

Those systems are ported only after the Godot core slice is verified on device.

## Rollback

If the Godot slice fails the migration gate on performance, development speed, interaction quality, or iPhone Web viability, continue from the current Web `main` implementation. No Web production code is removed by this decision.
