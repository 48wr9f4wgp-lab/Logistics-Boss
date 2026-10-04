extends "res://prototype/jobs_view.gd"
## Release-only presentation. Geometry, jobs and selection remain authoritative.
const CALLOUT_FONT_SIZE := 18
const CALLOUT_HEIGHT := 36.0
const CALLOUT_MARGIN := 8.0
var _readability_layer: CanvasLayer
var _callouts: Dictionary = {}
var _release_labels: Array[Label3D] = []
var _location_data: Dictionary = {}
var _callout_signature := ""

func _ready() -> void:
    super._ready()
    _readability_layer = CanvasLayer.new()
    _readability_layer.name = "ReadableWorldLocations"
    add_child(_readability_layer)

# The original floor, worker and manifest captions were scaled with the entire
# warehouse, becoming overlapping 7px text on a phone. Keep their nodes for the
# inherited renderer, but use a deliberately small screen-space label set.
func _label(parent: Node3D, title: String, text: String, position: Vector3, color: Color, font_size := 40) -> Label3D:
    var tag := super._label(parent,title,text,position,color,font_size)
    tag.visible = false
    _release_labels.append(tag)
    return tag

func refresh() -> void:
    super.refresh()
    if sim == null or not is_node_ready(): return
    if _slots.has("shelf"):
        var shelf: Node3D = _slots.shelf
        var rack := shelf.get_node_or_null("RackEquipment") as Node3D
        if rack != null:
            var inserts := rack.get_node_or_null("CapacityInserts") as Node3D
            if inserts == null:
                inserts = Node3D.new()
                inserts.name = "CapacityInserts"
                rack.add_child(inserts)
                for y in [.59,1.25,1.78]:
                    _box(inserts,"ExtraShelf",Vector3(2.12,.055,1.12),Vector3(0,y,0),TEAL.darkened(.2))
            inserts.visible = sim.rack_capacity > 12
    if _slots.has("packing"):
        var bench: Node3D = _slots.packing
        var tool := bench.get_node_or_null("PackingUpgrade") as Node3D
        if tool == null:
            tool = Node3D.new()
            tool.name = "PackingUpgrade"
            bench.add_child(tool)
            _box(tool,"TapeDispenser",Vector3(.28,.18,.3),Vector3(.4,1.03,0),TEAL)
        tool.visible = sim.pack_seconds < 3.0
    for index in range(_release_labels.size()-1,-1,-1):
        if not is_instance_valid(_release_labels[index]):
            _release_labels.remove_at(index)
        else:
            _release_labels[index].visible = false
    _refresh_callouts()

func _build_shell(state: Dictionary) -> void:
    _location_data = state.get("world",{}).duplicate(true)
    super._build_shell(state)

func fit_camera(view_size: Vector2) -> void:
    if camera == null: return
    camera.keep_aspect = Camera3D.KEEP_HEIGHT
    # A consistent isometric bearing gives the long main hall more horizontal
    # space. Fit the actual L-shaped building, not its empty enclosing rectangle.
    var center := _world_center
    var focus := not _selected.is_empty() and _slots.has(_selected)
    if focus:
        center = (_slots[_selected] as Node3D).position
        if _ghost != null: center = (center+_ghost.position)*.5
    camera.position = center + Vector3(28,38,22)
    camera.look_at(center,Vector3.UP)
    var points: Array[Vector3] = []
    if focus:
        var current: Vector3 = (_slots[_selected] as Node3D).position
        _append_corners(points,AABB(current-Vector3(2.0,.15,2.0),Vector3(4.0,3.0,4.0)))
        if _ghost != null:
            _append_corners(points,AABB(_ghost.position-Vector3(2.0,.15,2.0),Vector3(4.0,3.0,4.0)))
    else:
        for title in ["MainFoundation","AnnexFoundation"]:
            var floor_mesh := get_node_or_null(title) as MeshInstance3D
            if floor_mesh != null:
                _append_corners(points,floor_mesh.transform*floor_mesh.get_aabb())
        for slot in _slots.values():
            _append_corners(points,AABB((slot as Node3D).position-Vector3(1.4,.1,1.5),Vector3(2.8,2.4,3.0)))
    if points.is_empty():
        super.fit_camera(view_size)
        return
    var projected := Rect2()
    var first := true
    var inverse := camera.global_transform.affine_inverse()
    for point in points:
        var local: Vector3 = inverse*point
        var xy := Vector2(local.x,-local.y)
        if first:
            projected = Rect2(xy,Vector2.ZERO)
            first = false
        else:
            projected = projected.expand(xy)
    var projected_center := projected.get_center()
    camera.position += camera.basis.x*projected_center.x-camera.basis.y*projected_center.y
    var aspect := maxf(.2,view_size.x/maxf(1.0,view_size.y))
    var padding := Vector2(22,24) if not focus else Vector2(28,36)
    var usable := Vector2(maxf(.2,1.0-padding.x*2/maxf(1,view_size.x)),maxf(.2,1.0-padding.y*2/maxf(1,view_size.y)))
    camera.size = maxf(projected.size.y/usable.y,projected.size.x/(aspect*usable.x))
    _refresh_callouts()

func _append_corners(points: Array[Vector3], bounds: AABB) -> void:
    for index in 8:
        points.append(bounds.get_endpoint(index))

func _make_callout(id: String, color: Color) -> Dictionary:
    var line := Line2D.new()
    line.name = id+"Leader"
    line.width = 1.25
    line.default_color = Color(color,.68)
    line.antialiased = true
    _readability_layer.add_child(line)
    var label := Label.new()
    label.name = id+"Caption"
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_override("font",FONT)
    label.add_theme_font_size_override("font_size",CALLOUT_FONT_SIZE)
    label.add_theme_color_override("font_color",color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    var plate := StyleBoxFlat.new()
    plate.bg_color = Color("142733")
    plate.border_color = color.darkened(.58)
    plate.set_border_width_all(1)
    plate.set_corner_radius_all(7)
    plate.content_margin_left = 8
    plate.content_margin_right = 8
    label.add_theme_stylebox_override("normal",plate)
    _readability_layer.add_child(label)
    var item := {"label":label,"line":line,"anchor":Vector2.ZERO,"rect":Rect2()}
    _callouts[id] = item
    return item

func _refresh_callouts() -> void:
    if _readability_layer == null or sim == null or camera == null or not _built_shell: return
    var signature := str([_selected,camera.global_transform,camera.size,get_viewport().size,sim.rack_capacity,sim.pack_seconds,sim.bulk_capacity(),_ghost.position if is_instance_valid(_ghost) else null])
    for slot in _slots.values(): signature += str((slot as Node3D).position)
    if signature == _callout_signature: return
    _callout_signature = signature
    var descriptors: Array[Dictionary] = []
    if not _selected.is_empty() and _slots.has(_selected):
        var title := "棚の容量 %d個" % sim.rack_capacity if _selected == "shelf" else "梱包 %.1f秒/個" % sim.pack_seconds
        var equipment: Node3D = _slots[_selected]
        descriptors.append({"id":"Selected","text":title,"point":equipment.position+Vector3(0,2.2 if _selected=="shelf" else 1.0,0),"color":AMBER,"side":-1})
        if is_instance_valid(_ghost):
            descriptors.append({"id":"Candidate","text":"変更先","point":_ghost.position+Vector3(0,.1,0),"color":AMBER,"side":1})
    else:
        var data: Dictionary = _location_data
        var annex: Rect2 = data.get("annex",Rect2(-2,-7.8,9,5.8))
        descriptors.append({"id":"Inbound","text":"入荷","point":_position(data.get("inbound",Vector3(-8,0,-2)))+Vector3(0,.4,0),"color":WHITE,"side":-1})
        descriptors.append({"id":"Storage","text":"保管床 %d枠"%sim.bulk_capacity(),"point":Vector3(annex.get_center().x,.1,annex.position.y+.65),"color":BULK_COLOR,"side":1})
        descriptors.append({"id":"Outbound","text":"出荷","point":_position(data.get("outbound",Vector3(8,0,3)))+Vector3(0,.2,0),"color":TEAL,"side":1})
    for item in _callouts.values():
        (item.label as Label).visible = false
        (item.line as Line2D).visible = false
    var occupied: Array[Rect2] = []
    var protected: Array[Rect2] = []
    for slot in _slots.values():
        var position: Vector3 = (slot as Node3D).position
        var rect := Rect2(camera.unproject_position(position),Vector2.ZERO)
        var corners: Array[Vector3] = []
        _append_corners(corners,AABB(position-Vector3(1.1,0,1.4),Vector3(2.2,2.2,2.8)))
        for corner in corners: rect = rect.expand(camera.unproject_position(corner))
        protected.append(rect.grow(3))
    var screen := Vector2(get_viewport().size)
    for descriptor in descriptors:
        var item: Dictionary = _callouts.get(descriptor.id,{})
        if item.is_empty(): item = _make_callout(descriptor.id,descriptor.color)
        var label: Label = item.label
        label.text = descriptor.text
        var dimensions := Vector2(ceilf(FONT.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,CALLOUT_FONT_SIZE).x)+18,CALLOUT_HEIGHT)
        var anchor := camera.unproject_position(descriptor.point)
        item.anchor = anchor
        # Zoomed/panned-offscreen locations must not masquerade as visible
        # equipment or draw leaders across the entire warehouse.
        if _selected.is_empty() and not Rect2(Vector2.ZERO, screen).has_point(anchor): continue
        var placement := _callout_rect(anchor,dimensions,int(descriptor.side),screen,occupied,protected)
        label.position = placement.position.round()
        label.size = placement.size
        label.visible = true
        var end := Vector2(clampf(anchor.x,placement.position.x+5,placement.end.x-5),clampf(anchor.y,placement.position.y+5,placement.end.y-5))
        var line: Line2D = item.line
        line.points = PackedVector2Array([anchor,end])
        line.visible = anchor.distance_to(end)>4
        item.anchor = anchor
        item.rect = Rect2(label.position,label.size)
        occupied.append(item.rect.grow(5))

func _callout_rect(anchor: Vector2, dimensions: Vector2, side: int, screen: Vector2, occupied: Array[Rect2], protected: Array[Rect2]) -> Rect2:
    var left := Vector2(-dimensions.x-14,-dimensions.y-5)
    var right := Vector2(14,-dimensions.y-5)
    var offsets: Array[Vector2] = [left if side<0 else right,right if side<0 else left,Vector2(-dimensions.x*.5,-dimensions.y-24),Vector2(-dimensions.x*.5,20),Vector2(-dimensions.x-20,4),Vector2(20,4)]
    # Include perimeter fallbacks for short editor viewports. Labels must remain
    # legible and separated even when a candidate is close to current equipment.
    for y in [CALLOUT_MARGIN,screen.y-dimensions.y-CALLOUT_MARGIN]:
        for x in [CALLOUT_MARGIN,screen.x-dimensions.x-CALLOUT_MARGIN]:
            offsets.append(Vector2(x,y)-anchor)
    var best := Rect2()
    var best_score := INF
    for index in offsets.size():
        var origin := anchor+offsets[index]
        origin.x = clampf(origin.x,CALLOUT_MARGIN,maxf(CALLOUT_MARGIN,screen.x-dimensions.x-CALLOUT_MARGIN))
        origin.y = clampf(origin.y,CALLOUT_MARGIN,maxf(CALLOUT_MARGIN,screen.y-dimensions.y-CALLOUT_MARGIN))
        var candidate := Rect2(origin,dimensions)
        var score := anchor.distance_to(candidate.get_center())+float(index)*4
        for rect in occupied:
            score += candidate.intersection(rect).get_area()*1000
        for rect in protected:
            score += candidate.intersection(rect).get_area()*4
        if score < best_score:
            best = candidate
            best_score = score
    return best
