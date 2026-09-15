extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")


func _init() -> void:
    _test_route_api_and_save()
    _test_route_tradeoffs()
    _test_consolidated_gate_and_exact_batch_economics()
    _test_inflight_route_is_frozen()
    _test_route_can_move_bottleneck()
    print("Godot Rank 3 carrier routing smoke passed")
    quit(0)


func _test_route_api_and_save() -> void:
    var sim = _rank3_sim("balanced")
    assert(sim.active_routing_mode == "balanced", "Rank 3 must default to Balanced Parcel")

    var changed: Dictionary = sim.set_routing_mode("express")
    assert(bool(changed.get("ok", false)), "Rank 3 must allow Express Dispatch selection")
    assert(sim.active_routing_mode == "express", "route API must update authoritative state")
    assert(float(changed.get("measurement_window", 0.0)) == 25.0, "route switch must start Before / After measurement")

    var saved: Dictionary = sim.save_data()
    assert(int(saved.get("schema_version", 0)) == 6, "Carrier Routing must use save schema v6")
    assert(String(saved.get("active_routing_mode", "")) == "express", "active route must persist")

    var restored = Rank3WarehouseSimScript.new()
    assert(restored.load_data(saved), "schema v6 route save must load")
    assert(restored.active_routing_mode == "express", "route must survive Save / Load")

    var legacy: Dictionary = saved.duplicate(true)
    legacy["schema_version"] = 5
    legacy.erase("active_routing_mode")
    var migrated = Rank3WarehouseSimScript.new()
    assert(migrated.load_data(legacy), "schema v5 save must migrate")
    assert(migrated.active_routing_mode == "balanced", "v5 migration must default safely to Balanced Parcel")


func _test_route_tradeoffs() -> void:
    var balanced = _rank3_sim("balanced")
    balanced.packed_queue = 1
    var balanced_worker := _worker()
    var balanced_money := balanced.money
    balanced._start_task(balanced_worker, WarehouseSimScript.Task.SHIP)
    var balanced_duration := float(balanced_worker.get("duration", 0.0))
    balanced._complete_task(balanced_worker)
    assert(balanced.shipped == 1, "Balanced Parcel must dispatch one parcel")
    assert(balanced.money - balanced_money == 500, "Balanced Parcel must keep the reference shipment value")

    var express = _rank3_sim("express")
    express.packed_queue = 1
    var express_worker := _worker()
    var express_money := express.money
    express._start_task(express_worker, WarehouseSimScript.Task.SHIP)
    var express_duration := float(express_worker.get("duration", 0.0))
    express._complete_task(express_worker)
    assert(express.shipped == 1, "Express Dispatch must dispatch one parcel")
    assert(express_duration < balanced_duration, "Express Dispatch must clear outbound faster than Balanced Parcel")
    assert(express.money - express_money == 410, "Express Dispatch must trade margin for speed")
    assert(express.money - express_money < balanced.money - balanced_money, "Express Dispatch unit revenue must be lower than Balanced Parcel")


func _test_consolidated_gate_and_exact_batch_economics() -> void:
    var sim = _rank3_sim("consolidated")
    var ship_worker := _worker()
    ship_worker["role"] = "ship"

    sim.packed_queue = 3
    assert(not sim._routing_can_dispatch(), "Consolidated Linehaul must wait below its batch threshold")
    assert(sim._choose_task_for_worker(ship_worker) == WarehouseSimScript.Task.IDLE, "SHIP worker must not bypass consolidated batch gating")

    sim.packed_queue = 4
    assert(sim._routing_can_dispatch(), "Consolidated Linehaul must dispatch at the batch threshold")
    var money_before := sim.money
    var shipped_before := sim.shipped
    sim._start_task(ship_worker, WarehouseSimScript.Task.SHIP)
    assert(sim.packed_queue == 0, "Consolidated Linehaul must reserve the complete batch at task start")
    assert(int(ship_worker.get("routing_batch", 0)) == 4, "Consolidated task must freeze a four-parcel batch")
    sim._complete_task(ship_worker)
    assert(sim.shipped - shipped_before == 4, "Consolidated completion must create exactly four authoritative shipments")
    assert(sim.money - money_before == 2480, "Consolidated completion must create revenue exactly once")
    assert((sim.money - money_before) / 4 == 620, "Consolidated Linehaul must improve value per parcel")


func _test_inflight_route_is_frozen() -> void:
    var sim = _rank3_sim("express")
    sim.packed_queue = 5
    var worker := _worker()
    var money_before := sim.money
    sim._start_task(worker, WarehouseSimScript.Task.SHIP)
    assert(String(worker.get("routing_mode", "")) == "express", "SHIP task must capture its route when work starts")
    assert(bool(sim.set_routing_mode("consolidated").get("ok", false)), "route must remain switchable while a prior dispatch is in flight")
    sim._complete_task(worker)
    assert(sim.money - money_before == 410, "in-flight Express parcel must not be repriced by a later route switch")
    assert(sim.shipped == 1, "in-flight route switching must not duplicate shipments")


func _test_route_can_move_bottleneck() -> void:
    var sim = _rank3_sim("express")
    sim.packed_queue = 8
    sim.open_orders = 8
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    assert(String(sim.bottleneck().get("key", "")) == "outbound", "seeded scenario must begin with outbound congestion")

    for _index in range(8):
        var worker := _worker()
        sim._start_task(worker, WarehouseSimScript.Task.SHIP)
        sim._complete_task(worker)

    assert(sim.packed_queue == 0, "Express Dispatch must be able to clear the seeded outbound queue")
    assert(String(sim.bottleneck().get("key", "")) == "orders", "clearing outbound must expose the next open-order bottleneck")


func _rank3_sim(route: String):
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 6
    data["facility_rank"] = 3
    data["worker_count"] = 5
    data["money"] = 100000
    data["staffing_plan"] = "shipping"
    data["staffing_cooldown"] = 0.0
    data["active_routing_mode"] = route
    data["receiving_annex_unlocked"] = true
    data["inbound_queue"] = 0
    data["rack_stock"] = 0
    data["packing_queue"] = 0
    data["packed_queue"] = 0
    data["open_orders"] = 0
    data["shipped"] = 0
    assert(sim.load_data(data), "synthetic Rank 3 routing state must load")
    return sim


func _worker() -> Dictionary:
    return {
        "id": 999,
        "role": "ship",
        "task": WarehouseSimScript.Task.IDLE,
        "source": "center",
        "target": "center",
        "duration": 0.0,
        "remaining": 0.0,
        "progress": 0.0,
    }
