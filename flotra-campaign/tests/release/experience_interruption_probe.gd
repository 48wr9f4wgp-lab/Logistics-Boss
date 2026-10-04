extends SceneTree
## Independent regressions for interruptions during a real GUI press.
const Main = preload("res://prototype/growth_main.gd")
var app
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
    for frame in 4: await process_frame
func check(value: bool, label: String) -> void:
    if not value:
        failures.append(label)
        push_error(label)
func touch(point: Vector2, down: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = down
    Input.parse_input_event(event)
func run() -> void:
    root.size = Vector2i(390,844)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    app._accept_contract("growth_1")
    app.hud.show_controls()
    await settle()
    var button: Button = app.hud._speed_buttons[4]
    var point := button.get_global_rect().get_center()
    touch(point,true)
    await settle()
    root.size = Vector2i(390,567)
    await settle()
    touch(point,false)
    await settle()
    check(app.speed == 2, "Viewport resize cancels an in-flight settings press")
    app._set_speed(2)
    point = button.get_global_rect().get_center()
    touch(point,true)
    await settle()
    root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    touch(point,false)
    await settle()
    check(app.speed == 2, "Application focus loss rejects old button release")
    check(not app.running, "Application focus loss pauses the actual simulation")
    root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    touch(button.get_global_rect().get_center(),true)
    await settle()
    touch(button.get_global_rect().get_center(),false)
    await settle()
    check(app.speed == 4, "Fresh press after interruptions remains usable")
    app.queue_free()
    await settle()
    print(JSON.stringify({"suite":"experience_interruption_probe","failures":failures}))
    quit(0 if failures.is_empty() else 1)
