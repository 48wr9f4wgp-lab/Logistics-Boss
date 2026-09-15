extends Node3D
class_name Rank2FacilityView

const STEEL := Color(0.055, 0.11, 0.15)
const STEEL_LIGHT := Color(0.16, 0.23, 0.27)
const CYAN := Color(0.18, 0.72, 0.96)
const MINT := Color(0.27, 0.92, 0.68)
const ORANGE := Color(0.95, 0.48, 0.08)
const AMBER := Color(1.0, 0.68, 0.18)
const BLUE_PAD := Color(0.10, 0.31, 0.46)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _visual_root: Node3D
var _last_signature := ""


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    _visual_root = Node3D.new()
    _visual_root.name = "Rank2Facilities"
    add_child(_visual_root)
    _rebuild_if_needed(true)


func _process(_delta: float) -> void:
    _rebuild_if_needed(false)


func _rebuild_if_needed(force: bool) -> void:
    if sim == null or _visual_root == null:
        return

    var signature := _facility_signature()
    if not force and signature == _last_signature:
        return
    _last_signature = signature

    for child in _visual_root.get_children():
        child.queue_free()

    if sim.facility_rank < 2:
        return

    if bool(sim.facilities.get("double_dock", false)):
        _build_double_dock()
    elif bool(sim.facilities.get("buffer_yard", false)):
        _build_buffer_yard()

    if bool(sim.facilities.get("fast_pick_rack", false)):
        _build_fast_pick_rack()
    elif bool(sim.facilities.get("high_density_rack", false)):
        _build_high_density_rack()

    if bool(sim.facilities.get("parallel_pack", false)):
        _build_parallel_pack()
    elif bool(sim.facilities.get("fast_pack_cell", false)):
        _build_fast_pack_cell()


func _facility_signature() -> String:
    if sim == null:
        return ""
    return "%d|%s|%s|%s" % [
        sim.facility_rank,
        sim.selected_facility_for_group("intake"),
        sim.selected_facility_for_group("storage"),
        sim.selected_facility_for_group("packing"),
    ]


func _build_double_dock() -> void:
    var root := _group("Rank2Facility_DoubleDock")
    _box(root, "Pad", Vector3(2.45, 0.07, 1.55), Vector3(-6.25, 0.02, 0.15), BLUE_PAD)
    _box(root, "DockRailL", Vector3(0.10, 0.12, 1.45), Vector3(-7.25, 0.14, 0.15), CYAN)
    _box(root, "DockRailR", Vector3(0.10, 0.12, 1.45), Vector3(-5.25, 0.14, 0.15), CYAN)
    _box(root, "DockHeader", Vector3(2.10, 0.16, 0.14), Vector3(-6.25, 1.55, -0.55), CYAN)
    _box(root, "DockPostL", Vector3(0.14, 1.65, 0.14), Vector3(-7.20, 0.80, -0.55), STEEL)
    _box(root, "DockPostR", Vector3(0.14, 1.65, 0.14), Vector3(-5.30, 0.80, -0.55), STEEL)
    _status_light(root, Vector3(-6.25, 1.58, -0.64), MINT)


func _build_buffer_yard() -> void:
    var root := _group("Rank2Facility_BufferYard")
    _box(root, "BufferPad", Vector3(3.35, 0.06, 2.05), Vector3(-5.55, 0.01, 0.65), Color(0.10, 0.27, 0.34))
    for lane in 3:
        _box(root, "BufferLane", Vector3(0.055, 0.025, 1.65), Vector3(-6.55 + float(lane) * 1.0, 0.06, 0.65), CYAN)
    for pallet_index in 4:
        var x := -6.65 + float(pallet_index % 2) * 1.45
        var z := 0.20 + float(pallet_index / 2) * 0.92
        _pallet(root, Vector3(x, 0.16, z), AMBER)


func _build_fast_pick_rack() -> void:
    var root := _group("Rank2Facility_FastPickRack")
    _box(root, "PickZone", Vector3(2.55, 0.05, 1.25), Vector3(0.15, 0.03, -2.65), Color(0.07, 0.25, 0.31))
    for bay in 2:
        var x := -0.35 + float(bay) * 1.05
        for px in [x - 0.42, x + 0.42]:
            _box(root, "QuickPost", Vector3(0.09, 1.75, 0.09), Vector3(px, 0.90, -2.65), STEEL)
        for y in [0.42, 0.92, 1.42]:
            _box(root, "QuickShelf", Vector3(0.92, 0.075, 0.72), Vector3(x, y, -2.65), STEEL_LIGHT)
            _box(root, "QuickBeam", Vector3(0.98, 0.075, 0.06), Vector3(x, y + 0.04, -2.98), CYAN)


func _build_high_density_rack() -> void:
    var root := _group("Rank2Facility_HighDensityRack")
    for bay in 2:
        var z := -2.75 + float(bay) * 1.05
        for px in [-4.55, -3.25]:
            _box(root, "DensePost", Vector3(0.11, 3.05, 0.11), Vector3(px, 1.53, z), STEEL)
        for y in [0.48, 1.18, 1.88, 2.58]:
            _box(root, "DenseShelf", Vector3(1.42, 0.09, 0.80), Vector3(-3.90, y, z), STEEL_LIGHT)
            _box(root, "DenseBeam", Vector3(1.48, 0.09, 0.07), Vector3(-3.90, y + 0.04, z - 0.37), AMBER)


func _build_parallel_pack() -> void:
    var root := _group("Rank2Facility_ParallelPack")
    _box(root, "PackPad2", Vector3(2.35, 0.05, 0.95), Vector3(2.35, 0.03, 1.25), Color(0.33, 0.20, 0.07))
    _box(root, "PackTable2", Vector3(2.05, 0.30, 0.82), Vector3(2.35, 0.72, 1.25), STEEL_LIGHT)
    _box(root, "PackRail2", Vector3(2.20, 0.10, 0.08), Vector3(2.35, 0.98, 0.84), ORANGE)
    _status_light(root, Vector3(1.55, 1.08, 0.82), CYAN)
    _status_light(root, Vector3(3.15, 1.08, 0.82), CYAN)


func _build_fast_pack_cell() -> void:
    var root := _group("Rank2Facility_FastPackCell")
    _box(root, "CellPad", Vector3(1.65, 0.05, 1.35), Vector3(2.45, 0.03, 1.20), Color(0.19, 0.23, 0.12))
    _box(root, "CellBody", Vector3(1.30, 0.92, 0.92), Vector3(2.45, 0.58, 1.20), STEEL_LIGHT)
    _box(root, "CellOpening", Vector3(0.86, 0.50, 0.06), Vector3(2.45, 0.62, 0.72), Color(0.03, 0.08, 0.10))
    _box(root, "CellAccent", Vector3(1.38, 0.09, 0.08), Vector3(2.45, 1.05, 0.75), ORANGE)
    _status_light(root, Vector3(2.45, 1.22, 0.75), MINT)


func _group(group_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = group_name
    _visual_root.add_child(root)
    return root


func _pallet(parent: Node3D, position: Vector3, cargo_color: Color) -> void:
    _box(parent, "Pallet", Vector3(0.82, 0.10, 0.62), position, Color(0.42, 0.24, 0.10))
    _box(parent, "BufferCargo", Vector3(0.62, 0.46, 0.48), position + Vector3(0.0, 0.28, 0.0), cargo_color)


func _status_light(parent: Node3D, position: Vector3, color: Color) -> void:
    var light_mesh := _box(parent, "StatusLight", Vector3(0.18, 0.18, 0.08), position, color)
    var material := light_mesh.material_override as StandardMaterial3D
    if material != null:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.4


func _box(parent: Node, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.55
    instance.material_override = material
    parent.add_child(instance)
    return instance
