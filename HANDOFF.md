# Logistics Boss — Development Handoff

Updated: 2026-09-15 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Canonical engine: **Godot 4.7.2 Standard + GDScript**
Current stage: Functional Build / vertical-slice maturation. **Not release-ready.**

## Canonical source order

For current decisions use, in order:

1. Current explicit user instruction.
2. Current `main` implementation under `/godot`.
3. This `HANDOFF.md`.
4. `TECH_DECISION_GODOT_MIGRATION_2026-09-15.md`.
5. `VISUAL_NORTH_STAR_GODOT.md`.
6. Later title-specific specs such as `RANK3_FULFILLMENT_CENTER.md`, `CAPITAL_PACING_V1.md`, `CAPITAL_EXPANSION_V2.md`, benchmark / UX addenda.
7. `GDD_LOGISTICS_BOSS.md` except where superseded by later title-specific decisions.
8. Project-level `GAME_DEV_MASTER_RULES v1.3`.

If documentation conflicts with current Godot code, current Godot code wins. The old `/docs` Three.js/DOM implementation is **legacy reference only** and is not a compatibility target.

## 1. Product purpose / finished form

Logistics Boss is a mobile-first 3D logistics-management / automation-observer game.

Canonical loop:

`observe flow → find bottleneck → choose investment / operating decision → autonomous logistics reacts → measure result → new bottleneck emerges → reinvest at larger scale`

Player fantasy:
- operate and grow a logistics center;
- allocate capital and operating priorities;
- watch workers/machines/goods physically react;
- solve bottlenecks without manually carrying parcels or driving vehicles.

Finished-product quality target includes:
- visible autonomous logistics;
- strong game feel when goods move / ship / upgrade;
- FTUE that teaches observation and consequence, not one prescribed correct answer;
- compact mobile UI with the 3D facility visually dominant;
- visible facility growth from investment;
- progression, save, audio, VFX, haptics, analytics, performance and QA suitable for public release.

## 2. Technology / libraries / external services

Production:
- Godot `4.7.2` Standard;
- GDScript;
- GL Compatibility renderer;
- portrait-first viewport `390x844`;
- native iOS / Android are the intended production targets.

Engineering preview only:
- Godot Web export;
- GitHub Pages preview under `/godot-preview/`;
- preview URL: `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`.

Repository / CI:
- GitHub is canonical source control;
- `.github/workflows/godot-ci.yml` is the canonical CI;
- `.github/workflows/godot-preview-pages.yml` exports and publishes the engineering preview.

No production backend, DB, API, auth provider, SDK service or environment variables currently exist.

## 3. Major structure / important files

Production Godot:
- `godot/project.godot` — Godot config; main scene and icon binding.
- `godot/scenes/main.tscn` — root scene.
- `godot/main.gd` — composition root; creates sim/view/HUD/save; autosaves every 10s.
- `godot/domain/warehouse_sim.gd` — **authoritative domain/economy owner**.
- `godot/view/warehouse_view.gd` — base 3D facility, workers, parcels, touch orbit/pinch camera.
- `godot/view/visual_pass_2.gd` — warehouse density / equipment / industrial dressing.
- `godot/view/visual_pass_3.gd` — hero packing cell, emissive accents, rack cargo detail, vehicle readability.
- `godot/view/visual_composition_fix.gd` — real-iPhone composition correction after foreground truck/truss/camera issues.
- `godot/ui/game_hud.gd` — reusable base HUD implementation; contains historical Web fallback behavior but is **not loaded directly** by main.
- `godot/ui/game_hud_ja.gd` — **currently loaded canonical HUD**; subclasses base HUD and forces Japanese copy / CJK system-font fallback.
- `godot/persistence/save_store.gd` — versioned JSON save, temp write, backup fallback.
- `godot/tests/sim_smoke.gd` — deterministic domain smoke.
- `godot/export_presets.cfg` — Web engineering-preview export preset.
- `godot/icon.svg` — current canonical app icon asset.

Product / design docs:
- `VISUAL_NORTH_STAR_GODOT.md` — approved visual target.
- `TECH_DECISION_GODOT_MIGRATION_2026-09-15.md` — Godot canonicalization ADR.
- `HANDOFF.md` — current operational handoff.

Legacy reference only:
- `/docs/**` — old Three.js/DOM build. Do not add new gameplay there.

## 4. Implemented functions

Current Godot domain implementation:
- starting money `¥8,000`;
- inbound generation every 4s;
- order generation every 5s;
- 3 starting autonomous workers;
- STORE task: inbound → rack;
- PICK task: rack → packing queue;
- separate packing stage;
- SHIP task: packed queue → outbound;
- revenue only on real shipment completion (`BASE_SHIPMENT_VALUE = 500`);
- 1 RP every 5 completed shipments;
- rolling shipment-rate measurement;
- natural bottleneck diagnosis for inbound/rack/packing/outbound/orders;
- BALANCED / INBOUND / SHIP operating policies;
- pause / 1x / 2x / 4x;
- investments:
  - worker hire, max 7 workers;
  - rack expansion, +4 capacity per level, max 4;
  - worker speed, +15% multiplicative per level, max 4;
  - packing module, ~15% faster per level, max 4;
- save schema `1`;
- autosave / backup restore.

Current 3D / interaction:
- elevated isometric warehouse;
- inbound, storage, packing, outbound zones;
- autonomous workers visibly move between real task source/target positions;
- visible carried parcels / queue state;
- rack geometry grows with rack investment;
- forklifts / AGV / truck / conveyors / industrial dressing are present visually;
- one-finger orbit;
- two-finger pinch zoom;
- dark navy warehouse, warm task lights, cyan/orange accent language;
- Visual Pass 1–3 plus device composition correction.

Current HUD:
- 資金;
- 研究RP;
- 出荷ペース;
- 注文待ち;
- 詰まり分析;
- バランス / 入庫 / 出庫 / speed / 投資;
- management sheet with worker/rack/speed/packing investments;
- shipment / investment toast feedback.

App icon:
- `godot/project.godot` points `config/icon` to `res://icon.svg`;
- icon direction is the user-approved 4th concept: dark navy isometric warehouse + parcels + cyan logistics path + amber upward growth arrow;
- **important:** the repo asset is a vector recreation of the approved concept, not the original generated raster file pixel-for-pixel. If exact source-art fidelity is required later, import the original approved raster as source art and generate platform-specific icon sets from it.

## 5. Current implementation work / progress

Godot migration itself is complete and Godot is now canonical.

PR #20 `Adopt Godot as the canonical Logistics Boss production baseline`:
- merged;
- functional migration baseline commit: `070fb9866a759a3f376cb941231a83c1a5cac3a9`.

PR #21 `Retire legacy Web CI and make Godot CI canonical`:
- merged;
- merge commit: `d557f486d08b8c249209f21b43fea9134b47eb05`;
- removed old Web-only QA / pacing / Rank3 / readability workflows;
- canonical CI is now Godot-only;
- main Godot CI after merge completed **successfully**.

GitHub Pages automation subsequently committed the latest Godot engineering-preview export to main as:
- `524ae468b9f617d92cfdcd14f9bdcb8ece84222d` — `Publish Godot web engineering preview`.

Current visual direction has been checked on a real iPhone. Latest device-driven correction deliberately:
- pulled the camera back / raised overview feeling;
- reduced foreground truss obstruction;
- visually demoted the foreground truck;
- kept HUD and bottom navigation direction.

No current gameplay feature is mid-commit. Next work should start from `main` on a fresh feature branch.

## 6. Unimplemented / future work in priority order

P0 / next vertical-slice depth:
1. Port progression / Capital framework into Godot without rebuilding the old Web monolith.
2. Add real Before/After measurement sourced from domain events.
3. Make investment escalation materially transform the facility.
4. Re-test early/mid-game pacing in the Godot domain model rather than copying old Web numbers.

P1 / automation progression:
5. Forklift automation tied to real cargo events.
6. AGV automation tied to real cargo events.
7. Automatic sorter tied to real shipment flow.
8. Workforce expansion and hall expansion with real capacity / scene changes.
9. Truck dock / truck-wave logistics.
10. AS/RS automated storage/retrieval.

P1 / higher progression:
11. True Rank progression in Godot.
12. Rank 3 Fulfillment Center.
13. Carrier Routing tradeoffs rebuilt natively in Godot.

P2 / product polish:
14. FTUE for the Godot build.
15. Audio / music / machinery ambience / shipment feedback.
16. VFX and motion polish.
17. Native haptics.
18. Accessibility / font scaling / color readability.
19. Analytics / event taxonomy.
20. Performance profiling and device matrix.
21. Native iOS export/signing/install path, then Android packaging.
22. Store assets / submission only after explicit user approval.

## 7. Current bugs / technical issues

Known / open:
- visual quality is improved but still below final North Star; many assets are procedural primitives, not final production models;
- `warehouse_view.gd` plus layered `visual_pass_2.gd`, `visual_pass_3.gd`, `visual_composition_fix.gd` is accumulating presentation layering; before much more visual complexity, consider consolidating responsibilities rather than adding Visual Pass 4/5 indefinitely;
- `game_hud_ja.gd` relies on `SystemFont` fallback. This is appropriate for native targets but Web CJK behavior is not the typography authority;
- `game_hud.gd` still contains English/Web fallback logic because `game_hud_ja.gd` subclasses it. Do not mistake the base file for the active product UI;
- save schema is only version `1`; future progression expansion needs explicit migration policy before schema changes;
- no native iOS build/signing path has been verified yet;
- no performance budget / low-end device benchmark has been established;
- no analytics, crash reporting or telemetry yet.

Closed / verified:
- Godot 4.7.2 import/parse succeeds;
- deterministic sim smoke succeeds;
- full scene runtime smoke succeeds;
- Web engineering-preview export succeeds;
- main Godot CI after canonicalization succeeds;
- Godot became canonical after real iPhone visual checks.

## 8. Important design decisions and reasons

**Godot is canonical; old Web is legacy.**
Reason: the product now needs scene hierarchy, animated autonomous agents, visible facility growth, VFX/audio/haptics, mobile input and native packaging. DOM + Three.js was becoming a presentation/coordination ceiling.

**Domain simulation owns the economy.**
Reason: money and parcel lifecycle must have one source of truth. UI/rendering consume state/events and must never create revenue independently.

**Player solves the bottleneck; Director does not prescribe the answer.**
Reason: the game is an operations/capital decision game, not an instruction-following checklist.

**Contracts remain optional.**
Reason: mandatory contract gates previously contradicted free-form progression.

**Every major investment must pass four conditions:**
1. visible 3D change;
2. real logistics behavior/capacity change;
3. measurable Before/After;
4. can create or reveal another bottleneck.

**Japanese-first production UI.**
Reason: user readability and target product. Web preview limitations must not drive English product copy.

**Visual North Star is canonical.**
Reason: prevent incremental prototype aesthetics from becoming the final product. The target is a premium, dark industrial, stylized-isometric mobile logistics game with high readability and a warehouse-dominant composition.

## 9. Rejected ideas / changes not to make

Do not:
- return production development to Three.js/DOM unless user explicitly reverses the engine decision;
- maintain feature parity with `/docs`;
- restore mandatory-contract FTUE;
- make Director a one-tap “correct answer” button;
- auto-open/close management panels from bottleneck severity;
- use MutationObserver-style ownership hacks from the old Web implementation;
- create a single prescribed progression path;
- add decorative automation that is not driven by real sim state/events;
- award money from UI/VFX/animation callbacks;
- make players manually carry boxes or drive forklifts as the main loop;
- add meaningless waiting or resource states that stop the player from doing anything;
- copy old Web economy numbers blindly into Godot;
- keep stacking ad-hoc visual pass scripts forever without refactoring scene/presentation responsibilities;
- claim “fixed/complete” without parse/build/test/runtime/device verification as applicable.

## 10. UI / UX policy

Approved direction:
- portrait mobile first;
- warehouse is the hero; HUD must not cover the majority of the operation;
- top four metrics: 資金 / 研究RP / 出荷ペース / 注文待ち;
- compact diagnostic “詰まり分析” directly below metrics;
- persistent thumb-readable bottom controls;
- management decisions use progressive disclosure rather than dense card walls;
- Japanese critical text must be readable at normal iPhone distance;
- avoid 9–10px-equivalent critical text;
- cause/effect feedback such as `出荷 +¥500` should be short and satisfying;
- dark navy industrial environment, warm practical lights, restrained cyan tech accents, orange safety/equipment accents;
- real-device screenshot is the acceptance gate for composition changes.

Visual North Star specifics are in `VISUAL_NORTH_STAR_GODOT.md`.

## 11. DB / API / auth / env / persistence

There is currently:
- no database;
- no remote API;
- no authentication;
- no backend service;
- no environment-variable dependency;
- no cloud save;
- no analytics SDK.

Local Godot persistence:
- primary: `user://logistics_boss_godot_save.json`;
- temp: `user://logistics_boss_godot_save.tmp`;
- backup: `user://logistics_boss_godot_save.bak`;
- domain save schema: `1`.

Do not introduce external services, paid contracts, Store submission, production analytics accounts or other irreversible/external-impact actions without explicit user approval.

## 12. Exact next task

Start from current `main` and create a fresh feature branch for the **Godot Capital / Measurement foundation**.

Recommended first slice:
1. inspect `warehouse_sim.gd` and extract/define a clean investment model instead of letting it grow into a monolith;
2. add a domain-owned 25s Before/After measurement service or module using real shipment / queue / revenue events;
3. expose result data to HUD without letting UI mutate economy;
4. port only the first automation investment that clearly passes the four-condition gate (forklift is the leading candidate);
5. make its purchase visibly change 3D and actually alter STORE throughput;
6. add deterministic tests for purchase, persistence, real logistics events and revenue ownership;
7. run Godot CI: import/parse → sim smoke → full scene runtime → engineering-preview export;
8. only after automated green, do a real-iPhone visual/interaction check.

Before adding more feature depth, it is also reasonable to refactor presentation layering (`visual_pass_2`, `visual_pass_3`, composition fix) into clearer facility/detail/composition responsibilities if the next visual change would otherwise create another ad-hoc pass.

## 13. Branch / commit / work state

Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`

Important recent commits:
- `070fb9866a759a3f376cb941231a83c1a5cac3a9` — Godot adopted as canonical baseline (PR #20).
- `d557f486d08b8c249209f21b43fea9134b47eb05` — canonical Godot CI + legacy Web CI retirement (PR #21).
- `524ae468b9f617d92cfdcd14f9bdcb8ece84222d` — latest generated Godot Web engineering-preview publish before this handoff refresh.

PR status:
- PR #20 merged.
- PR #21 merged.
- no active feature PR is required to resume; create a new branch from current `main`.

Worktree / uncommitted state:
- all changes performed in this ChatGPT session were committed to GitHub;
- no known GitHub-side uncommitted changes;
- a user's separate local PC worktree cannot be inspected from this environment, so local uncommitted changes are **unknown**, not assumed absent.

CI status:
- canonical `Logistics Boss Godot CI` on main commit `d557f486...` completed **successfully**;
- that CI verifies Godot version/setup, project import/parse, deterministic domain smoke, full-scene runtime, Web engineering-preview export and artifact generation.

## Non-negotiable engineering operating rules

- GitHub `main` is canonical.
- Read current code before changing it.
- Use branch/PR for meaningful implementation changes.
- Do not claim completion without actual verification.
- Priority order for failures: cannot launch → cannot control → cannot progress → economy/progression defect → UX/visual polish.
- After meaningful changes: parse/build → automated test → runtime verify → regression → real-device check when visual/input behavior matters.
- Refactor responsibilities before creating giant Godot scripts.
- Preserve the core loop: observe → diagnose → decide → system reacts → measure → reinvest.
