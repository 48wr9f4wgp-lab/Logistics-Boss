extends Node3D
class_name GrowthAutomationView

const STEEL := Color(0.08, 0.14, 0.18)
const CYAN := Color(0.18, 0.72, 0.96)
const AMBER := Color(0.95, 0.48, 0.08)
const PARCEL := Color(0.78, 0.52, 0.25)
const BELT_POINTS := [Vector3(-0.35, 0.86, 1.85), Vector3(0.75, 0.86, 1.85), Vector3(0.75, 0.86, -0.05), Vector3(1.55, 0.86, -0.05)]
const FORK_POINTS := [Vector3(-5.25, 0, 2.35), Vector3(-4.65, 0, 3.35), Vector3(-1.75, 0, 3.35), Vector3(-1.75, 0, -0.15)]
var view: WarehouseView
var sim: FlotraV2Sim
var _fork: Node3D
var _cargo: Array[MeshInstance3D] = []
var _belt: Node3D
var _parcels: Array[MeshInstance3D] = []
var _last_rank := -1

func bind(next_view: WarehouseView, next_sim: FlotraV2Sim) -> void:
    view = next_view
    sim = next_sim
    sim.event_emitted.connect(_on_event)
    _build_belt()
    _sync_floor()

func _process(_delta: float) -> void:
    if sim == null:
        return
    _sync_floor()
    var state := sim.growth_automation_state()
    if bool(state["extra_owned"]) and _fork == null:
        _build_extra_fork()
    if _fork != null:
        _fork.visible = bool(state["extra_owned"])
        var active := bool(state["extra_active"])
        var progress := float(state["extra_progress"])
        var leg := progress * 2.0 if progress < 0.5 else (1.0 - progress) * 2.0
        _fork.position = _path_point(FORK_POINTS, leg) if active else Vector3(-5.8, 0.0, 3.35)
        if active:
            var next := _path_point(FORK_POINTS, clampf(leg + (0.02 if progress < 0.5 else -0.02), 0, 1))
            var direction := next - _fork.position
            if direction.length_squared() > 0.0001:
                _fork.rotation.y = atan2(-direction.x, -direction.z)
        for i in _cargo.size():
            _cargo[i].visible = active and i < int(state["extra_cargo"])
    _belt.visible = bool(state["conveyor_owned"])
    var jobs: Array = state["conveyor_jobs"]
    for i in _parcels.size():
        _parcels[i].visible = _belt.visible and i < jobs.size()
        if i < jobs.size():
            var progress := 1.0 - float(jobs[i]) / float(state["conveyor_duration"])
            _parcels[i].position = _path_point(BELT_POINTS, progress) + Vector3(0, 0.15, 0)

func _sync_floor() -> void:
    if view == null or sim == null or _last_rank == sim.facility_rank:
        return
    _last_rank = sim.facility_rank
    var floor_mesh := view.get_node_or_null("Floor") as MeshInstance3D
    if floor_mesh != null and floor_mesh.mesh is BoxMesh:
        var floor_box := floor_mesh.mesh.duplicate() as BoxMesh
        floor_box.size = Vector3(15.8, 0.24, 11.8) if sim.facility_rank == 1 else Vector3(19.0, 0.24, 13.4)
        floor_mesh.mesh = floor_box
    if sim.facility_rank >= 2 and not has_node("ExpansionApron"):
        var apron := Node3D.new()
        apron.name = "ExpansionApron"
        add_child(apron)
        # Permanent working-floor expansion, not a second decorative warehouse.
        _box(apron, "LeftEdge", Vector3(0.10, 0.035, 12.8), Vector3(-9.15, 0.0, 0.7), AMBER)
        _box(apron, "RightEdge", Vector3(0.10, 0.035, 12.8), Vector3(9.15, 0.0, 0.7), AMBER)
        _box(apron, "FrontEdge", Vector3(18.4, 0.035, 0.10), Vector3(0, 0.0, 7.1), CYAN)
        for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
            _box(apron, "BayMark", Vector3(0.08, 0.035, 1.2), Vector3(x, 0.0, 6.4), AMBER)

func _on_event(event: Dictionary) -> void:
    if String(event.get("type", "")) not in ["rank1_project_purchased", "growth_automation_purchased", "warehouse_expansion_purchased", "facility_purchased", "facility_renovated"]:
        return
    if view != null and view.has_method("focus_investment"):
        view.call("focus_investment", String(event.get("kind", "")))

func _build_extra_fork() -> void:
    var original := view.get_node_or_null("Forklift") as Node3D
    if original == null:
        return
    _fork = original.duplicate() as Node3D
    _fork.name = "AdditionalWorkingForklift"
    var old_cargo := _fork.get_node_or_null("AutomationCargo")
    if old_cargo != null:
        _fork.remove_child(old_cargo)
        old_cargo.free()
    add_child(_fork)
    _fork.scale = Vector3.ONE * 0.90
    for i in 2:
        _cargo.append(_box(_fork, "ActualCargo%d" % i, Vector3(0.35, 0.38, 0.48), Vector3(-0.20 + i * 0.40, 0.52, -0.90), PARCEL))

func _build_belt() -> void:
    _belt = Node3D.new()
    _belt.name = "WorkingTransferConveyor"
    add_child(_belt)
    for i in BELT_POINTS.size() - 1:
        var a: Vector3 = BELT_POINTS[i]
        var b: Vector3 = BELT_POINTS[i + 1]
        var length := a.distance_to(b)
        var segment := Node3D.new()
        _belt.add_child(segment)
        segment.position = (a + b) * 0.5
        segment.rotation.y = atan2((b - a).x, (b - a).z)
        _box(segment, "Belt", Vector3(0.58, 0.14, length), Vector3.ZERO, STEEL)
        for side in [-1.0, 1.0]:
            _box(segment, "Guard", Vector3(0.055, 0.13, length), Vector3(side * 0.32, 0.10, 0), AMBER)
        for j in maxi(2, int(length / 0.28)):
            var z := -length * 0.5 + 0.12 + float(j) * 0.28
            _box(segment, "Roller", Vector3(0.47, 0.035, 0.06), Vector3(0, 0.09, z), Color(0.30, 0.40, 0.44))
        for side in [-1.0, 1.0]:
            _box(segment, "Support", Vector3(0.08, 0.75, 0.08), Vector3(side * 0.22, -0.45, 0), STEEL)
    for i in FlotraV2Sim.CONVEYOR_CAPACITY:
        var parcel := _box(_belt, "TransportedParcel%d" % i, Vector3(0.35, 0.26, 0.30), BELT_POINTS[0], PARCEL)
        parcel.visible = false
        _parcels.append(parcel)
    _belt.visible = false

static func _path_point(points: Array, fraction: float) -> Vector3:
    var length := 0.0
    for i in points.size() - 1:
        length += (points[i] as Vector3).distance_to(points[i + 1])
    var remaining := clampf(fraction, 0, 1) * length
    for i in points.size() - 1:
        var a: Vector3 = points[i]
        var b: Vector3 = points[i + 1]
        var segment := a.distance_to(b)
        if remaining <= segment:
            return a.lerp(b, remaining / maxf(segment, 0.001))
        remaining -= segment
    return points[-1]

func _box(parent: Node, title: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.65
    node.material_override = material
    parent.add_child(node)
    return node
