extends "res://tests/capacity_growth_smoke.gd"

# Title-local diagnostic only. Rate multipliers exist in this observer subclass,
# never in the production economy. Cash/20 historical shipments are explicit
# boundary setup, so these reports are not natural purchase pacing evidence.
# Queue/idle times use 0.1s end-of-step samples, not parcel latency timestamps.
const STEP_SECONDS := 0.1
const MEASURED_CYCLES := 3

class FlowProbe:
    extends FlotraV2Sim

    var inbound_rate := 1.0
    var order_rate := 1.0
    var inbound_offered := 0
    var inbound_accepted := 0
    var order_offered := 0
    var order_accepted := 0
    var pick_started := 0

    func _current_inbound_interval() -> float:
        return super._current_inbound_interval() / inbound_rate

    func _current_order_interval() -> float:
        return super._current_order_interval() / order_rate

    func _spawn_flow(dt: float) -> void:
        var inbound_before := inbound_queue
        var orders_before := open_orders
        var inbound_timer_before := _inbound_timer
        var order_timer_before := _order_timer
        super._spawn_flow(dt)
        # Each timer increment is one offered arrival. Production spawn code is
        # called unchanged; queue deltas count actual accepted arrivals before
        # workers, equipment, or progression can consume them.
        inbound_offered += roundi((_inbound_timer - inbound_timer_before + dt) / _current_inbound_interval())
        order_offered += roundi((_order_timer - order_timer_before + dt) / _current_order_interval())
        inbound_accepted += inbound_queue - inbound_before
        order_accepted += open_orders - orders_before

    func _start_task(worker: Dictionary, task: int) -> void:
        var orders_before := open_orders
        super._start_task(worker, task)
        pick_started += orders_before - open_orders

    func reset_counts() -> void:
        inbound_offered = 0
        inbound_accepted = 0
        order_offered = 0
        order_accepted = 0
        pick_started = 0

func probe_fixture(stage: int, inbound_rate: float = 1.0, order_rate: float = 1.0, staffing: String = "balanced") -> FlowProbe:
    var s := FlowProbe.new()
    s.inbound_rate = inbound_rate
    s.order_rate = order_rate
    s.money = 250000
    expect(s.purchase_rank1_project(&"rack_wing")["ok"], "Fixture rack purchase")
    expect(s.purchase_rank1_project(&"forklift_project")["ok"], "Fixture forklift purchase")
    s.shipped = 20
    expect(s.purchase_warehouse_expansion()["ok"], "Fixture expansion")
    expect(s.purchase_growth_automation(&"transfer_conveyor")["ok"], "Fixture conveyor purchase")
    expect(s.purchase_growth_automation(&"extra_forklift")["ok"], "Fixture extra forklift purchase")
    if stage >= 1:
        expect(s.purchase_capacity(&"packing_cell", 0)["ok"], "Fixture first packing cell")
    if stage >= 2:
        expect(s.purchase_capacity(&"dispatch_lane", 0)["ok"], "Fixture first dispatch lane")
    if stage >= 3:
        expect(s.purchase_capacity(&"packing_cell", 1)["ok"], "Fixture second packing cell")
        expect(s.purchase_capacity(&"packing_cell", 2)["ok"], "Fixture third packing cell")
        expect(s.purchase_capacity(&"dispatch_lane", 1)["ok"], "Fixture second dispatch lane")
    if staffing != "balanced":
        expect(s.set_staffing_plan(staffing)["ok"], "Fixture staffing change")
    return s

func sample(s: FlowProbe, metrics: Dictionary) -> void:
    for key in ["inbound_queue", "rack_stock", "open_orders", "packing_queue", "packed_queue"]:
        var value := int(s.get(key))
        metrics[key + "_parcel_seconds"] = float(metrics.get(key + "_parcel_seconds", 0.0)) + value * STEP_SECONDS
        metrics[key + "_max"] = maxi(int(metrics.get(key + "_max", 0)), value)
    if s.rack_stock + s._reserved_store_slots() >= s.rack_capacity:
        metrics["rack_full_seconds"] = float(metrics.get("rack_full_seconds", 0.0)) + STEP_SECONDS
    for worker in s.workers:
        var role := String(worker.get("role", "unknown"))
        var task := int(worker["task"])
        var key := role + "_busy_worker_seconds"
        if task == WarehouseSim.Task.IDLE:
            match role:
                "store":
                    key = "store_idle_no_inbound_worker_seconds" if s.inbound_queue == 0 else "store_idle_rack_full_worker_seconds"
                "pick":
                    if s.rack_stock == 0 and s.open_orders == 0:
                        key = "pick_idle_no_stock_or_orders_worker_seconds"
                    elif s.rack_stock == 0:
                        key = "pick_idle_no_stock_worker_seconds"
                    elif s.open_orders == 0:
                        key = "pick_idle_no_orders_worker_seconds"
                    else:
                        key = "pick_idle_other_worker_seconds"
                "ship":
                    key = "ship_idle_no_packed_worker_seconds"
        elif task == WarehouseSim.Task.PICK and float(worker["remaining"]) <= 0.0:
            key = "pick_conveyor_blocked_worker_seconds"
        metrics[key] = float(metrics.get(key, 0.0)) + STEP_SECONDS
    var packing_occupied := s._packing_jobs.size()
    for remaining in s._cell_jobs:
        if remaining > 0.0:
            packing_occupied += 1
    metrics["packing_busy_slot_seconds"] = float(metrics.get("packing_busy_slot_seconds", 0.0)) + packing_occupied * STEP_SECONDS
    var idle_slots := s._packing_capacity() + s.packing_cells - packing_occupied
    metrics["packing_idle_slot_seconds"] = float(metrics.get("packing_idle_slot_seconds", 0.0)) + idle_slots * STEP_SECONDS

func measure(s: FlowProbe, label: String, seconds: float, cycle: int) -> Dictionary:
    s.reset_counts()
    var shipped_before := s.shipped
    var money_before := s.money
    var inventory_before := inventory(s)
    var orders_before := s.open_orders
    var cells_before := s.capacity_packed
    var lanes_before := s.capacity_shipped
    var metrics := {}
    var packing_start := s.packing_queue
    var packed_start := s.packed_queue
    var rack_start := s.rack_stock
    for _step in roundi(seconds / STEP_SECONDS):
        s.step(STEP_SECONDS)
        sample(s, metrics)
    expect(inventory(s) == inventory_before + s.inbound_accepted, "%s cycle %d: accepted cargo is conserved" % [label, cycle])
    expect(orders_before + s.order_accepted == s.open_orders + s.pick_started, "%s cycle %d: accepted orders are conserved" % [label, cycle])
    expect(s.money - money_before == (s.shipped - shipped_before) * WarehouseSim.BASE_SHIPMENT_VALUE, "%s cycle %d: revenue follows real shipments" % [label, cycle])
    expect(s.inbound_offered >= s.inbound_accepted and s.order_offered >= s.order_accepted, "Offered flow bounds accepted flow")
    expect(s.facility_rank == 2 and s.completed_contracts == 0, "Controlled comparison stays at Rank2 without contracts")
    var report := {
        "case": label, "cycle": cycle, "seconds": seconds,
        "shipped": s.shipped - shipped_before, "operating_cash": s.money - money_before,
        "inbound_offered": s.inbound_offered, "inbound_accepted": s.inbound_accepted,
        "inbound_rejected": s.inbound_offered - s.inbound_accepted,
        "orders_offered": s.order_offered, "orders_accepted": s.order_accepted,
        "orders_rejected": s.order_offered - s.order_accepted, "picks_started": s.pick_started,
        "cells_completed": s.capacity_packed - cells_before, "lanes_shipped": s.capacity_shipped - lanes_before,
        "packing_queue_start": packing_start, "packing_queue_end": s.packing_queue,
        "packed_queue_start": packed_start, "packed_queue_end": s.packed_queue,
        "rack_stock_start": rack_start, "rack_stock_end": s.rack_stock,
        "inbound_queue_end": s.inbound_queue, "orders_end": s.open_orders,
    }
    for key in metrics:
        report[key] = snappedf(float(metrics[key]), 0.01)
    print("FLOW_REPORT ", JSON.stringify(report))
    return report

func run() -> void:
    var cycle_seconds := WorkloadWaveModel.new().cycle_duration()
    expect(is_equal_approx(cycle_seconds, 255.0), "Diagnostic expects the declared 255s workload cycle")
    print("FLOW_PROTOCOL warmup_cycles=1 measured_cycles=%d cycle_seconds=%.1f sample_seconds=%.1f; diagnostic rates are test-only, no production balance change" % [MEASURED_CYCLES, cycle_seconds, STEP_SECONDS])
    # First reproduce the old 300s observation. The ordinary observer must not
    # alter any simulation state relative to the original uninstrumented fixture.
    for stage in 4:
        var s := probe_fixture(stage)
        measure(s, "original_300s_stage_%d" % stage, 300.0, 0)
        if stage == 0:
            var plain := fixture()
            for _step in 3000:
                plain.step(STEP_SECONDS)
            expect(s.snapshot() == plain.snapshot(), "Observer parity with original uninstrumented 300s fixture")
    # Parent names define a one-factor comparison. Stage2 adds only a lane to
    # stage1. Stage3 is retained solely as the original cumulative-max fixture.
    var cases := [
        {"label": "ordinary", "stage": 0, "parent": "none", "factor": "baseline"},
        {"label": "ordinary_cell", "stage": 1, "parent": "ordinary", "factor": "one_packing_cell"},
        {"label": "ordinary_cell_lane", "stage": 2, "parent": "ordinary_cell", "factor": "one_dispatch_lane"},
        {"label": "ordinary_cell_staff_shipping", "stage": 1, "staffing": "shipping", "parent": "ordinary_cell", "factor": "staffing_1_2_2"},
        {"label": "ordinary_max", "stage": 3, "parent": "none", "factor": "cumulative_not_single_factor"},
        {"label": "inbound_2x", "stage": 0, "inbound": 2.0, "parent": "ordinary", "factor": "inbound_rate_only"},
        {"label": "inbound_2x_cell", "stage": 1, "inbound": 2.0, "parent": "inbound_2x", "factor": "one_packing_cell"},
        {"label": "inbound_2x_cell_lane", "stage": 2, "inbound": 2.0, "parent": "inbound_2x_cell", "factor": "one_dispatch_lane"},
        {"label": "orders_2x", "stage": 0, "orders": 2.0, "parent": "ordinary", "factor": "order_rate_only"},
        {"label": "staff_picking", "stage": 0, "staffing": "picking", "parent": "ordinary", "factor": "staffing_1_3_1"},
        {"label": "staff_shipping", "stage": 0, "staffing": "shipping", "parent": "ordinary", "factor": "staffing_1_2_2"},
    ]
    var results := {}
    for scenario in cases:
        var label := String(scenario["label"])
        print("FLOW_CASE ", JSON.stringify(scenario))
        var s := probe_fixture(int(scenario["stage"]), float(scenario.get("inbound", 1.0)), float(scenario.get("orders", 1.0)), String(scenario.get("staffing", "balanced")))
        measure(s, label + "_warmup", cycle_seconds, 0)
        var cycles: Array[Dictionary] = []
        for cycle in MEASURED_CYCLES:
            cycles.append(measure(s, label, cycle_seconds, cycle + 1))
        results[label] = cycles
    for pair in [["ordinary", "ordinary_cell"], ["ordinary_cell", "ordinary_cell_lane"], ["ordinary_cell", "ordinary_cell_staff_shipping"], ["ordinary", "inbound_2x"], ["ordinary", "orders_2x"], ["ordinary", "staff_picking"], ["ordinary", "staff_shipping"], ["inbound_2x", "inbound_2x_cell"], ["inbound_2x_cell", "inbound_2x_cell_lane"]]:
        summarize_comparison(results, pair[0], pair[1])
    test_sustained_nonfork_benefit(results)
    # Diagnostic rate changes remain exploratory; only the observed ordinary-
    # workload benefit below is a permanent regression requirement.
    print("Capacity flow diagnostic checks finished; failures=%d" % failures)
    quit(1 if failures else 0)

func summarize_comparison(results: Dictionary, before: String, after: String) -> void:
    var comparison := {"before": before, "after": after, "measured_seconds": 255.0 * MEASURED_CYCLES}
    for label in [before, after]:
        var totals := {}
        var per_cycle_shipments: Array[int] = []
        var packing_ends: Array[int] = []
        var packed_ends: Array[int] = []
        for report in results[label]:
            per_cycle_shipments.append(int(report["shipped"]))
            packing_ends.append(int(report["packing_queue_end"]))
            packed_ends.append(int(report["packed_queue_end"]))
            for key in ["shipped", "inbound_offered", "inbound_accepted", "inbound_rejected", "orders_offered", "orders_accepted", "orders_rejected", "packing_queue_parcel_seconds", "packed_queue_parcel_seconds", "ship_busy_worker_seconds"]:
                totals[key] = snappedf(float(totals.get(key, 0.0)) + float(report.get(key, 0.0)), 0.01)
        totals["per_cycle_shipments"] = per_cycle_shipments
        totals["packing_queue_ends"] = packing_ends
        totals["packed_queue_ends"] = packed_ends
        comparison["before_totals" if label == before else "after_totals"] = totals
    print("FLOW_COMPARISON ", JSON.stringify(comparison))

func test_sustained_nonfork_benefit(results: Dictionary) -> void:
    # Evidence established this comparison before adding the regression. Both
    # variants already own one packing cell; the only intervention is one lane.
    # Do not prescribe an exact shipment total or change rates to make this pass.
    var before: Array = results["ordinary_cell"]
    var after: Array = results["ordinary_cell_lane"]
    for cycle in MEASURED_CYCLES:
        var base: Dictionary = before[cycle]
        var improved: Dictionary = after[cycle]
        for key in ["inbound_offered", "inbound_accepted", "inbound_rejected", "orders_offered", "orders_accepted", "orders_rejected", "picks_started"]:
            expect(base[key] == improved[key], "Lane comparison cycle %d has identical %s" % [cycle + 1, key])
        expect(int(improved["shipped"]) > int(base["shipped"]), "Added lane completes more real shipments in measured cycle %d" % (cycle + 1))
        expect(float(improved["packed_queue_parcel_seconds"]) < float(base["packed_queue_parcel_seconds"]), "Added lane reduces outbound queue area in measured cycle %d" % (cycle + 1))
        expect(int(improved["packed_queue_end"]) <= int(improved["packed_queue_start"]), "Added lane does not accumulate outbound backlog in measured cycle %d" % (cycle + 1))
    print("FLOW_REGRESSION ordinary_cell_to_one_lane sustained_cycles=%d; cargo/order/revenue conservation checked in every window" % MEASURED_CYCLES)
