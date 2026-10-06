extends SceneTree
## Headless presentation/domain regression. Native/WebGL pixel and performance
## captures are separate: these checks do not claim physical-device rendering.
const Sim = preload("res://prototype/growth_sim.gd")
const View = preload("res://prototype/growth_view.gd")
var checks := 0
var failures: Array[String] = []
var stages: Dictionary = {}
var mature_active: Dictionary = {}
var max_submitted_triangles := 0
var max_native_rendered_primitives := 0

func _init() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value and label not in failures:
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

func check_human_geometry(actor: Node3D) -> void:
    var bodies := 0
    var heads := 0
    var rounded_triangles := 0
    for child in actor.get_children():
        if not child is MeshInstance3D:
            continue
        var bounds: AABB = child.transform * child.get_aabb()
        if child.mesh is CapsuleMesh:
            bodies += 1
            var capsule := child.mesh as CapsuleMesh
            rounded_triangles += capsule.get_faces().size() / 3
            check(capsule.radial_segments == 8 and capsule.rings == 2, "Human body uses phone-scale low-poly subdivisions")
            check(is_equal_approx(capsule.radius, .18) and is_equal_approx(capsule.height, .62), "Human body's physical radius and height are unchanged")
            check(child.position.is_equal_approx(Vector3(0, .50, 0)), "Human body stays at its original local position")
            check(bounds.position.is_equal_approx(Vector3(-.18, .19, -.18)) and bounds.size.is_equal_approx(Vector3(.36, .62, .36)), "Low-poly body retains original geometric bounds")
        elif child.mesh is SphereMesh:
            heads += 1
            var head := child.mesh as SphereMesh
            rounded_triangles += head.get_faces().size() / 3
            check(head.radial_segments == 8 and head.rings == 3, "Human head uses phone-scale low-poly subdivisions with an equator")
            check(is_equal_approx(head.radius, .16) and is_equal_approx(head.height, .32), "Human head's physical radius and height are unchanged")
            check(child.position.is_equal_approx(Vector3(0, .97, 0)), "Human head stays at its original local position")
            check(bounds.position.is_equal_approx(Vector3(-.16, .81, -.16)) and bounds.size.is_equal_approx(Vector3(.32, .32, .32)), "Low-poly head retains original geometric bounds")
    check(bodies == 1 and heads == 1, "Each human retains exactly one body and one head")
    check(rounded_triangles <= 208, "Human rounded surfaces stay within the 208-triangle render budget")
    check(actor.has_node("CarriedParcel") and actor.has_node("LeftLeg") and actor.has_node("RightLeg"), "Low-poly humans retain cargo and gait nodes")

func check_render_budget(view) -> void:
    var submitted := 0
    for node in view.find_children("*", "MeshInstance3D", true, false):
        if node.is_visible_in_tree() and node.layers != 0 and node.mesh != null:
            submitted += node.mesh.get_faces().size() / 3
    for batch in view._box_batches:
        if not batch.is_visible_in_tree():
            continue
        var instances: MultiMesh = batch.multimesh
        var count := instances.instance_count if instances.visible_instance_count < 0 else mini(instances.instance_count, instances.visible_instance_count)
        # Count even zero-area hidden slots: their vertices are submitted too.
        submitted += (instances.mesh.get_faces().size() / 3) * count
    max_submitted_triangles = maxi(max_submitted_triangles, submitted)
    check(submitted <= 25000, "Whole warehouse submitted 3D geometry remains below 25,000 triangles")
    if DisplayServer.get_name() != "headless":
        var rendered := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
        max_native_rendered_primitives = maxi(max_native_rendered_primitives, rendered)
        # The original-lighting comparison includes a shadow pass. Geometry
        # submission has the same 25k cap; native pass totals have a 50k cap.
        var frame_limit := 25000 if OS.get_environment("FLOTRA_GROWTH_LIGHTING_PROFILE") == "lightweight" else 50000
        check(rendered <= frame_limit, "Actual native rendered primitive count stays within the selected lighting-pass budget")

func check_batches(view) -> void:
    check(view._box_batches.size() == 3, "Generated boxes use only ground, solid and emissive batches")
    var source_ids := {}
    var gpu_readback := DisplayServer.get_name() != "headless"
    var lightweight := OS.get_environment("FLOTRA_GROWTH_LIGHTING_PROFILE") == "lightweight"
    var local_from_world: Transform3D = view.global_transform.affine_inverse()
    for batch_index in view._box_batches.size():
        var batch: MultiMeshInstance3D = view._box_batches[batch_index]
        check(batch.multimesh.visible_instance_count == view._box_batch_sources[batch_index].size(), "Batch slots contain exactly their visible owners")
        var material := batch.material_override as StandardMaterial3D
        check(material != null, "Box batches retain standard opaque 3D materials")
        if material != null:
            check(material.shading_mode == (BaseMaterial3D.SHADING_MODE_PER_VERTEX if lightweight else BaseMaterial3D.SHADING_MODE_PER_PIXEL), "Box shading matches the explicitly selected comparison profile")
            check(material.diffuse_mode == (BaseMaterial3D.DIFFUSE_LAMBERT if lightweight else BaseMaterial3D.DIFFUSE_BURLEY) and material.specular_mode == (BaseMaterial3D.SPECULAR_DISABLED if lightweight else BaseMaterial3D.SPECULAR_SCHLICK_GGX), "Diffuse/specular mode matches the selected lighting profile")
            check(material.vertex_color_use_as_albedo and material.albedo_color == Color.WHITE, "Lightweight profile preserves every authoritative instance color")
            check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Lightweight boxes remain opaque with normal depth occlusion")
            check(material.emission_enabled == (batch_index == 2), "Only the existing emissive group glows")
            if batch_index == 2:
                check(is_equal_approx(material.emission_energy_multiplier, .15) and material.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY, "Emissive route brightness still follows its own instance color")
    var lights := 0
    for child in view.get_children():
        if child is DirectionalLight3D:
            lights += 1
            check(child.shadow_enabled == (not lightweight and lights == 1) and child.light_energy > 0.0, "Key/fill lighting and shadow scope match the selected profile")
    check(lights == 2, "Original key and fill directional lights remain present")
    var submitted_ids := {}
    for group in view._box_batches.size():
        var batch: MultiMeshInstance3D = view._box_batches[group]
        check(batch.cast_shadow == (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "Only real elevated solid equipment casts box shadows")
        for index in view._box_batch_sources[group].size():
            var source: MeshInstance3D = view._box_batch_sources[group][index]
            var id := source.get_instance_id()
            check(not submitted_ids.has(id), "Every visible source is submitted exactly once")
            submitted_ids[id] = true
            check(source.is_visible_in_tree() and view._live_box(source), "Only live visible sources are submitted")
            var material := source.material_override as StandardMaterial3D
            var bounds: AABB = source.global_transform * source.get_aabb()
            var expected_group := 2 if material.emission_enabled else (0 if bounds.end.y <= .12 else 1)
            check(group == expected_group, "Floor and emission categories match real source bounds and material")
            var shape := source.mesh as BoxMesh
            var expected := local_from_world * source.global_transform * Transform3D(Basis.from_scale(shape.size), Vector3.ZERO)
            var mirrored: Array = view._box_batch_states[group][index]
            check(mirrored[0] == id and (mirrored[1] as Transform3D).is_equal_approx(expected), "Batch mirror tracks exact authoritative source identity and geometry")
            check((mirrored[2] as Color).is_equal_approx(material.albedo_color), "Batch mirror follows current dynamic source color")
            if gpu_readback:
                var actual := batch.multimesh.get_instance_transform(index)
                check(actual.is_equal_approx(expected), "GPU batch exactly follows source transform and BoxMesh size")
                var color := batch.multimesh.get_instance_color(index)
                var wanted := material.albedo_color
                check(absf(color.r-wanted.r) <= .004 and absf(color.g-wanted.g) <= .004 and absf(color.b-wanted.b) <= .004 and absf(color.a-wanted.a) <= .004, "GPU batch follows dynamic source color")
    for source in view._box_sources:
        source_ids[source.get_instance_id()] = true
        check(view._live_box(source) and source.layers == 0, "Only live sources remain and direct drawing stays disabled")
        check(submitted_ids.has(source.get_instance_id()) == source.is_visible_in_tree(), "Hidden sources submit no geometry and visible ones have an owner")
    for node in view.find_children("*", "MeshInstance3D", true, false):
        if node.mesh is BoxMesh and view._live_box(node):
            check(source_ids.has(node.get_instance_id()), "Every live generated BoxMesh has a batch source")

func inspect(view, sim, dimensions: Vector2i) -> void:
    # These unchanged whole-floor assertions exercise the explicit overview.
    # work_camera_smoke and work_camera_layouts cover the new default framing.
    view.camera_action("reset")
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
            check_human_geometry(actor)
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
    check_batches(view)
    check_render_budget(view)
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
        for tick in 4:
            active.step(.25)
            view.refresh()
            check_batches(view)
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
            var expected_caption := "棚の容量 %d個" % active.rack_capacity if slot == "shelf" else "梱包 %.1f秒/個" % active.pack_seconds
            check(view._callouts.Selected.label.text == expected_caption, "Mature equipment caption preserves actual capacity and fractional packing time")
            check_batches(view)
            view.preview_slot(slot, "annex")
            view.fit_camera(Vector2(dimensions))
            view.refresh()
            check_callouts(view, dimensions, 2)
            check_batches(view)
            var screen := Rect2(Vector2.ZERO, Vector2(dimensions))
            for point in [view._slots[slot].position, view._ghost.position]:
                check(screen.has_point(view.camera.unproject_position(point)), "Selected equipment and proposed placement remain visible")
            view.select_slot("")
            check_batches(view)
        view.queue_free()
        await settle()
    print(JSON.stringify({"suite":"growth_view_smoke", "checks":checks, "failures":failures, "batch_gpu_readback":DisplayServer.get_name() != "headless", "max_submitted_triangles":max_submitted_triangles, "max_native_rendered_primitives":max_native_rendered_primitives, "scope":"Geometry/cache, triangle budget and batch parity; actual GPU buffer readback only when a native rendering display is used"}))
    quit(0 if failures.is_empty() else 1)
