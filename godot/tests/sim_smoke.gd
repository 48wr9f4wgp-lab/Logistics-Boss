extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")


func _init() -> void:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var start_money := sim.money
    var events: Array[Dictionary] = []

    sim.event_emitted.connect(func(event: Dictionary):
        events.append(event)
    )

    for _i in 2400:
        sim.step(0.1)

    assert(sim.shipped > 0, "simulation must complete real outbound shipments")
    var shipment_events := 0
    for event in events:
        if String(event.get("type", "")) == "shipment":
            shipment_events += 1
    assert(shipment_events == sim.shipped, "money-bearing shipments must come from shipment completion events")
    assert(sim.money > start_money, "cash must rise after successful outbound delivery")

    sim.money += 100000
    var before_capacity := sim.rack_capacity
    var rack_result := sim.purchase_upgrade(&"rack")
    assert(bool(rack_result.get("ok", false)), "rack investment should be purchasable")
    assert(sim.rack_capacity == before_capacity + 4, "rack investment must change real capacity")

    var forklift_result := sim.purchase_upgrade(&"forklift")
    assert(bool(forklift_result.get("ok", false)), "forklift automation should be purchasable")
    assert(sim.forklift_unlocked, "forklift purchase must unlock domain automation")
    assert(not bool(sim.purchase_upgrade(&"forklift").get("ok", true)), "forklift automation must be one-time capital")

    for _i in 350:
        sim.step(0.1)

    var forklift_store_events := 0
    var forklift_measurement_found := false
    for event in events:
        match String(event.get("type", "")):
            "forklift_stored":
                forklift_store_events += 1
            "measurement_completed":
                if String(event.get("kind", "")) == "forklift":
                    forklift_measurement_found = true
                    var before: Dictionary = event.get("before", {})
                    var after: Dictionary = event.get("after", {})
                    assert(before.has("shipments_per_min"), "measurement must contain real pre-investment shipment rate")
                    assert(after.has("revenue_per_min"), "measurement must contain real post-investment revenue rate")
                    assert(after.has("inbound_queue"), "measurement must contain inbound queue state")
                    assert(after.has("packing_queue"), "measurement must contain packing queue state")
                    assert(after.has("outbound_queue"), "measurement must contain outbound queue state")

    assert(forklift_store_events > 0, "forklift automation must execute real STORE throughput")
    assert(forklift_measurement_found, "forklift investment must produce a 25-second Before/After result")

    sim.set_policy(WarehouseSim.Policy.SHIP)
    assert(sim.policy == WarehouseSim.Policy.SHIP, "policy switch must persist in domain state")

    var legacy := sim.save_data()
    legacy["schema_version"] = 1
    legacy.erase("forklift_unlocked")
    for key in ["logistics_rating", "facility_rank", "completed_contracts", "contract_offers", "active_contract", "next_contract_id", "staffing_plan", "staffing_cooldown"]:
        legacy.erase(key)
    var migrated: WarehouseSim = WarehouseSimScript.new()
    assert(migrated.load_data(legacy), "schema 1 saves must migrate into schema 3")
    assert(int(migrated.save_data().get("schema_version", -1)) == 3, "migrated save must write schema 3")
    assert(not migrated.forklift_unlocked, "legacy saves must default forklift automation to locked")
    assert(migrated.facility_rank == 1 and migrated.logistics_rating == 0, "legacy saves must not invent Rank 2 progression")

    print("Godot warehouse simulation smoke passed")
    quit(0)
