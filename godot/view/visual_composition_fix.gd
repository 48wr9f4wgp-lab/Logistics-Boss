extends Node3D
class_name WarehouseVisualCompositionFix

var warehouse_view: WarehouseView


func bind(view: WarehouseView) -> void:
    warehouse_view = view
    warehouse_view._camera_distance = 16.7
    warehouse_view._orbit_pitch = -0.69
    warehouse_view._orbit_yaw = -0.80
    call_deferred("_apply_composition")


func _apply_composition() -> void:
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        camera.fov = 32.5

    _reduce_foreground_structure()
    _deemphasize_truck()


func _reduce_foreground_structure() -> void:
    if warehouse_view == null:
        return

    for child in warehouse_view.get_children():
        _tune_structure_recursive(child)


func _tune_structure_recursive(node: Node) -> void:
    if node is Node3D:
        var n := node as Node3D
        # LOGISTICS BOSS is played as an open-top cutaway. Overhead trusses and
        # emissive roof bars were repeatedly crossing the portrait camera and
        # hiding workers, racks and parcels. Keep the back wall, columns and
        # utility run for warehouse identity, but never let roof geometry block
        # the readable gameplay floor.
        if n.name == "RoofTruss" or n.name == "RoofLight":
            n.visible = false

    for child in node.get_children():
        _tune_structure_recursive(child)


func _deemphasize_truck() -> void:
    if warehouse_view == null:
        return

    var body := warehouse_view.get_node_or_null("TruckBody") as MeshInstance3D
    if body != null:
        var body_mat := body.material_override as StandardMaterial3D
        if body_mat != null:
            body_mat.albedo_color = Color(0.34, 0.42, 0.47)
            body_mat.roughness = 0.62

    var cab := warehouse_view.get_node_or_null("TruckCab") as MeshInstance3D
    if cab != null:
        var cab_mat := cab.material_override as StandardMaterial3D
        if cab_mat != null:
            cab_mat.albedo_color = Color(0.07, 0.16, 0.24)
            cab_mat.roughness = 0.54
