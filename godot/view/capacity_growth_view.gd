extends Node3D
class_name CapacityGrowthView

const FONT = preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const CELL_POS := [Vector3(0.0,0,4.5), Vector3(2.3,0,4.5), Vector3(4.6,0,4.5)]
const LANE_POS := [Vector3(7.35,0,-1.0), Vector3(7.35,0,1.6)]
const STEEL := Color(0.10,0.19,0.23)
const AMBER := Color(0.96,0.56,0.12)
const CYAN := Color(0.25,0.8,0.96)
var sim: FlotraV2Sim
var units: Array[Node3D] = []
var lanes: Array[Node3D] = []

func bind(next_sim: FlotraV2Sim) -> void:
    sim = next_sim

func _process(_delta: float) -> void:
    if sim == null:
        return
    while units.size() < sim.packing_cells:
        units.append(_build_cell(units.size()))
    while lanes.size() < sim.dispatch_lanes:
        lanes.append(_build_lane(lanes.size()))
    for i in units.size():
        var active := i < sim._cell_jobs.size() and sim._cell_jobs[i] > 0.0
        var progress := 1.0 - sim._cell_jobs[i] / sim.CELL_SECONDS if active else 0.0
        var root := units[i]
        var cargo := root.get_node("ActualCargo") as Node3D
        cargo.visible = active
        cargo.position.z = -0.5 + progress
        (root.get_node("Press") as Node3D).position.y = 1.05 + (absf(sin(progress * PI)) * 0.38 if active else 0.4)
        var label := root.get_node("UnitLabel") as Label3D
        label.text = "梱包%d %s" % [i + 1, "処理中" if active else "待機"]
    for i in lanes.size():
        var root := lanes[i]
        var job: Dictionary = sim._lane_jobs[i]
        var progress := 1.0 - float(job["remaining"]) / sim.LANE_SECONDS
        for j in 2:
            var cargo := root.get_node("ActualCargo%d" % j) as Node3D
            cargo.visible = int(job["cargo"]) > j
            cargo.position.x = -0.7 + progress * 1.35
        (root.get_node("UnitLabel") as Label3D).text = "出荷%d %s" % [i + 1, "搬送中" if int(job["cargo"]) > 0 else "待機"]

func _build_cell(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "PackingCell%d" % (index+1)
    root.position = CELL_POS[index]
    add_child(root)
    box(root,"Pad",Vector3(2.0,0.06,2.05),Vector3(0,0,0),STEEL)
    box(root,"Belt",Vector3(1.6,0.24,1.5),Vector3(0,0.65,0),STEEL)
    for x in [-0.8,0.8]:
        box(root,"Upright",Vector3(0.10,1.55,0.12),Vector3(x,0.8,0.1),AMBER)
        box(root,"Rail",Vector3(0.10,0.12,1.8),Vector3(x,0.85,0),CYAN)
    box(root,"Crossbar",Vector3(1.7,0.12,0.18),Vector3(0,1.57,0.1),CYAN)
    box(root,"Press",Vector3(1.1,0.13,0.60),Vector3(0,1.4,0.1),AMBER)
    box(root,"ActualCargo",Vector3(0.56,0.40,0.5),Vector3(0,1.0,0),Color(0.85,0.60,0.3))
    tag(root,"梱包%d" % (index+1),Vector3(0,0.45,1.05))
    _zone_target(root, "packing", Vector3(2.0,1.8,2.05))
    return root

func _build_lane(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "AutoDispatch%d" % (index+1)
    root.position = LANE_POS[index]
    add_child(root)
    box(root,"Pad",Vector3(2.45,0.06,2.0),Vector3.ZERO,STEEL)
    box(root,"PoweredRollers",Vector3(2.05,0.24,1.3),Vector3(0,0.65,0),STEEL)
    for z in [-0.65,0.65]:
        box(root,"Rail",Vector3(2.2,0.14,0.08),Vector3(0,0.85,z),CYAN)
    box(root,"DockFrame",Vector3(0.16,1.4,1.35),Vector3(1.0,0.8,0),AMBER)
    for j in 2:
        box(root,"ActualCargo%d" % j,Vector3(0.46,0.40,0.46),Vector3(0,1.0,-0.27 + j*0.54),Color(0.85,0.60,0.3))
    tag(root,"出荷%d" % (index+1),Vector3(0,0.45,0.98))
    _zone_target(root, "shipping", Vector3(2.45,1.8,2.0))
    return root

static func box(parent: Node, title: String, dimensions: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    node.position = position
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    node.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.6
    node.material_override = material
    parent.add_child(node)
    return node

static func tag(parent: Node, text: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.name = "UnitLabel"
    label.text = text
    label.position = position
    label.font = FONT
    label.font_size = 38
    label.pixel_size = 0.010
    label.outline_size = 8
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)

static func _zone_target(parent: Node3D, zone_key: String, size: Vector3) -> void:
    # New machinery remains a warehouse interaction surface, not dead scenery.
    var area := Area3D.new()
    area.name = "EquipmentTapTarget"
    area.collision_layer = WarehouseZoneInteractionView.ZONE_COLLISION_LAYER
    area.collision_mask = 0
    area.set_meta("zone_key", zone_key)
    area.position.y = size.y * 0.5
    var shape := CollisionShape3D.new()
    var bounds := BoxShape3D.new()
    bounds.size = size
    shape.shape = bounds
    area.add_child(shape)
    parent.add_child(area)
