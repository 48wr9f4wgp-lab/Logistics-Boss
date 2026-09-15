extends SceneTree

const OrchestrationSimScript = preload("res://tests/rank3_receiving_orchestration_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const RECEIVING_BONUS := 14
const HOLDING_CAPACITIES := [0, 6, 12, 18]
const STORAGE_OPTIONS := {
    "fast_pick_rack": &"fast_pick_rack",
    "high_density_rack": &"high_density_rack",
}


func _init() -> void:
    var storage_results: Dictionary = {}
    for storage_label in STORAGE_OPTIONS.keys():
        var storage_kind: StringName = STORAGE_OPTIONS[storage_label]
        var cases: Dictionary = {}
        for capacity in HOLDING_CAPACITIES:
            cases[str(capacity)] = _run_case(storage_kind, capacity)
        storage_results[storage_label] = cases

        var control: Dictionary = cases["0"]
        if not _require(int(control.get("lost_inbound", 0)) > 0, "%s control must prove peak inbound loss exists after Annex" % storage_label):
            return
        for capacity in [6, 12, 18]:
            var candidate: Dictionary = cases[str(capacity)]
            if not _require(int(candidate.get("potential_inbound", 0)) == int(control.get("potential_inbound", 0)), "%s holding case must preserve scheduled arrival demand" % storage_label):
                return
            if not _require(int(candidate.get("lost_inbound", 0)) <= int(control.get("lost_inbound", 0)), "%s holding must not increase lost arrivals" % storage_label):
                return

    var recommendation := _recommend_capacity(storage_results)
    print("RANK3_RECEIVING_ORCHESTRATION_SCOUT %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "receiving_annex_bonus": RECEIVING_BONUS,
        "holding_capacities": HOLDING_CAPACITIES,
        "storage_results": storage_results,
        "recommendation": recommendation,
    }))
    print("Godot Rank 3 receiving orchestration scout passed")
    quit(0)


func _run_case(storage_kind: StringName, holding_capacity: int) -> Dictionary:
    var sim = _prepared_case(storage_kind, holding_capacity)
    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var inbound_sum := 0.0
    var orders_sum := 0.0
    var holding_sum := 0.0
    var samples := 0
    var last_phase_id := ""
    var switches := 0

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
        inbound_sum += float(sim.inbound_queue)
        orders_sum += float(sim.open_orders)
        holding_sum += float(sim.holding_queue)
        samples += 1

    var shipments := int(sim.shipped) - start_shipped
    var divisor := maxf(1.0, float(samples))
    return {
        "storage": String(storage_kind),
        "holding_capacity": holding_capacity,
        "shipments": shipments,
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "revenue": int(sim.money) - start_money,
        "potential_inbound": int(sim.potential_inbound_arrivals),
        "direct_entries": int(sim.direct_inbound_entries),
        "held_arrivals": int(sim.held_inbound_arrivals),
        "released_arrivals": int(sim.released_inbound_arrivals),
        "facility_entries": int(sim.direct_inbound_entries + sim.released_inbound_arrivals),
        "lost_inbound": int(sim.lost_inbound_arrivals),
        "ending_holding": int(sim.holding_queue),
        "max_holding": int(sim.max_holding_queue),
        "holding_avg": snappedf(holding_sum / divisor, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "orders_avg": snappedf(orders_sum / divisor, 0.01),
        "ending_orders": int(sim.open_orders),
        "ending_inbound": int(sim.inbound_queue),
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "switches": switches,
    }


func _prepared_case(storage_kind: StringName, holding_capacity: int):
    var sim = OrchestrationSimScript.new()
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
    assert(sim.load_data(data), "receiving orchestration seed must load")

    for kind in [&"buffer_yard", storage_kind, &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in receiving orchestration scout" % String(kind))

    sim.configure_candidate(1.0, 1.0, 1.0, 0.0, 0.0, RECEIVING_BONUS)
    sim.configure_receiving_orchestration(holding_capacity)
    sim.inbound_queue = 6
    sim.rack_stock = mini(int(sim.rack_capacity), 10)
    sim.packing_queue = 3
    sim.packed_queue = 4
    sim.open_orders = 6
    return sim


func _recommend_capacity(storage_results: Dictionary) -> Dictionary:
    for capacity in [6, 12, 18]:
        var qualifies := true
        var minimum_gain := 1.0
        var total_lost := 0
        for storage_label in STORAGE_OPTIONS.keys():
            var cases: Dictionary = storage_results[storage_label]
            var control: Dictionary = cases["0"]
            var candidate: Dictionary = cases[str(capacity)]
            var control_shipments := maxf(1.0, float(control.get("shipments", 0)))
            var gain := (float(candidate.get("shipments", 0)) / control_shipments) - 1.0
            minimum_gain = minf(minimum_gain, gain)
            total_lost += int(candidate.get("lost_inbound", 0))
            if gain < 0.05:
                qualifies = false
        if qualifies:
            return {
                "qualified": true,
                "holding_capacity": capacity,
                "minimum_shipment_gain": snappedf(minimum_gain, 0.001),
                "combined_lost_inbound": total_lost,
            }
    return {
        "qualified": false,
        "holding_capacity": 0,
        "minimum_shipment_gain": 0.0,
        "combined_lost_inbound": -1,
    }


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
