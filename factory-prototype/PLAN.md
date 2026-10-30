# FORGE / 町工場 — first playable slice
Title-local, 2026-10-29. User-approved new concept; old FLOTRA development is superseded for this task, preserved unchanged.

Goal: touch-first factory placement, orders, actual worker routing/production, dispatch, reinvestment and worker training, with two investment directions. iPhone remains intended production target. This dependency-free Canvas/DOM build is a bounded engineering/gameplay prototype, not a production engine decision or a native iOS build. Production decision UNDECIDED; release approval NOT_REQUESTED. Existing repository and development Pages only.

Scope: docs/forge-preview; factory-prototype; scoped CI. No legacy save, economics, branch or source changes. Revert added files to roll back. Independent save namespace, validation and export/import; no offline billing. Saved state never overwritten on invalid data. Web Locks exclusive writer where supported, storage revision conflict guard otherwise.

Acceptance: two simultaneous orders share finite machine capacity; routing/layout and skill affect completion time; materials cost on acceptance; dispatch pays once; purchases cannot overspend; expansion and training alter capability; unsuitable placements reject; interrupted jobs restore consistently; no mutation in background; mobile controls usable. Domain tests plus actual browser journey/visual review. Native iPhone performance/fun remain unverified.

Initial slice: plates and precision shafts, cutter/drill/inspection and purchasable lathe, three workers, expandable floor. Quality rework is deterministic and explained. Training/mentoring included; external contracting, breakdowns, brands and multiple buildings deferred. Numbers are fictional balance parameters.

2026-10-30 / v0.4 extension: two growth contracts reuse the existing products and investment systems. Drill upgrade/addition opens short-deadline volume work; a lathe plus one skill-3 worker opens quality-3 shafts. Both routes stay available. Requirements, fictional parameters and save-rollback limitation are recorded in README.md and CHANGE_v04_2026-10-30.md. No native production or art-target decision.

2026-10-31 / v0.6: selected growth contract, preparation/material budget, and state-based next action. See CHANGE_PACKET_v06.md. This completes the bounded guidance pass; before expanding content further, prioritize a short iPhone play session of accept → invest → deliver and collect concrete feedback on readability, decisions and waiting. No actual-device or fun greenlight yet.
