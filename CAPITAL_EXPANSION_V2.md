# Logistics Boss — Capital Expansion v2

Status: implementation baseline / 2026-09-14
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

## Four-condition gate

Every Capital v2 major equipment category must pass all four conditions:

1. **Visible 3D change** — the machine/fleet must be readable in the warehouse.
2. **Actual logistics behavior change** — it must move work between real simulation stages, not only multiply a number.
3. **Measured Before/After** — the existing 25-second investment result report must apply unchanged and may show negative results.
4. **New bottleneck potential** — accelerating one stage must be capable of moving the limiting constraint downstream/upstream.

## Economy ownership

Capital v2 moves capital mutation and commercial shipment revenue into the simulation domain.

- `capital.js` is presentation/measurement and requests a purchase through the simulation API.
- `sim.js` owns cash deduction, upgrade state and shipment revenue.
- Shipment events expose the actual unit revenue so ROI measurement observes the same economy that the simulation uses.

This removes the v1 split where UI code directly changed money/upgrades and patched commercial revenue after the shipment event.

## Economic escalation

Existing v1 equipment remains the early capital layer. Phase 1 automation then reaches into larger capital bands.

Commercial asset tiers extend beyond Mega Logistics:
- Local Depot
- Mechanized Depot
- High-Throughput Warehouse
- Regional Fulfillment
- Automated DC
- Mega Logistics
- National Hub
- Automated Mega Hub

The purpose of higher parcel value is to support larger machinery and future property-scale expansion, not to create passive waiting as the main gameplay.

## Mobile / UX rules

- Capital Expansion remains first in the management bottom sheet.
- Locked automation categories show their asset threshold rather than disappearing completely.
- Buying equipment does not close management.
- The 25-second measurement remains visible while the player deliberately returns to the warehouse view.
- No FTUE rail or “buy this next” recommendation is added.

## Phase 1 acceptance criteria

- Forklift, AGV and Sorter have distinct investment cards and escalating costs.
- Each category changes real parcel flow in `sim.js`.
- Each category has a distinct visible 3D representation in `scene.js`.
- New upgrade state survives schema-3 save/load without breaking old saves.
- Commercial revenue is applied once, inside the simulation domain.
- Existing Capital v1 investments and Rank 1/Rank 2 progression continue to work.
- Static QA and simulation smoke tests cover the new chain.

## Deferred to later v2 phases

- AS/RS automated storage and retrieval.
- Property / hall expansion as an explicit purchasable capital category.
- Truck dock scheduling and truck waves.
- Multi-building logistics campus / second center.
- True Rank 3 `Fulfillment Center` gameplay.
- Event-synchronized pallet/parcel attachment to every vehicle animation.
- Free-form conveyor drawing.

These should be added only after Phase 1 proves that automation visibly changes the system and creates interesting new bottlenecks.
