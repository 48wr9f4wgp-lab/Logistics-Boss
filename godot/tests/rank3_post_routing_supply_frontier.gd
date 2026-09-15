extends SceneTree

const CandidateSimScript = preload("res://tests/rank3_supply_candidate_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const STORAGE_OPTIONS := [&"fast_pick_rack", &"high_density_rack"]
const ROUTES := ["balanced", "express"]
const CANDIDATES := {
    "control": {
        "store_multiplier": 1.0,
        "replenishment_cycle": 0.0,
        "demand_buffer_capacity": 0,
    },
    "putaway_assist": {
        "store_multiplier": 0.70,
        "replenishment_cycle": 0.0,
        "demand_buffer_capacity": 0,
    },
    "replenishment_lane": {
        "store_multiplier": 1.0,
        "replenishment_cycle": 3.2,
        "demand_buffer_capacity": 0,
    },
    "demand_buffer": {
        "store_multiplier": 1.0,
        "replenishment_cycle": 0.0,
        "demand_buffer_capacity": 32,
    },
    "combined_supply_control": {
        "store_multiplier": 1.0,
        "replenishment_cycle": 3.2,
        "demand_buffer_capacity": 32,
    },
}


func _init() -> void:
    var matrix: Dictionary = {}
    var comparisons: Dictionary = {}

    for storage_kind in STORAGE_OPTIONS:
        var storage_key := String(storage_kind)
        matrix[storage_key] = {}
        comparisons[storage_key] = {}

        for route in ROUTES:
            var cases: Dictionary = {}
            for candidate_name in CANDIDATES.keys():
                cases[candidate_name] = _run_case(storage_kind, route, CANDIDATES[candidate_name])
            matrix[storage_key][route] = cases
            comparisons[storage_key][route] = _compare_against_control(cases)

            var control: Dictionary = cases["control"]
            var replenishment: Dictionary = cases["replenishment_lane"]
            var demand_buffer: Dictionary = cases["demand_buffer"]
            var combined: Dictionary = cases["combined_supply_control"]

            if not _require(int(control.get("shipments", 0)) > 0, "%s / %s control must ship" % [storage_key, route]):
                return
            if not _require(int(control.get("lost_order_arrivals", 0)) > 0, "%s / %s control must expose dropped demand at the order cap" % [storage_key, route]):
                return
            if not _require(int(replenishment.get("replenishment_completions", 0)) > 0, "%s / %s replenishment sensitivity must execute" % [storage_key, route]):
                return
            if not _require(int(demand_buffer.get("captured_order_arrivals", 0)) > 0, "%s / %s demand buffer must capture capped arrivals" % [storage_key, route]):
                return
            if not _require(int(demand_buffer.get("lost_order_arrivals", 0)) < int(control.get("lost_order_arrivals", 0)), "%s / %s demand buffer must reduce dropped demand" % [storage_key, route]):
                return
            if not _require(int(combined.get("captured_order_arrivals", 0)) > 0 and int(combined.get("replenishment_completions", 0)) > 0, "%s / %s combined sensitivity must exercise both mechanisms" % [storage_key, route]):
                return

    print("RANK3_POST_ROUTING_SUPPLY_FRONTIER %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "storage_routes": matrix,
        "comparisons_vs_control": comparisons,
        "candidate_assumptions": CANDIDATES,
    }))
    print("Godot Rank 3 post-routing supply frontier passed")
    quit(0)


func _run_case(storage_kind: StringName, route: String, candidate: Dictionary) -> Dictionary:
    var sim = _prepared_rank3(storage_kind, route)
    sim.configure_supply_candidate(
        float(candidate.get("store_multiplier", 1.0)),
        float(candidate.get("replenishment_cycle", 0.0)),
        int(candidate.get("demand_buffer_capacity", 0))
    )

    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var route_profile: Dictionary = sim.routing_profile(route)
    var observed := {
        "direct_order_arrivals": 0,
        "inbound_arrivals": 0,
        "shipment_events": 0,
        "event_shipped_parcels": 0,
    }
    var sums := {
        "inbound": 0.0,
        "orders": 0.0,
        "pending_orders": 0.0,
        "rack": 0.0,
        "packing": 0.0,
        "packed": 0.0,
    }
    var exposure := {
        "order_cap": 0.0,
        "pick_starved": 0.0,
        "inbound_high": 0.0,
        "packed_pressure": 0.0,
    }
    var maxima := {
        "pending_orders": 0,
        "rack": 0,
        "packed": 0,
    }
    var bottlenecks: Dictionary = {}
    var last_phase_id := ""
    var switches := 0
    var samples := 0

    sim.event_emitted.connect(func(event: Dictionary):
        match String(event.get("type", "")):
            "order_arrival":
                observed["direct_order_arrivals"] = int(observed["direct_order_arrivals"]) + 1
            "inbound_arrival":
                observed["inbound_arrivals"] = int(observed["inbound_arrivals"]) + 1
            "shipment":
                observed["shipment_events"] = int(observed["shipment_events"]) + 1
                observed["event_shipped_parcels"] = int(observed["event_shipped_parcels"]) + int(event.get("count", 1))
    )

    for _i in int(ceil(CYCLE_SECONDS / STEP_SECONDS)):
        var wave: Dictionary = sim.workload_wave()
        var phase_id := String(wave.get("phase_id", ""))
        if phase_id != last_phase_id:
            last_phase_id = phase_id
            var target := _adaptive_plan_for_phase(phase_id)
            if not target.is_empty() and target != sim.staffing_plan and sim.staffing_cooldown <= 0.001:
                var result: Dictionary = sim.set_staffing_plan(target)
                if bool(result.get("ok", false)):
                    switches += 1

        sim.step(STEP_SECONDS)

        sums["inbound"] = float(sums["inbound"]) + float(sim.inbound_queue)
        sums["orders"] = float(sums["orders"]) + float(sim.open_orders)
        sums["pending_orders"] = float(sums["pending_orders"]) + float(sim.pending_orders)
        sums["rack"] = float(sums["rack"]) + float(sim.rack_stock)
        sums["packing"] = float(sums["packing"]) + float(sim.packing_queue)
        sums["packed"] = float(sums["packed"]) + float(sim.packed_queue)

        maxima["pending_orders"] = maxi(int(maxima["pending_orders"]), int(sim.pending_orders))
        maxima["rack"] = maxi(int(maxima["rack"]), int(sim.rack_stock))
        maxima["packed"] = maxi(int(maxima["packed"]), int(sim.packed_queue))

        if int(sim.open_orders) >= WarehouseSim.ORDER_LIMIT:
            exposure["order_cap"] = float(exposure["order_cap"]) + STEP_SECONDS
        if int(sim.open_orders) > 0 and int(sim.rack_stock) <= 0:
            exposure["pick_starved"] = float(exposure["pick_starved"]) + STEP_SECONDS
        if float(sim.inbound_queue) >= float(sim._current_inbound_limit()) * 0.8:
            exposure["inbound_high"] = float(exposure["inbound_high"]) + STEP_SECONDS
        if int(sim.packed_queue) >= 4:
            exposure["packed_pressure"] = float(exposure["packed_pressure"]) + STEP_SECONDS

        var bottleneck_key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[bottleneck_key] = int(bottlenecks.get(bottleneck_key, 0)) + 1
        samples += 1

    var divisor := maxf(1.0, float(samples))
    var shipments := int(sim.shipped) - start_shipped
    var revenue := int(sim.money) - start_money
    var demand_attempts := int(observed["direct_order_arrivals"]) + int(sim.captured_order_arrivals) + int(sim.lost_order_arrivals)
    return {
        "storage": String(storage_kind),
        "route": route,
        "unit_value": int(route_profile.get("unit_value", 0)),
        "shipments": shipments,
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "revenue": revenue,
        "revenue_per_parcel": snappedf(float(revenue) / maxf(1.0, float(shipments)), 0.1),
        "direct_order_arrivals": int(observed["direct_order_arrivals"]),
        "captured_order_arrivals": int(sim.captured_order_arrivals),
        "released_order_arrivals": int(sim.released_order_arrivals),
        "lost_order_arrivals": int(sim.lost_order_arrivals),
        "demand_attempts": demand_attempts,
        "ending_pending_orders": int(sim.pending_orders),
        "pending_orders_avg": snappedf(float(sums["pending_orders"]) / divisor, 0.01),
        "pending_orders_max": int(maxima["pending_orders"]),
        "inbound_arrivals": int(observed["inbound_arrivals"]),
        "inbound_avg": snappedf(float(sums["inbound"]) / divisor, 0.01),
        "orders_avg": snappedf(float(sums["orders"]) / divisor, 0.01),
        "rack_avg": snappedf(float(sums["rack"]) / divisor, 0.01),
        "packing_avg": snappedf(float(sums["packing"]) / divisor, 0.01),
        "packed_avg": snappedf(float(sums["packed"]) / divisor, 0.01),
        "rack_max": int(maxima["rack"]),
        "packed_max": int(maxima["packed"]),
        "order_cap_seconds": snappedf(float(exposure["order_cap"]), 0.1),
        "pick_starved_seconds": snappedf(float(exposure["pick_starved"]), 0.1),
        "inbound_high_seconds": snappedf(float(exposure["inbound_high"]), 0.1),
        "packed_pressure_seconds": snappedf(float(exposure["packed_pressure"]), 0.1),
        "replenishment_starts": int(sim.replenishment_starts),
        "replenishment_completions": int(sim.replenishment_completions),
        "shipment_events": int(observed["shipment_events"]),
        "event_shipped_parcels": int(observed["event_shipped_parcels"]),
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
    var sim = CandidateSimScript.new()
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
    assert(sim.load_data(data), "post-routing supply frontier seed must load")
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


func _compare_against_control(cases: Dictionary) -> Dictionary:
    var control: Dictionary = cases["control"]
    var result: Dictionary = {}
    for candidate_name in CANDIDATES.keys():
        if candidate_name == "control":
            continue
        var candidate: Dictionary = cases[candidate_name]
        result[candidate_name] = {
            "shipment_delta": int(candidate.get("shipments", 0)) - int(control.get("shipments", 0)),
            "revenue_delta": int(candidate.get("revenue", 0)) - int(control.get("revenue", 0)),
            "lost_order_delta": int(candidate.get("lost_order_arrivals", 0)) - int(control.get("lost_order_arrivals", 0)),
            "pick_starved_seconds_delta": snappedf(float(candidate.get("pick_starved_seconds", 0.0)) - float(control.get("pick_starved_seconds", 0.0)), 0.1),
            "inbound_avg_delta": snappedf(float(candidate.get("inbound_avg", 0.0)) - float(control.get("inbound_avg", 0.0)), 0.01),
            "orders_avg_delta": snappedf(float(candidate.get("orders_avg", 0.0)) - float(control.get("orders_avg", 0.0)), 0.01),
            "packed_avg_delta": snappedf(float(candidate.get("packed_avg", 0.0)) - float(control.get("packed_avg", 0.0)), 0.01),
            "dominant_bottleneck": String(candidate.get("dominant_bottleneck", "stable")),
            "ending_bottleneck": String(candidate.get("ending_bottleneck", "stable")),
        }
    return result


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
