# FLOTRA — Vertical Slice v2 Change Packet

Status: **LOCKED FOR IMPLEMENTATION**
Date: **2026-09-18 JST**
Phase: **VERTICAL_SLICE (Core Experience v2 rework)**
Production decision: **UNDECIDED**
Release approval: **NOT_REQUESTED**

## 1. Why the phase moved backward

A repeated iPhone Web playtest exposed product-level failures that invalidate the prior assumption that only native-device polish remained:

- facility/equipment growth was not visually legible enough during normal play;
- the Management sheet was difficult to parse: information hierarchy, action meaning, and expected result were unclear;
- play drifted toward opening Management and repeatedly buying available upgrades;
- the equipment/decision space became repetitive too quickly.

This is not treated as a cosmetic polish defect. It is a **Core Experience failure discovered during DEVICE_VALIDATION**.

Therefore FLOTRA returns from **DEVICE_VALIDATION → VERTICAL_SLICE** for a targeted Core Experience v2 rework. Existing technical, save, simulation, CI, and visual assets remain reusable evidence; they are not discarded.

## 2. Goal

Prove that FLOTRA is primarily:

> **a game where the player watches the warehouse, notices operational problems, intervenes in the relevant physical zone, and grows the warehouse through visible logistics decisions**

—not a game where the player mainly opens a menu and buys stat upgrades.

The v2 slice must make the warehouse itself the game board.

## 3. Non-goals

The slice does **not** include:

- Rank 3 redesign or new Rank 3 systems;
- INBOUND / PICKING / SHIPPING Rank 2 v2 equipment implementation;
- sorter / ASRS / cross-dock / new advanced automation content;
- App Store / TestFlight / production signing / final Bundle ID work;
- Android production work;
- backend, account, cloud save, IAP, ads, external analytics;
- broad visual polish unrelated to the v2 interaction loop;
- a free-placement factory editor.

Do not expand scope because an adjacent idea is attractive. New content waits until the v2 Core Experience passes playtest.

## 4. Existing behavior to preserve unless explicitly superseded

Keep:

- Godot 4.7.2 / GDScript / GL Compatibility;
- portrait 390×844 reference viewport;
- touch-first orbit and pinch;
- Domain authority over queues, workers, shipments, money, progression, routing, ownership, and measurement;
- authoritative Inbound → Store → Rack → Pick → Pack → Ship simulation;
- local save / backup / recovery;
- Before/After measurement infrastructure;
- current CI, Web preview, iOS export smoke, and regression coverage where still applicable;
- physical worker, parcel, rack, forklift, facility, and Rank visual assets that remain useful;
- existing Rank 3 implementation as a preserved legacy baseline, not v2 slice scope.

No UI or View code may fake logistics outcomes to make v2 appear successful.

## 5. Core Experience v2 — LOCKED DECISIONS

1. **3D Warehouse is the primary game screen.**
2. **Normal equipment decisions begin from a physical warehouse Zone, not from Management.**
3. The player loop is:
   **Observe → notice symptom → inspect Zone → choose operational/capital response → physical change → logistics reaction → measure → discover next constraint.**
4. The Bottleneck Director reports symptoms and evidence, **not the answer or recommended equipment**.
5. Management becomes an **executive dashboard**, not the default equipment store.
6. Repeated anonymous stat-level purchases are removed from the visible v2 loop. Major purchases must have a memorable physical/operational identity.
7. A major equipment decision must provide:
   - visible 3D change;
   - authoritative Domain effect;
   - readable strength;
   - readable weakness / trade-off;
   - measurable outcome.
8. Solving one bottleneck should credibly be able to expose another.
9. Rank 2 Zone equipment is **replaceable by paid renovation**. It is not a permanent one-time branch.
10. Only one equipment mode per Rank 2 Zone is active at a time.
11. Staffing remains a separate operational layer from capital equipment.
12. The top HUD hides RP until RP has a clear player-facing decision role.
13. Rank expansion remains a Management-level strategic project.
14. Equipment purchase requires a preview before commitment; a button press must not silently convert cash into an invisible stat.

## 6. Vertical Slice v2 scope

### 6.1 Rank 1 — complete v2 path

Rank 1 must teach the v2 game, not the old upgrade menu.

Initial Small Depot remains intentionally compact.

Required structural decisions:

- **Rack Wing** — visible storage expansion;
- **Second Packing Bench** — visible parallel packing capacity;
- **Worker Hire** — one additional worker, with value coming from placement rather than repeated hiring spam;
- **Forklift** — authoritative inbound-to-storage automation that visibly changes who does the work.

Remove visible repeated Speed Lv / Packing Lv style purchase loops from the v2 player path.

Rank 1 must end in a visible **Warehouse Expansion** project that grows the facility into Rank 2.

### 6.2 Rank 2 — only two v2 Zones in this slice

Implement only:

#### STORAGE
- **Fast Pick Rack**
  - strength: faster picking / fast access;
  - weakness: lower storage density.
- **High Density Rack**
  - strength: higher storage capacity;
  - weakness: slower picking.

#### PACKING
- **Parallel Pack Line**
  - strength: concurrent jobs / long-queue throughput;
  - weakness: slower individual processing and/or higher staffing demand.
- **Fast Pack Cell**
  - strength: low latency / fast single-job processing;
  - weakness: weaker long-queue resilience.

Both Zones:
- have one active equipment mode;
- can be renovated from A ⇄ B for a real cash cost;
- physically change the warehouse;
- must have at least one scenario where A is preferable and one where B is preferable.

### 6.3 Deferred Rank 2 target design

Target structure after the slice proves itself:

- INBOUND: Double Dock ⇄ Buffer Yard
- STORAGE: Fast Pick Rack ⇄ High Density Rack
- PICKING: Zone Picking ⇄ Batch Picking
- PACKING: Parallel Pack Line ⇄ Fast Pack Cell
- SHIPPING: Extra Dispatch Lane ⇄ Consolidation Stage

The deferred three Zones are design direction only. Do not implement them in this slice.

## 7. UI contract

### 7.1 Primary warehouse screen

The warehouse must retain the majority of the portrait viewport.

Top HUD should contain only high-frequency state needed while watching the floor, such as:

- cash;
- shipment rate;
- open orders;
- facility Rank.

RP is not displayed in the primary HUD.

The Director may say, for example:

- PACKING high load
- 14 waiting
- 42s sustained

It must not say buy packing upgrade or equivalent.

### 7.2 Zone interaction

The player taps a readable Zone target in the 3D warehouse.

Target Zone model for v2:
- INBOUND
- STORAGE
- PICKING
- PACKING
- SHIPPING

The slice only requires full v2 decision content for STORAGE and PACKING, plus Rank 1 interactions needed for onboarding.

### 7.3 Zone Panel

Open as a bottom sheet occupying roughly **35–42%** of the portrait viewport so the warehouse and adjacent flow remain visible.

Required information hierarchy:

1. Zone name + state;
2. current operational evidence;
3. current equipment;
4. **OPERATIONS** actions;
5. **CAPITAL** choices.

Do not mix all actions into a single undifferentiated button list.

Each equipment card must communicate:
- equipment name;
- primary strength;
- explicit weakness/trade-off;
- cost.

Do not mark one card as recommended.

### 7.4 Equipment preview / commit

Required flow:

**equipment card → preview → ghost / planned geometry → explicit build/renovate confirmation → physical construction/change**

The player must be able to see what part of the warehouse will change before committing cash.

### 7.5 Management Dashboard

Management no longer sells normal Zone equipment.

Target information architecture:

- **Overview**
- **Contracts**
- **Assets**
- **Staffing**

For this slice:
- Overview and Staffing are required v2 surfaces;
- Contracts may retain existing functionality with minimal restructuring;
- a full Assets history experience may be deferred if it does not block the Core Experience test.

Rank Expansion stays in Management because it is a facility-level strategic project.

### 7.6 Staffing

The old five-preset player-facing model is superseded for v2.

Player-facing staffing is direct Zone allocation / reassignment.

Implementation may internally reuse safe existing role logic where practical, but the player should understand **where workers are assigned**, not decode 3/1/1 preset labels.

## 8. Construction and reward feedback contract

A structural investment must not be a silent number change.

Required presentation:

1. selected Zone remains visible;
2. planned equipment is previewed;
3. player commits;
4. camera emphasizes the Zone without hiding adjacent logistics context;
5. geometry visibly changes;
6. authoritative logistics behavior changes;
7. measurement begins;
8. Before/After result appears after the existing real measurement window.

The result should make the consequence understandable, but should not prescribe the next purchase.

## 9. Renovation

LOCKED:
- Rank 2 equipment can be replaced;
- replacement costs money;
- no full refund loop;
- replacement changes physical geometry and Domain behavior;
- Before/After measurement runs again.

WORKING HYPOTHESES, not locked:
- renovation cost around 70–80% of a fresh build;
- temporary reduced capacity during renovation;
- renovation duration around 20–40 simulated seconds.

Do not implement downtime complexity until the simpler paid-renovation loop is proven enjoyable. Waiting must not become friction for its own sake.

## 10. Files expected to be in scope

Exact paths may change after implementation inspection, but expected responsibility areas are:

Domain:
- godot/domain/warehouse_sim.gd
- Rank 2 facility/equipment catalog and behavior files
- progression / staffing helpers
- measurement integration
- save-state additions only if required

UI:
- godot/ui/game_hud.gd
- Japanese/mobile/release HUD subclasses
- new Zone Panel / Dashboard responsibilities as appropriate
- FTUE / onboarding copy and state

View:
- godot/view/warehouse_view.gd
- Rank 2 facility view
- equipment preview / construction presentation
- Zone hit targets / world labels

QA:
- existing smoke/regression tests impacted by the new interaction model
- new v2 Core Loop smoke
- new Zone decision tests
- new equipment dominance/trade-off tests
- rendered visual capture updates only when required by the changed presentation

Do not perform a broad architecture rewrite merely to fit this packet.

## 11. Acceptance criteria

### 11.1 Core Experience

The slice fails if a normal playtest still feels like:
open Management → buy whatever is available → repeat.

PASS requires that a player can truthfully describe the session approximately as:

> “I saw where the warehouse was backing up, changed that part of the facility, then the pressure moved and I had to deal with the next problem.”

### 11.2 Rank 1

- first meaningful improvement can be reached without using Management as an equipment store;
- the player notices a physical symptom in the warehouse;
- a Zone interaction leads to a relevant action;
- Rack Wing / Second Packing Bench / Worker / Forklift produce legible consequences;
- Forklift visibly changes logistics behavior, not only a number;
- Rank 1 → Rank 2 visibly enlarges/restructures the facility.

### 11.3 Rank 2 STORAGE / PACKING

For each implemented Zone:
- both equipment options are understandable;
- both have a visible physical identity;
- both have a Domain-authoritative trade-off;
- A has at least one tested situation where it is preferable;
- B has at least one tested situation where it is preferable;
- renovation A ⇄ B works without save/progression corruption.

### 11.4 UI

- Zone Panel hierarchy is readable at 390×844;
- warehouse remains visible while making a Zone decision;
- Management Overview is understandable without scrolling through unrelated purchase controls;
- no normal Zone equipment is bought from Management;
- RP is absent from the primary HUD;
- Director does not provide the solution;
- touch does not require hover or precision tapping on tiny equipment.

### 11.5 Reward / growth legibility

Static geometry difference alone is not sufficient.

A human playtest must recognize:
- what physical area changed;
- what operational behavior changed;
- why the warehouse is more capable or differently configured.

## 12. Tests

Minimum automated coverage:

1. existing parse/import/startup;
2. authoritative shipment/revenue invariants;
3. save/recovery regression;
4. Rank 1 v2 progression smoke;
5. Zone selection / action reachability smoke;
6. equipment purchase + renovation persistence;
7. STORAGE A-wins scenario;
8. STORAGE B-wins scenario;
9. PACKING A-wins scenario;
10. PACKING B-wins scenario;
11. no tested equipment option is universally dominant across its paired scenarios;
12. measurement still uses authoritative Before/After state;
13. mobile layout / scroll / touch regression;
14. Web engineering export;
15. existing iOS export smoke remains green unless unrelated infrastructure changes.

Human verification:
- fresh 390×844 captures after material visual changes;
- iPhone Web playtest for the Core Experience loop;
- native physical-iPhone evidence remains required later when DEVICE_VALIDATION resumes.

## 13. Visual target

Preserve the current Art Bible / North Star direction:

- open-top cutaway logistics center;
- dark navy industrial base;
- cyan technology accents;
- amber safety accents;
- warm local task lighting;
- readable Inbound → Storage → Picking → Packing → Shipping flow.

v2 adds a stricter rule:

> **A player must be able to notice equipment and facility growth during ordinary play, not only in side-by-side screenshots.**

Zone labels, highlights, previews, and construction feedback must support the warehouse rather than cover it.

## 14. Rollback / recovery

Protected baseline before v2 rework:
- main at df9df289be4600024fe091e04b0e5128aa91fa34.

Implementation rules:
- use branch → PR → CI → visual/behavior verification → merge;
- split the work into reviewable increments;
- do not delete legacy Rank 3 or save logic simply because it is outside slice scope;
- preserve schema-v7 compatibility unless a deliberate migration is required;
- record any save-schema bump and migration explicitly;
- if a v2 sub-change fails, revert that sub-change rather than restoring the entire old UX by guesswork.

## 15. Recommended implementation order

1. **Interaction skeleton**
   - Zone targets;
   - Zone Panel;
   - symptom-only Director;
   - Management equipment removal.
2. **Rank 1 v2**
   - structural projects;
   - event-driven onboarding;
   - Warehouse Expansion.
3. **Staffing v2**
   - direct Zone allocation player model.
4. **Rank 2 STORAGE**
   - two modes + renovation + dominance tests.
5. **Rank 2 PACKING**
   - two modes + renovation + dominance tests.
6. **Construction/reward presentation**
   - preview / ghost / build / camera / measurement.
7. **iPhone Web playtest**
   - evaluate the Core Experience before adding other Zones.

Do not implement steps 4–6 as a reason to postpone testing the interaction skeleton. Test as soon as a coherent loop exists.

## 16. Exit from this rework

Vertical Slice v2 may return to **DEVICE_VALIDATION** only after:

- the v2 slice is playable end-to-end;
- CI/save regressions are green;
- Rank 1 and Rank 2 STORAGE/PACKING decisions work;
- fresh visual evidence has been inspected;
- iPhone Web playtest no longer presents the prior Management-clicker failure mode;
- the player can perceive facility/equipment consequences during ordinary play.

Passing this slice does **not** enter GREENLIGHT.

Afterward, DEVICE_VALIDATION resumes. Native representative-iPhone evidence is still required before GREENLIGHT.
