extends SceneTree
## Actual campaign scene, disposable state. Pixel/performance acceptance is separate.
const Main = preload("res://prototype/growth_main.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)
func run() -> void:
    var app := Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    app.hud.show_play()
    for frame in 4: await process_frame
    app.world.refresh()
    var before := var_to_bytes(app.sim.export_release_state())
    var truck: Node3D = app.world.get_node_or_null("OutboundTruckDisplay")
    check(truck != null, "Actual campaign installs a truck display")
    if truck == null:
        quit(1)
        return
    var identity := truck.get_instance_id()
    var wheels := truck.get_node("TruckWheels") as MultiMeshInstance3D
    check(wheels.multimesh.instance_count == 4, "All four wheels share one draw batch")
    check(truck.find_children("*", "CollisionObject3D", true, false).is_empty(), "No collision changes to real cargo routes")
    check(truck.find_children("*", "AnimationPlayer", true, false).is_empty(), "No invented delivery animation")
    var meshes := truck.find_children("*", "MeshInstance3D", true, false)
    var state: Dictionary = app.sim.snapshot()
    for mesh: MeshInstance3D in meshes:
        var bounds: AABB = mesh.global_transform * mesh.get_aabb()
        var clearance := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(.35)
        for edge in state.edges:
            var a := Vector2(edge.from.x, edge.from.z)
            var b := Vector2(edge.to.x, edge.to.z)
            check(not clearance.has_point(a) and not clearance.has_point(b), "Truck stays clear of route endpoints")
            for side in 4:
                var corners := [clearance.position, Vector2(clearance.end.x, clearance.position.y), clearance.end, Vector2(clearance.position.x, clearance.end.y)]
                check(Geometry2D.segment_intersects_segment(a, b, corners[side], corners[(side+1)%4]) == null, "Truck stays outside cargo approach segments")
    for size in [Vector2i(375, 567), Vector2i(390, 844), Vector2i(430, 932)]:
        root.size = size
        for frame in 4: await process_frame
        for turn in 4:
            app.world._camera_turn = turn
            app.world.fit_camera(app.viewport_container.size)
            for item in app.world._callouts.values():
                if item.label.visible:
                    check(not item.rect.intersects(app.world._truck_screen_rect()), "Location labels do not cover the truck")
            var screen := Rect2(Vector2.ZERO, app.viewport_container.size)
            for mesh: MeshInstance3D in meshes:
                for corner in 8:
                    var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
                    check(screen.has_point(app.world.camera.unproject_position(point)), "Truck geometry fits every overview turn and phone size")
    for frame in 12:
        app.world.refresh()
        await process_frame
    check(identity == truck.get_instance_id(), "Refresh retains the single stationary display")
    check(before == var_to_bytes(app.sim.export_release_state()), "Truck and camera leave complete campaign save byte-identical")
    check(not app.persistence_enabled, "No owner save writes")
    app.queue_free()
    await process_frame
    print("TRUCK_STATIC_DISPLAY ", JSON.stringify({"checks": checks, "failures": failures}))
    quit(0 if failures.is_empty() else 1)
