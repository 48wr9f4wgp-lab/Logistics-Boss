extends SceneTree

const MainScript = preload("res://main.gd")
const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    _clear_runtime_save()
    push_error(message)
    quit(1)


func _run() -> void:
    _clear_runtime_save()

    # Seed a real experienced Rank 2 save so startup exercises the returning-player
    # path instead of only the fresh-save path.
    var seeded = SimScript.new()
    seeded.money = 42000
    seeded.shipped = 12
    seeded.logistics_rating = 8
    seeded.facility_rank = 2
    seeded.completed_contracts = 4
    seeded.worker_count = 5
    seeded.facilities["buffer_yard"] = true
    var seed_store: LogisticsSaveStore = SaveStoreScript.new()
    if not seed_store.save_sim(seeded):
        _fail("runtime startup smoke must be able to seed a returning-player save")
        return

    var main = MainScript.new()
    get_root().add_child(main)
    await process_frame
    await process_frame

    if main.sim == null:
        _fail("runtime startup must create an authoritative simulation")
        return
    if main.sim.facility_rank != 2 or main.sim.logistics_rating < 8:
        _fail("runtime startup must restore authoritative progression before presentation binds")
        return
    if int(main.sim.save_data().get("schema_version", -1)) != FlotraV2Sim.SAVE_SCHEMA_V2:
        _fail("runtime startup must migrate the schema 7 seed into the schema 8 v2 runtime")
        return

    var hud = null
    for child in main.get_children():
        if child is GameHud:
            hud = child
            break
    if hud == null:
        _fail("runtime startup must attach the gameplay HUD")
        return
    if hud.sim == null:
        _fail("runtime startup must bind simulation to HUD")
        return
    if hud._money == null or hud._money.text == "—":
        _fail("runtime HUD must render live money instead of placeholder")
        return

    var warehouse_view: WarehouseView = null
    for child in main.get_children():
        if child is WarehouseView:
            warehouse_view = child as WarehouseView
            break
    if warehouse_view == null:
        _fail("runtime startup must attach the warehouse view")
        return

    var domain_liveness: WarehouseDomainLivenessView = null
    for child in warehouse_view.get_children():
        if child is WarehouseDomainLivenessView:
            domain_liveness = child as WarehouseDomainLivenessView
            break
    if domain_liveness == null:
        _fail("runtime startup must attach domain-driven warehouse liveness")
        return

    warehouse_view._sync_workers()
    domain_liveness._process(0.0)
    var workers_root := warehouse_view.get_node_or_null("Workers") as Node3D
    if workers_root == null or workers_root.get_child_count() == 0:
        _fail("warehouse liveness smoke requires visible authoritative workers")
        return
    var worker := workers_root.get_child(0) as Node3D
    if worker == null or worker.get_node_or_null("LivenessLeftArm") == null or worker.get_node_or_null("LivenessRightArm") == null:
        _fail("visible workers must receive readable arm silhouettes")
        return
    if worker.get_node_or_null("LivenessVestStripe") == null:
        _fail("visible workers must receive phone-readable safety-vest detail")
        return

    main.sim.workers[0]["task"] = WarehouseSim.Task.STORE
    main.sim.workers[0]["progress"] = 0.25
    domain_liveness._process(0.016)
    var left_arm := worker.get_node("LivenessLeftArm") as Node3D
    if left_arm == null or absf(left_arm.rotation.x) < 0.20:
        _fail("active authoritative worker task must drive visible walk motion")
        return

    main.sim.workers[0]["task"] = WarehouseSim.Task.IDLE
    domain_liveness._process(0.0)
    if absf(left_arm.rotation.x) > 0.001:
        _fail("idle workers must not retain fake walk motion")
        return

    var forklift := warehouse_view.get_node_or_null("Forklift") as Node3D
    if forklift == null:
        _fail("warehouse liveness smoke requires the physical forklift")
        return
    var beacon := forklift.get_node_or_null("LivenessBeacon") as MeshInstance3D
    if beacon == null:
        _fail("forklift must receive a low-cost activity beacon")
        return
    if beacon.visible:
        _fail("locked/inactive forklift must not fake an active beacon")
        return

    main.sim.forklift_unlocked = true
    main.sim.forklift_active = true
    main.sim.forklift_progress = 0.25
    domain_liveness._process(0.1)
    if not beacon.visible:
        _fail("authoritative active forklift state must enable its activity beacon")
        return
    var beacon_material := beacon.material_override as StandardMaterial3D
    if beacon_material == null or beacon_material.emission_energy_multiplier <= 1.7:
        _fail("active forklift beacon must be visibly emissive without a dynamic light")
        return

    main.sim.forklift_active = false
    domain_liveness._process(0.0)
    if beacon.visible:
        _fail("inactive forklift must return to a visually quiet state")
        return

    var resume_brief: LogisticsSessionResumeBrief = null
    for child in hud.get_children():
        if child is LogisticsSessionResumeBrief:
            resume_brief = child as LogisticsSessionResumeBrief
            break
    if resume_brief == null:
        _fail("returning startup must attach the session resume brief")
        return
    if not resume_brief.visible:
        _fail("experienced restored saves must surface the continuity brief on startup")
        return
    if resume_brief._label == null or not resume_brief._label.text.contains("RANK 3まで"):
        _fail("Rank 2 resume brief must expose the next facility milestone")
        return
    if not resume_brief._label.text.contains("拡張 1/3"):
        _fail("resume brief must read restored structural progress from the authoritative Domain")
        return

    if main.analytics == null or not _has_analytics_event(main.analytics.events(), "session_resume"):
        _fail("returning startup must record a provider-neutral session_resume analytics event")
        return

    resume_brief._process(LogisticsSessionResumeBrief.DISPLAY_SECONDS + 0.1)
    if resume_brief.visible:
        _fail("resume brief must yield the warehouse view after its short continuity window")
        return

    var before_time := float(main.sim.sim_time)
    await create_timer(0.25).timeout
    if float(main.sim.sim_time) <= before_time:
        _fail("runtime simulation clock must advance after startup")
        return

    main.queue_free()
    await process_frame
    _clear_runtime_save()
    print("Godot runtime startup, domain liveness, and returning-session brief smoke passed")
    quit(0)


func _has_analytics_event(events: Array[Dictionary], event_name: String) -> bool:
    for event in events:
        if String(event.get("name", "")) == event_name:
            return true
    return false


func _clear_runtime_save() -> void:
    for path in [
        SaveStoreScript.SAVE_PATH,
        SaveStoreScript.TEMP_PATH,
        SaveStoreScript.BACKUP_PATH,
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
