extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const ORDER_LIMIT := 18
const STORAGE_OPTIONS := [&"fast_pick_rack", &"high_density_rack"]
const ROUTES := ["balanced", "express", "consolidated"]


func _init() -> void:
    var storage_report: Dictionary = {}
    var comparisons: Dictionary = {}

    for storage_kind in STORAGE_OPTIONS:
        var route_results: Dictionary = {}
        for route in ROUTES:
            var result := _run_case(storage_kind, route)
            route_results[route] = result

            if not _require(int(result.get("shipments", 0)) > 0, "%s / %s must ship during a full workload cycle" % [String(storage_kind), route]):
                return
            if not _require(int(result.get("inbound_limit", 0)) >= 42, "%s / %s must include Buffer Yard + Receiving Annex capacity" % [String(storage_kind), route]):
                return
            if not _require(int(result.get("revenue", -1)) == int(result.get("shipments", 0)) * int(result.get("unit_value", 0)), "%s / %s must generate route revenue exactly once" % [String(storage_kind), route]):
                return
            if not _require(int(result.get("switches", 0)) >= 2, "%s / %s adaptive operation must execute staffing changes" % [String(storage_kind), route]):
                return

        storage_report[String(storage_kind)] = route_results
        comparisons[String(storage_kind)] = _compare_routes(route_results)

    print("RANK3_POST_ROUTING_FRONTIER %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "operating_policy": "forecast_adaptive_staffing",
        "intake": "buffer_yard + receiving_annex",
        "packing": "fast_pack_cell",
        "storage_results": storage_report,
        "route_comparisons_vs_balanced": comparisons,
    }))
    print("Godot Rank 3 post-routing frontier passed")
    quit(0)


func _run_case(storage_kind: StringName, route: String) -> Dictionary:
    var sim = _prepared_rank3(storage_kind, route)
    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var profile: Dictionary = sim.routing_profile(route)

    var sums := {
        "inbound": 0.0,
        "orders": 0.0,
        "rack": 0.0,
        "packing": 0.0,
        "packed": 0.0,
    }
    var maxima := {
        "inbound": 0,
        "orders": 0,
        "rack": 0,
        "packing": 0,
        "packed": 0,
    }
    var exposure := {
        "order_cap": 0.0,
        "inbound_high": 0.0,
        "pick_starved": 0.0,
        "packing_pressure": 0.0,
        "packed_pressure": 0.0,
        "dispatch_wait": 0.0,
    }
    var events := {
        "inbound_arrivals": 0,
        "ship_events": 0,
        "shipped_parcels": 0,
    }
    var bottlenecks: Dictionary = {}
    var last_phase_id := ""
    var switches := 0
    var samples := 0

    sim.event_emitted.connect(func(event: Dictionary):
        var event_type := String(event.get("type", ""))
        if event_type == "inbound_arrival":
            events["inbound_arrivals"] = int(events.get("inbound_arrivals", 0)) + 1
        elif event_type == "shipment":
            events["ship_events"] = int(events.get("ship_events", 0)) + 1
            events["shipped_parcels"] = int(events.get("shipped_parcels", 0)) + int(event.get("count", 1))
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

        sums["inbound"] = float(sums["inbound"]) + float(sim.inbound_queue)
        sums["orders"] = float(sums["orders"]) + float(sim.open_orders)
        sums["rack"] = float(sums["rack"]) + float(sim.rack_stock)
        sums["packing"] = float(sums["packing"]) + float(sim.packing_queue)
        sums["packed"] = float(sums["packed"]) + float(sim.packed_queue)

        maxima["inbound"] = maxi(int(maxima["inbound"]), int(sim.inbound_queue))
        maxima["orders"] = maxi(int(maxima["orders"]), int(sim.open_orders))
        maxima["rack"] = maxi(int(maxima["rack"]), int(sim.rack_stock))
        maxima["packing"] = maxi(int(maxima["packing"]), int(sim.packing_queue))
        maxima["packed"] = maxi(int(maxima["packed"]), int(sim.packed_queue))

        if int(sim.open_orders) >= ORDER_LIMIT:
            exposure["order_cap"] = float(exposure["order_cap"]) + STEP_SECONDS
        if float(sim.inbound_queue) >= float(sim._current_inbound_limit()) * 0.8:
            exposure["inbound_high"] = float(exposure["inbound_high"]) + STEP_SECONDS
        if int(sim.open_orders) > 0 and int(sim.rack_stock) <= 0:
            exposure["pick_starved"] = float(exposure["pick_starved"]) + STEP_SECONDS
        if int(sim.packing_queue) >= 3:
            exposure["packing_pressure"] = float(exposure["packing_pressure"]) + STEP_SECONDS
        if int(sim.packed_queue) >= 4:
            exposure["packed_pressure"] = float(exposure["packed_pressure"]) + STEP_SECONDS
        if int(sim.packed_queue) > 0 and not sim._routing_can_dispatch():
            exposure["dispatch_wait"] = float(exposure["dispatch_wait"]) + STEP_SECONDS

        var bottleneck_key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[bottleneck_key] = int(bottlenecks.get(bottleneck_key, 0)) + 1
        samples += 1

    var divisor := maxf(1.0, float(samples))
    var shipments := int(sim.shipped) - start_shipped
    var revenue := int(sim.money) - start_money
    return {
        "storage": String(storage_kind),
        "route": route,
        "unit_value": int(profile.get("unit_value", 0)),
        "batch_size": int(profile.get("batch_size", 1)),
        "shipments": shipments,
        "revenue": revenue,
        "revenue_per_parcel": snappedf(float(revenue) / maxf(1.0, float(shipments)), 0.1),
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "inbound_arrivals": int(events.get("inbound_arrivals", 0)),
        "ship_events": int(events.get("ship_events", 0)),
        "event_shipped_parcels": int(events.get("shipped_parcels", 0)),
        "inbound_limit": int(sim._current_inbound_limit()),
        "rack_capacity": int(sim.rack_capacity),
        "inbound_avg": snappedf(float(sums["inbound"]) / divisor, 0.01),
        "orders_avg": snappedf(float(sums["orders"]) / divisor, 0.01),
        "rack_avg": snappedf(float(sums["rack"]) / divisor, 0.01),
        "packing_avg": snappedf(float(sums["packing"]) / divisor, 0.01),
        "packed_avg": snappedf(float(sums["packed"]) / divisor, 0.01),
        "inbound_max": int(maxima["inbound"]),
        "orders_max": int(maxima["orders"]),
        "rack_max": int(maxima["rack"]),
        "packing_max": int(maxima["packing"]),
        "packed_max": int(maxima["packed"]),
        "order_cap_seconds": snappedf(float(exposure["order_cap"]), 0.1),
        "inbound_high_seconds": snappedf(float(exposure["inbound_high"]), 0.1),
        "pick_starved_seconds": snappedf(float(exposure["pick_starved"]), 0.1),
        "packing_pressure_seconds": snappedf(float(exposure["packing_pressure"]), 0.1),
        "packed_pressure_seconds": snappedf(float(exposure["packed_pressure"]), 0.1),
        "dispatch_wait_seconds": snappedf(float(exposure["dispatch_wait"]), 0.1),
        "dominant_bottleneck": _dominant_key(bottlenecks),
        "bottleneck_share": _bottleneck_share(bottlenecks, samples),
        "ending_bottleneck": String(sim.bottleneck().get("key", "stable")),
        "ending_inbound": int(sim.inbound_queue),
        "ending_orders": int(sim.open_orders),
        "ending_rack": int(sim.rack_stock),
        "ending_packing": int(sim.packing_queue),
        "ending_packed": int(sim.packed_queue),
        "switches": switches,
    }


func _prepared_rank3(storage_kind: StringName, route: String):
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 6
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 0
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
    data["receiving_annex_unlocked"] = true
    data["active_routing_mode"] = route
    data["rack_capacity"] = 12 if storage_kind == &"fast_pick_rack" else 20
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": storage_kind == &"fast_pick_rack",
        "high_density_rack": storage_kind == &"high_density_rack",
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "post-routing frontier seed must load")
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


func _compare_routes(route_results: Dictionary) -> Dictionary:
    var balanced: Dictionary = route_results["balanced"]
    var comparisons: Dictionary = {}
    for route in ["express", "consolidated"]:
        var result: Dictionary = route_results[route]
        comparisons[route] = {
            "shipment_delta": int(result.get("shipments", 0)) - int(balanced.get("shipments", 0)),
            "revenue_delta": int(result.get("revenue", 0)) - int(balanced.get("revenue", 0)),
            "orders_avg_delta": snappedf(float(result.get("orders_avg", 0.0)) - float(balanced.get("orders_avg", 0.0)), 0.01),
            "packed_avg_delta": snappedf(float(result.get("packed_avg", 0.0)) - float(balanced.get("packed_avg", 0.0)), 0.01),
            "order_cap_seconds_delta": snappedf(float(result.get("order_cap_seconds", 0.0)) - float(balanced.get("order_cap_seconds", 0.0)), 0.1),
            "packed_pressure_seconds_delta": snappedf(float(result.get("packed_pressure_seconds", 0.0)) - float(balanced.get("packed_pressure_seconds", 0.0)), 0.1),
            "dominant_bottleneck": String(result.get("dominant_bottleneck", "stable")),
            "ending_bottleneck": String(result.get("ending_bottleneck", "stable")),
        }
    return comparisons


func _dominant_key(counts: Dictionary) -> String:
    var best_key := "stable"
    var best_count := -1
    for key in counts.keys():
        var count := int(counts[key])
        if count > best_count:
            best_count = count
            best_key = String(key)
    return best_key


func _bottleneck_share(counts: Dictionary, samples: int) -> Dictionary:
    var result: Dictionary = {}
    var divisor := maxf(1.0, float(samples))
    for key in counts.keys():
        result[String(key)] = snappedf(float(counts[key]) / divisor, 0.001)
    return result


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
