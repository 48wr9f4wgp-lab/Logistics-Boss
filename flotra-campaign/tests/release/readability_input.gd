extends "res://tests/release/readability_world.gd"
func input_at(point: Vector2, down: bool, kind: String) -> InputEvent:
    if kind == "touch":
        var event := InputEventScreenTouch.new()
        event.index = 0
        event.position = point
        event.pressed = down
        return event
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = point
    event.global_position = point
    event.pressed = down
    return event
func world_point(id: String) -> Vector2:
    var position: Vector3 = app.world._slots[id].position + Vector3(0,1,0)
    return app.viewport_container.position + app.world.camera.unproject_position(position)
func tap_world(id: String, kind: String) -> void:
    var point := world_point(id)
    var motion := InputEventMouseMotion.new()
    motion.position = point
    motion.global_position = point
    root.push_input(motion)
    root.push_input(input_at(point,true,kind))
    root.push_input(input_at(point,false,kind))
    await settle()
func guard() -> void:
    await create_timer(.25).timeout
    await physics_frame
    await settle()
func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    for size in [Vector2i(375,667),Vector2i(390,844),Vector2i(430,932)]:
        root.size = size
        app = Main.new()
        app.persistence_enabled = false
        root.add_child(app)
        app.set_process(false)
        app.hud.show_play()
        app.sim.accept_contract("first_shift")
        app.world.refresh()
        await guard()
        for kind in ["mouse","touch"]:
            for id in ["shelf","packing"]:
                var point := world_point(id)
                check(app.world._slot_at(point-app.viewport_container.position)==id,"Camera projection preserves equipment picking")
                await tap_world(id,kind)
                check(app.hud._sheet_kind=="editor","World %s opens layout editor"%kind)
                check(app.world._selected==id,"World %s selects exact equipment"%kind)
                verify_labels(1)
                app.hud._choose("annex")
                await settle()
                verify_labels(2)
                app.hud.close_sheet()
                await guard()
                verify_labels(3)
            # A press interrupted by app focus loss must not select equipment.
            var point := world_point("shelf")
            root.push_input(input_at(point,true,kind))
            root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
            root.push_input(input_at(point,false,kind))
            await settle()
            check(app.hud._sheet_kind.is_empty() and app.world._selected.is_empty(),"Interrupted world touch never opens editor")
            root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
            await guard()
        app.queue_free()
        await process_frame
    print("READABILITY_INPUT %d checks, %d failures"%[checks,failures])
    quit(0 if failures==0 else 1)
