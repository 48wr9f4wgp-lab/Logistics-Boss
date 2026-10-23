extends SceneTree
## Isolated campaign-project import verification, not a rendered acceptance.
const Asset = preload("res://assets/models/truck_body_asset.gd")
const Main = preload("res://prototype/growth_main.gd")
var checks := 0
var failures := 0

func _init() -> void:
    run.call_deferred()

func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        push_error(message)

func run() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if sandbox.is_empty() or not ProjectSettings.globalize_path("user://").begins_with(sandbox):
        push_error("truck_body_import requires isolated FLOTRA_REVIEW_USER_ROOT")
        quit(1)
        return
    check(Asset.instantiate_body("user://missing_truck.glb") == null, "Missing asset is rejected")
    var wrong_path := "user://truck_material.tres"
    check(ResourceSaver.save(StandardMaterial3D.new(), wrong_path) == OK, "Wrong-type fixture saves")
    check(Asset.instantiate_body(wrong_path) == null, "Non-scene resource is rejected")
    DirAccess.remove_absolute(wrong_path)
    var roots: Array[Node] = [Node.new(), Node3D.new(), MeshInstance3D.new()]
    var hidden := MeshInstance3D.new()
    hidden.mesh = BoxMesh.new()
    hidden.visible = false
    roots.append(hidden)
    var hidden_parent := Node3D.new()
    hidden_parent.visible = false
    var child := MeshInstance3D.new()
    child.mesh = BoxMesh.new()
    hidden_parent.add_child(child)
    child.owner = hidden_parent
    roots.append(hidden_parent)
    for i in roots.size():
        var scene := PackedScene.new()
        check(scene.pack(roots[i]) == OK, "Invalid scene packs")
        var path := "user://truck_invalid_%d.tscn" % i
        check(ResourceSaver.save(scene, path) == OK, "Invalid fixture saves")
        roots[i].free()
        var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
        check(Asset.instantiate_body(path) == null, "Empty, hidden or non-3D scene is rejected")
        check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphans, "Rejected scene leaves no orphan")
        DirAccess.remove_absolute(path)

    var body := Asset.instantiate_body()
    check(body != null, "Original committed GLB imports in the campaign project")
    if body == null:
        quit(1)
        return
    var meshes := body.find_children("*", "MeshInstance3D", true, false)
    var triangles := 0
    var surfaces := 0
    check(meshes.size() == 6, "Six mesh nodes retained")
    for node in meshes:
        var geometry := node as MeshInstance3D
        for index in geometry.mesh.get_surface_count():
            var arrays := geometry.mesh.surface_get_arrays(index)
            triangles += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
            surfaces += 1
            var material := geometry.mesh.surface_get_material(index) as StandardMaterial3D
            check(material != null and material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) == null, "Imported material needs no texture")
    check(triangles == 276 and surfaces == 6, "Original bounded geometry is unchanged")
    check(body.find_children("*", "Light3D", true, false).is_empty(), "No imported lights")
    check(body.find_children("*", "CollisionObject3D", true, false).is_empty(), "No imported collisions")
    check(body.find_children("*", "AnimationPlayer", true, false).is_empty(), "No invented vehicle operations")
    var second := Asset.instantiate_body()
    check(second != null, "Second instance loads")
    if second != null:
        var second_meshes := second.find_children("*", "MeshInstance3D", true, false)
        check(meshes[0].mesh == second_meshes[0].mesh, "Instances share imported mesh data")
        second.free()

    var app := Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    var before := var_to_bytes(app.sim.export_release_state())
    check(app.world.get_node_or_null("DeliveryTruckBodyCandidate") == null, "Campaign does not auto-install an unreviewed body")
    # Temporary test attachment proves composition compatibility, not placement.
    app.world.add_child(body)
    var identity := body.get_instance_id()
    for frame in 12:
        await process_frame
    check(body.get_instance_id() == identity, "Imported body is not rebuilt every frame")
    check(before == var_to_bytes(app.sim.export_release_state()), "Temporary asset leaves the full campaign save unchanged")
    check(not app.persistence_enabled, "No player save is written")
    body.free()
    app.queue_free()
    await process_frame
    print("TRUCK_BODY_IMPORT checks=%d triangles=%d surfaces=%d failures=%d" % [checks, triangles, surfaces, failures])
    quit(0 if failures == 0 else 1)
