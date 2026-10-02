extends "res://tests/mobile_interaction_clarity_smoke.gd"

# Dedicated presentation regressions. Fixtures never load/write player saves.
# Failed actions are compared against complete authoritative save snapshots;
# rendering/notice lifetime must not introduce any economy or ownership changes.

func _run() -> void:
    get_root().size = Vector2i(390, 844)
    await _verify_hire_notice_lifecycle()
    await _verify_rank1_capital_failure()
    await _verify_rank2_build_and_renovation_failures()
    await _verify_staffing_failures()
    for viewport_size in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(430, 932)]:
        get_root().size = viewport_size
        await _verify_visible_mobile_notice()
    print("Zone action feedback checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)


func _bare_panel(sim: FlotraV2Sim, zone_key: String) -> WarehouseZonePanel:
    var panel: WarehouseZonePanel = ZoneScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone(zone_key)
    return panel


func _rank2_feedback_sim() -> FlotraV2Sim:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    for kind in [&"rack_wing", &"second_packing_bench"]:
        _expect(bool(sim.purchase_rank1_project(kind).get("ok", false)), "Rank2 fixture project must use real purchase API")
    sim.shipped = FlotraV2Sim.EXPANSION_SHIPMENTS
    _expect(bool(sim.purchase_warehouse_expansion().get("ok", false)), "Rank2 fixture must use real warehouse expansion API")
    return sim


func _assert_notice(panel: WarehouseZonePanel, fragment: String, context: String) -> void:
    _expect(panel._action_message.visible and panel._action_message.text.contains(fragment), context)


func _verify_hire_notice_lifecycle() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 0
    var panel := _bare_panel(sim, "inbound")
    await _settle()
    var before := sim.save_data()
    var measurements_before := sim._measurement._active_measurements.size()
    panel._on_operations_action()
    _assert_notice(panel, "資金不足", "Failed hire must explain insufficient funds immediately")
    await _settle()
    _assert_notice(panel, "3,500", "Failed hire notice must persist across frame refreshes")
    panel._process(3.0)
    panel._on_operations_action()
    _expect(panel._notice_remaining >= 4.99, "Repeated failed action restarts its reading time")
    panel._process(3.0)
    _assert_notice(panel, "資金不足", "Repeated retry must not prematurely expire its latest notice")
    _expect(sim.save_data() == before and sim._measurement._active_measurements.size() == measurements_before, "Repeated failed hire must not alter money, workers, saves or measurements")
    panel._process(2.1)
    _expect(panel._notice_text.is_empty() and panel._action_message.text.is_empty() and not panel._action_message.visible, "Expired hire error must disappear completely")

    for speed in [0.0, 1.0, 2.0, 4.0]:
        sim.time_scale = speed
        panel._on_operations_action()
        panel._process(1.0)
        _expect(is_equal_approx(panel._notice_remaining, 4.0), "Notice clock must use reading time at %sx simulation speed" % speed)
        panel._process(4.1)
        _expect(panel._notice_text.is_empty(), "Notice must expire even when the simulation is paused")

    panel._on_operations_action()
    panel.open_zone("inbound")
    _assert_notice(panel, "資金不足", "Reopening the same inspection must not erase an active failure")
    panel.open_zone("storage")
    _expect(panel._notice_text.is_empty() and not panel._action_message.text.contains("資金不足"), "Switching zones must clear old action notices")
    panel._on_operations_action()
    panel.close()
    panel.open_zone("storage")
    _expect(panel._notice_text.is_empty() and not panel._action_message.text.contains("資金不足"), "Close/reopen must not replay stale failures")

    panel._on_operations_action()
    sim.money = FlotraV2Sim.WORKER_HIRE_COST
    panel._on_operations_action()
    await _settle()
    _expect(sim.money == 0 and sim.worker_count == 4 and sim.rank1_project_owned(&"worker_hire"), "Affordable hire retry must apply the existing purchase exactly once")
    _expect(panel._notice_text.is_empty() and not panel._action_message.text.contains("資金不足"), "Successful hire retry must clear stale failure immediately")
    panel.queue_free()
    await _settle()


func _verify_rank1_capital_failure() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 0
    var panel := _bare_panel(sim, "storage")
    await _settle()
    var before := sim.save_data()
    panel._on_capital_action()
    _expect(panel.preview_kind() == &"rack_wing", "Unfunded capital remains inspectable without spending")
    # A stale/late activation must still receive the Domain's authoritative failure.
    panel._on_capital_action()
    await _settle()
    _assert_notice(panel, "資金不足", "Rank1 capital error must survive preview rendering")
    panel._on_capital_action()
    _expect(sim.save_data() == before, "Repeated blocked Rank1 construction must not change authoritative state")
    panel._process(5.1)
    _expect(not panel._action_message.text.contains("資金不足") and not panel._action_message.text.is_empty(), "Error expiry must restore the selected equipment details")
    _expect(panel.preview_kind() == &"rack_wing", "Failure and expiry must preserve the construction preview")
    panel._on_capital_action()
    sim.money = FlotraV2Sim.RACK_WING_COST
    panel._on_capital_action()
    await _settle()
    _expect(sim.money == 0 and sim.rank1_project_owned(&"rack_wing"), "Rank1 affordable retry must purchase once")
    _assert_notice(panel, "建設完了", "Successful Rank1 retry must replace its failure with the real result")
    panel.queue_free()
    await _settle()


func _verify_rank2_build_and_renovation_failures() -> void:
    var sim := _rank2_feedback_sim()
    var panel := _bare_panel(sim, "storage")
    await _settle()
    for kind in [&"fast_pick_rack", &"high_density_rack"]:
        var button: Button
        for candidate in panel._rank2_capital_buttons:
            if StringName(candidate.get_meta("kind", "")) == kind:
                button = candidate
        _expect(button != null, "Rank2 equipment route must exist")
        if button == null:
            continue
        sim.money = 0
        var before := sim.save_data()
        panel._on_rank2_capital_action(button)
        panel._on_rank2_capital_action(button)
        await _settle()
        _assert_notice(panel, "資金不足", "Rank2 build/renovation failure must persist over its strength/weakness preview")
        panel._on_rank2_capital_action(button)
        _expect(sim.save_data() == before, "Repeated blocked Rank2 purchase must not spend or change facilities")
        panel._process(5.1)
        _expect(panel._action_message.text.contains("強み") and panel._action_message.text.contains("弱み"), "After error expiry the Rank2 tradeoff details must return")
        panel._on_rank2_capital_action(button)
        var info: Dictionary = sim.rank2_v2_equipment_action_info(kind)
        sim.money = int(info["cost"])
        panel._on_rank2_capital_action(button)
        await _settle()
        _expect(sim.money == 0 and sim.selected_facility_for_group("storage") == String(kind), "Affordable Rank2 build/renovation retry must apply exactly once")
        _assert_notice(panel, "計測開始", "Rank2 success must replace a prior failure with its actual completion")
        _expect(not panel._action_message.text.contains("資金不足"), "Successful Rank2 purchase must never retain its old error")
    panel.queue_free()
    await _settle()


func _staffing_button(panel: WarehouseZonePanel, source: String) -> Button:
    for button in panel._staffing_move_buttons:
        if String(button.get_meta("from_zone", "")) == source:
            return button
    return null


func _verify_staffing_failures() -> void:
    var sim := _rank2_feedback_sim()
    var panel := _bare_panel(sim, "shipping")
    await _settle()
    panel._on_staffing_move(_staffing_button(panel, "inbound"))
    _assert_notice(panel, "再配置", "Real staffing success must be acknowledged")
    var before := sim.save_data()
    panel._on_staffing_move(_staffing_button(panel, "picking"))
    await _settle()
    _assert_notice(panel, "観察中", "Cooldown rejection must remain readable after frames")
    _expect(sim.save_data() == before, "Cooldown failure must not change staffing or money")
    sim.staffing_cooldown = 0.0 # Explicit UI fixture to reach the minimum guard.
    panel._render()
    before = sim.save_data()
    panel._on_staffing_move(_staffing_button(panel, "inbound"))
    await _settle()
    _assert_notice(panel, "最低1名", "Minimum staffing rejection must survive refresh")
    panel._process(2.0)
    panel._on_staffing_move(_staffing_button(panel, "inbound"))
    _expect(sim.save_data() == before, "Repeated minimum failure must keep workers and money unchanged")
    panel._on_staffing_move(_staffing_button(panel, "picking"))
    _assert_notice(panel, "再配置", "Valid staffing recovery must replace its minimum error")
    _expect(not panel._action_message.text.contains("最低1名"), "Staffing recovery must not leave stale error text")
    panel.queue_free()
    await _settle()


func _verify_visible_mobile_notice() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var panel: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    sim.money = 0
    panel.open_zone("inbound")
    await _settle()
    panel._scroll.ensure_control_visible(panel._operations_action)
    await _settle()
    _expect(clarity.router.button_at(panel._operations_action.get_global_rect().get_center()) == panel._operations_action, "Mobile hire action must remain reachable by scroll and touch")
    _tap(panel._operations_action)
    await _settle()
    _assert_notice(panel, "資金不足", "Real composed touch must produce a persistent failure notice")
    var rect := panel._action_message.get_global_rect()
    _expect(panel._panel.get_global_rect().encloses(rect) and get_root().get_visible_rect().encloses(rect), "Notice must be fully inside the visible mobile panel")
    _expect(not panel._scroll.is_ancestor_of(panel._action_message), "Result footer must remain visible regardless of equipment scroll position")
    _expect(panel._scroll.get_global_rect().end.y <= rect.position.y, "Footer must reserve layout space rather than overlap action buttons")
    _expect(rect.end.y <= hud._manage_button.get_global_rect().position.y, "Notice footer must clear the bottom dock")
    _expect(panel._action_message.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Passive notice must not intercept action taps")
    panel._scroll.scroll_vertical = 0
    await _settle()
    _expect(panel._action_message.get_global_rect() == rect, "Scrolling equipment must not move the notice footer")
    _expect(clarity.router.button_at(panel._close_button.get_global_rect().get_center()) == panel._close_button, "Close remains tappable while a failure is visible")
    _tap(panel._close_button)
    await _settle()
    _expect(not panel.is_open() and panel._notice_text.is_empty(), "Closing through touch clears the notice")
    hud.queue_free()
    await _settle()
