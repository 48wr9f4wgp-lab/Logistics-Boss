extends "res://prototype/release_view.gd"
## Growth presentation only. Floors, bays, routes and robot identities come from
## the simulation snapshot; this view never creates capacity or moves cargo.

const ROBOT_BODY := Color("d8e8e6")
const ROBOT_DARK := Color("203842")
const HUMAN_RADIAL_SEGMENTS := 8
const HUMAN_CAPSULE_RINGS := 2
const HUMAN_HEAD_RINGS := 3 # Include the equator, retaining the full head diameter.
const CoreGeometry = preload("res://prototype/jobs_sim.gd")
const HIDDEN_BOX_TRANSFORM := Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
var _box_sources: Array[MeshInstance3D] = []
var _box_batches: Array[MultiMeshInstance3D] = []
var _box_batch_states: Array = []
var _box_batch_sources: Array = [[], [], []]
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
var reduced_motion := false
var visible_growth_enabled := true
# Session-only view preferences, deliberately independent of saved game state
# and the layout editor's automatic equipment framing.
const CAMERA_MAX_ZOOM := 3.0
const CAMERA_DRAG_THRESHOLD := 8.0
var _camera_zoom := 1.0
var _camera_turn := 0
var _camera_pan := Vector2.ZERO
var _camera_fit_size := 1.0
var _camera_fit_position := Vector3.ZERO
var _camera_projected_size := Vector2.ONE
var _camera_view_size := Vector2(390, 500)
var _camera_touches: Dictionary = {}
var _camera_dragging := false
var _camera_mouse_down := false
var _camera_last := Vector2.ZERO
var _camera_start := Vector2.ZERO
var _camera_touch_slot := ""
var camera_input_gate: Callable


func set_reduced_motion(value: bool) -> void:
    if reduced_motion == value: return
    reduced_motion = value
    _rendered_snapshot = {}
    refresh()

func _process(delta: float) -> void:
    # Keep physical cargo transport visible. Only the decorative walking cycle
    # is suppressed; no clock, processing rate, route or entity is changed.
    if not reduced_motion:
        _pulse += delta

func _ready() -> void:
    super._ready()
    # Existing lights only: a warmer key and quieter ambient fill give the
    # unchanged box faces readable depth without a new lighting/shadow pass.
    var light_index := 0
    for child in get_children():
        if child is WorldEnvironment:
            child.environment.ambient_light_energy = .30
            child.environment.ambient_light_color = Color("aabdc9")
        elif child is DirectionalLight3D:
            child.light_energy = .86 if light_index == 0 else .16
            light_index += 1
    _make_box_batches()
    _growth_root = Node3D.new()
    _growth_root.name = "AuthoritativeGrowthFloors"
    add_child(_growth_root)

func _make_box_batches() -> void:
    var cube := BoxMesh.new()
    cube.size = Vector3.ONE
    # Ground markings receive shadows but never cast a second floor onto
    # themselves. Genuine equipment/wall casters keep the original key light.
    for group in 3:
        var emissive := group == 2
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.WHITE
        material.roughness = 1.0 if group == 0 else .82
        material.metallic_specular = .15 if group == 0 else .5
        material.vertex_color_use_as_albedo = true
        material.emission_enabled = emissive
        if emissive:
            material.emission = Color.WHITE
            material.emission_energy_multiplier = .15
            material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
        var instances := MultiMesh.new()
        instances.transform_format = MultiMesh.TRANSFORM_3D
        instances.use_colors = true
        instances.mesh = cube
        var batch := MultiMeshInstance3D.new()
        batch.name = ["GroundBoxBatch", "WarehouseBoxBatch", "EmissiveBoxBatch"][group]
        batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group == 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        batch.multimesh = instances
        batch.material_override = material
        add_child(batch)
        _box_batches.append(batch)

func _box(parent: Node, title: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    # Cohesive industrial materials: concrete is quieter than live cyan routes.
    # Keep all dimensions, positions and inherited source identities unchanged.
    var tint := color
    if title.ends_with("Foundation"):
        tint = Color("132735")
    elif title == "MainWorkingFloor":
        tint = Color("41484d")
    elif title in ["AnnexWorkingFloor", "GrowthWorkingFloor"]:
        tint = Color("2e404a")
    elif title == "ServiceConnectorFloor":
        tint = Color("354b52")
    elif title == "InboundReceivingPad":
        tint = Color("3d5a6a")
    elif title == "OutboundReceivingPad":
        tint = Color("37645e")
    elif title == "ExpansionJoint":
        tint = Color("637780")
    elif title == "SlabJoint":
        tint = Color("4a5257")
    elif title == "RackPost":
        tint = Color("d9994c")
    elif title in ["RackShelf", "ExtraShelf"]:
        tint = Color("263b49")
    elif title == "RackBeam":
        tint = Color("e6a859")
    var source := super._box(parent, title, size, position, tint)
    # Keep the original named node for authoritative transform/visibility,
    # selection geometry and existing tests. Only the batched copy is drawn.
    # A zero layer mask leaves `visible` available to the inherited renderer.
    source.layers = 0
    _box_sources.append(source)
    # A narrow cap remains inside each existing cutaway wall. Parenting it to
    # the authoritative wall makes connector openings and hidden walls exact.
    if title in ["AnnexBackWall", "AnnexLeftWall", "AnnexRightWall", "MainBackWall", "MainBackWallRight", "GrowthBackWall", "OuterCurb"] or title.ends_with("OpenSection"):
        _box(source, "WallCap", Vector3(size.x, .035, size.z), Vector3(0, size.y * .5 - .0175, 0), Color("657b85"))
    return source

func _live_box(source: MeshInstance3D) -> bool:
    if not is_instance_valid(source) or not source.is_inside_tree():
        return false
    var ancestor: Node = source
    while ancestor != null and ancestor != self:
        if ancestor.is_queued_for_deletion():
            return false
        ancestor = ancestor.get_parent()
    return true

func _refresh_box_batches() -> void:
    if _box_batches.is_empty():
        return
    var sources: Array[MeshInstance3D] = []
    var grouped: Array = [[], [], []]
    for source in _box_sources:
        if not _live_box(source):
            continue
        sources.append(source)
        if not source.is_visible_in_tree():
            continue
        var material := source.material_override as StandardMaterial3D
        var bounds := source.global_transform * source.get_aabb()
        var floor_level := bounds.end.y <= .12
        var group := 2 if material != null and material.emission_enabled else (0 if floor_level else 1)
        grouped[group].append(source)
    _box_sources = sources
    # Pack only visible sources into their one owning batch. Adding the ground
    # category must not submit three zero-sized copies of every source cube.
    var local_from_world := global_transform.affine_inverse()
    if _box_batch_states.size() != _box_batches.size():
        _box_batch_states = [[], [], []]
    for group in _box_batches.size():
        var instances: MultiMesh = _box_batches[group].multimesh
        var members: Array = grouped[group]
        if instances.instance_count < members.size():
            # Reserve in small blocks: busy lanes change emissive category and
            # must not reallocate GPU buffers on every authoritative step.
            instances.instance_count = ceili(float(members.size()) / 32.0) * 32
            _box_batch_states[group] = []
            _box_batch_states[group].resize(instances.instance_count)
        if instances.visible_instance_count != members.size():
            instances.visible_instance_count = members.size()
        for index in members.size():
            var source: MeshInstance3D = members[index]
            var material := source.material_override as StandardMaterial3D
            var color := material.albedo_color if material != null else Color.WHITE
            var shape := source.mesh as BoxMesh
            var transform := local_from_world * source.global_transform * Transform3D(Basis.from_scale(shape.size), Vector3.ZERO)
            var state: Array = [source.get_instance_id(), transform, color]
            if _box_batch_states[group][index] is Array and _box_batch_states[group][index] == state:
                continue
            instances.set_instance_transform(index, transform)
            instances.set_instance_color(index, color)
            _box_batch_states[group][index] = state
        _box_batch_sources[group] = members

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
    _refresh_visual_auto_pack()
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
    _refresh_box_batches()

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
    _camera_view_size = view_size
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    var center := _world_center
    var focus := not _selected.is_empty() and _slots.has(_selected)
    if focus:
        center = (_slots[_selected] as Node3D).position
        if is_instance_valid(_ghost):
            center = (center + _ghost.position) * .5
    # Let the long real northward warehouse use portrait height. Selected
    # equipment retains its established framing and all corners are still fit.
    var bearing := Vector3(28, 38, 22)
    if not focus:
        bearing = bearing.rotated(Vector3.UP, float(_camera_turn) * PI * .5)
    camera.position = center + bearing
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
    if not focus:
        _camera_fit_size = camera.size
        _camera_fit_position = camera.position
        _camera_projected_size = projected.size
        _apply_camera_view()
    else:
        _refresh_callouts()

func _apply_camera_view() -> void:
    if camera == null or not _selected.is_empty(): return
    camera.size = _camera_fit_size / _camera_zoom
    var aspect := _camera_view_size.x / maxf(1, _camera_view_size.y)
    # At least a substantial edge of the warehouse stays in view. Bounds use
    # all actual wing/connector corners in the CURRENT camera bearing.
    var visible_extent := Vector2(camera.size * aspect, camera.size)
    var limit := (_camera_projected_size * .5 - visible_extent * .25).max(_camera_projected_size * .12)
    _camera_pan = _camera_pan.clamp(-limit, limit)
    # Rectangular projected bounds contain empty diagonal corners around the
    # isometric footprint. Round the pan envelope so those corners cannot
    # leave the player looking at an almost-empty viewport.
    var normalized_pan := _camera_pan / limit.max(Vector2(.001, .001))
    if normalized_pan.length() > 1.0:
        _camera_pan /= normalized_pan.length()
    camera.position = _camera_fit_position + camera.basis.x * _camera_pan.x + camera.basis.y * _camera_pan.y
    _refresh_callouts()

func camera_action(action: String) -> void:
    if not _camera_allowed(): return
    cancel_pointer_input()
    match action:
        "reset":
            _camera_zoom = 1.0
            _camera_turn = 0
            _camera_pan = Vector2.ZERO
            fit_camera(_camera_view_size)
        "left", "right":
            _camera_turn = posmod(_camera_turn + (-1 if action == "left" else 1), 4)
            _camera_pan = Vector2.ZERO
            fit_camera(_camera_view_size)
        "in", "out":
            _zoom_camera(1.25 if action == "in" else .8, _camera_view_size * .5)

func _camera_allowed() -> bool:
    return _selected.is_empty() and (not input_gate.is_valid() or input_gate.call()) and (not camera_input_gate.is_valid() or camera_input_gate.call())

func _pan_camera(delta: Vector2) -> void:
    var scale := camera.size / maxf(1, _camera_view_size.y)
    _camera_pan += Vector2(-delta.x, delta.y) * scale
    _apply_camera_view()

func _zoom_camera(factor: float, anchor: Vector2) -> void:
    var before := camera.size
    _camera_zoom = clampf(_camera_zoom * factor, 1.0, CAMERA_MAX_ZOOM)
    var after := _camera_fit_size / _camera_zoom
    var offset := anchor - _camera_view_size * .5
    _camera_pan += Vector2(offset.x, -offset.y) * (before - after) / maxf(1, _camera_view_size.y)
    _apply_camera_view()

func _touch_pair() -> Array[Vector2]:
    var keys := _camera_touches.keys()
    return [_camera_touches[keys[0]], _camera_touches[keys[1]]]

func _unhandled_input(event: InputEvent) -> void:
    # When either OS emulation option is enabled, handle only the original
    # device stream in the world. GUI buttons keep Godot's normal emulation.
    if event.device == InputEvent.DEVICE_ID_EMULATION and (event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag): return
    if event is InputEventScreenTouch and event.canceled:
        cancel_pointer_input()
        return
    # The editor retains its original precise tap/preview workflow.
    if not _selected.is_empty():
        super._unhandled_input(event)
        return
    if not _camera_allowed():
        cancel_pointer_input()
        return
    if event is InputEventMouseButton:
        # Touch already has stable identities; its emulated mouse duplicate
        # must not pan twice or select equipment after a pinch.
        if event.device == InputEvent.DEVICE_ID_EMULATION: return
        if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            _zoom_camera(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15, event.position)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _camera_mouse_down = true
                _camera_dragging = false
                _camera_last = event.position
                _camera_start = event.position
                _camera_touch_slot = _slot_at(event.position)
            else:
                var select := _camera_mouse_down and not _camera_dragging and _camera_start.distance_to(event.position) < CAMERA_DRAG_THRESHOLD
                var slot := _camera_touch_slot
                cancel_pointer_input()
                if select: _select_camera_tap(slot, event.position)
    elif event is InputEventMouseMotion:
        if event.device == InputEvent.DEVICE_ID_EMULATION: return
        if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
            if _camera_mouse_down: cancel_pointer_input()
            return
        if not _camera_mouse_down: return
        if _camera_start.distance_to(event.position) >= CAMERA_DRAG_THRESHOLD:
            _camera_dragging = true
        if _camera_dragging: _pan_camera(event.position - _camera_last)
        _camera_last = event.position
    elif event is InputEventScreenTouch:
        if event.canceled:
            cancel_pointer_input()
            return
        if event.pressed:
            _camera_touches[event.index] = event.position
            if _camera_touches.size() == 1:
                _camera_dragging = false
                _camera_start = event.position
                _camera_touch_slot = _slot_at(event.position)
            else:
                _camera_dragging = true
                _camera_touch_slot = ""
        elif _camera_touches.has(event.index):
            var select := _camera_touches.size() == 1 and not _camera_dragging and _camera_start.distance_to(event.position) < CAMERA_DRAG_THRESHOLD
            var slot := _camera_touch_slot
            _camera_touches.erase(event.index)
            if _camera_touches.is_empty():
                cancel_pointer_input()
            if select: _select_camera_tap(slot, event.position)
    elif event is InputEventScreenDrag and _camera_touches.has(event.index):
        if _camera_touches.size() == 2:
            var before := _touch_pair()
            _camera_touches[event.index] = event.position
            var after := _touch_pair()
            _pan_camera((after[0] + after[1] - before[0] - before[1]) * .5)
            var distance := before[0].distance_to(before[1])
            if distance >= 10:
                _zoom_camera(clampf(after[0].distance_to(after[1]) / distance, .75, 1.3334), (after[0] + after[1]) * .5)
        elif _camera_touches.size() == 1:
            if _camera_start.distance_to(event.position) >= CAMERA_DRAG_THRESHOLD:
                _camera_dragging = true
            if _camera_dragging: _pan_camera(event.position - Vector2(_camera_touches[event.index]))
            _camera_touches[event.index] = event.position
        else:
            _camera_touches[event.index] = event.position

func _select_camera_tap(slot: String, point: Vector2) -> void:
    if not slot.is_empty() and slot == _slot_at(point):
        select_slot(slot)
        slot_selected.emit(slot)

func cancel_pointer_input() -> void:
    super.cancel_pointer_input()
    _camera_touches.clear()
    _camera_mouse_down = false
    _camera_dragging = false
    _camera_touch_slot = ""

func camera_metrics() -> Dictionary:
    return {"zoom":_camera_zoom, "turn":_camera_turn, "panX":_camera_pan.x, "panY":_camera_pan.y,
        "size":camera.size, "fitSize":_camera_fit_size, "touches":_camera_touches.size(), "mouseDown":_camera_mouse_down}

func _build_worker(id: String) -> Node3D:
    if int(id) < _human_count:
        var human := super._build_worker(id)
        # At phone scale these primitives are only a few pixels wide. Reduce
        # their tessellation, retaining the original radius, height, placement,
        # materials, cargo children and animation/worker identity unchanged.
        for child in human.get_children():
            if not child is MeshInstance3D:
                continue
            if child.mesh is CapsuleMesh:
                child.mesh.radial_segments = HUMAN_RADIAL_SEGMENTS
                child.mesh.rings = HUMAN_CAPSULE_RINGS
            elif child.mesh is SphereMesh:
                child.mesh.radial_segments = HUMAN_RADIAL_SEGMENTS
                child.mesh.rings = HUMAN_HEAD_RINGS
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
        if not _actors.has(id):
            continue
        var robot: Node3D = _actors[id]
        if int(id) < _human_count:
            if reduced_motion:
                (robot.get_node("LeftLeg") as Node3D).rotation.x = 0.0
                (robot.get_node("RightLeg") as Node3D).rotation.x = 0.0
            continue
        # The inherited human gait must not make a robot's wheels kick.
        (robot.get_node("LeftLeg") as Node3D).rotation.x = 0.0
        (robot.get_node("RightLeg") as Node3D).rotation.x = 0.0
        (robot.get_node("SafetyVest") as Node3D).scale = Vector3.ONE


func _refresh_cargo(items: Array) -> void:
    super._refresh_cargo(items)
    # A stationary six-unit bulk manifest is a real pallet load, not one tiny
    # decorative cube. Each visible carton below corresponds to one actual unit.
    # Carrying/inbound parcels keep their original reserved transport envelope.
    var counts := {}
    for item in items:
        if str(item.get("job_kind", item.get("kind", ""))) != "bulk":
            continue
        var key := str(item.get("manifest_id", -1)) + ":" + str(item.get("stage", ""))
        counts[key] = int(counts.get(key, 0)) + 1
    for item in items:
        var id := str(item.get("id", 0))
        if not _cargo.has(id):
            continue
        var node: Node3D = _cargo[id]
        var bulk := str(item.get("job_kind", item.get("kind", ""))) == "bulk"
        var on_bay := bulk and not str(item.get("bay_id", "")).is_empty() and str(item.get("stage", "")) in ["bulk_storage", "reserved_bulk_ship"]
        var load := node.get_node_or_null("BulkPallet") as Node3D
        if on_bay and load == null:
            load = Node3D.new()
            load.name = "BulkPallet"
            node.add_child(load)
            _box(load, "PalletDeck", Vector3(.84, .05, .64), Vector3(0, -.15, 0), Color("96764f"))
            for x in [-.28, .28]:
                _box(load, "PalletRunner", Vector3(.12, .065, .62), Vector3(x, -.2075, 0), Color("665139"))
            for index in 6:
                _box(load, "Unit%d" % index, Vector3(.25, .27, .27), Vector3((index % 3 - 1) * .27, .01, (-.15 if index < 3 else .15)), BULK_COLOR.darkened(.035 * float(index % 3)))
            for z in [-.15, .15]:
                _box(load, "LoadStrap", Vector3(.82, .012, .038), Vector3(0, .151, z), Color("e7d6ad"))
        (node.get_node("Carton") as Node3D).visible = not on_bay
        (node.get_node("Tape") as Node3D).visible = not on_bay
        if load != null:
            load.visible = on_bay
            if on_bay:
                var key := str(item.get("manifest_id", -1)) + ":" + str(item.get("stage", ""))
                var units := int(counts.get(key, 0))
                load.set_meta("represented_units", units)
                for index in 6:
                    (load.get_node("Unit%d" % index) as Node3D).visible = index < units


func _refresh_routes(edges: Array) -> void:
    super._refresh_routes(edges)
    # Idle lanes are quiet physical floor marks; live flow and actual queued
    # traffic retain distinct cyan/amber semantic signals. Never alter visibility.
    for edge in edges:
        var id := str(edge.get("id", ""))
        if not _routes.has(id):
            continue
        var busy := int(edge.get("occupied", 0)) > 0
        var waiting := int(edge.get("waiters", 0)) > 0
        var tint := Color("ffc472") if waiting else (Color("53c6b7") if busy else Color("3c4e57"))
        var route: Node3D = _routes[id]
        for lane in 2:
            (route.get_node("Lane%d" % lane) as MeshInstance3D).material_override = _material(tint, busy)

func _refresh_bays(bays: Array) -> void:
    super._refresh_bays(bays)
    for bay in bays:
        var id := str(bay.get("id", ""))
        if not _bay_nodes.has(id):
            continue
        var node: Node3D = _bay_nodes[id]
        var occupied := bool(bay.get("occupied", false))
        var pad := node.get_node("Footprint") as MeshInstance3D
        pad.material_override = _material(Color("3b4950") if occupied else Color("293b45"))
        # Empty bays stay visible as subdued floor paint, instead of a grid of
        # glowing brown tiles. Occupied boundaries remain readable around loads.
        for child in node.get_children():
            if child is MeshInstance3D and child != pad:
                child.material_override = _material(Color("ae9f78") if occupied else Color("74817e"))


# Isolated presentation slice: one real owned machine, never extra capacity/cargo.
func _refresh_visual_auto_pack() -> void:
    if not _slots.has("packing"): return
    var slot: Node3D = _slots.packing
    var owned: bool = visible_growth_enabled and not sim.legacy_profile and "auto_pack" in sim.purchased_upgrades
    var machine := slot.get_node_or_null("VisualAutoPack") as Node3D
    if owned and machine == null:
        machine = Node3D.new()
        machine.name = "VisualAutoPack"
        # Keep every solid inside the existing 1.6 x 1.0 physical footprint.
        # Height preserves the gantry silhouette without occupying a traffic lane.
        machine.scale = Vector3(.64, 1.0, .49)
        slot.add_child(machine)
        # Open central bay preserves sight of the authoritative packing parcels.
        _box(machine,"Plinth",Vector3(2.48,.16,1.96),Vector3(0,.16,0),Color("172f3d"))
        _box(machine,"WorkDeck",Vector3(2.12,.12,1.30),Vector3(0,.53,0),Color("627b85"))
        for side in [-1,1]:
            _box(machine,"Foot",Vector3(.36,.36,1.8),Vector3(side*1.04,.34,0),Color("e5ece5"))
            _box(machine,"GantryPillar",Vector3(.30,1.66,.42),Vector3(side*.98,1.17,-.56),Color("f2b345"))
            _box(machine,"DarkInset",Vector3(.32,.87,.05),Vector3(side*.98,1.12,-.40),Color("344853"))
            _box(machine,"SafetyCap",Vector3(.38,.12,.50),Vector3(side*.98,2.01,-.51),Color("fff1c6"))
        _box(machine,"GantryBridge",Vector3(2.42,.40,.60),Vector3(0,1.95,-.51),Color("f2b345"))
        _box(machine,"TopCover",Vector3(2.46,.10,.66),Vector3(0,2.20,-.51),Color("e9efe6"))
        _box(machine,"ControlCabinet",Vector3(.16,.91,1.02),Vector3(1.155,1.06,.22),Color("e5ece5"))
        _box(machine,"ControlScreen",Vector3(.16,.25,.04),Vector3(1.155,1.30,.75),Color("1e5658"))
        _box(machine,"StatusStrip",Vector3(1.66,.13,.055),Vector3(0,1.97,-.18),Color("668079"))
        _box(machine,"PressRail",Vector3(.15,.40,.18),Vector3(0,1.60,-.50),Color("a4b9bd"))
        _box(machine,"SealingHead",Vector3(.78,.25,.53),Vector3(0,1.33,-.26),Color("e9efe6"))
        for x in [-.62,0,.62]:
            _box(machine,"FrontTrim",Vector3(.28,.09,.03),Vector3(x,.20,.99),Color("f2b345"))
    (slot.get_node("PackingEquipment") as Node3D).visible = not owned
    var old_tool := slot.get_node_or_null("PackingUpgrade") as Node3D
    if old_tool != null and owned: old_tool.visible = false
    if machine == null: return
    machine.visible = owned
    if not owned: return
    var working: bool = not sim.pack_jobs.is_empty()
    var fraction := 0.0
    if working:
        fraction = clampf(1.0-float(sim.pack_jobs[0].remaining)/sim.pack_seconds,0.0,1.0)
    # No wall-clock animation: pausing or an empty station leaves this exactly still.
    var head := machine.get_node("SealingHead") as Node3D
    head.position = Vector3(0,1.33,-.26)
    if working and _cargo.has(str(sim.pack_jobs[0].cargo_id)):
        var parcel: Node3D = _cargo[str(sim.pack_jobs[0].cargo_id)]
        var actual_position := machine.to_local(parcel.global_position)
        head.position.x = actual_position.x
        head.position.z = actual_position.z
    head.position.y = 1.33 - .31*sin(fraction*PI)
    machine.set_meta("actual_pack_cargo_id", int(sim.pack_jobs[0].cargo_id) if working else -1)
    machine.set_meta("actual_pack_fraction",fraction)
    var strip := machine.get_node("StatusStrip") as MeshInstance3D
    strip.material_override = _material(Color("65f4b1") if working else Color("668079"))
