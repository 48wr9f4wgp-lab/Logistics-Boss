extends Node3D
class_name WarehouseZoneInteractionView

signal zone_selected(zone_key: String)

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const ZONE_COLLISION_LAYER := 1 << 19
const TAP_MAX_MOVEMENT := 18.0
const RAY_LENGTH := 120.0

const ZONE_DEFINITIONS := {
    "inbound": {
        "label": "INBOUND",
        "position": Vector3(-5.25, 1.05, 0.15),
        "size": Vector3(2.55, 2.1, 7.2),
    },
    "storage": {
        "label": "STORAGE",
        "position": Vector3(-2.20, 1.05, 0.15),
        "size": Vector3(2.70, 2.1, 7.2),
    },
    "picking": {
        "label": "PICKING",
        "position": Vector3(0.25, 1.05, 0.15),
        "size": Vector3(1.70, 2.1, 7.2),
    },
    "packing": {
        "label": "PACKING",
        "position": Vector3(2.65, 1.05, 0.15),
        "size": Vector3(2.60, 2.1, 7.2),
    },
    "shipping": {
        "label": "SHIPPING",
        "position": Vector3(5.30, 1.05, 0.15),
        "size": Vector3(2.45, 2.1, 7.2),
    },
}

var _view: WarehouseView
var _camera: Camera3D
var _zone_areas: Dictionary = {}
var _zone_labels: Dictionary = {}
var _touch_start: Dictionary = {}
var _touch_movement: Dictionary = {}
var _mouse_pressed := false
var _mouse_start := Vector2.ZERO
var _mouse_movement := 0.0


func bind(view: WarehouseView) -> void:
    _view = view
    _camera = view._camera if view != null else null
    if _zone_areas.is_empty():
        _build_zone_targets()


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
        var zone_position: Vector3 = definition["position"]
        label.position = Vector3(zone_position.x, 0.16, 3.55)
        label.font = JAPANESE_UI_FONT
        label.font_size = 22
        label.outline_size = 7
        label.modulate = Color(0.70, 0.91, 1.0, 0.82)
        label.no_depth_test = true
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.double_sided = true
        add_child(label)
        _zone_labels[String(zone_key)] = label


func _unhandled_input(event: InputEvent) -> void:
    if _camera == null:
        return

    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_start[touch.index] = touch.position
            _touch_movement[touch.index] = 0.0
        else:
            var movement := float(_touch_movement.get(touch.index, 9999.0))
            _touch_start.erase(touch.index)
            _touch_movement.erase(touch.index)
            if movement <= TAP_MAX_MOVEMENT:
                _select_at_screen(touch.position)
        return

    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _touch_movement.has(drag.index):
            _touch_movement[drag.index] = float(_touch_movement[drag.index]) + drag.relative.length()
        return

    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index != MOUSE_BUTTON_LEFT:
            return
        if mouse_button.pressed:
            _mouse_pressed = true
            _mouse_start = mouse_button.position
            _mouse_movement = 0.0
        else:
            var should_select := _mouse_pressed and _mouse_movement <= TAP_MAX_MOVEMENT
            _mouse_pressed = false
            if should_select:
                _select_at_screen(mouse_button.position)
        return

    if event is InputEventMouseMotion and _mouse_pressed:
        _mouse_movement += (event as InputEventMouseMotion).relative.length()


func _select_at_screen(screen_position: Vector2) -> String:
    var zone_key := pick_zone_at_screen(screen_position)
    if not zone_key.is_empty():
        zone_selected.emit(zone_key)
    return zone_key


func pick_zone_at_screen(screen_position: Vector2) -> String:
    if _camera == null:
        return ""
    var from := _camera.project_ray_origin(screen_position)
    var direction := _camera.project_ray_normal(screen_position)
    return pick_zone_from_ray(from, from + direction * RAY_LENGTH)


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
