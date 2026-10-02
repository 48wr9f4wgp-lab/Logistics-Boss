extends "res://tests/blender_workbench_capture.gd"

func _run() -> void:
    _directory = OS.get_environment("FLOTRA_POLISH_CAPTURE_DIR")
    if _directory.is_empty() or OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Capture requires output and isolated profile")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(_directory)
    get_root().size = Vector2i(390, 844)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    _app = MainScene.instantiate()
    get_root().add_child(_app)
    _app.set_process(false)
    _sim = _app.get("sim")
    for child in _app.get_children():
        if child is WarehouseView: _view = child
        if child is MobileGameHud: _hud = child
    _sim.set_time_scale(0.0)
    var clarity := _hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.coach.visible = false
    for viewport in [Vector2i(390,844), Vector2i(375,667), Vector2i(430,932)]:
        get_root().size = viewport
        _empty()
        await _save("empty-%d.png" % viewport.x)
        if viewport.x == 390: await _measure("empty-390")
        _busy()
        await _save("busy-%d.png" % viewport.x)
        if viewport.x == 390: await _measure("busy-390")
    get_root().size = Vector2i(390,844)
    clarity.zone.open_zone("packing")
    await _save("packing-panel-390.png")
    clarity.zone.close()
    _view.set_process(false)
    _hud.visible = false
    get_root().size = Vector2i(1024,768)
    _view._camera.position = Vector3(-11.5,13.5,13.0)
    _view._camera.look_at(Vector3(0.0,0.7,0.2),Vector3.UP)
    _view._camera.fov = 45.0
    await _save("warehouse-inspection.png")
    await _capture_later_rank()
    var report := {"engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual main scene, identical synthetic states, paused Domain, Linux cloud renderer. Not iPhone QA.","results":_measurements}
    var f := FileAccess.open(_directory.path_join("render-metrics.json"),FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "))
    f.close()
    print("WAREHOUSE_COHESION_CAPTURE_OK " + JSON.stringify(report))
    _app.queue_free()
    await process_frame
    quit(0)


func _empty() -> void:
    super._empty()
    _view._sync_workers()
    for i in _view._worker_nodes.size():
        var role := String(_sim.workers[i].get("role", ""))
        _view._worker_nodes[i].position = WorkRoutes.waiting(role, i)


func _capture_later_rank() -> void:
    var data := _sim.save_data()
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["worker_count"] = 5
    data["receiving_annex_unlocked"] = true
    data["inbound_carrier_program_unlocked"] = true
    data["active_routing_mode"] = "balanced"
    data["facilities"] = {"double_dock":false,"buffer_yard":true,"fast_pick_rack":true,"high_density_rack":false,"parallel_pack":false,"fast_pack_cell":true}
    if not _sim.load_data(data):
        push_error("Synthetic later-rank capture must load")
        quit(1)
        return
    _sim.set_time_scale(0.0)
    _view.set_process(true)
    _hud.visible = true
    get_root().size = Vector2i(430,932)
    _view._camera_distance = 32.0
    _view._orbit_yaw = MobileWarehouseView.OVERVIEW_YAW
    _view._orbit_pitch = MobileWarehouseView.OVERVIEW_PITCH
    _view._camera_pose_initialized = false
    await _save("rank3-max-zoom-430.png")
    _view._orbit_pitch = -0.48
    _view._camera_pose_initialized = false
    await _save("rank3-max-zoom-low-angle-430.png")
