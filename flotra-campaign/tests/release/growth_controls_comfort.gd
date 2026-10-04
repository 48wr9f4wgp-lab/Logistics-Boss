extends SceneTree
const HUD = preload("res://prototype/growth_hud.gd")
const SIM = preload("res://prototype/growth_sim.gd")
var errors: Array[String] = []
var requests: Array = []
var prefs := {"preferred_speed":2,"pause_on_menus":false,"reduced_motion":false}
func _initialize(): run.call_deferred()
func check(value: bool, label: String):
    if not value:
        errors.append(label)
        push_error(label)
func settle():
    for frame in 4: await process_frame
func inspect(node: Node):
    if node is Button:
        check(node.get_theme_font_size("font_size") >= 18, "18px button " + str(node.name))
        check(node.custom_minimum_size.y >= 56, "56px button " + str(node.name))
    elif node is Label:
        check(node.get_theme_font_size("font_size") >= 18, "18px label " + str(node.name))
    for child in node.get_children(): inspect(child)
func touch(point: Vector2, down: bool):
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = down
    Input.parse_input_event(event)
func run():
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    var sim = SIM.new()
    var hud = HUD.new()
    hud.bind_sim(sim)
    hud.contract_requested.connect(func(id): requests.append(["job",id]))
    hud.speed_requested.connect(func(value): requests.append(["speed",value]))
    hud.pause_requested.connect(func(paused): requests.append(["pause",paused]))
    hud.preference_requested.connect(func(key,value):
        requests.append([key,value])
        prefs[key] = value
        if sim.has_method("set_preference"): sim.call("set_preference",key,value)
        hud.set_preferences(prefs)
    )
    root.size = Vector2i(375,567)
    root.add_child(hud)
    await settle()
    check(hud._scroll.get_global_rect().encloses(hud._content.get_node("StartTrial").get_global_rect()), "Fresh primary start above fold at 375x567")
    check(hud._close.text == "仕事へ", "Fresh entry close clearly leads to job selection")
    hud.close_sheet()
    check(hud._sheet_kind == "jobs" and not hud._trial_running, "Fresh entry selects work without starting empty warehouse")
    hud.close_sheet()
    for dimensions in [Vector2i(375,567),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320)]:
        root.size = dimensions
        hud.show_entry()
        await settle()
        if dimensions.y >= 567:
            check(hud._scroll.get_global_rect().encloses(hud._content.get_node("StartTrial").get_global_rect()), "Entry primary action above fold " + str(dimensions))
        hud.show_controls()
        await settle()
        inspect(hud._root)
        var rect: Rect2 = hud._scroll.get_global_rect()
        if dimensions.y >= 567:
            check(rect.encloses(hud._speed_buttons[4].get_global_rect()), "All speed controls above fold " + str(dimensions))
            check(rect.encloses(hud._content.get_node("ControlsPause").get_global_rect()), "Pause above fold " + str(dimensions))
        check(hud._speed_buttons.size() == 3, "Three actual speeds")
        hud.close_sheet()
        check(hud._back.text == "操作", "Top-level controls discovery")
    root.size = Vector2i(375,567)
    hud.show_controls()
    await settle()
    var speed_button: Button = hud._speed_buttons[4]
    var point := speed_button.get_global_rect().get_center()
    touch(point,true)
    for frame in 5:
        hud.refresh()
        await process_frame
    check(speed_button.is_pressed(), "Speed held through refresh remains pressed")
    touch(point,false)
    await settle()
    check(requests.count(["speed",4.0]) == 1 and hud._speed == 4.0, "Held speed touch emits exactly once")
    hud._toggle_preference("pause_on_menus")
    hud._toggle_preference("reduced_motion")
    check(prefs.pause_on_menus and prefs.reduced_motion, "Comfort controls emit exact persisted keys")
    check(hud._sheet_kind == "controls", "Preference change keeps controls open")
    sim.accept_contract("growth_1")
    hud.refresh()
    hud.set_trial_running(false)
    hud._toggle_pause()
    check(hud._sheet_kind.is_empty() and hud._trial_running and requests[-1] == ["pause",false], "Explicit resume closes controls and emits resume")
    sim.accept_contract("growth_1")
    hud.set_trial_running(true)
    hud.refresh()
    for tick in 5000:
        if sim.finished: break
        sim.step(0.25)
    hud.refresh()
    hud.show_conditions()
    await settle()
    check(hud._content.has_node("GrowthQuickActions/StartNextJob"), "Completion next job is one action")
    check(hud._content.has_node("GrowthQuickActions/ReplayCurrentJob"), "Completion replay is one action")
    hud._request_quick_contract("growth_2")
    hud._request_quick_contract("growth_2")
    check(requests.count(["job","growth_2"]) == 1, "Quick next job emits once")
    hud._open_upgrades()
    await settle()
    check(not hud._content.get_node("FutureUpgrades").visible, "Future equipment folded by default")
    var wing: Button = hud._upgrade_buttons["wing_1"]
    var crew: Button = hud._upgrade_buttons["crew_4"]
    check(not wing.disabled and not crew.disabled, "Both first earned upgrades available")
    check(wing.get_global_rect().position.y < crew.get_global_rect().position.y, "First physical expansion stays first")
    check(hud._scroll.get_global_rect().encloses(wing.get_global_rect()), "First earned expansion action above fold at shortest phone")
    hud._toggle_upgrades_group("future")
    check(hud._content.get_node("FutureUpgrades").visible, "Future roadmap available explicitly")
    var restored = SIM.new()
    restored.accept_contract("growth_1")
    restored.step(1)
    var saved_hud = HUD.new()
    saved_hud.bind_sim(restored)
    var starts: Array = []
    saved_hud.trial_started.connect(func(): starts.append(true))
    root.add_child(saved_hud)
    await settle()
    check(saved_hud._close.text == "倉庫へ", "Restored entry close clearly returns to warehouse")
    saved_hud.close_sheet()
    check(saved_hud._sheet_kind.is_empty() and not saved_hud._trial_running and starts.is_empty(), "Closing restored entry never silently resumes cargo")
    hud.free()
    saved_hud.free()
    print("GROWTH_CONTROLS_COMFORT ","PASS" if errors.is_empty() else "FAIL"," ",errors)
    quit(0 if errors.is_empty() else 1)
