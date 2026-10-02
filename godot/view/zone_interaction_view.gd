extends Node3D
class_name WarehouseZoneInteractionView

signal zone_selected(zone_key: String)

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const ZONE_COLLISION_LAYER := 1 << 19
const TAP_MAX_MOVEMENT := 18.0
const RAY_LENGTH := 120.0
# Godot sends this synthetic mouse event before its originating ScreenTouch.
const EMULATED_MOUSE_DEVICE := -1
const LABEL_TAP_MIN_SIZE := Vector2(44.0, 44.0)

const ZONE_DEFINITIONS := {
    "inbound": {
        "label": "入荷",
        "position": Vector3(-5.25, 1.05, 0.15),
        "size": Vector3(2.55, 2.1, 7.2),
    },
    "storage": {
        "label": "保管",
        "position": Vector3(-2.20, 1.05, 0.15),
        "size": Vector3(2.70, 2.1, 7.2),
    },
    "picking": {
        "label": "ピッキング",
        "position": Vector3(0.25, 1.05, 0.15),
        "size": Vector3(1.70, 2.1, 7.2),
    },
    "packing": {
        "label": "梱包",
        "position": Vector3(2.65, 1.05, 0.15),
        "size": Vector3(2.60, 2.1, 7.2),
    },
    "shipping": {
        "label": "出荷",
        "position": Vector3(5.30, 1.05, 0.15),
        "size": Vector3(2.45, 2.1, 7.2),
    },
}

var _view: WarehouseView
var _camera: Camera3D
var _sim: WarehouseSim
var _guidance_zone := ""
var _label_refresh_elapsed := 0.0
var _zone_areas: Dictionary = {}
var _zone_labels: Dictionary = {}
var _touch_start: Dictionary = {}
var _touch_movement: Dictionary = {}
var _touch_contacts: Dictionary = {}
var _touch_gesture_blocked := false
var _last_observed_touch_event: InputEvent
var _mouse_pressed := false
var _mouse_start := Vector2.ZERO
var _mouse_movement := 0.0


func bind(view: WarehouseView, next_sim: WarehouseSim = null) -> void:
    _view = view
    _camera = view._camera if view != null else null
    _sim = next_sim
    if _zone_areas.is_empty():
        _build_zone_targets()
    _refresh_zone_labels()


func set_sim(next_sim: WarehouseSim) -> void:
    _sim = next_sim
    _refresh_zone_labels()


func set_guidance_zone(zone_key: String) -> void:
    _guidance_zone = zone_key if ZONE_DEFINITIONS.has(zone_key) else ""
    _refresh_zone_labels()


func clear_guidance_zone() -> void:
    if _guidance_zone.is_empty():
        return
    _guidance_zone = ""
    _refresh_zone_labels()


func guidance_zone() -> String:
    return _guidance_zone


func _process(delta: float) -> void:
    _label_refresh_elapsed += maxf(0.0, delta)
    if _label_refresh_elapsed < 0.20:
        return
    _label_refresh_elapsed = 0.0
    _refresh_zone_labels()


func _build_zone_targets() -> void:
    for zone_key in ZONE_DEFINITIONS:
        var definition: Dictionary = ZONE_DEFINITIONS[zone_key]

        var area := Area3D.new()
        area.name = "ZoneTarget_%s" % String(zone_key)
        area.position = definition["position"]
        area.collision_layer = ZONE_COLLISION_LAYER
        area.collision_mask = 0
        area.input_ray_pickable = true
        area.set_meta("zone_key", String(zone_key))
        add_child(area)

        var collision := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = definition["size"]
        collision.shape = box
        area.add_child(collision)
        _zone_areas[String(zone_key)] = area

        var label := Label3D.new()
        label.name = "ZoneLabel_%s" % String(zone_key)
        label.text = String(definition["label"])
        # Keep captions at their own equipment edge instead of stacking all
        # five along one foreground diagonal in the portrait overview.
        var anchors := {
            "inbound": Vector3(-5.65, 0.40, 3.78),
            "storage": Vector3(-3.65, 1.40, -0.30),
            "picking": Vector3(0.25, 0.34, 2.75),
            "packing": Vector3(2.65, 2.75, -1.20),
            "shipping": Vector3(5.65, 0.42, 2.70),
        }
        label.position = anchors[String(zone_key)]
        label.font = JAPANESE_UI_FONT
        label.font_size = 32
        label.outline_size = 4
        label.modulate = Color(0.76, 0.94, 1.0, 0.96)
        label.outline_modulate = Color(0.0, 0.04, 0.06, 0.96)
        label.no_depth_test = true
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.double_sided = true
        # Keep operational labels legible at overview and far zoom. The font
        # is rendered at high source resolution, with a stable ~14px screen size.
        label.fixed_size = true
        label.pixel_size = 0.0009
        add_child(label)
        _zone_labels[String(zone_key)] = label

    _refresh_zone_labels()


func _refresh_zone_labels() -> void:
    for zone_key in _zone_labels:
        var label := _zone_labels[zone_key] as Label3D
        if label == null:
            continue
        var key := String(zone_key)
        var base := String((ZONE_DEFINITIONS[key] as Dictionary).get("label", key.to_upper()))
        var state := _zone_state(key)

        if key == _guidance_zone:
            label.text = "%s\nここをタップ" % base
            label.modulate = Color(1.0, 0.72, 0.24, 1.0)
            label.outline_modulate = Color(0.08, 0.03, 0.0, 1.0)
        elif state == 2:
            label.text = "%s ›\n混雑" % base
            label.modulate = Color(1.0, 0.43, 0.30, 1.0)
            label.outline_modulate = Color(0.09, 0.01, 0.0, 1.0)
        elif state == 1:
            label.text = "%s ›\n高負荷" % base
            label.modulate = Color(1.0, 0.76, 0.30, 0.98)
            label.outline_modulate = Color(0.07, 0.03, 0.0, 0.98)
        else:
            label.text = base + " ›"
            label.modulate = Color(0.76, 0.94, 1.0, 0.96)
            label.outline_modulate = Color(0.0, 0.04, 0.06, 0.96)


func _zone_state(zone_key: String) -> int:
    if _sim == null:
        return 0
    match zone_key:
        "inbound":
            return 2 if _sim.inbound_queue >= 8 else (1 if _sim.inbound_queue >= 4 else 0)
        "storage":
            var fill := float(_sim.rack_stock) / float(maxi(1, _sim.rack_capacity))
            return 2 if fill >= 0.95 else (1 if fill >= 0.70 else 0)
        "picking":
            return 2 if _sim.open_orders >= 10 else (1 if _sim.open_orders >= 6 else 0)
        "packing":
            return 2 if _sim.packing_queue >= 8 else (1 if _sim.packing_queue >= 3 else 0)
        "shipping":
            return 2 if _sim.packed_queue >= 8 else (1 if _sim.packed_queue >= 4 else 0)
    return 0


func _input(event: InputEvent) -> void:
    observe_touch_input(event)


func observe_touch_input(event: InputEvent) -> void:
    if _camera == null:
        return
    if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
        return
    # The composed raw UI router forwards before consuming. Unhandled events
    # also reach _input; count each shared InputEvent only once.
    if event == _last_observed_touch_event:
        return
    _last_observed_touch_event = event
    # Observe without consuming: GUI Controls may own one finger of a gesture,
    # but its remaining world finger must not become a new single-finger tap.
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        _mouse_pressed = false
        if touch.pressed and not touch.canceled:
            if _touch_contacts.is_empty():
                _touch_gesture_blocked = false
                _touch_start.clear()
                _touch_movement.clear()
            _touch_contacts[touch.index] = true
            if _touch_contacts.size() > 1:
                _touch_gesture_blocked = true
        else:
            if touch.canceled:
                _touch_gesture_blocked = true
            _touch_contacts.erase(touch.index)
            # Keep release eligibility until _unhandled_input has run. Deferred
            # cleanup also retires contacts whose release is consumed by GUI.
            _retire_touch.call_deferred(touch.index)
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _touch_movement.has(drag.index):
            _touch_movement[drag.index] = float(_touch_movement[drag.index]) + drag.relative.length()


func _retire_touch(index: int) -> void:
    if _touch_contacts.has(index):
        return
    _touch_start.erase(index)
    _touch_movement.erase(index)
    if _touch_contacts.is_empty():
        _touch_gesture_blocked = false


func _unhandled_input(event: InputEvent) -> void:
    if _camera == null:
        return
    # ScreenTouch owns world selection. Its emulated mouse must not bypass
    # cancellation/multitouch protection or select the same Zone twice.
    if event is InputEventMouse and event.device == EMULATED_MOUSE_DEVICE:
        return

    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and not touch.canceled:
            _touch_start[touch.index] = touch.position
            _touch_movement[touch.index] = 0.0
        else:
            if touch.canceled:
                _touch_gesture_blocked = true
            var movement := float(_touch_movement.get(touch.index, 9999.0))
            if _touch_start.has(touch.index):
                movement = maxf(movement, (touch.position - (_touch_start[touch.index] as Vector2)).length())
            var should_select := not _touch_gesture_blocked and movement <= TAP_MAX_MOVEMENT
            _touch_start.erase(touch.index)
            _touch_movement.erase(touch.index)
            # A surviving stationary pinch finger is still part of the same
            # blocked gesture, including any new fingers joining before it lifts.
            if should_select:
                _select_at_screen(touch.position)
        return

    if event is InputEventScreenDrag:
        return

    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index != MOUSE_BUTTON_LEFT:
            return
        if not _touch_contacts.is_empty():
            _mouse_pressed = false
            return
        if mouse_button.pressed:
            _mouse_pressed = true
            _mouse_start = mouse_button.position
            _mouse_movement = 0.0
        else:
            var movement := maxf(_mouse_movement, mouse_button.position.distance_to(_mouse_start))
            var should_select := _mouse_pressed and movement <= TAP_MAX_MOVEMENT
            _mouse_pressed = false
            if should_select:
                _select_at_screen(mouse_button.position)
        return

    if event is InputEventMouseMotion and _mouse_pressed:
        _mouse_movement += (event as InputEventMouseMotion).relative.length()


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        _touch_start.clear()
        _touch_movement.clear()
        _touch_contacts.clear()
        _last_observed_touch_event = null
        _touch_gesture_blocked = false
        _mouse_pressed = false
        _mouse_movement = 0.0


func _select_at_screen(screen_position: Vector2) -> String:
    var zone_key := pick_zone_at_screen(screen_position)
    if not zone_key.is_empty():
        zone_selected.emit(zone_key)
    return zone_key


func pick_zone_at_screen(screen_position: Vector2) -> String:
    if _camera == null:
        return ""
    # Labels are billboards and may sit in front of a neighboring 3D target.
    # Honor the visible label first; nearest center resolves overlapping hit
    # padding consistently instead of depending on dictionary iteration order.
    var label_key := ""
    var nearest_distance := INF
    for zone_key in _zone_labels:
        var rect := zone_label_screen_rect(String(zone_key))
        if not rect.has_area() or not rect.has_point(screen_position):
            continue
        var distance := screen_position.distance_squared_to(rect.get_center())
        if distance < nearest_distance:
            nearest_distance = distance
            label_key = String(zone_key)
    if not label_key.is_empty():
        return label_key
    var from := _camera.project_ray_origin(screen_position)
    var direction := _camera.project_ray_normal(screen_position)
    return pick_zone_from_ray(from, from + direction * RAY_LENGTH)


func zone_label_screen_rect(zone_key: String) -> Rect2:
    var visual_rect := zone_label_visual_screen_rect(zone_key)
    if not visual_rect.has_area():
        return Rect2()
    var size := Vector2(maxf(LABEL_TAP_MIN_SIZE.x, visual_rect.size.x + 8.0), maxf(LABEL_TAP_MIN_SIZE.y, visual_rect.size.y + 8.0))
    return Rect2(visual_rect.get_center() - size * 0.5, size)


func zone_label_visual_screen_rect(zone_key: String) -> Rect2:
    var label := _zone_labels.get(zone_key) as Label3D
    if _camera == null or label == null or not label.is_visible_in_tree():
        return Rect2()
    if _camera.is_position_behind(label.global_position):
        return Rect2()
    # Match Godot's billboard shader, including fixed_size's camera-depth scale.
    # Projection then accounts for FOV, portrait aspect, and orthographic cameras.
    # get_aabb() is a rotation-safe cube for billboards, not their text rectangle.
    # Label3D's cached triangle mesh follows its actual multiline text layout.
    var mesh := label.generate_triangle_mesh()
    if mesh == null:
        return Rect2()
    var faces := mesh.get_faces()
    if faces.is_empty():
        return Rect2()
    var bounds := AABB(faces[0], Vector3.ZERO)
    for vertex in faces:
        bounds = bounds.expand(vertex)
    var outline := label.outline_size * label.pixel_size
    bounds.position -= Vector3(outline, outline, 0.0)
    bounds.size += Vector3(outline * 2.0, outline * 2.0, 0.0)
    var scale := label.global_basis.get_scale()
    if label.fixed_size:
        if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
            scale *= absf(1.0 / _camera.get_camera_projection().y.y)
        else:
            scale *= -_camera.to_local(label.global_position).z
    var right := _camera.global_basis.x * scale.x
    var up := _camera.global_basis.y * scale.y
    var first := _camera.unproject_position(label.global_position + right * bounds.position.x + up * bounds.position.y)
    var last := _camera.unproject_position(label.global_position + right * bounds.end.x + up * bounds.end.y)
    var rect := Rect2(first, last - first).abs()
    if not rect.intersects(get_viewport().get_visible_rect()):
        return Rect2()
    return rect


func pick_zone_from_ray(from: Vector3, to: Vector3) -> String:
    if not is_inside_tree():
        return ""
    var world := get_world_3d()
    if world == null:
        return ""
    var query := PhysicsRayQueryParameters3D.create(from, to, ZONE_COLLISION_LAYER)
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var result: Dictionary = world.direct_space_state.intersect_ray(query)
    if result.is_empty():
        return ""
    var collider: Object = result.get("collider") as Object
    if collider is Area3D:
        return String((collider as Area3D).get_meta("zone_key", ""))
    return ""


func zone_keys() -> Array[String]:
    var keys: Array[String] = []
    for zone_key in ZONE_DEFINITIONS:
        keys.append(String(zone_key))
    return keys
