extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const STEP_SECONDS := 0.25
const RECOVERY_LIMIT_SECONDS := 600.0
const RANK2_PLANS := ["balanced", "receiving", "picking", "dock", "shipping"]
const INTAKE_OPTIONS := [&"double_dock", &"buffer_yard"]
const STORAGE_OPTIONS := [&"fast_pick_rack", &"high_density_rack"]
const PACKING_OPTIONS := [&"parallel_pack", &"fast_pack_cell"]
const ROUTES := [
    Rank3WarehouseSim.ROUTE_BALANCED,
    Rank3WarehouseSim.ROUTE_EXPRESS,
    Rank3WarehouseSim.ROUTE_CONSOLIDATED,
]


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not _verify_rank1_zero_cash_contract_recovery():
        return
    if not _verify_rank2_staffing_zero_cash_recovery():
        return
    if not _verify_rank2_exclusive_facility_paths_recover():
        return
    if not _verify_rank3_routes_zero_cash_recovery():
        return
    if not _verify_rank3_structural_cash_recovery():
        return

    print("Godot progression/resource dead-end audit passed")
    quit(0)


func _verify_rank1_zero_cash_contract_recovery() -> bool:
    var sim = SimScript.new()
    sim.money = 0

    var ship_offer_id := -1
    for offer in sim.contract_offers:
        if String(offer.get("kind", "")) == "ship":
            ship_offer_id = int(offer.get("id", -1))
            break
    if ship_offer_id < 0:
        _fail("fresh Rank 1 must expose a shipment contract without requiring cash")
        return false
    if not bool(sim.choose_contract(ship_offer_id).get("ok", false)):
        _fail("zero-cash Rank 1 must still be able to accept a progression contract")
        return false

    var start_shipped: int = sim.shipped
    if not _advance_until(sim, func() -> bool:
        return sim.completed_contracts >= 1
    , 120.0):
        _fail("zero-cash Rank 1 must complete the normal shipment contract through autonomous flow")
        return false
    if sim.shipped <= start_shipped or sim.money <= 0 or sim.logistics_rating <= 0:
        _fail("Rank 1 zero-cash recovery must restore shipments, cash, and rating progress")
        return false
    return true


func _verify_rank2_staffing_zero_cash_recovery() -> bool:
    for plan in RANK2_PLANS:
        var sim = _rank2_seed(String(plan))
        sim.money = 0
        var summary: Dictionary = sim.staffing_summary()
        if int(summary.get("store", 0)) <= 0 or int(summary.get("pick", 0)) <= 0 or int(summary.get("ship", 0)) <= 0:
            _fail("Rank 2 staffing preset must never remove a required logistics role: %s" % String(plan))
            return false

        var start_shipped: int = sim.shipped
        if not _advance_until(sim, func() -> bool:
            return sim.money >= 10000
        , RECOVERY_LIMIT_SECONDS):
            _fail("Rank 2 staffing preset must recover from zero cash to the cheapest structural investment: %s" % String(plan))
            return false
        if sim.shipped <= start_shipped:
            _fail("Rank 2 staffing preset must keep authoritative shipment flow alive: %s" % String(plan))
            return false
    return true


func _verify_rank2_exclusive_facility_paths_recover() -> bool:
    for intake in INTAKE_OPTIONS:
        for storage in STORAGE_OPTIONS:
            for packing in PACKING_OPTIONS:
                var sim = _rank2_seed("balanced")
                sim.money = 1000000
                for kind in [intake, storage, packing]:
                    if not bool(sim.purchase_facility(kind).get("ok", false)):
                        _fail("Rank 2 dead-end audit could not construct facility path: %s" % String(kind))
                        return false

                sim.money = 0
                var start_shipped: int = sim.shipped
                if not _advance_until(sim, func() -> bool:
                    return sim.money >= CapitalCatalog.FORKLIFT_COST
                , RECOVERY_LIMIT_SECONDS):
                    _fail(
                        "Rank 2 exclusive facility choices must not create a zero-cash progression dead end: %s / %s / %s"
                        % [String(intake), String(storage), String(packing)]
                    )
                    return false
                if sim.shipped <= start_shipped:
                    _fail("Rank 2 facility path must keep shipping after cash is fully spent")
                    return false
    return true


func _verify_rank3_routes_zero_cash_recovery() -> bool:
    for route in ROUTES:
        var sim = _rank3_seed(String(route), false, false)
        sim.money = 0
        var start_shipped: int = sim.shipped
        if not _advance_until(sim, func() -> bool:
            return sim.money > 0
        , RECOVERY_LIMIT_SECONDS):
            _fail("Rank 3 routing mode must recover from zero cash: %s" % String(route))
            return false
        if sim.shipped <= start_shipped:
            _fail("Rank 3 routing mode must keep authoritative shipment flow alive: %s" % String(route))
            return false
    return true


func _verify_rank3_structural_cash_recovery() -> bool:
    var sim = _rank3_seed(Rank3WarehouseSim.ROUTE_BALANCED, false, false)
    sim.money = 0

    if not _advance_until(sim, func() -> bool:
        return sim.money >= sim.receiving_annex_cost()
    , RECOVERY_LIMIT_SECONDS):
        _fail("Rank 3 must be able to fund Receiving Annex from zero cash through live operations")
        return false
    if not bool(sim.purchase_receiving_annex().get("ok", false)):
        _fail("recovered Rank 3 cash must purchase Receiving Annex normally")
        return false

    sim.money = 0
    if not _advance_until(sim, func() -> bool:
        return sim.money >= sim.inbound_carrier_program_cost()
    , RECOVERY_LIMIT_SECONDS):
        _fail("post-Annex Rank 3 must be able to fund the inbound carrier program from zero cash")
        return false
    if not bool(sim.purchase_inbound_carrier_program().get("ok", false)):
        _fail("recovered post-Annex cash must purchase the inbound carrier program normally")
        return false

    var start_shipped: int = sim.shipped
    _advance_for(sim, 120.0)
    if sim.shipped <= start_shipped:
        _fail("late Rank 3 structural investments must not deadlock shipment flow")
        return false
    return true


func _rank2_seed(plan: String):
    var sim = SimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = Rank3InboundCarrierSim.SAVE_SCHEMA_INBOUND_CARRIER
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["completed_contracts"] = 4
    data["worker_count"] = 5
    data["money"] = 0
    data["forklift_unlocked"] = true
    data["staffing_plan"] = plan
    data["staffing_cooldown"] = 0.0
    data["inbound_queue"] = 0
    data["rack_stock"] = 0
    data["packing_queue"] = 0
    data["packed_queue"] = 0
    data["open_orders"] = 0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    data["receiving_annex_unlocked"] = false
    data["inbound_carrier_program_unlocked"] = false
    if not sim.load_data(data):
        _fail("Rank 2 dead-end seed must load")
    return sim


func _rank3_seed(route: String, annex: bool, carrier: bool):
    var sim = SimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = Rank3InboundCarrierSim.SAVE_SCHEMA_INBOUND_CARRIER
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 0
    data["forklift_unlocked"] = true
    data["rack_level"] = 2
    data["speed_level"] = 2
    data["pack_level"] = 2
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["active_routing_mode"] = route
    data["receiving_annex_unlocked"] = annex
    data["inbound_carrier_program_unlocked"] = carrier and annex
    data["inbound_queue"] = 0
    data["rack_stock"] = 0
    data["packing_queue"] = 0
    data["packed_queue"] = 0
    data["open_orders"] = 0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    if not sim.load_data(data):
        _fail("Rank 3 dead-end seed must load")
    return sim


func _advance_until(sim, condition: Callable, max_seconds: float) -> bool:
    var steps := int(ceil(max_seconds / STEP_SECONDS))
    for _i in steps:
        if condition.call():
            return true
        sim.step(STEP_SECONDS)
    return bool(condition.call())


func _advance_for(sim, seconds: float) -> void:
    var steps := int(ceil(seconds / STEP_SECONDS))
    for _i in steps:
        sim.step(STEP_SECONDS)
