# Logistics Boss — Development Handoff

Updated: 2026-09-15 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical production baseline: GitHub `main`
Active migration branch: `port/godot-vertical-slice`

## 0. Canonical source order

For current development decisions use:

1. Current user instruction.
2. This `HANDOFF.md` and `TECH_DECISION_GODOT_MIGRATION_2026-09-15.md` while the Godot migration branch is active.
3. Current `main` Web implementation as the behavioral / balance / rollback reference.
4. `RANK3_FULFILLMENT_CENTER.md`, `CAPITAL_PACING_V1.md`, `CAPITAL_EXPANSION_V2.md`, current UX / benchmark addenda.
5. `GDD_LOGISTICS_BOSS.md` except where later title-specific decisions supersede stale FTUE / technology language.
6. Project-level `GAME_DEV_MASTER_RULES v1.3`.

Do not restore stale mandatory-contract FTUE, Director one-tap answers, severity-driven panel opening, MutationObserver ownership guards, or a single prescribed progression path.

Current product rule: **the game diagnoses state and consequences; the player chooses the solution.**

## 1. Product core

Logistics Boss is a mobile-first 3D logistics management / automation-observer game.

Canonical loop:

`observe flow → find bottleneck → choose investment / operating decision → autonomous logistics changes → measure Before/After → a new bottleneck emerges → reinvest at larger scale`

Player fantasy is operating and capital allocation, not manual parcel carrying or avatar driving.

Finished-product priorities:
- visible autonomous logistics;
- meaningful capital escalation;
- multiple viable operating / investment paths;
- measurable consequences including negative tradeoffs;
- bottlenecks that move when solved;
- clear mobile UX while keeping the facility visually primary.

Current stage: Functional Build / deeper Vertical Slice maturation. **Not release-ready.**

## 2. Technology decision — GODOT MIGRATION ACTIVE

On 2026-09-15 the user explicitly chose to continue development in Godot.

The migration is deliberate and reversible:
- Godot 4.7.x Standard + GDScript;
- GL Compatibility renderer for mobile/Web compatibility;
- Godot project lives under `/godot` during the migration gate;
- current Web build under `/docs` remains intact and deployable;
- Web is the reference implementation for proven simulation behavior, pacing, Capital systems, Rank 3 routing and iPhone findings;
- do **not** delete or rewrite the Web baseline until the Godot slice wins the migration gate.

Why the decision changed from older “do not migrate engine” wording:
- product risk is no longer primarily discovering the core loop;
- future value depends increasingly on scene hierarchy, autonomous 3D motion, facility growth, VFX/audio/haptics, mobile interaction and native packaging;
- the existing DOM + Three.js management surface was still accumulating readability / responsibility cost on iPhone;
- the user explicitly approved Godot migration.

`TECH_DECISION_GODOT_MIGRATION_2026-09-15.md` is the title-specific ADR for this transition.

## 3. Web baseline — preserve as rollback/reference

Current Web stack:
- static HTML/CSS/vanilla JavaScript ES modules;
- Three.js `0.186.0`;
- Rapier compat `0.20.0`;
- GitHub Pages from `main/docs`;
- Web save key `logistics_boss_save`, schema `3`.

The latest Web gameplay includes:
- free-form Rank 1;
- Rank 2 staffing + structural zones;
- Capital automation, workforce, hall expansion, truck waves and AS/RS;
- measured capital pacing;
- persisted Rank 3 Fulfillment Center;
- Carrier Routing with Balanced / Express / Consolidated tradeoffs;
- real routing events and 3D routing visualization;
- mobile management readability pass after real-iPhone QA.

Web money/revenue remains owned by `docs/src/sim.js`; UI and visuals must not become alternate economy writers.

## 4. Active Godot branch

Branch: `port/godot-vertical-slice`
Draft PR: #20

Initial architecture:
- `godot/domain/warehouse_sim.gd` — authoritative deterministic logistics/economy state;
- `godot/view/warehouse_view.gd` — low-poly 3D facility, workers, parcels and touch camera;
- `godot/ui/game_hud.gd` — portrait-first HUD, policy/speed controls and management sheet;
- `godot/persistence/save_store.gd` — Godot-specific versioned save / backup;
- `godot/main.gd` — composition root only;
- `godot/tests/sim_smoke.gd` — headless domain smoke once a Godot executable is available.

Current Godot slice code contains:
- inbound generation;
- order generation;
- 3 autonomous workers;
- real STORE / PICK / SHIP tasks;
- separate packing stage;
- outbound-completion-only revenue;
- BALANCED / INBOUND / SHIP policy switching;
- pause / 1x / 2x / 4x;
- hire worker, rack capacity, worker speed and packing investments;
- visible workers and carried parcels;
- visible rack growth from rack investment;
- visible inbound / rack / outbound parcel counts;
- bottleneck label;
- one-finger orbit + two-finger pinch zoom;
- autosave with temp file + backup fallback.

### Godot verification status

Verified:
- repository structure exists;
- Web regression suites still pass on the migration branch;
- domain/economy ownership is separated in the new code;
- migration is isolated from existing `/docs` gameplay.

Not yet verified:
- GDScript compile in Godot 4.7.2;
- headless `godot/tests/sim_smoke.gd` execution;
- scene launch;
- worker animation / camera behavior in-engine;
- Japanese font fallback;
- performance;
- Web export;
- iPhone behavior.

**Do not call the Godot slice functional or visually complete until those checks pass.**

The current ChatGPT execution environment does not contain a Godot executable. The draft PR intentionally remains unmerged for this reason.

## 5. Godot vertical-slice migration gate

Godot becomes the production baseline only after all of the following are demonstrated:

1. `inbound → storage → pick → pack → outbound → revenue` runs continuously.
2. Three or more autonomous workers visibly execute actual simulation tasks.
3. Policy choice changes task priority within seconds.
4. A natural bottleneck appears without scripted fake congestion.
5. At least one investment removes or shifts that bottleneck.
6. Investment creates both a real domain change and a visible 3D change.
7. Revenue is awarded only from successful outbound completion.
8. Mobile portrait UI leaves the facility visually dominant.
9. Touch orbit / pinch and pause / 1x / 2x / 4x are usable.
10. Versioned save/load restores progression safely.
11. Godot Web export runs on iPhone.
12. The Godot slice is at least equal to the Web baseline on clarity, interaction feel, performance and development maintainability.

Until this gate passes, `main/docs` remains the safe rollback product.

## 6. Port order after the gate

Do not immediately recreate every Web feature.

Port in this order:
1. Core slice quality: movement, queue readability, game feel, mobile controls.
2. Director as diagnostic-only state explanation.
3. Rank 1 free progression.
4. Rank 2 staffing and one-of-two structural zones.
5. Capital measurement framework.
6. Forklift / AGV / sorter automation.
7. Workforce + hall growth.
8. Truck waves.
9. AS/RS.
10. Rank 3 promotion and Carrier Routing.
11. Audio / haptics / VFX / accessibility / analytics / performance gates.

Every major investment must still satisfy the four-condition gate:
1. visible 3D change;
2. real logistics behavior or capacity change;
3. measurable Before/After;
4. ability to create or reveal another bottleneck.

## 7. Preserved design decisions

- Contracts are optional.
- Director diagnoses; it does not choose the solution.
- Player decisions are low-frequency operating / capital decisions, not avatar micromanagement.
- No permanent “correct route” at Rank 3.
- Negative Before/After results are allowed and should be shown honestly.
- Resource states must not accidentally make the game impossible to continue.
- Decorative automation detached from real events is not acceptable.
- Save formats remain versioned and engine-specific until an explicit migration is designed.
- New Godot UI should be redesigned as game UI, not a pixel copy of the Web DOM.

## 8. Capital / balance reference from Web

Use Web numbers as **reference**, not automatic Godot constants, until Godot throughput is measured.

Web mid-game pacing was audited into roughly:
- 8.5 min;
- 12.0 min;
- 11.1 min;
- 7.5 min;

for the tested capital milestones, with a desired 7–15 minute band.

Do not transplant those values blindly if Godot task cadence differs. First match the perceived loop, then rerun deterministic pacing in the Godot domain model.

## 9. Immediate next actions

1. Open branch / PR #20 in a real Godot 4.7.2 environment.
2. Run project import / script compile.
3. Fix every parser/runtime error before visual work.
4. Run:
   `godot --headless --path godot --script tests/sim_smoke.gd`
5. Launch desktop scene and verify real worker flow + revenue ownership.
6. Tune initial camera framing and mobile UI only after it actually runs.
7. Create Web export preset and export only after the native/editor slice is stable.
8. Deploy the Godot Web slice separately from current production Pages; do not overwrite `/docs` yet.
9. Verify on iPhone.
10. Only then decide whether Godot becomes canonical production implementation and merge the migration PR.

## 10. Non-negotiable engineering rules

- GitHub is the canonical shared baseline.
- Large migration changes stay on branch/PR until verified.
- Never claim uncompiled code works.
- Never claim device visuals are complete without device verification.
- Domain simulation owns money, parcel lifecycle and progression mutations.
- Rendering/UI consume state and events; they do not create revenue independently.
- Avoid new God scripts becoming monoliths; extract responsibilities before feature growth.
- Preserve the Web baseline until the migration gate passes.
- After meaningful changes: compile/build → automated behavior test → visual/behavior verify → regression → device check where required.
