extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")


func _init() -> void:
    var report := {
        "intake": {
            "double_dock": _run_case(&"double_dock", "receiving", 180.0),
            "buffer_yard": _run_case(&"buffer_yard", "receiving", 180.0),
        },
        "storage": {
            "fast_pick_rack": _run_case(&"fast_pick_rack", "picking", 180.0),
            "high_density_rack": _run_case(&"high_density_rack", "picking", 180.0),
        },
        "packing": {
            "parallel_pack": _run_case(&"parallel_pack", "picking", 180.0),
            "fast_pack_cell": _run_case(&"fast_pack_cell", "picking", 180.0),
        },
    }

    for group in report.values():
        for metrics in (group as Dictionary).values():
            assert(int((metrics as Dictionary).get("shipments", 0)) > 0, "every Rank 2 facility scenario must preserve real shipment flow")

    print("RANK2_ZONE_PACING_REPORT %s" % JSON.stringify(report))
    print("Godot Rank 2 zone pacing report passed")
    quit(0)


func _run_case(kind: StringName, staffing: String, seconds: float) -> Dictionary:
    var sim := _prepared_rank2(staffing)
    var inbound_arrivals := 0
    var facility_shipments := 0
    sim.event_emitted.connect(func(event: Dictionary):
        match String(event.get("type", "")):
            "inbound_arrival":
                inbound_arrivals += 1
            "shipment":
                facility_shipments += 1
    )

    var purchase := sim.purchase_facility(kind)
    assert(bool(purchase.get("ok", false)), "%s must purchase in pacing report" % String(kind))

    var samples := 0
    var inbound_sum := 0.0
    var rack_sum := 0.0
    var packing_sum := 0.0
    var outbound_sum := 0.0
    var orders_sum := 0.0
    var max_inbound := sim.inbound_queue
    var max_packing := sim.packing_queue
    var bottlenecks := {}
    var steps := int(seconds * 10.0)
    for _i in steps:
        sim.step(0.1)
        inbound_sum += sim.inbound_queue
        rack_sum += sim.rack_stock
        packing_sum += sim.packing_queue
        outbound_sum += sim.packed_queue
        orders_sum += sim.open_orders
        max_inbound = maxi(max_inbound, sim.inbound_queue)
        max_packing = maxi(max_packing, sim.packing_queue)
        var key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[key] = int(bottlenecks.get(key, 0)) + 1
        samples += 1

    return {
        "shipments": facility_shipments,
        "shipments_per_min": snappedf(float(facility_shipments) * 60.0 / seconds, 0.1),
        "inbound_arrivals": inbound_arrivals,
        "inbound_avg": snappedf(inbound_sum / maxf(1.0, float(samples)), 0.01),
        "rack_avg": snappedf(rack_sum / maxf(1.0, float(samples)), 0.01),
        "packing_avg": snappedf(packing_sum / maxf(1.0, float(samples)), 0.01),
        "outbound_avg": snappedf(outbound_sum / maxf(1.0, float(samples)), 0.01),
        "orders_avg": snappedf(orders_sum / maxf(1.0, float(samples)), 0.01),
        "max_inbound": max_inbound,
        "max_packing": max_packing,
        "rack_capacity": sim.rack_capacity,
        "inbound_capacity": sim._current_inbound_limit(),
        "inbound_interval": snappedf(sim._current_inbound_interval(), 0.001),
        "packing_capacity": sim._packing_capacity(),
        "packing_duration": snappedf(sim._packing_duration(), 0.001),
        "dominant_bottleneck": _dominant_key(bottlenecks),
    }


func _prepared_rank2(staffing: String) -> WarehouseSim:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var data := sim.save_data()
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["worker_count"] = 5
    data["money"] = 200000
    data["forklift_unlocked"] = true
    data["pack_level"] = 1
    data["pack_time_multiplier"] = 0.85
    data["staffing_plan"] = staffing
    data["staffing_cooldown"] = 0.0
    data["inbound_queue"] = 10
    data["rack_stock"] = 6
    data["packing_queue"] = 4
    data["packed_queue"] = 1
    data["open_orders"] = 8
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "Rank 2 pacing scenario must load")
    return sim


func _dominant_key(counts: Dictionary) -> String:
    var best_key := "stable"
    var best_count := -1
    for key in counts:
        var count := int(counts[key])
        if count > best_count:
            best_count = count
            best_key = String(key)
    return best_key
