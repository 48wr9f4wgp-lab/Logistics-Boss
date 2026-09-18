extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const FacilityViewScript = preload("res://view/rank2_facility_view.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not await _verify_domain_and_persistence():
        return
    if not await _verify_zone_panel_flow():
        return
    if not await _verify_geometry_replacement():
        return

    print("Godot Rank 2 v2 renovation smoke passed")
    quit(0)


func _rank2_sim() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 250000
    for kind in sim.rank1_project_kinds():
        var result: Dictionary = sim.purchase_rank1_project(kind)
        if not bool(result.get("ok", false)):
            _fail("renovation seed must complete Rank 1 project: %s" % String(kind))
            return sim
    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)):
        _fail("renovation seed must expand to Rank 2")
        return sim
    sim.money = 250000
    sim.staffing_cooldown = 0.0
    return sim


func _verify_domain_and_persistence() -> bool:
    var sim := _rank2_sim()
    if sim.facility_rank != 2:
        return false

    var events: Array[Dictionary] = []
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        events.append(event.duplicate(true))
    )

    var base_capacity := sim.rack_capacity
    var start_money := sim.money

    var fast_build: Dictionary = sim.purchase_facility(&"fast_pick_rack")
    if not bool(fast_build.get("ok", false)) or String(fast_build.get("action", "")) != "build":
        _fail("Fast Pick Rack must support first-time build")
        return false
    if sim.selected_facility_for_group("storage") != "fast_pick_rack":
        _fail("Fast Pick Rack must become the only active STORAGE mode")
        return false
    if sim.rack_capacity != base_capacity + 12:
        _fail("Fast Pick Rack must authoritatively add 12 storage slots")
        return false
    if start_money - sim.money != 13000:
        _fail("Fast Pick Rack fresh build must cost ¥13,000")
        return false

    var high_info: Dictionary = sim.rank2_v2_equipment_action_info(&"high_density_rack")
    if not bool(high_info.get("renovating", false)) or int(high_info.get("cost", 0)) != 9000:
        _fail("High Density Rack must expose 75% paid renovation after Fast Pick")
        return false

    var before_high_money := sim.money
    var high_renovation: Dictionary = sim.purchase_facility(&"high_density_rack")
    if not bool(high_renovation.get("ok", false)) or String(high_renovation.get("action", "")) != "renovate":
        _fail("STORAGE must renovate Fast Pick → High Density")
        return false
    if before_high_money - sim.money != 9000:
        _fail("High Density renovation must cost ¥9,000 with no refund")
        return false
    if bool(sim.facilities.get("fast_pick_rack", true)) or not bool(sim.facilities.get("high_density_rack", false)):
        _fail("STORAGE renovation must leave exactly one active mode")
        return false
    if sim.rack_capacity != base_capacity + 16:
        _fail("High Density renovation must replace the STORAGE capacity contribution")
        return false

    sim.rack_stock = sim.rack_capacity
    var stock_before_downsize := sim.rack_stock
    var before_fast_money := sim.money
    var fast_renovation: Dictionary = sim.purchase_facility(&"fast_pick_rack")
    if not bool(fast_renovation.get("ok", false)):
        _fail("STORAGE must renovate High Density → Fast Pick")
        return false
    if before_fast_money - sim.money != 9750:
        _fail("Fast Pick renovation must cost ¥9,750 with no refund")
        return false
    if sim.rack_capacity != base_capacity + 12:
        _fail("Fast Pick renovation must restore the lower-capacity STORAGE mode")
        return false
    if sim.rack_stock != stock_before_downsize:
        _fail("renovating to lower STORAGE capacity must never delete existing inventory")
        return false

    var parallel_build: Dictionary = sim.purchase_facility(&"parallel_pack")
    if not bool(parallel_build.get("ok", false)) or String(parallel_build.get("action", "")) != "build":
        _fail("Parallel Pack Line must support first-time build")
        return false
    if int(sim.call("_packing_capacity")) != 2:
        _fail("Parallel Pack Line must authoritatively provide two concurrent jobs")
        return false
    var parallel_duration := float(sim.call("_packing_duration"))
    if absf(parallel_duration - 3.3) > 0.01:
        _fail("Parallel Pack Line must preserve its 10% per-box slowdown")
        return false

    var fast_cell_info: Dictionary = sim.rank2_v2_equipment_action_info(&"fast_pack_cell")
    if int(fast_cell_info.get("cost", 0)) != 9750 or not bool(fast_cell_info.get("renovating", false)):
        _fail("Fast Pack Cell must expose 75% paid renovation from Parallel Pack")
        return false

    var fast_cell_renovation: Dictionary = sim.purchase_facility(&"fast_pack_cell")
    if not bool(fast_cell_renovation.get("ok", false)):
        _fail("PACKING must renovate Parallel Pack → Fast Pack Cell")
        return false
    if int(sim.call("_packing_capacity")) != 1:
        _fail("Fast Pack Cell must replace the Rank 1 second bench and retain one-job weakness")
        return false
    var fast_cell_duration := float(sim.call("_packing_duration"))
    if absf(fast_cell_duration - 1.74) > 0.01:
        _fail("Fast Pack Cell must authoritatively process a single job 42% faster")
        return false

    var saved: Dictionary = sim.save_data()
    var restored: FlotraV2Sim = SimScript.new()
    if not restored.load_data(saved):
        _fail("schema 9 renovation state must reload")
        return false
    if restored.selected_facility_for_group("storage") != "fast_pick_rack":
        _fail("save/load must preserve renovated STORAGE mode")
        return false
    if restored.selected_facility_for_group("packing") != "fast_pack_cell":
        _fail("save/load must preserve renovated PACKING mode")
        return false
    if int(restored.call("_packing_capacity")) != 1:
        _fail("save/load must preserve Fast Pack Cell authoritative weakness")
        return false

    if not _has_event(events, "facility_renovated", "high_density_rack"):
        _fail("renovation must emit an authoritative facility_renovated event")
        return false

    var measured := _rank2_sim()
    var measurement_events: Array[Dictionary] = []
    measured.event_emitted.connect(func(event: Dictionary) -> void:
        measurement_events.append(event.duplicate(true))
    )
    for _index in 270:
        measured.step(0.1)
    if not bool(measured.purchase_facility(&"fast_pick_rack").get("ok", false)):
        _fail("measurement seed must build Fast Pick Rack")
        return false
    for _index in 270:
        measured.step(0.1)
    var renovation: Dictionary = measured.purchase_facility(&"high_density_rack")
    if String(renovation.get("measurement_kind", "")) != "renovation_high_density_rack":
        _fail("renovation must start a distinct authoritative Before/After measurement")
        return false
    for _index in 270:
        measured.step(0.1)
    if not _has_measurement(measurement_events, "renovation_high_density_rack"):
        _fail("renovation Before/After measurement must complete after the real window")
        return false

    return true


func _verify_zone_panel_flow() -> bool:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(&"fast_pick_rack").get("ok", false)):
        return false

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone("storage")
    await process_frame

    var high_button := _button_for_kind(panel, "high_density_rack")
    if high_button == null:
        _fail("STORAGE Zone must expose High Density Rack beside the active Fast Pick Rack")
        return false

    var money_before_preview := sim.money
    high_button.emit_signal("pressed")
    await process_frame
    if sim.money != money_before_preview:
        _fail("first Rank 2 equipment tap must preview without spending cash")
        return false
    if not panel._action_message.text.contains("強み") or not panel._action_message.text.contains("弱み"):
        _fail("Rank 2 preview must show explicit strength and weakness")
        return false
    if not high_button.text.contains("改装する"):
        _fail("second-step Rank 2 commitment must explicitly say renovate")
        return false

    high_button.emit_signal("pressed")
    await process_frame
    if sim.selected_facility_for_group("storage") != "high_density_rack":
        _fail("second Rank 2 tap must commit the STORAGE renovation")
        return false
    if not panel._equipment.text.contains("高密度ラック"):
        _fail("Zone Panel current equipment must immediately show the renovated Rank 2 system")
        return false
    if not panel._action_message.text.contains("計測開始"):
        _fail("renovation result must keep Before/After feedback readable")
        return false

    panel.open_zone("packing")
    await process_frame
    var visible_count := 0
    for button in panel._rank2_capital_buttons:
        if button.visible:
            visible_count += 1
    if visible_count != 2:
        _fail("PACKING Zone must expose both Rank 2 equipment approaches")
        return false

    panel.queue_free()
    await process_frame
    return true


func _verify_geometry_replacement() -> bool:
    var sim := _rank2_sim()
    if not bool(sim.purchase_facility(&"fast_pick_rack").get("ok", false)):
        return false
    if not bool(sim.purchase_facility(&"parallel_pack").get("ok", false)):
        return false

    var holder := Node3D.new()
    get_root().add_child(holder)

    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var facilities: Rank2FacilityView = FacilityViewScript.new()
    warehouse.add_child(facilities)
    facilities.bind(warehouse, sim)
    await process_frame
    await process_frame

    if facilities.find_child("Rank2Facility_FastPickRack", true, false) == null:
        _fail("Fast Pick Rack geometry must exist before renovation")
        return false
    if facilities.find_child("Rank2Facility_ParallelPack", true, false) == null:
        _fail("Parallel Pack geometry must exist before renovation")
        return false

    if not bool(sim.purchase_facility(&"high_density_rack").get("ok", false)):
        return false
    if not bool(sim.purchase_facility(&"fast_pack_cell").get("ok", false)):
        return false
    facilities._process(0.0)
    await process_frame
    await process_frame

    if facilities.find_child("Rank2Facility_FastPickRack", true, false) != null:
        _fail("renovation must remove old Fast Pick Rack geometry")
        return false
    if facilities.find_child("Rank2Facility_HighDensityRack", true, false) == null:
        _fail("renovation must create High Density Rack geometry")
        return false
    if facilities.find_child("Rank2Facility_ParallelPack", true, false) != null:
        _fail("renovation must remove old Parallel Pack geometry")
        return false
    if facilities.find_child("Rank2Facility_FastPackCell", true, false) == null:
        _fail("renovation must create Fast Pack Cell geometry")
        return false

    holder.queue_free()
    await process_frame
    return true


func _button_for_kind(panel: WarehouseZonePanel, kind: String) -> Button:
    for button in panel._rank2_capital_buttons:
        if String(button.get_meta("kind", "")) == kind:
            return button
    return null


func _has_event(events: Array[Dictionary], event_type: String, kind: String) -> bool:
    for event in events:
        if String(event.get("type", "")) == event_type and String(event.get("kind", "")) == kind:
            return true
    return false


func _has_measurement(events: Array[Dictionary], kind: String) -> bool:
    for event in events:
        if String(event.get("type", "")) == "measurement_completed" and String(event.get("kind", "")) == kind:
            return true
    return false
