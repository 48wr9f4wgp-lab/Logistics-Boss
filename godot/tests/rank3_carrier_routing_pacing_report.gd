extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const BACKLOG_SECONDS := 30.0
const TRICKLE_SECONDS := 35.0


func _init() -> void:
    var balanced := _run_backlog_case("balanced")
    var express := _run_backlog_case("express")
    var consolidated := _run_backlog_case("consolidated")

    if not _require(int(express.get("shipments", 0)) > int(balanced.get("shipments", 0)), "Express Dispatch must improve outbound throughput under a sustained packed backlog"):
        return
    if not _require(float(express.get("revenue_per_shipment", 0.0)) < float(balanced.get("revenue_per_shipment", 0.0)), "Express Dispatch must trade shipment margin for speed"):
        return
    if not _require(float(consolidated.get("revenue_per_shipment", 0.0)) > float(balanced.get("revenue_per_shipment", 0.0)), "Consolidated Linehaul must improve value per shipped parcel"):
        return
    if not _require(int(consolidated.get("shipments", 0)) > int(balanced.get("shipments", 0)), "Consolidated batch dispatch must provide batch efficiency once sufficient packed inventory exists"):
        return

    for result in [balanced, express, consolidated]:
        var expected_revenue := int(result.get("shipments", 0)) * int(result.get("unit_value", 0))
        if not _require(int(result.get("revenue", -1)) == expected_revenue, "%s must generate shipment revenue exactly once" % String(result.get("route", "route"))):
            return

    var balanced_trickle := _run_trickle_case("balanced")
    var consolidated_trickle := _run_trickle_case("consolidated")
    if not _require(float(consolidated_trickle.get("packed_avg", 0.0)) > float(balanced_trickle.get("packed_avg", 0.0)) + 0.35, "Consolidated Linehaul must expose higher packed-inventory pressure under slow trickle supply"):
        return

    print("RANK3_CARRIER_ROUTING_PACING %s" % JSON.stringify({
        "backlog_seconds": BACKLOG_SECONDS,
        "backlog": {
            "balanced": balanced,
            "express": express,
            "consolidated": consolidated,
        },
        "trickle_seconds": TRICKLE_SECONDS,
        "trickle": {
            "balanced": balanced_trickle,
            "consolidated": consolidated_trickle,
        },
    }))
    print("Godot Rank 3 Carrier Routing pacing report passed")
    quit(0)


func _run_backlog_case(route: String) -> Dictionary:
    var sim = _prepared_rank3(route)
    sim.packed_queue = 80
    sim.packing_queue = 0
    sim._inbound_timer = 9999.0
    sim._order_timer = 9999.0

    var start_shipped := int(sim.shipped)
    var start_money := int(sim.money)
    var packed_sum := 0.0
    var samples := 0
    for _index in int(ceil(BACKLOG_SECONDS / STEP_SECONDS)):
        sim.step(STEP_SECONDS)
        packed_sum += float(sim.packed_queue)
        samples += 1

    var shipments := int(sim.shipped) - start_shipped
    var revenue := int(sim.money) - start_money
    var profile: Dictionary = sim.routing_profile(route)
    return {
        "route": route,
        "shipments": shipments,
        "revenue": revenue,
        "unit_value": int(profile.get("unit_value", 0)),
        "revenue_per_shipment": snappedf(float(revenue) / maxf(1.0, float(shipments)), 0.1),
        "shipments_per_min": snappedf(float(shipments) * 60.0 / BACKLOG_SECONDS, 0.1),
        "packed_avg": snappedf(packed_sum / maxf(1.0, float(samples)), 0.01),
        "packed_end": int(sim.packed_queue),
    }


func _run_trickle_case(route: String) -> Dictionary:
    var sim = _prepared_rank3(route)
    sim.packed_queue = 0
    sim.packing_queue = 8
    sim.pack_level = 0
    sim.pack_time_multiplier = 1.0
    sim.facilities["parallel_pack"] = false
    sim.facilities["fast_pack_cell"] = false
    sim._inbound_timer = 9999.0
    sim._order_timer = 9999.0

    var start_shipped := int(sim.shipped)
    var packed_sum := 0.0
    var max_packed := 0
    var samples := 0
    for _index in int(ceil(TRICKLE_SECONDS / STEP_SECONDS)):
        sim.step(STEP_SECONDS)
        packed_sum += float(sim.packed_queue)
        max_packed = maxi(max_packed, int(sim.packed_queue))
        samples += 1

    return {
        "route": route,
        "shipments": int(sim.shipped) - start_shipped,
        "packed_avg": snappedf(packed_sum / maxf(1.0, float(samples)), 0.01),
        "packed_max": max_packed,
        "packed_end": int(sim.packed_queue),
    }


func _prepared_rank3(route: String):
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 6
    data["facility_rank"] = 3
    data["worker_count"] = 5
    data["money"] = 500000
    data["staffing_plan"] = "shipping"
    data["staffing_cooldown"] = 0.0
    data["active_routing_mode"] = route
    data["workload_clock"] = 0.0
    data["dispatch_start_shipped"] = int(data.get("shipped", 0))
    data["inbound_queue"] = 0
    data["rack_stock"] = 0
    data["packing_queue"] = 0
    data["packed_queue"] = 0
    data["open_orders"] = 0
    data["shipped"] = 0
    data["rack_capacity"] = 24
    data["receiving_annex_unlocked"] = true
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "synthetic Rank 3 routing pacing state must load")
    return sim


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
