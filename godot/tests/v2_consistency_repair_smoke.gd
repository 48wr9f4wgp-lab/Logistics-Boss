extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const MeasurementScript = preload("res://domain/flow_measurement.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")

const STEP := 0.25


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_rank1_worker_activity_copy():
        return
    if not _verify_local_investment_verdict():
        return
    if not _verify_inflight_worker_inventory_survives_downsize():
        return
    if not _verify_inflight_forklift_inventory_survives_downsize():
        return

    print("Godot v2 consistency repair smoke passed")
    quit(0)


func _verify_rank1_worker_activity_copy() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.step(0.1)

    var activity: Dictionary = sim.worker_activity_summary()
    var total_count := (
        int(activity.get("store", 0))
        + int(activity.get("pick", 0))
        + int(activity.get("ship", 0))
        + int(activity.get("idle", 0))
    )
    if int(activity.get("total", 0)) != 3 or total_count != 3:
        _fail("Rank 1 worker activity summary must account for all three authoritative Workers")
        return false

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone("inbound")
    await process_frame
    panel._process(0.0)

    if not panel._operations.text.contains("全Worker 3人") or not panel._operations.text.contains("自動配分"):
        _fail("Rank 1 Zone Panel must describe dynamic Worker allocation instead of showing role count 0")
        return false

    panel.queue_free()
    await process_frame
    return true


func _verify_local_investment_verdict() -> bool:
    var measurement: FlowMeasurement = MeasurementScript.new()
    var at := 0.0

    for _index in int(ceil(25.0 / STEP)):
        at += STEP
        measurement.record_state(
            at,
            STEP,
            4,
            2,
            1,
            2,
            7,
            8
        )

    var before := measurement.begin_investment(&"rank1_rack_wing", 2500, at)
    if float(before.get("rack_pressure", 0.0)) < 0.80:
        _fail("consistency smoke requires a high pre-investment rack pressure baseline")
        return false

    for _index in int(ceil(25.0 / STEP)):
        at += STEP
        measurement.record_state(
            at,
            STEP,
            4,
            2,
            1,
            2,
            7,
            12
        )

    var completed := measurement.collect_completed(at)
    if completed.size() != 1:
        _fail("Rack Wing local-effect measurement must complete after 25 seconds")
        return false

    var verdict: Dictionary = completed[0].get("verdict", {})
    if String(verdict.get("state", "")) != "improved":
        _fail("Rack Wing must be allowed to score improvement from reduced storage pressure even with flat shipments")
        return false
    if String(verdict.get("basis_key", "")) != "rack_pressure":
        _fail("Rack Wing verdict must expose rack_pressure as its operational basis")
        return false
    if String(verdict.get("basis", "")) != "保管圧":
        _fail("Rack Wing verdict must expose a player-readable storage-pressure basis")
        return false

    return true


func _verify_inflight_worker_inventory_survives_downsize() -> bool:
    var sim := _prepared_rank2_high_density()
    if sim.facility_rank != 2:
        return false

    var old_capacity := sim.rack_capacity
    sim.rack_stock = old_capacity - 1
    sim.inbound_queue = 1

    var worker := sim.workers[0]
    sim.call("_start_task", worker, WarehouseSim.Task.STORE)
    if sim.inbound_queue != 0:
        _fail("in-flight worker preservation smoke must reserve one inbound box")
        return false

    var renovate: Dictionary = sim.purchase_facility(&"fast_pick_rack")
    if not bool(renovate.get("ok", false)):
        _fail("worker preservation smoke must renovate High Density → Fast Pick")
        return false
    if sim.rack_capacity >= old_capacity:
        _fail("worker preservation smoke requires a real capacity-down renovation")
        return false

    sim.call("_update_workers", 4.0)
    if sim.rack_stock != old_capacity:
        _fail("in-flight STORE completion must preserve inventory above the new nominal capacity")
        return false

    return true


func _verify_inflight_forklift_inventory_survives_downsize() -> bool:
    var sim := _prepared_rank2_high_density()
    if sim.facility_rank != 2 or not sim.forklift_unlocked:
        return false

    var old_capacity := sim.rack_capacity
    sim.rack_stock = old_capacity - 1
    sim.inbound_queue = 1
    sim.call("_update_forklift", 0.0)

    if not sim.forklift_active or sim.inbound_queue != 0:
        _fail("in-flight forklift preservation smoke must start one reserved transfer")
        return false

    var renovate: Dictionary = sim.purchase_facility(&"fast_pick_rack")
    if not bool(renovate.get("ok", false)):
        _fail("forklift preservation smoke must renovate High Density → Fast Pick")
        return false

    sim.call("_update_forklift", WarehouseSim.FORKLIFT_CYCLE + 0.1)
    if sim.rack_stock != old_capacity:
        _fail("in-flight Forklift completion must preserve inventory above the new nominal capacity")
        return false

    return true


func _prepared_rank2_high_density() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 250000
    for kind in sim.rank1_project_kinds():
        var project: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(project.get("ok", false)):
            _fail("consistency seed must complete Rank 1 project: %s" % String(kind))
            return sim

    sim.logistics_rating = LogisticsProgression.RANK2_RATING

    sim.shipped = maxi(sim.shipped, FlotraV2Sim.EXPANSION_SHIPMENTS) # Explicit Rank2 fixture, not pacing evidence.
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)):
        _fail("consistency seed must expand to Rank 2")
        return sim

    sim.money = 250000
    var build: Dictionary = sim.purchase_facility(&"high_density_rack")
    if not bool(build.get("ok", false)):
        _fail("consistency seed must install High Density Rack")
    return sim
