extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const ViewScript = preload("res://view/warehouse_view_mobile.gd")
const ZoneInteractionScript = preload("res://view/zone_interaction_view.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = SimScript.new()

    var view: MobileWarehouseView = ViewScript.new()
    get_root().add_child(view)
    view.bind_sim(sim)
    await process_frame

    var interaction: WarehouseZoneInteractionView = ZoneInteractionScript.new()
    view.add_child(interaction)
    interaction.bind(view)
    await process_frame
    await physics_frame

    var keys := interaction.zone_keys()
    if keys.size() != 5:
        _fail("v2 warehouse must expose exactly five top-level operational Zone targets")
        return
    for expected in ["inbound", "storage", "picking", "packing", "shipping"]:
        if expected not in keys:
            _fail("v2 warehouse is missing Zone target: %s" % expected)
            return
        if not interaction._zone_areas.has(expected):
            _fail("v2 Zone target must own a physical Area3D: %s" % expected)
            return
        if not interaction._zone_labels.has(expected):
            _fail("v2 Zone target must expose a readable world label: %s" % expected)
            return

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    interaction.zone_selected.connect(panel.open_zone)

    var storage_area := interaction._zone_areas["storage"] as Area3D
    var world_from := storage_area.global_position + Vector3(0.0, 12.0, 0.0)
    var world_to := storage_area.global_position - Vector3(0.0, 12.0, 0.0)
    var world_pick := interaction.pick_zone_from_ray(world_from, world_to)
    if world_pick != "storage":
        _fail("physical v2 Zone target ray must resolve STORAGE")
        return

    var storage_screen := view._camera.unproject_position(storage_area.global_position)
    var screen_pick := interaction._select_at_screen(storage_screen)
    if screen_pick != "storage":
        _fail("screen-space tap path must resolve the physical STORAGE Zone")
        return
    await process_frame
    if not panel.is_open() or panel.selected_zone() != "storage":
        _fail("selecting a 3D Zone must open the matching Zone Panel")
        return

    sim.packing_queue = 9
    sim.packed_queue = 2
    panel.open_zone("packing")
    panel._process(0.0)
    if not panel._title.text.contains("PACKING"):
        _fail("Zone Panel must identify the selected operational Zone")
        return
    if not panel._state.text.contains("CONGESTED"):
        _fail("Zone Panel must classify authoritative packing pressure")
        return
    if not panel._evidence.text.contains("梱包待ち 9箱"):
        _fail("Zone Panel must show concrete authoritative evidence instead of a recommendation")
        return
    if panel._operations.text.is_empty() or panel._capital.text.is_empty():
        _fail("Zone Panel must separate OPERATIONS and CAPITAL information hierarchy")
        return
    if panel._panel.anchor_top < 0.54 or panel._panel.anchor_top > 0.60:
        _fail("Zone Panel must remain a lower-sheet surface so the warehouse stays visible")
        return

    var rank2 = SimScript.new()
    rank2.facility_rank = 2
    rank2.logistics_rating = 8
    rank2.worker_count = 5
    rank2.money = 200000
    rank2.packing_queue = 9

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(rank2)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._v2_overview_panel == null or not hud._v2_overview_panel.visible:
        _fail("v2 mobile Management must open on an executive Overview shell")
        return
    if hud._v2_overview_label == null or not hud._v2_overview_label.text.contains("PACKING 混雑"):
        _fail("Management Overview must summarize Zone state without prescribing equipment")
        return

    for button in hud._upgrade_buttons.values():
        if (button as Button).visible:
            _fail("legacy repeated upgrades must not remain player-facing in mobile v2 Management")
            return
    for button in hud._facility_buttons.values():
        if (button as Button).visible:
            _fail("normal Rank 2 Zone equipment must not remain purchasable from mobile v2 Management")
            return
    if hud._staffing_grid != null and hud._staffing_grid.visible:
        _fail("legacy staffing presets must not remain player-facing during v2 staffing transition")
        return

    if hud._rp == null or hud._rp.get_parent() == null or hud._rp.get_parent().get_parent() is not PanelContainer:
        _fail("v2 HUD must retain the RP metric node for compatibility")
        return
    if (hud._rp.get_parent().get_parent() as PanelContainer).visible:
        _fail("RP must be hidden from the primary v2 HUD")
        return

    hud._render()
    if hud._bottleneck == null or not hud._bottleneck.text.contains("PACKING"):
        _fail("v2 Director must report the active packing symptom")
        return
    if not hud._bottleneck.text.contains("待機 9"):
        _fail("v2 Director must include concrete symptom evidence")
        return
    if hud._bottleneck.text.contains("強化") or hud._bottleneck.text.contains("→"):
        _fail("v2 Director must not reveal the action/equipment answer")
        return

    if hud._management_title == null or hud._management_title.text != "経営管理":
        _fail("mobile Management must present itself as management, not a capital store")
        return
    if hud._management_hint == null or not hud._management_hint.text.contains("Zone"):
        _fail("v2 Management must direct equipment decisions back to the warehouse Zones")
        return

    hud.queue_free()
    panel.queue_free()
    view.queue_free()
    await process_frame
    print("Godot v2 interaction skeleton smoke passed")
    quit(0)

