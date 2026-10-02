extends "res://tests/blender_workbench_capture.gd"

func _run() -> void:
    _directory = OS.get_environment("FLOTRA_POLISH_CAPTURE_DIR")
    if _directory.is_empty() or OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Capture requires output and isolated profile")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(_directory)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for viewport in [Vector2i(375,667), Vector2i(390,844), Vector2i(430,932)]:
        get_root().size = viewport
        _app = MainScene.instantiate()
        get_root().add_child(_app)
        _app.set_process(false)
        _sim = _app.get("sim")
        for child in _app.get_children():
            if child is WarehouseView: _view = child
            if child is MobileGameHud: _hud = child
        _hud._speed_index = 3
        _hud._cycle_speed() # Use the real pause handler so the button matches the fixture.
        var clarity := _hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
        clarity.coach._persist_completion = false
        clarity.coach._process(5.0)
        await _save("guide-%d.png" % viewport.x)
        clarity._open_goal()
        (_hud._v2_zone_nav_buttons["storage"] as Button).pressed.emit()
        await _save("inspect-%d.png" % viewport.x)
        _sim.money = 0
        clarity.zone._on_operations_action()
        await _save("failure-%d.png" % viewport.x)
        clarity.zone.close()
        _sim.money = 10000
        clarity.zone.open_zone("storage")
        clarity.zone._on_capital_action()
        await _save("preview-%d.png" % viewport.x)
        clarity.zone._on_capital_action()
        await _save("measuring-%d.png" % viewport.x)
        if viewport.x == 390: await _measure("paused-investment-390")
        _sim.set_time_scale(1.0)
        for _i in 510: _sim.step(0.05)
        _sim.set_time_scale(0.0)
        await _save("result-%d.png" % viewport.x)
        _app.queue_free()
        await process_frame
    var report := {"engine": Engine.get_version_info(), "device": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "scope": "Actual main scene, identical synthetic states and isolated profiles; native Linux cloud render, not iPhone QA", "results": _measurements}
    var file := FileAccess.open(_directory.path_join("render-metrics.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("PLAYFLOW_CAPTURE_OK actual-main synthetic-state native-render not-device-QA")
    quit(0)
