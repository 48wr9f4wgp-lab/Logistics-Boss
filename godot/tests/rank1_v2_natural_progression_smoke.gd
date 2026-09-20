extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")

const STEP := 0.10
const MAX_SIM_SECONDS := 900.0

const PROJECT_ORDER: Array[StringName] = [
    FlotraV2Sim.PROJECT_RACK_WING,
    FlotraV2Sim.PROJECT_WORKER_HIRE,
    FlotraV2Sim.PROJECT_SECOND_PACKING_BENCH,
    FlotraV2Sim.PROJECT_FORKLIFT,
]


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    var starting_money := sim.money
    var started_contracts := 0
    var project_index := 0
    var expansion_attempted := false

    while sim.sim_time < MAX_SIM_SECONDS and sim.facility_rank < 2:
        if sim.active_contract.is_empty() and not sim.contract_offers.is_empty():
            var offer := _choose_offer(sim.contract_offers)
            if not offer.is_empty():
                var result: Dictionary = sim.choose_contract(int(offer.get("id", -1)))
                if bool(result.get("ok", false)):
                    started_contracts += 1

        if project_index < PROJECT_ORDER.size():
            var project_kind := PROJECT_ORDER[project_index]
            var cost := sim.rank1_project_cost(project_kind)
            if sim.money >= cost:
                var purchase: Dictionary = sim.purchase_rank1_project(project_kind)
                if bool(purchase.get("ok", false)):
                    project_index += 1

        if (
            project_index >= PROJECT_ORDER.size()
            and sim.logistics_rating >= LogisticsProgression.RANK2_RATING
            and sim.money >= FlotraV2Sim.WAREHOUSE_EXPANSION_COST
        ):
            expansion_attempted = true
            var expansion: Dictionary = sim.purchase_warehouse_expansion()
            if not bool(expansion.get("ok", false)):
                _fail("natural progression met the visible Rank 2 conditions but Warehouse Expansion still failed")
                return

        sim.step(STEP)

    if sim.facility_rank != 2:
        _fail(
            "fresh Rank 1 must reach Rank 2 using only earned cash, normal contracts and normal project purchases "
            + "within %.0f simulated seconds; got rank=%d money=%d rating=%d projects=%d contracts=%d shipped=%d"
            % [
                MAX_SIM_SECONDS,
                sim.facility_rank,
                sim.money,
                sim.logistics_rating,
                sim.rank1_projects_completed(),
                sim.completed_contracts,
                sim.shipped,
            ]
        )
        return

    if not expansion_attempted:
        _fail("natural progression must reach Rank 2 through the explicit Warehouse Expansion action")
        return
    if sim.completed_contracts < 4:
        _fail("Rank 2 progression must earn the required logistics rating from completed contracts")
        return
    if sim.logistics_rating < LogisticsProgression.RANK2_RATING:
        _fail("Rank 2 progression must retain earned logistics rating")
        return
    if sim.rank1_projects_completed() != PROJECT_ORDER.size():
        _fail("natural progression must complete all four Rank 1 structural projects")
        return
    if sim.shipped <= 0:
        _fail("natural progression must produce real authoritative shipments")
        return
    if starting_money != 5000:
        _fail("natural progression smoke expects the canonical fresh-save starting cash")
        return

    print(
        "RANK1_V2_NATURAL_PROGRESSION "
        + "time=%.1f contracts=%d started=%d shipped=%d rating=%d money=%d"
        % [
            sim.sim_time,
            sim.completed_contracts,
            started_contracts,
            sim.shipped,
            sim.logistics_rating,
            sim.money,
        ]
    )
    print("Godot Rank 1 v2 natural progression smoke passed")
    quit(0)


func _choose_offer(offers: Array[Dictionary]) -> Dictionary:
    # Prefer the simple shipment contract because it exercises the complete
    # authoritative Inbound→Store→Pick→Pack→Ship chain without state injection.
    for offer in offers:
        if String(offer.get("kind", "")) == "ship":
            return offer
    return offers[0] if not offers.is_empty() else {}
