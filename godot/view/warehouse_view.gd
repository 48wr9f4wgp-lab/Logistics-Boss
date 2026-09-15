extends Node3D
class_name WarehouseView

const STATION_POSITIONS := {
    "center": Vector3(0.0, 0.35, 2.0),
    "inbound": Vector3(-5.0, 0.35, 1.8),
    "rack": Vector3(-1.5, 0.35, 0.0),
    "packing": Vector3(2.5, 0.35, 0.0),
    "outbound": Vector3(5.0, 0.35, 1.8),
}

var sim: WarehouseSim

var _camera: Camera3D
var _worker_root: Node3D
var _rack_root: Node3D
var _inbound_boxes: Node3D
var _rack_boxes: Node3D
var _packed_boxes: Node3D
var _bottleneck_label: Label3D

var _worker_nodes: Array[Node3D] = []
var _last_worker_count := -1
var _last_rack_capacity := -1
var _last_inbound := -1
var _last_rack_stock := -1
var _last_packed := -1

var _orbit_yaw := -0.62
var _orbit_pitch := -0.55
var _camera_distance := 16.0
var _touches: Dictionary = {}
var _last_pinch_distance := 0.0


func bind_sim(next_sim: WarehouseSim) -> void:
    sim = next_sim


func _ready() -> void:
    _build_environment()
    _build_facility()
    _build_camera()


func _process(_delta: float) -> void:
    if sim == null:
        return

    _sync_workers()
    _sync_rack_geometry()
    _sync_box_counts()
    _sync_bottleneck()
    _update_camera()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _camera_distance = maxf(9.0, _camera_distance - 0.8)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _camera_distance = minf(24.0, _camera_distance + 0.8)

    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
        _orbit_yaw -= event.relative.x * 0.008
        _orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.006, -1.05, -0.25)

    if event is InputEventScreenTouch:
        if event.pressed:
            _touches[event.index] = event.position
        else:
            _touches.erase(event.index)
            _last_pinch_distance = 0.0

    if event is InputEventScreenDrag:
        _touches[event.index] = event.position
        if _touches.size() == 1:
            _orbit_yaw -= event.relative.x * 0.009
            _orbit_pitch = clampf(_orbit_pitch - event.relative.y * 0.007, -1.05, -0.25)
        elif _touches.size() >= 2:
            var ids := _touches.keys()
            var a: Vector2 = _touches[ids[0]]
            var b: Vector2 = _touches[ids[1]]
            var distance := a.distance_to(b)
            if _last_pinch_distance > 0.0:
                _camera_distance = clampf(
                    _camera_distance - (distance - _last_pinch_distance) * 0.025,
                    9.0,
                    24.0
                )
            _last_pinch_distance = distance


func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.035, 0.06, 0.075)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.58, 0.70, 0.78)
    environment.ambient_light_energy = 0.68
    world.environment = environment
    add_child(world)

    var key_light := DirectionalLight3D.new()
    key_light.light_energy = 1.15
    key_light.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
    key_light.shadow_enabled = true
    add_child(key_light)

    var fill := OmniLight3D.new()
    fill.position = Vector3(0.0, 7.0, 3.0)
    fill.omni_range = 18.0
    fill.light_energy = 2.2
    fill.light_color = Color(0.53, 0.77, 0.90)
    add_child(fill)


func _build_camera() -> void:
    _camera = Camera3D.new()
    _camera.fov = 42.0
    _camera.current = true
    add_child(_camera)


func _build_facility() -> void:
    _box("Floor", Vector3(14.0, 0.25, 10.0), Vector3(0.0, -0.15, 1.0), Color(0.24, 0.31, 0.35))

    _box("InboundPad", Vector3(2.3, 0.12, 2.3), Vector3(-5.0, 0.05, 1.8), Color(0.30, 0.50, 0.65))
    _box("PackingPad", Vector3(2.5, 0.12, 2.4), Vector3(2.5, 0.05, 0.0), Color(0.62, 0.43, 0.16))
    _box("OutboundPad", Vector3(2.3, 0.12, 2.3), Vector3(5.0, 0.05, 1.8), Color(0.25, 0.58, 0.48))

    _make_station_sign("INBOUND", Vector3(-5.0, 2.0, 0.6), Color(0.42, 0.81, 1.0))
    _make_station_sign("PACK", Vector3(2.5, 2.0, -1.0), Color(1.0, 0.72, 0.26))
    _make_station_sign("OUTBOUND", Vector3(5.0, 2.0, 0.6), Color(0.46, 0.93, 0.70))

    _box("PackTable", Vector3(2.1, 0.35, 1.15), Vector3(2.5, 0.85, 0.0), Color(0.12, 0.18, 0.21))
    _box("OutboundConveyor", Vector3(2.0, 0.22, 0.7), Vector3(4.2, 0.68, 1.8), Color(0.09, 0.20, 0.27))

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

    _bottleneck_label = Label3D.new()
    _bottleneck_label.position = Vector3(0.0, 4.1, 0.8)
    _bottleneck_label.font_size = 48
    _bottleneck_label.outline_size = 8
    _bottleneck_label.modulate = Color(0.92, 0.97, 1.0)
    _bottleneck_label.text = "Warehouse安定運転"
    add_child(_bottleneck_label)


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
            var idle_x := -1.1 + float(i % 4) * 0.72
            var idle_z := 2.5 + float(i / 4) * 0.65
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

    var bays := 2 + sim.rack_level
    for bay in bays:
        var z := -1.8 + float(bay) * 1.2
        for x in [-2.2, -0.8]:
            _box_into(_rack_root, "Post", Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), Color(0.10, 0.15, 0.18))
        for y in [0.45, 1.15, 1.85]:
            _box_into(_rack_root, "Shelf", Vector3(1.55, 0.11, 0.85), Vector3(-1.5, y, z), Color(0.82, 0.58, 0.18))


func _sync_box_counts() -> void:
    if _last_inbound != sim.inbound_queue:
        _last_inbound = sim.inbound_queue
        _rebuild_boxes(_inbound_boxes, mini(sim.inbound_queue, 12), Vector3(-5.65, 0.28, 1.2), Vector2(4, 3), Color(0.87, 0.62, 0.28))

    if _last_rack_stock != sim.rack_stock:
        _last_rack_stock = sim.rack_stock
        _rebuild_boxes(_rack_boxes, mini(sim.rack_stock, 16), Vector3(-2.0, 0.62, -1.85), Vector2(4, 4), Color(0.90, 0.70, 0.38))

    if _last_packed != sim.packed_queue:
        _last_packed = sim.packed_queue
        _rebuild_boxes(_packed_boxes, mini(sim.packed_queue, 10), Vector3(4.35, 0.35, 1.45), Vector2(5, 2), Color(0.85, 0.66, 0.35))


func _sync_bottleneck() -> void:
    var info := sim.bottleneck()
    _bottleneck_label.text = String(info["label"])
    match int(info["severity"]):
        2:
            _bottleneck_label.modulate = Color(1.0, 0.58, 0.42)
        1:
            _bottleneck_label.modulate = Color(1.0, 0.80, 0.43)
        _:
            _bottleneck_label.modulate = Color(0.55, 1.0, 0.73)


func _update_camera() -> void:
    if _camera == null:
        return

    var target := Vector3(0.0, 0.65, 0.8)
    var horizontal := cos(_orbit_pitch) * _camera_distance
    var height := -sin(_orbit_pitch) * _camera_distance
    _camera.global_position = target + Vector3(
        sin(_orbit_yaw) * horizontal,
        height,
        cos(_orbit_yaw) * horizontal
    )
    _camera.look_at(target, Vector3.UP)


func _create_worker(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "Worker%d" % index

    var body := MeshInstance3D.new()
    var body_mesh := CylinderMesh.new()
    body_mesh.top_radius = 0.26
    body_mesh.bottom_radius = 0.30
    body_mesh.height = 0.72
    body.mesh = body_mesh
    body.position.y = 0.42

    var body_material := StandardMaterial3D.new()
    var palette := [
        Color(0.24, 0.66, 0.93),
        Color(0.35, 0.82, 0.60),
        Color(0.80, 0.45, 0.86),
        Color(0.97, 0.70, 0.25),
        Color(0.90, 0.38, 0.43),
        Color(0.25, 0.78, 0.82),
        Color(0.57, 0.48, 0.91),
    ]
    body_material.albedo_color = palette[index % palette.size()]
    body.material_override = body_material
    root.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.20
    head_mesh.height = 0.40
    head.mesh = head_mesh
    head.position.y = 0.92
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color(0.90, 0.74, 0.59)
    head.material_override = skin
    root.add_child(head)

    var cargo := MeshInstance3D.new()
    cargo.name = "Cargo"
    var cargo_mesh := BoxMesh.new()
    cargo_mesh.size = Vector3(0.38, 0.28, 0.30)
    cargo.mesh = cargo_mesh
    cargo.position = Vector3(0.0, 0.55, -0.38)
    var cargo_material := StandardMaterial3D.new()
    cargo_material.albedo_color = Color(0.91, 0.69, 0.35)
    cargo.material_override = cargo_material
    cargo.visible = false
    root.add_child(cargo)

    return root


func _make_station_sign(text: String, position: Vector3, color: Color) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = position
    label.font_size = 36
    label.outline_size = 6
    label.modulate = color
    add_child(label)


func _rebuild_boxes(root: Node3D, count: int, start: Vector3, grid: Vector2, color: Color) -> void:
    for child in root.get_children():
        child.queue_free()

    var columns := maxi(1, int(grid.x))
    for i in count:
        var x := start.x + float(i % columns) * 0.42
        var z := start.z + float((i / columns) % maxi(1, int(grid.y))) * 0.42
        var y := start.y + float(i / (columns * maxi(1, int(grid.y)))) * 0.34
        _box_into(root, "Parcel", Vector3(0.34, 0.28, 0.34), Vector3(x, y, z), color)


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
    material.roughness = 0.72
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance
