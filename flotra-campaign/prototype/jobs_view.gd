extends "res://prototype/layout_view.gd"

# All positions, occupied bays and manifested unit quantities come from JobsSim.
# Colour identifies actual work; it never changes completion or travel speed.
const BULK_COLOR := Color("e9b575")
const PICK_COLOR := Color("75d7ce")
var _bay_root: Node3D
var _bay_nodes: Dictionary = {}

func _ready() -> void:
    super._ready()
    _bay_root = Node3D.new()
    _bay_root.name = "AuthoritativeBulkBays"
    add_child(_bay_root)

func refresh() -> void:
    super.refresh()
    if sim == null or not is_node_ready() or _bay_root == null:
        return
    var state: Dictionary = sim.snapshot()
    _refresh_bays(state.get("bulk_bays", []))
    var annex_tag := get_node_or_null("AnnexLabel") as Label3D
    if annex_tag != null:
        annex_tag.text = "増築・保管床"
        annex_tag.font_size = 30


func _refresh_bays(bays: Array) -> void:
    var seen := {}
    for bay in bays:
        var id := str(bay.get("id", ""))
        seen[id] = true
        var bounds: Rect2 = bay.get("footprint", Rect2())
        var center := Vector3(bounds.get_center().x,0.0,bounds.get_center().y)
        if bounds.size == Vector2.ZERO:
            center = _position(bay.get("position",Vector3.ZERO))
            bounds = Rect2(center.x-.55,center.z-.55,1.1,1.1)
        if not _bay_nodes.has(id):
            var node := Node3D.new()
            node.name = "Bay_"+id
            _bay_root.add_child(node)
            _bay_nodes[id] = node
            _box(node,"Footprint",Vector3(bounds.size.x,.018,bounds.size.y),Vector3(0,.02,0),BULK_COLOR.darkened(.75))
            for x in [-bounds.size.x*.5,bounds.size.x*.5]:
                _box(node,"Boundary",Vector3(.035,.025,bounds.size.y),Vector3(x,.04,0),BULK_COLOR)
            for z in [-bounds.size.y*.5,bounds.size.y*.5]:
                _box(node,"Boundary",Vector3(bounds.size.x,.025,.035),Vector3(0,.04,z),BULK_COLOR)
            _label(node,"BayState","",Vector3(0,.10,bounds.size.y*.5+.14),BULK_COLOR,25)
        var node: Node3D = _bay_nodes[id]
        node.position = center
        var blocked := bool(bay.get("blocked", not bool(bay.get("available",true))))
        var occupied := bool(bay.get("occupied",false))
        node.visible = not blocked
        var tag := node.get_node("BayState") as Label3D
        tag.text = "" # Bay outlines carry capacity without overlapping world labels.
        var pad := node.get_node("Footprint") as MeshInstance3D
        pad.material_override = _material(BULK_COLOR.darkened(.56 if occupied else .78))
    for id in _bay_nodes.keys():
        if not seen.has(id):
            (_bay_nodes[id] as Node3D).queue_free()
            _bay_nodes.erase(id)

func _refresh_workers(workers: Array) -> void:
    super._refresh_workers(workers)
    for worker in workers:
        var id := str(worker.get("id",0))
        if not _actors.has(id):
            continue
        var node: Node3D = _actors[id]
        var kind := str(worker.get("job_kind",worker.get("kind","pick")))
        var units := int(worker.get("units",1))
        var parcel := node.get_node("CarriedParcel") as Node3D
        # The manifest carrier's reserved radius is .25; the individual
        # carrier's radius is .18. Keep the rendered load inside that envelope.
        parcel.position = Vector3(0,.60,0)
        parcel.scale = Vector3.ONE * (.89 if units > 1 else .64)
        var vest := node.get_node("SafetyVest") as Node3D
        vest.scale = Vector3(.85,1,.85)
        var carton := parcel.get_node("Carton") as MeshInstance3D
        carton.material_override = _material(BULK_COLOR if kind == "bulk" else PICK_COLOR)
        var tag := node.get_node_or_null("ManifestUnits") as Label3D
        if tag == null:
            tag = _label(node,"ManifestUnits","",Vector3(0,1.34,0),BULK_COLOR,26)
        tag.text = "%d箱" % units
        tag.modulate = BULK_COLOR if kind == "bulk" else PICK_COLOR
        tag.visible = bool(worker.get("carrying",false)) and units > 1

func _refresh_cargo(items: Array) -> void:
    # The domain retains every individual unit for conservation. Show an intact
    # bulk manifest/refill tote once, with its real contained unit count.
    var rendered: Array = []
    var groups: Dictionary = {}
    for original in items:
        var kind := str(original.get("job_kind",original.get("kind","pick")))
        var stage := str(original.get("stage",""))
        var intact := kind == "bulk" or stage in ["inbound","reserved_restock","carried_restock"]
        var grouped: bool = intact and original.has("manifest_id")
        if grouped:
            var key := str(original.manifest_id)+":"+stage
            if groups.has(key):
                rendered[int(groups[key])].units += 1
                continue
            groups[key] = rendered.size()
        # Only retained representatives reach presentation. Keep their input
        # order/identity and copy before changing units; skipped members never
        # had a visible node and do not need a second full dictionary copy.
        var item: Dictionary = original.duplicate(true)
        if grouped: item.units = 1
        rendered.append(item)
    super._refresh_cargo(rendered)
    for item in rendered:
        var id := str(item.get("id",0))
        if not _cargo.has(id):
            continue
        var node: Node3D = _cargo[id]
        var kind := str(item.get("job_kind",item.get("kind","pick")))
        var units := int(item.get("units",1))
        (node.get_node("Carton") as MeshInstance3D).material_override = _material(BULK_COLOR if kind == "bulk" else PICK_COLOR)
        var tag := node.get_node_or_null("UnitCount") as Label3D
        if tag == null:
            tag = _label(node,"UnitCount","",Vector3(0,.55,0),BULK_COLOR,24)
        tag.text = "%d箱" % units
        tag.modulate = BULK_COLOR if kind == "bulk" else PICK_COLOR
        tag.visible = units > 1
        if kind == "bulk":
            # A consolidated manifest sits inside its authoritative bay, rather
            # than receiving the individual-parcel station stacking offset.
            node.position = _position(item.get("position",Vector3.ZERO)) + Vector3(0,.25,0)

func _build_rack(parent: Node3D) -> void:
    super._build_rack(parent)
    # The inherited decorative beam protruded beyond the rack's declared 1.25
    # unit model depth. Keep the complete visible mesh inside Domain footprint.
    for child in parent.get_children():
        if child is MeshInstance3D and is_equal_approx((child as Node3D).position.z, .64):
            (child as Node3D).position.z = .59
