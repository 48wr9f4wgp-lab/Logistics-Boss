extends SceneTree
## Headless presentation/domain regression. Native/WebGL pixel and performance
## captures are separate: these checks do not claim physical-device rendering.
const Sim = preload("res://prototype/growth_sim.gd")
const View = preload("res://prototype/growth_view.gd")
var checks := 0
var failures: Array[String] = []
var stages: Dictionary = {}
var mature_active: Dictionary = {}

func _init() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func finish(sim) -> void:
    for second in 1800:
        sim.step(1.0)
        if sim.finished:
            check(sim.check_invariants().ok, "Fixture finishes with every unit conserved")
            return
    check(false, "Fixture contract completes within bounded horizon")

func prepare_stages() -> void:
    var sim = Sim.new()
    stages[0] = sim.export_release_state()
    for number in range(1, 7):
        check(sim.accept_contract("growth_%d" % number).ok, "Fixture accepts actual milestone")
        finish(sim)
    # Every fixture is earned through public domain actions, including repeat
    # work when needed. No wallet, cargo, geometry or unlock is injected.
    for definition in Sim.GROWTH_UPGRADES:
        for attempt in 30:
            if sim.campaign_wallet >= int(definition.cost):
                break
            check(sim.accept_contract("growth_1").ok, "Fixture can earn its next purchase")
            finish(sim)
        check(sim.buy_upgrade(str(definition.id)).ok, "Fixture buys " + str(definition.id))
        stages[sim._wing_count()] = sim.export_release_state()
    check(stages.has_all([0, 1, 2, 3, 4]), "All four real expansion stages are available")
    check(sim.accept_contract("route_hub").ok, "Mature fixture accepts qualifying dispatch")
    sim.step(85.0)
    mature_active = sim.export_release_state()
    check(sim.check_invariants().ok, "Active mature fixture retains conserved cargo")

func settle() -> void:
    for frame in 3:
        await process_frame

func check_callouts(view, dimensions: Vector2i, expected: int) -> void:
    var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
    var occupied: Array[Rect2] = []
    for item in view._callouts.values():
        var label: Label = item.label
        if not label.visible:
            continue
        check(label.get_theme_font_size("font_size") >= 18, "World text remains at least 18 logical pixels")
        check(screen.encloses(label.get_rect()), "World caption stays inside actual viewport")
        check(label.size.x >= label.get_minimum_size().x, "World caption retains its natural width")
        check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "World caption never steals a touch")
        for rect in occupied:
            check(not rect.intersects(label.get_rect()), "World captions remain separated")
        occupied.append(label.get_rect())
    check(occupied.size() == expected, "Only key locations or selected equipment are labeled")
    for label in view.find_children("*", "Label3D", true, false):
        check(not label.visible, "No scaled-down 3D labels are visible")

func check_floor(view, mesh: MeshInstance3D, dimensions: Vector2i) -> void:
    var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
    for index in 8:
        var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(index)
        check(screen.has_point(view.camera.unproject_position(point)), "Every actual floor corner fits the overview")

func check_walls(view) -> void:
    for child in view._growth_root.get_children():
        if not child is MeshInstance3D or not str(child.name).contains("OpenSection"):
            continue
        var bounds: AABB = child.transform * child.get_aabb()
        var footprint := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
        for connector in view._growth_connectors:
            check(footprint.intersection(connector).get_area() <= 0.00001, "Retained hall wall never crosses a service connector")

func inspect(view, sim, dimensions: Vector2i) -> void:
    view.refresh()
    view.fit_camera(Vector2(dimensions))
    var state: Dictionary = sim.snapshot()
    check(view._growth_floors.size() == state.world.growth_wings.size(), "Exactly one foundation per purchased wing")
    check(view._connector_floors.size() == state.world.growth_connectors.size(), "Exactly one foundation per authoritative connector")
    check(view._routes.size() == state.edges.size(), "Every current route has one visual and obsolete routes are removed")
    for title in ["MainFoundation", "AnnexFoundation"]:
        check_floor(view, view.get_node(title), dimensions)
    for mesh in view._growth_floors + view._connector_floors:
        check_floor(view, mesh, dimensions)
    check(view._actors.size() == sim.workers.size(), "Actor count equals the actual workforce")
    var robots := 0
    for worker in sim.workers:
        var actor: Node3D = view._actors[str(worker.id)]
        var is_robot: bool = int(worker.id) >= int(state.human_count)
        check((actor.get_meta("growth_actor_kind") == "robot") == is_robot, "Actor kind matches current human/robot identity")
        if not is_robot:
            continue
        robots += 1
        check(actor.has_node("RobotChassis") and actor.has_node("RobotEyes"), "Courier robot has distinct physical body and face")
        check(is_zero_approx(actor.get_node("LeftLeg").rotation.x) and is_zero_approx(actor.get_node("RightLeg").rotation.x), "Robot wheels never inherit the human kicking gait")
        for title in ["RobotChassis", "SafetyVest", "RobotHead", "RobotEyes", "RobotBeacon", "LeftLeg", "RightLeg"]:
            var mesh := actor.get_node(title) as MeshInstance3D
            var bounds: AABB = mesh.transform * mesh.get_aabb()
            for index in 8:
                var point := bounds.get_endpoint(index)
                check(Vector2(point.x, point.z).length() <= Sim.WORKER_RADIUS + .00001, "Robot body remains inside its reserved movement radius")
    check(robots == int(state.robot_count), "No decorative extra robots exist")
    check(view.get_node("AnnexBackWall").visible == state.world.growth_wings.is_empty(), "Original annex opens only when connected expansion exists")
    check(view._callouts.Storage.label.text == "保管床 %d枠" % sim.bulk_capacity(), "Capacity caption reports authoritative usable bays")
    check_callouts(view, dimensions, 3)
    check_walls(view)
    var saved: Dictionary = sim.export_release_state()
    var cached: PackedByteArray = var_to_bytes(sim.snapshot())
    var nodes: int = view.find_children("*", "", true, false).size()
    var materials: int = view._materials.size()
    for frame in 12:
        view.refresh()
    check(view.find_children("*", "", true, false).size() == nodes, "Unchanged refreshes never grow the scene")
    check(view._materials.size() == materials, "Unchanged refreshes never grow the material cache")
    check(sim.export_release_state() == saved, "Rendering never mutates saved authoritative state")
    check(var_to_bytes(sim.snapshot()) == cached, "Rendering never mutates the shared cached snapshot")

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    prepare_stages()
    if not failures.is_empty():
        print(JSON.stringify({"suite":"growth_view_smoke", "checks":checks, "failures":failures}))
        quit(1)
        return
    for dimensions in [Vector2i(375, 271), Vector2i(375, 371), Vector2i(390, 548), Vector2i(430, 636)]:
        root.size = dimensions
        var view = View.new()
        root.add_child(view)
        view.bind_sim(Sim.new())
        await settle()
        var core_bounds: AABB = view.get_node("MainFoundation").get_aabb()
        var core_transform: Transform3D = view.get_node("MainFoundation").transform
        # Load earlier stages as well as later ones into the same view to expose
        # stale bays/routes, wall openings, robot kinds or material accumulation.
        for count in [0, 1, 2, 3, 4, 2, 0, 4]:
            var sim = Sim.new()
            check(sim.import_release_state(stages[count]).ok, "Earned expansion-stage fixture imports")
            view.bind_sim(sim)
            await settle()
            inspect(view, sim, dimensions)
        var active = Sim.new()
        check(active.import_release_state(mature_active).ok, "Active mature fixture imports")
        view.bind_sim(active)
        await settle()
        inspect(view, active, dimensions)
        var loaded_view = View.new()
        root.add_child(loaded_view)
        loaded_view.bind_sim(active)
        await settle()
        check(loaded_view.get_node("MainFoundation").get_aabb() == core_bounds and loaded_view.get_node("MainFoundation").transform == core_transform, "Loaded mature warehouse retains identical original hall bounds")
        loaded_view.queue_free()
        await settle()
        for slot in ["shelf", "packing"]:
            view.select_slot(slot)
            view.fit_camera(Vector2(dimensions))
            check_callouts(view, dimensions, 1)
            view.preview_slot(slot, "annex")
            view.fit_camera(Vector2(dimensions))
            view.refresh()
            check_callouts(view, dimensions, 2)
            var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
            for point in [view._slots[slot].position, view._ghost.position]:
                check(screen.has_point(view.camera.unproject_position(point)), "Selected equipment and proposed placement remain visible")
            view.select_slot("")
        view.queue_free()
        await settle()
    print(JSON.stringify({"suite":"growth_view_smoke", "checks":checks, "failures":failures, "scope":"Headless real-state geometry/cache checks, not rendered device performance"}))
    quit(0 if failures.is_empty() else 1)
