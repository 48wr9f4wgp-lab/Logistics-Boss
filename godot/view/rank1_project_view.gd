extends Node3D
class_name Rank1ProjectView

const STEEL := Color(0.055, 0.11, 0.15)
const STEEL_LIGHT := Color(0.16, 0.23, 0.27)
const CYAN := Color(0.18, 0.72, 0.96)
const ORANGE := Color(0.95, 0.48, 0.08)
const STORAGE_PAD := Color(0.07, 0.22, 0.29)
const PACK_PAD := Color(0.30, 0.19, 0.07)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _visual_root: Node3D
var _last_signature := ""


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    _visual_root = Node3D.new()
    _visual_root.name = "Rank1V2Projects"
    add_child(_visual_root)
    _rebuild_if_needed(true)


func _process(_delta: float) -> void:
    _rebuild_if_needed(false)


func _rebuild_if_needed(force: bool) -> void:
    if sim == null or _visual_root == null:
        return

    var signature := _signature()
    if not force and signature == _last_signature:
        return
    _last_signature = signature

    for child in _visual_root.get_children():
        child.queue_free()

    if _project_owned("rack_wing"):
        _build_rack_wing()
    if _project_owned("second_packing_bench"):
        _build_second_packing_bench()


func _signature() -> String:
    return "%s|%s|%d" % [
        str(_project_owned("rack_wing")),
        str(_project_owned("second_packing_bench")),
        sim.facility_rank if sim != null else 0,
    ]


func _project_owned(kind: String) -> bool:
    if sim == null or not sim.has_method("rank1_project_owned"):
        return false
    return bool(sim.call("rank1_project_owned", StringName(kind)))


func _build_rack_wing() -> void:
    var root := _group("Rank1Project_RackWing")
    _box(root, "RackWingPad", Vector3(1.55, 0.045, 3.35), Vector3(-3.92, 0.025, -1.05), STORAGE_PAD)
    _box(root, "RackWingStripe", Vector3(1.40, 0.025, 0.08), Vector3(-3.92, 0.055, 0.54), CYAN)

    for bay in 3:
        var z := -2.20 + float(bay) * 1.05
        for x in [-4.42, -3.42]:
            _box(root, "RackWingPost", Vector3(0.10, 2.65, 0.10), Vector3(x, 1.33, z), STEEL)
        for y in [0.48, 1.12, 1.76, 2.40]:
            _box(root, "RackWingShelf", Vector3(1.10, 0.085, 0.72), Vector3(-3.92, y, z), STEEL_LIGHT)
            _box(root, "RackWingBeam", Vector3(1.16, 0.075, 0.06), Vector3(-3.92, y + 0.04, z - 0.33), ORANGE)

    var beacon := _box(root, "RackWingBeacon", Vector3(0.16, 0.16, 0.08), Vector3(-3.92, 2.82, 0.50), CYAN)
    _make_emissive(beacon, CYAN, 1.6)


func _build_second_packing_bench() -> void:
    var root := _group("Rank1Project_SecondPackingBench")
    _box(root, "SecondPackPad", Vector3(2.05, 0.05, 1.10), Vector3(3.12, 0.03, 1.28), PACK_PAD)
    _box(root, "SecondPackBench", Vector3(1.75, 0.28, 0.80), Vector3(3.12, 0.70, 1.28), STEEL_LIGHT)
    _box(root, "SecondPackRail", Vector3(1.88, 0.09, 0.08), Vector3(3.12, 0.95, 0.90), ORANGE)
    _box(root, "SecondPackScreenStand", Vector3(0.08, 0.58, 0.08), Vector3(3.70, 1.16, 1.30), STEEL)
    var screen := _box(root, "SecondPackScreen", Vector3(0.50, 0.30, 0.055), Vector3(3.70, 1.44, 1.30), CYAN)
    _make_emissive(screen, CYAN, 1.45)


func _group(group_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = group_name
    _visual_root.add_child(root)
    return root


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


func _make_emissive(instance: MeshInstance3D, color: Color, energy: float) -> void:
    var material := instance.material_override as StandardMaterial3D
    if material == null:
        return
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
