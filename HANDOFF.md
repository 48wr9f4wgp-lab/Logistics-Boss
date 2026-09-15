# Logistics Boss — Development Handoff

Updated: 2026-09-15 JST  
Repository: `48wr9f4wgp-lab/Logistics-Boss`  
Canonical production baseline: GitHub `main`  
Canonical engine: **Godot 4.7.x + GDScript**

## 0. Canonical source order

For current development decisions use:

1. Current user instruction.
2. This `HANDOFF.md`.
3. `TECH_DECISION_GODOT_MIGRATION_2026-09-15.md`.
4. Current `/godot` implementation on `main`.
5. `RANK3_FULFILLMENT_CENTER.md`, `CAPITAL_PACING_V1.md`, `CAPITAL_EXPANSION_V2.md`, benchmark / UX addenda.
6. `GDD_LOGISTICS_BOSS.md` except where later title-specific decisions supersede stale FTUE / technology language.
7. Project-level `GAME_DEV_MASTER_RULES v1.3`.

The old Three.js / DOM implementation under `/docs` is **legacy reference only**. It is no longer a compatibility target and must not block Godot-side architecture, UI, rendering, input, save, balance, or content decisions.

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

## 2. Technology decision — GODOT IS CANONICAL

On 2026-09-15 the user explicitly chose to continue development in Godot and later approved retiring the old Web implementation as a production target.

Canonical technology direction:
- Godot 4.7.x Standard;
- GDScript;
- GL Compatibility renderer for mobile breadth during development;
- native iOS / Android are the production targets;
- Web export may remain as a temporary engineering preview only;
- Web limitations must not force English UI, DOM-style layout, or architecture compromises.

The migration gate has been passed. PR #20 was merged into `main` as commit `070fb9866a759a3f376cb941231a83c1a5cac3a9`.

Why Godot won:
- core logistics loop runs in the Godot domain model;
- real autonomous workers execute STORE / PICK / SHIP tasks;
- investments change both simulation and visible 3D state;
- touch orbit / pinch zoom and time controls are implemented;
- save/load is versioned and smoke-tested;
- Godot 4.7.2 import, deterministic sim smoke, full-scene runtime and Web export all pass CI;
- real iPhone visual checks show the Godot direction exceeds the old DOM / Three.js presentation ceiling.

`TECH_DECISION_GODOT_MIGRATION_2026-09-15.md` is the title-specific ADR.

## 3. Godot production architecture

Current source structure:
- `godot/domain/warehouse_sim.gd` — authoritative deterministic logistics / economy state;
- `godot/view/warehouse_view.gd` — facility, workers, parcels, touch camera;
- `godot/view/visual_pass_2.gd` — facility presentation enrichment;
- `godot/view/visual_pass_3.gd` — hero-machine, lighting, material/readability details;
- `godot/view/visual_composition_fix.gd` — real-device composition correction;
- `godot/ui/game_hud.gd` — base mobile HUD;
- `godot/ui/game_hud_ja.gd` — **canonical Japanese-first HUD**;
- `godot/persistence/save_store.gd` — Godot-specific versioned save / backup;
- `godot/icon.svg` — canonical app icon asset;
- `godot/main.gd` — composition root only.

Domain ownership rule:
- simulation owns money, parcel lifecycle, task assignment and progression mutations;
- UI / rendering consume state and events;
- rendering must not create revenue or fake operational outcomes.

## 4. Current Godot slice

Implemented:
- inbound generation;
- order generation;
- 3+ autonomous workers;
- real STORE / PICK / SHIP tasks;
- separate packing stage;
- outbound-completion-only revenue;
- BALANCED / INBOUND / SHIP operating policy switching;
- pause / 1x / 2x / 4x;
- worker / rack / speed / packing investments;
- visible workers and carried parcels;
- visible rack growth from investment;
- visible inbound / rack / outbound parcel states;
- bottleneck diagnosis;
- one-finger orbit + two-finger pinch zoom;
- autosave with temp file + backup fallback;
- Visual Pass 1–3;
- real-device composition fix;
- Japanese-first native UI;
- canonical warehouse-growth app icon.

Current icon direction:
- dark navy background;
- isometric warehouse block;
- visible parcels in the bay;
- cyan logistics flow path;
- amber upward-growth arrow;
- no text inside the icon.

## 5. Japanese UI policy

Product UI is **Japanese-first**.

Current native labels include:
- 資金
- 研究RP
- 出荷ペース
- 注文待ち
- 詰まり分析
- バランス / 入庫 / 出庫 / 投資
- 事業投資

`godot/ui/game_hud_ja.gd` uses native system-font fallback for iOS / Android / desktop CJK rendering.

Important:
- Godot Web does not provide the same reliable system-font fallback path for CJK.
- Do not reintroduce English product UI merely to satisfy Web preview limitations.
- Web preview may remain useful for geometry / camera / interaction checks, but native builds are the typography truth.

## 6. Visual North Star

The adopted North Star is the premium mobile isometric warehouse image approved in this project conversation and recorded by `VISUAL_NORTH_STAR_GODOT.md`.

Target qualities:
- dark navy industrial space;
- warm local work lights + restrained cyan emissive accents;
- readable logistics flow at phone scale;
- warehouse remains visually dominant over HUD;
- facility visibly becomes denser and more sophisticated with investment;
- workers, racks, AGV / forklift / dock assets read immediately at a glance;
- avoid toy-model emptiness, but also avoid clutter that blocks the facility.

Recent real-device correction:
- foreground truck was too dominant;
- front ceiling trusses crossed the visual focus too aggressively;
- camera was too close / low;
- composition was corrected by raising / pulling camera back, reducing foreground obstructions and demoting the truck visually.

## 7. Legacy Web policy

The old `/docs` implementation may remain in the repository for historical / behavioral reference, but:
- do not add new gameplay there;
- do not require feature parity;
- do not delay Godot work to preserve DOM or Three.js behavior;
- do not use legacy Web as the rollback target for normal development;
- old Web regression workflows may be removed once equivalent Godot tests cover the same product risks.

Preserved useful reference concepts from the old build:
- measured Capital pacing;
- optional contracts;
- diagnostic-only Director;
- four-condition major-investment gate;
- Rank 3 routing tradeoffs;
- historical iPhone UX findings.

## 8. Major design rules preserved across the engine change

- Contracts are optional.
- Director diagnoses; it does not choose the solution.
- Player decisions are low-frequency operating / capital decisions, not avatar micromanagement.
- No permanent “correct route”.
- Negative Before/After results are allowed and should be shown honestly.
- Resource states must not accidentally make the game impossible to continue.
- Decorative automation detached from real events is not acceptable.
- Save formats remain versioned and engine-specific until an explicit migration is designed.
- New UI is game-native, not a DOM layout copied into Godot.

Every major investment must still satisfy:
1. visible 3D change;
2. real logistics behavior or capacity change;
3. measurable Before/After;
4. ability to create or reveal another bottleneck.

## 9. Balance reference

Legacy Web numbers are **reference only**, not automatic Godot constants.

The old audited mid-game milestone times were roughly:
- 8.5 min;
- 12.0 min;
- 11.1 min;
- 7.5 min;

with a desired 7–15 minute band.

Do not transplant values blindly. Measure real Godot task cadence and rebuild pacing around the perceived loop.

## 10. Immediate next actions

1. Continue real-device Visual Pass against the approved North Star.
2. Port the progression / Capital framework into Godot domain modules without recreating the old Web monolith.
3. Add Before/After measurement in Godot from real domain events.
4. Port visible automation in order of player value: forklift / AGV / sorter → workforce / hall → truck waves → AS/RS.
5. Rebuild Rank 3 promotion and Carrier Routing as Godot-native systems.
6. Add audio, VFX and haptics after the core investment loop is stable.
7. Establish native iOS build / signing / device-install pipeline before Release Candidate.
8. Remove legacy Web CI only after equivalent Godot coverage exists.

## 11. Non-negotiable engineering rules

- GitHub `main` is canonical.
- Never claim uncompiled code works.
- Never claim device visuals are complete without device verification.
- Domain simulation owns money, parcel lifecycle and progression mutations.
- Rendering/UI consume state and events; they do not create revenue independently.
- Avoid large God scripts becoming monoliths; extract responsibilities before feature growth.
- After meaningful changes: parse/build → automated behavior test → runtime verify → regression → device check where required.
- Godot is now the production engine. Do not return to the legacy Web architecture unless the user explicitly reverses this decision.
