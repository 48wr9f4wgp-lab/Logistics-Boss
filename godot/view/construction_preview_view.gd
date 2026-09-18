extends Node3D
class_name WarehouseConstructionPreviewView

const PREVIEW_CYAN := Color(0.25, 0.88, 1.0, 0.30)
const PREVIEW_AMBER := Color(1.0, 0.68, 0.20, 0.30)
const COMMIT_CYAN := Color(0.30, 0.95, 1.0, 0.90)
const COMMIT_AMBER := Color(1.0, 0.72, 0.24, 0.90)

const ZONE_FOOTPRINTS := {
    "inbound": {"center": Vector3(-5.25, 0.055, 0.15), "half": Vector2(1.25, 3.10)},
    "storage": {"center": Vector3(-2.20, 0.055, 0.15), "half": Vector2(1.35, 3.10)},
    "picking": {"center": Vector3(0.25, 0.055, 0.15), "half": Vector2(0.85, 3.10)},
    "packing": {"center": Vector3(2.65, 0.055, 0.15), "half": Vector2(1.30, 3.10)},
    "shipping": {"center": Vector3(5.30, 0.055, 0.15), "half": Vector2(1.20, 3.10)},
}

var warehouse_view: WarehouseView
var current_zone := ""
var current_kind: StringName = &""

var _preview_root: Node3D
var _commit_sequence := 0


func bind(view: WarehouseView) -> void:
    warehouse_view = view
    _preview_root = Node3D.new()
    _preview_root.name = "ConstructionPreview"
    add_child(_preview_root)


func show_preview(zone_key: String, kind: StringName) -> void:
    if _preview_root == null:
        return
    clear_preview()
    current_zone = zone_key
    current_kind = kind

    _build_zone_outline(_preview_root, zone_key, _preview_color(kind), 0.30)
    _build_kind_ghost(_preview_root, kind)


func clear_preview() -> void:
    current_zone = ""
    current_kind = &""
    if _preview_root == null:
        return
    for child in _preview_root.get_children():
        child.queue_free()


func show_commit(zone_key: String, kind: StringName, action: String) -> void:
    _commit_sequence += 1
    var root := Node3D.new()
    root.name = "ConstructionCommit_%d" % _commit_sequence
    add_child(root)

    var color := COMMIT_AMBER if _is_packing_kind(kind) else COMMIT_CYAN
    _build_zone_outline(root, zone_key, color, 0.92)

    # A short vertical beacon bridges the preview ghost to the real geometry
    # without obscuring the warehouse or inventing gameplay state.
    var center := _zone_center(zone_key)
    var beacon := _box(
        root,
        "CommitBeacon",
        Vector3(0.12, 1.15, 0.12),
        center + Vector3(0.0, 0.58, 0.0),
        color,
        0.88
    )
    var beacon_material := beacon.material_override as StandardMaterial3D

    var tween := root.create_tween()
    tween.set_parallel(true)
    tween.tween_property(root, "scale", Vector3(1.06, 1.0, 1.06), 0.90)        .set_trans(Tween.TRANS_QUAD)        .set_ease(Tween.EASE_OUT)
    if beacon_material != null:
        tween.tween_property(beacon_material, "emission_energy_multiplier", 0.25, 0.90)            .set_trans(Tween.TRANS_QUAD)            .set_ease(Tween.EASE_OUT)
    tween.chain().tween_interval(0.12)
    tween.chain().tween_callback(Callable(root, "queue_free"))

    root.set_meta("zone_key", zone_key)
    root.set_meta("kind", String(kind))
    root.set_meta("action", action)


func has_preview() -> bool:
    return not current_zone.is_empty() and current_kind != &""


func preview_child_count() -> int:
    return _preview_root.get_child_count() if _preview_root != null else 0


func _build_kind_ghost(parent: Node3D, kind: StringName) -> void:
    var color := _preview_color(kind)
    match kind:
        &"rack_wing":
            _box(parent, "Ghost_RackWingPad", Vector3(1.55, 0.055, 3.35), Vector3(-3.92, 0.045, -1.05), color)
            for z in [-2.20, -1.15, -0.10]:
                _box(parent, "Ghost_RackWing", Vector3(1.10, 2.55, 0.72), Vector3(-3.92, 1.30, z), color)
        &"second_packing_bench":
            _box(parent, "Ghost_SecondPackPad", Vector3(2.05, 0.055, 1.10), Vector3(3.12, 0.045, 1.28), color)
            _box(parent, "Ghost_SecondPackBench", Vector3(1.75, 0.55, 0.80), Vector3(3.12, 0.55, 1.28), color)
        &"forklift_project":
            _box(parent, "Ghost_ForkliftLane", Vector3(2.10, 0.055, 1.00), Vector3(-3.70, 0.045, 1.45), color)
            _box(parent, "Ghost_ForkliftBody", Vector3(0.95, 0.70, 0.72), Vector3(-3.70, 0.42, 1.45), color)
            _box(parent, "Ghost_ForkliftMast", Vector3(0.12, 1.15, 0.58), Vector3(-3.18, 0.68, 1.45), color)
        &"fast_pick_rack":
            _box(parent, "Ghost_FastPickPad", Vector3(2.55, 0.055, 1.25), Vector3(0.15, 0.045, -2.65), color)
            for x in [-0.35, 0.70]:
                _box(parent, "Ghost_FastPickRack", Vector3(0.92, 1.70, 0.72), Vector3(x, 0.88, -2.65), color)
        &"high_density_rack":
            for z in [-2.75, -1.70]:
                _box(parent, "Ghost_HighDensityRack", Vector3(1.42, 2.95, 0.80), Vector3(-3.90, 1.50, z), color)
        &"parallel_pack":
            _box(parent, "Ghost_ParallelPackPad", Vector3(2.35, 0.055, 0.95), Vector3(2.35, 0.045, 1.25), color)
            _box(parent, "Ghost_ParallelPackLine", Vector3(2.05, 0.72, 0.82), Vector3(2.35, 0.56, 1.25), color)
        &"fast_pack_cell":
            _box(parent, "Ghost_FastPackCellPad", Vector3(1.65, 0.055, 1.35), Vector3(2.45, 0.045, 1.20), color)
            _box(parent, "Ghost_FastPackCell", Vector3(1.30, 1.02, 0.92), Vector3(2.45, 0.62, 1.20), color)


func _build_zone_outline(
    parent: Node3D,
    zone_key: String,
    color: Color,
    alpha: float
) -> void:
    if not ZONE_FOOTPRINTS.has(zone_key):
        return
    var definition: Dictionary = ZONE_FOOTPRINTS[zone_key]
    var center: Vector3 = definition["center"]
    var half: Vector2 = definition["half"]
    var thickness := 0.075

    _box(parent, "ZonePreviewNorth", Vector3(half.x * 2.0, 0.035, thickness), center + Vector3(0.0, 0.0, -half.y), color, alpha)
    _box(parent, "ZonePreviewSouth", Vector3(half.x * 2.0, 0.035, thickness), center + Vector3(0.0, 0.0, half.y), color, alpha)
    _box(parent, "ZonePreviewWest", Vector3(thickness, 0.035, half.y * 2.0), center + Vector3(-half.x, 0.0, 0.0), color, alpha)
    _box(parent, "ZonePreviewEast", Vector3(thickness, 0.035, half.y * 2.0), center + Vector3(half.x, 0.0, 0.0), color, alpha)


func _preview_color(kind: StringName) -> Color:
    return PREVIEW_AMBER if _is_packing_kind(kind) else PREVIEW_CYAN


func _is_packing_kind(kind: StringName) -> bool:
    return kind in [
        &"second_packing_bench",
        &"parallel_pack",
        &"fast_pack_cell",
    ]


func _zone_center(zone_key: String) -> Vector3:
    if not ZONE_FOOTPRINTS.has(zone_key):
        return Vector3.ZERO
    return (ZONE_FOOTPRINTS[zone_key] as Dictionary)["center"]


func _box(
    parent: Node,
    node_name: String,
    size: Vector3,
    position: Vector3,
    color: Color,
    alpha: float = 0.28
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = position

    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(color.r, color.g, color.b, alpha)
    material.roughness = 0.30
    material.metallic = 0.15
    material.emission_enabled = true
    material.emission = Color(color.r, color.g, color.b, 1.0)
    material.emission_energy_multiplier = 1.35
    instance.material_override = material
    parent.add_child(instance)
    return instance
