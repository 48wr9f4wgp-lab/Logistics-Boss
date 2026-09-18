extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")

const STEP := 0.05


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var fast_pick_orders := _storage_order_backlog(&"fast_pick_rack")
    var dense_orders := _storage_order_backlog(&"high_density_rack")
    if fast_pick_orders <= dense_orders:
        _fail("Fast Pick Rack must win the order-backlog scenario")
        return

    var fast_pick_buffer := _storage_buffer_absorption(&"fast_pick_rack")
    var dense_buffer := _storage_buffer_absorption(&"high_density_rack")
    if dense_buffer <= fast_pick_buffer:
        _fail("High Density Rack must win the storage-pressure scenario")
        return

    var parallel_long_queue := _packing_long_queue(&"parallel_pack")
    var fast_cell_long_queue := _packing_long_queue(&"fast_pack_cell")
    if parallel_long_queue <= fast_cell_long_queue:
        _fail("Parallel Pack Line must win the long-queue throughput scenario: parallel=%d fast=%d" % [
            parallel_long_queue,
            fast_cell_long_queue,
        ])
        return

    var parallel_latency := _packing_single_job_latency(&"parallel_pack")
    var fast_cell_latency := _packing_single_job_latency(&"fast_pack_cell")
    if fast_cell_latency >= parallel_latency:
        _fail("Fast Pack Cell must win the single-job latency scenario")
        return

    print("Rank 2 v2 dominance smoke passed")
    print("STORAGE orders fast=%d dense=%d" % [fast_pick_orders, dense_orders])
    print("STORAGE buffer fast=%d dense=%d" % [fast_pick_buffer, dense_buffer])
    print("PACKING long_queue parallel=%d fast=%d" % [parallel_long_queue, fast_cell_long_queue])
    print("PACKING latency parallel=%.2f fast=%.2f" % [parallel_latency, fast_cell_latency])
    quit(0)


func _rank2_sim() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 250000
    for kind in sim.rank1_project_kinds():
        var result: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(result.get("ok", false)):
            _fail("dominance seed must complete Rank 1 project: %s" % String(kind))
            return sim
    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)):
        _fail("dominance seed must expand to Rank 2")
        return sim
    sim.money = 250000
    sim.staffing_cooldown = 0.0
    return sim


func _freeze_sources(sim: FlotraV2Sim) -> void:
    sim._inbound_timer = 9999.0
    sim._order_timer = 9999.0


func _storage_order_backlog(kind: StringName) -> int:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(kind).get("ok", false)):
        return -1
    if not bool(sim.reassign_zone_staffing("inbound", "picking").get("ok", false)):
        return -1

    _freeze_sources(sim)
    sim.inbound_queue = 0
    sim.rack_stock = 20
    sim.open_orders = 18
    sim.packing_queue = 0
    sim.packed_queue = 0

    var counter := {"picked": 0}
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        if String(event.get("type", "")) == "picked":
            counter["picked"] = int(counter["picked"]) + 1
    )

    for _index in int(ceil(20.0 / STEP)):
        sim.step(STEP)
    return int(counter["picked"])


func _storage_buffer_absorption(kind: StringName) -> int:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(kind).get("ok", false)):
        return -1
    if not bool(sim.reassign_zone_staffing("picking", "inbound").get("ok", false)):
        return -1

    _freeze_sources(sim)
    sim.inbound_queue = 14
    sim.rack_stock = 20
    sim.open_orders = 0
    sim.packing_queue = 0
    sim.packed_queue = 0

    var start_stock := sim.rack_stock
    for _index in int(ceil(14.0 / STEP)):
        sim.step(STEP)
    return sim.rack_stock - start_stock


func _packing_long_queue(kind: StringName) -> int:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(kind).get("ok", false)):
        return -1

    _freeze_sources(sim)
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.open_orders = 0
    sim.packing_queue = 200
    sim.packed_queue = 0

    var counter := {"completed": 0}
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        if String(event.get("type", "")) == "packing_complete":
            counter["completed"] = int(counter["completed"]) + 1
    )

    for _index in int(ceil(180.0 / STEP)):
        sim.step(STEP)
    return int(counter["completed"])


func _packing_single_job_latency(kind: StringName) -> float:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(kind).get("ok", false)):
        return INF

    _freeze_sources(sim)
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.open_orders = 0
    sim.packing_queue = 1
    sim.packed_queue = 0

    var state := {"completed_at": INF}
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        if String(event.get("type", "")) == "packing_complete" and is_inf(float(state["completed_at"])):
            state["completed_at"] = sim.sim_time
    )

    for _index in int(ceil(6.0 / STEP)):
        sim.step(STEP)
        if not is_inf(float(state["completed_at"])):
            break
    return float(state["completed_at"])
