extends SceneTree
const Main = preload("res://prototype/release_main.gd")
var app
var output: String
func _init() -> void: call_deferred("run")
func capture(label: String) -> void:
    app.hud.refresh()
    app.world.refresh()
    for _i in 8: await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    assert(image.save_png(output.path_join(label+".png")) == OK)
func finish_contract() -> void:
    for _i in 1800:
        app.sim.step(1)
        if app.sim.finished: return
    assert(false,"contract timed out")
func run() -> void:
    output = OS.get_environment("FLOTRA_RELEASE_CAPTURE_DIR")
    assert(not output.is_empty())
    DirAccess.make_dir_recursive_absolute(output)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    for size in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        root.size = size
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        await capture("entry-%d"%size.x)
        app.hud.show_play()
        app.hud.show_job_choices()
        await capture("contracts-%d"%size.x)
        app.hud._request_contract("first_shift")
        app.sim.step(72)
        await capture("running-%d"%size.x)
        app._pause_trial(true)
        app.hud.select_slot("shelf")
        await capture("layout-%d"%size.x)
        app.hud.close_sheet()
        app.sim.step(1200)
        app.hud.show_conditions()
        await capture("completed-%d"%size.x)
        app.hud.show_job_choices()
        app.hud._switch_release_tab("upgrades")
        await capture("upgrades-%d"%size.x)
        app.hud.close_sheet()
        for id in ["worker_4","rack_24","packing_2","floor_2","worker_5"]:
            app.sim.buy_upgrade(id)
        for id in ["small_orders","pallet_wave","packing_rush","storage_peak","final_dispatch"]:
            assert(app.sim.accept_contract(id).ok)
            for upgrade in ["worker_4","rack_24","packing_2","floor_2","worker_5"]:
                app.sim.buy_upgrade(upgrade)
            finish_contract()
            for upgrade in ["worker_4","rack_24","packing_2","floor_2","worker_5"]:
                app.sim.buy_upgrade(upgrade)
        app.hud.show_conditions()
        await capture("campaign-complete-%d"%size.x)
        app.hud.show_play()
        app.sim.accept_contract("storage_peak")
        app.sim.step(60)
        await capture("expanded-%d"%size.x)
        app.queue_free()
        await process_frame
    var file := FileAccess.open(output.path_join("metadata.json"),FileAccess.WRITE)
    file.store_string(JSON.stringify({"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"scope":"native Linux actual campaign states; not iPhone/Safari"},"  "))
    print("RELEASE_CAPTURE_PASS")
    quit()
