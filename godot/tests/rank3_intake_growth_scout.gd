extends SceneTree

const CandidateSimScript = preload("res://tests/rank3_candidate_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const STORAGE_OPTIONS := {
    "fast_pick_rack": &"fast_pick_rack",
    "high_density_rack": &"high_density_rack",
}
const CANDIDATES := {
    "control": {"inbound_bonus": 0, "crossdock_cycle": 0.0},
    "receiving_annex": {"inbound_bonus": 14, "crossdock_cycle": 0.0},
    "receiving_annex_crossdock": {"inbound_bonus": 14, "crossdock_cycle": 4.5},
}


func _init() -> void:
    var storage_results: Dictionary = {}
    var comparisons: Dictionary = {}

    for storage_label in STORAGE_OPTIONS.keys():
        var storage_kind: StringName = STORAGE_OPTIONS[storage_label]
        var cases: Dictionary = {}
        for candidate_label in CANDIDATES.keys():
            cases[candidate_label] = _run_case(storage_kind, CANDIDATES[candidate_label])
        storage_results[storage_label] = cases
        comparisons[storage_label] = _compare(cases)

    print("RANK3_INTAKE_GROWTH_SCOUT %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "storage_results": storage_results,
        "comparisons": comparisons,
    }))

    for storage_label in storage_results.keys():
        var cases: Dictionary = storage_results[storage_label]
        var control: Dictionary = cases["control"]
        var annex: Dictionary = cases["receiving_annex"]
        var combined: Dictionary = cases["receiving_annex_crossdock"]
        if not _require(int(control.get("shipments", 0)) > 0, "%s control must ship" % storage_label):
            return
        if not _require(int(annex.get("inbound_arrivals", 0)) >= int(control.get("inbound_arrivals", 0)), "%s annex must not accept fewer inbound parcels" % storage_label):
            return
        if not _require(int(combined.get("crossdock_completions", 0)) > 0, "%s combined candidate must exercise cross-dock" % storage_label):
            return

    print("Godot Rank 3 intake growth scout passed")
    quit(0)


func _run_case(storage_kind: StringName, candidate: Dictionary) -> Dictionary:
    var sim = _prepared_rank2(storage_kind)
    sim.configure_candidate(
        1.0,
        1.0,
        1.0,
        0.0,
        float(candidate.get("crossdock_cycle", 0.0)),
        int(candidate.get("inbound_bonus", 0))
    )

    var start_shipped: int = int(sim.shipped)
    var start_money: int = int(sim.money)
    var order_sum := 0.0
    var inbound_sum := 0.0
    var rack_sum := 0.0
    var packing_sum := 0.0
    var packed_sum := 0.0
    var max_orders := 0
    var max_inbound := 0
    var arrivals := {"inbound": 0, "orders": 0}
    var last_phase_id := ""
    var switches := 0

    sim.event_emitted.connect(func(event: Dictionary):
        match String(event.get("type", "")):
            "inbound_arrival":
                arrivals["inbound"] = int(arrivals.get("inbound", 0)) + 1
            "order_arrival":
                arrivals["orders"] = int(arrivals.get("orders", 0)) + 1
    )

    var samples := 0
    for _i in int(ceil(CYCLE_SECONDS / STEP_SECONDS)):
        var wave: Dictionary = sim.workload_wave()
        var phase_id := String(wave.get("phase_id", ""))
        if phase_id != last_phase_id:
            last_phase_id = phase_id
            var target := _adaptive_plan_for_phase(phase_id)
            if not target.is_empty() and target != sim.staffing_plan and sim.staffing_cooldown <= 0.001:
                var staffing_result: Dictionary = sim.set_staffing_plan(target)
                if bool(staffing_result.get("ok", false)):
                    switches += 1

        sim.step(STEP_SECONDS)
        order_sum += float(sim.open_orders)
        inbound_sum += float(sim.inbound_queue)
        rack_sum += float(sim.rack_stock)
        packing_sum += float(sim.packing_queue)
        packed_sum += float(sim.packed_queue)
        max_orders = maxi(max_orders, int(sim.open_orders))
        max_inbound = maxi(max_inbound, int(sim.inbound_queue))
        samples += 1

    var divisor := maxf(1.0, float(samples))
    return {
        "storage": String(storage_kind),
        "inbound_bonus": int(candidate.get("inbound_bonus", 0)),
        "crossdock_cycle": float(candidate.get("crossdock_cycle", 0.0)),
        "shipments": int(sim.shipped) - start_shipped,
        "revenue": int(sim.money) - start_money,
        "shipments_per_min": snappedf(float(int(sim.shipped) - start_shipped) / (CYCLE_SECONDS / 60.0), 0.1),
        "inbound_arrivals": int(arrivals.get("inbound", 0)),
        "order_arrivals": int(arrivals.get("orders", 0)),
        "orders_avg": snappedf(order_sum / divisor, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "rack_avg": snappedf(rack_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "packed_avg": snappedf(packed_sum / divisor, 0.01),
        "max_orders": max_orders,
        "max_inbound": max_inbound,
        "inbound_limit": int(sim._current_inbound_limit()),
        "crossdock_starts": int(sim.crossdock_starts),
        "crossdock_completions": int(sim.crossdock_completions),
        "switches": switches,
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "ending_orders": int(sim.open_orders),
        "ending_inbound": int(sim.inbound_queue),
        "ending_rack": int(sim.rack_stock),
        "ending_packing": int(sim.packing_queue),
        "ending_packed": int(sim.packed_queue),
    }


func _compare(cases: Dictionary) -> Dictionary:
    var control: Dictionary = cases["control"]
    var result: Dictionary = {}
    for candidate_label in ["receiving_annex", "receiving_annex_crossdock"]:
        var candidate: Dictionary = cases[candidate_label]
        result[candidate_label] = {
            "shipment_delta": int(candidate.get("shipments", 0)) - int(control.get("shipments", 0)),
            "revenue_delta": int(candidate.get("revenue", 0)) - int(control.get("revenue", 0)),
            "inbound_arrival_delta": int(candidate.get("inbound_arrivals", 0)) - int(control.get("inbound_arrivals", 0)),
            "orders_avg_delta": snappedf(float(candidate.get("orders_avg", 0.0)) - float(control.get("orders_avg", 0.0)), 0.01),
            "inbound_avg_delta": snappedf(float(candidate.get("inbound_avg", 0.0)) - float(control.get("inbound_avg", 0.0)), 0.01),
            "ending_bottleneck": String(candidate.get("ending_bottleneck", "")),
        }
    return result


func _prepared_rank2(storage_kind: StringName):
    var sim = CandidateSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 4
    data["facility_rank"] = 2
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 500000
    data["forklift_unlocked"] = true
    data["pack_level"] = 1
    data["pack_time_multiplier"] = 0.85
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["workload_clock"] = 0.0
    data["dispatch_start_shipped"] = int(data.get("shipped", 0))
    data["inbound_queue"] = 6
    data["rack_stock"] = 6
    data["packing_queue"] = 3
    data["packed_queue"] = 4
    data["open_orders"] = 6
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "Rank 3 intake-growth seed must load")

    for kind in [&"buffer_yard", storage_kind, &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in Rank 3 intake-growth scout" % String(kind))

    sim.inbound_queue = 6
    sim.rack_stock = mini(int(sim.rack_capacity), 10)
    sim.packing_queue = 3
    sim.packed_queue = 4
    sim.open_orders = 6
    return sim


func _adaptive_plan_for_phase(phase_id: String) -> String:
    match phase_id:
        "forecast_inbound":
            return "balanced"
        "forecast_orders":
            return "picking"
        "forecast_dispatch":
            return "shipping"
    return ""


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
