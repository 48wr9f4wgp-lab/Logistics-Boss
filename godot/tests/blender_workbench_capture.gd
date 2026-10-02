extends "res://tests/polish_render_capture.gd"

var _measurements: Array[Dictionary] = []

func _run() -> void:
    _directory = OS.get_environment("FLOTRA_POLISH_CAPTURE_DIR")
    if _directory.is_empty() or OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Capture requires output directory and isolated profile")
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
    _empty()
    await _save("empty-390.png")
    await _measure("empty-390")
    _busy()
    await _save("busy-390.png")
    await _measure("busy-390")
    get_root().size = Vector2i(375, 667)
    await _save("busy-375.png")
    get_root().size = Vector2i(430, 932)
    await _save("busy-430.png")
    _sim.packing_queue = 24
    await _save("capacity-backlog-430.png")
    # Inspection camera, distinct from actual portrait gameplay screenshots.
    _view.set_process(false)
    _hud.visible = false
    get_root().size = Vector2i(960, 720)
    _view._camera.position = Vector3(5.8, 4.3, 4.9)
    _view._camera.look_at(Vector3(2.55, 0.83, -0.05), Vector3.UP)
    _view._camera.fov = 32.0
    await _save("workbench-inspection.png")
    var report := {
        "engine": Engine.get_version_info(),
        "device": RenderingServer.get_video_adapter_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "scope": "Actual main scene, synthetic empty/busy states, paused Domain, isolated profile, Linux cloud rendering. Not iPhone evidence.",
        "results": _measurements,
    }
    var f := FileAccess.open(_directory.path_join("render-metrics.json"), FileAccess.WRITE)
    f.store_string(JSON.stringify(report, "  "))
    f.close()
    print("BLENDER_CAPTURE_OK " + JSON.stringify(report))
    _app.queue_free()
    await process_frame
    quit(0)

func _measure(label: String) -> void:
    for _i in 60: await process_frame
    var frame_ms: Array[float] = []
    var draw_calls: Array[float] = []
    var primitives: Array[float] = []
    var previous := Time.get_ticks_usec()
    for _i in 180:
        await process_frame
        var now := Time.get_ticks_usec()
        frame_ms.append(float(now - previous) / 1000.0)
        previous = now
        draw_calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
        primitives.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    frame_ms.sort()
    draw_calls.sort()
    primitives.sort()
    _measurements.append({
        "state": label, "sample_frames": frame_ms.size(), "viewport": str(get_root().size),
        "frame_wall_ms_p50": frame_ms[90], "frame_wall_ms_p95": frame_ms[171],
        "draw_calls_p50": draw_calls[90], "primitives_p50": primitives[90],
        "objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
    })
