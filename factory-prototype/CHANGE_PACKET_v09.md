# FORGE v0.9 — 育てる町工場を画面にする

2026-10-31 / existing development Pages / visual iteration

## Purpose

The player explicitly rejected the placeholder graphics. Bring the approved isometric, lightly stylized metal-and-oil workshop direction into the functioning game. Prioritize the factory scene without adding another game system.

## Changes

- A dedicated read-only workshop renderer replaces the old simple-box pass. Cutaway walls, steel columns, windows/light, concrete texture, contact shadows, tools, pallets, delivery truck and small exterior details establish the setting.
- Cutter, drill press, lathe and inspection bench have distinct shapes, paint and metal parts. Actual level 2/3 upgrades add guards, panels and tooling.
- Actual jobs drive spindle/feed/arm/leg movement, carried stock and restrained cutting sparks. Machines and workers share depth sorting. Pause and reduced motion stop the animated details.
- Compact mobile chrome, consistent drawn icons, optional equipment labels and a reset-to-overview control. The existing stage-selection and production actions remain accessible.
- Labels are drawn above bodies and now receive matching picking priority. A regression covers a rear machine label overlapping a foreground machine body.
- Static scene caching and a 30fps drawing cap. Simulation continues to use the unchanged fixed timestep.

## Scope and compatibility

Only `docs/forge-preview`, `factory-prototype` and the existing scoped workflow. `model.mjs` is byte-identical to v0.8. Existing save key/schema, work routing, prices, pay, deadlines, skipping, import/export and writer protection are preserved. No changes to FLOTRA or other titles.

## Verification before publishing

- 47 existing/extended Node tests pass; browser module syntax checks pass.
- NAPI Canvas visual review: fresh factory, active job, lathe, upgraded machines and selection. Independent review reproduced and fixed the label overlap issue and verified overview reset.
- Rendering leaves state byte-identical; paused and reduced-motion frames are unchanged as animation time varies; working frames change.
- The real mobile browser layout and public click journey are checked after the normal development deployment. They are separate from Canvas-only checks. Physical iPhone/Safari performance and the player's judgement of the new art remain unverified.

## Public browser verification

The development Pages deployment for `625e95085f41f73a6fc7c4b14201e88b982f1a89` completed successfully. A fresh isolated browser confirmed v0.9 and tested the actual public page: accept 12 plates, skip to completion, dispatch, upgrade the cutter to level 2, then reload. Cash, delivered count and level persisted; no page or console errors occurred. Optional labels, zoom and overview reset worked.

At 390×844 the scene grew from 320px to 420px, with no page overflow. 320×740 and 1280×900 also fit. A 57px vertical overflow was found at 375×667 and 390×667, so a compact-height layout was added to keep the complete action/menu area visible. Its short-screen recheck is recorded in the follow-up browser evidence. Tests use an isolated test save, not the player's browser data.

## Rollback

Revert this change and redeploy the same development Pages. Existing v0.8 save data needs no conversion.
