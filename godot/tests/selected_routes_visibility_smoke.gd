extends SceneTree

var _failures := 0
func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Use tools/run_polish_checks.sh for an isolated save profile")
        quit(1)
        return
    var main := load("res://scenes/main.tscn").instantiate() as Node
    get_root().add_child(main)
    main.set_process(false)
    var sim: WarehouseSim = main.get("sim")
    sim.set_time_scale(0)
    var view: WarehouseView
    var hud: MobileGameHud
    for node in main.get_children():
        if node is WarehouseView: view = node
        if node is MobileGameHud: hud = node
    var routes := view.get_node("SelectedWorkRoutes") as SelectedWorkRoutes
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    var zone := clarity.zone
    for worker in sim.workers: worker["task"] = WarehouseSim.Task.IDLE
    zone.open_zone("packing")
    zone.close()
    routes._process(0)
    _expect(not routes.toggle.visible, "Machine-owned packing does not offer an empty hide action")
    zone.open_zone("picking")
    zone.close()
    routes._process(0)
    _expect(not routes.toggle.visible, "Idle crew does not offer an empty hide action")
    sim.workers[0]["task"] = WarehouseSim.Task.PICK
    sim.workers[0]["source"] = "rack"
    sim.workers[0]["target"] = "packing"
    routes._process(0)
    _expect(routes.toggle.visible, "An actual selected worker route can be hidden")
    _expect(routes.lines[0].visible, "A visible hide action corresponds to actual route geometry")
    routes.toggle.emit_signal("pressed")
    routes._process(0)
    _expect(not routes.toggle.visible and not routes.lines[0].visible, "Hide clears both geometry and its control")
    zone.open_zone("picking")
    routes._process(0)
    _expect(not routes.toggle.visible, "Open panel owns its interaction surface")
    zone.close()
    hud._sheet.visible = true
    routes._process(0)
    _expect(not routes.toggle.visible and routes.selected.is_empty(), "Management removes selected route state")
    main.queue_free()
    await process_frame
    print("Selected route visibility checks complete; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)
