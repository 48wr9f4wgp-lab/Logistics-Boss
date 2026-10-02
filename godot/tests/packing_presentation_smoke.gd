extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const ViewScript = preload("res://view/warehouse_view.gd")
const Pass2Script = preload("res://view/visual_pass_2.gd")
const Pass3Script = preload("res://view/visual_pass_3.gd")
const QueueScript = preload("res://view/queue_pressure_view.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")

var failures := 0


func _init() -> void:
    call_deferred("_run")


func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)


func _run() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0

    var view: WarehouseView = ViewScript.new()
    get_root().add_child(view)
    view.bind_sim(sim)
    var pass2: WarehouseVisualPass2 = Pass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    var pass3: WarehouseVisualPass3 = Pass3Script.new()
    view.add_child(pass3)
    pass3.bind(view, hud)
    var queue: WarehouseQueuePressureView = QueueScript.new()
    view.add_child(queue)
    queue.bind(view, sim)
    await process_frame
    await process_frame

    _check(pass2.find_children("PalletCarton*", "MeshInstance3D", true, false).is_empty(), "Empty staging pallets must not invent incoming goods")
    _check(pass2.find_children("ParcelStack*", "MeshInstance3D", true, false).is_empty(), "Packing decoration must not invent waiting/output goods")
    _check(pass3.find_children("Carton", "MeshInstance3D", true, false).is_empty(), "Rack and packing decoration must not invent stock")
    _check(_visible_jobs(pass3) == 0, "Empty operation hides every in-process parcel")
    _check(_lamp_energy(pass3._packing_green) == 0.0 and _lamp_energy(pass3._packing_amber) == 0.0, "Idle status lamps must both be dark")
    _check(view._rack_boxes.get_child_count() == 0 and view._inbound_boxes.get_child_count() == 0 and view._packed_boxes.get_child_count() == 0, "Empty stock has no goods in the authoritative stock views")
    _check(int(queue.visible_backlog_counts()["packing"]) == 0, "Empty packing has no backlog parcels")

    var parcel_ids: Array[int] = []
    for parcel in pass3._packing_parcels:
        parcel_ids.append(parcel.get_instance_id())
    _check(parcel_ids.size() == WarehouseVisualPass3.PACKING_JOB_VISUAL_CAP, "Packing uses a bounded two-slot pool")

    sim.packing_queue = 1
    sim._update_packing(0.25)
    pass3._sync_packing_activity()
    _check(_visible_jobs(pass3) == 1 and sim._packing_jobs.size() == 1, "A real packing job exposes exactly one process parcel")
    _check(_lamp_energy(pass3._packing_green) > 0.0 and _lamp_energy(pass3._packing_amber) == 0.0, "Processing without pressure lights only green")
    var early_position := pass3._packing_parcels[0].position
    sim._update_packing(0.50)
    pass3._sync_packing_activity()
    _check(pass3._packing_parcels[0].position.x > early_position.x, "Parcel movement follows authoritative remaining job time")

    sim.set_time_scale(0.0)
    var paused_position := pass3._packing_parcels[0].position
    var paused_jobs: Array[float] = sim._packing_jobs.duplicate()
    for i in 10:
        sim.step(0.25)
        pass3._process(0.25)
    _check(pass3._packing_parcels[0].position == paused_position and sim._packing_jobs == paused_jobs, "Pause freezes semantic cargo movement")

    var saved_before: Dictionary = sim.save_data()
    var event_count := {"value": 0}
    sim.event_emitted.connect(func(_event: Dictionary): event_count["value"] += 1)
    for i in 20:
        pass3._process(1.0)
    _check(sim.save_data() == saved_before and sim._packing_jobs == paused_jobs, "Presentation never mutates economy, saves, or task state")
    _check(int(event_count["value"]) == 0, "Presentation never emits simulated logistics events")
    _check(FlotraV2Sim.SAVE_SCHEMA_V2 == 11, "Presentation polish preserves schema 11")

    sim.set_time_scale(1.0)
    sim.packing_queue = 8
    pass3._sync_packing_activity()
    queue._sync_queues()
    _check(_lamp_energy(pass3._packing_green) == 0.0 and _lamp_energy(pass3._packing_amber) > 0.0, "Waiting pressure lights only amber, even while processing")
    _check(int(queue.visible_backlog_counts()["packing"]) == 8, "Waiting parcels stay owned by QueuePressureView")
    _check(_visible_jobs(pass3) == 1, "Backlog must not be duplicated as in-process parcels")

    sim.rank1_projects["second_packing_bench"] = true
    sim._update_packing(0.10)
    pass3._sync_packing_activity()
    _check(_visible_jobs(pass3) == 2 and sim._packing_jobs.size() == 2, "Parallel work shows exactly two active parcels")
    _check(pass3._packing_parcels[1].position.z > 1.0, "Second job is presented on the actual second bench")
    sim.packing_queue = 0
    sim._update_packing(10.0)
    pass3._sync_packing_activity()
    _check(_visible_jobs(pass3) == 0, "Completing all jobs clears every in-process parcel")
    _check(_lamp_energy(pass3._packing_green) == 0.0 and _lamp_energy(pass3._packing_amber) == 0.0, "Cleared work restores quiet lamps")

    # Expansion cells have their own truthful cargo in CapacityGrowthView. They
    # must never be double-counted on the base packing benches.
    sim._cell_jobs.append(2.0)
    pass3._sync_packing_activity()
    _check(_visible_jobs(pass3) == 0, "Expansion cell jobs are not duplicated on the base packing benches")
    for i in parcel_ids.size():
        _check(parcel_ids[i] == pass3._packing_parcels[i].get_instance_id(), "Cargo pool stays fixed through empty/active/pressure transitions")

    hud.queue_free()
    view.queue_free()
    await process_frame
    print("Packing presentation regression failures=%d" % failures)
    quit(0 if failures == 0 else 1)


func _visible_jobs(pass3: WarehouseVisualPass3) -> int:
    var count := 0
    for parcel in pass3._packing_parcels:
        if parcel.visible:
            count += 1
    return count


func _lamp_energy(lamp: MeshInstance3D) -> float:
    return (lamp.material_override as StandardMaterial3D).emission_energy_multiplier
