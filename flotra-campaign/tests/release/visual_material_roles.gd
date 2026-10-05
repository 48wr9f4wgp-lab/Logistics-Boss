extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Store = preload("res://prototype/release_save.gd")
var errors: Array[String] = []
var checks := 0
func check(ok: bool, text: String):
    checks += 1
    if not ok: errors.append(text); push_error(text)
func _initialize(): run.call_deferred()
func run():
    var app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FLOTRA_GROWTH_FIXTURES")+"/late.json"))
    var decoded: Dictionary = Store.new().decode(fixture.encoded)
    check(app.sim.import_release_state(decoded.data).ok, "Valid real mature fixture")
    var seen := {"idle":false,"active":false,"waiting":false,"empty":false,"occupied":false}
    for tick in 30:
        app.sim.step(.75)
        var before = app.sim.export_release_state()
        app.world.refresh()
        for frame in 2: await process_frame
        var state: Dictionary = app.sim.snapshot()
        for edge in state.edges:
            var busy := int(edge.occupied) > 0
            var waiting := int(edge.waiters) > 0
            seen["waiting" if waiting else ("active" if busy else "idle")] = true
            var expected := Color("ffc472") if waiting else (Color("53c6b7") if busy else Color("3c4e57"))
            for lane in 2:
                var mesh: MeshInstance3D = app.world._routes[str(edge.id)].get_node("Lane%d" % lane)
                check(mesh.material_override.albedo_color.is_equal_approx(expected), "Actual idle/active/waiting lane material is truthful")
                check(mesh.visible == not bool(edge.lanes[lane].get("blocked", false)), "Material pass preserves blocked lane visibility")
        for bay in state.bulk_bays:
            var occupied := bool(bay.occupied)
            seen["occupied" if occupied else "empty"] = true
            var node: Node3D = app.world._bay_nodes[str(bay.id)]
            check(node.visible == bool(bay.available), "Material pass preserves unavailable bay hiding")
            check(node.get_node("Footprint").material_override.albedo_color.is_equal_approx(Color("3b4950") if occupied else Color("293b45")), "Occupied/empty pad follows actual bay state")
        check(app.sim.export_release_state() == before, "Material pass never changes gameplay or save state")
    for key in seen: check(seen[key], "Real fixture exercised " + key)
    print(JSON.stringify({"suite":"visual_material_roles","checks":checks,"failures":errors,"states_exercised":seen}))
    quit(0 if errors.is_empty() else 1)
