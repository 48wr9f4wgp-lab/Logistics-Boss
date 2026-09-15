extends SceneTree

const WorkloadSimScript = preload("res://domain/workload_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const PICK_TASK := 2
const STORAGE_OPTIONS := {
    "fast_pick_rack": &"fast_pick_rack",
    "high_density_rack": &"high_density_rack",
}


func _init() -> void:
    var results: Dictionary = {}
    for label in STORAGE_OPTIONS.keys():
        results[label] = _run_storage_case(StringName(STORAGE_OPTIONS[label]))

    var fast_pick: Dictionary = results["fast_pick_rack"]
    var high_density: Dictionary = results["high_density_rack"]
    var comparison := {
        "shipment_delta_high_density_vs_fast_pick": int(high_density.get("shipments", 0)) - int(fast_pick.get("shipments", 0)),
        "revenue_delta_high_density_vs_fast_pick": int(high_density.get("revenue", 0)) - int(fast_pick.get("revenue", 0)),
        "orders_avg_delta": snappedf(float(high_density.get("orders_avg", 0.0)) - float(fast_pick.get("orders_avg", 0.0)), 0.01),
        "rack_avg_delta": snappedf(float(high_density.get("rack_avg", 0.0)) - float(fast_pick.get("rack_avg", 0.0)), 0.01),
        "pick_started_delta": int(high_density.get("pick_tasks_started", 0)) - int(fast_pick.get("pick_tasks_started", 0)),
        "stockout_seconds_delta": snappedf(float(high_density.get("pick_starved_seconds", 0.0)) - float(fast_pick.get("pick_starved_seconds", 0.0)), 0.01),
    }

    print("RANK3_READINESS_SCOUT %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "storage_cases": results,
        "comparison": comparison,
    }))

    if not _require(int(fast_pick.get("shipments", 0)) > 0 and int(high_density.get("shipments", 0)) > 0, "both storage paths must sustain authoritative shipments"):
        return
    if not _require(int(fast_pick.get("switches", 0)) > 0 and int(high_density.get("switches", 0)) > 0, "scout must exercise forecast-driven staffing"):
        return
    if not _require(int(high_density.get("rack_capacity", 0)) > int(fast_pick.get("rack_capacity", 0)), "High Density must preserve its real capacity advantage"):
        return

    print("Godot Rank 3 readiness scout passed")
    quit(0)


func _run_storage_case(storage_kind: StringName) -> Dictionary:
    var sim: WorkloadWarehouseSim = _prepared_rank2(storage_kind)
    var start_shipped := sim.shipped
    var start_money := sim.money
    var order_sum := 0.0
    var inbound_sum := 0.0
    var rack_sum := 0.0
    var packed_sum := 0.0
    var max_orders := 0
    var max_inbound := 0
    var max_rack := 0
    var pick_starved_seconds := 0.0
    var rack_full_seconds := 0.0
    var samples := 0
    var switches := 0
    var pick_tasks_started := 0
    var last_phase_id := ""

    sim.event_emitted.connect(func(event: Dictionary):
        if String(event.get("type", "")) == "worker_task_started" and int(event.get("task", -1)) == PICK_TASK:
            pick_tasks_started += 1
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
        packed_sum += float(sim.packed_queue)
        max_orders = maxi(max_orders, sim.open_orders)
        max_inbound = maxi(max_inbound, sim.inbound_queue)
        max_rack = maxi(max_rack, sim.rack_stock)
        if sim.open_orders > 0 and sim.rack_stock <= 0:
            pick_starved_seconds += STEP_SECONDS
        if sim.rack_stock >= sim.rack_capacity:
            rack_full_seconds += STEP_SECONDS
        samples += 1

    var divisor := maxf(1.0, float(samples))
    return {
        "storage": String(storage_kind),
        "shipments": sim.shipped - start_shipped,
        "revenue": sim.money - start_money,
        "shipments_per_min": snappedf(float(sim.shipped - start_shipped) / (CYCLE_SECONDS / 60.0), 0.1),
        "orders_avg": snappedf(order_sum / divisor, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "rack_avg": snappedf(rack_sum / divisor, 0.01),
        "packed_avg": snappedf(packed_sum / divisor, 0.01),
        "max_orders": max_orders,
        "max_inbound": max_inbound,
        "max_rack": max_rack,
        "rack_capacity": sim.rack_capacity,
        "pick_starved_seconds": snappedf(pick_starved_seconds, 0.01),
        "rack_full_seconds": snappedf(rack_full_seconds, 0.01),
        "pick_tasks_started": pick_tasks_started,
        "switches": switches,
        "ending_orders": sim.open_orders,
        "ending_inbound": sim.inbound_queue,
        "ending_rack": sim.rack_stock,
        "ending_packed": sim.packed_queue,
    }


func _prepared_rank2(storage_kind: StringName) -> WorkloadWarehouseSim:
    var sim: WorkloadWarehouseSim = WorkloadSimScript.new()
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
    assert(sim.load_data(data), "Rank 3 readiness seed must load")

    for kind in [&"buffer_yard", storage_kind, &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in Rank 3 readiness scout" % String(kind))

    sim.inbound_queue = 6
    sim.rack_stock = mini(sim.rack_capacity, 10)
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
