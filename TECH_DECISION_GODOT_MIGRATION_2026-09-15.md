# Logistics Boss — Godot Migration Decision Record

Date: 2026-09-15 JST  
Status: **Godot adopted as canonical production baseline**  
Canonical repo: `48wr9f4wgp-lab/Logistics-Boss`

## Decision

Logistics Boss production development moves to **Godot 4.x + GDScript**.

The previous Three.js/DOM build is now a **legacy reference only**. It is no longer a compatibility target and does not block Godot-side architecture, UI, rendering, input, save, balance, or content decisions.

Do not delete legacy files merely to make the repository look clean. Keep them until removal is useful, but stop spending development time maintaining parity with them.

## Canonical product loop

`observe flow -> find bottleneck -> choose investment / operating decision -> autonomous logistics reacts -> measure result -> reinvest at larger scale`

This remains the product truth. Godot is now the implementation truth.

## Why Godot won the gate

The Godot vertical slice has demonstrated the required production qualities:

1. `inbound -> storage -> pick -> pack -> outbound -> revenue` runs continuously.
2. Autonomous workers visibly execute real simulation tasks.
3. Policy choice changes worker prioritization.
4. Natural bottlenecks appear and can be improved by investment.
5. Investment changes both simulation state and visible 3D facility state.
6. Revenue comes from real outbound completion.
7. Mobile portrait UI keeps the warehouse as the primary visual surface.
8. Touch orbit / pinch zoom and time controls are implemented.
9. Save/load is versioned separately and verified by runtime smoke tests.
10. Godot 4.7.2 project import, full-scene runtime and Web export pass in CI.
11. iPhone visual checks show the Godot presentation has surpassed the old DOM/Three.js direction.
12. A Visual North Star and production icon direction are now defined specifically for the Godot version.

## Production architecture

- `godot/domain/warehouse_sim.gd` — authoritative logistics/economy state.
- `godot/view/warehouse_view.gd` — engine-native 3D facility and parcel/worker visualization.
- `godot/view/visual_pass_*.gd` — presentation-only visual layers; no economy ownership.
- `godot/ui/game_hud_ja.gd` — Japanese-first mobile HUD.
- `godot/persistence/save_store.gd` — Godot-specific versioned persistence.
- `godot/main.gd` — composition root.
- `godot/icon.svg` — canonical app icon asset.

## Language and platform direction

- Product UI is **Japanese-first**.
- Native iOS/Android are the production targets.
- System-font fallback is allowed for native builds so CJK glyphs render without bundling a proprietary platform font.
- Web export may remain as a temporary engineering preview, but it is **not** a production constraint and does not justify English fallback or Web-specific product compromises.

## Legacy Web policy

The old Web build may remain in the repository as a behavioral/history reference, but:

- do not add new gameplay there;
- do not require feature parity;
- do not delay Godot changes to preserve DOM layout or Three.js behavior;
- legacy Web-specific regression workflows may be removed once the Godot replacements cover the same product risk.

## Next priorities

1. Japanese-native HUD and icon integration.
2. Continue Visual Pass toward the canonical North Star.
3. Port progression/Capital systems into Godot domain modules without recreating the old monolith.
4. Add engine-native audio, VFX and haptics.
5. Establish native iOS device build/signing path before Release Candidate.

## Rollback

The previous Web build remains available for historical reference, but it is no longer the planned production rollback target. If a Godot subsystem fails, fix or replace that subsystem inside the Godot architecture rather than returning the product to DOM + Three.js development.
