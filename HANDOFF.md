# Logistics Boss — Development Handoff

Updated: 2026-09-14 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Current audited main baseline: `9d94634d41d8eafdce129fd36366086038e36e64`

## 0. Canonical source order

For every development decision, use this order:

1. Current `main` implementation.
2. This `HANDOFF.md` for the latest title-specific state and immediate task.
3. `CAPITAL_EXPANSION_V1.md`, `CAPITAL_EXPANSION_V2.md`, `UX_ERGONOMICS_PASS_2026-09-14.md`, and current benchmark addenda.
4. `GDD_LOGISTICS_BOSS.md`.
5. Project-level `GAME_DEV_MASTER_RULES v1.3`.

Older GDD / FTUE language that prescribes a single path is stale. Do **not** restore:
- mandatory “choose a contract” progression;
- “今やること” rails;
- Director buttons that choose the correct answer for the player;
- severity-driven automatic Director opening;
- MutationObserver layers that compete over UI state.

Current product rule: **the game diagnoses state and consequences; the player chooses the solution.**

## 1. Product core

Logistics Boss is a mobile-first 3D logistics management / automation-observer game.

Canonical loop:

`observe → find bottleneck → choose investment / operating decision → visible 3D logistics changes → measure Before/After → a new bottleneck emerges → reinvest at a larger scale → grow into a huge logistics center`

The player does not manually carry parcels or control an avatar. The fantasy is operating and capital allocation: workers, machines and buildings react autonomously.

Finished-product priorities:
- visible autonomous 3D logistics;
- meaningful capital escalation;
- multiple viable investment paths;
- measurable operational consequences;
- new bottlenecks created by successful improvements;
- clear mobile UX while keeping the warehouse visually primary.

Current stage: Functional Build moving toward deeper Vertical Slice / product-quality validation. Not release-ready.

## 2. Technology / deployment

Current production path:
- static HTML / CSS / vanilla JavaScript ES modules;
- Three.js `0.186.0` via jsDelivr;
- `@dimforge/rapier3d-compat` `0.20.0` via jsDelivr;
- GitHub Actions static QA + Node smoke tests;
- GitHub Pages from `main/docs`;
- iPhone Safari / Home Screen web app is the primary real-device target;
- localStorage save key: `logistics_boss_save`;
- save schema: `3`.

No backend, accounts, analytics service, npm build, app-store wrapper or native engine is currently required. Do not migrate engines without an actual requirement/performance/native blocker.

## 3. Current architecture

Important files:
- `docs/src/sim.js` — authoritative simulation/economy state, workers, parcel lifecycle, facilities, capital purchase API, contracts, save/load.
- `docs/src/scene.js` — Three.js scene, workers/parcels, visible equipment/building growth, camera/touch, FLOW visualization.
- `docs/src/ui.js` — HUD, Director presentation, policies/contracts, Rank 2 UI. Director open/closed state is user-controlled here.
- `docs/src/freedom.js` — non-linear Rank 1 Warehouse-rating progression.
- `docs/src/capital-model.js` — Capital investment definitions, cost ladders, unlock assets, commercial tiers.
- `docs/src/capital.js` — Capital bottom-sheet UI and 25-second Before/After measurement. Requests purchases through `sim.purchaseCapitalUpgrade()`; it does not own money mutation.
- `docs/src/ergonomics.js` — mobile sheet/ergonomic behavior only; it must not overwrite primary HUD metrics.
- `docs/tests/` — progression, Director stability, ergonomics/HUD and Capital smoke coverage.
- `.github/workflows/qa.yml` — canonical static/regression gate.

Removed architectural debt that must stay removed:
- `docs/src/insight-stability.js` observer guard;
- `docs/src/ftue2.js` post-render FTUE override;
- duplicated top-HUD writers.

## 4. Confirmed interaction fixes

### Director / optional-contract flicker — CLOSED on iPhone
Root cause was multiple modules/old FTUE logic competing for the same Director DOM/open state.

Current architecture:
- `ui.js` is the single authority for Director presentation/open state;
- severity changes do not automatically open a closed panel;
- old `STEP 1/3` / “出庫優先にする” correct-answer UI is removed;
- contracts are explicitly optional;
- regression tests fail if the old FTUE/Director ownership returns.

User re-tested the deployed Pages build on iPhone and confirmed the earlier rapid Director/contract flicker no longer occurs.

### Top HUD `出荷ペース` flicker — CLOSED on iPhone
Root cause: `ui.js` wrote cumulative shipped count while `ergonomics.js` rewrote the same third HUD card as shipments/min, producing rapid values such as `3 ↔ 79`.

Current architecture:
- the third primary HUD card is explicitly `出荷ペース`;
- `ui.js` is its single numeric writer;
- cumulative shipped count is separate;
- `ergonomics.js` no longer performs positional top-HUD rewrites;
- `hud-metric-stability-smoke.mjs` + CI lock the ownership.

User supplied a follow-up iPhone screen recording. The metric then changed naturally over time instead of alternating between two unrelated values, so this P0 is closed.

## 5. Current gameplay systems

### Core simulation
- Inbound → rack → pick → pack → outbound flow.
- Autonomous workers and role/task assignment.
- Pause / 1x / 2x / 4x.
- Cash after real shipment.
- Orders, receiving, packing and outbound queues.
- Bottleneck diagnosis for inbound / rack / orders / packed output.
- Recovery-first congestion; no hard fail state.

### Freedom progression / contracts
- Rank 1 Warehouse rating can grow through shipped volume, throughput, stable operation and optional contracts.
- Warehouse target remains rating 8.
- Optional three-choice contracts remain available but are not a mandatory rail.
- RP and research perks remain active.

### Rank 2
- Warehouse rank unlocks a 5-worker base operation.
- Staffing presets: receiving / balanced / picking / dock / shipping.
- Three one-of-two structural zones for intake, storage and packing.
- Facilities visibly change the 3D warehouse and affect the simulation.
- Rank 2 facility decisions have a Before/After impact report.
- Fulfillment Center readiness UI exists; true Rank 3 gameplay is still not implemented.

## 6. Capital Expansion — current main

### Capital v1
Early capital layer remains:
- Rack Wing;
- Packing Module;
- Handling / Route Improvement;
- Conveyor Spine.

They produce real simulation and visible 3D effects.

### Capital v2 Phase 1 — automation
Implemented and merged:
- **Forklift Fleet** — batch inbound → rack handling with visible forklift vehicles.
- **AGV Pick Fleet** — rack → packing automated picking with visible AGVs.
- **Automatic Sorter** — packed → real shipment automation with visible sorter modules.

Commercial shipment revenue and capital mutation are owned by `sim.js`. Capital UI measures the same economy through shipment events.

### Capital v2 Phase 2 — workforce + property
Merged into main at `9d94634d41d8eafdce129fd36366086038e36e64`.

#### Workforce Expansion
Capital card: `現場チーム増員`.
- Unlock: equipment assets `¥2,500`.
- Costs: `¥3,500 / 15,000 / 70,000 / 350,000 / 1,800,000`.
- Five levels.
- Each level adds **one real simulation worker** through the existing staffing/dispatch system.
- Because workers are rendered from `sim.state.workers`, each hire produces another visible 3D worker.
- This is deliberately a flexible human-capacity path, not an infinite +1 numeric clicker.

#### Logistics Hall Expansion
Capital card: `物流ホール拡張`.
- Unlock: equipment assets `¥200,000`.
- Costs: `¥300,000 / 2,500,000 / 20,000,000`.
- Three levels.
- Each level adds real simulation capacity: rack `+8` and receiving buffer `+4`.
- Each purchased level reveals one additional full 3D hall (`HALL 2`–`HALL 4`) and widens camera framing.
- Hall expansion does **not** directly process parcels faster. It creates physical headroom, so labor/picking/packing/outbound can become the new bottleneck.

The existing Capital 25-second Before/After measurement applies to workforce and hall purchases through the same generic purchase path.

## 7. Four-condition gate for every new major purchase

Do not add a major Capital category unless all four are true:

1. **Visible 3D change** — machine, worker, fleet, building or site visibly changes.
2. **Real logistics behavior change** — it changes actual capacity or parcel/work movement, not only a displayed multiplier.
3. **Before/After measurement** — the player can see operational effect, including negative outcomes.
4. **New bottleneck potential** — solving one constraint can expose another.

This is more important than adding a large number of upgrade cards.

## 8. Latest verification state

For PR #5 (`feature/capital-v2-workforce-hall` → `main`):
- PR static QA: success.
- Changed-file audit: only intended six files.
- Squash merged to main: `9d94634d41d8eafdce129fd36366086038e36e64`.
- Main static QA: success, including Director stability, HUD stability, Rank 1 freedom, Rank 2 and Capital v2 smoke gates.
- GitHub Pages build: success.
- GitHub Pages deploy: success.

What is **not** yet verified:
- real-iPhone visual/interaction check of the new Workforce and Hall Capital cards;
- real-iPhone visual reveal/camera framing for a purchased hall;
- real-iPhone confirmation that an added worker is readable at current camera scale.

Do not call those visual details finished until device-tested.

## 9. Known risks / design watchpoints

- Workforce must remain a strategic alternative/bridge to automation, not dominate every bottleneck by cheap headcount spam. Tune costs and marginal value from play data.
- Hall expansion creates capacity, not processing speed. If the player does not feel the building-scale payoff or cannot understand why throughput did not immediately jump, presentation/measurement needs improvement rather than fake speed bonuses.
- Existing commercial tiers may need rebalance now that property costs reach tens of millions.
- True Rank 3 does not exist despite Fulfillment Center readiness UI.
- `sim.js`, `scene.js` and `ui.js` are getting large; refactor by responsibility before another major complexity jump, but do not rewrite functioning systems wholesale.
- No service worker; CDN dependencies mean true offline launch is not guaranteed.
- No analytics yet; real product tuning still relies on manual play/device observation.
- Build/test success is not equivalent to real-device UX success.

## 10. Next product-development order

After the Phase 2 device check, continue Capital v2 depth in this order unless fresh benchmark evidence says otherwise:

1. **Truck dock / truck-wave system** — create visible inbound/outbound demand waves and a reason to invest in dock throughput/buffering.
2. **AS/RS automated storage/retrieval** — property/automation interaction, not a plain rack multiplier.
3. **True Rank 3: Fulfillment Center** — larger operating layer and staged routing packages.
4. **Campus / second-center expansion** — only after one-center capital escalation is proven fun and readable.

Before a major new visual pass or Rank 3 implementation, refresh live-market/benchmark evidence per project rules.

## 11. Exact first task for the next chat

1. Pull current `main` and confirm baseline at or after `9d94634d41d8eafdce129fd36366086038e36e64`.
2. Confirm the newest `HANDOFF.md` supersedes the older P0 Director/FTUE instructions.
3. If the user has not yet device-checked Capital v2 Phase 2, request only this focused iPhone verification after code-side checks:
   - open `投資` and verify `現場チーム増員` / `物流ホール拡張` cards are readable;
   - when affordable, buy one workforce level and confirm one visible worker appears and operates;
   - when a hall purchase is reachable/test-funded, confirm the additional hall appears and camera framing remains usable.
4. If device verification is clean, begin **Truck Dock / Truck Waves** as Capital v2 Phase 3. It must satisfy the four-condition gate and must not introduce a prescribed correct purchase.
5. Continue the normal gate after changes: `syntax/build → automated tests → behavior/regression → Pages deploy → iPhone visual verification where required`.

## 12. Non-negotiable rules

- Current GitHub main is canonical; never trust an old chat over the code.
- Do not claim an untested fix is fixed.
- Do not restore old prescribed FTUE/Director rails.
- Do not stack MutationObservers to hide state-ownership bugs; fix ownership.
- Do not turn Capital progression into invisible numeric level-ups.
- Do not add features merely for quantity; prioritize touch feel, clarity, visible growth, progression and replay desire.
- Do not let a resource/bottleneck state make the game unintentionally impossible to play.
- Preserve save compatibility unless an explicit migration is implemented and tested.
- Keep money/economy mutation in the simulation domain.
- After meaningful code changes, run the strongest available build/test/behavior/regression checks before reporting completion.
