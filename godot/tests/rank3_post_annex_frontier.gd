extends SceneTree

const CandidateSimScript = preload("res://tests/rank3_candidate_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const RECEIVING_BONUS := 14
const STORE_TASK := 1
const PICK_TASK := 2
const SHIP_TASK := 3
const STORAGE_OPTIONS := {
    "fast_pick_rack": &"fast_pick_rack",
    "high_density_rack": &"high_density_rack",
}
const CANDIDATES := {
    "control": {
        "store_multiplier": 1.0,
        "pick_multiplier": 1.0,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "pick_to_light": {
        "store_multiplier": 1.0,
        "pick_multiplier": 0.85,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "amr_tote_runner": {
        "store_multiplier": 1.0,
        "pick_multiplier": 0.70,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "automated_retrieval_cell": {
        "store_multiplier": 1.0,
        "pick_multiplier": 1.0,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 4.5,
        "crossdock_cycle": 0.0,
    },
    "auto_sorter_lane": {
        "store_multiplier": 1.0,
        "pick_multiplier": 1.0,
        "ship_multiplier": 0.70,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "putaway_assist": {
        "store_multiplier": 0.70,
        "pick_multiplier": 1.0,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "asrs_flow_cell": {
        "store_multiplier": 0.70,
        "pick_multiplier": 0.70,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 0.0,
    },
    "crossdock_express_lane": {
        "store_multiplier": 1.0,
        "pick_multiplier": 1.0,
        "ship_multiplier": 1.0,
        "retrieval_cycle": 0.0,
        "crossdock_cycle": 4.5,
    },
}


func _init() -> void:
    var storage_results: Dictionary = {}
    var comparisons: Dictionary = {}
    var winners: Dictionary = {}

    for storage_label in STORAGE_OPTIONS.keys():
        var storage_kind: StringName = STORAGE_OPTIONS[storage_label]
        var results: Dictionary = {}
        for candidate_label in CANDIDATES.keys():
            results[candidate_label] = _run_case(storage_kind, CANDIDATES[candidate_label])
        storage_results[storage_label] = results
        comparisons[storage_label] = _compare_against_control(results)
        winners[storage_label] = _best_throughput_candidate(results)

        var control: Dictionary = results["control"]
        if not _require(int(control.get("shipments", 0)) > 0, "%s Annex control must ship" % storage_label):
            return
        if not _require(int(control.get("inbound_limit", 0)) >= 42, "%s Annex control must include +14 receiving capacity" % storage_label):
            return
        if not _require(int(results["automated_retrieval_cell"].get("autonomous_retrieval_completions", 0)) > 0, "%s retrieval candidate must execute" % storage_label):
            return
        if not _require(int(results["crossdock_express_lane"].get("crossdock_completions", 0)) > 0, "%s crossdock candidate must execute" % storage_label):
            return

    print("RANK3_POST_ANNEX_FRONTIER %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "receiving_bonus": RECEIVING_BONUS,
        "storage_results": storage_results,
        "comparisons": comparisons,
        "throughput_winners": winners,
    }))
    print("Godot Rank 3 post-Annex frontier passed")
    quit(0)


func _run_case(storage_kind: StringName, candidate: Dictionary) -> Dictionary:
    var sim = _prepared_rank2(storage_kind)
    sim.configure_candidate(
        float(candidate.get("store_multiplier", 1.0)),
        float(candidate.get("pick_multiplier", 1.0)),
        float(candidate.get("ship_multiplier", 1.0)),
        float(candidate.get("retrieval_cycle", 0.0)),
        float(candidate.get("crossdock_cycle", 0.0)),
        RECEIVING_BONUS
    )

    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var sums := {"orders": 0.0, "inbound": 0.0, "rack": 0.0, "packing": 0.0, "packed": 0.0}
    var exposure := {"order_cap": 0.0, "pick_starved": 0.0, "rack_full": 0.0}
    var events := {"store": 0, "pick": 0, "ship": 0, "inbound": 0}
    var bottlenecks: Dictionary = {}
    var last_phase_id := ""
    var switches := 0
    var samples := 0

    sim.event_emitted.connect(func(event: Dictionary):
        var event_type := String(event.get("type", ""))
        if event_type == "inbound_arrival":
            events["inbound"] = int(events.get("inbound", 0)) + 1
        elif event_type == "worker_task_started":
            var task := int(event.get("task", -1))
            if task == STORE_TASK:
                events["store"] = int(events.get("store", 0)) + 1
            elif task == PICK_TASK:
                events["pick"] = int(events.get("pick", 0)) + 1
            elif task == SHIP_TASK:
                events["ship"] = int(events.get("ship", 0)) + 1
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
        sums["orders"] = float(sums["orders"]) + float(sim.open_orders)
        sums["inbound"] = float(sums["inbound"]) + float(sim.inbound_queue)
        sums["rack"] = float(sums["rack"]) + float(sim.rack_stock)
        sums["packing"] = float(sums["packing"]) + float(sim.packing_queue)
        sums["packed"] = float(sums["packed"]) + float(sim.packed_queue)
        if int(sim.open_orders) >= 18:
            exposure["order_cap"] = float(exposure["order_cap"]) + STEP_SECONDS
        if int(sim.open_orders) > 0 and int(sim.rack_stock) <= 0:
            exposure["pick_starved"] = float(exposure["pick_starved"]) + STEP_SECONDS
        if int(sim.rack_stock) >= int(sim.rack_capacity):
            exposure["rack_full"] = float(exposure["rack_full"]) + STEP_SECONDS
        var bottleneck_key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[bottleneck_key] = int(bottlenecks.get(bottleneck_key, 0)) + 1
        samples += 1

    var divisor := maxf(1.0, float(samples))
    var shipments := int(sim.shipped) - start_shipped
    return {
        "storage": String(storage_kind),
        "shipments": shipments,
        "revenue": int(sim.money) - start_money,
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "inbound_arrivals": int(events.get("inbound", 0)),
        "inbound_limit": int(sim._current_inbound_limit()),
        "orders_avg": snappedf(float(sums["orders"]) / divisor, 0.01),
        "inbound_avg": snappedf(float(sums["inbound"]) / divisor, 0.01),
        "rack_avg": snappedf(float(sums["rack"]) / divisor, 0.01),
        "packing_avg": snappedf(float(sums["packing"]) / divisor, 0.01),
        "packed_avg": snappedf(float(sums["packed"]) / divisor, 0.01),
        "order_cap_seconds": snappedf(float(exposure["order_cap"]), 0.1),
        "pick_starved_seconds": snappedf(float(exposure["pick_starved"]), 0.1),
        "rack_full_seconds": snappedf(float(exposure["rack_full"]), 0.1),
        "store_tasks_started": int(events.get("store", 0)),
        "pick_tasks_started": int(events.get("pick", 0)),
        "ship_tasks_started": int(events.get("ship", 0)),
        "autonomous_retrieval_completions": int(sim.autonomous_retrieval_completions),
        "crossdock_completions": int(sim.crossdock_completions),
        "dominant_bottleneck": _dominant_key(bottlenecks),
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "ending_orders": int(sim.open_orders),
        "ending_inbound": int(sim.inbound_queue),
        "ending_rack": int(sim.rack_stock),
        "ending_packing": int(sim.packing_queue),
        "ending_packed": int(sim.packed_queue),
        "switches": switches,
    }


func _compare_against_control(cases: Dictionary) -> Dictionary:
    var control: Dictionary = cases["control"]
    var comparisons: Dictionary = {}
    for candidate_label in CANDIDATES.keys():
        if candidate_label == "control":
            continue
        var result: Dictionary = cases[candidate_label]
        comparisons[candidate_label] = {
            "shipment_delta": int(result.get("shipments", 0)) - int(control.get("shipments", 0)),
            "revenue_delta": int(result.get("revenue", 0)) - int(control.get("revenue", 0)),
            "orders_avg_delta": snappedf(float(result.get("orders_avg", 0.0)) - float(control.get("orders_avg", 0.0)), 0.01),
            "order_cap_seconds_delta": snappedf(float(result.get("order_cap_seconds", 0.0)) - float(control.get("order_cap_seconds", 0.0)), 0.1),
            "inbound_avg_delta": snappedf(float(result.get("inbound_avg", 0.0)) - float(control.get("inbound_avg", 0.0)), 0.01),
            "packed_avg_delta": snappedf(float(result.get("packed_avg", 0.0)) - float(control.get("packed_avg", 0.0)), 0.01),
            "ending_orders": int(result.get("ending_orders", 0)),
            "ending_bottleneck": String(result.get("ending_bottleneck", "stable")),
        }
    return comparisons


func _best_throughput_candidate(cases: Dictionary) -> Dictionary:
    var control_shipments := int(cases["control"].get("shipments", 0))
    var best_label := "control"
    var best_shipments := control_shipments
    for candidate_label in CANDIDATES.keys():
        var shipments := int(cases[candidate_label].get("shipments", 0))
        if shipments > best_shipments:
            best_shipments = shipments
            best_label = String(candidate_label)
    return {
        "candidate": best_label,
        "shipments": best_shipments,
        "shipment_delta": best_shipments - control_shipments,
    }


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
    assert(sim.load_data(data), "post-Annex frontier seed must load")

    for kind in [&"buffer_yard", storage_kind, &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in post-Annex frontier" % String(kind))

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
