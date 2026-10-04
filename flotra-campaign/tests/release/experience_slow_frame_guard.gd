extends SceneTree
## Deterministic equivalent of queued rapid taps on a CPU-stalled acceptance
## frame. Wall-clock delay intentionally does NOT yield a process frame.
const ReleaseHUD = preload("res://prototype/release_hud.gd")
const GrowthHUD = preload("res://prototype/growth_hud.gd")
const ReleaseSim = preload("res://prototype/release_sim.gd")
const GrowthSim = preload("res://prototype/growth_sim.gd")
const ReleaseMain = preload("res://prototype/release_main.gd")
const GrowthMain = preload("res://prototype/growth_main.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
func settle() -> void:
    for frame in 4: await process_frame
func mouse(point: Vector2, pressed: bool) -> void:
    var motion := InputEventMouseMotion.new()
    motion.position = point
    motion.global_position = point
    root.push_input(motion)
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    root.push_input(event)
func click(point: Vector2) -> void:
    mouse(point, true)
    mouse(point, false)
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(375,667)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    for definition in [[ReleaseHUD,ReleaseSim,"release"],[GrowthHUD,GrowthSim,"growth"]]:
        var hud = definition[0].new()
        var sim = definition[1].new()
        sim.accept_contract("growth_1" if definition[2] == "growth" else "first_shift")
        hud.bind_sim(sim)
        root.add_child(hud)
        hud.show_play()
        hud.set_trial_running(true)
        hud.show_conditions()
        await settle()
        hud.close_sheet()
        var dismissal_frame := Engine.get_process_frames()
        OS.delay_msec(230)
        check(Engine.get_process_frames() == dismissal_frame, str(definition[2]) + " fixture has one slow frame")
        for index in 5: click(hud._primary.get_global_rect().get_center())
        check(hud._sheet_kind.is_empty(), str(definition[2]) + " slow-frame queued taps never open underlying editor")
        await process_frame
        if not hud._sheet_kind.is_empty():
            hud.close_sheet()
            await create_timer(.25).timeout
            await settle()
        click(hud._primary.get_global_rect().get_center())
        await settle()
        check(hud._sheet_kind == "editor", str(definition[2]) + " fresh later-frame action remains usable")
        hud.close_sheet()
        OS.delay_msec(230)
        var point: Vector2 = hud._primary.get_global_rect().get_center()
        mouse(point,true)
        await process_frame
        mouse(point,false)
        await settle()
        check(hud._sheet_kind.is_empty(), str(definition[2]) + " blocked same-frame press cannot activate when released in a later frame")
        click(point)
        await settle()
        check(hud._sheet_kind == "editor", str(definition[2]) + " fresh press clears rejection of the earlier held gesture")
        hud.free()
        await settle()
    for definition in [[ReleaseMain,"first_shift","release"],[GrowthMain,"growth_1","growth"]]:
        var app = definition[0].new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        app.hud.show_play()
        app._accept_contract(definition[1])
        if app.has_method("_update_world_visibility"): app._update_world_visibility()
        app.world.refresh()
        await settle()
        await physics_frame
        app.hud.show_conditions()
        await settle()
        app.hud.close_sheet()
        if app.has_method("_update_world_visibility"): app._update_world_visibility()
        app._resize_world()
        var position: Vector3 = app.world._slots.shelf.position + Vector3(0,1,0)
        var point: Vector2 = app.viewport_container.position + app.world.camera.unproject_position(position)
        OS.delay_msec(230)
        for index in 5: click(point)
        check(app.hud._sheet_kind.is_empty() and app.world._selected.is_empty(), str(definition[2]) + " slow-frame dismissal cannot select a world slot")
        await process_frame
        if not app.hud._sheet_kind.is_empty():
            app.hud.close_sheet()
            if app.has_method("_update_world_visibility"): app._update_world_visibility()
            await create_timer(.25).timeout
            await settle()
        position = app.world._slots.shelf.position + Vector3(0,1,0)
        point = app.viewport_container.position + app.world.camera.unproject_position(position)
        click(point)
        await settle()
        check(app.hud._sheet_kind == "editor" and app.world._selected == "shelf", str(definition[2]) + " deliberate later-frame world tap remains usable")
        app.queue_free()
        await settle()
    print(JSON.stringify({"suite":"experience_slow_frame_guard","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
