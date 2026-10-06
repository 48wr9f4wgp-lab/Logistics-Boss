extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Store = preload("res://prototype/release_save.gd")
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String):
    checks += 1
    if not ok: failures.append(message); push_error(message)
func _initialize(): run.call_deferred()
func run():
    var app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    check(app.viewport.msaa_3d == Viewport.MSAA_2X, "Actual warehouse SubViewport has2xMSAA")
    var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLOTRA_GROWTH_FIXTURES")+"/late.json"))
    var decoded: Dictionary = Store.new().decode(data.encoded)
    check(decoded.ok, "Mature fixture decodes")
    check(app.sim.import_release_state(decoded.data).ok, "Mature fixture imports")
    app.world.bind_sim(app.sim)
    var samples: Array = []
    for seconds in [0.0, .25, 1.0, 5.0, 20.0, 60.0, 120.0, 240.0, 480.0]:
        app.sim.step(seconds)
        var before = app.sim.export_release_state()
        app.world.refresh()
        for frame in 3: await process_frame
        check(app.sim.export_release_state() == before, "Rendering never changes authoritative save state")
        check(app.sim.check_invariants().ok, "Domain conservation remains true through pickup and delivery")
        samples.append(inspect_loads(app))
    check(app.sim.finished, "Mature job reaches actual completion")
    check(int(samples[-1].loaded_pallets) == 0, "Delivered pallets leave no stranded artwork")
    check(app.sim.import_release_state(decoded.data).ok, "Original in-flight save reloads")
    app.world.refresh()
    for frame in 3: await process_frame
    var reloaded := inspect_loads(app)
    check(reloaded == samples[0], "In-flight reload restores exactly its physical pallet artwork")
    print(JSON.stringify({"suite":"visual_quality","checks":checks,"failures":failures,"samples":samples,"reloaded":reloaded,"msaa_3d":app.viewport.msaa_3d}))
    quit(0 if failures.is_empty() else 1)

func inspect_loads(app) -> Dictionary:
    var expected_groups := {}
    var expected_units := 0
    for item in app.sim.snapshot().cargo:
        if str(item.get("job_kind", item.get("kind", ""))) == "bulk" and not str(item.get("bay_id", "")).is_empty() and str(item.get("stage", "")) in ["bulk_storage", "reserved_bulk_ship"]:
            expected_groups[str(item.manifest_id) + ":" + str(item.stage)] = true
            expected_units += 1
    var loads := 0
    var units := 0
    for node in app.world._cargo.values():
        var load: Node3D = node.get_node_or_null("BulkPallet")
        if load == null or not load.visible: continue
        loads += 1
        units += int(load.get_meta("represented_units"))
        var drawn_units := 0
        for child in load.get_children():
            if str(child.name).begins_with("Unit") and child.visible: drawn_units += 1
            if child is MeshInstance3D:
                var bounds: AABB = load.transform * child.transform * child.get_aabb()
                check(bounds.position.x >= -.5 and bounds.end.x <= .5 and bounds.position.z >= -.5 and bounds.end.z <= .5, "Pallet remains inside real1m bay")
        check(drawn_units == int(load.get_meta("represented_units")), "Cartons equal actual grouped units")
        check(not node.get_node("Carton").visible and not node.get_node("Tape").visible, "No duplicate old carton is drawn")
    check(loads == expected_groups.size() and units == expected_units, "Only actual stationary bay manifests have pallet artwork")
    return {"loaded_pallets":loads,"represented_units":units}
