extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const STEP_SECONDS := 0.1


func _init() -> void:
    var migration := Rank3WarehouseSimScript.new()
    var legacy := _rank2_gate_seed(migration, false)
    assert(migration.load_data(legacy), "schema-v4 Rank 2 state must migrate into Rank 3 simulation")
    assert(int(migration.facility_rank) == 2, "schema-v4 migration must not fake Rank 3 before capital/throughput gates are met")
    assert(not bool(migration.receiving_annex_unlocked), "legacy save must not invent the Receiving Annex")
    assert(int(migration.save_data().get("schema_version", 0)) == 5, "migrated save must write schema v5")

    var sim = Rank3WarehouseSimScript.new()
    var seed := _rank2_gate_seed(sim, true)
    assert(sim.load_data(seed), "Rank 3 gate seed must load")
    assert(int(sim.completed_contracts) == 0, "Rank 3 gate regression must prove contracts are optional")
    assert(int(sim.equipment_asset_value()) >= Rank3WarehouseSim.RANK3_MIN_ASSETS, "Rank 3 gate seed must meet the capital asset threshold")

    var observed := {"rank3_events": 0}
    sim.event_emitted.connect(func(event: Dictionary):
        if String(event.get("type", "")) == "rank_up" and int(event.get("rank", 0)) == 3:
            observed["rank3_events"] = int(observed.get("rank3_events", 0)) + 1
    )

    for _i in int(ceil(24.0 / STEP_SECONDS)):
        sim.step(STEP_SECONDS)
        if int(sim.facility_rank) >= 3:
            break

    assert(int(sim.facility_rank) == 3, "completed Rank 2 structure plus assets and live throughput must promote to Rank 3 without contracts")
    assert(int(observed.get("rank3_events", 0)) == 1, "Rank 3 promotion must emit exactly one rank_up event")
    assert(bool(sim.rank3_readiness().get("ready", false)), "Rank 3 readiness must remain satisfied after promotion")
    assert(not sim.rank3_readiness().has("contracts_required"), "Rank 3 readiness must not expose a mandatory contract gate")

    var before_limit := int(sim._current_inbound_limit())
    var before_money := int(sim.money)
    var purchase: Dictionary = sim.purchase_receiving_annex()
    assert(bool(purchase.get("ok", false)), "Rank 3 must be able to purchase Receiving Annex when funded")
    assert(bool(sim.receiving_annex_unlocked), "Receiving Annex purchase must become authoritative domain state")
    assert(int(sim.money) == before_money - int(purchase.get("cost", 0)), "Receiving Annex purchase must charge authoritative money once")
    assert(int(sim._current_inbound_limit()) == before_limit + 14, "Receiving Annex must add the measured +14 inbound acceptance capacity")
    assert(not bool(sim.purchase_receiving_annex().get("ok", false)), "Receiving Annex must remain a one-time capital purchase")

    var saved: Dictionary = sim.save_data()
    assert(int(saved.get("schema_version", 0)) == 5, "Rank 3 save must use schema v5")
    assert(bool(saved.get("receiving_annex_unlocked", false)), "Rank 3 save must persist Receiving Annex ownership")

    var restored = Rank3WarehouseSimScript.new()
    assert(restored.load_data(saved), "schema-v5 Rank 3 save must load")
    assert(int(restored.facility_rank) == 3, "Rank 3 facility rank must survive save/load")
    assert(bool(restored.receiving_annex_unlocked), "Receiving Annex ownership must survive save/load")
    assert(int(restored._current_inbound_limit()) == int(sim._current_inbound_limit()), "Receiving Annex capacity effect must not double-apply on reload")

    print("Godot Rank 3 Receiving Annex smoke passed")
    quit(0)


func _rank2_gate_seed(sim, meet_assets: bool) -> Dictionary:
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 4
    data["facility_rank"] = 2
    data["logistics_rating"] = 16
    data["completed_contracts"] = 0
    data["worker_count"] = 7 if meet_assets else 5
    data["money"] = 500000
    data["forklift_unlocked"] = true
    data["rack_level"] = 4 if meet_assets else 0
    data["speed_level"] = 4 if meet_assets else 0
    data["pack_level"] = 4 if meet_assets else 1
    data["worker_speed"] = 1.75 if meet_assets else 1.0
    data["pack_time_multiplier"] = 0.52 if meet_assets else 0.85
    data["staffing_plan"] = "shipping"
    data["staffing_cooldown"] = 0.0
    data["workload_clock"] = 0.0
    data["dispatch_start_shipped"] = int(data.get("shipped", 0))
    data["inbound_queue"] = 4
    data["rack_stock"] = 8
    data["packing_queue"] = 0
    data["packed_queue"] = 20
    data["open_orders"] = 6
    data["rack_capacity"] = 40 if meet_assets else 12
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    return data
