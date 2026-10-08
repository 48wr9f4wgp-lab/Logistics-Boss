extends SceneTree
## Visual-only scope: real purchases and packing, unchanged normal camera/save.
## Replaces the deferred optional-inspection test with explicit absence coverage.
const Main = preload("res://prototype/growth_main.gd")
const Sim = preload("res://prototype/dispatch_sim.gd")
const Save = preload("res://prototype/dispatch_save.gd")
var app
var checks := 0
var failures: Array[String] = []
var route_evidence := {}

func _initialize() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func refresh_read_only(label: String) -> void:
    var before := var_to_bytes(app.sim.export_release_state())
    app.world.refresh()
    app.hud.refresh()
    check(before == var_to_bytes(app.sim.export_release_state()), label + ": presentation leaves exact save unchanged")

func finish_job(id: String) -> void:
    check(app.sim.accept_contract(id).ok, "accept earned " + id)
    for tick in 4000:
        if app.sim.finished: break
        app.sim.step(.25)
    check(app.sim.finished, "complete earned " + id)

func check_absence(label: String) -> void:
    check(not app.world.has_method("begin_equipment_inspection"), label + ": no inspection start path")
    check(not app.world.has_method("end_equipment_inspection"), label + ": no inspection return path")
    check(not app.hud.has_signal("equipment_inspection_requested"), label + ": no inspection signal")
    check(app.hud._root.find_child("InspectOwnedAutoPack", true, false) == null, label + ": no inspection entry")

func check_machine_footprint(machine: Node3D, label: String) -> void:
    var inverse: Transform3D = app.world._slots.packing.global_transform.affine_inverse()
    for mesh in machine.get_children():
        if not mesh is MeshInstance3D: continue
        var bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
        check(bounds.position.x >= -.80001 and bounds.end.x <= .80001 and bounds.position.z >= -.50001 and bounds.end.z <= .50001, label + ": " + str(mesh.name) + " stays inside unchanged physical footprint")

func check_cargo_clearance(machine: Node3D, cargo: Node3D, label: String) -> void:
    var carton: MeshInstance3D = cargo.get_node("Carton")
    var parcel_bounds: AABB = carton.global_transform * carton.get_aabb()
    for mesh in machine.get_children():
        if not mesh is MeshInstance3D: continue
        var bounds: AABB = mesh.global_transform * mesh.get_aabb()
        check(not bounds.intersects(parcel_bounds), label + ": " + str(mesh.name) + " clears the actual working carton")

func check_real_traffic() -> void:
    check(app.sim.apply_layout("pack_annex").ok, "use real annex packing layout")
    check(app.sim.accept_contract("route_bulk").ok, "start real bulk traffic route")
    app.world.refresh()
    var old_base := Rect2(3.76, -6.28, 2.48, 1.96)
    var new_base := Rect2(5.0 - .7936, -5.3 - .4802, 1.5872, .97265)
    var old_intersections := 0
    var new_intersections := 0
    var sampled_workers := 0
    var sample := {}
    for tick in 10000:
        if app.sim.finished: break
        app.sim.step(.05)
        for worker in app.sim.workers:
            var p: Vector3 = worker.position
            var radius: float = .25 if worker.carrying and worker.cargo_ids.size() > 1 else .18
            sampled_workers += 1
            if old_base.grow(radius).has_point(Vector2(p.x, p.z)):
                old_intersections += 1
                if sample.is_empty() and worker.carrying and worker.cargo_ids.size() > 1:
                    app.world.refresh()
                    var actor: Node3D = app.world._actors[str(worker.id)]
                    check(actor.global_position.is_equal_approx(p), "real loaded worker render node follows authoritative position")
                    sample = {"worker":worker.id,"time":app.sim.sim_time,"position":[p.x,p.y,p.z],"renderedPosition":[actor.global_position.x,actor.global_position.y,actor.global_position.z],"radius":radius,"cargoCount":worker.cargo_ids.size(),"task":worker.task}
            if new_base.grow(radius).has_point(Vector2(p.x, p.z)):
                new_intersections += 1
    check(app.sim.finished, "real bulk traffic completes")
    check(old_intersections > 0 and not sample.is_empty(), "real loaded cart path reproduces original decorative intrusion")
    check(new_intersections == 0, "same actual worker/cart path clears corrected footprint")
    route_evidence = {"sampledWorkers":sampled_workers,"oldBaseIntersections":old_intersections,"correctedBaseIntersections":new_intersections,"actualLoadedWorkerSample":sample}

func run() -> void:
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    app.hud.show_play()
    refresh_read_only("starter")
    check(app.world._slots.packing.get_node_or_null("VisualAutoPack") == null, "no machine before actual purchase")
    check(app.world._slots.packing.get_node("PackingEquipment").visible, "starter retains ordinary manual packing table")
    finish_job("growth_1")
    finish_job("growth_2")
    var earned: Dictionary = app.sim.export_release_state().duplicate(true)
    app.hud._open_upgrades()
    check_absence("before purchase")
    var wallet: int = app.sim.campaign_wallet
    check(app.sim.buy_upgrade("auto_pack").ok, "real existing auto_pack purchase")
    check(app.sim.campaign_wallet == wallet - 240, "existing purchase price remains 240")
    refresh_read_only("owned")
    check_absence("owned upgrades menu")
    app.hud.show_play()
    app._update_world_visibility()
    app.world.cancel_pointer_input()
    # The menu guard is time based. Wait before using the ordinary camera path.
    var until := Time.get_ticks_msec() + 250
    while Time.get_ticks_msec() < until or app.hud._background_input_blocked():
        await process_frame
    var machine: Node3D = app.world._slots.packing.get_node_or_null("VisualAutoPack")
    check(machine != null and machine.visible, "purchase shows machine in normal warehouse")
    if machine == null:
        quit(1)
        return
    check(not app.world._slots.packing.get_node("PackingEquipment").visible, "owned machine replaces manual model")
    check_machine_footprint(machine, "idle machine")
    check(app.world._selected.is_empty(), "machine appears without selection or a special camera")
    check(app.viewport_container.visible, "normal warehouse remains visible")
    var state := var_to_bytes(app.sim.export_release_state())
    app.world.camera_action("in")
    check(app.world._camera_zoom > 1, "normal camera zoom still works")
    app.world.camera_action("right")
    check(app.world._camera_turn == 1, "normal camera quarter turn still works")
    app.world._camera_mouse_down = true
    app.world.camera_action("reset")
    check(app.world._camera_zoom == 1 and app.world._camera_turn == 0 and app.world._camera_pan == Vector2.ZERO, "normal reset restores overview")
    check(not app.world._camera_mouse_down and app.world._camera_touches.is_empty(), "normal reset cancels held gestures")
    check(state == var_to_bytes(app.sim.export_release_state()), "camera flow leaves exact save unchanged")
    check(app.sim.accept_contract("growth_2").ok, "start real packing job")
    for tick in 8000:
        if not app.sim.pack_jobs.is_empty(): break
        app.sim.step(.05)
    check(not app.sim.pack_jobs.is_empty(), "fixture reaches actual packing work")
    if app.sim.pack_jobs.is_empty():
        quit(1)
        return
    refresh_read_only("packing")
    var cargo_id: int = app.sim.pack_jobs[0].cargo_id
    check(int(machine.get_meta("actual_pack_cargo_id")) == cargo_id, "head is linked to an actual pack_jobs cargo ID")
    var head: Node3D = machine.get_node("SealingHead")
    var cargo: Node3D = app.world._cargo[str(cargo_id)]
    check(is_equal_approx(head.global_position.x, cargo.global_position.x) and is_equal_approx(head.global_position.z, cargo.global_position.z), "head follows actual rendered cargo position after footprint scaling")
    check_machine_footprint(machine, "active machine")
    check_cargo_clearance(machine, cargo, "active machine")
    var fraction: float = clampf(1.0 - float(app.sim.pack_jobs[0].remaining) / app.sim.pack_seconds, 0.0, 1.0)
    check(is_equal_approx(float(machine.get_meta("actual_pack_fraction")), fraction), "animation progress derives from remaining packing work")
    var original_head: Vector3 = head.position
    app.sim.step(.05)
    refresh_read_only("advanced packing")
    check(int(machine.get_meta("actual_pack_cargo_id")) == cargo_id and head.position != original_head, "actual work progression moves the same cargo's sealing head")
    # Sample every remaining domain tick of this exact parcel's press cycle.
    # All supporting solids and the moving head must clear its real mesh.
    while not app.sim.pack_jobs.is_empty() and int(app.sim.pack_jobs[0].cargo_id) == cargo_id:
        app.world.refresh()
        check_cargo_clearance(machine, cargo, "sealing cycle")
        if float(app.sim.pack_jobs[0].remaining) <= .05: break
        app.sim.step(.05)
    # No domain step: advancing rendered frames and decorative pulse cannot move it.
    var paused_head: Vector3 = head.position
    state = var_to_bytes(app.sim.export_release_state())
    for frame in 8:
        app.world._process(.25)
        app.world.refresh()
        await process_frame
    check(head.position == paused_head, "paused head remains exactly still across rendered frames")
    check(state == var_to_bytes(app.sim.export_release_state()), "paused visuals preserve in-flight state byte-for-byte")
    var encoded: String = Save.new().encode(app.sim.export_release_state())
    var decoded: Dictionary = Save.new().decode(encoded)
    check(decoded.ok, "existing schema5 save accepts exact active packing state")
    var restored = Sim.new()
    check(restored.import_release_state(decoded.data).ok, "existing importer restores active packing state")
    check(var_to_bytes(restored.export_release_state()) == state, "active cargo save/resume remains exact")
    check(restored.pack_jobs == app.sim.pack_jobs, "in-flight packing work is unchanged by save/resume")
    # The machine goes idle when authoritative packing work ends.
    for tick in 8000:
        if app.sim.finished: break
        app.sim.step(.05)
    check(app.sim.finished and app.sim.pack_jobs.is_empty(), "actual job finishes with no packing work")
    refresh_read_only("finished")
    check(int(machine.get_meta("actual_pack_cargo_id")) == -1 and float(machine.get_meta("actual_pack_fraction")) == 0, "idle machine has no invented cargo or progress")
    check(head.position == Vector3(0, 1.33, -.26), "idle sealing head returns to rest")
    check_real_traffic()
    # Reloading an earlier genuine unowned save cannot leave a purchased machine visible.
    check(app.sim.import_release_state(earned).ok, "reload genuine pre-purchase earned state")
    refresh_read_only("restored unowned")
    # A layout change can rebuild its visual slot. Inspect the current slot,
    # never the stale node retained from before the real relocation above.
    var current_machine: Node3D = app.world._slots.packing.get_node_or_null("VisualAutoPack")
    check((current_machine == null or not current_machine.visible) and app.world._slots.packing.get_node("PackingEquipment").visible, "unowned state restores manual table and hides machine")
    check(app.sim.check_invariants().ok, "cargo/domain invariants remain valid")
    check(not app.persistence_enabled, "all coverage uses an isolated no-save app")
    print("VISUAL_GROWTH_ONLY " + JSON.stringify({"checks":checks,"failures":failures,"routeEvidence":route_evidence}))
    app.queue_free()
    await process_frame
    quit(0 if failures.is_empty() else 1)
