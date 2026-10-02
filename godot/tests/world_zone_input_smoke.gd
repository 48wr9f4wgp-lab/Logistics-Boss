extends SceneTree

const ViewScript = preload("res://view/warehouse_view_mobile.gd")
const InteractionScript = preload("res://view/zone_interaction_view.gd")

var _view: MobileWarehouseView
var _interaction: WarehouseZoneInteractionView
var _position := Vector2.ZERO
var _selected: Array[String] = []
var _failures := 0
var _checks := 0


class TouchControl extends Control:
    var intercepted := 0

    func _gui_input(event: InputEvent) -> void:
        if event is InputEventScreenTouch or event is InputEventScreenDrag:
            intercepted += 1
            accept_event()


func _init() -> void:
    call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
    _checks += 1
    if not condition:
        _failures += 1
        push_error(message)


func _run() -> void:
    get_root().size = Vector2i(390, 844)
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_touch_from_mouse = false
    _view = ViewScript.new()
    get_root().add_child(_view)
    # A real camera and physical Zone targets, without loading or saving a game.
    _view._update_camera(1.0)
    _interaction = InteractionScript.new()
    _view.add_child(_interaction)
    _interaction.bind(_view)
    _interaction.zone_selected.connect(func(zone_key: String): _selected.append(zone_key))
    await process_frame
    await physics_frame
    await process_frame
    var storage := _interaction._zone_areas["storage"] as Area3D
    _position = _view._camera.unproject_position(storage.global_position)
    _expect(_interaction.pick_zone_at_screen(_position) == "storage", "World input fixture must ray-pick the real storage Zone")

    # Input.parse_input_event covers the engine's mouse-before-touch emulation.
    # Viewport.push_input and direct _unhandled_input calls bypass that stage.
    for emulate_mouse in [false, true]:
        Input.emulate_mouse_from_touch = emulate_mouse
        _verify_touch_gestures("emulation=%s" % str(emulate_mouse))
    _verify_mouse()
    _verify_focus_loss()
    await _verify_gui_contact()
    await _verify_raw_ui_contact()
    await _verify_label_targets()
    await _verify_label_bounds()
    await _verify_blank_world_pick()

    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    _view.queue_free()
    await process_frame
    print("World Zone input checks finished; checks=%d failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _verify_touch_gestures(label: String) -> void:
    var before := _selected.size()
    _touch(0, _position, true)
    _touch(0, _position, false)
    _expect(_selected.size() == before + 1, "Single world tap must select exactly once (%s)" % label)

    before = _selected.size()
    _touch(0, _position, true)
    _touch(0, _position, false, true)
    _expect(_selected.size() == before, "Canceled world touch must never select (%s)" % label)

    before = _selected.size()
    _touch(0, _position, true)
    _touch(0, _position + Vector2(40.0, 0.0), false)
    _expect(_selected.size() == before, "Large release displacement must not select even without a drag event (%s)" % label)

    before = _selected.size()
    var yaw := _view._orbit_yaw
    _touch(0, _position, true)
    _drag(0, _position + Vector2(30.0, 0.0), Vector2(30.0, 0.0))
    _drag(0, _position, Vector2(-30.0, 0.0))
    _touch(0, _position, false)
    _expect(_selected.size() == before, "Drag returning to its start must not become a tap (%s)" % label)
    _expect(not is_equal_approx(yaw, _view._orbit_yaw), "Touch drag must still orbit the camera (%s)" % label)

    # One finger stays still during a real pinch. Both release orders matter.
    for stationary_first in [true, false]:
        before = _selected.size()
        _touch(0, _position, true)
        _touch(1, _position + Vector2(50.0, 0.0), true)
        _drag(1, _position + Vector2(60.0, 0.0), Vector2(10.0, 0.0))
        var distance := _view._camera_distance
        _drag(1, _position + Vector2(100.0, 0.0), Vector2(40.0, 0.0))
        _expect(not is_equal_approx(distance, _view._camera_distance), "Pinch must still zoom the camera (%s)" % label)
        if stationary_first:
            _touch(0, _position, false)
            _touch(1, _position + Vector2(100.0, 0.0), false)
        else:
            _touch(1, _position + Vector2(100.0, 0.0), false)
            _touch(0, _position, false)
        _expect(_selected.size() == before, "Stationary pinch finger must not select in either release order (%s)" % label)

    before = _selected.size()
    _touch(0, _position, true)
    _touch(1, _position, true)
    _touch(1, _position, false, true)
    _touch(2, _position, true)
    _touch(0, _position, false)
    _touch(2, _position, false)
    _expect(_selected.size() == before, "Multitouch/cancellation must stay blocked until every overlapping finger lifts (%s)" % label)

    before = _selected.size()
    _touch(0, _position, true)
    _touch(0, _position, false)
    _expect(_selected.size() == before + 1, "Fresh single tap must work immediately after all fingers lift (%s)" % label)

    before = _selected.size()
    _touch(8, _position, false)
    _expect(_selected.size() == before, "Unmatched touch release must not select (%s)" % label)


func _verify_mouse() -> void:
    var before := _selected.size()
    _mouse(_position, true)
    _mouse(_position, false)
    _expect(_selected.size() == before + 1, "A genuine left mouse click must still select exactly once after touch input")
    before = _selected.size()
    var yaw := _view._orbit_yaw
    _mouse(_position, true)
    var motion := InputEventMouseMotion.new()
    motion.device = 0
    motion.position = _position + Vector2(30.0, 0.0)
    motion.global_position = motion.position
    motion.relative = Vector2(30.0, 0.0)
    motion.button_mask = MOUSE_BUTTON_MASK_LEFT
    _send(motion)
    _mouse(_position, false)
    _expect(_selected.size() == before, "A genuine mouse drag must not select a Zone")
    _expect(not is_equal_approx(yaw, _view._orbit_yaw), "A genuine mouse drag must still orbit the camera")


func _verify_focus_loss() -> void:
    for notification in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
        var before := _selected.size()
        _touch(0, _position, true)
        _interaction.notification(notification)
        _touch(0, _position, false)
        _expect(_selected.size() == before, "An interrupted touch must not select after focus loss or suspension")
        _touch(0, _position, true)
        _touch(0, _position, false)
        _expect(_selected.size() == before + 1, "A fresh touch must work after focus loss or suspension")
        before = _selected.size()
        _mouse(_position, true)
        _interaction.notification(notification)
        _mouse(_position, false)
        _expect(_selected.size() == before, "An interrupted mouse press must not select after focus loss or suspension")
        _mouse(_position, true)
        _mouse(_position, false)
        _expect(_selected.size() == before + 1, "A fresh mouse click must work after focus loss or suspension")


func _verify_label_targets() -> void:
    var poses := [
        Vector3(MobileWarehouseView.OVERVIEW_YAW, MobileWarehouseView.OVERVIEW_PITCH, 19.5),
        Vector3(-0.65, -0.75, 19.5),
        Vector3(-1.50, -0.85, 24.0),
        Vector3(-0.20, -0.70, 32.0),
    ]
    for size in [Vector2i(375, 812), Vector2i(390, 844), Vector2i(430, 932)]:
        get_root().size = size
        await process_frame
        for pose in poses:
            _view._orbit_yaw = pose.x
            _view._orbit_pitch = pose.y
            _view._camera_distance = pose.z
            _view._camera_pose_initialized = false
            _view._update_camera(1.0)
            for key in _interaction.zone_keys():
                var label := _interaction._zone_labels[key] as Label3D
                var point := _view._camera.unproject_position(label.global_position)
                _expect(get_root().get_visible_rect().has_point(point), "Zone label center must remain inside portrait fixture: %s, %s, %s" % [key, str(size), str(pose)])
                var before := _selected.size()
                _touch(0, point, true)
                _touch(0, point, false)
                _expect(_selected.size() == before + 1 and _selected[-1] == key, "Tapping visible %s label must select that Zone: %s, %s; point=%s direct=%s count=%d last=%s" % [key, str(size), str(pose), str(point), _interaction.pick_zone_at_screen(point), _selected.size() - before, _selected[-1] if not _selected.is_empty() else "none"])


func _verify_gui_contact() -> void:
    var blocker := TouchControl.new()
    blocker.position = Vector2(5.0, 80.0)
    blocker.size = Vector2(100.0, 100.0)
    get_root().add_child(blocker)
    await process_frame
    var ui_point := blocker.get_global_rect().get_center()
    for ui_first in [true, false]:
        var before := _selected.size()
        _touch(0, _position, true)
        _touch(1, ui_point, true)
        if ui_first:
            _touch(1, ui_point, false)
            _touch(0, _position, false)
        else:
            _touch(0, _position, false)
            _touch(1, ui_point, false)
        _expect(_selected.size() == before, "World finger must remain blocked when another finger is consumed by a GUI Control")
    _expect(blocker.intercepted > 0, "GUI multitouch fixture must actually consume touch events")
    await process_frame
    var before := _selected.size()
    _touch(0, _position, true)
    _touch(0, _position, false)
    _expect(_selected.size() == before + 1, "World taps must recover once GUI and world contacts have both lifted")
    blocker.queue_free()
    await process_frame


func _verify_label_bounds() -> void:
    var label := _interaction._zone_labels["storage"] as Label3D
    var old_fixed := label.fixed_size
    var old_pixel_size := label.pixel_size
    label.fixed_size = true
    label.pixel_size = 0.0009
    await process_frame
    var projection := _view._camera.get_camera_projection()
    var viewport_size := _view.get_viewport().get_visible_rect().size
    # Independent font metrics catch billboard get_aabb()'s conservative cube.
    var text_size := label.font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, label.font_size)
    text_size += Vector2.ONE * label.outline_size * 2.0
    var expected := Vector2(text_size.x * label.pixel_size * absf(projection.x.x) * viewport_size.x * 0.5, text_size.y * label.pixel_size * absf(projection.y.y) * viewport_size.y * 0.5)
    var near_rect := _interaction.zone_label_visual_screen_rect("storage")
    _expect(near_rect.size.distance_to(expected) < 0.1, "Fixed-size label visual bounds must match the renderer projection")
    var old_camera_transform := _view._camera.global_transform
    _view._camera.translate_object_local(Vector3(0.0, 0.0, 10.0))
    var far_rect := _interaction.zone_label_visual_screen_rect("storage")
    _expect(near_rect.size.distance_to(far_rect.size) < 0.1, "Fixed-size label visual bounds must remain stable when camera depth changes")
    var hit_rect := _interaction.zone_label_screen_rect("storage")
    _expect(hit_rect.size.x >= 44.0 and hit_rect.size.y >= 44.0 and hit_rect.encloses(far_rect), "Touch hit bounds must include the visible text and a 44px minimum")
    label.hide()
    _expect(not _interaction.zone_label_screen_rect("storage").has_area(), "Hidden labels must not create screen-space touch targets")
    label.show()
    _view._camera.global_transform = old_camera_transform
    label.fixed_size = old_fixed
    label.pixel_size = old_pixel_size
    await process_frame


func _verify_raw_ui_contact() -> void:
    var sim := preload("res://domain/flotra_v2_sim.gd").new()
    var hud := preload("res://ui/game_hud_mobile.gd").new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    var zone := preload("res://ui/warehouse_zone_panel.gd").new()
    hud.add_child(zone)
    zone.bind_sim(sim)
    var router := preload("res://ui/mobile_ui_gesture_router.gd").new()
    hud.add_child(router)
    router.bind(hud, zone)
    router.raw_touch_observed.connect(_interaction.observe_touch_input)
    await process_frame
    await process_frame
    var ui_point := hud._manage_button.get_global_rect().get_center()
    for ui_first in [true, false]:
        var before := _selected.size()
        _touch(0, _position, true)
        _touch(1, ui_point, true)
        _expect(router._pointer == 1, "Composed UI router must actually own the second contact")
        if ui_first:
            _touch(1, ui_point, false, true)
            _touch(0, _position, false)
        else:
            _touch(0, _position, false)
            _touch(1, ui_point, false, true)
        _expect(_selected.size() == before, "World finger must not select while the composed raw UI router owns another finger")
    hud.queue_free()
    await process_frame


func _verify_blank_world_pick() -> void:
    get_root().size = Vector2i(390, 844)
    _view.reset_work_overview()
    _view._camera_pose_initialized = false
    _view._update_camera(1.0)
    var sim := preload("res://domain/flotra_v2_sim.gd").new()
    sim.inbound_queue = 8
    sim.rack_stock = 12
    sim.packing_queue = 7
    sim.packed_queue = 4
    sim.open_orders = 9
    _interaction.set_sim(sim)
    await process_frame
    await physics_frame
    await process_frame
    # Independent reviewed repro: a conservative billboard AABB formerly made
    # the picking label steal blank warehouse space below its actual text.
    var point := Vector2(240.0, 480.0)
    var from := _view._camera.project_ray_origin(point)
    var to := from + _view._camera.project_ray_normal(point) * 120.0
    _expect(_interaction.pick_zone_from_ray(from, to) == "storage", "Blank warehouse repro must physically hit storage")
    _expect(not _interaction.zone_label_screen_rect("picking").has_point(point), "Picking label must not claim blank space through a billboard AABB cube")
    _expect(_interaction.pick_zone_at_screen(point) == "storage", "Blank warehouse space must preserve the underlying storage Zone")
    _interaction.set_sim(null)
    await process_frame


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


func _mouse(position: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.device = 0
    event.position = position
    event.global_position = position
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    _send(event)


func _send(event: InputEvent) -> void:
    # Engine events use window coordinates; the picker uses viewport coordinates.
    # Respect the project's portrait stretch transform at every tested size.
    Input.parse_input_event(event.xformed_by(get_root().get_screen_transform()))
    Input.flush_buffered_events()
