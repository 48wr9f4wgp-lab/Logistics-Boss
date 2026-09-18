extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_domain():
        return
    if not await _verify_ui():
        return

    print("Godot direct Zone staffing smoke passed")
    quit(0)


func _rank2_sim() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    for kind in sim.rank1_project_kinds():
        var result: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(result.get("ok", false)):
            _fail("staffing seed must complete Rank 1 project: %s" % String(kind))
            return sim
    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)):
        _fail("staffing seed must expand to Rank 2")
    return sim


func _verify_domain() -> bool:
    var sim := _rank2_sim()
    if sim.facility_rank != 2:
        return false

    var opening: Dictionary = sim.direct_staffing_summary()
    if int(opening.get("inbound", 0)) != 2 or int(opening.get("picking", 0)) != 2 or int(opening.get("shipping", 0)) != 1:
        _fail("Rank 2 direct staffing must begin at 2/2/1")
        return false

    var first := sim.reassign_zone_staffing("inbound", "picking")
    if not bool(first.get("ok", false)):
        _fail("direct staffing must move one worker from RECEIVING to PICKING")
        return false

    var after_first := sim.direct_staffing_summary()
    if int(after_first.get("inbound", 0)) != 1 or int(after_first.get("picking", 0)) != 3 or int(after_first.get("shipping", 0)) != 1:
        _fail("direct staffing reassignment must become 1/3/1")
        return false

    var role_summary: Dictionary = sim.staffing_summary()
    if int(role_summary.get("store", 0)) != 1 or int(role_summary.get("pick", 0)) != 3 or int(role_summary.get("ship", 0)) != 1:
        _fail("direct Zone counts must drive authoritative worker roles")
        return false

    var blocked := sim.reassign_zone_staffing("picking", "shipping")
    if bool(blocked.get("ok", false)) or String(blocked.get("reason", "")) != "cooldown":
        _fail("direct staffing must enforce the 30-second observation lock")
        return false

    sim.step(LogisticsProgression.STAFFING_COOLDOWN_SECONDS + 0.1)
    var second := sim.reassign_zone_staffing("picking", "shipping")
    if not bool(second.get("ok", false)):
        _fail("staffing must unlock after the observation window")
        return false

    var after_second := sim.direct_staffing_summary()
    if int(after_second.get("inbound", 0)) != 1 or int(after_second.get("picking", 0)) != 2 or int(after_second.get("shipping", 0)) != 2:
        _fail("second direct reassignment must become 1/2/2")
        return false

    sim.step(LogisticsProgression.STAFFING_COOLDOWN_SECONDS + 0.1)
    var minimum := sim.reassign_zone_staffing("inbound", "picking")
    if bool(minimum.get("ok", false)) or String(minimum.get("reason", "")) != "minimum":
        _fail("staffing must preserve at least one worker in every staffed flow")
        return false

    var saved := sim.save_data()
    if int(saved.get("schema_version", -1)) != FlotraV2Sim.SAVE_SCHEMA_V2:
        _fail("direct staffing must persist in schema 9")
        return false

    var restored: FlotraV2Sim = SimScript.new()
    if not restored.load_data(saved):
        _fail("schema 9 direct staffing save must reload")
        return false
    var restored_summary := restored.direct_staffing_summary()
    if int(restored_summary.get("inbound", 0)) != 1 or int(restored_summary.get("picking", 0)) != 2 or int(restored_summary.get("shipping", 0)) != 2:
        _fail("schema 9 must preserve direct Zone staffing exactly")
        return false

    var schema8 := saved.duplicate(true)
    schema8["schema_version"] = FlotraV2Sim.SAVE_SCHEMA_RANK1_V2
    schema8["staffing_plan"] = "picking"
    schema8.erase("zone_staffing")
    var migrated: FlotraV2Sim = SimScript.new()
    if not migrated.load_data(schema8):
        _fail("schema 8 staffing preset must migrate into schema 9")
        return false
    var migrated_summary := migrated.direct_staffing_summary()
    if int(migrated_summary.get("inbound", 0)) != 1 or int(migrated_summary.get("picking", 0)) != 3 or int(migrated_summary.get("shipping", 0)) != 1:
        _fail("schema 8 picking preset must migrate to direct 1/3/1 counts")
        return false

    return true


func _verify_ui() -> bool:
    var sim := _rank2_sim()
    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone("picking")
    await process_frame

    if not panel._operations.text.contains("担当Worker 2人"):
        _fail("PICKING Zone must show its current direct worker count")
        return false

    var visible_buttons: Array[Button] = []
    for button in panel._staffing_move_buttons:
        if button.visible:
            visible_buttons.append(button)
    if visible_buttons.size() != 2:
        _fail("a staffed Zone must expose the two possible worker sources")
        return false

    var receiving_button: Button = null
    var shipping_button: Button = null
    for button in visible_buttons:
        var source := String(button.get_meta("from_zone", ""))
        if source == "inbound":
            receiving_button = button
        elif source == "shipping":
            shipping_button = button

    if receiving_button == null or receiving_button.disabled:
        _fail("PICKING must allow a worker to move from RECEIVING when RECEIVING has 2")
        return false
    if shipping_button == null or not shipping_button.disabled:
        _fail("PICKING must protect SHIPPING when SHIPPING is already at the one-worker floor")
        return false

    receiving_button.emit_signal("pressed")
    await process_frame
    var changed := sim.direct_staffing_summary()
    if int(changed.get("inbound", 0)) != 1 or int(changed.get("picking", 0)) != 3:
        _fail("Zone Panel staffing action must update authoritative counts")
        return false
    if not panel._action_message.text.contains("観察") and not panel._action_message.text.contains("再配置"):
        _fail("Zone Panel must explain the staffing result/observation lock")
        return false

    panel.open_zone("packing")
    await process_frame
    for button in panel._staffing_move_buttons:
        if button.visible:
            _fail("PACKING must not fake direct Worker allocation")
            return false
    if not panel._operations.text.contains("Worker直接配置なし"):
        _fail("PACKING must explicitly state that it is equipment-processed")
        return false

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._v2_staffing_panel == null or not hud._v2_staffing_panel.visible:
        _fail("Rank 2 Management must expose executive staffing overview")
        return false
    if hud._v2_staffing_label == null or not hud._v2_staffing_label.text.contains("RECEIVING/STORAGE 1人"):
        _fail("Management staffing overview must reflect live direct allocation")
        return false
    if hud._staffing_grid != null and hud._staffing_grid.visible:
        _fail("legacy preset grid must remain hidden after direct staffing launches")
        return false

    hud.queue_free()
    panel.queue_free()
    await process_frame
    return true
