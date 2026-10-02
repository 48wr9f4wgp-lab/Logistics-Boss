extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
var _directory := ""
var _app: Node
var _sim: WarehouseSim
var _view: WarehouseView
var _hud: MobileGameHud

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _directory = OS.get_environment("FLOTRA_POLISH_CAPTURE_DIR")
    if _directory.is_empty() or OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Capture requires FLOTRA_POLISH_CAPTURE_DIR and isolated test profile")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(_directory)
    get_root().size = Vector2i(390, 844)
    _app = MainScene.instantiate()
    get_root().add_child(_app)
    # The actual production scene is composed, but this diagnostic fixture owns
    # progression: no wall-clock simulation/autosave and no user profile writes.
    _app.set_process(false)
    _sim = _app.get("sim")
    for child in _app.get_children():
        if child is WarehouseView: _view = child
        if child is MobileGameHud: _hud = child
    _sim.set_time_scale(0.0)
    await _save("fresh-390.png")
    var clarity := _hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.coach.visible = false
    _empty()
    await _save("empty-390.png")
    if OS.get_environment("FLOTRA_LABEL_EXPERIMENT") == "1":
        var zones: WarehouseZoneInteractionView
        for child in _view.get_children():
            if child is WarehouseZoneInteractionView: zones = child
        for node in zones._zone_labels.values():
            var label := node as Label3D
            label.fixed_size = true
            label.font_size = 32
            label.pixel_size = 0.0009
            label.outline_size = 4
        await _save("labels-fixed-390.png")
    _busy()
    await _save("busy-390.png")
    _sim.set_time_scale(1.0)
    for _i in 16: _sim.step(0.05)
    _sim.set_time_scale(0.0)
    await _save("busy-progress-390.png")
    clarity.zone.open_zone("shipping")
    await _save("shipping-panel-390.png")
    clarity.zone.close()
    get_root().size = Vector2i(375, 667)
    await _save("busy-375.png")
    get_root().size = Vector2i(430, 932)
    await _save("busy-430.png")
    print("FLOTRA_POLISH_CAPTURE_OK actual-main synthetic-state no-device-pass")
    _app.queue_free()
    await process_frame
    quit(0)

func _empty() -> void:
    _sim.inbound_queue = 0
    _sim.rack_stock = 0
    _sim.packing_queue = 0
    _sim.packed_queue = 0
    _sim.open_orders = 0
    _sim._packing_jobs.clear()
    for worker in _sim.workers:
        worker["task"] = WarehouseSim.Task.IDLE
        worker["progress"] = 0.0
    _hud._toast_timer = 0
    _hud._measurement_timer = 0

func _busy() -> void:
    _sim.inbound_queue = 8
    _sim.rack_stock = 12
    _sim.packing_queue = 7
    _sim.packed_queue = 4
    _sim.open_orders = 9
    _sim._packing_jobs.assign([_sim._packing_duration() * 0.7])
    var tasks := [WarehouseSim.Task.STORE, WarehouseSim.Task.PICK, WarehouseSim.Task.SHIP]
    var sources := ["inbound", "rack", "packing"]
    var targets := ["rack", "packing", "outbound"]
    for i in mini(3, _sim.workers.size()):
        var worker: Dictionary = _sim.workers[i]
        worker["task"] = tasks[i]
        worker["source"] = sources[i]
        worker["target"] = targets[i]
        worker["progress"] = 0.6
        worker["duration"] = 3.0

func _save(filename: String) -> void:
    for _i in 12: await process_frame
    await RenderingServer.frame_post_draw
    var result := get_root().get_texture().get_image().save_png(_directory.path_join(filename))
    if result != OK:
        push_error("Capture save failed: %s" % filename)
        quit(1)
    print("CAPTURE %s size=%s" % [filename, str(get_root().size)])
