extends SceneTree
# Read-only test harness outside the exported project. Never instantiate a scene.
func _initialize() -> void:
    var paths := ["res://.godot/exported/133200997/export-5f2775806746314698573e32bc8e4921-release.scn", "res://.godot/exported/133200997/export-6b9ecba11763283c49e0456ea8e7e3d0-growth.scn", "res://.godot/exported/133200997/export-c0b1cce5d9f1449052f4a6622f9dad6e-save_size_web.scn", "res://.godot/imported/packing_workbench.glb-5346c9a59928ee467deb20c316f6591b.scn"]
    var report := []
    for path in paths:
        var scene := load(path) as PackedScene
        assert(scene != null)
        var bundle: Dictionary = scene.get("_bundled")
        var state := scene.get_state()
        var nodes := []
        for i in state.get_node_count():
            var properties := []
            for j in state.get_node_property_count(i):
                var value: Variant = state.get_node_property_value(i, j)
                var property := {"name": str(state.get_node_property_name(i, j)), "type": typeof(value)}
                if value is Resource:
                    property["resourceClass"] = value.get_class()
                    property["resourcePath"] = value.resource_path
                else:
                    property["value"] = var_to_str(value)
                properties.append(property)
            nodes.append({"name": str(state.get_node_name(i)), "type": str(state.get_node_type(i)), "path": str(state.get_node_path(i)), "hasInstance": state.get_node_instance(i) != null, "properties": properties})
        report.append({"path": path.trim_prefix("res://"), "node_ids": Array(bundle.node_ids), "id_paths": bundle.get("id_paths", []), "node_paths": bundle.get("node_paths", []), "base_scene": bundle.get("base_scene", -1), "conn_count": bundle.conn_count, "node_count": state.get_node_count(), "nodes": nodes})
    var destination := OS.get_environment("SCENE_ID_REPORT")
    assert(not destination.is_empty())
    var file := FileAccess.open(destination, FileAccess.WRITE)
    assert(file != null)
    file.store_string(JSON.stringify(report, "  "))
    print("SCENE_ID_STRUCTURE ", JSON.stringify(report))
    quit()
