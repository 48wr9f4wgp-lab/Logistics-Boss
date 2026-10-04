extends "res://tests/release/release_capture.gd"
## Source/PCK visual fixture at actual CSS-equivalent phone dimensions.
func run() -> void:
    output = OS.get_environment("FLOTRA_RELEASE_CAPTURE_DIR")
    assert(not output.is_empty())
    DirAccess.make_dir_recursive_absolute(output)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for size in [Vector2i(375,567), Vector2i(375,667), Vector2i(390,844), Vector2i(430,932), Vector2i(667,320), Vector2i(667,354)]:
        root.size = size
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        var suffix := "-%dx%d" % [size.x, size.y]
        await capture("entry" + suffix)
        app.hud.show_play()
        app.hud.show_job_choices()
        await capture("contracts" + suffix)
        app.hud._request_contract("first_shift")
        app.sim.step(72)
        await capture("running" + suffix)
        app._pause_trial(true)
        app.hud.select_slot("shelf")
        await capture("layout" + suffix)
        app.hud._choose("annex")
        app.hud._scroll.scroll_vertical = 1000
        await capture("layout-details" + suffix)
        app.hud.close_sheet()
        app.sim.step(1200)
        app.hud.show_conditions()
        await capture("completed" + suffix)
        app.hud._scroll.scroll_vertical = 1000
        await capture("result-controls" + suffix)
        app.hud.show_job_choices()
        app.hud._switch_release_tab("upgrades")
        await capture("upgrades" + suffix)
        app.queue_free()
        await process_frame
    var file := FileAccess.open(output.path_join("phone-metadata.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"scope":"native rendered CSS-equivalent phone viewports; physical iPhone/Safari not verified"},"  "))
    print("PHONE_HUD_CAPTURE_PASS")
    quit()
