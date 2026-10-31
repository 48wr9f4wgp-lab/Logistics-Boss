# FORGE v0.9 — Workshop visual overhaul

Date: 2026-10-31 (Japan). Title-local, VERTICAL_SLICE, LITE.

Goal: replace the abstract prototype appearance with a readable, tactile workshop that invites building and investment. Current user rejected v0.8 graphics and authorized implementation of the generated visual concept.

Non-goals: economic changes, new save fields, new production systems, native/App Store release.

Existing behavior: fixed-tick production, manual shipment, completion skip, editable machines, saved investment/worker progression.

Scope: docs/forge-preview/{app.mjs,index.html,style.css,renderer.mjs,view.mjs,assets/}; focused geometry/render tests; title-local verification and art reference.

Acceptance: detailed distinct machine art, coherent isometric floor/light/depth, workers follow actual routes and work state, camera/picking remain aligned, selected machines and valid placements visible, 390px phone UI with accessible controls, full accept/skip/ship/invest/reload works. Animation respects pause, menus and reduced motion. Missing image art has a usable fallback.

Tests: existing model suite; renderer no-state-mutation and projection/picking; browser visual review and ordinary actions at phone dimensions. No claim of physical iPhone or final concept fidelity from desktop tests.

Target: generated concept in this conversation (Library libfile_5096c9470d308191941431528267f2b4), warm industrial diorama, olive/teal machines, navy workers, amber accents. Aspirational target, distinct from screenshots of implementation. Build renderer is 2.5D and uses image assets, not a 3D runtime.

Recovery: revert v0.9 PR and re-deploy existing Pages; model and save schema/key remain unchanged. Existing local checkout clean at e0c1841; isolated worktree based on fetched origin/main same SHA. User/Atlas unsynced changes unknown.
