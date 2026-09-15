# LOGISTICS BOSS — Rank 2 Post-Zone Decision

Date: 2026-09-15 JST
Status: measured product decision

## Question

After all three Rank 2 expansion zones exist, what should be built next?

Candidates included more automation (especially AGV) versus a system that makes operations decisions more situational.

## Evidence

`godot/tests/rank2_post_zone_frontier.gd` measures all:
- 8 possible completed Zone A/B/C facility combinations;
- 5 Rank 2 staffing presets per combination;
- 240 simulated seconds per scenario;
- 40 scenarios total.

The scout records throughput, queue pressure, worker utilization, task mix and dominant bottleneck, then selects the best staffing preset for each facility combination.

Current green CI result:
- best staffing winner: `shipping` in 8 / 8 completed facility combinations;
- best-plan dominant bottleneck: `stable` in 4 / 8, `orders` in 4 / 8;
- fastest combination: Double Dock + Fast Pick Rack + Fast Pack Cell = 29.5 shipments/min;
- slowest best-case combination: Buffer Yard + Fast Pick Rack + Parallel Pack = 25.5 shipments/min;
- every completed three-zone build remains well above the current 6 shipments/min Rank 3 readiness floor.

Representative completed-build results with best staffing:
- Double Dock + Fast Pick + Parallel Pack: 29.3/min, stable.
- Double Dock + Fast Pick + Fast Pack: 29.5/min, stable.
- Double Dock + High Density + either pack choice: 27.8/min, order backlog dominant.
- Buffer Yard + Fast Pick: 25.5–25.8/min, mostly stable.
- Buffer Yard + High Density: 25.5/min, order backlog dominant.

## Interpretation

### 1. Do not add AGV simply because it is the next automation tier

The measured system does not show a universal rack-to-pack bottleneck. Fast Pick builds are already stable under the best steady-state staffing configuration. An AGV added globally at this point would often be throughput-neutral and would risk becoming another expensive button without a meaningful decision.

### 2. High Density Rack creates a real future niche for AGV

High Density builds preserve capacity but deliberately slow PICK. In all four completed High Density combinations, the best steady-state configuration still trends toward order backlog. This is credible evidence that later PICK automation can solve a real, player-created bottleneck instead of an invented one.

AGV remains a valid future candidate, especially as a counterplay to High Density storage, but it is not the immediate next system.

### 3. Current Rank 2 staffing has a late-game dominant strategy

With Forklift Automation active and all three zones completed, `出荷強化 1/2/2` wins throughput in all eight facility combinations.

This is not a runtime bug: Forklift removes much of the manual STORE burden, leaving one STORE worker + two PICK + two SHIP as the strongest static allocation. But it is a game-design warning. If the workload remains stationary, the player learns one staffing answer and no longer needs to observe and react.

### 4. The next system should create time-varying workload pressure

Before another permanent automation purchase, Rank 2 should gain deterministic operational waves that change which stage needs labor over time, for example:
- inbound truck / receiving surge;
- order-release / picking surge;
- outbound dispatch deadline or shipping surge;
- recovery / normal-flow windows.

The purpose is not random punishment. Each wave must be visible in advance or legible as it begins, produce a measurable queue shift, and make at least two staffing plans strategically correct in different operating contexts.

This directly strengthens the canonical loop:
`observe → identify current bottleneck → change staffing / operation → autonomous response → measure result`.

## Locked implementation direction

Next Rank 2 gameplay slice:
1. add a deterministic workload-wave model to the Domain;
2. expose upcoming/current wave clearly in the mobile HUD and 3D warehouse where useful;
3. keep the 30-second staffing reassignment commitment so timing matters;
4. add scenario tests proving different staffing presets win different wave contexts;
5. measure whether the workload system creates real switching value without causing unwinnable deadlocks;
6. only then re-evaluate AGV using the High Density PICK bottleneck evidence.

Do not claim Rank 3 / Fulfillment Center complete from the existing readiness gate. Fresh iPhone verification of the new Rank 2 structural UI/3D also remains required.
