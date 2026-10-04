extends SceneTree
const HUD = preload("res://prototype/growth_hud.gd")
const SIM = preload("res://prototype/growth_sim.gd")
var errors: Array[String] = []
var hud
var sim
var contract_requests: Array[String] = []
func _initialize():
    _run.call_deferred()
func check(condition: bool, label: String):
    if not condition:
        errors.append(label)
        push_error(label)
func settled():
    await process_frame
    await process_frame
    await process_frame
func inspect(node: Node):
    if node is Button:
        check(node.get_theme_font_size("font_size") >= 18, "Button font " + str(node.name))
        check(node.custom_minimum_size.y >= 56, "Button target " + str(node.name))
    if node is Label:
        check(node.get_theme_font_size("font_size") >= 18, "Label font " + str(node.name))
    for child in node.get_children():
        inspect(child)
func touch_at(point: Vector2, pressed: bool):
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = pressed
    Input.parse_input_event(event)
func swipe_from(point: Vector2, distance: float):
    touch_at(point, true)
    await process_frame
    var previous := point
    for step in range(1, 11):
        var next := point - Vector2(0, distance * float(step) / 10.0)
        var event := InputEventScreenDrag.new()
        event.index = 0
        event.position = next
        event.relative = next - previous
        event.screen_relative = event.relative
        event.velocity = event.relative * 40.0
        event.screen_velocity = event.velocity
        Input.parse_input_event(event)
        previous = next
        await create_timer(0.025).timeout
    await create_timer(0.25).timeout
    touch_at(previous, false)
    await settled()
func verify_touch_scrolling():
    root.size = Vector2i(375, 567)
    hud._open_contracts()
    await settled()
    var first: Button = hud._contract_buttons["growth_1"]
    var visible_area: Rect2 = hud._scroll.get_global_rect()
    check(visible_area.encloses(first.get_global_rect()), "First job action is fully above fold at 375x567")
    # Start on the actual action, not an empty gap. Scrolling must cancel its
    # held state instead of accepting the job on finger-up.
    await swipe_from(first.get_global_rect().get_center(), 240.0)
    check(hud._sheet_kind == "jobs" and hud._scroll.scroll_vertical > 100, "Drag from enabled job button scrolls")
    check(contract_requests.is_empty(), "Button drag does not accept a job")
    for tab in ["upgrades", "records"]:
        if tab == "upgrades":
            hud._open_upgrades()
            hud._toggle_upgrades_group("future")
        else: hud.show_conditions()
        await settled()
        for attempt in 2:
            var rect: Rect2 = hud._scroll.get_global_rect()
            var before: int = hud._scroll.scroll_vertical
            await swipe_from(Vector2(rect.get_center().x, rect.end.y - 16), rect.size.y - 32)
            check(hud._scroll.scroll_vertical > before, "Real touch scroll continues in " + tab)
        check(hud._sheet_kind == ("jobs" if tab == "upgrades" else "records"), "Scrolling never activates " + tab + " action")
    hud._open_contracts()
    await settled()
    first = hud._contract_buttons["growth_1"]
    var point := first.get_global_rect().get_center()
    touch_at(point, true)
    for tick in 5:
        hud.refresh()
        await process_frame
    check(first.is_pressed(), "Fresh touch remains held across refresh")
    touch_at(point, false)
    await settled()
    check(contract_requests == ["growth_1"], "Fresh held touch accepts exactly once after scroll repair")
    check(hud._sheet_kind.is_empty(), "Accepted touch dismisses sheet")
    contract_requests.clear()
    hud._open_contracts()

func _run():
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    sim = SIM.new()
    hud = HUD.new()
    hud.bind_sim(sim)
    root.add_child(hud)
    hud.contract_requested.connect(func(id): contract_requests.append(id))
    await settled()
    check(hud._speed == 2.0, "Default speed is 2x")
    check(hud._sheet_kind == "entry" and hud._close.name == "CloseSheet", "Entry names preserved")
    check(hud._content.has_node("StartTrial"), "Entry CTA name preserved")
    hud.close_sheet()
    check(hud._sheet_kind == "jobs", "First entry CTA opens jobs")
    for size in [Vector2i(390,844), Vector2i(360,740), Vector2i(320,568), Vector2i(844,390), Vector2i(568,320)]:
        root.size = size
        hud._layout()
        await settled()
        hud.show_entry()
        await settled()
        inspect(hud._root)
        hud._open_contracts()
        await settled()
        check(hud._tabs.get_child_count() == 2, "Only two work tabs")
        check(hud._contract_buttons.has("growth_1"), "Initial growth job present")
        check(not hud._contract_buttons["growth_1"].disabled, "First job available")
        check(hud._content.has_node("OpenGrowthUpgrades"), "Expansion quick path")
        inspect(hud._root)
        hud._open_upgrades()
        await settled()
        check(hud._upgrade_buttons.has("wing_4"), "Four wings shown")
        inspect(hud._root)
        hud.show_controls()
        await settled()
        check(hud._speed_buttons.has(4), "4x speed selectable")
        hud._choose_speed(4.0)
        check(hud._speed == 4.0, "4x speed preserved")
        hud.set_speed(2.0)
        hud.show_conditions()
        hud._toggle_history()
        check(hud._content.get_node("GrowthHistory").visible, "Optional history opens")
        inspect(hud._root)
        hud.show_layout_editor()
        await settled()
        check(hud._apply.get_parent() == hud._body, "Editor apply remains pinned")
        check(hud._apply.position.y + hud._apply.size.y <= hud._body.size.y + 1, "Editor action within body")
        inspect(hud._root)
        print("VIEWPORT_OK ", size)
    await verify_touch_scrolling()
    sim.contract_results["first_shift"] = {"best_time":123.45,"best_medal":"gold","attempts":2,"earned":180}
    hud.refresh()
    hud.show_conditions()
    hud._toggle_history()
    var history: String = hud._content.get_node("GrowthHistory/SavedJobRecords").text
    check(history.contains("はじめての出荷") and history.contains("2回") and history.contains("2:03.45") and history.contains("金"), "Legacy records readable")
    # A stale press cannot activate a newly shown contract.
    hud._open_contracts()
    var button = hud._contract_buttons["growth_1"]
    button.set_meta("press_epoch", hud._input_epoch - 1)
    button.pressed.emit()
    check(hud._sheet_kind == "jobs", "Stale epoch prevented activation")
    # No UI action mutates simulation state without the scene handling a signal.
    check(sim.current_contract_id.is_empty(), "HUD remains read-only")
    # Wire the same scene-owned mutation boundary as growth_main, then verify
    # completion, recurring payment and the visible outward-expansion reward.
    hud.contract_requested.connect(func(id):
        var result: Dictionary = sim.accept_contract(id)
        hud.show_contract_result(result)
        if bool(result.get("ok", false)):
            hud.set_trial_running(true)
    )
    hud.upgrade_requested.connect(func(id): hud.show_upgrade_result(sim.buy_upgrade(id)))
    hud._request_contract("growth_1")
    check(sim.current_contract_id == "growth_1", "Scene receives accepted job")
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
    check(sim.finished, "First physical job finishes")
    hud._notice = ""
    hud.refresh()
    check(hud._reason_title.text.contains("報酬 +140"), "Completion announces actual payment")
    hud.show_conditions()
    check(hud._content.get_node("ReleaseRecordOutcome").text.contains("+140"), "Result shows earned reward")
    check(hud._content.has_node("GrowWarehouse"), "Completion growth quick path")
    hud._open_upgrades()
    check(not hud._upgrade_buttons["wing_1"].disabled, "First wing affordable after first job")
    var prior_epoch: int = hud._input_epoch
    hud._request_upgrade("wing_1")
    check(hud._sheet_kind.is_empty(), "Wing purchase reveals warehouse")
    check(hud._input_epoch > prior_epoch, "Wing reveal uses dismissal guard")
    check(int(hud._growth().get("wing_count", 0)) == 1, "Growth status updates after wing")
    hud._open_contracts()
    check(hud._contract_buttons["growth_1"].text.contains("+140"), "Replay promises recurring reward")
    var wallet_before: int = sim.campaign_wallet
    hud._request_contract("growth_1")
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
    hud._notice = ""
    hud.refresh()
    check(sim.finished and sim.campaign_wallet == wallet_before + 140, "Repeated milestone pays again")
    hud._open_upgrades()
    hud._request_upgrade("crew_4")
    check(hud._sheet_kind == "jobs", "Non-wing purchase stays in equipment sheet")
    check(hud._upgrade_buttons["crew_4"].disabled, "Bought crew cannot be purchased twice")
    print("GROWTH_HUD_SMOKE ", "PASS" if errors.is_empty() else "FAIL", " errors=", errors)
    hud.free()
    sim = null
    quit(0 if errors.is_empty() else 1)
