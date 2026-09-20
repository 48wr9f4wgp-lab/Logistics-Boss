extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
var _directory := ""


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _directory = OS.get_environment("FLOTRA_CLARITY_CAPTURE_DIR")
    if _directory.is_empty():
        push_error("FLOTRA_CLARITY_CAPTURE_DIR is required")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(_directory)
    get_root().size = Vector2i(390, 844)
    var app := MainScene.instantiate()
    get_root().add_child(app)
    var sim: WarehouseSim = app.get("sim")
    var hud: MobileGameHud
    for child in app.get_children():
        if child is MobileGameHud:
            hud = child as MobileGameHud
    if hud == null:
        push_error("Actual main scene did not create MobileGameHud")
        quit(1)
        return
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    sim.set_time_scale(0.0)
    await _save("clarity_fresh.png")

    # Deterministic diagnostic fixture only. This is not progression/fun proof.
    sim.money = 100000
    for kind in [&"rack_wing", &"second_packing_bench", &"worker_hire", &"forklift_project"]:
        var result: Dictionary = sim.call("purchase_rank1_project", kind)
        if not bool(result.get("ok", false)):
            push_error("Capture fixture purchase failed: %s" % String(kind))
            quit(1)
            return
    sim.logistics_rating = 0
    sim.active_contract.clear()
    clarity.coach.visible = false
    hud._measurement_timer = 0.0
    hud._measurement_panel.visible = false
    hud._toast_timer = 0.0
    hud._toast_panel.visible = false
    if clarity.resume_brief != null:
        clarity.resume_brief.call("bind", sim, true)
    clarity.refresh()
    await _save("clarity_completed_equipment.png")
    if clarity.resume_brief != null:
        clarity.resume_brief.visible = false
    clarity.open_section("contracts")
    await _save("clarity_contracts.png")
    clarity.open_section("field")
    await _save("clarity_field.png")
    hud._sheet.visible = false
    clarity.zone.open_zone("storage")
    await _save("clarity_installed_storage.png")
    print("Actual-main mobile clarity captures complete")
    quit(0)


func _save(filename: String) -> void:
    for _index in 12:
        await process_frame
    await RenderingServer.frame_post_draw
    var image := get_root().get_texture().get_image()
    var result := image.save_png(_directory.path_join(filename))
    if result != OK:
        push_error("Failed to write capture %s: %s" % [filename, str(result)])
        quit(1)
