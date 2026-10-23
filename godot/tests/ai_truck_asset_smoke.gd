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
