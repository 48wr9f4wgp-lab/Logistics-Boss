# Logistics Boss — Development Handoff

Updated: 2026-09-15 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Current gameplay baseline: `8e0ffc9af23f5270c26259bd9a43a52774433746`

## 0. Canonical source order

For every development decision, use this order:

1. Current `main` implementation.
2. This `HANDOFF.md` for latest title-specific state and immediate task.
3. `RANK3_FULFILLMENT_CENTER.md`, `CAPITAL_PACING_V1.md`, `CAPITAL_EXPANSION_V2.md`, `CAPITAL_EXPANSION_V1.md`, current UX/benchmark addenda.
4. `GDD_LOGISTICS_BOSS.md`.
5. Project-level `GAME_DEV_MASTER_RULES v1.3`.

Older FTUE/GDD language that prescribes a single path is stale. Do **not** restore mandatory contracts, “今やること” rails, Director correct-answer buttons, severity-driven panel opening, or MutationObserver state guards.

Current product rule: **the game diagnoses state and consequences; the player chooses the solution.**

## 1. Product core

Logistics Boss is a mobile-first 3D logistics management / automation-observer game.

Canonical loop:

`observe → find bottleneck → choose investment / operating decision → autonomous 3D logistics changes → measure Before/After → a new bottleneck emerges → reinvest at larger scale`

Player fantasy is operating and capital allocation, not manual parcel carrying or avatar driving.

Finished-product priorities:
- visible autonomous logistics;
- meaningful capital escalation;
- multiple viable operating/investment paths;
- measurable consequences including negative tradeoffs;
- bottlenecks that move when solved;
- clear mobile UX while keeping the facility visually primary.

Current stage: Functional Build / deeper Vertical Slice maturation. **Not release-ready.**

## 2. Technology / deployment

- static HTML/CSS/vanilla JavaScript ES modules;
- Three.js `0.186.0`;
- Rapier compat `0.20.0`;
- GitHub Actions static/regression QA;
- GitHub Pages from `main/docs`;
- iPhone Safari / Home Screen web app is primary real-device target;
- localStorage save key `logistics_boss_save`;
- save schema `3`.

Do not migrate engine without a concrete performance/native requirement.

## 3. Architecture ownership

- `docs/src/sim.js` — authoritative simulation/economy, parcel lifecycle, workers, automation, revenue, facility rank, routing boundary, save/load.
- `docs/src/scene.js` — core Three.js warehouse view and orchestration of visual modules.
- `docs/src/ui.js` — HUD, Director, policies/contracts, Rank 2 controls. Director state remains single-owner here.
- `docs/src/freedom.js` — free-form Rank 1 progression.
- `docs/src/capital-model.js` / `capital.js` — Capital definitions, economy tiers, purchases, 25s investment Before/After.
- `docs/src/rank3-model.js` / `rank3.js` — Rank 3 readiness model and readiness presentation.
- `docs/src/routing-model.js` — Carrier Routing package definitions/economics.
- `docs/src/routing.js` — Rank 3 routing management UI and 25s route-switch measurement.
- `docs/src/routing-visual.js` — Rank 3 Routing Hub, carrier lanes and real-event dispatch visualization.
- `docs/src/asrs-visual.js` — AS/RS visual module.
- `docs/src/ergonomics.js` — mobile sheet ergonomics only; must not overwrite primary HUD metrics.
- `docs/tests/` — progression, Director/HUD stability, Capital, pacing and Rank 3 regression coverage.

Removed debt that must stay removed:
- `docs/src/insight-stability.js`;
- `docs/src/ftue2.js`;
- duplicated top-HUD writers;
- one-shot routing/promotion codemod scripts/workflows after their use.

## 4. Closed P0 interaction issues

### Director / optional-contract flicker — CLOSED on iPhone
`ui.js` owns Director presentation/open state. Severity changes do not auto-open it. Contracts are optional.

### Top HUD `出荷ペース` flicker — CLOSED on iPhone
`ui.js` is the single writer for the primary throughput metric. Ergonomics no longer rewrites it.

Do not reintroduce multi-writer UI state.

## 5. Current gameplay progression

### Rank 1 — Small Depot
- free-form Warehouse rating;
- rating can grow through shipment volume, throughput, stable operation and optional contracts;
- contracts are never mandatory;
- target rating 8.

### Rank 2 — Warehouse
- five-worker base operation;
- staffing presets;
- three one-of-two structural zones: intake, storage, packing;
- real simulation + visible 3D facility effects;
- Before/After facility impact.

### Rank 3 — Fulfillment Center
Rank 3 is now a real persisted facility rank.

Readiness is path-agnostic and requires:
1. all three Rank 2 structural zones;
2. invested Capital `>= ¥200,000`;
3. measured throughput `>= 6 shipments/min`.

**Contracts are not part of Rank 3 readiness.** A deterministic regression proves promotion with zero completed contracts.

On readiness, `sim.js` promotes Rank 2 → Rank 3, emits the rank-up event, serializes rank 3 and restores it through schema 3.

## 6. Capital Expansion v2 — implemented layers

### Phase 1 — Automation
- Forklift Fleet: inbound → rack;
- AGV Pick Fleet: rack → packing;
- Automatic Sorter: packed downstream handling.

### Phase 2 — Workforce + Property
- `現場チーム増員`: each level adds one real worker and visible 3D staff;
- `物流ホール拡張`: real rack/receiving capacity and visible HALL 2–4 growth.

### Phase 3 — Truck Dock / Truck Waves
- real truck approach/arrival/unload/depart cycle;
- visible dock/truck behavior;
- inbound arrives in waves instead of a constant stream once active.

### Phase 4 — AS/RS automated warehouse
- real automated storage/retrieval behavior;
- capacity and transfer effects;
- visible high-bay/stacker-crane operation.

Every major Capital category must continue to satisfy:
1. visible 3D change;
2. real logistics behavior/capacity change;
3. Before/After measurement;
4. potential to expose another bottleneck.

## 7. Capital Pacing v1

Mid-game capital pacing was measured through deterministic real simulation and rebalanced to avoid long passive money waits.

Current audited milestone windows are approximately:
- 8.5 min;
- 12.0 min;
- 11.1 min;
- 7.5 min.

CI guards the intended `7–15 minute` band for the audited capital steps. Do not casually change commercial shipment values, Capital costs or throughput multipliers without rerunning pacing regression.

## 8. Rank 3 Carrier Routing — current main

Merged through PR #17 at gameplay baseline `8e0ffc9af23f5270c26259bd9a43a52774433746`.

Rank 3 changes the real downstream flow to:

`packing → packed → outbound staging / Routing Hub → carrier dispatch → shipment revenue`

Workers and Automatic Sorter **cannot bypass routing** at Rank 3.

### Balanced Parcel
- dispatch interval: 4.2s;
- batch 1;
- revenue multiplier 1.00x.

### Express Dispatch
- dispatch interval: 1.8s;
- batch 1;
- revenue multiplier 0.82x;
- clears downstream faster at lower unit margin.

### Consolidated Linehaul
- dispatch interval: 7.5s;
- minimum/batch 3;
- revenue multiplier 1.22x;
- higher unit margin but can accumulate outbound staging.

There is deliberately **no permanent correct route**.

### Measurement
After a route switch, `routing.js` measures a 25-second Before/After using real shipment events:
- shipments/min;
- packed/outbound queue;
- open orders;
- revenue/min.

Negative deltas are shown rather than hidden.

### 3D
`routing-visual.js` adds:
- a visible Routing Hub near outbound;
- three carrier lanes/gates;
- selected-route lighting/signage;
- route-specific cadence indication;
- parcel movement triggered only by real `route_dispatch` events.

## 9. Verification state

For Rank 3 / Carrier Routing:
- branch Static QA: success;
- branch Capital Pacing: success;
- branch Rank 3 readiness/promotion/routing/integration: success;
- PR #17 merged to main;
- main Static QA: success;
- main Capital Pacing: success;
- main Rank 3 readiness/promotion/routing/integration: success;
- GitHub Pages build: success;
- GitHub Pages deploy: verify final status before claiming deployed if this handoff is read during the active deploy window.

Still **not verified on real iPhone**:
- Rank 3 management-sheet layout/readability;
- three routing buttons at phone width;
- Routing Hub/gate readability at current camera scale;
- real dispatch parcel animation visibility;
- route switch + 25s report interaction feel.

Do not call Rank 3 visually complete until that device check passes.

## 10. Known risks / design watchpoints

- Express must not become universally optimal merely because throughput dominates revenue tradeoff.
- Consolidated must not become a passive-wait trap; batching should create a decision, not dead time with no recovery.
- Routing queue is intentionally a new downstream bottleneck candidate; Director/readability may need a follow-up if players cannot distinguish packed vs routing congestion.
- `sim.js`, `scene.js`, `ui.js` remain large. Continue extracting new responsibilities into modules rather than broad rewrites.
- Save schema persists progression/routing mode, not transient parcel queues; this matches current save architecture.
- No backend/analytics yet; balance still needs real-session observation.
- Build/test success is not equivalent to iPhone UX success.

## 11. Immediate next order

1. **Real iPhone Rank 3 verification** on deployed Pages:
   - reach/load Rank 3;
   - open management sheet and verify Carrier Routing panel fits/readable;
   - switch Balanced → Express → Consolidated;
   - confirm selected lane changes visibly in 3D;
   - confirm actual dispatch parcels use the selected lane;
   - let one 25s report finish and confirm all four metrics are readable.
2. Fix any P0/P1 device/readability issue before adding another major system.
3. If device verification is clean, run a Rank 3 balance/play-feel pass using real-session observations, especially Express vs Consolidated opportunity cost and outbound queue readability.
4. Only after the one-center Rank 3 loop is proven fun/readable should campus / second-center scope be reconsidered.

## 12. Non-negotiable rules

- GitHub `main` is canonical.
- Never claim untested visual/device behavior is finished.
- Contracts remain optional.
- Director diagnoses; it does not choose the solution.
- No MutationObserver band-aids for ownership bugs.
- Capital growth must remain visible and behaviorally real.
- Money/revenue mutation stays in simulation domain.
- New automation must not create fake decorative movement detached from real events.
- Avoid resource states that unintentionally make the game impossible to continue.
- Preserve save compatibility unless an explicit migration is implemented and tested.
- After meaningful changes: syntax/build → automated behavior tests → regression → Pages → device verification where required.
