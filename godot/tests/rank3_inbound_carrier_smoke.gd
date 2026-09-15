extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")


func _init() -> void:
    var migration = _rank3_sim(false)
    var legacy: Dictionary = migration.save_data()
    legacy["schema_version"] = 6
    legacy.erase("inbound_carrier_program_unlocked")
    assert(migration.load_data(legacy), "schema-v6 Rank 3 save must migrate into inbound carrier simulation")
    assert(not migration.inbound_carrier_program_unlocked, "schema-v6 migration must not invent inbound carrier ownership")
    assert(int(migration.save_data().get("schema_version", 0)) == 7, "migrated inbound carrier save must write schema v7")

    var locked = _rank3_sim(false)
    var locked_result: Dictionary = locked.purchase_inbound_carrier_program()
    assert(not bool(locked_result.get("ok", false)), "inbound carrier program must require Receiving Annex")
    assert(String(locked_result.get("reason", "")) == "annex", "missing annex must be the explicit purchase blocker")

    var sim = _rank3_sim(true)
    var before_interval := float(sim._current_inbound_interval())
    var before_money := int(sim.money)
    var before_assets := int(sim.equipment_asset_value())
    var observed := {"count": 0, "measurement": 0.0}
    sim.event_emitted.connect(func(event: Dictionary):
        if String(event.get("type", "")) == "inbound_carrier_program_purchased":
            observed["count"] = int(observed.get("count", 0)) + 1
            observed["measurement"] = float(event.get("measurement_window", 0.0))
    )

    var purchase: Dictionary = sim.purchase_inbound_carrier_program()
    assert(bool(purchase.get("ok", false)), "funded Rank 3 with Receiving Annex must purchase inbound carrier program")
    assert(sim.inbound_carrier_program_unlocked, "purchase must become authoritative Domain state")
    assert(int(sim.money) == before_money - SimScript.INBOUND_CARRIER_PROGRAM_COST, "purchase must charge authoritative money exactly once")
    assert(is_equal_approx(float(sim._current_inbound_interval()), before_interval * SimScript.INBOUND_CARRIER_INTERVAL_MULTIPLIER), "program must apply measured x0.85 scheduled inbound cadence")
    assert(int(sim.equipment_asset_value()) == before_assets + SimScript.INBOUND_CARRIER_PROGRAM_COST, "carrier program must become part of owned equipment assets")
    assert(int(observed.get("count", 0)) == 1, "purchase must emit exactly one carrier program event")
    assert(float(observed.get("measurement", 0.0)) == FlowMeasurement.WINDOW_SECONDS, "purchase must start canonical Before/After measurement")
    assert(not bool(sim.purchase_inbound_carrier_program().get("ok", false)), "carrier program must remain a one-time investment")

    var saved: Dictionary = sim.save_data()
    assert(int(saved.get("schema_version", 0)) == 7, "carrier program save must use schema v7")
    assert(bool(saved.get("inbound_carrier_program_unlocked", false)), "carrier program ownership must persist")

    var restored = SimScript.new()
    assert(restored.load_data(saved), "schema-v7 inbound carrier save must load")
    assert(restored.inbound_carrier_program_unlocked, "carrier program ownership must survive save/load")
    assert(is_equal_approx(float(restored._current_inbound_interval()), float(sim._current_inbound_interval())), "carrier cadence effect must not double-apply on reload")

    print("Godot Rank 3 inbound carrier program smoke passed")
    quit(0)


func _rank3_sim(annex_owned: bool):
    var sim = SimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 7
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 0
    data["worker_count"] = 5
    data["money"] = 500000
    data["receiving_annex_unlocked"] = annex_owned
    data["active_routing_mode"] = "balanced"
    data["inbound_carrier_program_unlocked"] = false
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
    assert(sim.load_data(data), "synthetic Rank 3 inbound carrier state must load")
    return sim
