extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")


func _init() -> void:
    var sim := _rank2_sim()
    var events: Array[Dictionary] = []
    sim.event_emitted.connect(func(event: Dictionary): events.append(event))

    var start_money := sim.money
    var base_capacity := sim.rack_capacity

    var intake := sim.purchase_facility(&"double_dock")
    assert(bool(intake.get("ok", false)), "Rank 2 must allow one Zone A facility")
    assert(sim._current_inbound_limit() == 20, "Double Dock must raise inbound limit by 6")
    assert(sim._current_inbound_interval() < WarehouseSim.INBOUND_INTERVAL, "Double Dock must increase inbound arrival frequency")
    assert(String(sim.selected_facility_for_group("intake")) == "double_dock", "Zone A selection must persist in domain state")
    assert(not bool(sim.purchase_facility(&"buffer_yard").get("ok", true)), "Zone A choices must be mutually exclusive")

    var storage := sim.purchase_facility(&"fast_pick_rack")
    assert(bool(storage.get("ok", false)), "Rank 2 must allow one Zone B facility")
    assert(sim.rack_capacity == base_capacity + 12, "Fast Pick Rack must add twelve storage slots")
    assert(not bool(sim.purchase_facility(&"high_density_rack").get("ok", true)), "Zone B choices must be mutually exclusive")

    var packing := sim.purchase_facility(&"parallel_pack")
    assert(bool(packing.get("ok", false)), "Rank 2 must allow one Zone C facility")
    assert(sim._packing_capacity() == 2, "Parallel Pack Line must allow two simultaneous packing jobs")
    assert(sim._packing_duration() > 3.0 * sim.pack_time_multiplier, "Parallel Pack Line must trade concurrency for slower individual packs")
    assert(not bool(sim.purchase_facility(&"fast_pack_cell").get("ok", true)), "Zone C choices must be mutually exclusive")

    assert(sim.expansion_zones_completed() == 3, "Rank 2 progress must count three structural zones")
    var expected_spend := sim.facility_cost(&"double_dock") + sim.facility_cost(&"fast_pick_rack") + sim.facility_cost(&"parallel_pack")
    assert(sim.money == start_money - expected_spend, "facility purchases must debit authoritative Domain money")

    for _i in 360:
        sim.step(0.1)

    var purchased := 0
    var measured := 0
    for event in events:
        var event_type := String(event.get("type", ""))
        if event_type == "facility_purchased":
            purchased += 1
        elif event_type == "measurement_completed" and String(event.get("kind", "")).begins_with("facility_"):
            measured += 1
    assert(purchased == 3, "each selected zone must emit a real facility purchase event")
    assert(measured == 3, "each structural investment must complete a Before/After measurement")

    var saved := sim.save_data()
    var reloaded: WarehouseSim = WarehouseSimScript.new()
    assert(reloaded.load_data(saved), "Rank 2 facility state must reload")
    assert(reloaded.expansion_zones_completed() == 3, "all structural zone choices must survive save/load")
    assert(reloaded.rack_capacity == sim.rack_capacity, "saved facility capacity must not be double-applied on load")
    assert(bool(reloaded.facilities.get("double_dock", false)), "Double Dock selection must persist")
    assert(bool(reloaded.facilities.get("fast_pick_rack", false)), "Fast Pick Rack selection must persist")
    assert(bool(reloaded.facilities.get("parallel_pack", false)), "Parallel Pack selection must persist")

    var buffer_sim := _rank2_sim()
    assert(bool(buffer_sim.purchase_facility(&"buffer_yard").get("ok", false)), "Buffer Yard must be independently selectable")
    assert(buffer_sim._current_inbound_limit() == 28, "Buffer Yard must create the larger inbound surge buffer")
    assert(is_equal_approx(buffer_sim._current_inbound_interval(), WarehouseSim.INBOUND_INTERVAL), "Buffer Yard must not increase arrival rate")

    var density_sim := _rank2_sim()
    var density_base := density_sim.rack_capacity
    assert(bool(density_sim.purchase_facility(&"high_density_rack").get("ok", false)), "High Density Rack must be independently selectable")
    assert(density_sim.rack_capacity == density_base + 16, "High Density Rack must add sixteen storage slots")

    var fast_pack_sim := _rank2_sim()
    assert(bool(fast_pack_sim.purchase_facility(&"fast_pack_cell").get("ok", false)), "Fast Pack Cell must be independently selectable")
    assert(fast_pack_sim._packing_capacity() == 1, "Fast Pack Cell must remain single-capacity")
    assert(fast_pack_sim._packing_duration() < 3.0 * fast_pack_sim.pack_time_multiplier, "Fast Pack Cell must materially reduce pack duration")

    print("Godot Rank 2 facility smoke passed")
    quit(0)


func _rank2_sim() -> WarehouseSim:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var data := sim.save_data()
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["worker_count"] = 5
    data["money"] = 200000
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "synthetic Rank 2 test state must load")
    return sim
