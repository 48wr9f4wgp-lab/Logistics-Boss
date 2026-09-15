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
    var result := sim.purchase_upgrade(&"rack")
    assert(bool(result.get("ok", false)), "rack investment should be purchasable")
    assert(sim.rack_capacity == before_capacity + 4, "rack investment must change real capacity")

    sim.set_policy(WarehouseSim.Policy.SHIP)
    assert(sim.policy == WarehouseSim.Policy.SHIP, "policy switch must persist in domain state")

    print("Godot warehouse simulation smoke passed")
    quit(0)
