extends Node3D
class_name WarehouseDomainLivenessView

const ARM_COLOR := Color(0.075, 0.12, 0.15)
const GLOVE_COLOR := Color(0.12, 0.17, 0.19)
const WHEEL_COLOR := Color(0.028, 0.035, 0.040)
const BEACON_COLOR := Color(1.0, 0.56, 0.10)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _visual_time := 0.0
var _forklift: Node3D
var _beacon: MeshInstance3D


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    call_deferred("_resolve_forklift")


func _process(delta: float) -> void:
    if warehouse_view == null or sim == null:
        return

    _visual_time += maxf(delta, 0.0)
    _sync_workers()
    _sync_forklift()


func _sync_workers() -> void:
    var workers_root := warehouse_view.get_node_or_null("Workers") as Node3D
    if workers_root == null:
        return

    var visible_count := mini(workers_root.get_child_count(), sim.workers.size())
    for index in visible_count:
        var worker := workers_root.get_child(index) as Node3D
        if worker == null:
            continue
        _ensure_worker_details(worker)

        var data: Dictionary = sim.workers[index]
        var active := int(data.get("task", WarehouseSim.Task.IDLE)) != WarehouseSim.Task.IDLE
        var progress := clampf(float(data.get("progress", 0.0)), 0.0, 1.0)
        var phase := progress * TAU * 3.0 + float(index) * 0.73
        _animate_worker(worker, phase, active)


func _ensure_worker_details(worker: Node3D) -> void:
    if worker.get_node_or_null("LivenessLeftArm") == null:
        var left_arm := _box("LivenessLeftArm", Vector3(0.14, 0.48, 0.15), Vector3(-0.34, 0.68, 0.0), ARM_COLOR, 0.58)
        worker.add_child(left_arm)
        var left_glove := _box("LivenessLeftGlove", Vector3(0.16, 0.16, 0.17), Vector3(0.0, -0.27, 0.0), GLOVE_COLOR, 0.64)
        left_arm.add_child(left_glove)

    if worker.get_node_or_null("LivenessRightArm") == null:
        var right_arm := _box("LivenessRightArm", Vector3(0.14, 0.48, 0.15), Vector3(0.34, 0.68, 0.0), ARM_COLOR, 0.58)
        worker.add_child(right_arm)
        var right_glove := _box("LivenessRightGlove", Vector3(0.16, 0.16, 0.17), Vector3(0.0, -0.27, 0.0), GLOVE_COLOR, 0.64)
        right_arm.add_child(right_glove)

    if worker.get_node_or_null("LivenessVestStripe") == null:
        var stripe := _box("LivenessVestStripe", Vector3(0.54, 0.065, 0.405), Vector3(0.0, 0.72, -0.01), Color(0.92, 0.82, 0.30), 0.46)
        worker.add_child(stripe)


func _animate_worker(worker: Node3D, phase: float, active: bool) -> void:
    var left_arm := worker.get_node_or_null("LivenessLeftArm") as Node3D
    var right_arm := worker.get_node_or_null("LivenessRightArm") as Node3D
    var cargo := worker.get_node_or_null("Cargo") as Node3D

    var swing := sin(phase) * 0.42 if active else 0.0
    if left_arm != null:
        left_arm.rotation.x = swing
    if right_arm != null:
        right_arm.rotation.x = -swing

    if active:
        worker.position.y += sin(phase * 2.0) * 0.024

    if cargo != null:
        cargo.position.y = 0.66 + (absf(sin(phase)) * 0.018 if active else 0.0)
        cargo.rotation.z = sin(phase * 0.5) * 0.035 if active else 0.0


func _sync_forklift() -> void:
    if _forklift == null:
        _resolve_forklift()
    if _forklift == null:
        return

    _ensure_forklift_details()
    if _beacon == null:
        return

    var active := sim.forklift_unlocked and sim.forklift_active
    _beacon.visible = active
    var material := _beacon.material_override as StandardMaterial3D
    if material != null:
        material.emission_energy_multiplier = 1.8 + (sin(_visual_time * 8.0) * 0.5 + 0.5) * 1.5 if active else 0.0

    var cargo := _forklift.get_node_or_null("AutomationCargo") as Node3D
    if cargo != null:
        cargo.position.y = 0.48 + (sin(clampf(sim.forklift_progress, 0.0, 1.0) * TAU * 2.0) * 0.018 if active else 0.0)


func _resolve_forklift() -> void:
    if warehouse_view == null:
        return
    _forklift = warehouse_view.get_node_or_null("Forklift") as Node3D
    if _forklift != null:
        _ensure_forklift_details()


func _ensure_forklift_details() -> void:
    if _forklift == null:
        return

    if _forklift.get_node_or_null("LivenessWheelFL") == null:
        for wheel in [
            ["LivenessWheelFL", Vector3(-0.48, 0.21, -0.34)],
            ["LivenessWheelFR", Vector3(0.48, 0.21, -0.34)],
            ["LivenessWheelRL", Vector3(-0.48, 0.21, 0.38)],
            ["LivenessWheelRR", Vector3(0.48, 0.21, 0.38)],
        ]:
            _forklift.add_child(_box(String(wheel[0]), Vector3(0.18, 0.30, 0.26), wheel[1], WHEEL_COLOR, 0.72))

    _beacon = _forklift.get_node_or_null("LivenessBeacon") as MeshInstance3D
    if _beacon == null:
        _beacon = _emissive_box("LivenessBeacon", Vector3(0.17, 0.16, 0.17), Vector3(0.0, 1.52, 0.18), BEACON_COLOR, 0.0)
        _forklift.add_child(_beacon)
    _beacon.visible = sim != null and sim.forklift_unlocked and sim.forklift_active


func _box(name: String, size: Vector3, position: Vector3, color: Color, roughness: float) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness
    material.metallic = 0.04
    instance.material_override = material
    return instance


func _emissive_box(name: String, size: Vector3, position: Vector3, color: Color, energy: float) -> MeshInstance3D:
    var instance := _box(name, size, position, color, 0.34)
    var material := instance.material_override as StandardMaterial3D
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return instance
