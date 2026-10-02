extends SceneTree

# Synthetic lifecycle dispatch at Godot's Window notification boundary, with
# actual composed main-scene input. This is not browser/iPhone delivery evidence.
# Canvas blur can send WINDOW_FOCUS_OUT independently of application focus.
const MainScene := preload("res://scenes/main.tscn")
const PORTRAITS := [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]
const LOSS_CASES := {
    "window": [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT],
    "application": [Node.NOTIFICATION_APPLICATION_FOCUS_OUT],
    "pause": [Node.NOTIFICATION_APPLICATION_PAUSED],
    "duplicate_window_application": [
        Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,
        Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
        Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT,
        Node.NOTIFICATION_APPLICATION_FOCUS_OUT,
    ],
}

var _app: Node
var _sim: FlotraV2Sim
var _hud: MobileGameHud
var _clarity: MobileInteractionClarity
var _router: MobileUiGestureRouter
var _zone: WarehouseZonePanel
var _view: MobileWarehouseView
var _world: WarehouseZoneInteractionView
var _actions := 0
var _contract_presses := 0
var _selections := 0
var _checks := 0
var _failures := 0
var _label := ""


func _init() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error("%s: %s" % [_label, message])


func _run() -> void:
    if OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("Use run_polish_checks.sh with a disposable profile")
        quit(1)
        return
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    for portrait in PORTRAITS:
        get_root().size = portrait
        await _fresh()
        for loss_case in LOSS_CASES:
            for mouse in [false, true]:
                _label = "%s %s %s" % [str(portrait), loss_case, "mouse" if mouse else "touch"]
                await _held_action(LOSS_CASES[loss_case], mouse)
                await _held_world(LOSS_CASES[loss_case], mouse)
        _label = "%s cancel/multitouch/isolation" % str(portrait)
        await _other_cancellation_paths()
        _label = "%s world drag/pinch" % str(portrait)
        await _world_gestures()
        _app.queue_free()
        await _settle()
    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    print("Window focus input checks finished; checks=%d failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _fresh() -> void:
    _app = MainScene.instantiate()
    get_root().add_child(_app)
    # Freeze authoritative progression/autosave, not input or scene composition.
    _app.set_process(false)
    _sim = _app.get("sim") as FlotraV2Sim
    _sim.set_time_scale(0.0)
    _sim.money = 100000
    _sim.active_contract.clear()
    for child in _app.get_children():
        if child is MobileGameHud:
            _hud = child
        elif child is MobileWarehouseView:
            _view = child
    _clarity = _hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    _router = _clarity.router
    _zone = _clarity.zone
    _clarity.coach._persist_completion = false
    for child in _view.get_children():
        if child is WarehouseZoneInteractionView:
            _world = child
    _router.action_activated.connect(func(_button: Button): _actions += 1)
    _hud._contract_buttons[0].pressed.connect(func(): _contract_presses += 1)
    _world.zone_selected.connect(func(_key: String): _selections += 1)
    await _settle()
    await physics_frame
    _expect(not _hud.is_processing_input() and not _zone.is_processing_input(), "Composed main must have one raw UI owner")


func _open_contracts() -> Button:
    _sim.active_contract.clear()
    if _sim.contract_offers.is_empty():
        _sim._refresh_contract_offers()
    _zone.close()
    _clarity.open_section("contracts")
    await _settle()
    var button := _hud._contract_buttons[0]
    _expect(_router.button_at(button.get_global_rect().get_center()) == button, "Contract target must be visible and hittable")
    return button


func _world_point() -> Vector2:
    _zone.close()
    _hud._sheet.hide()
    _view.reset_work_overview()
    _view._camera_pose_initialized = false
    _view._update_camera(1.0)
    await _settle()
    var point := _world.zone_label_screen_rect("storage").get_center()
    _expect(get_root().get_visible_rect().has_point(point) and _router.button_at(point) == null, "World target must be on canvas and outside UI actions")
    _expect(_world.pick_zone_at_screen(point) == "storage", "World fixture must pick the real storage label")
    return point


func _lose_focus(notifications: Array) -> void:
    # Window::_event_callback propagates these notifications to scene children.
    # Avoid direct calls to either gesture owner's cancellation implementation.
    for what in notifications:
        get_root().propagate_notification(what)
    get_root().propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
    get_root().propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    get_root().propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)


func _held_action(notifications: Array, mouse: bool) -> void:
    var button: Button = await _open_contracts()
    var point := button.get_global_rect().get_center()
    if mouse:
        await _mouse_ready()
    var actions := _actions
    var presses := _contract_presses
    var selections := _selections
    var money := _sim.money
    var camera := _camera_state()
    var normal := button.get_theme_stylebox("normal")
    _pointer(point, true, mouse)
    _expect(_router.is_pressing(button) and _router._pointer == (-2 if mouse else 0), "Held action must be owned by its genuine pointer")
    _expect(button.get_theme_stylebox("normal") == button.get_theme_stylebox("pressed"), "Held action must show pressed feedback")
    _lose_focus(notifications)
    _expect(_router._pointer == -1 and _router._button == null and _router._blocked_touches.is_empty(), "Focus loss must retire the action pointer")
    _expect(button.get_theme_stylebox("normal") == normal, "Focus loss must restore the prior button styling")
    _pointer(point, false, mouse)
    await _settle()
    _expect(_actions == actions and _contract_presses == presses and _sim.active_contract.is_empty() and _sim.money == money, "Interrupted release must not accept a contract or spend")
    # A delayed duplicate release cannot revive the old action after the mouse
    # suppression interval. Genuine mouse needs that interval before a fresh down.
    await _mouse_ready()
    _pointer(point, false, mouse)
    _expect(_actions == actions and _sim.active_contract.is_empty(), "Late unmatched release must remain inert")
    _expect(_selections == selections and not _zone.is_open(), "Canceled UI input must not leak into world selection")
    _expect(_camera_state().is_equal_approx(camera) and _view._touches.is_empty(), "UI focus/release must not orbit, zoom or leave camera touches")
    # Start afresh through the same engine path. A baseline failure may already
    # have accepted a contract, so reset only the domain fixture before recovery.
    button = await _open_contracts()
    point = button.get_global_rect().get_center()
    actions = _actions
    presses = _contract_presses
    _pointer(point, true, mouse)
    _pointer(point, false, mouse)
    await _settle()
    _expect(_actions == actions + 1 and _contract_presses == presses + 1 and not _sim.active_contract.is_empty() and not _hud._sheet.visible, "Fresh press must accept exactly once and return to the warehouse")
    _expect(_selections == selections, "Fresh UI action must stay isolated from world selection")
    _sim.active_contract.clear()


func _held_world(notifications: Array, mouse: bool) -> void:
    var point: Vector2 = await _world_point()
    if mouse:
        await _mouse_ready()
    var selections := _selections
    var actions := _actions
    var money := _sim.money
    _pointer(point, true, mouse)
    _expect(_world._mouse_pressed if mouse else _world._touch_start.has(0), "World gesture must own a real press before focus loss")
    _lose_focus(notifications)
    _expect(_world._touch_start.is_empty() and _world._touch_contacts.is_empty() and not _world._mouse_pressed, "Focus loss must retire world selection eligibility")
    _pointer(point, false, mouse)
    await _settle()
    _expect(_selections == selections and not _zone.is_open(), "Interrupted world release must not select a Zone")
    _expect(_actions == actions and _sim.money == money and _sim.active_contract.is_empty(), "World focus/release must not trigger HUD or domain actions")
    _expect(_view._touches.is_empty(), "Delivered world release must retire camera contact too")
    # Clear a panel opened by the unchanged baseline before checking reentry.
    _zone.close()
    selections = _selections
    await _mouse_ready()
    _pointer(point, false, mouse)
    _expect(_selections == selections, "Late unmatched world release must not select")
    _pointer(point, true, mouse)
    _pointer(point, false, mouse)
    await _settle()
    _expect(_selections == selections + 1 and _zone.is_open() and _zone.selected_zone() == "storage", "Fresh world press must select exactly one real Zone")
    _expect(_actions == actions, "World reentry must not activate a HUD button")
    _zone.close()


func _other_cancellation_paths() -> void:
    for emulate_mouse in [false, true]:
        Input.emulate_mouse_from_touch = emulate_mouse
        var button: Button = await _open_contracts()
        var point := button.get_global_rect().get_center()
        var actions := _actions
        var selections := _selections
        _touch(0, point, true)
        _touch(0, point, false, true)
        _expect(_actions == actions and _sim.active_contract.is_empty(), "Canceled UI touch must remain inert with either emulation setting")
        _touch(0, point, true)
        _drag(0, point + Vector2(0, -24), Vector2(0, -24))
        _drag(0, point, Vector2(0, 24))
        _touch(0, point, false)
        _expect(_actions == actions, "UI drag returning to its start must never become an action")
        for release_first in [0, 1]:
            _touch(0, point, true)
            _touch(1, point, true)
            _expect(_router._blocked_touches.has(1), "Second UI finger must be tracked as blocked")
            _lose_focus(LOSS_CASES["duplicate_window_application"])
            _touch(release_first, point, false)
            _touch(1 - release_first, point, false, true)
            _expect(_actions == actions and _router._pointer == -1 and _router._blocked_touches.is_empty(), "Duplicate focus loss and either release order must cancel all UI fingers")
        _expect(_selections == selections and _view._touches.is_empty(), "UI cancellation and multitouch must remain isolated from world/camera")
        point = await _world_point()
        _touch(0, point, true)
        _touch(0, point, false, true)
        _expect(_selections == selections and not _zone.is_open(), "Canceled world touch must remain inert with either emulation setting")
        # One world contact plus a raw-UI-owned contact must stay blocked even
        # when one release is consumed. Neither order may become a world tap.
        var ui_point := _hud._manage_button.get_global_rect().get_center()
        for ui_first in [false, true]:
            _touch(0, point, true)
            _touch(1, ui_point, true)
            _expect(_router._pointer == 1 and _world._touch_contacts.size() == 2, "Composed router must forward its contact to the world observer")
            _lose_focus(LOSS_CASES["window"])
            if ui_first:
                _touch(1, ui_point, false, true)
                _touch(0, point, false)
            else:
                _touch(0, point, false)
                _touch(1, ui_point, false, true)
            _expect(_actions == actions and _selections == selections, "Focus loss must cancel mixed UI/world contacts in both release orders")
        await _settle()
        _touch(0, point, true)
        _touch(0, point, false)
        _expect(_selections == selections + 1 and _zone.is_open(), "Fresh single world tap must recover after mixed contacts")
        _zone.close()
    Input.emulate_mouse_from_touch = true


func _world_gestures() -> void:
    var point: Vector2 = await _world_point()
    var selections := _selections
    var actions := _actions
    var yaw := _view._orbit_yaw
    _touch(0, point, true)
    _drag(0, point + Vector2(30, 0), Vector2(30, 0))
    _expect(not is_equal_approx(yaw, _view._orbit_yaw), "Ordinary world drag must still orbit")
    _lose_focus(LOSS_CASES["window"])
    _touch(0, point, false)
    _expect(_selections == selections and _view._touches.is_empty(), "Interrupted drag release must not become a tap or retain a camera contact")
    for first in [0, 1]:
        point = await _world_point()
        _touch(0, point, true)
        _touch(1, point + Vector2(50, 0), true)
        _drag(1, point + Vector2(60, 0), Vector2(10, 0))
        var distance := _view._camera_distance
        _drag(1, point + Vector2(90, 0), Vector2(30, 0))
        _expect(not is_equal_approx(distance, _view._camera_distance), "Ordinary world pinch must still zoom")
        _lose_focus(LOSS_CASES["window"])
        _touch(first, point if first == 0 else point + Vector2(90, 0), false)
        _touch(1 - first, point if first == 1 else point + Vector2(90, 0), false)
        _expect(_selections == selections and _actions == actions, "Interrupted pinch must not activate either surface in either release order")
        _expect(_view._touches.is_empty() and is_zero_approx(_view._last_pinch_distance), "Delivered pinch releases must clear camera gesture state")
    point = await _world_point()
    yaw = _view._orbit_yaw
    _touch(0, point, true)
    _drag(0, point + Vector2(24, 0), Vector2(24, 0))
    _touch(0, point + Vector2(24, 0), false)
    _expect(not is_equal_approx(yaw, _view._orbit_yaw) and _selections == selections, "A fresh drag must remain usable after focus reentry")


func _camera_state() -> Vector3:
    return Vector3(_view._orbit_yaw, _view._orbit_pitch, _view._camera_distance)


func _mouse_ready() -> void:
    # The router uses wall-clock ticks; a SceneTreeTimer can count time spent
    # earlier in a long frame and wake before that real deadline.
    while Time.get_ticks_msec() <= _router._suppress_until:
        await process_frame


func _pointer(position: Vector2, pressed: bool, mouse: bool) -> void:
    if mouse:
        var event := InputEventMouseButton.new()
        event.device = 0
        event.position = position
        event.global_position = position
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        _send(event)
    else:
        _touch(0, position, pressed)


func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    event.canceled = canceled
    _send(event)


func _drag(index: int, position: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = position
    event.relative = relative
    _send(event)


func _send(event: InputEvent) -> void:
    # Respect real engine emulation and the portrait window/stretch transform.
    Input.parse_input_event(event.xformed_by(get_root().get_screen_transform()))
    Input.flush_buffered_events()


func _settle() -> void:
    for _frame in 3:
        await process_frame
