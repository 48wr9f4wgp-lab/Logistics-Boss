extends SceneTree
const Main = preload("res://prototype/growth_main.gd")
const Sim = preload("res://prototype/dispatch_sim.gd")
var failures: Array[String] = []
var checks := 0
var output := OS.get_environment("FLOTRA_LINE_FIXTURES")
func fixture(name: String, sim) -> void:
    if output.is_empty(): return
    DirAccess.make_dir_recursive_absolute(output)
    var file := FileAccess.open(output.path_join(name + ".json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({"encoded": preload("res://prototype/dispatch_save.gd").new().encode(sim.export_release_state())}))
func _init() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)
        push_error(message)
func finish(sim, id: String) -> void:
    check(sim.accept_contract(id).ok, "accept " + id)
    for i in 10000:
        if sim.finished: break
        sim.step(.05)
    check(sim.finished, "finish " + id)
func run() -> void:
    var app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    finish(app.sim, "growth_1")
    finish(app.sim, "growth_2")
    var before_purchase: Dictionary = app.sim.export_release_state().duplicate(true)
    fixture("before", app.sim)
    check(app.sim.buy_upgrade("auto_pack").ok, "existing purchase connects all three modules")
    check(app.sim.campaign_wallet == 200, "100 + 140 + 200 - 240; no new charge")
    fixture("owned", app.sim)
    check(app.sim.accept_contract("growth_2").ok, "start actual parcel work")
    var phases := {}
    var last_x := -INF
    var tracked := -1
    var nodes := -1
    for tick in 5000:
        if app.sim.finished: break
        app.sim.step(.05)
        var state := var_to_bytes(app.sim.export_release_state())
        app.world.refresh()
        check(state == var_to_bytes(app.sim.export_release_state()), "view never mutates ledger")
        var machine: Node3D = app.world._slots.packing.get_node("VisualAutoPack")
        var line: Node3D = machine.get_node("ConnectedLine")
        if nodes == -1: nodes = line.get_child_count()
        check(line.get_child_count() == nodes and nodes == 11, "constant 11 line meshes; no per-frame nodes")
        if app.sim.pack_jobs.is_empty(): continue
        var id: int = app.sim.pack_jobs[0].cargo_id
        var parcel: Node3D = app.world._cargo[str(id)]
        var point: Vector3 = line.to_local(parcel.global_position)
        if tracked != id:
            tracked = id
            last_x = -INF
        check(point.x >= last_x - .00001, "same real parcel moves only forward")
        last_x = point.x
        var phase: String = machine.get_meta("line_phase")
        if not phases.has(phase): fixture(phase, app.sim)
        phases[phase] = true
        check(point.x >= -.50001 and point.x <= .50001, "parcel remains within station")
        for mesh in line.get_children():
            var bounds: AABB = (app.world._slots.packing.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
            check(bounds.position.x >= -.80001 and bounds.end.x <= .80001 and bounds.position.z >= -.50001 and bounds.end.z <= .50001, "line footprint " + str(mesh.name))
            var carton: MeshInstance3D = parcel.get_node("Carton")
            check(not (mesh.global_transform * mesh.get_aabb()).intersects(carton.global_transform * carton.get_aabb()), "line mechanism clears actual carton " + str(mesh.name))
        var arm: Node3D = line.get_node("Gripper")
        if phase == "transfer": check(is_equal_approx(arm.position.x, point.x), "arm follows actual outgoing parcel")
        var updates: int = line.get_meta("motion_updates")
        var frozen := [parcel.transform, arm.transform, machine.get_node("SealingHead").transform]
        app.world._process(.5)
        app.world.set_reduced_motion(not app.world.reduced_motion)
        app.world.refresh()
        check(frozen == [parcel.transform, arm.transform, machine.get_node("SealingHead").transform], "pause freezes all process motion")
        check(int(line.get_meta("motion_updates")) == updates, "unchanged mechanisms skip writes even after view invalidation")
        var restored = Sim.new()
        check(restored.import_release_state(app.sim.export_release_state()).ok, "active line imports with unchanged schema")
        check(state == var_to_bytes(restored.export_release_state()), "exact in-flight save round trip")
    check(phases.size() == 3, "real run traverses belt, sealing and transfer")
    check(app.sim.finished and app.sim.shipped == 24 and app.sim.check_invariants().ok, "no invented output")
    for layout in ["clear_aisle", "pack_annex", "split", "compact"]:
        check(app.sim.apply_layout(layout).ok, "existing free layout " + layout)
        app.world.refresh()
        var cell: Node3D = app.world._slots.packing
        var line: Node3D = cell.get_node("VisualAutoPack/ConnectedLine")
        check(line.global_position.is_equal_approx(cell.global_position), "all modules follow packing layout " + layout)
        check(line.get_child_count() == 11, "relocation builds exactly one connected line")
    check(app.sim.import_release_state(before_purchase).ok, "restore older unowned save")
    app.world.refresh()
    check(not app.world._slots.packing.get_node("VisualAutoPack").visible, "old unowned save restores manual equipment")
    print("AUTOMATION_LINE " + JSON.stringify({"checks": checks, "failures": failures, "phases": phases, "additional_meshes": nodes}))
    app.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
