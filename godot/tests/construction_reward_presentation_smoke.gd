extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const Rank2FacilityViewScript = preload("res://view/rank2_facility_view.gd")
const PreviewViewScript = preload("res://view/construction_preview_view.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_rank1_preview_lifecycle():
        return
    if not await _verify_rank2_preview_commit_transition():
        return

    print("Godot construction/reward presentation smoke passed")
    quit(0)


func _build_context(sim: FlotraV2Sim) -> Dictionary:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var preview: WarehouseConstructionPreviewView = PreviewViewScript.new()
    warehouse.add_child(preview)
    preview.bind(warehouse)

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.construction_preview_changed.connect(preview.show_preview)
    panel.construction_preview_cleared.connect(preview.clear_preview)
    panel.construction_committed.connect(preview.show_commit)

    return {
        "holder": holder,
        "warehouse": warehouse,
        "preview": preview,
        "panel": panel,
    }


func _verify_rank1_preview_lifecycle() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    var context := _build_context(sim)
    var holder: Node3D = context["holder"]
    var preview: WarehouseConstructionPreviewView = context["preview"]
    var panel: WarehouseZonePanel = context["panel"]

    panel.open_zone("storage")
    await process_frame

    var cash_before := sim.money
    panel._capital_action.emit_signal("pressed")
    await process_frame

    if sim.money != cash_before:
        _fail("Rank 1 first capital tap must not spend cash")
        return false
    if panel.preview_kind() != &"rack_wing":
        _fail("Rank 1 STORAGE first tap must enter Rack Wing preview")
        return false
    if not preview.has_preview() or preview.current_kind != &"rack_wing":
        _fail("Rank 1 preview signal must create a physical Rack Wing ghost")
        return false
    if preview.preview_child_count() < 5:
        _fail("Rank 1 Rack Wing preview must contain Zone outline plus planned geometry")
        return false
    if not _has_transparent_mesh(preview):
        _fail("planned construction geometry must be visually ghosted / transparent")
        return false

    panel.open_zone("packing")
    await process_frame
    if preview.has_preview():
        _fail("switching Zones must clear the previous construction ghost")
        return false
    if sim.money != cash_before:
        _fail("switching Zones after preview must not spend cash")
        return false

    panel._capital_action.emit_signal("pressed")
    await process_frame
    if panel.preview_kind() != &"second_packing_bench":
        _fail("PACKING first tap must enter Second Packing Bench preview")
        return false
    if preview.find_child("Ghost_SecondPackBench", true, false) == null:
        _fail("Second Packing Bench preview must show planned 3D geometry")
        return false

    panel.close()
    await process_frame
    if preview.has_preview() or preview.preview_child_count() != 0:
        _fail("closing the Zone Panel must remove all stale construction preview geometry")
        return false
    if sim.money != cash_before:
        _fail("closing preview without commit must not spend cash")
        return false

    panel.queue_free()
    holder.queue_free()
    await process_frame
    return true


func _verify_rank2_preview_commit_transition() -> bool:
    var sim := _rank2_sim()
    var context := _build_context(sim)
    var holder: Node3D = context["holder"]
    var warehouse: WarehouseView = context["warehouse"]
    var preview: WarehouseConstructionPreviewView = context["preview"]
    var panel: WarehouseZonePanel = context["panel"]

    var facilities: Rank2FacilityView = Rank2FacilityViewScript.new()
    warehouse.add_child(facilities)
    facilities.bind(warehouse, sim)

    panel.open_zone("storage")
    await process_frame

    var fast_button := _rank2_button(panel, "fast_pick_rack")
    var dense_button := _rank2_button(panel, "high_density_rack")
    if fast_button == null or dense_button == null:
        _fail("Rank 2 STORAGE must expose both previewable equipment choices")
        return false

    var cash_before := sim.money
    fast_button.emit_signal("pressed")
    await process_frame

    if sim.money != cash_before:
        _fail("Rank 2 first equipment tap must preview without spending cash")
        return false
    if preview.current_kind != &"fast_pick_rack":
        _fail("Fast Pick preview must drive the physical preview View")
        return false
    if preview.find_child("Ghost_FastPickRack", true, false) == null:
        _fail("Fast Pick preview must show planned rack geometry")
        return false

    dense_button.emit_signal("pressed")
    await process_frame
    if sim.money != cash_before:
        _fail("switching Rank 2 preview choice must not spend cash")
        return false
    if preview.current_kind != &"high_density_rack":
        _fail("selecting another equipment card must replace the active preview")
        return false
    if preview.find_child("Ghost_FastPickRack", true, false) != null:
        _fail("switching preview choices must not leave stale Fast Pick ghost geometry")
        return false
    if preview.find_child("Ghost_HighDensityRack", true, false) == null:
        _fail("High Density preview must replace the old ghost with planned geometry")
        return false

    dense_button.emit_signal("pressed")
    await process_frame
    facilities._process(0.0)
    await process_frame

    if sim.money >= cash_before:
        _fail("second Rank 2 tap must spend cash only after explicit commit")
        return false
    if preview.has_preview() or preview.preview_child_count() != 0:
        _fail("successful commit must clear planned ghost geometry")
        return false
    if facilities.find_child("Rank2Facility_HighDensityRack", true, false) == null:
        _fail("successful commit must replace ghost with real authoritative equipment geometry")
        return false

    var commit_nodes := preview.find_children("ConstructionCommit_*", "Node3D", true, false)
    if commit_nodes.is_empty():
        _fail("successful commit must leave a short selected-Zone reward emphasis")
        return false
    var commit_root := commit_nodes[0] as Node3D
    if commit_root == null or String(commit_root.get_meta("zone_key", "")) != "storage":
        _fail("construction reward emphasis must remain tied to the selected Zone")
        return false
    if not panel._action_message.text.contains("計測開始"):
        _fail("physical commit transition must remain linked to authoritative Before/After measurement")
        return false

    panel.queue_free()
    holder.queue_free()
    await process_frame
    return true


func _rank2_sim() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 250000
    for kind in sim.rank1_project_kinds():
        var result: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(result.get("ok", false)):
            _fail("preview seed must complete Rank 1 project: %s" % String(kind))
            return sim
    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    sim.shipped = maxi(sim.shipped, FlotraV2Sim.EXPANSION_SHIPMENTS) # Explicit Rank2 fixture, not pacing evidence.
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)):
        _fail("preview seed must expand to Rank 2")
        return sim
    sim.money = 250000
    sim.staffing_cooldown = 0.0
    return sim


func _rank2_button(panel: WarehouseZonePanel, kind: String) -> Button:
    for button in panel._rank2_capital_buttons:
        if String(button.get_meta("kind", "")) == kind:
            return button
    return null


func _has_transparent_mesh(root: Node) -> bool:
    for child in root.find_children("*", "MeshInstance3D", true, false):
        var mesh := child as MeshInstance3D
        if mesh == null:
            continue
        var material := mesh.material_override as StandardMaterial3D
        if material == null:
            continue
        if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 0.95:
            return true
    return false
