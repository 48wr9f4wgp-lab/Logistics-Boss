# Logistics Boss — Development Handoff

Updated: 2026-09-14 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Audited code baseline before this HANDOFF-only commit: `e75e1e694efe13a163a4452e6575b3bb0902ff16`

> **Source-of-truth order for the next chat**
> 1. Current `main` implementation
> 2. Title-specific current specs: `CAPITAL_EXPANSION_V1.md`, `UX_ERGONOMICS_PASS_2026-09-14.md`, benchmark addendum
> 3. `GDD_LOGISTICS_BOSS.md`
> 4. Project-level `GAME_DEV_MASTER_RULES v1.3`
>
> `GDD_LOGISTICS_BOSS.md` still contains older Rank 1 FTUE / prescribed-action text that conflicts with the newer freedom/capital direction. **Do not reintroduce those stale rails just because the text still exists.** Current code + newer title-specific specs win.

## 1. Purpose / intended finished product

**Logistics Boss** is a mobile-first 3D logistics management / automation-observer game.

The player does **not** manually carry boxes or control an avatar. The fantasy is:

`observe flow → identify constraint → invest / change operations → autonomous workers & equipment react → throughput/revenue changes → measure result → reinvest at a much larger scale`

Target finished experience:
- begin as a tiny manual depot;
- earn aggressively increasing cash;
- buy visibly meaningful equipment;
- watch the facility become faster/larger/more automated;
- solved bottlenecks expose new bottlenecks downstream;
- grow toward conveyors, sorters, forklifts/AGVs, automated storage, truck yards, multiple halls / logistics centers;
- the player chooses **what to improve first**; the app shows state and consequences, not a single correct path.

The differentiator is **visible autonomous 3D logistics + capital escalation + measurable ROI**, not spreadsheet-only management and not idle waiting.

Current stage: Vertical Slice / Functional Build. Not release-ready.

## 2. Technology / libraries / external services

Current production path is intentionally simple:
- Static HTML / CSS / vanilla JavaScript (ES modules)
- Three.js `0.186.0` from jsDelivr CDN
- `@dimforge/rapier3d-compat` `0.20.0` from jsDelivr CDN
- GitHub repository + GitHub Actions
- GitHub Pages deploying `main/docs`
- PWA-style manifest / Apple Home Screen icon
- iPhone Safari / Home Screen web app is primary device test target

No npm, bundler, TypeScript, backend, database, account system, analytics service or app-store wrapper exists yet.

Important: Three.js is still the correct current engine **until an actual scale/native blocker appears**. Do not migrate to Godot/Unity/PlayCanvas merely for preference.

## 3. Current directory structure / important files

```text
/
├─ README.md
├─ GDD_LOGISTICS_BOSS.md
├─ CAPITAL_EXPANSION_V1.md
├─ BENCHMARK_LOGISTICS_BOSS_2026-09-13.md
├─ BENCHMARK_CAPITAL_LOOP_ADDENDUM_2026-09-14.md
├─ UX_ERGONOMICS_PASS_2026-09-14.md
├─ RANK2_SYSTEMS_PASS_PLAN.md
├─ HANDOFF.md
├─ .github/
│  └─ workflows/
│     ├─ qa.yml
│     └─ readability-pass-3.yml   # old one-shot patch workflow; trigger is path-limited
└─ docs/
   ├─ index.html
   ├─ styles.css
   ├─ readability.css
   ├─ ux.css
   ├─ focus.css
   ├─ ftue2.css
   ├─ capital.css
   ├─ ergonomics.css
   ├─ insight-stability.css
   ├─ manifest.webmanifest
   ├─ apple-touch-icon.png
   ├─ health.html
   ├─ .nojekyll
   ├─ src/
   │  ├─ main.js
   │  ├─ sim.js
   │  ├─ scene.js
   │  ├─ ui.js
   │  ├─ freedom.js
   │  ├─ ftue2.js
   │  ├─ capital-model.js
   │  ├─ capital.js
   │  ├─ ergonomics.js
   │  └─ insight-stability.js
   └─ tests/
      ├─ progression-smoke.mjs
      └─ ergonomics-smoke.mjs
```

Critical responsibilities:
- `sim.js`: domain state, workers, parcel lifecycle, contracts, Rank 2 facilities, save schema, time/update loop.
- `scene.js`: Three.js rendering, warehouse geometry, workers/boxes, camera/touch, FLOW visuals, decorative Rapier overflow.
- `ui.js`: legacy/core HUD + policies + contracts + Rank 2 UI; currently contains some stale FTUE/autotoggle logic.
- `freedom.js`: non-linear Rank 1 Warehouse-rating progression.
- `capital-model.js`: investment definitions, nonlinear costs, commercial revenue tiers.
- `capital.js`: capital UI, purchases, revenue uplift, 25 s before/after investment measurement.
- `ergonomics.js`: mobile bottom-sheet behavior, investment affordance, observation/result pulse, top metric override.
- `ftue2.js`: overrides old Rank 1 prescribed FTUE into freedom/sandbox language.
- `insight-stability.js`: current guard against Director panel auto-open/close / 契約-button flicker.

## 4. Implemented features

### Core simulation
- Inbound → rack → pick → pack → outbound parcel flow.
- Autonomous workers and task assignment.
- Rank 1 policies: Balanced / Inbound / Ship.
- Pause / 1x / 2x / 4x.
- Cash only after successful shipment.
- Orders, inbound arrivals, packing queue, outbound queue.
- Bottleneck ratios for inbound / rack / orders / packed output.
- Recovery-first congestion; no hard game-over.

### Contracts / research
- Optional 3-choice contract offers: shipping, inbound-clean, throughput.
- Contract cash/RP/reputation rewards.
- Milestone RP rewards.
- Research perks: Smart Dispatch, Standardized Packing, High-value Contracts.

### Freedom progression
Rank 1 Warehouse rating can increase through multiple routes instead of a mandatory contract rail:
- cumulative shipped volume;
- throughput;
- stable operation time;
- optional contracts.

Warehouse unlock target remains rating 8.

### Rank 2 systems
- Rank 2 `Warehouse` unlocks 5-worker operation.
- Five staffing presets: 3/1/1, 2/2/1, 1/3/1, 2/1/2, 1/2/2.
- 30 simulated-second staffing reassignment lock.
- Three one-of-two structural zones:
  - Intake: Double Dock vs Buffer Yard
  - Storage: Fast Pick Rack vs High Density Rack
  - Packing: Parallel Pack Line vs Fast Pack Cell
- All affect simulation; scene has corresponding visible structures.
- 20-second Rank 2 facility decision-impact report.
- Fulfillment Center readiness UI exists (zones/contracts/throughput) but **Rank 3 gameplay does not**.

### Capital Expansion v1
Current primary product direction:
- Rack Wing: costs `1,000 / 4,500 / 30,000 / 250,000`
- Packing Module: `1,600 / 7,000 / 50,000 / 400,000 / 4,000,000`
- Handling/Route Improvement: `2,000 / 8,500 / 60,000 / 500,000 / 5,000,000`
- Conveyor Spine: `3,500 / 18,000 / 120,000 / 1,000,000`

Effects are real simulation effects using existing upgrade state:
- rack capacity + visible rack growth;
- pack-time reduction + visible modules;
- movement-speed increase + visible route/lane expansion;
- automatic inbound→rack conveyor movement.

Commercial tiers based on invested equipment assets increase parcel revenue:
`¥120 → ¥200 → ¥500 → ¥1,200 → ¥3,000 → ¥8,000`.

After investment, `capital.js` compares a pre-purchase 25 s window with a post-purchase 25 s window and reports:
- shipments/min;
- revenue/min;
- open orders;
- inbound queue;
- rack utilization;
- rough payback time.

Negative outcomes are intentionally shown; do not fake positive ROI.

### 3D / presentation
- Low-poly warehouse, racks, stations, parcels, workers.
- Cutaway/dollhouse warehouse shell to avoid structural occlusion.
- FLOW overlay / route cues.
- Touch orbit + pinch zoom; no joystick.
- Observation mode.
- Visible facility growth for several current upgrades/facilities.
- Rapier used only for incidental overflow/physical chaos; core economy does not depend on physics.

### Mobile UX
- Bottom thumb-zone compact controls.
- Investment entry point in bottom row; affordable equipment gets a subtle green affordance.
- Management is a bottom sheet, not a full-screen mode.
- Sheet does not auto-close after purchases.
- Downward handle gesture / tap closes sheet.
- Purchase measurement can continue while watching the warehouse; compact result pulse remains visible.
- Safe-area-aware PWA layout.
- Frequent touch targets targeted around 44–48 CSS px.

### Persistence / build
- localStorage save key: `logistics_boss_save`
- save schema: `3`
- periodic save + pagehide/visibility save
- GitHub Actions static QA + Node smoke tests
- GitHub Pages deploy from `main/docs`

## 5. Currently in progress / progress state

### A. Bottleneck Director / 契約-toggle stability — **latest active bugfix**
User reported:
1. Director frame flickered as bottleneck severity changed.
2. After the first fix, when collapsed, the **契約 button itself** flickered as if `契約 ↔ 閉じる` were fighting.

Current main now has `insight-stability.js` using DOM state as the authority and restoring the user-preferred compact state after `ui.render()`.

**Status:** code committed, static QA success, Pages deploy success, but the final `契約` flicker fix has **NOT yet been re-verified on the user's iPhone**.

Important architectural cause still present: `ui.js` itself retains severity-driven auto open/close logic and a private `insightCompact` flag, while `insight-stability.js` tries to override it. This is technical debt even if the visible flicker is now hidden.

### B. Capital loop
Capital Expansion v1 is implemented and functional, but product depth is only the first tier. It has not yet reached the intended “massive logistics empire” scale.

### C. Human-factors pass
UX/ergonomics pass is implemented. Further user testing should happen only after obvious code-side friction is audited first.

## 6. Unimplemented / next work in priority order

### P0 — stabilize existing interaction before asking user to test again
1. **Remove the root Director state conflict** from `ui.js` rather than stacking another observer workaround.
   - delete severity-triggered `setInsightCompact(true/false)` from render;
   - make panel open/closed state user-controlled, single-source;
   - align `updateInsightToggle()` with actual panel state;
   - remove `lastDirectorSeverity` if no longer needed;
   - simplify/delete `insight-stability.js` after direct fix if safe.
2. Add a regression test that repeatedly changes severity and renders while collapsed, asserting the panel stays collapsed and button label never alternates.
3. Deploy, then iPhone verify the left-top panel for 20–30 s.

### P1 — clean stale/contradictory FTUE/UI code
4. Remove old Rank 1 prescribed-step logic still living in `ui.js` (`STEP 1/3`, “まず契約を選ぼう”, one-tap recommendations) instead of relying on `ftue2.js` to override it after render.
5. Update `GDD_LOGISTICS_BOSS.md` and `.github/workflows/qa.yml` so QA no longer requires stale prescriptive FTUE strings.
6. Preserve the current design rule: app reports **goal/state/diagnosis**, player chooses solution.

### P1 — Capital Expansion v2 / product depth
7. Tune first-session economy from real play data: first meaningful investment timing, ROI readability, next-purchase anticipation.
8. Add new physically distinct capital categories, not more invisible multipliers. Priority candidates from current spec/benchmarks:
   - forklift / pallet handling;
   - sorter;
   - AGV fleet;
   - automated rack / AS-RS;
   - property / hall expansion;
   - truck dock / truck waves;
   - multi-building logistics campus / second center.
9. Every new major purchase must satisfy all four:
   - visible 3D change;
   - actual simulation behavior change;
   - measurable before/after result;
   - creates/reveals a new bottleneck / new desire to invest.

### P1 — actual Rank 3 gameplay
10. Implement Fulfillment Center gameplay. Current UI says it is the next stage, but there is no true Rank 3 state/rank yet.
11. First Rank 3 layer should likely be conveyor/sorter routing packages with mobile-friendly staged choices, **not** desktop-style free-form belt drawing.

### P2 — production engineering
12. Refactor oversized files before complexity explodes (`scene.js` ~39 KB, `sim.js` ~35 KB, `ui.js` ~24 KB).
13. Introduce proper unit/E2E/browser regression tooling when migration cost is justified (Vitest/Playwright were recommended; not installed yet).
14. Add performance budgets/profiling for worker/equipment scale.
15. Add audio/game-feel/haptics pass beyond current light vibration feedback.
16. Add analytics only after product proof / closed testing.
17. Decide native wrapper/engine only when Store/native SDK/performance needs are real.
18. Implement real offline support if still required: there is currently **no service worker**, and Three/Rapier load from CDN, so GDD's “offline” intent is not fully satisfied.

## 7. Current bugs / technical risks

### Known / unverified
- **Director 契約-button flicker:** latest fix deployed but not yet iPhone-confirmed.

### Architectural debt
- `ui.js` and `insight-stability.js` both influence Director compact/open state. Single-source state is required.
- `ui.js` still contains obsolete prescriptive FTUE logic while `ftue2.js` post-processes/neutralizes it. This is fragile and makes QA misleading.
- `qa.yml` still explicitly greps for stale Rank 1 FTUE strings, so “QA success” does not mean the latest design architecture is clean.
- `capital.js` mutates `sim.state.upgrades` and money directly, then calls `setPolicy()` mainly to mark save dirty. This works but should become a simulation-domain purchase API before capital systems expand significantly.
- Commercial revenue uplift is applied in `capital.js` by listening to shipment events after `sim.js` has already applied base revenue. Functional, but cross-module economy ownership is split.
- GDD calls the simulation deterministic, but inbound/order/contract generation uses `Math.random`; treat deterministic-domain intent as “physics does not own economy”, not true replay determinism.
- Static CDN dependencies + no service worker mean no guaranteed offline launch.
- `main` is currently unprotected.
- Legacy one-shot `.github/workflows/readability-pass-3.yml` remains; it is path-triggered and inert unless edited, but should not be reused as the normal development mechanism.

## 8. Important design decisions and why

### Observer-management, not manual controls
The product originally explored more direct operation, but the stronger loop is giving instructions/investments and watching autonomous logistics react. No avatar/joystick gameplay.

### Capital amplification is the primary growth fantasy
The user wants to earn aggressively, spend large capital, visibly improve efficiency, then spend vastly more. Therefore equipment and facility scale—not button count—is the core progression reward.

### Visible effect + measured effect
A purchase must look different in 3D **and** provide operational evidence. This avoids “did that upgrade even do anything?” and turns ROI into gameplay.

### Freedom over prescribed rails
No “next press this button” FTUE. Contracts are optional. Rank 1 rating has multiple sources. Director should diagnose, not choose the solution.

### Staged logistics packages instead of free-form factory editor (for now)
Benchmarks (Factorio / Builderment / shapez 2 / Satisfactory) support deep automation, but full belt editing creates mobile complexity. Current strategy is readable staged equipment choices first; free-form placement is deferred.

### Three.js + deterministic-ish domain state + decorative Rapier
Three.js gives rapid mobile/PWA iteration. Simulation state is kept separate from rendering. Rapier is intentionally non-authoritative so physics chaos cannot corrupt the economy/task loop.

### 3D world is primary, management is a bottom sheet
Human-factors pass keeps frequent actions in thumb reach and keeps the warehouse visible. UI should support observation, not replace it.

## 9. Rejected ideas / changes not to reintroduce

Do **not** reintroduce without a new explicit design review:
- mandatory “contract → contract → contract” progression rail;
- “今やること: X” prescriptive FTUE;
- Director one-tap “correct answer” as the default product loop;
- repeated +/- priority tapping as the main game;
- numeric Lv-up clicker gameplay with no visible machine/world change;
- passive waiting / ad-idle model as the core gameplay;
- manual first-person/avatar/joystick operation;
- full free-form conveyor editor before staged automation proves itself on mobile;
- core economy driven by nondeterministic physics;
- automatic panel opening/closing caused by volatile bottleneck severity;
- giant UI panels permanently covering the 3D warehouse;
- engine migration without a measured blocker;
- developing Logistics Boss in the old Velvet repository; this repo is canonical.

Also: do not treat one benchmark as a template. Extract principles from multiple titles.

## 10. UI / UX policy

- 3D warehouse is the visual hero.
- Top HUD = glance metrics; bottom = frequent controls.
- Frequent touch targets ≈44–48 CSS px minimum.
- Primary compact row should fit portrait iPhone without horizontal scrolling.
- Investment is a primary bottom-row action; affordable state may be signaled subtly.
- Management is a bottom sheet and must preserve world context.
- Purchase must never force-close management.
- User decides when panels open/close; volatile simulation state may change labels/colors, **not layout state**.
- Director: diagnose state/cause; do not prescribe a single solution.
- No tutorial rail. Explain controls/systems, not the required play sequence.
- Before/after metrics must use comparable windows and show negative deltas honestly.
- Equipment investment should be visually readable in the world without needing the numbers.
- Observation mode / FLOW are secondary analysis tools, not mandatory steps.

## 11. DB / API / auth / env configuration

There is currently no server-side stack.

- DB: none
- Backend API: none
- Authentication: none
- Accounts/cloud save: none
- Environment variables: none
- Analytics: none
- Monetization/IAP/ads: none
- Save: browser localStorage, key `logistics_boss_save`, schema v3
- External runtime network: jsDelivr CDN for Three.js and Rapier
- Hosting: GitHub Pages from `main/docs`
- PWA: manifest + 180x180 icon + standalone mode; no service worker

## 12. Exact first task for the next chat

**Do not add new gameplay features first. Do not ask the user to retest immediately.**

Start with the Director state architecture:

1. Fetch current `main` and confirm HEAD.
2. Inspect `docs/src/ui.js`, `docs/src/insight-stability.js`, `docs/src/main.js`, `docs/src/ftue2.js`.
3. Remove severity-driven automatic `setInsightCompact()` calls from `ui.js`.
4. Make user toggle state the only authority for Director open/closed state.
5. Ensure label changes (`契約 / 開く / 閉じる`) never mutate panel open/closed state.
6. Add automated regression coverage for repeated severity changes + repeated renders while collapsed.
7. Run static QA/smoke tests and deploy.
8. Only then ask for a short iPhone visual check of the left-top Director.

After that passes, continue Capital Expansion v2 rather than returning to FTUE rails.

## 13. Git state / branch / work status

- Repository: `48wr9f4wgp-lab/Logistics-Boss`
- Default/canonical branch: `main`
- Audited code baseline before HANDOFF doc commit: `e75e1e694efe13a163a4452e6575b3bb0902ff16`
- Baseline message: `Remove unused temporary stability helper`
- Previous functional fix commit: `0cb0bebd992e4687241a4654f429fc1a4b3468a6` — `Stop contract toggle flicker after closing insight panel`
- `main` is not branch-protected.
- Open PRs at handoff time: none.
- Static QA for baseline: success.
- GitHub Pages deploy for baseline: success.
- Final iPhone verification of the last flicker fix: **not done yet**.
- Remote GitHub has no concept of local uncommitted changes; all work performed in this session was committed to remote `main`. No local worktree was available to inspect.
- Existing old topic branches include capital/ergonomics/FTUE/Rank2/readability/flicker branches. Treat them as historical unless intentionally comparing; **`main` is canonical**.

## Handoff safety notes

- Never claim a visual/mobile bug fixed until iPhone behavior is actually rechecked.
- Build/test/deploy success is not equivalent to real-device UX success.
- Before a major visual pass, RC, or major gameplay expansion, refresh benchmarks per project rules.
- Keep changes reversible; avoid destructive cleanup just to make the repository look tidy.
