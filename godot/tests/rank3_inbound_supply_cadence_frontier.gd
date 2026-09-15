extends SceneTree

const CandidateSimScript = preload("res://tests/rank3_inbound_cadence_sim.gd")
const STEP_SECONDS := 0.1
const CYCLE_SECONDS := 510.0
const ORDER_LIMIT := 18
const STORAGE_OPTIONS := [&"fast_pick_rack", &"high_density_rack"]
const ROUTES := ["balanced", "express"]
const CASES := {
    "control": {"multiplier": 1.00, "holding": 0},
    "cadence_92": {"multiplier": 0.92, "holding": 0},
    "cadence_85": {"multiplier": 0.85, "holding": 0},
    "cadence_80": {"multiplier": 0.80, "holding": 0},
    "cadence_85_holding6": {"multiplier": 0.85, "holding": 6},
}


func _init() -> void:
    var matrix: Dictionary = {}
    var comparisons: Dictionary = {}

    for storage_kind in STORAGE_OPTIONS:
        var storage_key := String(storage_kind)
        matrix[storage_key] = {}
        comparisons[storage_key] = {}

        for route in ROUTES:
            var results: Dictionary = {}
            for case_name in CASES.keys():
                results[case_name] = _run_case(storage_kind, route, CASES[case_name])

            matrix[storage_key][route] = results
            comparisons[storage_key][route] = _compare_against_control(results)

            var control: Dictionary = results["control"]
            var cadence_92: Dictionary = results["cadence_92"]
            var cadence_85: Dictionary = results["cadence_85"]
            var cadence_80: Dictionary = results["cadence_80"]
            var holding_85: Dictionary = results["cadence_85_holding6"]

            if not _require(int(control.get("shipments", 0)) > 0, "%s / %s control must ship" % [storage_key, route]):
                return
            if not _require(int(cadence_92.get("potential_inbound", 0)) > int(control.get("potential_inbound", 0)), "%s / %s 0.92 cadence must schedule more inbound" % [storage_key, route]):
                return
            if not _require(int(cadence_85.get("potential_inbound", 0)) > int(cadence_92.get("potential_inbound", 0)), "%s / %s 0.85 cadence must schedule more inbound than 0.92" % [storage_key, route]):
                return
            if not _require(int(cadence_80.get("potential_inbound", 0)) > int(cadence_85.get("potential_inbound", 0)), "%s / %s 0.80 cadence must schedule more inbound than 0.85" % [storage_key, route]):
                return
            if not _require(int(holding_85.get("potential_inbound", 0)) == int(cadence_85.get("potential_inbound", 0)), "%s / %s Holding 6 must not manufacture inbound demand" % [storage_key, route]):
                return
            if not _require(int(holding_85.get("lost_inbound", 0)) <= int(cadence_85.get("lost_inbound", 0)), "%s / %s Holding 6 must not increase inbound loss" % [storage_key, route]):
                return

    print("RANK3_INBOUND_SUPPLY_CADENCE_FRONTIER %s" % JSON.stringify({
        "cycle_seconds": CYCLE_SECONDS,
        "operating_policy": "forecast_adaptive_staffing",
        "fixed_intake": "buffer_yard + receiving_annex",
        "fixed_packing": "fast_pack_cell",
        "cases": CASES,
        "matrix": matrix,
        "comparisons_vs_control": comparisons,
    }))
    print("Godot Rank 3 inbound supply cadence frontier passed")
    quit(0)


func _run_case(storage_kind: StringName, route: String, config: Dictionary) -> Dictionary:
    var sim = _prepared_rank3(storage_kind, route)
    sim.configure_inbound_supply(float(config.get("multiplier", 1.0)), int(config.get("holding", 0)))

    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var profile: Dictionary = sim.routing_profile(route)
    var sums := {"inbound": 0.0, "orders": 0.0, "rack": 0.0, "packing": 0.0, "packed": 0.0, "holding": 0.0}
    var maxima := {"inbound": 0, "orders": 0, "rack": 0, "packing": 0, "packed": 0, "holding": 0}
    var exposure := {"inbound_high": 0.0, "order_cap": 0.0, "pick_starved": 0.0, "packing_pressure": 0.0, "packed_pressure": 0.0}
    var bottlenecks: Dictionary = {}
    var last_phase_id := ""
    var switches := 0
    var samples := 0

    for _i in int(ceil(CYCLE_SECONDS / STEP_SECONDS)):
        var phase_id := String(sim.workload_wave().get("phase_id", ""))
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
        sums["holding"] = float(sums["holding"]) + float(sim.holding_queue)

        maxima["inbound"] = maxi(int(maxima["inbound"]), int(sim.inbound_queue))
        maxima["orders"] = maxi(int(maxima["orders"]), int(sim.open_orders))
        maxima["rack"] = maxi(int(maxima["rack"]), int(sim.rack_stock))
        maxima["packing"] = maxi(int(maxima["packing"]), int(sim.packing_queue))
        maxima["packed"] = maxi(int(maxima["packed"]), int(sim.packed_queue))
        maxima["holding"] = maxi(int(maxima["holding"]), int(sim.holding_queue))

        if float(sim.inbound_queue) >= float(sim._current_inbound_limit()) * 0.8:
            exposure["inbound_high"] = float(exposure["inbound_high"]) + STEP_SECONDS
        if int(sim.open_orders) >= ORDER_LIMIT:
            exposure["order_cap"] = float(exposure["order_cap"]) + STEP_SECONDS
        if int(sim.open_orders) > 0 and int(sim.rack_stock) <= 0:
            exposure["pick_starved"] = float(exposure["pick_starved"]) + STEP_SECONDS
        if int(sim.packing_queue) >= 3:
            exposure["packing_pressure"] = float(exposure["packing_pressure"]) + STEP_SECONDS
        if int(sim.packed_queue) >= 4:
            exposure["packed_pressure"] = float(exposure["packed_pressure"]) + STEP_SECONDS

        var key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[key] = int(bottlenecks.get(key, 0)) + 1
        samples += 1

    var shipments := int(sim.shipped) - start_shipped
    var revenue := int(sim.money) - start_money
    var unit_value := int(profile.get("unit_value", 0))
    var facility_entries := int(sim.direct_inbound_entries) + int(sim.released_inbound_arrivals)
    var divisor := maxf(1.0, float(samples))

    if not _require(revenue == shipments * unit_value, "%s / %s must preserve exact route revenue" % [String(storage_kind), route]):
        return {}
    if not _require(int(sim.potential_inbound_arrivals) == int(sim.direct_inbound_entries) + int(sim.held_inbound_arrivals) + int(sim.lost_inbound_arrivals), "%s / %s inbound accounting must balance" % [String(storage_kind), route]):
        return {}

    return {
        "storage": String(storage_kind),
        "route": route,
        "cadence_multiplier": float(config.get("multiplier", 1.0)),
        "holding_capacity": int(config.get("holding", 0)),
        "unit_value": unit_value,
        "shipments": shipments,
        "shipments_per_min": snappedf(float(shipments) / (CYCLE_SECONDS / 60.0), 0.1),
        "revenue": revenue,
        "potential_inbound": int(sim.potential_inbound_arrivals),
        "facility_entries": facility_entries,
        "direct_inbound": int(sim.direct_inbound_entries),
        "held_inbound": int(sim.held_inbound_arrivals),
        "released_inbound": int(sim.released_inbound_arrivals),
        "lost_inbound": int(sim.lost_inbound_arrivals),
        "holding_end": int(sim.holding_queue),
        "holding_max": int(maxima["holding"]),
        "inbound_avg": snappedf(float(sums["inbound"]) / divisor, 0.01),
        "orders_avg": snappedf(float(sums["orders"]) / divisor, 0.01),
        "rack_avg": snappedf(float(sums["rack"]) / divisor, 0.01),
        "packing_avg": snappedf(float(sums["packing"]) / divisor, 0.01),
        "packed_avg": snappedf(float(sums["packed"]) / divisor, 0.01),
        "holding_avg": snappedf(float(sums["holding"]) / divisor, 0.01),
        "inbound_max": int(maxima["inbound"]),
        "orders_max": int(maxima["orders"]),
        "rack_max": int(maxima["rack"]),
        "packing_max": int(maxima["packing"]),
        "packed_max": int(maxima["packed"]),
        "inbound_high_seconds": snappedf(float(exposure["inbound_high"]), 0.1),
        "order_cap_seconds": snappedf(float(exposure["order_cap"]), 0.1),
        "pick_starved_seconds": snappedf(float(exposure["pick_starved"]), 0.1),
        "packing_pressure_seconds": snappedf(float(exposure["packing_pressure"]), 0.1),
        "packed_pressure_seconds": snappedf(float(exposure["packed_pressure"]), 0.1),
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
    assert(sim.load_data(data), "inbound cadence frontier seed must load")
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


func _compare_against_control(results: Dictionary) -> Dictionary:
    var control: Dictionary = results["control"]
    var comparisons: Dictionary = {}
    for case_name in CASES.keys():
        if case_name == "control":
            continue
        var result: Dictionary = results[case_name]
        comparisons[case_name] = {
            "potential_inbound_delta": int(result.get("potential_inbound", 0)) - int(control.get("potential_inbound", 0)),
            "facility_entry_delta": int(result.get("facility_entries", 0)) - int(control.get("facility_entries", 0)),
            "lost_inbound_delta": int(result.get("lost_inbound", 0)) - int(control.get("lost_inbound", 0)),
            "shipment_delta": int(result.get("shipments", 0)) - int(control.get("shipments", 0)),
            "revenue_delta": int(result.get("revenue", 0)) - int(control.get("revenue", 0)),
            "pick_starved_seconds_delta": snappedf(float(result.get("pick_starved_seconds", 0.0)) - float(control.get("pick_starved_seconds", 0.0)), 0.1),
            "packed_pressure_seconds_delta": snappedf(float(result.get("packed_pressure_seconds", 0.0)) - float(control.get("packed_pressure_seconds", 0.0)), 0.1),
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
