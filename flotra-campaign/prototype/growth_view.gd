extends "res://prototype/release_view.gd"
## Growth presentation only. Floors, bays, routes and robot identities come from
## the simulation snapshot; this view never creates capacity or moves cargo.

const ROBOT_BODY := Color("d8e8e6")
const ROBOT_DARK := Color("203842")
const CoreGeometry = preload("res://prototype/jobs_sim.gd")
var _growth_root: Node3D
var _growth_floors: Array[MeshInstance3D] = []
var _connector_floors: Array[MeshInstance3D] = []
var _growth_wings: Array[Rect2] = []
var _growth_connectors: Array[Rect2] = []
var _growth_signature := ""
var _human_count := 3
var _rendered_snapshot: Dictionary = {}
var _rendered_selection := ""
var _rendered_preview := ""
var _rendered_ghost_present := false
var _rendered_ghost_position := Vector3.ZERO

func _ready() -> void:
    super._ready()
    _growth_root = Node3D.new()
    _growth_root.name = "AuthoritativeGrowthFloors"
    add_child(_growth_root)

func _build_shell(state: Dictionary) -> void:
    # The inherited shell estimates the original hall from routing bounds.
    # Feeding north-wing trunk nodes into it would widen that hall on reload,
    # while a warehouse expanded during play would retain its original walls.
    # Freeze the original architectural shell to the original graph; purchased
    # additions are rendered independently from their authoritative rectangles.
    var core_state := state.duplicate()
    var core_edges: Array = []
    for edge in state.get("edges", []):
        if CoreGeometry.POINTS.has(str(edge.get("a", ""))) and CoreGeometry.POINTS.has(str(edge.get("b", ""))):
            core_edges.append(edge)
    core_state["edges"] = core_edges
    super._build_shell(core_state)

func refresh() -> void:
    if sim == null or not is_node_ready():
        return
    var state: Dictionary = sim.snapshot()
    var ghost_present := is_instance_valid(_ghost)
    var ghost_position := _ghost.position if ghost_present else Vector3.ZERO
    if is_same(state, _rendered_snapshot) and _selected == _rendered_selection and _preview == _rendered_preview and ghost_present == _rendered_ghost_present and ghost_position == _rendered_ghost_position:
        # Growth snapshots are replaced after every authoritative mutation.
        # Reusing the same immutable snapshot means a paused/unchanged view:
        # retain meshes instead of regrouping cargo and rewriting hidden labels.
        # Camera/viewport changes can still reposition readable screen captions.
        _refresh_callouts()
        return
    _rendered_snapshot = state
    _rendered_selection = _selected
    _rendered_preview = _preview
    _rendered_ghost_present = ghost_present
    _rendered_ghost_position = ghost_position
    _human_count = int(state.get("human_count", state.get("workers", []).size()))
    var changed := _sync_growth_geometry(state)
    super.refresh()
    # The original annex wall must open into the newly purchased, connected
    # working floor rather than visually bisect an authoritative route.
    var old_wall := get_node_or_null("AnnexBackWall") as Node3D
    if old_wall != null:
        old_wall.visible = _growth_wings.is_empty()
    if changed:
        _open_connector_walls()
        var world_data: Dictionary = state.get("world", {})
        var storage_bounds: Rect2 = world_data.get("annex", Rect2(-2, -7.8, 9, 5.8))
        for wing in _growth_wings:
            storage_bounds = storage_bounds.merge(wing)
        _location_data["annex"] = storage_bounds
        _callout_signature = ""
        fit_camera(Vector2(get_viewport().size))

func _sync_growth_geometry(state: Dictionary) -> bool:
    if _growth_root == null:
        return false
    var world_data: Dictionary = state.get("world", {})
    var wings: Array = world_data.get("growth_wings", [])
    var connectors: Array = world_data.get("growth_connectors", [])
    var signature := str(state.get("topology_revision", world_data.get("topology_revision", 0))) + ":" + str(wings) + ":" + str(connectors)
    if signature == _growth_signature:
        return false
    _growth_signature = signature
    for child in _growth_root.get_children():
        _growth_root.remove_child(child)
        child.queue_free()
    _growth_floors.clear()
    _connector_floors.clear()
    _growth_wings.clear()
    _growth_connectors.clear()
    # Inherited routes are deliberately cached by ID. A topology revision is
    # their one rebuild boundary, including removed or relocated graph edges.
    if routes_root != null:
        for child in routes_root.get_children():
            routes_root.remove_child(child)
            child.queue_free()
        _routes.clear()
    var north := INF
    for value in wings:
        if not value is Rect2:
            continue
        var bounds: Rect2 = value.abs()
        if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
            continue
        _growth_wings.append(bounds)
        north = minf(north, bounds.position.y)
    for value in connectors:
        if not value is Rect2:
            continue
        var bounds: Rect2 = value.abs()
        if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
            continue
        _growth_connectors.append(bounds)
        var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
        var foundation := _box(_growth_root, "ServiceConnectorFoundation", Vector3(bounds.size.x, .40, bounds.size.y), center - Vector3(0, .29, 0), NAVY)
        _connector_floors.append(foundation)
        _box(_growth_root, "ServiceConnectorFloor", Vector3(bounds.size.x - .04, .085, bounds.size.y - .04), center - Vector3(0, .047, 0), Color("3b575b"))
    for index in _growth_wings.size():
        var bounds: Rect2 = _growth_wings[index]
        var module := Node3D.new()
        module.name = "GrowthWing_%d" % (index + 1)
        _growth_root.add_child(module)
        var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
        var foundation := _box(module, "GrowthFoundation", Vector3(bounds.size.x, .40, bounds.size.y), center - Vector3(0, .29, 0), NAVY)
        _growth_floors.append(foundation)
        var floor_color := Color("3b575b") if index % 2 == 0 else Color("354f55")
        _box(module, "GrowthWorkingFloor", Vector3(bounds.size.x - .04, .085, bounds.size.y - .04), center - Vector3(0, .047, 0), floor_color)
        _box(module, "ExpansionJoint", Vector3(bounds.size.x, .018, .055), Vector3(center.x, .008, bounds.end.y - .025), TEAL.darkened(.18))
        for x in [bounds.position.x, bounds.end.x]:
            _box(module, "OuterCurb", Vector3(.12, .30, bounds.size.y), Vector3(x, .10, center.z), NAVY)
        # Internal strips share an open floor. Only the actual northern edge
        # receives a back wall; no decorative barrier crosses robot traffic.
        if is_equal_approx(bounds.position.y, north):
            _box(module, "GrowthBackWall", Vector3(bounds.size.x, .65, .12), Vector3(center.x, .25, bounds.position.y), NAVY)
    return true

func _open_connector_walls() -> void:
    # Retain the architectural wall except for actual service-aisle openings.
    # Both old hall back-wall segments can otherwise bisect a new side route.
    for title in ["MainBackWall", "MainBackWallRight"]:
        var wall := get_node_or_null(title) as MeshInstance3D
        if wall == null or not wall.mesh is BoxMesh:
            continue
        wall.visible = true
        var shape := wall.mesh as BoxMesh
        var spans: Array[Vector2] = [Vector2(wall.position.x - shape.size.x * .5, wall.position.x + shape.size.x * .5)]
        var opened := false
        for connector in _growth_connectors:
            if connector.position.y > wall.position.z + shape.size.z * .5 or connector.end.y < wall.position.z - shape.size.z * .5:
                continue
            var remaining: Array[Vector2] = []
            for span in spans:
                var low := maxf(span.x, connector.position.x)
                var high := minf(span.y, connector.end.x)
                if low >= high:
                    remaining.append(span)
                    continue
                opened = true
                if low > span.x:
                    remaining.append(Vector2(span.x, low))
                if high < span.y:
                    remaining.append(Vector2(high, span.y))
            spans = remaining
        if not opened:
            continue
        wall.visible = false
        for span in spans:
            _box(_growth_root, title + "OpenSection", Vector3(span.y - span.x, shape.size.y, shape.size.z), Vector3((span.x + span.y) * .5, wall.position.y, wall.position.z), NAVY)

func fit_camera(view_size: Vector2) -> void:
    if camera == null:
        return
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    var center := _world_center
    var focus := not _selected.is_empty() and _slots.has(_selected)
    if focus:
        center = (_slots[_selected] as Node3D).position
        if is_instance_valid(_ghost):
            center = (center + _ghost.position) * .5
    camera.position = center + Vector3(28, 38, 22)
    camera.look_at(center, Vector3.UP)
    var points: Array[Vector3] = []
    if focus:
        var current: Vector3 = (_slots[_selected] as Node3D).position
        _append_corners(points, AABB(current - Vector3(2.0, .15, 2.0), Vector3(4.0, 3.0, 4.0)))
        if is_instance_valid(_ghost):
            _append_corners(points, AABB(_ghost.position - Vector3(2.0, .15, 2.0), Vector3(4.0, 3.0, 4.0)))
    else:
        for title in ["MainFoundation", "AnnexFoundation"]:
            var floor_mesh := get_node_or_null(title) as MeshInstance3D
            if floor_mesh != null:
                _append_corners(points, floor_mesh.global_transform * floor_mesh.get_aabb())
        for floor_mesh in _growth_floors + _connector_floors:
            if is_instance_valid(floor_mesh):
                _append_corners(points, floor_mesh.global_transform * floor_mesh.get_aabb())
        for slot in _slots.values():
            _append_corners(points, AABB((slot as Node3D).position - Vector3(1.4, .1, 1.5), Vector3(2.8, 2.4, 3.0)))
    if points.is_empty():
        super.fit_camera(view_size)
        return
    var projected := Rect2()
    var first := true
    var inverse := camera.global_transform.affine_inverse()
    for point in points:
        var local: Vector3 = inverse * point
        var xy := Vector2(local.x, -local.y)
        if first:
            projected = Rect2(xy, Vector2.ZERO)
            first = false
        else:
            projected = projected.expand(xy)
    var projected_center := projected.get_center()
    camera.position += camera.basis.x * projected_center.x - camera.basis.y * projected_center.y
    var aspect := maxf(.2, view_size.x / maxf(1.0, view_size.y))
    var padding := Vector2(22, 24) if not focus else Vector2(28, 36)
    var usable := Vector2(maxf(.2, 1.0 - padding.x * 2 / maxf(1, view_size.x)), maxf(.2, 1.0 - padding.y * 2 / maxf(1, view_size.y)))
    camera.size = maxf(projected.size.y / usable.y, projected.size.x / (aspect * usable.x))
    _refresh_callouts()

func _build_worker(id: String) -> Node3D:
    if int(id) < _human_count:
        var human := super._build_worker(id)
        human.set_meta("growth_actor_kind", "human")
        return human
    var robot := Node3D.new()
    robot.name = "Robot_" + id
    robot.set_meta("growth_actor_kind", "robot")
    actors_root.add_child(robot)
    # A compact, low wheeled carrier stays inside the individual .18m radius.
    # The actual manifest remains on the inherited, conserved cargo carrier.
    _box(robot, "RobotChassis", Vector3(.26, .19, .24), Vector3(0, .20, 0), ROBOT_BODY)
    _box(robot, "SafetyVest", Vector3(.24, .045, .22), Vector3(0, .315, 0), TEAL)
    _box(robot, "RobotHead", Vector3(.24, .14, .16), Vector3(0, .405, -.035), ROBOT_BODY)
    var face := _box(robot, "RobotEyes", Vector3(.20, .055, .02), Vector3(0, .415, -.12), TEAL)
    face.material_override = _material(TEAL, true)
    _box(robot, "RobotBeacon", Vector3(.07, .065, .07), Vector3(.085, .505, .02), AMBER)
    for side in [-1, 1]:
        _box(robot, "LeftLeg" if side < 0 else "RightLeg", Vector3(.025, .14, .19), Vector3(float(side) * .135, .10, 0), ROBOT_DARK)
    _parcel(robot, "CarriedParcel", Vector3(0, .60, 0), .43)
    _label(robot, "Waiting", "", Vector3(0, .90, 0), AMBER, 30)
    return robot

func _refresh_workers(workers: Array) -> void:
    # Recruitment may shift the boundary between human and robot IDs. Replace
    # only an actor whose authoritative kind changed, never its simulated work.
    for worker in workers:
        var id := str(worker.get("id", 0))
        var kind := "human" if int(id) < _human_count else "robot"
        if _actors.has(id) and str((_actors[id] as Node3D).get_meta("growth_actor_kind", "human")) != kind:
            var old_actor: Node3D = _actors[id]
            actors_root.remove_child(old_actor)
            old_actor.queue_free()
            _actors.erase(id)
    super._refresh_workers(workers)
    for worker in workers:
        var id := str(worker.get("id", 0))
        if int(id) < _human_count or not _actors.has(id):
            continue
        var robot: Node3D = _actors[id]
        # The inherited human gait must not make a robot's wheels kick.
        (robot.get_node("LeftLeg") as Node3D).rotation.x = 0.0
        (robot.get_node("RightLeg") as Node3D).rotation.x = 0.0
        (robot.get_node("SafetyVest") as Node3D).scale = Vector3.ONE
