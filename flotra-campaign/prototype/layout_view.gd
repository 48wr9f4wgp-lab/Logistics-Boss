extends Node3D

signal slot_selected(id: String)
const FONT = preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const WORKBENCH = preload("res://assets/models/packing_workbench.glb")
const NAVY := Color("192d3b")
const STEEL := Color("405564")
const TEAL := Color("59d9ca")
const AMBER := Color("ffc472")
const WHITE := Color("dbe5e8")
var sim
var camera: Camera3D
var equipment_root: Node3D
var actors_root: Node3D
var routes_root: Node3D
var _slots: Dictionary = {}
var _actors: Dictionary = {}
var _routes: Dictionary = {}
var _cargo: Dictionary = {}
var _materials: Dictionary = {}
var _layout_signature := ""
var _selected := ""
var _preview := ""
var _world_center := Vector3.ZERO
var _world_extent := Vector2(18, 15)
var _built_shell := false
var _down_slot := ""
var _down_position := Vector2.ZERO
var _touch_index := -1
var input_gate: Callable
var _pulse := 0.0
var _ghost: Node3D

func _ready() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("101e29")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b2c5cf")
    env.ambient_light_energy = 0.45
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-56, -35, 0)
    key.light_energy = 0.75
    key.light_color = Color("ffead3")
    key.shadow_enabled = true
    add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-30, 110, 0)
    fill.light_energy = 0.22
    fill.light_color = Color("90cddf")
    add_child(fill)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    camera.far = 100
    add_child(camera)
    routes_root = Node3D.new()
    routes_root.name = "AuthoritativeRoutes"
    add_child(routes_root)
    equipment_root = Node3D.new()
    equipment_root.name = "FixedPlots"
    add_child(equipment_root)
    actors_root = Node3D.new()
    actors_root.name = "ActualCargoAndWorkers"
    add_child(actors_root)
    fit_camera(Vector2(390, 500))

func bind_sim(next_sim) -> void:
    sim = next_sim
    if is_node_ready():
        refresh()

func _process(delta: float) -> void:
    _pulse += delta

func _material(color: Color, emissive := false) -> StandardMaterial3D:
    var key := str(color) + str(emissive)
    if not _materials.has(key):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.82
        if emissive:
            mat.emission_enabled = true
            mat.emission = color
            mat.emission_energy_multiplier = 0.15
        _materials[key] = mat
    return _materials[key]

func _box(parent: Node, title: String, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = title
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = position
    mesh.material_override = _material(color)
    parent.add_child(mesh)
    return mesh

func _label(parent: Node3D, title: String, text: String, position: Vector3, color: Color, font_size := 40) -> Label3D:
    var tag := Label3D.new()
    tag.name = title
    tag.text = text
    tag.font = FONT
    tag.font_size = font_size
    tag.pixel_size = 0.022
    tag.outline_size = 8
    tag.modulate = color
    tag.outline_modulate = Color("10202b")
    tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    tag.position = position
    parent.add_child(tag)
    return tag

func _position(value: Variant) -> Vector3:
    if value is Vector3:
        return value
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO

func _build_shell(state: Dictionary) -> void:
    var low := Vector3(INF, 0, INF)
    var high := Vector3(-INF, 0, -INF)
    for edge in state.get("edges", []):
        for key in ["from", "to"]:
            var p := _position(edge.get(key, Vector3.ZERO))
            low.x = minf(low.x, p.x)
            low.z = minf(low.z, p.z)
            high.x = maxf(high.x, p.x)
            high.z = maxf(high.z, p.z)
    for slot in state.get("slots", []):
        var p := _position(slot.get("position", Vector3.ZERO))
        low.x = minf(low.x, p.x)
        low.z = minf(low.z, p.z)
        high.x = maxf(high.x, p.x)
        high.z = maxf(high.z, p.z)
    if not is_finite(low.x):
        low = Vector3(-7, 0, -5)
        high = Vector3(7, 0, 5)
    low -= Vector3(2.1, 0, 2.1)
    high += Vector3(2.1, 0, 2.1)
    _world_center = (low + high) * 0.5
    _world_extent = Vector2(high.x-low.x, high.z-low.z)
    # A working main hall plus ONE connected northern wing. The graph enters
    # through the same opening; no detached decorative second warehouse.
    var world_data: Dictionary = state.get("world", {})
    var annex: Rect2 = world_data.get("annex", Rect2(-2,-7,10,5))
    var main_back := -4.15
    var front := high.z
    var hall_center := Vector3(_world_center.x,0,(front+main_back)*.5)
    var hall_size := Vector2(_world_extent.x,front-main_back)
    _box(self,"MainFoundation",Vector3(hall_size.x,.40,hall_size.y),hall_center-Vector3(0,.29,0),NAVY)
    _box(self,"MainWorkingFloor",Vector3(hall_size.x-.10,.08,hall_size.y-.10),hall_center-Vector3(0,.05,0),Color("354752"))
    var wing_back := annex.position.y-.2
    var wing_left := annex.position.x-.2
    var wing_right := annex.end.x+.2
    var wing_depth := main_back-wing_back+.18
    var wing_center := Vector3((wing_left+wing_right)*.5,0,(main_back+wing_back)*.5)
    _box(self,"AnnexFoundation",Vector3(wing_right-wing_left,.40,wing_depth),wing_center-Vector3(0,.29,0),NAVY)
    _box(self,"AnnexWorkingFloor",Vector3(wing_right-wing_left-.10,.085,wing_depth),wing_center-Vector3(0,.047,0),Color("3b575b"))
    _box(self,"ExpansionJoint",Vector3(wing_right-wing_left,.018,.055),Vector3(wing_center.x,.008,main_back+.12),TEAL)
    _box(self,"AnnexBackWall",Vector3(wing_right-wing_left,.85,.15),Vector3(wing_center.x,.35,wing_back),NAVY)
    _box(self,"AnnexLeftWall",Vector3(.15,.75,wing_depth),Vector3(wing_left,.30,wing_center.z),NAVY)
    _box(self,"AnnexRightWall",Vector3(.15,.75,wing_depth),Vector3(wing_right,.30,wing_center.z),NAVY)
    if wing_left > low.x:
        _box(self,"MainBackWall",Vector3(wing_left-low.x,.85,.15),Vector3((wing_left+low.x)*.5,.35,main_back),NAVY)
    if high.x > wing_right:
        _box(self,"MainBackWallRight",Vector3(high.x-wing_right,.85,.15),Vector3((wing_right+high.x)*.5,.35,main_back),NAVY)
    _box(self,"LeftCurb",Vector3(.15,.28,hall_size.y),Vector3(low.x,.10,hall_center.z),NAVY)
    _box(self,"FrontFascia",Vector3(hall_size.x,.13,.12),Vector3(hall_center.x,-.24,front),STEEL)
    for x in range(ceili(low.x),floori(high.x)+1,2):
        _box(self,"SlabJoint",Vector3(.014,.006,hall_size.y-.2),Vector3(x,-.006,hall_center.z),Color("596e78"))
    var inbound_position := _position(world_data.get("inbound",Vector3(-8,0,-2)))
    var outbound_position := _position(world_data.get("outbound",Vector3(8,0,3)))
    _box(self,"InboundReceivingPad",Vector3(2.4,.04,2.0),inbound_position+Vector3(0,.015,0),Color("386777"))
    _box(self,"OutboundReceivingPad",Vector3(2.4,.04,2.0),outbound_position+Vector3(0,.015,0),Color("39736b"))
    _label(self,"InboundLabel","入荷",inbound_position+Vector3(0,.12,1.2),WHITE,38)
    _label(self,"OutboundLabel","出荷",outbound_position+Vector3(0,.12,1.2),WHITE,38)
    _label(self,"AnnexLabel","別館",Vector3(wing_center.x,1.10,wing_back+.14),TEAL,40)
    _built_shell = true
    fit_camera(Vector2(get_viewport().size))

func fit_camera(view_size: Vector2) -> void:
    if camera == null:
        return
    var center := _world_center
    var extent := _world_extent
    if not _selected.is_empty() and _slots.has(_selected):
        var current: Vector3 = (_slots[_selected] as Node3D).position
        var candidate: Vector3 = _ghost.position if _ghost != null else current
        center = (current+candidate)*.5
        extent = Vector2(absf(current.x-candidate.x)+6.5,absf(current.z-candidate.z)+6.5)
    camera.position = center + Vector3(30,44,14)
    camera.look_at(center + Vector3(0,.1,0), Vector3.UP)
    var aspect := maxf(.4, view_size.x/maxf(1,view_size.y))
    var projected_width := extent.x*.423+extent.y*.906
    var projected_height := (extent.x*.906+extent.y*.423)*.80
    camera.size = maxf(projected_height+2.2, (projected_width+1.4)/aspect)

func refresh() -> void:
    if sim == null or not is_node_ready():
        return
    var state: Dictionary = sim.snapshot()
    if not _built_shell:
        _build_shell(state)
    var signature := ""
    for slot in state.get("slots", []):
        signature += String(slot.get("id",""))+String(slot.get("kind",""))+str(slot.get("position",Vector3.ZERO))+str(slot.get("choice_id",""))
    if signature != _layout_signature:
        _layout_signature = signature
        _rebuild_slots(state.get("slots", []))
    for item in state.get("equipment", []):
        var id := String(item.get("id", ""))
        if _slots.has(id):
            var equipment_node := _slots[id] as Node3D
            equipment_node.position = _position(item.get("position", Vector3.ZERO))
            var dimensions: Vector3 = item.get("size", Vector3(1.6,.95,1.0))
            var rack_node := equipment_node.get_node_or_null("RackEquipment") as Node3D
            if rack_node != null:
                rack_node.scale = Vector3(dimensions.x/2.22, dimensions.y/1.85, dimensions.z/1.25)
            var bench_node := equipment_node.get_node_or_null("PackingEquipment") as Node3D
            if bench_node != null and not bench_node.has_meta("fit_done"):
                _fit_equipment(bench_node, dimensions)
                bench_node.set_meta("fit_done",true)
    _refresh_routes(state.get("edges", []))
    _refresh_workers(state.get("workers", []))
    _refresh_cargo(state.get("cargo", []))
    for id in _slots:
        var root: Node3D = _slots[id]
        var pad := root.get_node("PlotPad") as MeshInstance3D
        pad.material_override = _material(AMBER.darkened(.28) if id == _selected else TEAL.darkened(.57))

func _rebuild_slots(slots: Array) -> void:
    for child in equipment_root.get_children():
        equipment_root.remove_child(child)
        child.queue_free()
    _slots.clear()
    for slot in slots:
        var id := String(slot.get("id", ""))
        var kind := String(slot.get("kind", "aisle"))
        var root := Node3D.new()
        root.name = "Plot_"+id
        root.position = _position(slot.get("position",Vector3.ZERO))
        equipment_root.add_child(root)
        _slots[id] = root
        _box(root,"PlotPad",Vector3(2.6,.04,2.2),Vector3(0,.02,0),TEAL.darkened(.57))
        for z in [-1.1,1.1]:
            _box(root,"PlotLine",Vector3(2.6,.045,.045),Vector3(0,.05,z),TEAL.darkened(.2))
        for x in [-1.3,1.3]:
            _box(root,"PlotLine",Vector3(.045,.045,2.2),Vector3(x,.05,0),TEAL.darkened(.2))
        if kind in ["shelf", "rack", "storage"] or kind.contains("rack") or kind.contains("shelf"):
            var rack := Node3D.new()
            rack.name = "RackEquipment"
            root.add_child(rack)
            _build_rack(rack)
            rack.scale = Vector3(2.6/2.22, 2.2/1.85, 2.8/1.25)
        elif kind in ["packing", "pack", "packing_cell"] or kind.contains("pack"):
            var bench := WORKBENCH.instantiate() as Node3D
            bench.name = "PackingEquipment"
            bench.scale = Vector3.ONE
            root.add_child(bench)
        else:
            for z in [-.55,0.0,.55]:
                _box(root,"AisleArrow",Vector3(.65,.06,.10),Vector3(0,.06,z),WHITE.darkened(.15))
        var label := "棚" if id == "shelf" else ("梱包" if id == "packing" else String(slot.get("label",id)))
        if label.length() > 9:
            label = label.substr(0,9)
        _label(root,"PlotLabel",label,Vector3(0,.2,1.55),WHITE,36)
        var area := Area3D.new()
        area.name = "PlotTarget"
        area.collision_layer = 1
        area.collision_mask = 0
        area.set_meta("slot_id",id)
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(2.7,2.3,2.3)
        shape.shape = box
        shape.position.y = 1
        area.add_child(shape)
        root.add_child(area)

func _build_rack(parent: Node3D) -> void:
    for x in [-1.03,1.03]:
        for z in [-.55,.55]:
            _box(parent,"RackPost",Vector3(.09,1.85,.09),Vector3(x,.94,z),Color("f1a451"))
    for y in [.28,.93,1.58]:
        _box(parent,"RackShelf",Vector3(2.22,.09,1.25),Vector3(0,y,0),STEEL)
        _box(parent,"RackBeam",Vector3(2.22,.13,.07),Vector3(0,y+.03,.64),Color("e69546"))
    # No decorative cartons: all visible cargo below follows Domain state.

func _refresh_routes(edges: Array) -> void:
    for edge in edges:
        var id := String(edge.get("id",""))
        var a := _position(edge.get("from",Vector3.ZERO))
        var b := _position(edge.get("to",Vector3.ZERO))
        var direction := (b-a).normalized()
        var normal := Vector3(-direction.z,0,direction.x)
        if not _routes.has(id):
            var root := Node3D.new()
            root.name = "Edge_"+id
            routes_root.add_child(root)
            for lane in 2:
                var offset := normal*(-.32 if lane == 0 else .32)
                var length := a.distance_to(b)
                var mesh := _box(root,"Lane%d" % lane,Vector3(.23,.025,maxf(.01,length)),(a+b)*.5+offset+Vector3(0,.025,0),TEAL.darkened(.55))
                if length > .01:
                    mesh.look_at(b+offset+Vector3(0,.025,0),Vector3.UP)
            _routes[id] = root
        var root: Node3D = _routes[id]
        var waiters := int(edge.get("waiters",0))
        var busy: bool = int(edge.get("occupied",0)) > 0
        var color := AMBER if waiters>0 else (TEAL if busy else Color("354e58"))
        for lane in 2:
            var mesh := root.get_node("Lane%d" % lane) as MeshInstance3D
            var actual_lanes: Array = edge.get("lanes", [])
            mesh.visible = not bool(actual_lanes[lane].get("blocked",false)) if actual_lanes.size() > lane else (int(edge.get("capacity",1)) > 1 or lane == 1)
            mesh.material_override = _material(color,busy)

func _build_worker(id: String) -> Node3D:
    var root := Node3D.new()
    root.name = "Worker_"+id
    actors_root.add_child(root)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = .18
    capsule.height = .62
    body.mesh = capsule
    body.position.y = .50
    body.material_override = _material(TEAL.darkened(.12))
    root.add_child(body)
    _box(root,"SafetyVest",Vector3(.36,.30,.22),Vector3(0,.61,0),AMBER)
    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = .16
    sphere.height = .32
    head.mesh = sphere
    head.position.y = .97
    head.material_override = _material(WHITE)
    root.add_child(head)
    _box(root,"LeftLeg",Vector3(.13,.30,.14),Vector3(-.105,.18,0),NAVY)
    _box(root,"RightLeg",Vector3(.13,.30,.14),Vector3(.105,.18,0),NAVY)
    _parcel(root,"CarriedParcel",Vector3(0,.59,-.38),.43)
    _label(root,"Waiting","待ち",Vector3(0,1.46,0),AMBER,30)
    return root

func _refresh_workers(workers: Array) -> void:
    var seen := {}
    for worker in workers:
        var id := str(worker.get("id",0))
        seen[id] = true
        if not _actors.has(id):
            _actors[id] = _build_worker(id)
        var node: Node3D = _actors[id]
        var next := _position(worker.get("position",Vector3.ZERO))
        var delta := next-node.position
        if delta.length() > .01:
            node.rotation.y = atan2(-delta.x,-delta.z)
        node.position = next
        (node.get_node("CarriedParcel") as Node3D).visible = bool(worker.get("carrying",false))
        var waiting := bool(worker.get("waiting",false))
        (node.get_node("Waiting") as Label3D).visible = waiting
        var swing := sin(_pulse*9.0+int(worker.get("id",0)))*.20 if delta.length()>.001 and not waiting else 0.0
        (node.get_node("LeftLeg") as Node3D).rotation.x = swing
        (node.get_node("RightLeg") as Node3D).rotation.x = -swing
    for id in _actors.keys():
        if not seen.has(id):
            (_actors[id] as Node3D).queue_free()
            _actors.erase(id)

func _parcel(parent: Node, name: String, position: Vector3, size: float) -> Node3D:
    var root := Node3D.new()
    root.name = name
    root.position = position
    parent.add_child(root)
    _box(root,"Carton",Vector3(size,size*.75,size*.80),Vector3.ZERO,Color("d9a463"))
    _box(root,"Tape",Vector3(size*.18,.012,size*.82),Vector3(0,size*.38,0),Color("f4d798"))
    return root

func _refresh_cargo(cargo: Array) -> void:
    var seen := {}
    var per_station := {}
    for item in cargo:
        var stage := String(item.get("stage",""))
        if stage in ["shipped","worker","carried","transit"] or stage.begins_with("carried_"):
            continue
        if bool(item.get("carried",false)):
            continue
        var id := str(item.get("id",0))
        var p := _position(item.get("position",Vector3.ZERO))
        if stage == "storage" and _slots.has("shelf"):
            p = (_slots["shelf"] as Node3D).position + Vector3(0,.08,0)
        elif stage in ["packing_queue", "packing", "packed"] and _slots.has("packing"):
            p = (_slots["packing"] as Node3D).position + Vector3(0,.50,0)
        var group := str(p)+stage
        var count := int(per_station.get(group,0))
        per_station[group] = count+1
        # Capped physical rendering, not capped Domain inventory.
        if count >= 12:
            continue
        seen[id] = true
        if not _cargo.has(id):
            _cargo[id] = _parcel(actors_root,"Parcel_"+id,Vector3.ZERO,.39)
        var node: Node3D = _cargo[id]
        node.position = p+Vector3((count%3-1)*.47,.24+(count/6)*.36,(count%6/3)*.44)
    for id in _cargo.keys():
        if not seen.has(id):
            (_cargo[id] as Node3D).queue_free()
            _cargo.erase(id)

func select_slot(id: String) -> void:
    _selected = id
    if id.is_empty() and _ghost != null:
        _ghost.queue_free()
        _ghost = null
    refresh()

func set_preview(id: String) -> void:
    _preview = id

func _slot_at(point: Vector2) -> String:
    if camera == null:
        return ""
    var origin := camera.project_ray_origin(point)
    var end := origin+camera.project_ray_normal(point)*100.0
    var query := PhysicsRayQueryParameters3D.create(origin,end,1)
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    return String(hit["collider"].get_meta("slot_id","")) if not hit.is_empty() else ""

func _unhandled_input(event: InputEvent) -> void:
    if input_gate.is_valid() and not input_gate.call():
        cancel_pointer_input()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _down_position = event.position
            _down_slot = _slot_at(event.position)
        else:
            var id := _slot_at(event.position)
            if not id.is_empty() and id == _down_slot and _down_position.distance_to(event.position) < 18:
                select_slot(id)
                slot_selected.emit(id)
            _down_slot = ""
    elif event is InputEventScreenTouch:
        if event.pressed and _touch_index < 0:
            _touch_index = event.index
            _down_position = event.position
            _down_slot = _slot_at(event.position)
        elif not event.pressed and event.index == _touch_index:
            var id := _slot_at(event.position)
            if not id.is_empty() and id == _down_slot and _down_position.distance_to(event.position)<18:
                select_slot(id)
                slot_selected.emit(id)
            _touch_index = -1
            _down_slot = ""

func preview_slot(slot_id: String, choice_id: String) -> void:
    if _ghost != null:
        _ghost.queue_free()
        _ghost = null
    if sim == null or choice_id.is_empty():
        return
    var state: Dictionary = sim.snapshot()
    for slot in state.get("slots", []):
        if String(slot.id) != slot_id or String(slot.choice_id) == choice_id:
            continue
        for choice in slot.get("choices", []):
            if String(choice.id) != choice_id:
                continue
            _ghost = Node3D.new()
            _ghost.name = "UncommittedPlacementPreview"
            _ghost.position = _position(choice.position)
            add_child(_ghost)
            var footprint := Vector3(2.2,2.2,2.8) if slot_id == "shelf" else Vector3(1.6,.95,1.0)
            for item in state.get("equipment", []):
                if String(item.get("id", "")) == slot_id:
                    footprint = item.get("size", footprint)
            var w := footprint.x
            var d := footprint.z
            for x in [-w*.5,w*.5]:
                _box(_ghost,"PreviewEdge",Vector3(.07,.04,d),Vector3(x,.07,0),AMBER)
            for z in [-d*.5,d*.5]:
                _box(_ghost,"PreviewEdge",Vector3(w,.04,.07),Vector3(0,.07,z),AMBER)
            _label(_ghost,"PreviewLabel","変更先",Vector3(0,.2,d*.5+.25),AMBER,34)
            return

func cancel_pointer_input() -> void:
    _down_slot = ""
    _touch_index = -1

func _notification(what: int) -> void:
    if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
        cancel_pointer_input()

func _fit_equipment(node: Node3D, dimensions: Vector3) -> void:
    var found := false
    var bounds := AABB()
    for child in node.find_children("*", "MeshInstance3D", true, false):
        var part := child as MeshInstance3D
        if part.mesh == null:
            continue
        var relative: Transform3D = node.global_transform.affine_inverse() * part.global_transform
        var transformed: AABB = relative * part.get_aabb()
        bounds = bounds.merge(transformed) if found else transformed
        found = true
    if not found:
        return
    var scaling := Vector3(dimensions.x/maxf(.001,bounds.size.x),dimensions.y/maxf(.001,bounds.size.y),dimensions.z/maxf(.001,bounds.size.z))
    node.scale = scaling
    var center := bounds.get_center()
    node.position = Vector3(-center.x*scaling.x,-bounds.position.y*scaling.y,-center.z*scaling.z)
