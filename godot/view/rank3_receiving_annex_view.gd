extends Node3D
class_name Rank3ReceivingAnnexView

const STEEL := Color(0.055, 0.11, 0.15)
const STEEL_LIGHT := Color(0.16, 0.23, 0.27)
const CYAN := Color(0.18, 0.72, 0.96)
const MINT := Color(0.27, 0.92, 0.68)
const AMBER := Color(1.0, 0.68, 0.18)
const CONCRETE := Color(0.13, 0.18, 0.21)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _visual_root: Node3D
var _last_signature := ""


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    _visual_root = Node3D.new()
    _visual_root.name = "Rank3Expansion"
    add_child(_visual_root)
    _rebuild_if_needed(true)


func _process(_delta: float) -> void:
    _rebuild_if_needed(false)


func _rebuild_if_needed(force: bool) -> void:
    if sim == null or _visual_root == null:
        return

    var annex_owned := false
    if sim.has_method("receiving_annex_info"):
        annex_owned = bool(sim.get("receiving_annex_unlocked"))
    var signature := "%d|%s" % [int(sim.facility_rank), str(annex_owned)]
    if not force and signature == _last_signature:
        return
    _last_signature = signature

    for child in _visual_root.get_children():
        child.queue_free()

    if sim.facility_rank < 3:
        return

    _build_fulfillment_center_mark()
    if annex_owned:
        _build_receiving_annex()


func _build_fulfillment_center_mark() -> void:
    var root := _group("Rank3_FulfillmentCenterMark")
    _box(root, "Rank3Apron", Vector3(3.6, 0.055, 0.72), Vector3(-5.25, 0.01, 4.72), Color(0.075, 0.20, 0.25))
    _box(root, "Rank3Stripe", Vector3(3.3, 0.026, 0.10), Vector3(-5.25, 0.05, 4.44), CYAN)
    _box(root, "Rank3PostL", Vector3(0.11, 1.45, 0.11), Vector3(-6.75, 0.72, 4.55), STEEL)
    _box(root, "Rank3PostR", Vector3(0.11, 1.45, 0.11), Vector3(-3.75, 0.72, 4.55), STEEL)
    _box(root, "Rank3Header", Vector3(3.12, 0.16, 0.16), Vector3(-5.25, 1.42, 4.55), CYAN)
    _status_light(root, Vector3(-5.25, 1.57, 4.47), MINT)


func _build_receiving_annex() -> void:
    var root := _group("Rank3_ReceivingAnnex")
    _box(root, "AnnexFloor", Vector3(4.15, 0.16, 2.85), Vector3(-5.25, -0.02, 6.10), CONCRETE)
    _box(root, "AnnexSafetyEdge", Vector3(4.10, 0.06, 0.10), Vector3(-5.25, 0.08, 7.47), AMBER)

    for lane in 3:
        var x := -6.45 + float(lane) * 1.20
        _box(root, "AnnexLane", Vector3(0.07, 0.025, 2.20), Vector3(x, 0.08, 6.05), CYAN)

    for x in [-7.05, -3.45]:
        _box(root, "AnnexCanopyPost", Vector3(0.14, 2.20, 0.14), Vector3(x, 1.10, 5.55), STEEL)
        _box(root, "AnnexCanopyPost", Vector3(0.14, 2.20, 0.14), Vector3(x, 1.10, 7.05), STEEL)
    _box(root, "AnnexRoof", Vector3(3.90, 0.16, 1.80), Vector3(-5.25, 2.22, 6.30), STEEL_LIGHT)
    _box(root, "AnnexRoofAccent", Vector3(3.60, 0.08, 0.10), Vector3(-5.25, 2.13, 5.43), CYAN)

    _pallet(root, Vector3(-6.35, 0.17, 5.65))
    _pallet(root, Vector3(-5.15, 0.17, 6.25))
    _pallet(root, Vector3(-4.05, 0.17, 5.75))
    _status_light(root, Vector3(-6.45, 1.65, 5.38), MINT)
    _status_light(root, Vector3(-4.05, 1.65, 5.38), MINT)


func _group(group_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = group_name
    _visual_root.add_child(root)
    return root


func _pallet(parent: Node3D, position: Vector3) -> void:
    _box(parent, "AnnexPallet", Vector3(0.78, 0.10, 0.58), position, Color(0.42, 0.24, 0.10))
    _box(parent, "AnnexCargo", Vector3(0.60, 0.50, 0.44), position + Vector3(0.0, 0.30, 0.0), AMBER)


func _status_light(parent: Node3D, position: Vector3, color: Color) -> void:
    var light_mesh := _box(parent, "StatusLight", Vector3(0.18, 0.18, 0.08), position, color)
    var material := light_mesh.material_override as StandardMaterial3D
    if material != null:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.5


func _box(parent: Node, node_name: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.54
    instance.material_override = material
    parent.add_child(instance)
    return instance
