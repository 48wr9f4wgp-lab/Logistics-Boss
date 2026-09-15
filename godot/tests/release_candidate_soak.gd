extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var fresh = SimScript.new()
    fresh.set_time_scale(4.0)
    var fresh_start: int = int(fresh.shipped)
    _advance(fresh, 300)
    if fresh.shipped <= fresh_start:
        _fail("fresh Rank 1 simulation must keep shipping without manual parcel control")
        return
    if fresh.money < 0 or fresh.inbound_queue < 0 or fresh.open_orders < 0:
        _fail("fresh simulation must never create negative economy or queue state")
        return

    var fresh_save: Dictionary = fresh.save_data()
    var fresh_restored = SimScript.new()
    if not fresh_restored.load_data(fresh_save):
        _fail("long-running fresh save must restore")
        return
    fresh_restored.set_time_scale(4.0)
    var restored_before: int = int(fresh_restored.shipped)
    _advance(fresh_restored, 120)
    if fresh_restored.shipped <= restored_before:
        _fail("restored fresh save must resume productive logistics")
        return

    var late = _late_rank3_sim()
    late.set_time_scale(4.0)
    var routes := [
        Rank3WarehouseSim.ROUTE_BALANCED,
        Rank3WarehouseSim.ROUTE_EXPRESS,
        Rank3WarehouseSim.ROUTE_CONSOLIDATED,
    ]
    for route in routes:
        if String(late.active_routing_mode) != String(route):
            var route_result: Dictionary = late.set_routing_mode(String(route))
            if not bool(route_result.get("ok", false)):
                _fail("Rank 3 route must remain selectable during soak: %s" % String(route))
                return
        var segment_before: int = int(late.shipped)
        _advance(late, 180)
        if late.shipped <= segment_before:
            _fail("Rank 3 route must not deadlock shipment flow: %s" % String(route))
            return
        if late.money < 0 or late.inbound_queue < 0 or late.rack_stock < 0 or late.packing_queue < 0 or late.packed_queue < 0 or late.open_orders < 0:
            _fail("Rank 3 soak must preserve non-negative logistics state")
            return

    var late_save: Dictionary = late.save_data()
    var late_restored = SimScript.new()
    if not late_restored.load_data(late_save):
        _fail("schema-v7 late-game save must restore after soak")
        return
    if not late_restored.receiving_annex_unlocked or not late_restored.inbound_carrier_program_unlocked:
        _fail("late-game structural investments must survive soak save/load")
        return
    if String(late_restored.active_routing_mode) != String(late.active_routing_mode):
        _fail("active carrier routing must survive soak save/load")
        return

    late_restored.set_time_scale(4.0)
    var final_before: int = int(late_restored.shipped)
    _advance(late_restored, 180)
    if late_restored.shipped <= final_before:
        _fail("restored Rank 3 save must continue shipping")
        return

    print("Godot release candidate soak passed")
    quit(0)


func _advance(sim, simulated_seconds: int) -> void:
    for _index in simulated_seconds:
        sim.step(0.25)


func _late_rank3_sim():
    var sim = SimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 7
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 500000
    data["receiving_annex_unlocked"] = true
    data["active_routing_mode"] = Rank3WarehouseSim.ROUTE_BALANCED
    data["inbound_carrier_program_unlocked"] = true
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["workload_clock"] = 0.0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    if not sim.load_data(data):
        _fail("synthetic Rank 3 soak state must load")
        return sim
    return sim
