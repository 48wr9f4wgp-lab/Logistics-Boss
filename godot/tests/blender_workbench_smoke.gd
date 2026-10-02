extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Workbench = preload("res://assets/models/packing_workbench.glb")
var failures := 0

func _init() -> void:
    call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _run() -> void:
    var asset := Workbench.instantiate() as Node3D
    var meshes := asset.find_children("*", "MeshInstance3D", true, false)
    _expect(meshes.size() == 1, "Workbench stays one mesh")
    var geometry := meshes[0] as MeshInstance3D
    _expect(geometry.mesh.get_surface_count() == 1, "Workbench stays one material surface")
    var triangles := 0
    for surface in geometry.mesh.get_surface_count():
        triangles += int(geometry.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size() / 3)
    _expect(triangles == 304, "Workbench triangle budget is exactly 304")
    var material := geometry.mesh.surface_get_material(0) as StandardMaterial3D
    _expect(material != null and material.vertex_color_use_as_albedo, "Imported material preserves vertex palette")
    _expect(material.get_texture(BaseMaterial3D.TEXTURE_ALBEDO) == null, "No texture memory required")
    _expect(not material.emission_enabled, "Static terminal cannot impersonate active status")
    _expect(material.cull_mode == BaseMaterial3D.CULL_BACK, "Single-sided surfaces avoid backface shading cost")
    _expect(asset.find_children("*", "Light3D", true, false).is_empty(), "No additional lights")
    _expect(asset.find_children("*", "CollisionObject3D", true, false).is_empty(), "No added physics or interaction blockers")
    _expect(asset.find_children("*", "AnimationPlayer", true, false).is_empty(), "No autonomous decorative activity")
    var bounds := geometry.get_aabb()
    _expect(is_equal_approx(bounds.size.x, 2.35) and bounds.size.y < 1.8 and bounds.size.z < 1.2, "GLB uses meter units and correct Y-up orientation")
    asset.free()

    var app := MainScene.instantiate()
    get_root().add_child(app)
    app.set_process(false)
    var sim := app.get("sim") as FlotraV2Sim
    sim.set_time_scale(0.0)
    var view: WarehouseView
    for child in app.get_children():
        if child is WarehouseView: view = child
    await process_frame
    await process_frame
    var station := view.get_node_or_null("PackingWorkbench") as Node3D
    _expect(station != null, "Production scene instantiates Blender asset")
    _expect(station.position == Vector3(2.55, 0.0, -0.05), "Station remains at the existing packing anchor")
    _expect(view.get_node_or_null("PackTable") == null and view.get_node_or_null("PackMonitor") == null and view.get_node_or_null("PackScreen") == null, "Old body is replaced instead of duplicated")
    var queues: WarehouseQueuePressureView
    for child in view.get_children():
        if child is WarehouseQueuePressureView: queues = child
    sim.packing_queue = WarehouseQueuePressureView.PACKING_VISUAL_CAP + 5
    queues._sync_queues()
    _expect(queues._packing_root.get_child_count() == WarehouseQueuePressureView.PACKING_VISUAL_CAP * 2, "Clearance fixture covers the full capped backlog plus tape")
    var live_mesh := station.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
    var overlapping_triangles := 0
    var arrays := live_mesh.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    for parcel in queues._packing_root.get_children():
        var parcel_mesh := parcel as MeshInstance3D
        var parcel_bounds: AABB = parcel_mesh.global_transform * parcel_mesh.get_aabb()
        for triangle in range(0, indices.size(), 3):
            var point: Vector3 = live_mesh.global_transform * vertices[indices[triangle]]
            var triangle_bounds := AABB(point, Vector3.ZERO)
            triangle_bounds = triangle_bounds.expand(live_mesh.global_transform * vertices[indices[triangle + 1]])
            triangle_bounds = triangle_bounds.expand(live_mesh.global_transform * vertices[indices[triangle + 2]])
            if triangle_bounds.grow(0.005).intersects(parcel_bounds):
                overlapping_triangles += 1
    _expect(overlapping_triangles == 0, "Workbench geometry clears all capped authoritative backlog parcels and tape, with 5mm tolerance")
    var snapshot := sim.save_data().duplicate(true)
    var identity := station.get_instance_id()
    for _i in 12: await process_frame
    _expect(sim.save_data() == snapshot, "Asset and presentation never mutate saves or economy")
    _expect(station.get_instance_id() == identity, "Static asset is not reconstructed every frame")
    _expect(FlotraV2Sim.SAVE_SCHEMA_V2 == 11, "Schema 11 preserved")
    # Multiple instances reuse imported mesh/material data instead of cloning them.
    var clone := Workbench.instantiate() as Node3D
    var clone_geometry := clone.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
    var live_geometry := station.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
    _expect(clone_geometry.mesh == live_geometry.mesh, "Instances share the imported mesh")
    clone.free()
    app.queue_free()
    await process_frame
    print("BLENDER_WORKBENCH_SMOKE triangles=%d meshes=1 surfaces=1 textures=0 failures=%d" % [triangles, failures])
    quit(0 if failures == 0 else 1)
