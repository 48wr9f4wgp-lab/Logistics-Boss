extends SceneTree

const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")


func _init() -> void:
    var root := Node3D.new()
    get_root().add_child(root)

    var view: WarehouseView = WarehouseViewScript.new()
    root.add_child(view)

    var pass2: WarehouseVisualPass2 = WarehouseVisualPass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)

    var composition: WarehouseVisualCompositionFix = WarehouseVisualCompositionFixScript.new()
    view.add_child(composition)
    composition.bind(view)

    await process_frame
    await process_frame

    var roof_nodes := view.find_children("Roof*", "Node3D", true, false)
    assert(roof_nodes.is_empty(), "open-top warehouse must not generate roof trusses or roof lights")

    var utility_nodes := view.find_children("Utility*", "Node3D", true, false)
    assert(utility_nodes.is_empty(), "open-top warehouse must not generate overhead utility bars")

    var left_wall := view.get_node_or_null("LeftWall") as Node3D
    assert(left_wall != null, "readability smoke expects the base facility left wall")
    assert(not left_wall.visible, "foreground side wall must not block the portrait cutaway view")

    view._camera_distance = 25.0
    await process_frame
    var camera: Camera3D = root.get_viewport().get_camera_3d()
    assert(camera != null, "overview smoke requires an active camera")
    assert(camera.fov > 38.0, "max pinch distance must widen into a true warehouse overview")

    print("Godot warehouse visual readability smoke passed")
    quit(0)
