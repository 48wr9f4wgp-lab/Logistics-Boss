# FORGE / 町工場 — first playable slice
Title-local, 2026-10-29. User-approved new concept; old FLOTRA development is superseded for this task, preserved unchanged.

Goal: touch-first factory placement, orders, actual worker routing/production, dispatch, reinvestment and worker training, with two investment directions. iPhone remains intended production target. This dependency-free Canvas/DOM build is a bounded engineering/gameplay prototype, not a production engine decision or a native iOS build. Production decision UNDECIDED; release approval NOT_REQUESTED. Existing repository and development Pages only.

Scope: docs/forge-preview; factory-prototype; scoped CI. No legacy save, economics, branch or source changes. Revert added files to roll back. Independent save namespace, validation and export/import; no offline billing. Saved state never overwritten on invalid data. Web Locks exclusive writer where supported, storage revision conflict guard otherwise.

Acceptance: two simultaneous orders share finite machine capacity; routing/layout and skill affect completion time; materials cost on acceptance; dispatch pays once; purchases cannot overspend; expansion and training alter capability; unsuitable placements reject; interrupted jobs restore consistently; no mutation in background; mobile controls usable. Domain tests plus actual browser journey/visual review. Native iPhone performance/fun remain unverified.

Initial slice: plates and precision shafts, cutter/drill/inspection and purchasable lathe, three workers, expandable floor. Quality rework is deterministic and explained. Training/mentoring included; external contracting, breakdowns, brands and multiple buildings deferred. Numbers are fictional balance parameters.
