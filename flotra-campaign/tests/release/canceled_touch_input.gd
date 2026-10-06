extends SceneTree
## Cancellation must be distinct from release through the actual engine parser.
const Main = preload("res://prototype/growth_main.gd")
var app
var checks := 0
var failures: Array[String] = []
var activations := 0

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func settle() -> void:
    if is_instance_valid(app): app._update_world_visibility()
    for frame in 4: await process_frame

func touch(point: Vector2, down: bool, canceled: bool = false, index: int = 0) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = point
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)

func mouse(point: Vector2, down: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
    event.position = point
    event.global_position = point
    event.pressed = down
    Input.parse_input_event(event)

func cancel_at(point: Vector2, web: bool, index: int = 0) -> void:
    if web:
        # This is the Web loader's real ordering: DOM capture callback first,
        # then an ordinary release because that loader discards cancellation.
        app._cancel_web_touch()
    touch(point, false, not web, index)

func guard() -> void:
    while app.hud._background_input_blocked(): await process_frame
    await settle()

func run() -> void:
    root.size = Vector2i(390, 844)
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    app.hud.show_controls()
    await settle()
    app.hud.speed_requested.connect(func(_speed: float): activations += 1)
    # Exercise both native cancellation and the browser's lost-cancel stream.
    # Both OS emulation directions remain enabled/disabled independently; the
    # repair must not globally disable mouse or touch compatibility.
    for emulate_mouse in [false, true]:
        for emulate_touch in [false, true]:
            Input.emulate_mouse_from_touch = emulate_mouse
            Input.emulate_touch_from_mouse = emulate_touch
            for web in [false, true]:
                var label := "web=%s mouse=%s touch=%s" % [web, emulate_mouse, emulate_touch]
                var button: Button = app.hud._speed_buttons[4]
                var point := button.get_global_rect().get_center()
                app._set_speed(2)
                activations = 0
                touch(point, true)
                await settle()
                cancel_at(point, web)
                await settle()
                check(app.speed == 2 and activations == 0, "Held canceled HUD touch never activates: " + label)
                for pair in 3:
                    touch(point, true)
                    cancel_at(point, web)
                await settle()
                check(app.speed == 2 and activations == 0, "Three pre-frame canceled touch pairs never activate: " + label)
                touch(point, true)
                await settle()
                touch(point, false)
                await settle()
                check(app.speed == 4 and activations == 1, "Fresh touch after cancellations activates once: " + label)
                app._set_speed(2)
                activations = 0
                touch(point, true)
                cancel_at(point, web)
                # Recovery must not depend on a timeout or rendered frame.
                touch(point, true)
                touch(point, false)
                await settle()
                check(app.speed == 4 and activations == 1, "Same-frame fresh touch recovers exactly once: " + label)
                app._set_speed(2)
                activations = 0
                mouse(point, true)
                await settle()
                mouse(point, false)
                await settle()
                check(app.speed == 4 and activations == 1, "Genuine mouse remains usable exactly once: " + label)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app.hud.close_sheet()
    await guard()
    # This legacy cancellation case deliberately starts from whole view.
    app.world.camera_action("reset")
    var camera: Button = app.hud._root.find_child("CameraIn", true, false)
    var camera_point := camera.get_global_rect().get_center()
    for pair in 3:
        touch(camera_point, true)
        cancel_at(camera_point, true)
    await settle()
    check(app.world._camera_zoom == 1, "Canceled camera buttons preserve the PR150 overview")
    touch(camera_point, true)
    touch(camera_point, false)
    await settle()
    check(app.world._camera_zoom == 1.25, "Fresh camera touch recovers after canceled buttons")
    app.world.camera_action("reset")
    var point: Vector2 = app.viewport_container.position + app.world.camera.unproject_position(app.world._slots["shelf"].position + Vector3(0, 1, 0))
    for pair in 3:
        touch(point, true)
        cancel_at(point, true)
    await settle()
    check(app.hud._sheet_kind.is_empty() and app.world._camera_touches.is_empty(), "Canceled world taps never select equipment or retain camera ownership")
    touch(point, true)
    touch(point, false)
    await settle()
    check(app.hud._sheet_kind == "editor" and app.world._selected == "shelf", "Fresh equipment tap opens layout after cancellation")
    app.hud._choose("annex")
    await settle()
    check(not app.hud._apply.disabled and app.hud._apply.is_visible_in_tree(), "Cancellation fixture targets an enabled, visible placement confirmation")
    var before_layout: Dictionary = app.sim.export_release_state()
    point = app.hud._apply.get_global_rect().get_center()
    touch(point, true)
    await settle()
    cancel_at(point, true)
    await settle()
    check(app.sim.export_release_state() == before_layout, "Canceled layout confirmation cannot commit a placement")
    touch(point, true)
    touch(point, false)
    await settle()
    check(app.sim.export_release_state() != before_layout, "Fresh placement confirmation remains usable after cancellation")
    app.hud.close_sheet()
    await guard()
    app.hud.show_controls()
    await settle()
    point = app.hud._speed_buttons[4].get_global_rect().get_center()
    app._set_speed(2)
    touch(point, true)
    app._cancel_web_touch()
    app.hud.close_sheet()
    touch(point, false)
    await settle()
    check(app.speed == 2 and app.hud._sheet_kind.is_empty(), "Canceled release after dismissal cannot reach background UI")
    app.free()
    print(JSON.stringify({"suite":"canceled_touch_input", "checks":checks, "failures":failures}))
    quit(0 if failures.is_empty() else 1)
