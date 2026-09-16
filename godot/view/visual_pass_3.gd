extends Node3D
class_name WarehouseVisualPass3

const NAVY := Color(0.016, 0.034, 0.047)
const STEEL := Color(0.055, 0.090, 0.115)
const STEEL_LIGHT := Color(0.16, 0.23, 0.27)
const ORANGE := Color(0.97, 0.49, 0.08)
const CYAN := Color(0.16, 0.80, 1.0)
const MINT := Color(0.24, 0.95, 0.67)
const WARM := Color(1.0, 0.70, 0.31)
const ALERT := Color(1.0, 0.26, 0.08)
const ALERT_SOFT := Color(1.0, 0.56, 0.18)
const CARTON := Color(0.78, 0.53, 0.26)
const SIGNAL_IDLE_ENERGY := 1.05
const SIGNAL_WARNING_ENERGY := 3.2
const SIGNAL_CRITICAL_ENERGY := 4.6

var warehouse_view: WarehouseView
var hud: GameHud
var _flow_signals: Dictionary = {}
var _last_bottleneck_key := ""
var _last_bottleneck_severity := -1


func bind(view: WarehouseView, game_hud: GameHud) -> void:
    warehouse_view = view
    hud = game_hud
    warehouse_view._camera_distance = 14.85
    warehouse_view._orbit_pitch = -0.61
    warehouse_view._orbit_yaw = -0.80
    call_deferred("_tune_camera")
    call_deferred("_sync_domain_bottleneck_signals")


func _ready() -> void:
    _build_pack_focal_cell()
    _build_rack_depth_details()
    _build_floor_wayfinding()
    _build_vehicle_readability()
    _build_practical_glow()


func _process(_delta: float) -> void:
    _sync_domain_bottleneck_signals()


func _tune_camera() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        camera.fov = 30.25

    # HUD geometry is owned by the release/mobile HUD classes. Visual passes may
    # tune the 3D camera, materials and scene readability, but must not rewrite
    # screen-space layout after the HUD has completed its responsive setup.


func _build_pack_focal_cell() -> void:
    # The packing cell is the visual heart of the warehouse. A gantry and light bar
    # give the eye one clear hero machine without changing simulation behavior.
    _box("PackHeroBase", Vector3(3.15, 0.075, 2.55), Vector3(2.55, 0.055, -0.08), Color(0.24, 0.16, 0.055))
    for x in [1.15, 3.95]:
        _box("PackGantryPost", Vector3(0.15, 2.20, 0.15), Vector3(x, 1.15, -0.75), STEEL)
    _box("PackGantryTop", Vector3(2.95, 0.17, 0.18), Vector3(2.55, 2.20, -0.75), STEEL_LIGHT)
    _emissive_box("PackGantryGlow", Vector3(2.35, 0.055, 0.055), Vector3(2.55, 2.12, -0.66), CYAN, 3.2)

    _box("PackStatusTower", Vector3(0.16, 1.05, 0.16), Vector3(3.72, 1.55, -0.40), STEEL)
    _emissive_box("PackStatusGreen", Vector3(0.19, 0.18, 0.19), Vector3(3.72, 2.02, -0.40), MINT, 2.8)
    _emissive_box("PackStatusAmber", Vector3(0.19, 0.13, 0.19), Vector3(3.72, 1.84, -0.40), WARM, 2.0)

    # Parcels on the pack handoff create a readable production line rather than empty furniture.
    for i in 5:
        var x := 1.62 + float(i) * 0.43
        _carton(Vector3(x, 1.04, 0.05), Vector3(0.36, 0.28, 0.34))

    # Short guard rails make the cell feel like installed industrial equipment.
    for z in [-1.20, 1.08]:
        _box("PackGuard", Vector3(3.0, 0.10, 0.10), Vector3(2.55, 0.60, z), ORANGE)
        _box("PackGuardPostL", Vector3(0.11, 0.74, 0.11), Vector3(1.08, 0.37, z), ORANGE)
        _box("PackGuardPostR", Vector3(0.11, 0.74, 0.11), Vector3(4.02, 0.37, z), ORANGE)


func _build_rack_depth_details() -> void:
    # Add loaded pallet silhouettes and address beacons to break the primitive rack look.
    for aisle in 2:
        var x := -2.25 + float(aisle) * 1.45
        for z in [-2.95, -1.90, -0.85, 0.20, 1.25]:
            _pallet(Vector3(x, 0.17, z))
            _carton(Vector3(x - 0.24, 0.54, z), Vector3(0.42, 0.42, 0.52))
            _carton(Vector3(x + 0.24, 0.54, z), Vector3(0.42, 0.42, 0.52))

    for z in [-3.25, -1.15, 0.95, 3.05]:
        _emissive_box("RackBeacon", Vector3(0.10, 0.20, 0.08), Vector3(-0.08, 2.65, z), CYAN, 2.1)


func _build_floor_wayfinding() -> void:
    # Chevron route marks visually connect receiving -> storage -> pack -> outbound.
    var route_points := [
        Vector3(-4.45, 0.043, 2.85),
        Vector3(-2.65, 0.043, 2.85),
        Vector3(-0.70, 0.043, 2.20),
        Vector3(1.05, 0.043, 1.35),
        Vector3(3.55, 0.043, 1.55),
        Vector3(5.00, 0.043, 2.25),
    ]
    for p in route_points:
        var a := _box("RouteChevronA", Vector3(0.55, 0.025, 0.085), p + Vector3(-0.17, 0.0, 0.0), Color(0.36, 0.65, 0.72))
        a.rotation_degrees.y = -28.0
        var b := _box("RouteChevronB", Vector3(0.55, 0.025, 0.085), p + Vector3(0.17, 0.0, 0.0), Color(0.36, 0.65, 0.72))
        b.rotation_degrees.y = 28.0

    # Small floor plates reduce the remaining empty-slab feeling without creating fake gameplay objects.
    for x in [-5.85, -4.85, 4.55, 5.55]:
        _box("FloorPlate", Vector3(0.72, 0.025, 0.52), Vector3(x, 0.036, 3.15), Color(0.11, 0.17, 0.19))


func _build_vehicle_readability() -> void:
    # Add high-contrast edges around the forklift and AGV so they remain readable on a phone.
    if warehouse_view != null:
        var forklift := warehouse_view.get_node_or_null("Forklift")
        if forklift != null:
            _emissive_box_into(forklift, "ForkHeadLampL", Vector3(0.13, 0.12, 0.05), Vector3(-0.25, 1.10, -0.48), WARM, 2.7)
            _emissive_box_into(forklift, "ForkHeadLampR", Vector3(0.13, 0.12, 0.05), Vector3(0.25, 1.10, -0.48), WARM, 2.7)
            _box_into(forklift, "ForkRoof", Vector3(0.82, 0.08, 0.68), Vector3(0.0, 1.35, 0.18), STEEL_LIGHT)

    _emissive_box("AGVSideGlowL", Vector3(0.045, 0.08, 0.64), Vector3(-0.62, 0.30, 3.05), CYAN, 2.7)
    _emissive_box("AGVSideGlowR", Vector3(0.045, 0.08, 0.64), Vector3(0.42, 0.30, 3.05), CYAN, 2.7)

    # Truck door/marker details keep the vehicle recognizable even when partly cropped.
    _box("TruckDoor", Vector3(0.035, 0.72, 0.66), Vector3(4.02, 0.88, 4.25), Color(0.08, 0.18, 0.29))
    _emissive_box("TruckTailGlow", Vector3(0.05, 0.17, 0.85), Vector3(7.22, 0.70, 4.25), Color(1.0, 0.20, 0.12), 2.1)


func _build_practical_glow() -> void:
    # These low-cost emissive edges are the in-world operational status layer.
    # They mirror authoritative bottleneck state instead of inventing a second
    # visual simulation, so the player can read the problem inside the facility.
    _register_flow_signal(
        "inbound",
        _emissive_box("InboundEdge", Vector3(1.95, 0.045, 0.055), Vector3(-5.25, 0.16, 1.18), CYAN, SIGNAL_IDLE_ENERGY)
    )
    _register_flow_signal(
        "rack",
        _emissive_box("StorageEdge", Vector3(0.055, 0.045, 4.40), Vector3(-0.12, 0.16, -0.10), Color(0.35, 0.65, 0.88), SIGNAL_IDLE_ENERGY)
    )
    _register_flow_signal(
        "orders",
        _emissive_box("PickEdge", Vector3(1.45, 0.045, 0.055), Vector3(0.68, 0.16, 1.40), CYAN, SIGNAL_IDLE_ENERGY)
    )
    _register_flow_signal(
        "packing",
        _emissive_box("PackEdge", Vector3(2.85, 0.045, 0.055), Vector3(2.55, 0.16, -1.42), Color(0.58, 0.34, 0.14), SIGNAL_IDLE_ENERGY)
    )
    _register_flow_signal(
        "outbound",
        _emissive_box("OutboundEdge", Vector3(2.10, 0.045, 0.055), Vector3(5.15, 0.16, 1.10), MINT, SIGNAL_IDLE_ENERGY)
    )

    _point_light(Vector3(2.55, 3.0, -0.25), WARM, 4.4, 1.55)
    _point_light(Vector3(-1.55, 3.2, -0.70), Color(0.35, 0.65, 0.88), 4.8, 0.80)


func _register_flow_signal(key: String, mesh: MeshInstance3D) -> void:
    _flow_signals[key] = [mesh]


func _sync_domain_bottleneck_signals() -> void:
    if hud == null or hud.sim == null or _flow_signals.is_empty():
        return

    var info: Dictionary = hud.sim.bottleneck()
    var active_key := String(info.get("key", "stable"))
    var severity := int(info.get("severity", 0))
    if active_key == _last_bottleneck_key and severity == _last_bottleneck_severity:
        return

    for key_variant in _flow_signals.keys():
        var key := String(key_variant)
        var active := key == active_key and active_key != "stable"
        var color := _base_signal_color(key)
        var energy := SIGNAL_IDLE_ENERGY
        if active:
            color = ALERT if severity >= 2 else ALERT_SOFT
            energy = SIGNAL_CRITICAL_ENERGY if severity >= 2 else SIGNAL_WARNING_ENERGY

        var meshes: Array = _flow_signals[key]
        for mesh_variant in meshes:
            var mesh := mesh_variant as MeshInstance3D
            if mesh == null:
                continue
            var material := mesh.material_override as StandardMaterial3D
            if material == null:
                continue
            material.albedo_color = color
            material.emission = color
            material.emission_energy_multiplier = energy

    _last_bottleneck_key = active_key
    _last_bottleneck_severity = severity


func _base_signal_color(key: String) -> Color:
    match key:
        "inbound":
            return CYAN
        "rack":
            return Color(0.35, 0.65, 0.88)
        "orders":
            return CYAN
        "packing":
            return Color(0.58, 0.34, 0.14)
        "outbound":
            return MINT
        _:
            return Color(0.28, 0.48, 0.56)


func _point_light(position: Vector3, color: Color, light_range: float, energy: float) -> void:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.omni_range = light_range
    light.light_energy = energy
    light.shadow_enabled = false
    add_child(light)


func _pallet(position: Vector3) -> void:
    _box("Pallet", Vector3(0.95, 0.10, 0.78), position, Color(0.43, 0.25, 0.095))
    for dx in [-0.31, 0.0, 0.31]:
        _box("PalletSlat", Vector3(0.22, 0.075, 0.84), position + Vector3(dx, 0.075, 0.0), Color(0.55, 0.33, 0.12))


func _carton(position: Vector3, size: Vector3) -> void:
    _box("Carton", size, position, CARTON)
    _box("CartonTape", Vector3(size.x * 0.16, size.y + 0.012, size.z + 0.015), position + Vector3(0.0, 0.008, 0.0), Color(0.88, 0.77, 0.56))
    _box("CartonLabel", Vector3(size.x * 0.42, size.y * 0.40, 0.018), position + Vector3(0.0, 0.0, -size.z * 0.51), Color(0.90, 0.92, 0.89))


func _box(name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    return _box_into(self, name, size, position, color)


func _box_into(parent: Node, name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.48
    material.metallic = 0.05 if color.b > color.r else 0.0
    instance.material_override = material
    parent.add_child(instance)
    return instance


func _emissive_box(name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    return _emissive_box_into(self, name, size, position, color, energy)


func _emissive_box_into(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.roughness = 0.28
    instance.material_override = material
    parent.add_child(instance)
    return instance
