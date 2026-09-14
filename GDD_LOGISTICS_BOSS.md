# Logistics Boss — Vertical Slice GDD

Status: Context Lock / Vertical Slice
Canonical project rule: GAME_DEV_MASTER_RULES v1.3

## 1. Context Lock
- Product name: Logistics Boss
- Platform: iPhone Safari / PWA-first web, PC browser secondary
- Region / audience: global-capable, Japanese prototype UI, casual-to-midcore management/simulation players
- Genre: 3D logistics management sim / automation observer
- Core loop: issue priorities -> autonomous workers move goods -> observe bottlenecks -> change priorities / buy upgrades -> throughput and profit rise
- Meta loop: more workers -> faster handling -> larger racks -> faster packing -> conveyor automation -> larger facility
- Session: 5–15 minutes for vertical slice
- Orientation / input: responsive portrait-landscape; tap, drag/orbit, pinch zoom; no virtual joystick
- Offline / online: offline single-player vertical slice
- Monetization: none in prototype; decision deferred until product proof
- LiveOps: none in prototype
- Device tier: recent mid-range iPhone and above; low-poly stylized 3D; stable interactive frame rate over visual complexity
- Save: localStorage with schema_version; backend not required for vertical slice
- Privacy class: no account, no PII, no external analytics in prototype

## 2. Success Definition
- Repeat action: set policy, inspect the flow, remove bottlenecks, buy the next throughput upgrade.
- Satisfaction: the facility visibly clears queues and becomes more efficient because of the player's decisions.
- Growth: worker count, walking speed, rack capacity, packing speed, automation level, cash, shipments and physical facility size.
- Return reason: unlock the next automation layer and see a larger autonomous logistics center operate.
- Monetization point: intentionally undecided until retention and session appeal are proven.
- Shared category expectations: pause / 1x / 2x / 4x, readable bottlenecks, autonomous agents, visible production flow, meaningful upgrades.
- Differentiation: compact mobile-first 3D logistics simulation where operational problems are visible in the world instead of hidden behind spreadsheets.

## 3. Vertical Slice
### Facility
- Inbound dock
- Rack storage
- Packing station
- Outbound dock
- 3 autonomous workers

### Flow
Inbound parcel -> worker stores parcel -> rack -> order arrives -> worker picks parcel -> packing -> worker ships packed parcel -> cash

### Player directives
- BALANCE: balanced intake and shipping
- INBOUND: prioritize clearing inbound backlog
- SHIP: prioritize orders and outbound flow

### Time controls
Pause / 1x / 2x / 4x

### Upgrades
- Hire worker
- Worker speed
- Rack capacity
- Packing speed
- Conveyor automation

### Research
- Smart Dispatch
- Standardized Packing
- High-value Contracts

### Bottlenecks surfaced to player
- Inbound queue full
- Rack capacity full
- Pending orders rising
- Packed goods waiting for outbound

### Observation systems
- Bottleneck Director identifies dominant constraint and recommends an action.
- FLOW overlay shows only useful task routes and saturation cues, not all data at all times.
- Facility growth must be visible: racks, packing modules, conveyors, gates and halls expand as upgrades accumulate.

### Physics use
Rapier is limited to visible overflow parcels / incidental physical chaos when inbound is clogged. Core economy and task assignment do not depend on nondeterministic physics.

## 4. Non-goals for this slice
- Character customization
- Large building editor
- Complex pathfinding/navmesh
- Multiple product SKUs
- Staff needs/moods
- Cloud save, accounts, multiplayer
- Monetization, ads, store release

## 5. Acceptance Criteria
- The player can understand what is entering, stored, packing, and shipping without controlling an avatar.
- Workers continuously find and execute valid tasks without player micromanagement.
- Changing policy visibly changes worker behavior within several seconds.
- Money and shipment count increase only after successful outbound delivery.
- At least one bottleneck can emerge naturally and be improved by an upgrade or directive change.
- Pause / speed controls work on iPhone.
- Camera orbit / zoom works with touch and does not require a virtual joystick.
- Save restores progression fields safely with schema_version.
- No critical interaction depends on hover.
- Normal play keeps the 3D facility visually dominant over UI chrome.

## 6. Tech Decision
- Rendering: Three.js
- Camera: lightweight custom touch orbit / pinch zoom controller
- Physics: Rapier WASM, capped decorative overflow bodies only
- Simulation: deterministic JavaScript domain state separated from rendering
- Persistence: localStorage key `logistics_boss_save`, versioned snapshot
- Hosting: GitHub Pages static `/docs`; no Replit or always-on server required
- Canonical repository: `48wr9f4wgp-lab/Logistics-Boss`

## 7. Next Gate
Do not expand content broadly until the slice proves: directive -> autonomous response -> bottleneck visibility -> upgrade -> measurable throughput improvement -> visible facility growth.


## Progression Spine v1 — Phase 1 LOCK

Core meta loop: **contract → cash/RP/logistics rating → facility rank → structural investment → new bottleneck → new directive**.

- Cash builds structural facilities and secondary numeric upgrades.
- RP buys research/perks.
- Logistics Rating is non-spend progression from contracts.
- Rank 1 Small Depot → Rank 2 Warehouse at Logistics Rating 8.
- Rank 2: Second Inbound ¥2,400; one rack strategy (Fast Pick or High Density) ¥2,800; Second Pack Line ¥3,200.
- Every structural investment changes both simulation behavior and visible 3D geometry.
- Free-placement building remains out of scope.


## Rank 1 UX / FTUE Pass 1 LOCK

Rank 1 must teach the game before adding more progression. The always-visible Director is the primary action translator: show the problem in plain Japanese, show a concrete current count, explain why it matters, and offer one contextual action button. Rank 1 FTUE communicates three steps: choose a contract, react to the Director, then repeat contracts until Logistics Rating 8 unlocks Warehouse.

UX rules:
- Use player-language labels such as 棚使用, 注文待ち, 入荷待ち, and 出荷ペース instead of abstract capacity terminology where possible.
- Management stays open after buying an upgrade, facility, or research item; only the player closes it.
- Milestones use non-blocking toast feedback. Large center-screen celebration is reserved for contract completion and Facility Rank up.
- Contract selection must be labeled explicitly; do not use an unlabeled plus icon as the primary affordance.
- Upgrade cards must state their practical effect, not only their name and level.
