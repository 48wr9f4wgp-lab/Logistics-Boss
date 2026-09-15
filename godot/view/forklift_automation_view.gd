extends Node3D
class_name ForkliftAutomationView

const PARK := Vector3(-4.45, 0.0, 0.55)
const INBOUND := Vector3(-5.25, 0.0, 2.35)
const RACK := Vector3(-1.75, 0.0, -0.15)
const CARGO_COLOR := Color(0.84, 0.61, 0.31)

var warehouse_view: WarehouseView
var sim: WarehouseSim
var _forklift: Node3D
var _cargo: MeshInstance3D


func bind(view: WarehouseView, next_sim: WarehouseSim) -> void:
    warehouse_view = view
    sim = next_sim
    call_deferred("_resolve_forklift")


func _process(_delta: float) -> void:
    if sim == null or warehouse_view == null:
        return
    if _forklift == null:
        _resolve_forklift()
    if _forklift == null:
        return

    _forklift.visible = sim.forklift_unlocked
    if not sim.forklift_unlocked:
        return

    if not sim.forklift_active:
        _forklift.position = PARK
        _forklift.rotation.y = -0.55
        if _cargo != null:
            _cargo.visible = false
        return

    var progress := clampf(sim.forklift_progress, 0.0, 1.0)
    var target := RACK
    if progress <= 0.5:
        var leg := smoothstep(0.0, 1.0, progress * 2.0)
        _forklift.position = INBOUND.lerp(RACK, leg)
        target = RACK
        if _cargo != null:
            _cargo.visible = true
    else:
        var leg := smoothstep(0.0, 1.0, (progress - 0.5) * 2.0)
        _forklift.position = RACK.lerp(INBOUND, leg)
        target = INBOUND
        if _cargo != null:
            _cargo.visible = false

    var direction := target - _forklift.position
    if direction.length_squared() > 0.001:
        _forklift.rotation.y = atan2(direction.x, direction.z)


func _resolve_forklift() -> void:
    if warehouse_view == null:
        return
    _forklift = warehouse_view.get_node_or_null("Forklift") as Node3D
    if _forklift == null:
        return

    _cargo = _forklift.get_node_or_null("AutomationCargo") as MeshInstance3D
    if _cargo == null:
        _cargo = MeshInstance3D.new()
        _cargo.name = "AutomationCargo"
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.58, 0.44, 0.56)
        _cargo.mesh = mesh
        _cargo.position = Vector3(0.0, 0.48, -0.92)
        var material := StandardMaterial3D.new()
        material.albedo_color = CARGO_COLOR
        material.roughness = 0.72
        _cargo.material_override = material
        _forklift.add_child(_cargo)

    _forklift.position = PARK
    _forklift.visible = sim != null and sim.forklift_unlocked
    _cargo.visible = false
