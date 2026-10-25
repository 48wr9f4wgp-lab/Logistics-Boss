extends RefCounted
## Original demonstration body/cab only. This loader owns no placement, wheels,
## routes, cargo, income or saved state. The separate outbound display owns
## stationary campaign placement; this loader remains usable in isolation.

const MODEL_PATH := "res://assets/models/flotra_delivery_truck_demo.glb"

static func instantiate_body(path: String = MODEL_PATH) -> Node3D:
    if not ResourceLoader.exists(path):
        return null
    var packed := load(path) as PackedScene
    if packed == null:
        return null
    var instance := packed.instantiate()
    var body := instance as Node3D
    if body == null or not _has_visible_geometry(body):
        if instance != null:
            instance.free()
        return null
    body.name = "DeliveryTruckBodyCandidate"
    return body

static func _has_visible_geometry(node: Node3D) -> bool:
    if not node.visible:
        return false
    if node is MeshInstance3D:
        var geometry := node as MeshInstance3D
        if geometry.mesh != null and geometry.mesh.get_surface_count() > 0:
            return true
    for child in node.get_children():
        if child is Node3D and _has_visible_geometry(child):
            return true
    return false
