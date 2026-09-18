extends Node3D
class_name WarehouseView

const STATION_POSITIONS := {
    "center": Vector3(0.0, 0.35, 2.6),
    "inbound": Vector3(-5.25, 0.35, 2.4),
    "rack": Vector3(-1.6, 0.35, -0.15),
    "packing": Vector3(2.55, 0.35, -0.05),
    "outbound": Vector3(5.15, 0.35, 2.35),
}

const NAVY := Color(0.025, 0.055, 0.075)
const FLOOR := Color(0.16, 0.205, 0.235)
const STEEL := Color(0.075, 0.12, 0.16)
const STEEL_LIGHT := Color(0.13, 0.20, 0.25)
const ORANGE := Color(0.95, 0.48, 0.08)
const CYAN := Color(0.18, 0.72, 0.96)
const MINT := Color(0.27, 0.92, 0.68)
const WARM := Color(1.0, 0.72, 0.42)
const PARCEL := Color(0.78, 0.52, 0.25)

const MOUSE_ORBIT_SENSITIVITY := Vector2(0.0040, 0.0030)
const TOUCH_ORBIT_SENSITIVITY := Vector2(0.0032, 0.0026)
const PINCH_ZOOM_SENSITIVITY := 0.012
const CAMERA_POSITION_SMOOTHING := 10.0
const INPUT_DEADZONE := 0.75
const MAX_DRAG_STEP := 36.0
const MAX_PINCH_STEP := 48.0

var sim: WarehouseSim

var _camera: Camera3D
var _worker_root: Node3D
var _rack_root: Node3D
var _inbound_boxes: Node3D
var _rack_boxes: Node3D
var _packed_boxes: Node3D

var _worker_nodes: Array[Node3D] = []
var _last_worker_count := -1
var _last_rack_capacity := -1
var _last_inbound := -1
var _last_rack_stock := -1
var _last_packed := -1

var _orbit_yaw := -0.78
var _orbit_pitch := -0.70
var _camera_distance := 18.0
var _touches: Dictionary = {}
var _last_pinch_distance := 0.0
var _camera_pose_initialized := false


func bind_sim(next_sim: WarehouseSim) -> void:
    sim = next_sim


func _ready() -> void:
    _build_environment()
    _build_facility()
    _build_camera()


func _process(delta: float) -> void:
    if sim == null:
        return

    _sync_workers()
    _sync_rack_geometry()
    _sync_box_counts()
    _update_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _camera_distance = maxf(12.0, _camera_distance - 0.8)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _camera_distance = minf(25.0, _camera_distance + 0.8)

    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
        var mouse_drag: Vector2 = event.relative
        mouse_drag = mouse_drag.limit_length(MAX_DRAG_STEP)
        if mouse_drag.length() >= INPUT_DEADZONE:
            _orbit_yaw -= mouse_drag.x * MOUSE_ORBIT_SENSITIVITY.x
            _orbit_pitch = clampf(
                _orbit_pitch - mouse_drag.y * MOUSE_ORBIT_SENSITIVITY.y,
                -0.98,
                -0.48
            )

    if event is InputEventScreenTouch:
        if event.pressed:
            _touches[event.index] = event.position
            if _touches.size() >= 2:
                _last_pinch_distance = 0.0
        else:
            _touches.erase(event.index)
            _last_pinch_distance = 0.0

    if event is InputEventScreenDrag:
        _touches[event.index] = event.position
        if _touches.size() == 1:
            var touch_drag: Vector2 = event.relative
            touch_drag = touch_drag.limit_length(MAX_DRAG_STEP)
            if touch_drag.length() >= INPUT_DEADZONE:
                _orbit_yaw -= touch_drag.x * TOUCH_ORBIT_SENSITIVITY.x
                _orbit_pitch = clampf(
                    _orbit_pitch - touch_drag.y * TOUCH_ORBIT_SENSITIVITY.y,
                    -0.98,
                    -0.48
                )
        elif _touches.size() >= 2:
            var ids := _touches.keys()
            var a: Vector2 = _touches[ids[0]]
            var b: Vector2 = _touches[ids[1]]
            var distance := a.distance_to(b)
            if _last_pinch_distance > 0.0:
                var pinch_delta := clampf(
                    distance - _last_pinch_distance,
                    -MAX_PINCH_STEP,
                    MAX_PINCH_STEP
                )
                _camera_distance = clampf(
                    _camera_distance - pinch_delta * PINCH_ZOOM_SENSITIVITY,
                    12.0,
                    25.0
                )
            _last_pinch_distance = distance


func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.012, 0.027, 0.040)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.20, 0.31, 0.39)
    environment.ambient_light_energy = 0.58
    world.environment = environment
    add_child(world)

    var key_light := DirectionalLight3D.new()
    key_light.light_energy = 0.72
    key_light.light_color = Color(0.70, 0.84, 0.95)
    key_light.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
    key_light.shadow_enabled = true
    add_child(key_light)

    var cool_fill := OmniLight3D.new()
    cool_fill.position = Vector3(-1.0, 7.2, 1.5)
    cool_fill.omni_range = 20.0
    cool_fill.light_energy = 1.2
    cool_fill.light_color = Color(0.28, 0.62, 0.82)
    add_child(cool_fill)

    _work_light(Vector3(-5.2, 4.0, 1.9), 7.2, 2.7)
    _work_light(Vector3(-1.6, 4.8, -0.8), 8.5, 2.35)
    _work_light(Vector3(2.6, 4.0, -0.1), 6.5, 2.8)
    _work_light(Vector3(5.1, 4.0, 2.2), 6.5, 2.65)


func _work_light(position: Vector3, light_range: float, energy: float) -> void:
    var light := OmniLight3D.new()
    light.position = position
    light.omni_range = light_range
    light.light_energy = energy
    light.light_color = WARM
    light.shadow_enabled = true
    add_child(light)


func _build_camera() -> void:
    _camera = Camera3D.new()
    _camera.fov = 34.0
    _camera.current = true
    add_child(_camera)


func _build_facility() -> void:
    _box("Floor", Vector3(15.8, 0.24, 11.8), Vector3(0.0, -0.16, 0.7), FLOOR)
    _box("BackWall", Vector3(15.8, 4.3, 0.24), Vector3(0.0, 2.0, -4.9), Color(0.035, 0.065, 0.085))
    _box("LeftWall", Vector3(0.24, 4.3, 10.8), Vector3(-7.8, 2.0, 0.45), Color(0.030, 0.058, 0.077))

    _build_lane_markings()
    _build_inbound_dock()
    _build_packing_zone()
    _build_outbound_dock()
    _build_agv()
    _build_forklift()

    _worker_root = Node3D.new()
    _worker_root.name = "Workers"
    add_child(_worker_root)

    _rack_root = Node3D.new()
    _rack_root.name = "RackGeometry"
    add_child(_rack_root)

    _inbound_boxes = Node3D.new()
    _inbound_boxes.name = "InboundBoxes"
    add_child(_inbound_boxes)

    _rack_boxes = Node3D.new()
    _rack_boxes.name = "RackBoxes"
    add_child(_rack_boxes)

    _packed_boxes = Node3D.new()
    _packed_boxes.name = "PackedBoxes"
    add_child(_packed_boxes)

    _make_station_sign("INBOUND", Vector3(-5.45, 2.35, -3.95), CYAN)
    _make_station_sign("STORAGE", Vector3(-1.65, 3.85, -4.55), Color(0.58, 0.76, 1.0))
    _make_station_sign("PACK", Vector3(2.55, 2.5, -3.95), Color(1.0, 0.72, 0.26))
    _make_station_sign("OUTBOUND", Vector3(5.25, 2.35, -3.95), MINT)


func _build_lane_markings() -> void:
    var yellow := Color(0.92, 0.60, 0.10)
    for z in [-3.5, 3.7]:
        _box("Lane", Vector3(12.8, 0.025, 0.055), Vector3(0.0, 0.015, z), yellow)
    for x in [-6.25, 0.0, 6.25]:
        _box("Lane", Vector3(0.055, 0.025, 7.2), Vector3(x, 0.015, 0.1), yellow)


func _build_inbound_dock() -> void:
    _box("InboundPad", Vector3(2.65, 0.10, 2.55), Vector3(-5.25, 0.02, 2.4), Color(0.11, 0.38, 0.55))
    _dock_frame(Vector3(-5.25, 1.25, -4.45), CYAN)
    _box("InboundDesk", Vector3(1.65, 0.72, 0.85), Vector3(-5.15, 0.40, -2.85), STEEL_LIGHT)


func _build_packing_zone() -> void:
    _box("PackingPad", Vector3(3.1, 0.10, 2.75), Vector3(2.55, 0.02, -0.05), Color(0.42, 0.26, 0.075))
    _box("PackTable", Vector3(2.35, 0.36, 1.15), Vector3(2.55, 0.85, -0.05), STEEL_LIGHT)
    _box("PackMonitor", Vector3(0.62, 0.54, 0.12), Vector3(2.55, 1.47, -0.52), Color(0.06, 0.12, 0.15))
    _box("PackScreen", Vector3(0.48, 0.38, 0.03), Vector3(2.55, 1.47, -0.59), CYAN)
    _conveyor(Vector3(3.95, 0.68, 0.72), Vector3(2.2, 0.28, 0.78))


func _build_outbound_dock() -> void:
    _box("OutboundPad", Vector3(2.8, 0.10, 2.55), Vector3(5.15, 0.02, 2.35), Color(0.08, 0.38, 0.31))
    _dock_frame(Vector3(5.2, 1.25, -4.45), MINT)
    _conveyor(Vector3(5.15, 0.68, 1.45), Vector3(2.15, 0.26, 0.78))
    _box("TruckBody", Vector3(2.1, 1.75, 1.55), Vector3(6.15, 0.92, 4.25), Color(0.72, 0.76, 0.79))
    _box("TruckCab", Vector3(1.0, 1.35, 1.5), Vector3(4.55, 0.70, 4.25), Color(0.12, 0.27, 0.42))


func _dock_frame(center: Vector3, accent: Color) -> void:
    _box("DockPost", Vector3(0.18, 2.3, 0.18), center + Vector3(-1.05, 0.0, 0.0), STEEL)
    _box("DockPost", Vector3(0.18, 2.3, 0.18), center + Vector3(1.05, 0.0, 0.0), STEEL)
    _box("DockBeam", Vector3(2.28, 0.18, 0.18), center + Vector3(0.0, 1.05, 0.0), accent)


func _conveyor(position: Vector3, size: Vector3) -> void:
    _box("Conveyor", size, position, Color(0.08, 0.13, 0.16))
    var roller_count := maxi(2, int(size.x / 0.35))
    for i in roller_count:
        var x := position.x - size.x * 0.42 + float(i) * (size.x * 0.84 / float(maxi(1, roller_count - 1)))
        _box("Roller", Vector3(0.055, size.y + 0.035, size.z * 0.92), Vector3(x, position.y + 0.04, position.z), Color(0.30, 0.38, 0.42))


func _build_agv() -> void:
    _box("AGVBase", Vector3(1.05, 0.24, 0.82), Vector3(-0.10, 0.18, 3.05), Color(0.72, 0.77, 0.80))
    _box("AGVTop", Vector3(0.82, 0.12, 0.62), Vector3(-0.10, 0.34, 3.05), Color(0.05, 0.11, 0.14))
    _box("AGVLight", Vector3(0.52, 0.055, 0.035), Vector3(-0.10, 0.29, 2.62), CYAN)


func _build_forklift() -> void:
    var root := Node3D.new()
    root.name = "Forklift"
    root.position = Vector3(-3.7, 0.0, 1.45)
    add_child(root)
    _box_into(root, "Body", Vector3(0.95, 0.62, 1.1), Vector3(0.0, 0.40, 0.0), Color(0.96, 0.58, 0.08))
    _box_into(root, "Cab", Vector3(0.78, 0.72, 0.66), Vector3(0.0, 0.91, 0.18), STEEL)
    _box_into(root, "MastL", Vector3(0.10, 1.65, 0.10), Vector3(-0.33, 1.05, -0.56), Color(0.04, 0.07, 0.08))
    _box_into(root, "MastR", Vector3(0.10, 1.65, 0.10), Vector3(0.33, 1.05, -0.56), Color(0.04, 0.07, 0.08))
    _box_into(root, "ForkL", Vector3(0.10, 0.08, 0.85), Vector3(-0.28, 0.18, -0.86), STEEL_LIGHT)
    _box_into(root, "ForkR", Vector3(0.10, 0.08, 0.85), Vector3(0.28, 0.18, -0.86), STEEL_LIGHT)


func _sync_workers() -> void:
    if _last_worker_count != sim.worker_count:
        _last_worker_count = sim.worker_count
        for node in _worker_nodes:
            node.queue_free()
        _worker_nodes.clear()
        for i in sim.worker_count:
            var worker := _create_worker(i)
            _worker_root.add_child(worker)
            _worker_nodes.append(worker)

    for i in mini(_worker_nodes.size(), sim.workers.size()):
        var data: Dictionary = sim.workers[i]
        var node := _worker_nodes[i]
        var task := int(data["task"])

        if task == WarehouseSim.Task.IDLE:
            var idle_x := 0.1 + float(i % 4) * 0.72
            var idle_z := 2.0 + float(i / 4) * 0.65
            node.position = Vector3(idle_x, 0.35, idle_z)
            node.rotation.y = 0.0
            node.get_node("Cargo").visible = false
            continue

        var source: Vector3 = STATION_POSITIONS.get(String(data["source"]), STATION_POSITIONS["center"])
        var target: Vector3 = STATION_POSITIONS.get(String(data["target"]), STATION_POSITIONS["center"])
        var t := smoothstep(0.0, 1.0, float(data["progress"]))
        node.position = source.lerp(target, t)
        node.look_at(Vector3(target.x, node.position.y, target.z), Vector3.UP, true)
        node.get_node("Cargo").visible = true


func _sync_rack_geometry() -> void:
    if _last_rack_capacity == sim.rack_capacity:
        return
    _last_rack_capacity = sim.rack_capacity

    for child in _rack_root.get_children():
        child.queue_free()

    var bays := 3 + sim.rack_level
    for aisle in 2:
        var rack_x := -2.25 + float(aisle) * 1.45
        for bay in bays:
            var z := -3.25 + float(bay) * 1.05
            for px in [rack_x - 0.56, rack_x + 0.56]:
                _box_into(_rack_root, "RackPost", Vector3(0.11, 3.35, 0.11), Vector3(px, 1.68, z), Color(0.055, 0.12, 0.18))
            for y in [0.52, 1.30, 2.08, 2.86]:
                _box_into(_rack_root, "RackShelf", Vector3(1.24, 0.095, 0.76), Vector3(rack_x, y, z), Color(0.18, 0.26, 0.30))
                _box_into(_rack_root, "RackBeam", Vector3(1.32, 0.10, 0.08), Vector3(rack_x, y + 0.04, z - 0.36), ORANGE)


func _sync_box_counts() -> void:
    if _last_inbound != sim.inbound_queue:
        _last_inbound = sim.inbound_queue
        _rebuild_boxes(_inbound_boxes, mini(sim.inbound_queue, 12), Vector3(-6.0, 0.28, 1.72), Vector2(4, 3), PARCEL)

    if _last_rack_stock != sim.rack_stock:
        _last_rack_stock = sim.rack_stock
        _rebuild_boxes(_rack_boxes, mini(sim.rack_stock, 20), Vector3(-2.55, 0.68, -3.3), Vector2(4, 5), Color(0.82, 0.60, 0.34))

    if _last_packed != sim.packed_queue:
        _last_packed = sim.packed_queue
        _rebuild_boxes(_packed_boxes, mini(sim.packed_queue, 10), Vector3(4.45, 0.36, 1.15), Vector2(5, 2), Color(0.84, 0.61, 0.31))


func _update_camera(delta: float) -> void:
    if _camera == null:
        return

    var target := Vector3(0.0, 0.85, 0.25)
    var horizontal := cos(_orbit_pitch) * _camera_distance
    var height := -sin(_orbit_pitch) * _camera_distance
    var desired_position := target + Vector3(
        sin(_orbit_yaw) * horizontal,
        height,
        cos(_orbit_yaw) * horizontal
    )

    if not _camera_pose_initialized:
        _camera.global_position = desired_position
        _camera_pose_initialized = true
    else:
        var smoothing_weight := 1.0 - exp(-CAMERA_POSITION_SMOOTHING * maxf(delta, 0.0))
        _camera.global_position = _camera.global_position.lerp(
            desired_position,
            clampf(smoothing_weight, 0.0, 1.0)
        )

    _camera.look_at(target, Vector3.UP)


func _create_worker(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Worker%d" % index

    var legs := MeshInstance3D.new()
    var legs_mesh := BoxMesh.new()
    legs_mesh.size = Vector3(0.42, 0.46, 0.34)
    legs.mesh = legs_mesh
    legs.position.y = 0.25
    var legs_material := StandardMaterial3D.new()
    legs_material.albedo_color = Color(0.035, 0.07, 0.09)
    legs_material.roughness = 0.72
    legs.material_override = legs_material
    root.add_child(legs)

    var body := MeshInstance3D.new()
    var body_mesh := CylinderMesh.new()
    body_mesh.top_radius = 0.25
    body_mesh.bottom_radius = 0.29
    body_mesh.height = 0.62
    body.mesh = body_mesh
    body.position.y = 0.66
    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.10, 0.20, 0.27)
    body_material.roughness = 0.60
    body_material.metallic = 0.04
    body.material_override = body_material
    root.add_child(body)

    var vest := MeshInstance3D.new()
    var vest_mesh := BoxMesh.new()
    vest_mesh.size = Vector3(0.52, 0.32, 0.38)
    vest.mesh = vest_mesh
    vest.position = Vector3(0.0, 0.68, -0.02)
    var vest_material := StandardMaterial3D.new()
    var vest_palette := [ORANGE, Color(0.97, 0.70, 0.12), Color(0.18, 0.65, 0.90)]
    vest_material.albedo_color = vest_palette[index % vest_palette.size()]
    vest_material.roughness = 0.46
    vest_material.metallic = 0.02
    vest.material_override = vest_material
    root.add_child(vest)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.20
    head_mesh.height = 0.40
    head.mesh = head_mesh
    head.position.y = 1.08
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.88, 0.69, 0.53)
    skin.roughness = 0.76
    head.material_override = skin
    root.add_child(head)

    var helmet := MeshInstance3D.new()
    var helmet_mesh := CylinderMesh.new()
    helmet_mesh.top_radius = 0.215
    helmet_mesh.bottom_radius = 0.235
    helmet_mesh.height = 0.12
    helmet.mesh = helmet_mesh
    helmet.position.y = 1.25
    var helmet_material := StandardMaterial3D.new()
    helmet_material.albedo_color = Color(1.0, 0.72, 0.08)
    helmet_material.roughness = 0.34
    helmet_material.metallic = 0.08
    helmet.material_override = helmet_material
    root.add_child(helmet)

    var cargo := MeshInstance3D.new()
    cargo.name = "Cargo"
    var cargo_mesh := BoxMesh.new()
    cargo_mesh.size = Vector3(0.42, 0.32, 0.34)
    cargo.mesh = cargo_mesh
    cargo.position = Vector3(0.0, 0.66, -0.40)
    var cargo_material := StandardMaterial3D.new()
    cargo_material.albedo_color = Color(0.86, 0.61, 0.30)
    cargo_material.roughness = 0.80
    cargo.material_override = cargo_material
    cargo.visible = false
    root.add_child(cargo)

    return root


func _make_station_sign(text: String, position: Vector3, color: Color) -> void:
    var plate := _box("SignPlate", Vector3(2.1, 0.58, 0.09), position + Vector3(0.0, 0.0, 0.10), Color(0.025, 0.055, 0.070))
    plate.rotation_degrees.x = -4.0

    var label := Label3D.new()
    label.text = text
    label.position = position
    label.font_size = 34
    label.outline_size = 7
    label.modulate = color
    add_child(label)


func _rebuild_boxes(root: Node3D, count: int, start: Vector3, grid: Vector2, color: Color) -> void:
    for child in root.get_children():
        child.queue_free()

    var columns := maxi(1, int(grid.x))
    for i in count:
        var x := start.x + float(i % columns) * 0.46
        var z := start.z + float((i / columns) % maxi(1, int(grid.y))) * 0.46
        var y := start.y + float(i / (columns * maxi(1, int(grid.y)))) * 0.36
        # Small deterministic tone variation keeps queue piles from reading as
        # one cloned plastic block while preserving the authoritative box count.
        var tone := 0.96 + float(i % 3) * 0.025
        var parcel_color := Color(
            clampf(color.r * tone, 0.0, 1.0),
            clampf(color.g * tone, 0.0, 1.0),
            clampf(color.b * tone, 0.0, 1.0),
            color.a
        )
        _box_into(root, "Parcel", Vector3(0.39, 0.31, 0.39), Vector3(x, y, z), parcel_color)


func _box(name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    return _box_into(self, name, size, position, color)


func _box_into(parent: Node, name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position

    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.58
    material.metallic = 0.0

    # Final mobile surface finish: cardboard stays matte, while the forklift's
    # painted body and steel cab/mast get enough specular separation to stop
    # reading as the same flat material. Geometry and gameplay remain unchanged.
    match name:
        "Parcel":
            material.roughness = 0.80
        "Body":
            material.roughness = 0.42
            material.metallic = 0.10
        "Cab", "MastL", "MastR":
            material.roughness = 0.50
            material.metallic = 0.18

    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance
