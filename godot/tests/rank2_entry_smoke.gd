extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const Rank3SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")


func _init() -> void:
    var sim: WarehouseSim = WarehouseSimScript.new()
    assert(sim.facility_rank == 1, "fresh operation must begin at Rank 1")
    assert(sim.logistics_rating == 0, "fresh operation must begin at zero Logistics Rating")
    assert(sim.contract_offers.size() == 3, "Rank 1 must expose three contract choices")
    assert(not bool(sim.set_staffing_plan("picking").get("ok", true)), "Rank 1 must not expose Warehouse staffing")

    for contract_index in 4:
        _complete_ship_contract(sim, contract_index + 1)

    assert(sim.logistics_rating >= 8, "four successful contracts must reach Warehouse rating gate")
    assert(sim.facility_rank == 2, "Logistics Rating 8 must promote to Rank 2 Warehouse")
    assert(sim.worker_count >= 5, "Warehouse rank-up must grant at least a five-person crew")

    var balanced := sim.staffing_summary()
    assert(int(balanced.get("store", 0)) == 2, "balanced Warehouse crew must use two receiving workers")
    assert(int(balanced.get("pick", 0)) == 2, "balanced Warehouse crew must use two pickers")
    assert(int(balanced.get("ship", 0)) == 1, "balanced Warehouse crew must use one shipper")

    var picking_result := sim.set_staffing_plan("picking")
    assert(bool(picking_result.get("ok", false)), "Warehouse must allow a structural picking plan")
    var picking := sim.staffing_summary()
    assert(int(picking.get("store", 0)) == 1, "picking plan must allocate 1 receiving worker")
    assert(int(picking.get("pick", 0)) == 3, "picking plan must allocate 3 pickers")
    assert(int(picking.get("ship", 0)) == 1, "picking plan must allocate 1 shipper")
    assert(not bool(sim.set_staffing_plan("shipping").get("ok", true)), "staffing must enforce the 30-second observation lock")

    for _i in 305:
        sim.step(0.1)
    assert(bool(sim.set_staffing_plan("shipping").get("ok", false)), "staffing must unlock after 30 simulated seconds")
    var shipping := sim.staffing_summary()
    assert(int(shipping.get("store", 0)) == 1 and int(shipping.get("pick", 0)) == 2 and int(shipping.get("ship", 0)) == 2, "shipping plan must allocate 1/2/2")

    for _i in 120:
        sim.step(0.1)
    for worker in sim.workers:
        var task := int(worker.get("task", WarehouseSim.Task.IDLE))
        var role := String(worker.get("role", ""))
        if task == WarehouseSim.Task.STORE:
            assert(role == "store", "Rank 2 receiving task must be executed by receiving role")
        elif task == WarehouseSim.Task.PICK:
            assert(role == "pick", "Rank 2 pick task must be executed by pick role")
        elif task == WarehouseSim.Task.SHIP:
            assert(role == "ship", "Rank 2 ship task must be executed by ship role")

    var saved := sim.save_data()
    assert(int(saved.get("schema_version", -1)) == 3, "Rank 2 foundation must persist with save schema 3")
    var round_trip: WarehouseSim = WarehouseSimScript.new()
    assert(round_trip.load_data(saved), "schema 3 save must reload")
    assert(round_trip.facility_rank == 2, "Warehouse rank must survive save/load")
    assert(round_trip.logistics_rating == sim.logistics_rating, "Logistics Rating must survive save/load")
    assert(round_trip.completed_contracts == sim.completed_contracts, "completed contracts must survive save/load")
    assert(round_trip.staffing_plan == sim.staffing_plan, "staffing plan must survive save/load")

    var schema2 := saved.duplicate(true)
    schema2["schema_version"] = 2
    for key in ["logistics_rating", "facility_rank", "completed_contracts", "contract_offers", "active_contract", "next_contract_id", "staffing_plan", "staffing_cooldown"]:
        schema2.erase(key)
    var migrated: WarehouseSim = WarehouseSimScript.new()
    assert(migrated.load_data(schema2), "schema 2 saves must migrate into schema 3")
    assert(migrated.facility_rank == 1, "legacy schema 2 save must default to Rank 1 without inventing progression")
    assert(migrated.logistics_rating == 0, "legacy schema 2 save must default Logistics Rating safely")
    assert(int(migrated.save_data().get("schema_version", -1)) == 3, "migrated save must write schema 3")

    _verify_meta_loop_to_rank3()

    print("Godot Rank 2 entry and canonical meta-loop E2E smoke passed")
    quit(0)


func _complete_ship_contract(sim: WarehouseSim, expected_completed: int) -> void:
    var offer_id := -1
    for offer in sim.contract_offers:
        if String(offer.get("kind", "")) == "ship":
            offer_id = int(offer.get("id", -1))
            break
    assert(offer_id >= 0, "ship contract offer must be available")
    assert(bool(sim.choose_contract(offer_id).get("ok", false)), "player must be able to choose a contract")

    for _i in 1000:
        sim.step(0.1)
        if sim.active_contract.is_empty():
            break
    assert(sim.completed_contracts == expected_completed, "ship contract must complete through real shipment flow")

    for _i in 60:
        if not sim.contract_offers.is_empty():
            break
        sim.step(0.1)
    if expected_completed < 4:
        assert(sim.contract_offers.size() == 3, "new contract choices must return after completion cooldown")


func _verify_meta_loop_to_rank3() -> void:
    var sim: Rank3InboundCarrierSim = Rank3SimScript.new()
    var events: Array[Dictionary] = []
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        events.append(event.duplicate(true))
    )

    var starting_money: int = sim.money
    var starting_rp: int = sim.research_rp
    for contract_index in 4:
        _complete_ship_contract(sim, contract_index + 1)

    assert(sim.facility_rank == 2, "meta loop must convert contract rating into the Rank 2 Warehouse")
    assert(sim.money > starting_money, "successful contracts and live shipments must grow operating cash")
    assert(sim.research_rp > starting_rp, "successful contracts and live shipments must grow RP")
    assert(sim.logistics_rating >= 8, "successful contracts must grow Logistics Rating to the Rank 2 gate")
    assert(_has_rank_event(events, 2), "meta loop must emit the authoritative Rank 2 promotion event")

    _purchase_facility_with_profit(sim, &"buffer_yard")
    _purchase_facility_with_profit(sim, &"high_density_rack")
    _purchase_facility_with_profit(sim, &"fast_pack_cell")
    assert(sim.expansion_zones_completed() == 3, "meta loop must complete all three structural Rank 2 expansion zones")

    _purchase_upgrade_with_profit(sim, &"forklift")
    for _index in 2:
        _purchase_upgrade_with_profit(sim, &"worker")
    for _index in 4:
        _purchase_upgrade_with_profit(sim, &"rack")
    for _index in 3:
        _purchase_upgrade_with_profit(sim, &"speed")
    for _index in 2:
        _purchase_upgrade_with_profit(sim, &"packing")

    assert(sim.facility_rank == 2, "Rank 3 must not unlock before the asset gate is actually satisfied")
    assert(sim.equipment_asset_value() < Rank3WarehouseSim.RANK3_MIN_ASSETS, "pre-gate asset build must stay below the Rank 3 threshold")

    _warm_until_throughput(sim, Rank3WarehouseSim.RANK3_MIN_THROUGHPUT)
    assert(sim.throughput_per_minute() >= Rank3WarehouseSim.RANK3_MIN_THROUGHPUT, "meta loop must establish live throughput before Rank 3")
    assert(sim.facility_rank == 2, "throughput alone must not bypass the Rank 3 capital gate")

    _purchase_upgrade_with_profit(sim, &"speed")
    assert(sim.equipment_asset_value() >= Rank3WarehouseSim.RANK3_MIN_ASSETS, "final structural investment must satisfy the Rank 3 asset gate")
    assert(sim.facility_rank == 2, "Rank promotion must occur through the simulation gate, not directly inside purchase code")

    sim.step(0.1)
    assert(sim.facility_rank == 3, "zones + owned assets + live throughput must promote to Rank 3 Fulfillment Center")
    assert(_has_rank_event(events, 3), "meta loop must emit the authoritative Rank 3 promotion event")
    assert(bool(sim.rank3_readiness().get("ready", false)), "Rank 3 readiness must remain true after promotion")
    assert(sim.routing_modes().size() == 3, "Rank 3 must open a larger-scale carrier routing decision")
    assert(not sim.receiving_annex_info().is_empty(), "Rank 3 must open the Receiving Annex structural investment")

    var pressure_seen := false
    for _index in 1800:
        sim.step(0.1)
        if String(sim.bottleneck().get("key", "stable")) != "stable":
            pressure_seen = true
            break
    assert(pressure_seen, "larger-scale operation must surface a new operational pressure for the next decision")


func _purchase_facility_with_profit(sim: Rank3InboundCarrierSim, kind: StringName) -> void:
    var cost: int = sim.facility_cost(kind)
    _earn_until(sim, cost)
    var result: Dictionary = sim.purchase_facility(kind)
    assert(bool(result.get("ok", false)), "meta loop facility purchase must use earned operating cash")


func _purchase_upgrade_with_profit(sim: Rank3InboundCarrierSim, kind: StringName) -> void:
    var cost: int = sim.upgrade_cost(kind)
    _earn_until(sim, cost)
    var result: Dictionary = sim.purchase_upgrade(kind)
    assert(bool(result.get("ok", false)), "meta loop capital purchase must use earned operating cash")


func _earn_until(sim: Rank3InboundCarrierSim, required_cash: int) -> void:
    for _index in 6000:
        if sim.money >= required_cash:
            return
        sim.step(0.1)
    assert(sim.money >= required_cash, "live logistics operation must be able to fund the next meta-loop investment")


func _warm_until_throughput(sim: Rank3InboundCarrierSim, required_throughput: float) -> void:
    for _index in 1800:
        sim.step(0.1)
        if sim.throughput_per_minute() >= required_throughput:
            return
    assert(sim.throughput_per_minute() >= required_throughput, "live Rank 2 operation must reach the Rank 3 throughput gate")


func _has_rank_event(events: Array[Dictionary], rank: int) -> bool:
    for event in events:
        if String(event.get("type", "")) == "rank_up" and int(event.get("rank", -1)) == rank:
            return true
    return false
