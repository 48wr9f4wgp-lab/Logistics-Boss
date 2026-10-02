@tool
extends EditorScenePostImport

# glTF COLOR_0 survives import, but the Godot 4.7.2 material flag defaults to
# disabled for this untextured Blender export. Apply it at import time, so all
# instances share the same baked material and there is no runtime repair loop.
func _post_import(scene: Node) -> Object:
    for node in scene.find_children("*", "MeshInstance3D", true, false):
        var geometry := node as MeshInstance3D
        for surface in geometry.mesh.get_surface_count():
            var material := geometry.mesh.surface_get_material(surface) as StandardMaterial3D
            if material != null:
                material.vertex_color_use_as_albedo = true
                material.vertex_color_is_srgb = false # glTF vertex colors are linear
    return scene
