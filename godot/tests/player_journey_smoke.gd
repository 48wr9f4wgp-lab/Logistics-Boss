extends "res://tests/mobile_notification_clearance_smoke.gd"

# Regression of the composed player journey, not a balance or device claim.
# Every run requires a disposable profile; fixture money/rank is explicit below.
const MainScene = preload("res://scenes/main.tscn")
var _checks := 0


func _expect(value: bool, message: String) -> void:
    _checks += 1
    super._expect(value, message)


func _run() -> void:
    if OS.get_environment("FLOTRA_POLISH_ISOLATED") != "1":
        push_error("player_journey_smoke requires the isolated-profile runner")
        quit(1)
        return
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    for dimensions in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(430, 932)]:
        get_root().size = dimensions
        print("Player journey viewport=%s" % str(dimensions))
        await _verify_composed_journey()
    await _verify_overlapping_measurements()
    await _verify_legacy_result_preservation()
    for family in ["upgrade", "facility", "renovation", "annex", "routing", "carrier", "rank1", "growth", "capacity"]:
        await _verify_result_lifecycle(family, false)
        await _verify_result_lifecycle(family, true)
    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    print("Player journey checks=%d; failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _verify_composed_journey() -> void:
    var app := MainScene.instantiate()
    get_root().add_child(app)
    # Freeze wall-clock Domain stepping and autosaves, while production UI still
    # receives genuine engine events. Tests advance only Domain simulation time.
    app.set_process(false)
    var sim := app.get("sim") as FlotraV2Sim
    var hud: MobileGameHud
    for child in app.get_children():
        if child is MobileGameHud:
            hud = child
    _expect(hud != null, "Actual main scene includes the production mobile HUD")
    if hud == null:
        app.queue_free()
        await _settle()
        return
    var zone: WarehouseZonePanel
    var coach: V2Rank1Coach
    for child in hud.get_children():
        if child is WarehouseZonePanel:
            zone = child
        if child is V2Rank1Coach:
            coach = child
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    _expect(zone != null and coach != null and clarity != null, "Main composes Zone Panel, coach and interaction routing")
    if zone == null or coach == null or clarity == null:
        app.queue_free()
        await _settle()
        return
    coach._persist_completion = false
    sim.money = 100000 # Explicit UI fixture, never natural earnings evidence.
    sim.inbound_queue = 8
    coach._process(0.1)
    await _settle()
    _expect(coach.current_step_key() == "inspect", "Fresh main advances from observation to inspection")
    _engine_tap(hud._v2_growth_goal)
    await _settle()
    _expect(hud._sheet.visible and clarity._section == "field", "Actual growth goal opens the Management field section")
    _engine_tap(hud._v2_zone_nav_buttons["inbound"] as Button)
    await _settle()
    _expect(zone.is_open() and zone.selected_zone() == "inbound" and not hud._sheet.visible, "Field navigation opens the real inbound Zone Panel")
    _expect(coach.current_step_key() == "act", "Opening a Zone from Management advances the actual main coach")
    _expect(coach._zone_interaction.guidance_zone().is_empty(), "Management navigation clears world inspection guidance")
    var before_money := sim.money
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.money == before_money and zone.preview_kind() == &"forklift_project", "First investment tap is a non-spending preview")
    _expect(clarity.router.button_at(zone._capital_action.get_global_rect().get_center()) == zone._capital_action, "Preview must leave the capital confirmation center inside the visible input clip")
    _expect(zone._scroll.get_global_rect().encloses(zone._capital_action.get_global_rect()), "Forklift preview keeps the whole confirmation label and hit area inside the scroll clip")
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.forklift_unlocked and sim.money < before_money and not zone.is_open(), "Second investment tap buys once and returns to the warehouse")
    _expect(coach.current_step_key() == "measure", "Production investment event advances coach to measurement")
    await _verify_measurement_clock(sim, hud, "フォークリフト", "Rank 1 project")
    _expect(coach.current_step_key() == "complete", "Matching authoritative result completes the actual main coach")

    # Failed operations must survive the normal per-frame render and pause/speed
    # changes, and must not follow the player into a different Zone.
    zone.open_zone("picking")
    sim.money = 0
    var blocked_snapshot := sim.save_data()
    zone._on_operations_action()
    var failure_text := zone._action_message.text
    _expect(failure_text.contains("資金"), "Unaffordable worker action provides an explicit reason")
    _expect(sim.save_data() == blocked_snapshot, "Failed action and notice rendering leave authoritative state unchanged")
    _expect(not zone._scroll.is_ancestor_of(zone._action_message) and zone._action_message.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Only the active failure notice is pinned outside scrolling content and remains passive")
    _expect(zone._action_message.get_theme_font_size("font_size") >= 12, "Pinned action failure remains readable")
    zone._process(0.1)
    _expect(zone._action_message.visible and zone._action_message.text == failure_text, "Action failure survives the next render")
    sim.set_time_scale(4.0)
    sim.step(2.0)
    zone._process(1.0)
    _expect(zone._action_message.visible and zone._action_message.text == failure_text, "Failure reading time is not consumed by accelerated simulation")
    zone.open_zone("storage")
    _expect(zone._action_message.text != failure_text, "Opening another Zone clears the prior action failure")
    zone.close()
    sim.set_time_scale(1.0)
    sim.money = 100000

    # Authoritative purchases establish a Rank 2 UI fixture. Shipments are seeded
    # only to cross its boundary; economy/progression tests cover natural pacing.
    zone.open_zone("storage")
    await _settle()
    before_money = sim.money
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.money == before_money and zone.preview_kind() == &"rack_wing", "Storage investment tap opens its non-spending preview")
    _expect(zone._scroll.get_global_rect().encloses(zone._capital_action.get_global_rect()), "Storage preview keeps the whole confirmation label and hit area inside the scroll clip")
    _expect(zone._scroll.is_ancestor_of(zone._action_message) and not zone._action_message.text.is_empty(), "Long storage preview details remain inside scrolling content")
    _engine_tap(zone._capital_action)
    await _settle()
    _expect(sim.rank1_project_owned(&"rack_wing") and sim.money == before_money - sim.RACK_WING_COST and not zone.is_open(), "Storage confirmation buys the second equipment family exactly once and reveals the warehouse")
    sim.shipped = sim.EXPANSION_SHIPMENTS
    _expect(bool(sim.purchase_warehouse_expansion().get("ok", false)), "Fixture reaches Rank 2 through authoritative expansion API")
    _advance_domain(sim, 30.0)
    hud._process(11.0)
    await _settle()

    zone.open_zone("inbound")
    await _settle()
    before_money = sim.money
    _engine_tap(zone._automation_action)
    await _settle()
    _expect(sim.money == before_money and zone.preview_kind() == &"extra_forklift", "Growth automation also previews without spending")
    _expect(clarity.router.button_at(zone._automation_action.get_global_rect().get_center()) == zone._automation_action, "Automation preview retains a reachable confirmation target")
    _engine_tap(zone._automation_action)
    await _settle()
    _expect(sim.extra_forklift_owned and not zone.is_open(), "Growth automation commits and exposes warehouse observation")
    await _verify_measurement_clock(sim, hud, "フォークリフト2号車", "Growth automation")

    zone.open_zone("packing")
    await _settle()
    before_money = sim.money
    _engine_tap(zone._capacity_action)
    await _settle()
    _expect(sim.money == before_money and zone.preview_kind() == &"packing_cell_1", "Capacity action previews the exact next unit")
    _expect(clarity.router.button_at(zone._capacity_action.get_global_rect().get_center()) == zone._capacity_action, "Capacity preview retains a reachable confirmation target")
    _engine_tap(zone._capacity_action)
    await _settle()
    _expect(sim.packing_cells == 1 and not zone.is_open(), "Capacity commit adds exactly one cell and returns to observation")
    await _verify_measurement_clock(sim, hud, "梱包セル", "Capacity investment")

    # A later legacy facility event must not revive the expired capacity result.
    zone.open_zone("storage")
    await _settle()
    var facility_button: Button
    for button in zone._rank2_capital_buttons:
        if String(button.get_meta("kind", "")) == "fast_pick_rack":
            facility_button = button
    _expect(facility_button != null, "Actual main exposes the Rank 2 storage facility action")
    if facility_button != null:
        zone._scroll.ensure_control_visible(facility_button)
        await _settle()
        before_money = sim.money
        _engine_tap(facility_button)
        await _settle()
        _expect(sim.money == before_money and zone.preview_kind() == &"fast_pick_rack", "Facility tap previews without spending after the previous result expires")
        zone._scroll.ensure_control_visible(facility_button)
        await _settle()
        _expect(clarity.router.button_at(facility_button.get_global_rect().get_center()) == facility_button, "Facility preview retains its engine-touch confirmation target")
        _engine_tap(facility_button)
        await _settle()
        _expect(bool(sim.facilities.get("fast_pick_rack", false)) and sim.money == before_money - sim.facility_cost(&"fast_pick_rack") and not zone.is_open(), "Facility confirmation buys exactly once and exposes fresh feedback")
        await _verify_measurement_clock(sim, hud, "高速棚", "Facility after expired result")

    # A stale preview is an actual failed Domain action. Invoke its handler
    # directly because normal disabled controls correctly block unsafe taps.
    zone.open_zone("packing")
    zone._on_capacity_action()
    zone._capacity_expected = -1
    zone._on_capacity_action()
    failure_text = zone._action_message.text
    _expect(failure_text.contains("増設できません"), "Stale capacity commit gives a meaningful failure notice")
    zone._process(0.5)
    _expect(zone._action_message.visible and zone._action_message.text == failure_text, "Capacity failure survives preview cleanup and refresh")
    zone.close()
    zone.open_zone("packing")
    _expect(zone._action_message.text != failure_text, "Closing and reopening a Zone clears stale action notices")
    app.queue_free()
    await _settle()


func _verify_measurement_clock(sim: FlotraV2Sim, hud: MobileGameHud, equipment: String, category: String) -> void:
    hud._process(0.0)
    await _settle()
    _verify_feedback_clearance(hud, category + " progress")
    _expect(hud._measurement_panel.visible and hud._measurement_label.text.contains("計測中"), "%s starts a visible measurement banner" % category)
    _expect(hud._measurement_label.text.contains(equipment), "%s banner identifies the investment" % category)
    _expect(hud._measurement_label.text.contains("25秒"), "%s begins with the authoritative 25-second window" % category)
    _verify_measuring_style(hud, category)
    sim.set_time_scale(0.0)
    var paused_at := sim.sim_time
    sim.step(35.0)
    hud._process(35.0)
    _expect(is_equal_approx(sim.sim_time, paused_at), "%s pause freezes authoritative time" % category)
    _expect(hud._measurement_panel.visible and hud._measurement_label.text.contains("計測中"), "%s measurement remains visible beyond the old wall-clock timeout while paused" % category)
    _expect(hud._measurement_label.text.contains("停止") and hud._measurement_label.text.contains("25秒"), "%s paused status explains the unchanged remaining simulation time" % category)
    await _settle()
    _verify_feedback_clearance(hud, category + " paused progress")
    sim.set_time_scale(4.0)
    _advance_domain(sim, 1.25)
    hud._process(1.25)
    _expect(hud._measurement_label.text.contains("20秒"), "%s countdown follows 4x simulation time rather than real time" % category)
    sim.set_time_scale(1.0)
    _advance_domain(sim, 20.1)
    hud._process(0.0)
    _expect(hud._measurement_panel.visible and not hud._measurement_label.text.contains("計測中"), "%s authoritative completion replaces the progress banner" % category)
    _expect(hud._measurement_label.text.contains(equipment) and hud._measurement_label.text.contains("→"), "%s completion identifies equipment and observed before/after result" % category)
    await _settle()
    _verify_feedback_clearance(hud, category + " result")
    hud._process(11.0) # Finish reading this result before the next single-investment fixture.


func _advance_domain(sim: FlotraV2Sim, real_seconds: float) -> void:
    var remaining := real_seconds
    while remaining > 0.0001:
        var tick := minf(0.1, remaining)
        sim.step(tick)
        remaining -= tick


func _verify_feedback_clearance(hud: MobileGameHud, phase: String) -> void:
    var panel_rect := hud._measurement_panel.get_global_rect()
    var dock := hud._find_bottom_dock()
    _expect(not panel_rect.intersects(dock.get_global_rect()), "%s leaves the permanent control dock unobstructed" % phase)
    _expect(panel_rect.encloses(hud._measurement_label.get_global_rect()), "%s keeps all wrapped feedback inside its panel" % phase)
    _expect(panel_rect.position.y >= 0.0 and panel_rect.end.y <= hud.get_viewport().get_visible_rect().size.y, "%s remains within the portrait canvas" % phase)
    var routes: SelectedWorkRoutes
    for child in hud.get_parent().get_children():
        if child is WarehouseView:
            routes = child.get_node_or_null("SelectedWorkRoutes") as SelectedWorkRoutes
    _expect(routes != null, "Actual main includes selected route controls")
    if routes != null:
        routes._process(0.0)
        for button in [routes.overview, routes.toggle]:
            _expect(not panel_rect.intersects(button.get_global_rect()), "%s leaves %s outside the feedback panel" % [phase, button.text])


func _verify_overlapping_measurements() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    sim.facility_rank = 2 # Explicit measurement fixture, not progression evidence.
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await _settle()
    _expect(bool(sim.purchase_capacity(&"packing_cell", 0).get("ok", false)), "First same-kind investment succeeds")
    _advance_domain(sim, 5.0)
    _expect(bool(sim.purchase_capacity(&"packing_cell", 1).get("ok", false)), "Second same-kind investment succeeds independently")
    hud._process(0.0)
    _expect(hud._measurement_label.text.contains("ほか1件") and hud._measurement_label.text.contains("複数変更"), "Overlapping progress discloses other measurements and attribution limits")
    _advance_domain(sim, 20.1)
    hud._process(0.0)
    var first_result := hud._measurement_label.text
    _expect(not first_result.contains("計測中") and first_result.contains("複数変更"), "First completed overlapping investment exposes the actual qualified result")
    sim.set_time_scale(0.0)
    hud._sheet.visible = true
    hud._process(40.0)
    _expect(not hud._measurement_panel.visible and hud._measurement_label.text == first_result, "Management defers a completed result without consuming reading time")
    hud._sheet.visible = false
    hud._process(0.0)
    _expect(hud._measurement_panel.visible and hud._measurement_label.text == first_result, "Closing Management restores the unread result before pending status")
    hud._process(11.0)
    _expect(hud._measurement_label.text.contains("計測中") and hud._measurement_label.text.contains("5秒"), "Same-kind completion removes only the oldest watch; later countdown survives")
    sim.set_time_scale(1.0)
    _advance_domain(sim, 5.0)
    hud._process(0.0)
    var second_result := hud._measurement_label.text
    _expect(not second_result.contains("計測中"), "The later same-kind completion produces its own result")
    _expect(bool(sim.purchase_capacity(&"packing_cell", 2).get("ok", false)), "A further investment can start during result reading time")
    hud._process(0.0)
    _expect(hud._measurement_label.text == second_result, "A new capacity purchase preserves an unread completed result")
    hud._process(11.0)
    _expect(hud._measurement_label.text.contains("計測中") and hud._measurement_label.text.contains("25秒"), "New purchase progress appears after the preserved result reading time")
    _advance_domain(sim, 25.1)
    hud._process(11.0)
    _expect(not hud._measurement_panel.visible, "All repeated-kind completions leave no orphan progress banner")
    sim.money = 100000
    _expect(bool(sim.purchase_capacity(&"dispatch_lane", 0).get("ok", false)), "First simultaneous dispatch investment succeeds")
    _expect(bool(sim.purchase_capacity(&"dispatch_lane", 1).get("ok", false)), "Second same-kind investment can share exactly the same simulation timestamp")
    hud._process(0.0)
    _expect(hud._measurement_label.text.contains("ほか1件"), "Simultaneous same-kind investments keep separate watches")
    _advance_domain(sim, 25.1)
    hud._process(0.0)
    _expect(hud._measurement_label.text.contains("自動出荷レーン") and not hud._measurement_label.text.contains("計測中"), "Both simultaneous authoritative completions deliver the named result")
    hud._process(11.0)
    _expect(not hud._measurement_panel.visible, "Same-tick completions remove both watches without a phantom countdown")
    hud.queue_free()
    await _settle()


func _verify_measuring_style(hud: MobileGameHud, category: String) -> void:
    var style := hud._measurement_panel.get_theme_stylebox("panel") as StyleBoxFlat
    _expect(hud._measurement_label.get_theme_font_size("font_size") == 13, "%s uses the measuring font rather than the previous verdict font" % category)
    _expect(hud._measurement_label.get_theme_color("font_color").is_equal_approx(Color(0.90, 0.98, 1.0)) and style.border_color.is_equal_approx(Color(0.18, 0.72, 0.96, 0.92)), "%s uses measuring colors rather than the previous verdict colors" % category)


func _verify_result_lifecycle(family: String, unread: bool) -> void:
    var category := "%s after %s result" % [family, "unread" if unread else "expired"]
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 1000000 # Explicit fixtures, never natural progression evidence.
    sim.forklift_unlocked = true
    if family in ["facility", "renovation", "growth", "capacity"]:
        sim.facility_rank = 2
    elif family in ["annex", "routing", "carrier"]:
        sim.facility_rank = 3
    if family == "carrier":
        sim.receiving_annex_unlocked = true
    if family == "renovation":
        sim.facilities["fast_pick_rack"] = true
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    hud.set_process(false) # Drive reading time explicitly, independently of frames.
    await _settle()
    _expect(bool(sim.purchase_upgrade(&"speed").get("ok", false)), "%s starts with a genuine investment" % category)
    _advance_domain(sim, 25.1)
    hud._process(0.0)
    var result := hud._measurement_label.text
    var result_color := hud._measurement_label.get_theme_color("font_color")
    var result_border := (hud._measurement_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color
    _expect(hud._pending_measurements.is_empty() and result.contains("搬送訓練") and not result.contains("計測中"), "%s begins only after the previous authoritative completion empties the queue" % category)
    hud._process(3.0 if unread else 11.0)
    var reading_time := hud._measurement_timer
    if unread:
        hud._sheet.visible = true
        hud._process(40.0)
    else:
        _expect(not hud._measurement_panel.visible and reading_time <= 0.0, "%s has fully expired before the next event" % category)
    sim.set_time_scale(0.0)
    var purchase: Dictionary
    match family:
        "upgrade": purchase = sim.purchase_upgrade(&"rack")
        "facility": purchase = sim.purchase_facility(&"fast_pick_rack")
        "renovation": purchase = sim.purchase_facility(&"high_density_rack")
        "annex": purchase = sim.purchase_receiving_annex()
        "routing": purchase = sim.set_routing_mode("express")
        "carrier": purchase = sim.purchase_inbound_carrier_program()
        "rank1": purchase = sim.purchase_rank1_project(&"rack_wing")
        "growth": purchase = sim.purchase_growth_automation(&"extra_forklift")
        "capacity": purchase = sim.purchase_capacity(&"packing_cell", 0)
    _expect(bool(purchase.get("ok", false)) and hud._pending_measurements.size() == 1, "%s creates exactly one new authoritative watch" % category)
    if unread:
        hud._process(40.0)
        _expect(not hud._measurement_panel.visible and hud._measurement_label.text == result and is_equal_approx(hud._measurement_timer, reading_time), "%s preserves hidden result text and remaining reading time through the purchase" % category)
        _expect(hud._measurement_label.get_theme_font_size("font_size") == 12 and hud._measurement_label.get_theme_color("font_color") == result_color and (hud._measurement_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color == result_border, "%s preserves the unread verdict styling" % category)
        hud._sheet.visible = false
        hud._process(0.0)
        _expect(hud._measurement_panel.visible and hud._measurement_label.text == result, "%s restores the unread result when Management closes" % category)
        hud._process(reading_time + 0.1)
    hud._process(0.0)
    _expect(hud._measurement_panel.visible and hud._measurement_label.text.contains("残り25秒") and hud._measurement_label.text.contains("一時停止中"), "%s immediately shows the fresh paused countdown" % category)
    _verify_measuring_style(hud, category)
    var paused_at := sim.sim_time
    sim.step(35.0)
    hud._process(35.0)
    _expect(is_equal_approx(sim.sim_time, paused_at) and hud._measurement_label.text.contains("残り25秒") and hud._measurement_label.text.contains("一時停止中"), "%s retains the paused countdown beyond the legacy timeout" % category)
    sim.set_time_scale(4.0)
    _advance_domain(sim, 1.275) # 5.1 game seconds avoids a floating-point ceil boundary.
    hud._process(1.275)
    _expect(is_equal_approx(sim.sim_time, paused_at + 5.1) and hud._measurement_label.text.contains("残り20秒") and not hud._measurement_label.text.contains("一時停止中"), "%s follows resumed 4x simulation time" % category)
    _verify_measuring_style(hud, category + " resumed")
    sim.set_time_scale(1.0)
    _advance_domain(sim, 20.1)
    hud._process(0.0)
    _expect(hud._pending_measurements.is_empty() and hud._measurement_panel.visible and not hud._measurement_label.text.contains("計測中") and hud._measurement_label.text.contains("→"), "%s ends only on the new authoritative completion" % category)
    hud._process(11.0)
    _expect(not hud._measurement_panel.visible, "%s leaves no orphan measurement after its own result expires" % category)
    hud.queue_free()
    await _settle()


func _verify_legacy_result_preservation() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await _settle()
    _expect(bool(sim.purchase_upgrade(&"speed").get("ok", false)), "Legacy measurement fixture uses an authoritative upgrade")
    _advance_domain(sim, 25.1)
    hud._process(0.0)
    var result := hud._measurement_label.text
    _expect(result.contains("搬送訓練") and not result.contains("計測中"), "Legacy investment produces its named before/after result")
    _expect(bool(sim.purchase_upgrade(&"rack").get("ok", false)), "Another legacy investment can begin while that result is visible")
    hud._process(0.0)
    _expect(hud._measurement_label.text == result, "Superclass legacy event handling cannot overwrite the unread result")
    hud._process(11.0)
    _expect(hud._measurement_label.text.contains("棚の増設") and hud._measurement_label.text.contains("25秒"), "Preserved legacy result gives way to its new pending measurement")
    _advance_domain(sim, 25.1)
    hud._process(11.0)
    _expect(not hud._measurement_panel.visible, "Legacy event completion also clears every pending watch")
    hud.queue_free()
    await _settle()
