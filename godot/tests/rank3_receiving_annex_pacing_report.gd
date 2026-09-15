extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const STORAGE_OPTIONS := [&"fast_pick_rack", &"high_density_rack"]


func _init() -> void:
    var report: Dictionary = {}
    for storage_kind in STORAGE_OPTIONS:
        var control := _run_case(storage_kind, false)
        var annex := _run_case(storage_kind, true)
        var shipment_delta := int(annex.get("shipments", 0)) - int(control.get("shipments", 0))
        var revenue_delta := int(annex.get("revenue", 0)) - int(control.get("revenue", 0))
        var pct := float(shipment_delta) / maxf(1.0, float(control.get("shipments", 0)))
        report[String(storage_kind)] = {
            "control": control,
            "annex": annex,
            "shipment_delta": shipment_delta,
            "shipment_pct": snappedf(pct, 0.001),
            "revenue_delta": revenue_delta,
        }
        if not _require(int(control.get("shipments", 0)) > 0, "%s control must ship" % String(storage_kind)):
            return
        if not _require(int(annex.get("inbound_arrivals", 0)) > int(control.get("inbound_arrivals", 0)), "%s Annex must accept additional peak inbound parcels" % String(storage_kind)):
            return
        if not _require(shipment_delta > 0, "%s Annex must improve authoritative shipments" % String(storage_kind)):
            return
        if not _require(pct >= 0.05, "%s Annex must preserve at least a 5%% cycle throughput gain" % String(storage_kind)):
            return

    print("RANK3_RECEIVING_ANNEX_PACING %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "annex_cost": Rank3WarehouseSim.RECEIVING_ANNEX_COST,
        "capacity_bonus": Rank3WarehouseSim.RECEIVING_ANNEX_CAPACITY_BONUS,
        "storage_results": report,
    }))
    print("Godot Rank 3 Receiving Annex pacing report passed")
    quit(0)


func _run_case(storage_kind: StringName, annex_owned: bool) -> Dictionary:
    var sim = _prepared_rank3(storage_kind, annex_owned)
    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var observed := {"inbound_arrivals": 0}
    var order_sum := 0.0
    var inbound_sum := 0.0
    var packing_sum := 0.0
    var packed_sum := 0.0
    var max_inbound := 0
    var last_phase_id := ""
    var switches := 0

    sim.event_emitted.connect(func(event: Dictionary):
        if String(event.get("type", "")) == "inbound_arrival":
            observed["inbound_arrivals"] = int(observed.get("inbound_arrivals", 0)) + 1
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
        packing_sum += float(sim.packing_queue)
        packed_sum += float(sim.packed_queue)
        max_inbound = maxi(max_inbound, int(sim.inbound_queue))
        samples += 1

    var divisor := maxf(1.0, float(samples))
    var shipments := int(sim.shipped) - start_shipped
    return {
        "storage": String(storage_kind),
        "annex_owned": annex_owned,
        "shipments": shipments,
        "revenue": int(sim.money) - start_money,
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "inbound_arrivals": int(observed.get("inbound_arrivals", 0)),
        "inbound_limit": int(sim._current_inbound_limit()),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "orders_avg": snappedf(order_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "packed_avg": snappedf(packed_sum / divisor, 0.01),
        "max_inbound": max_inbound,
        "ending_orders": int(sim.open_orders),
        "ending_inbound": int(sim.inbound_queue),
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "switches": switches,
    }


func _prepared_rank3(storage_kind: StringName, annex_owned: bool):
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 5
    data["facility_rank"] = 3
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
    data["rack_stock"] = 10
    data["packing_queue"] = 3
    data["packed_queue"] = 4
    data["open_orders"] = 6
    data["receiving_annex_unlocked"] = annex_owned
    data["rack_capacity"] = 12 if storage_kind == &"fast_pick_rack" else 20
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": storage_kind == &"fast_pick_rack",
        "high_density_rack": storage_kind == &"high_density_rack",
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic Rank 3 pacing state must load")
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
