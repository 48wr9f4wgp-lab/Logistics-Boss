# マチコバ！ — first playable slice

Confirmed public title: マチコバ！ / tagline: 小さな工場、大きな夢。 User decision: 2026-10-31. Previous working title: FORGE / 町工場. See `NAMING_DECISION_2026-10-31.md`.
Title-local, 2026-10-29. User-approved new concept; old FLOTRA development is superseded for this task, preserved unchanged.

Goal: touch-first factory placement, orders, actual worker routing/production, dispatch, reinvestment and worker training, with two investment directions. iPhone remains intended production target. This dependency-free Canvas/DOM build is a bounded engineering/gameplay prototype, not a production engine decision or a native iOS build. Production decision UNDECIDED; release approval NOT_REQUESTED. Existing repository and development Pages only.

Scope: docs/forge-preview; factory-prototype; scoped CI. No legacy save, economics, branch or source changes. Revert added files to roll back. Independent save namespace, validation and export/import; no offline billing. Saved state never overwritten on invalid data. Web Locks exclusive writer where supported, storage revision conflict guard otherwise.

Acceptance: two simultaneous orders share finite machine capacity; routing/layout and skill affect completion time; materials cost on acceptance; dispatch pays once; purchases cannot overspend; expansion and training alter capability; unsuitable placements reject; interrupted jobs restore consistently; no mutation in background; mobile controls usable. Domain tests plus actual browser journey/visual review. Native iPhone performance/fun remain unverified.

Initial slice: plates and precision shafts, cutter/drill/inspection and purchasable lathe, three workers, expandable floor. Quality rework is deterministic and explained. Training/mentoring included; external contracting, breakdowns, brands and multiple buildings deferred. Numbers are fictional balance parameters.

2026-10-30 / v0.4 extension: two growth contracts reuse the existing products and investment systems. Drill upgrade/addition opens short-deadline volume work; a lathe plus one skill-3 worker opens quality-3 shafts. Both routes stay available. Requirements, fictional parameters and save-rollback limitation are recorded in README.md and CHANGE_v04_2026-10-30.md. No native production or art-target decision.

2026-10-31 / v0.6: selected growth contract, preparation/material budget, and state-based next action. See CHANGE_PACKET_v06.md. This completes the bounded guidance pass; before expanding content further, prioritize a short iPhone play session of accept → invest → deliver and collect concrete feedback on readability, decisions and waiting. No actual-device or fun greenlight yet.

2026-10-31 / v0.7: direct user feedback reported too much waiting. Added an opt-in completion skip with real costs and automatic pause at the next ready order. See CHANGE_PACKET_v07.md. No new game systems/content; this addresses the wait before the next decision.

2026-10-31 / v0.8: investment feedback shows actual per-piece processing and inspection effects before upgrade/training, remaining cash/shortfalls, and visible machine levels. See CHANGE_PACKET_v08.md. This is a decision/readability pass, not new content or a claim of proven fun.

2026-10-31 / v0.9: explicit player feedback rejected the placeholder graphics. Implement the approved stylized workshop direction in the playable development build: recognisable machinery, working people, light/materials, visible upgrades, and more mobile scene space. See CHANGE_PACKET_v09.md. This is the next visual iteration, not a native release or a claim that visual appeal has been validated by the player.

2026-10-31 / v0.10: connect the existing shipment loop to investment and growth goals. Highlight the first affordable order and give result-screen guidance based on remaining commitments, current goals and actual delivery status. Keep detailed accounting available without placing it before the next decision. See CHANGE_PACKET_v010.md. This is a bounded guidance pass with no new systems, rewards or saved state; device/fun validation remains open.

2026-10-31 / v0.11: the player liked the graphics and explicitly requested further polish. Keep the current miniature-workshop direction and refine material separation, window/contact lighting and real pickup/carry/working poses. See CHANGE_PACKET_v011.md. This locks the existing direction as the reference for refinement; it does not authorize an unrelated redesign or change the game model, native-production decision or device-validation status.


v0.12: The player reported too many places to look. One ticket on the floor now handles the common order, work, shipment and next-step journey. Optional controls and management live behind two named entries. Keep the approved workshop renderer and existing saves. Evaluate the next player impression on iPhone.

v0.13: Build a more legible, material-rich workshop around the v0.12 single work ticket. Use north-light roof bays, directional light on the slab, distinct machine silhouettes and a warm workbench behind the interactive miniature. Evaluate the scene at normal phone scale and after enlargement.

v0.14: Continue the visual pass by making workers, machine controls and material handoffs readable in motion. The walking direction and pose follow the existing job. In-process stock remains at its actual service cell until pickup. Verify mixed orders, reloads and equipment moves, alongside the normal mobile ticket.

v0.15: A commercial-quality art target for the main workshop. Bake original three-dimensional tool bodies, moving assemblies, crew, truck and rooms with a single lighting setup. Validate against the same shift in v0.14, including existing save paths, reduced motion and direct control selection. Physical iPhone review remains open.
