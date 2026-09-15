extends SceneTree

const WorkloadSimScript = preload("res://domain/workload_warehouse_sim.gd")


func _init() -> void:
    var rank1 = WorkloadSimScript.new()
    assert(not bool(rank1.workload_wave().get("enabled", true)), "workload waves must remain locked at Rank 1")

    var sim = _rank2_sim(0.0, "balanced")
    var opening: Dictionary = sim.workload_wave()
    assert(String(opening.get("key", "")) == "normal", "Rank 2 workload cycle must begin with a forecast/recovery window")
    assert(String(opening.get("next_wave_key", "")) == "inbound_surge", "first forecast must point to inbound surge")
    assert(is_equal_approx(float(opening.get("seconds_until_next_wave", 0.0)), 35.0), "Rank 2 must provide 35 seconds of warning before the first surge")

    var normal_inbound := sim._current_inbound_interval()
    sim.step(35.1)
    var inbound_wave: Dictionary = sim.workload_wave()
    assert(String(inbound_wave.get("key", "")) == "inbound_surge", "cycle must enter inbound surge after warning window")
    assert(sim._current_inbound_interval() < normal_inbound * 0.6, "inbound surge must materially accelerate actual source arrivals")

    var order_sim = _rank2_sim(120.1, "picking")
    var order_wave: Dictionary = order_sim.workload_wave()
    assert(String(order_wave.get("key", "")) == "order_surge", "120 seconds into the cycle must be order surge")
    assert(order_sim._current_order_interval() < 1.1, "order surge must materially accelerate actual order arrivals")

    var dispatch_sim = _rank2_sim(205.1, "shipping")
    dispatch_sim.packed_queue = 8
    var dispatch_wave: Dictionary = dispatch_sim.workload_wave()
    assert(String(dispatch_wave.get("key", "")) == "dispatch_window", "205 seconds into the cycle must be dispatch window")
    var before_shipped := dispatch_sim.shipped
    for _i in 120:
        dispatch_sim.step(0.1)
    assert(dispatch_sim.shipped > before_shipped, "dispatch window must measure real outbound shipments")
    assert(int(dispatch_sim.workload_wave().get("dispatch_shipments", 0)) == dispatch_sim.shipped - before_shipped, "dispatch progress must be derived from authoritative shipments")

    var saved := order_sim.save_data()
    assert(int(saved.get("schema_version", -1)) == 4, "workload-aware runtime must save schema 4")
    var restored = WorkloadSimScript.new()
    assert(restored.load_data(saved), "schema 4 workload save must load")
    assert(absf(restored.workload_clock - order_sim.workload_clock) < 0.001, "workload clock must survive save/load")
    assert(String(restored.workload_wave().get("phase_id", "")) == String(order_sim.workload_wave().get("phase_id", "")), "workload phase must survive save/load")

    var schema3 := saved.duplicate(true)
    schema3["schema_version"] = 3
    schema3.erase("workload_clock")
    schema3.erase("dispatch_start_shipped")
    var migrated = WorkloadSimScript.new()
    assert(migrated.load_data(schema3), "schema 3 saves must migrate into workload schema 4")
    assert(int(migrated.save_data().get("schema_version", -1)) == 4, "schema 3 migration must write schema 4")
    assert(is_equal_approx(migrated.workload_clock, 0.0), "legacy Rank 2 saves must enter a safe forecast window, not a surprise surge")

    print("Godot Rank 2 workload wave smoke passed")
    quit(0)


func _rank2_sim(clock: float, staffing: String):
    var sim = WorkloadSimScript.new()
    var data := sim.save_data()
    data["schema_version"] = 4
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["worker_count"] = 5
    data["money"] = 100000
    data["staffing_plan"] = staffing
    data["staffing_cooldown"] = 0.0
    data["workload_clock"] = clock
    data["dispatch_start_shipped"] = int(data.get("shipped", 0))
    assert(sim.load_data(data), "synthetic Rank 2 workload state must load")
    return sim
