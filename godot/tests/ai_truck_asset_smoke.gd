extends SceneTree

# Bounded GLB import/integration regression. Isolated test profile is provided
# by the usual CI wrapper; never modifies a player's save.
const MainScene = preload("res://scenes/main.tscn")
const TruckAsset = preload("res://assets/models/flotra_delivery_truck_demo.glb")
var failures := 0

func _init() -> void:
    call_deferred("_run")

func _expect(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _run() -> void:
    if OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("ai_truck_asset_smoke requires the isolated-profile runner")
        quit(1)
        return
    if OS.get_cmdline_user_args().has("--corrupt-truck-fixture"):
        _test_corrupt_fixture()
        quit(0 if failures == 0 else 1)
        return
    _test_fallbacks()
    _test_corrupt_subprocess()
    var model := TruckAsset.instantiate() as Node3D
    _expect(model != null, "GLB can instantiate as Node3D")
    if model == null:
        quit(1)
        return
    var meshes := model.find_children("*", "MeshInstance3D", true, false)
    _expect(meshes.size() == 6, "Prototype has six merged, opaque material surfaces")
    var triangles := 0
    var surfaces := 0
    for node in meshes:
        var geometry := node as MeshInstance3D
        for i in geometry.mesh.get_surface_count():
            var arrays := geometry.mesh.surface_get_arrays(i)
            triangles += int(arrays[Mesh.ARRAY_INDEX].size() / 3)
            surfaces += 1
            _expect(geometry.mesh.surface_get_material(i) != null, "Material survived glTF import")
    _expect(triangles == 276 and surfaces == 6, "Bounded geometry and draw surfaces")
    _expect(model.find_children("*", "Light3D", true, false).is_empty(), "GLB adds no lights")
    _expect(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "GLB adds no collision")
    _expect(model.find_children("*", "AnimationPlayer", true, false).is_empty(), "GLB does not fake operations")
    model.free()

    var app := MainScene.instantiate()
    get_root().add_child(app)
    app.set_process(false)
    var sim := app.get("sim") as FlotraV2Sim
    sim.set_time_scale(0.0)
    var view: WarehouseView
    for child in app.get_children():
        if child is WarehouseView:
            view = child
    await process_frame
    await process_frame
    _expect(view != null, "Canonical warehouse loaded")
    if view == null:
        quit(1)
        return
    var installed := view.get_node_or_null("DeliveryTruckVisual") as Node3D
    _expect(installed != null, "Truck GLB is visible inside actual warehouse")
    _expect(not (view.get_node("TruckBody") as MeshInstance3D).visible, "Old cargo body is hidden, not double-drawn")
    _expect(not (view.get_node("TruckCab") as MeshInstance3D).visible, "Old cab is hidden, not double-drawn")
    if installed != null:
        _expect(installed.position == Vector3(6.0, 0.0, 4.25), "Delivery model uses the existing dock anchor")
        var ident := installed.get_instance_id()
        var snapshot := sim.save_data().duplicate(true)
        for _i in 12:
            await process_frame
        _expect(ident == installed.get_instance_id(), "GLB instance persists; no per-frame rebuild")
        _expect(snapshot == sim.save_data(), "Visual-only asset does not mutate saves/economy")
    app.queue_free()
    await process_frame
    print("AI_TRUCK_ASSET_SMOKE triangles=%d surfaces=%d failures=%d" % [triangles, surfaces, failures])
    quit(0 if failures == 0 else 1)


func _test_fallbacks() -> void:
    # Injectable paths exercise the real installer without editing the committed
    # GLB or loading a player's save. The CI wrapper owns this disposable user://.
    var material_path := "user://truck_wrong_resource.tres"
    _expect(ResourceSaver.save(StandardMaterial3D.new(), material_path) == OK, "Wrong-resource fixture saved")
    var fixtures := ["user://truck_missing.glb", material_path]
    var roots: Array[Node] = [Node.new(), Node3D.new(), MeshInstance3D.new()]
    var hidden := MeshInstance3D.new()
    hidden.mesh = BoxMesh.new()
    hidden.visible = false
    roots.append(hidden)
    var hidden_parent := Node3D.new()
    hidden_parent.visible = false
    var hidden_child := MeshInstance3D.new()
    hidden_child.mesh = BoxMesh.new()
    hidden_parent.add_child(hidden_child)
    hidden_child.owner = hidden_parent
    roots.append(hidden_parent)
    for index in roots.size():
        var packed := PackedScene.new()
        _expect(packed.pack(roots[index]) == OK, "Fallback scene packs")
        var path := "user://truck_invalid_%d.tscn" % index
        _expect(ResourceSaver.save(packed, path) == OK, "Fallback scene saves")
        fixtures.append(path)
        roots[index].free()
    var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
    for path in fixtures:
        var view := WarehouseView.new()
        var body := MeshInstance3D.new()
        var cab := MeshInstance3D.new()
        view.add_child(body)
        view.add_child(cab)
        view._try_install_truck_glb(body, cab, path)
        _expect(body.visible and cab.visible, "Rejected asset preserves both legacy shells: %s" % path)
        _expect(view.get_child_count() == 2, "Rejected asset adds no partial truck: %s" % path)
        view.free()
    _expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_count, "Rejected scene roots do not leak orphan nodes")

    # Also accept a visible mesh at the scene root, not only nested GLB meshes.
    var mesh_root := MeshInstance3D.new()
    mesh_root.mesh = BoxMesh.new()
    var valid_scene := PackedScene.new()
    _expect(valid_scene.pack(mesh_root) == OK, "Root-mesh scene packs")
    var valid_path := "user://truck_root_mesh.tscn"
    _expect(ResourceSaver.save(valid_scene, valid_path) == OK, "Root-mesh scene saves")
    mesh_root.free()
    var valid_view := WarehouseView.new()
    var valid_body := MeshInstance3D.new()
    var valid_cab := MeshInstance3D.new()
    valid_view.add_child(valid_body)
    valid_view.add_child(valid_cab)
    valid_view._try_install_truck_glb(valid_body, valid_cab, valid_path)
    _expect(not valid_body.visible and not valid_cab.visible, "Visible root mesh replaces legacy shells")
    _expect(valid_view.get_node_or_null("DeliveryTruckVisual") != null, "Visible root mesh installs")
    valid_view.free()
    for path in fixtures + [valid_path]:
        if FileAccess.file_exists(path):
            _expect(DirAccess.remove_absolute(path) == OK, "Disposable fixture removed")
    print("AI_TRUCK_FALLBACK_SMOKE rejected=%d failures=%d" % [fixtures.size(), failures])


func _test_corrupt_fixture() -> void:
    var path := "user://truck_corrupt.tscn"
    var file := FileAccess.open(path, FileAccess.WRITE)
    _expect(file != null, "Corrupt fixture file opens")
    if file == null:
        return
    file.store_string("this is not a scene resource")
    file.close()
    var view := WarehouseView.new()
    var body := MeshInstance3D.new()
    var cab := MeshInstance3D.new()
    view.add_child(body)
    view.add_child(cab)
    view._try_install_truck_glb(body, cab, path)
    _expect(body.visible and cab.visible and view.get_child_count() == 2, "Corrupt scene preserves legacy truck")
    view.free()
    _expect(DirAccess.remove_absolute(path) == OK, "Corrupt fixture removed")
    print("AI_TRUCK_CORRUPTION_PROBE failures=%d" % failures)


func _test_corrupt_subprocess() -> void:
    # Expected ResourceLoader diagnostics stay in the isolated child log. Only
    # these exact errors are accepted; the ordinary CI error gate is unchanged.
    var output: Array = []
    var status := OS.execute(OS.get_executable_path(), [
        "--headless", "--path", ProjectSettings.globalize_path("res://"),
        "--script", "res://tests/ai_truck_asset_smoke.gd", "--", "--corrupt-truck-fixture",
    ], output, true)
    var log_text := "\n".join(output)
    var file := FileAccess.open("user://truck_corruption_probe.log", FileAccess.WRITE)
    _expect(file != null, "Corruption diagnostic log opens")
    if file != null:
        file.store_string(log_text)
        file.close()
    var expected_errors := [
        "ERROR: user://truck_corrupt.tscn:1 - Parse Error: Expected '['.",
        "ERROR: Failed loading resource: user://truck_corrupt.tscn.",
    ]
    var actual_errors: Array[String] = []
    for line in log_text.split("\n"):
        if line.begins_with("ERROR:"):
            actual_errors.append(line.strip_edges())
    _expect(status == 0 and log_text.contains("AI_TRUCK_CORRUPTION_PROBE failures=0"), "Corrupt-resource child completes with fallback intact")
    _expect(actual_errors == expected_errors, "Only the two expected corrupt-resource errors occurred")
    _expect(not log_text.contains("SCRIPT ERROR") and not log_text.contains("leaked"), "Corruption probe has no script failure or leaked nodes")
    print("AI_TRUCK_CORRUPTION_SMOKE exit=%d expected_errors=%d failures=%d" % [status, actual_errors.size(), failures])
