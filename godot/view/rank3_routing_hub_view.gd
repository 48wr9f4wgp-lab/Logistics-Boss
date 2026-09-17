extends Node3D
class_name Rank3RoutingHubView

const STEEL := Color(0.055, 0.11, 0.15)
const STEEL_LIGHT := Color(0.16, 0.23, 0.27)
const CYAN := Color(0.18, 0.72, 0.96)
const MINT := Color(0.27, 0.92, 0.68)
const AMBER := Color(1.0, 0.68, 0.18)
const CONCRETE := Color(0.12, 0.17, 0.20)
const PARCEL := Color(0.76, 0.48, 0.20)

# The portrait camera looks from the front-left. The original hub lived at z~5,
# which made the Rank 3 carrier dominate the lower-right foreground. Keep the
# routing state visible, but stage it on the right service side instead of between
# the camera and the warehouse floor.
const HUB_X := 7.10
const HUB_Z := 0.45

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _visual_root: Node3D
var _last_signature := ""


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    _visual_root = Node3D.new()
    _visual_root.name = "Rank3RoutingPresentation"
    add_child(_visual_root)
    _rebuild_if_needed(true)


func _process(_delta: float) -> void:
    _rebuild_if_needed(false)


func _rebuild_if_needed(force: bool) -> void:
    if sim == null or _visual_root == null:
        return

    var mode := "locked"
    if sim.facility_rank >= 3 and sim.has_method("routing_summary"):
        var routing: Dictionary = sim.call("routing_summary")
        mode = String(routing.get("mode", "balanced"))
    var signature := "%d|%s" % [int(sim.facility_rank), mode]
    if not force and signature == _last_signature:
        return
    _last_signature = signature

    for child in _visual_root.get_children():
        child.queue_free()

    if sim.facility_rank < 3:
        return

    var hub := _group(_visual_root, "Rank3_RoutingHub")
    _build_common_hub(hub)
    match mode:
        "express":
            _build_express(hub)
        "consolidated":
            _build_consolidated(hub)
        _:
            _build_balanced(hub)


func _build_common_hub(parent: Node3D) -> void:
    _box(parent, "RoutingApron", Vector3(4.20, 0.10, 2.45), Vector3(HUB_X, -0.03, HUB_Z), CONCRETE)
    _box(parent, "RoutingSafetyEdge", Vector3(4.05, 0.035, 0.08), Vector3(HUB_X, 0.04, HUB_Z + 1.15), AMBER)
    _box(parent, "RoutingHeaderPostL", Vector3(0.10, 1.45, 0.10), Vector3(HUB_X - 1.80, 0.72, HUB_Z - 1.00), STEEL)
    _box(parent, "RoutingHeaderPostR", Vector3(0.10, 1.45, 0.10), Vector3(HUB_X + 1.80, 0.72, HUB_Z - 1.00), STEEL)
    _box(parent, "RoutingHeader", Vector3(3.70, 0.12, 0.12), Vector3(HUB_X, 1.42, HUB_Z - 1.00), STEEL_LIGHT)


func _build_balanced(parent: Node3D) -> void:
    var root := _group(parent, "RoutingHub_Balanced")
    _box(root, "BalancedLaneL", Vector3(0.08, 0.03, 1.65), Vector3(HUB_X - 0.80, 0.045, HUB_Z - 0.05), CYAN)
    _box(root, "BalancedLaneR", Vector3(0.08, 0.03, 1.65), Vector3(HUB_X + 0.80, 0.045, HUB_Z - 0.05), MINT)
    _vehicle(root, "BalancedCarrier", Vector3(1.10, 0.58, 1.40), Vector3(HUB_X, 0.38, HUB_Z + 0.20), STEEL_LIGHT, MINT)
    _status_light(root, Vector3(HUB_X, 1.57, HUB_Z - 1.05), MINT)


func _build_express(parent: Node3D) -> void:
    var root := _group(parent, "RoutingHub_Express")
    _box(root, "ExpressLane", Vector3(0.13, 0.035, 1.82), Vector3(HUB_X, 0.05, HUB_Z - 0.02), CYAN)
    for z_offset in [-0.58, -0.11, 0.36]:
        _box(root, "ExpressArrow", Vector3(0.72, 0.04, 0.14), Vector3(HUB_X, 0.07, HUB_Z + z_offset), CYAN)
    _vehicle(root, "ExpressCarrier", Vector3(0.92, 0.50, 1.18), Vector3(HUB_X, 0.34, HUB_Z + 0.37), CYAN, AMBER)
    _status_light(root, Vector3(HUB_X, 1.57, HUB_Z - 1.05), CYAN)


func _build_consolidated(parent: Node3D) -> void:
    var root := _group(parent, "RoutingHub_Consolidated")
    _box(root, "ConsolidatedLaneL", Vector3(0.08, 0.03, 1.80), Vector3(HUB_X - 0.95, 0.045, HUB_Z - 0.03), AMBER)
    _box(root, "ConsolidatedLaneR", Vector3(0.08, 0.03, 1.80), Vector3(HUB_X + 0.95, 0.045, HUB_Z - 0.03), AMBER)
    for index in range(4):
        var x := HUB_X - 1.40 + float(index % 2) * 0.75
        var z := HUB_Z - 0.50 + float(index / 2) * 0.62
        _pallet(root, Vector3(x, 0.12, z))
    _vehicle(root, "ConsolidatedCarrier", Vector3(1.35, 0.68, 1.95), Vector3(HUB_X + 0.65, 0.43, HUB_Z + 0.13), STEEL_LIGHT, AMBER)
    _status_light(root, Vector3(HUB_X, 1.57, HUB_Z - 1.05), AMBER)


func _vehicle(parent: Node3D, prefix: String, body_size: Vector3, position: Vector3, body_color: Color, accent: Color) -> void:
    _box(parent, "%sBody" % prefix, body_size, position, body_color)
    _box(parent, "%sCab" % prefix, Vector3(body_size.x * 0.82, body_size.y * 0.82, 0.42), position + Vector3(0.0, 0.02, -body_size.z * 0.52), accent)
    _box(parent, "%sWheelL" % prefix, Vector3(0.18, 0.18, 0.34), position + Vector3(-body_size.x * 0.52, -body_size.y * 0.38, 0.32), Color(0.025, 0.03, 0.035))
    _box(parent, "%sWheelR" % prefix, Vector3(0.18, 0.18, 0.34), position + Vector3(body_size.x * 0.52, -body_size.y * 0.38, 0.32), Color(0.025, 0.03, 0.035))


func _pallet(parent: Node3D, position: Vector3) -> void:
    _box(parent, "RoutingPallet", Vector3(0.55, 0.08, 0.42), position, Color(0.38, 0.22, 0.10))
    _box(parent, "RoutingCargo", Vector3(0.44, 0.34, 0.34), position + Vector3(0.0, 0.20, 0.0), PARCEL)


func _status_light(parent: Node3D, position: Vector3, color: Color) -> void:
    var light_mesh := _box(parent, "RoutingStatusLight", Vector3(0.16, 0.16, 0.07), position, color)
    var material := light_mesh.material_override as StandardMaterial3D
    if material != null:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.6


func _group(parent: Node, group_name: String) -> Node3D:
    var root := Node3D.new()
    root.name = group_name
    parent.add_child(root)
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
    material.roughness = 0.52
    instance.material_override = material
    parent.add_child(instance)
    return instance
