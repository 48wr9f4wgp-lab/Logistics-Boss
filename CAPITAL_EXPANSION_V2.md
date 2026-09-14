# Logistics Boss — Capital Expansion v2

Status: implementation baseline / 2026-09-15
Authority: title-specific continuation of `CAPITAL_EXPANSION_V1.md`.

## Product goal

Capital Expansion v2 deepens the existing capital loop without turning Logistics Boss into a numeric upgrade clicker or prescribed puzzle.

Core loop remains:

observe flow → identify constraint → choose an investment → equipment visibly changes → logistics behavior changes → measure Before/After → a downstream constraint appears → reinvest at a larger scale

The player chooses the investment order. The UI may expose cost, capability, unlock condition and measured consequences, but must not prescribe a single correct purchase.

## Phase 1 automation chain

Three physically distinct automation categories are added after the first equipment tiers.

### Forklift Fleet
- Unlock: equipment assets ≥ ¥8,000.
- First cost: ¥15,000.
- Simulation: periodically transfers multiple unreserved inbound parcels directly into available rack slots.
- Visual: low-poly forklifts with mast, forks and pallet shuttle between receiving and storage.
- Expected new constraint: storage / picking / order processing becomes the next pressure point after inbound handling is accelerated.

### AGV Pick Fleet
- Unlock: equipment assets ≥ ¥40,000.
- First cost: ¥40,000.
- Simulation: periodically transfers ordered parcels from racks into the packing queue without using a picker.
- Visual: autonomous guided vehicles shuttle between racks and packing.
- Expected new constraint: packing or outbound becomes the next pressure point after picking is accelerated.

### Automatic Sorter
- Unlock: equipment assets ≥ ¥200,000.
- First cost: ¥90,000.
- Simulation: periodically consumes packed parcels and completes real shipments without a shipping worker.
- Visual: conveyor/sorter modules with rollers, scanner and diverter grow near outbound.
- Expected new constraint: packing, storage or inbound supply becomes the next pressure point after outbound is accelerated.

## Phase 2 workforce and property expansion

Phase 2 adds two investments that answer different bottleneck classes instead of extending automation as a single ladder.

### Workforce Expansion
- Unlock: equipment assets ≥ ¥2,500.
- First cost: ¥3,500.
- Levels: 5.
- Simulation: each purchase adds one real worker to the current staffing plan. The worker receives tasks through the same store / pick / ship dispatch system as the existing crew.
- Visual: one additional 3D worker appears immediately in the warehouse for each level.
- Strategic role: flexible short- and mid-term capacity. It can relieve several bottlenecks, but it is less specialized than later automation.
- Expected new constraint: once labor clears one process, packing capacity, rack capacity, receiving or outbound can become the next limiter.

### Logistics Hall Expansion
- Unlock: equipment assets ≥ ¥200,000.
- First cost: ¥300,000.
- Levels: 3.
- Simulation per level: rack capacity +8 parcels and receiving buffer +4 parcels.
- Visual: a full additional warehouse hall is revealed in 3D for every purchased level; camera framing expands with the site.
- Strategic role: property-scale buffer/capacity investment. It does not magically process parcels faster; it creates physical headroom for a larger operation.
- Expected new constraint: after storage/receiving pressure is reduced, labor, picking, packing or outbound becomes the limiting stage.

Workforce and hall expansion are not prescribed upgrades. A player can automate early, hire more people, buy property, or mix the approaches according to the observed constraint.

## Four-condition gate

Every Capital v2 major investment category must pass all four conditions:

1. **Visible 3D change** — the machine, worker, fleet or building must be readable in the warehouse.
2. **Actual logistics behavior change** — it must change real simulation capacity or move work between real stages, not only multiply a display number.
3. **Measured Before/After** — the existing 25-second investment result report must apply unchanged and may show negative results.
4. **New bottleneck potential** — relieving one constraint must be capable of moving the limiting constraint elsewhere.

## Economy ownership

Capital v2 keeps capital mutation and commercial shipment revenue inside the simulation domain.

- `capital.js` is presentation/measurement and requests a purchase through the simulation API.
- `sim.js` owns cash deduction, upgrade state, workforce growth, hall capacity and shipment revenue.
- Shipment events expose the actual unit revenue so ROI measurement observes the same economy that the simulation uses.

This removes the v1 split where UI code directly changed money/upgrades and patched commercial revenue after the shipment event.

## Economic escalation

Existing v1 equipment remains the early capital layer. Workforce, automation and property then reach into progressively larger capital bands.

Commercial asset tiers extend beyond Mega Logistics:
- Local Depot
- Mechanized Depot
- High-Throughput Warehouse
- Regional Fulfillment
- Automated DC
- Mega Logistics
- National Hub
- Automated Mega Hub

The purpose of higher parcel value is to support larger machinery and property-scale expansion, not to create passive waiting as the main gameplay.

## Mobile / UX rules

- Capital Expansion remains first in the management bottom sheet.
- Locked categories show their asset threshold rather than disappearing completely.
- Buying equipment, hiring staff or expanding the hall does not close management.
- The 25-second measurement remains visible while the player deliberately returns to the warehouse view.
- The next equipment unlock and next commercial tier remain pinned at sheet level while capital cards scroll underneath.
- No FTUE rail or “buy this next” recommendation is added.

## Phase 1 acceptance criteria

- Forklift, AGV and Sorter have distinct investment cards and escalating costs.
- Each category changes real parcel flow in `sim.js`.
- Each category has a distinct visible 3D representation in `scene.js`.
- New upgrade state survives schema-3 save/load without breaking old saves.
- Commercial revenue is applied once, inside the simulation domain.
- Existing Capital v1 investments and Rank 1/Rank 2 progression continue to work.
- Static QA and simulation smoke tests cover the new chain.

## Phase 2 acceptance criteria

- Workforce Expansion is a Capital card and each level adds one real worker.
- The added worker is visible in 3D and participates in the same role/dispatch system as existing staff.
- Logistics Hall Expansion is a Capital card with three escalating property levels.
- Each hall level increases real receiving and rack capacity.
- Each hall level reveals one additional 3D warehouse hall and widens camera framing.
- Workforce and hall levels survive schema-3 save/load.
- The existing 25-second Before/After report applies to both investments.
- Static QA and Capital v2 smoke tests cover purchase, capacity, persistence and simulation behavior.

## Phase 3 — Truck Dock / Truck Waves

Phase 3 converts late-game inbound flow from a smooth drip into visible truck arrivals.

- Capital card: `トラックドック`
- Costs: `¥650,000 / ¥5,000,000 / ¥40,000,000`
- Unlock: investment total `¥500,000`
- Level 1–3 add visible 3D dock bays and a real truck arrival/unload/depart cycle.
- Once installed, inbound supply comes in waves instead of the old continuous cadence.
- Higher levels increase boxes per truck and arrival frequency while reducing unload time per box.
- Trucks unload into the same authoritative inbound parcel queue, so insufficient receiving/rack/picking/packing capacity creates a new bottleneck instead of being bypassed.
- Existing 25-second Capital Before/After measurement applies without forcing a prescribed solution.

Four-condition gate:
1. Visible 3D dock/truck change.
2. Real logistics behavior changes from drip to waves.
3. Before/After remains measurable.
4. More dock capacity can expose internal bottlenecks.

## Phase 4 — AS/RS Automated Storage & Retrieval

Phase 4 moves the storage layer from conventional racks toward a high-bay automated warehouse rather than adding another generic speed multiplier.

### AS/RS Automated Warehouse
- Capital card: `AS/RS自動倉庫`.
- Unlock: investment total `¥1,000,000`.
- Costs: `¥1,800,000 / ¥14,000,000 / ¥90,000,000`.
- Levels: 3.
- Storage capacity: +16 real rack slots per level.
- Automated cycle: one real storage/retrieval move approximately every `5.4 / 3.9 / 2.8` seconds by level.
- Storage move: unreserved inbound parcel → real rack slot.
- Retrieval move: ordered rack parcel → real packing queue.
- The controller alternates store/retrieve intent and falls back to the available direction, so the system continues to serve the current warehouse state instead of stalling on an impossible action.
- Visual: each level adds a distinct high-bay rack tower with a moving stacker-crane carriage, shuttle and live scanner/beacon response to `asrs_store` / `asrs_pick` events.
- Strategic role: simultaneously create high-density storage and reduce rack-stage labor dependence without bypassing packing or outbound.
- Expected new constraint: after rack handling is automated, packing cells, sorter/outbound capacity, or inbound truck waves can become the next limiter.

Phase 4 must not make workforce, forklift, AGV, hall or truck-dock choices obsolete. Those investments solve different stages and remain valid depending on the observed bottleneck.

### Phase 4 acceptance criteria
- AS/RS is a distinct Capital category and remains locked below ¥1,000,000 invested capital.
- Each level adds +16 authoritative rack capacity.
- The simulation emits real `asrs_store` and `asrs_pick` events from actual parcel state changes.
- AS/RS state and capacity survive schema-3 save/load.
- A purchased level produces a visible high-bay 3D module; additional levels add additional modules.
- Stack-crane/shuttle motion reacts to real AS/RS transfer events rather than being a static decoration only.
- Existing 25-second Before/After measurement applies to AS/RS unchanged.
- Capital v2 smoke tests require both real storage and retrieval behavior.

## Deferred to later v2 phases

- Multi-building logistics campus / second center beyond the three hall extensions.
- True Rank 3 `Fulfillment Center` gameplay.
- Event-synchronized pallet/parcel attachment to every vehicle animation.
- Free-form conveyor drawing.

These should be added only after the current workforce / automation / property choices prove that they create meaningfully different investment strategies and bottlenecks.
