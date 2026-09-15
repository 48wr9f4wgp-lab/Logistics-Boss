extends Node3D
class_name WarehouseVisualPass2

const NAVY := Color(0.018, 0.038, 0.052)
const STEEL := Color(0.055, 0.095, 0.125)
const STEEL_MID := Color(0.10, 0.16, 0.19)
const ORANGE := Color(0.96, 0.48, 0.08)
const CYAN := Color(0.16, 0.78, 1.0)
const MINT := Color(0.24, 0.94, 0.68)
const WARM := Color(1.0, 0.69, 0.34)
const CONCRETE_DARK := Color(0.105, 0.135, 0.155)

var warehouse_view: WarehouseView


func bind_view(view: WarehouseView) -> void:
    warehouse_view = view
    warehouse_view._camera_distance = 16.15
    warehouse_view._orbit_pitch = -0.64
    warehouse_view._orbit_yaw = -0.80


func _ready() -> void:
    _build_floor_density()
    _build_ceiling_structure()
    _build_storage_detail()
    _build_pack_cell_detail()
    _build_dock_detail()
    _detail_existing_vehicles()
    _build_light_rhythm()
    call_deferred("_tune_camera")


func _tune_camera() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        camera.fov = 31.5


func _build_floor_density() -> void:
    # Break up the large empty slab into operational zones without changing gameplay paths.
    _box("CentralAisle", Vector3(3.55, 0.018, 8.4), Vector3(0.55, 0.018, 0.30), Color(0.135, 0.17, 0.19))
    _box("InboundZone", Vector3(3.05, 0.020, 3.35), Vector3(-5.0, 0.020, 2.0), Color(0.105, 0.17, 0.205))
    _box("PackZone", Vector3(3.65, 0.020, 3.25), Vector3(2.55, 0.020, -0.15), Color(0.22, 0.15, 0.065))
    _box("OutboundZone", Vector3(3.1, 0.020, 3.15), Vector3(5.15, 0.020, 2.0), Color(0.07, 0.19, 0.16))

    for z in [-2.9, -1.7, -0.5, 0.7, 1.9, 3.1]:
        _box("AisleMarker", Vector3(2.8, 0.025, 0.045), Vector3(0.45, 0.032, z), Color(0.48, 0.55, 0.57))

    # Safety hatching near busy cells.
    for i in 8:
        var x := 1.05 + float(i) * 0.36
        var stripe := _box("SafetyStripe", Vector3(0.13, 0.028, 1.0), Vector3(x, 0.036, 1.34), ORANGE)
        stripe.rotation_degrees.y = 18.0

    for i in 6:
        var z := 0.70 + float(i) * 0.36
        _box("DockStripe", Vector3(1.35, 0.028, 0.10), Vector3(5.15, 0.036, z), Color(0.86, 0.72, 0.22))


func _build_ceiling_structure() -> void:
    # Canonical mobile presentation is an open-top cutaway. Do not generate
    # trusses, roof lights or utility bars above the playable floor: even when
    # hidden later they can reappear through lifecycle/cached-preview edge cases
    # and they destroy parcel/worker readability in portrait framing.
    for x in [-6.9, -4.55, -2.2, 0.15, 2.5, 4.85, 7.0]:
        _box("WallColumn", Vector3(0.16, 4.0, 0.20), Vector3(x, 2.0, -4.72), STEEL)


func _build_storage_detail() -> void:
    # End guards and pallet staging visually anchor the rack block.
    for z in [-3.15, 2.45]:
        _box("RackGuard", Vector3(3.7, 0.18, 0.16), Vector3(-1.55, 0.28, z), ORANGE)
        for x in [-3.25, 0.15]:
            _box("GuardPost", Vector3(0.18, 0.65, 0.18), Vector3(x, 0.34, z), ORANGE)

    _pallet_stack(Vector3(-4.55, 0.05, -1.65), 3, 2)
    _pallet_stack(Vector3(-5.55, 0.05, 0.20), 2, 2)
    _pallet_stack(Vector3(-3.95, 0.05, 3.10), 2, 1)

    # Tall endcap board makes STORAGE a visual focal point.
    _box("StorageEndcap", Vector3(3.55, 0.58, 0.18), Vector3(-1.55, 3.45, -3.92), NAVY)
    _box_emissive("StorageAccent", Vector3(2.85, 0.06, 0.04), Vector3(-1.55, 3.47, -3.80), CYAN, 2.0)


func _build_pack_cell_detail() -> void:
    # Secondary workstation and guarded automation spine add hierarchy around the packing cell.
    _box("PackSideTable", Vector3(1.35, 0.25, 0.74), Vector3(3.65, 0.72, -1.48), STEEL_MID)
    _box("PackSideScreen", Vector3(0.45, 0.40, 0.08), Vector3(3.65, 1.25, -1.72), NAVY)
    _box_emissive("PackSideGlow", Vector3(0.34, 0.27, 0.025), Vector3(3.65, 1.25, -1.77), CYAN, 2.25)

    for x in [1.15, 3.95]:
        _box("GuardPost", Vector3(0.11, 0.95, 0.11), Vector3(x, 0.49, 1.00), ORANGE)
    _box("GuardRail", Vector3(2.9, 0.10, 0.10), Vector3(2.55, 0.85, 1.00), ORANGE)

    # Two parcel stacks make the pack/outbound handoff feel active.
    _parcel_stack(Vector3(1.15, 0.20, -1.25), 3, 2, Color(0.79, 0.55, 0.29))
    _parcel_stack(Vector3(4.10, 0.20, 0.10), 2, 2, Color(0.83, 0.61, 0.32))


func _build_dock_detail() -> void:
    # Dock bumpers and a canopy make the far side feel built-in rather than pasted onto a wall.
    for x in [-5.25, 5.20]:
        _box("DockCanopy", Vector3(2.8, 0.22, 1.45), Vector3(x, 3.28, -4.14), STEEL_MID)
        _box("DockBumperL", Vector3(0.20, 0.58, 0.22), Vector3(x - 0.78, 0.42, -4.24), Color(0.035, 0.045, 0.05))
        _box("DockBumperR", Vector3(0.20, 0.58, 0.22), Vector3(x + 0.78, 0.42, -4.24), Color(0.035, 0.045, 0.05))

    _box_emissive("InboundDockGlow", Vector3(1.55, 0.05, 0.04), Vector3(-5.25, 2.82, -4.02), CYAN, 2.0)
    _box_emissive("OutboundDockGlow", Vector3(1.55, 0.05, 0.04), Vector3(5.20, 2.82, -4.02), MINT, 2.0)

    # Road apron and wheel stop sell the truck bay in the foreground/right edge.
    _box("TruckApron", Vector3(4.15, 0.035, 2.2), Vector3(5.55, 0.01, 4.10), CONCRETE_DARK)
    _box("WheelStop", Vector3(2.8, 0.20, 0.22), Vector3(5.65, 0.13, 3.35), ORANGE)


func _detail_existing_vehicles() -> void:
    # Forklift: wheels, counterweight and blue work lamp.
    var forklift := warehouse_view.get_node_or_null("Forklift") if warehouse_view != null else null
    if forklift != null:
        for p in [Vector3(-0.46, 0.23, -0.32), Vector3(0.46, 0.23, -0.32), Vector3(-0.46, 0.23, 0.35), Vector3(0.46, 0.23, 0.35)]:
            _wheel(forklift, p, 0.22, 0.16, Vector3(90.0, 0.0, 0.0))
        _box_into(forklift, "Counterweight", Vector3(0.86, 0.48, 0.35), Vector3(0.0, 0.42, 0.53), ORANGE)
        _box_emissive_into(forklift, "ForkWorkLamp", Vector3(0.42, 0.09, 0.05), Vector3(0.0, 1.20, -0.42), CYAN, 2.4)

    # Truck: wheels, roof marker and side stripe. These are visual detail only; no simulated motion is introduced.
    for x in [4.70, 5.75, 6.65]:
        for z in [3.55, 4.95]:
            _wheel(self, Vector3(x, 0.42, z), 0.31, 0.20, Vector3(90.0, 0.0, 0.0))
    _box("TruckStripe", Vector3(2.05, 0.12, 0.04), Vector3(6.15, 1.08, 3.46), CYAN)
    _box_emissive("TruckMarker", Vector3(0.56, 0.06, 0.05), Vector3(4.55, 1.42, 3.48), WARM, 1.8)

    # AGV outline makes the existing unit legible at the chosen camera scale.
    _box_emissive("AGVEdgeA", Vector3(0.86, 0.035, 0.035), Vector3(-0.10, 0.38, 2.64), CYAN, 2.5)
    _box("AGVBumper", Vector3(1.10, 0.09, 0.08), Vector3(-0.10, 0.18, 2.62), ORANGE)


func _build_light_rhythm() -> void:
    # Small practicals add contrast but avoid turning the scene into a neon arcade.
    _point_light(Vector3(-4.8, 3.0, -1.1), WARM, 3.7, 1.15)
    _point_light(Vector3(2.6, 3.0, 0.2), WARM, 4.0, 1.25)
    _point_light(Vector3(5.0, 2.8, 2.1), Color(0.48, 0.90, 0.76), 3.7, 0.75)


func _point_light(position: Vector3, color: Color, light_range: float, energy: float) -> void:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.omni_range = light_range
    light.light_energy = energy
    light.shadow_enabled = false
    add_child(light)


func _pallet_stack(origin: Vector3, columns: int, rows: int) -> void:
    _box("PalletBase", Vector3(maxf(1.0, float(columns) * 0.52), 0.12, maxf(0.75, float(rows) * 0.48)), origin + Vector3(0.0, 0.08, 0.0), Color(0.44, 0.27, 0.10))
    for r in rows:
        for c in columns:
            var x := origin.x - float(columns - 1) * 0.25 + float(c) * 0.50
            var z := origin.z - float(rows - 1) * 0.23 + float(r) * 0.46
            _box("PalletCarton", Vector3(0.43, 0.48, 0.40), Vector3(x, origin.y + 0.38, z), Color(0.72, 0.48, 0.24))


func _parcel_stack(origin: Vector3, columns: int, rows: int, color: Color) -> void:
    for r in rows:
        for c in columns:
            var x := origin.x - float(columns - 1) * 0.23 + float(c) * 0.46
            var y := origin.y + float(r) * 0.36
            _box("ParcelStack", Vector3(0.40, 0.31, 0.40), Vector3(x, y, origin.z), color)


func _wheel(parent: Node, position: Vector3, radius: float, width: float, rotation_degrees: Vector3) -> void:
    var wheel := MeshInstance3D.new()
    wheel.name = "Wheel"
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = width
    mesh.radial_segments = 14
    wheel.mesh = mesh
    wheel.position = position
    wheel.rotation_degrees = rotation_degrees
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.018, 0.022, 0.025)
    material.roughness = 0.92
    wheel.material_override = material
    parent.add_child(wheel)


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
    material.roughness = 0.54
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance


func _box_emissive(name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    return _box_emissive_into(self, name, size, position, color, energy)


func _box_emissive_into(parent: Node, name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    material.roughness = 0.35
    mesh_instance.material_override = material
    parent.add_child(mesh_instance)
    return mesh_instance