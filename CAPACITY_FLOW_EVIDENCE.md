# FLOTRA capacity diagnosis
Date: 2026-09-21 / scope: title-local / development evidence
Source: capacity_flow_report.gd. Initial execution Godot4.5.1; identical reported comparisons and regression checks passed on matching Godot4.7.2. See CAPACITY_VERIFICATION_2026-09-21.json.
Protocol: Rank2 explicit controlled fixture, two forklifts and transfer conveyor, equal original workforce5, no contracts. One255s workload-cycle warmup followed by3complete255s cycles at0.1s step. No production rate/revenue multiplier.

| Configuration | Shipments per measured cycle | Final packing queue | Final dispatch queue |
| --- | --- | --- | --- |
| No cumulative additions |83 /85 /85|23|0|
| One packing cell |83 /85 /85|0|24|
| Cell + one automatic lane |92 /92 /92|0|0|
| Cell + staffing1/2/2 |92 /92 /92|0|0|
| Three cells + two lanes |92 /92 /92|0|0|

The original300s comparison reproduces86shipments for all4equipment variants. It hides the growing queue. The first constraint is packing; removing it exposes dispatch. A second dispatch worker OR an automatic lane handles that constraint. A lane is not the only answer. Standard-supply output rises253→276(about9.1%) over765s in the measured fixture.
The first lane also reduces dispatch queue area14999→183.3 parcel-seconds vs the one-cell configuration, with equal offered/accepted input and real shipment revenue. These are sampled queue-area values, not individual parcel-latency measurements.

Inflow2x or order2x alone gives255 shipments and worsens downstream pressure; staffing changes without packing capacity stay253. No new workload progression is adopted from this experiment. Beyond the first cell plus a dispatch solution, maximal equipment gives no further total-output gain under this ordinary workload. Later-unit value and long-term growth remain unproven; all5purchases are not a required player objective.

Regression: original reproduction; observer-vs-production state parity; cargo/order/cash conservation; same input for the lane comparison; sustained increase and lower dispatch queue area in each of3cycles. No exact output-number assertion forces the result. Rate multipliers exist only in a diagnostic subclass. This is neither natural purchase pacing nor human-fun/native-performance proof.
