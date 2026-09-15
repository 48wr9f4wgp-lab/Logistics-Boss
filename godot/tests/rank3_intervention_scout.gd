extends SceneTree

const CandidateSimScript = preload("res://tests/rank3_candidate_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const PICK_TASK := 2
const STORAGE_OPTIONS := {
    "fast_pick_rack": &"fast_pick_rack",
    "high_density_rack": &"high_density_rack",
}
const CANDIDATES := {
    "control": {
        "pick_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "assumption": "late Rank 2 baseline",
    },
    "pick_to_light": {
        "pick_multiplier": 0.85,
        "retrieval_cycle": 0.0,
        "assumption": "15% shorter human PICK cycle",
    },
    "amr_tote_runner": {
        "pick_multiplier": 0.70,
        "retrieval_cycle": 0.0,
        "assumption": "30% shorter human PICK cycle by removing travel",
    },
    "automated_retrieval_cell": {
        "pick_multiplier": 1.0,
        "retrieval_cycle": 4.5,
        "assumption": "one independent rack-to-pack retrieval every 4.5s",
    },
}


func _init() -> void:
    var storage_results: Dictionary = {}
    var comparisons: Dictionary = {}

    for storage_label in STORAGE_OPTIONS.keys():
        var storage_kind: StringName = STORAGE_OPTIONS[storage_label]
        var candidate_results: Dictionary = {}
        for candidate_label in CANDIDATES.keys():
            candidate_results[candidate_label] = _run_case(storage_kind, CANDIDATES[candidate_label])
        storage_results[storage_label] = candidate_results
        comparisons[storage_label] = _compare_against_control(candidate_results)

    print("RANK3_INTERVENTION_SCOUT %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "candidate_assumptions": CANDIDATES,
        "storage_results": storage_results,
        "comparisons": comparisons,
    }))

    for storage_label in storage_results.keys():
        var cases: Dictionary = storage_results[storage_label]
        var control: Dictionary = cases["control"]
        if not _require(int(control.get("shipments", 0)) > 0, "%s control must sustain real shipments" % storage_label):
            return
        if not _require(int(control.get("pick_tasks_started", 0)) > 0, "%s control must exercise real worker PICK tasks" % storage_label):
            return
        for candidate_label in ["pick_to_light", "amr_tote_runner"]:
            var result: Dictionary = cases[candidate_label]
            if not _require(int(result.get("pick_tasks_started", 0)) > 0, "%s / %s must exercise worker PICK" % [storage_label, candidate_label]):
                return
        var retrieval: Dictionary = cases["automated_retrieval_cell"]
        if not _require(int(retrieval.get("autonomous_retrieval_starts", 0)) > 0, "%s retrieval candidate must execute automation" % storage_label):
            return
        if not _require(int(retrieval.get("autonomous_retrieval_completions", 0)) > 0, "%s retrieval candidate must complete automation" % storage_label):
            return

    print("Godot Rank 3 intervention scout passed")
    quit(0)


func _run_case(storage_kind: StringName, candidate: Dictionary) -> Dictionary:
    var sim = _prepared_rank2(storage_kind)
    sim.configure_candidate(
        float(candidate.get("pick_multiplier", 1.0)),
        float(candidate.get("retrieval_cycle", 0.0))
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
    var max_rack := 0
    var max_packing := 0
    var max_packed := 0
    var pick_starved_seconds := 0.0
    var order_cap_seconds := 0.0
    var rack_full_seconds := 0.0
    var samples := 0
    var switches := 0
    var event_counts := {"pick_started": 0}
    var last_phase_id := ""
    var bottleneck_counts: Dictionary = {}

    sim.event_emitted.connect(func(event: Dictionary):
        if String(event.get("type", "")) == "worker_task_started" and int(event.get("task", -1)) == PICK_TASK:
            event_counts["pick_started"] = int(event_counts.get("pick_started", 0)) + 1
    )

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
        max_rack = maxi(max_rack, int(sim.rack_stock))
        max_packing = maxi(max_packing, int(sim.packing_queue))
        max_packed = maxi(max_packed, int(sim.packed_queue))
        if int(sim.open_orders) > 0 and int(sim.rack_stock) <= 0:
            pick_starved_seconds += STEP_SECONDS
        if int(sim.open_orders) >= 18:
            order_cap_seconds += STEP_SECONDS
        if int(sim.rack_stock) >= int(sim.rack_capacity):
            rack_full_seconds += STEP_SECONDS
        var bottleneck_key := String(sim.bottleneck().get("key", "stable"))
        bottleneck_counts[bottleneck_key] = int(bottleneck_counts.get(bottleneck_key, 0)) + 1
        samples += 1

    var divisor := maxf(1.0, float(samples))
    return {
        "storage": String(storage_kind),
        "shipments": int(sim.shipped) - start_shipped,
        "revenue": int(sim.money) - start_money,
        "shipments_per_min": snappedf(float(int(sim.shipped) - start_shipped) / (CYCLE_SECONDS / 60.0), 0.1),
        "orders_avg": snappedf(order_sum / divisor, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "rack_avg": snappedf(rack_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "packed_avg": snappedf(packed_sum / divisor, 0.01),
        "max_orders": max_orders,
        "max_inbound": max_inbound,
        "max_rack": max_rack,
        "max_packing": max_packing,
        "max_packed": max_packed,
        "rack_capacity": int(sim.rack_capacity),
        "pick_starved_seconds": snappedf(pick_starved_seconds, 0.01),
        "order_cap_seconds": snappedf(order_cap_seconds, 0.01),
        "rack_full_seconds": snappedf(rack_full_seconds, 0.01),
        "pick_tasks_started": int(event_counts.get("pick_started", 0)),
        "autonomous_retrieval_starts": int(sim.autonomous_retrieval_starts),
        "autonomous_retrieval_completions": int(sim.autonomous_retrieval_completions),
        "switches": switches,
        "bottleneck_distribution": bottleneck_counts,
        "dominant_bottleneck": _dominant_key(bottleneck_counts),
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "ending_orders": int(sim.open_orders),
        "ending_inbound": int(sim.inbound_queue),
        "ending_rack": int(sim.rack_stock),
        "ending_packing": int(sim.packing_queue),
        "ending_packed": int(sim.packed_queue),
    }


func _compare_against_control(cases: Dictionary) -> Dictionary:
    var control: Dictionary = cases["control"]
    var comparison: Dictionary = {}
    for candidate_label in ["pick_to_light", "amr_tote_runner", "automated_retrieval_cell"]:
        var result: Dictionary = cases[candidate_label]
        comparison[candidate_label] = {
            "shipment_delta": int(result.get("shipments", 0)) - int(control.get("shipments", 0)),
            "shipment_pct": snappedf(
                (float(result.get("shipments", 0)) / maxf(1.0, float(control.get("shipments", 0))) - 1.0) * 100.0,
                0.1
            ),
            "revenue_delta": int(result.get("revenue", 0)) - int(control.get("revenue", 0)),
            "orders_avg_delta": snappedf(float(result.get("orders_avg", 0.0)) - float(control.get("orders_avg", 0.0)), 0.01),
            "order_cap_seconds_delta": snappedf(float(result.get("order_cap_seconds", 0.0)) - float(control.get("order_cap_seconds", 0.0)), 0.01),
            "packed_avg_delta": snappedf(float(result.get("packed_avg", 0.0)) - float(control.get("packed_avg", 0.0)), 0.01),
            "dominant_bottleneck": String(result.get("dominant_bottleneck", "")),
            "ending_bottleneck": String(result.get("ending_bottleneck", "")),
        }
    return comparison


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
    assert(sim.load_data(data), "Rank 3 intervention seed must load")

    for kind in [&"buffer_yard", storage_kind, &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in Rank 3 intervention scout" % String(kind))

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


func _dominant_key(counts: Dictionary) -> String:
    var best_key := "stable"
    var best_count := -1
    for key in counts.keys():
        var count := int(counts[key])
        if count > best_count:
            best_count = count
            best_key = String(key)
    return best_key


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
