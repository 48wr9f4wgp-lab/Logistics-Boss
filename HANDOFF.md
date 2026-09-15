# LOGISTICS BOSS — Development Handoff

Updated: 2026-09-15 JST
Repository: `48wr9f4wgp-lab/Logistics-Boss`
Canonical branch: `main`
Canonical engine: **Godot 4.7.2 Standard + GDScript**
Current stage: **Functional Build / Vertical Slice maturation**. Not release-ready.

## 1. Canonical source order

Use, in order:
1. current explicit user instruction;
2. current `main` implementation under `/godot`;
3. this `HANDOFF.md`;
4. title-specific ADR / GDD / Art Bible / confirmed specs;
5. project-level `GAME_DEV_MASTER_RULES`.

`/docs/**` old Three.js/DOM gameplay is legacy reference only. Do not add new production gameplay there.

## 2. Product / core loop

LOGISTICS BOSS is a portrait mobile 3D logistics-management / automation-observer game.

Canonical loop:

`物流を観察 → ボトルネック発見 → 投資 / 運用判断 → 作業員・設備が自律反応 → 出荷量 / 収益 / 詰まりが変化 → 結果測定 → より大きな再投資`

The player is the logistics-center owner / operations manager. Manual parcel carrying or forklift driving is not the main loop.

Finished-form requirements include:
- physical flow: inbound → storage → pick → pack → ship;
- autonomous workers / forklifts / AGV / sorter / ASRS / trucks;
- visible facility growth;
- solving one bottleneck reveals another;
- diagnosis shows what is bad but does not prescribe what to buy;
- measurable Before/After for major investments;
- FTUE, progression, save, audio, VFX, haptics, analytics, performance and QA before public release.

## 3. Technology / delivery

Production:
- Godot `4.7.2` Standard;
- GDScript;
- GL Compatibility;
- portrait-first `390x844`;
- native iOS / Android final targets.

Engineering preview only:
- Godot Web export;
- `https://48wr9f4wgp-lab.github.io/Logistics-Boss/godot-preview/`.

GitHub:
- `.github/workflows/godot-ci.yml` — parse/import, domain smoke, economy pacing, Japanese glyph smoke, visual readability smoke, full-scene runtime, Web export;
- `.github/workflows/godot-preview-pages.yml` — preview export/publish.

No production backend, DB, auth, cloud save, analytics SDK, crash reporting, IAP, Store integration or environment variables yet.

## 4. Important production files

- `godot/project.godot` — project config / icon / viewport.
- `godot/scenes/main.tscn` — root scene.
- `godot/main.gd` — composition root; creates sim/view/HUD/save; autosaves.
- `godot/domain/warehouse_sim.gd` — **authoritative logistics/economy owner**.
- `godot/domain/capital_catalog.gd` — investment types / cost / max state.
- `godot/domain/flow_measurement.gd` — 25-second Before/After domain measurement.
- `godot/view/warehouse_view.gd` — base facility / workers / parcels / camera.
- `godot/view/forklift_automation_view.gd` — real Forklift Automation presentation driven by domain state.
- `godot/view/visual_pass_2.gd`, `visual_pass_3.gd` — industrial presentation layers.
- `godot/view/visual_composition_fix.gd` — real-device composition/readability correction; currently enforces open-top cutaway by hiding obstructive roof trusses/lights.
- `godot/ui/game_hud.gd` — reusable base HUD, not loaded directly.
- `godot/ui/game_hud_ja.gd` — **canonical active Japanese HUD**.
- `godot/assets/fonts/MPLUS1p-Regular.ttf` — embedded Japanese UI font; OFL license stored beside it.
- `godot/persistence/save_store.gd` — atomic JSON save + backup fallback.
- `godot/tests/sim_smoke.gd` — domain smoke.
- `godot/tests/economy_pacing_report.gd` — deterministic balance regression / report.
- `godot/tests/font_smoke.gd` — Japanese glyph coverage.
- `godot/tests/visual_readability_smoke.gd` — open-top / obstruction regression.
- `godot/icon.svg` — current canonical icon.

## 5. Current domain implementation

New-game defaults after Economy Balance v1:
- money: `¥5,000`;
- workers: `3`;
- rack capacity: `8`;
- inbound cadence: `2.8s`;
- order cadence: `3.0s`;
- shipment value: `¥500`;
- RP: +1 every 5 completed shipments;
- packing base time: `3.0s`.

Tasks:
- STORE: inbound → rack;
- PICK: rack → packing;
- packing: independent processing stage;
- SHIP: packed → outbound;
- revenue only on real shipment completion.

Policies / speed:
- BALANCED / INBOUND / SHIP;
- Pause / 1x / 2x / 4x.

Standard investments:
- worker hire: `¥3,500` first, max 7 workers;
- rack expansion: `¥2,500` first, +4 capacity, max Lv4;
- worker speed: `¥4,000` first, ×1.15 per level, max Lv4;
- packing: `¥4,500` first, ×0.85 time per level, max Lv4.

Major automation:
- Forklift Automation: `¥20,000`, one-time;
- executes real inbound→rack STORE throughput with `3.2s` cycle;
- its 3D vehicle appears/moves only after unlock and follows real forklift domain activity;
- domain reservation prevents rack overbooking.

## 6. Capital measurement / balance state

`flow_measurement.gd` owns 25-second Before/After measurement sourced from real domain state/events.
Metrics include:
- shipments/min;
- revenue/min;
- average inbound queue;
- average packing queue;
- average outbound queue.

Latest deterministic Economy Balance v1 measurements:

Clean no-investment 5-minute baseline:
- `79` shipments;
- `15.8 shipments/min`;
- `¥39,500` earned;
- ending bottleneck: **inbound**.

Forklift target from clean start when saving for it:
- price `¥20,000`;
- affordable at about `119.1s` / `30 shipments`.

Same warmed-state 120-second comparisons:
- extra worker: `31 → 41` shipments, `+10`, `+¥5,000`, bottleneck moves to packing;
- worker speed: `31 → 36`, `+5`, `+¥2,500`;
- Forklift: `31 → 39`, `+8`, `+¥4,000`; inbound avg `10.65 → 5.66`, next bottleneck becomes packing;
- rack: inbound avg `10.65 → 8.43`; capacity/buffer investment, not guaranteed immediate revenue gain;
- packing bought while inbound is the current bottleneck: no shipment gain, intentionally demonstrating that the wrong investment can be inefficient.

Measured intended progression chain:
- **inbound bottleneck**
- Forklift → `+8` shipments / 120s
- bottleneck becomes **packing**
- Packing upgrade → `40 → 46`, `+6` / 120s
- bottleneck returns to **stable**.

`economy_pacing_report.gd` now fails CI if this core causal sequence regresses.

## 7. Persistence

Save schema: **2**.

Primary files:
- `user://logistics_boss_godot_save.json`;
- temp: `user://logistics_boss_godot_save.tmp`;
- backup: `user://logistics_boss_godot_save.bak`.

Schema 1 saves migrate to schema 2; legacy saves default Forklift Automation to locked.

Important: Economy Balance v1 changes **new-game starting cash only**. Existing saves retain their saved money/progression. New logistics cadence / processing constants apply when the updated build runs.

Do not reset/delete the user's save without explicit approval.

## 8. Current 3D / mobile presentation

Visual direction:
- dark navy industrial;
- warm local task lights;
- cyan tech accents;
- orange safety/logistics accents;
- stylized premium mobile isometric warehouse;
- warehouse remains the hero behind compact HUD.

Real-iPhone-driven fixes already merged:
- camera orbit sensitivity reduced and frame-rate-independent smoothing added;
- touch deadzone and input spike clamp added;
- pinch sensitivity reduced;
- Japanese missing-glyph issue fixed by embedding M PLUS 1p rather than relying on `SystemFont`;
- obstructive roof trusses / roof light bars removed from the gameplay camera, establishing an **open-top cutaway** presentation;
- shipment toast reduced;
- bottom dock raised above the iPhone home indicator;
- `Warehouse安定運転` corrected to Japanese `安定運転`.

Automated visual-readability smoke verifies roof geometry cannot reappear as foreground obstruction. Final composition acceptance still requires real-device screenshots.

## 9. Recent merged work

- PR #20 — Godot canonical production baseline.
- PR #21 — Godot-only canonical CI / legacy Web CI retirement.
- PR #22 — Capital / 25s Before-After measurement / real Forklift Automation / save schema 2.
- PR #23 — mobile camera smoothing and sensitivity correction.
- PR #24/#25 — reproducible embedded Japanese font + Japanese rendering regression test.
- PR #26 — warehouse open-top visibility + portrait HUD readability corrections.
- PR #27 — deterministic economy pacing harness.
- PR #28 — Economy Balance v1: meaningful throughput headroom and bottleneck progression.

PR #28 product commit:
- `a2f0b1659430bae53d884eff871569918a8938f3` — `Rebalance early logistics capacity and first automation`.

Current main also contains automated preview-publish commits; therefore the literal main HEAD may be a later bot commit than the product commit above.

After PR #28:
- main Godot CI passed;
- Preview Pages publish passed.

## 10. Hard design / implementation rules

- Domain simulation owns money, logistics state and investment effects. UI/rendering never award revenue.
- Player solves bottlenecks; diagnostics do not prescribe the purchase.
- Major investments must provide: visible 3D change + real logistics change + measurable Before/After + ability to reveal another bottleneck.
- Do not add decorative automation disconnected from real sim state/events.
- Do not make manual forklift driving / parcel carrying the main loop.
- Do not create meaningless waits or resource dead-ends.
- Do not blindly copy old Web economy values.
- Do not call unverified work complete.
- Before adding another `visual_pass_x`, consolidate/refactor presentation responsibilities instead.

## 11. Known open issues / product gaps

- 3D assets remain mostly procedural primitives; visual quality is below final North Star.
- presentation is still layered across `warehouse_view`, `visual_pass_2`, `visual_pass_3`, and `visual_composition_fix`; further large visual expansion should first clarify/consolidate responsibilities.
- rack expansion currently improves buffer pressure but can slightly reduce short-window shipments because workers may spend extra time filling the larger rack; monitor as progression grows.
- no FTUE yet for the current Godot loop.
- no audio / music / final VFX / haptics.
- no true rank progression / hall expansion yet.
- no analytics / crash reporting / telemetry.
- no native iOS export/signing/install path verified yet; current iPhone checks use Web engineering preview.
- no Android packaging/device matrix yet.
- no performance budget / low-end device benchmark yet.

## 12. Exact next work

First gate:
- real-iPhone check of the latest Web preview after PR #26/#28, specifically confirming the open-top warehouse no longer blocks workers/racks/parcels and the raised bottom dock/toast remain comfortable.

Development can continue in parallel without resetting the user's save.

Next implementation slice should be **the next real automation/progression decision based on measured post-upgrade bottlenecks**, not a decorative feature. Before choosing AGV/sorter blindly:
1. extend the deterministic progression harness beyond Forklift → Packing;
2. identify the next sustained bottleneck after the packing upgrade;
3. choose the equipment whose real logistics responsibility solves that bottleneck (AGV, sorter, dock/truck, etc.);
4. add it as a domain-owned investment/effect;
5. connect dedicated 3D presentation to that real state;
6. require measurable Before/After and a new downstream bottleneck;
7. persist it with explicit schema migration if save structure changes;
8. run full CI and then real-device verification.

Before major new visual complexity, refactor presentation layering rather than creating `visual_pass_4/5/...`.

## 13. Verification state

Verified automated gates on current product state:
- Godot 4.7.2 parse/import: PASS;
- domain sim smoke: PASS;
- deterministic economy pacing/progression: PASS;
- Japanese glyph coverage: PASS;
- warehouse visual readability: PASS;
- full scene runtime smoke: PASS;
- Web engineering-preview export: PASS;
- Preview Pages publish: PASS.

Still requires human/device acceptance:
- latest open-top warehouse composition on iPhone;
- final native iOS typography/input/performance once native packaging exists.
