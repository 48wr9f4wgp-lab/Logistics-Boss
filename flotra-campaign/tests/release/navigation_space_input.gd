extends SceneTree
## Focused native/headless regression for the compact desktop overview and
## separate work/equipment routes. Geometry and real engine input only; this
## does not establish rendered appearance, browser or physical-phone behavior.
const Main = preload("res://prototype/growth_main.gd")
const DIMENSIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(375, 667), Vector2i(390, 844)]
const CAMERA_KEYS := ["CameraLeft", "CameraRight", "CameraOut", "CameraIn", "CameraReset"]
var app
var checks := 0
var failures: Array[String] = []
var geometries: Array[Dictionary] = []
var purchases: Array[String] = []
var clock := {"now": 1000000}

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func settle(frames: int = 4) -> void:
    for frame in frames: await process_frame
    if is_instance_valid(app): app._update_world_visibility()

func guard() -> void:
    var deadline := Time.get_ticks_msec() + 2000
    while app.hud._background_input_blocked() and Time.get_ticks_msec() < deadline:
        await process_frame
    check(not app.hud._background_input_blocked(), "Dismissal guard expires for a fresh gesture")
    await settle()

func node(key: String) -> Control:
    return app.hud._root.find_child(key, true, false) as Control

func touch(point: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func mouse(point: Vector2, down: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = MOUSE_BUTTON_LEFT
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
    event.pressed = down
    Input.parse_input_event(event)
    Input.flush_buffered_events()

func pointer(point: Vector2, down: bool) -> void:
    if root.size.x >= 1000: mouse(point, down)
    else: touch(point, down)

func click(button: Button) -> void:
    check(button != null and button.is_visible_in_tree(), "Input target exists and is visible")
    if button == null or not button.is_visible_in_tree(): return
    await guard()
    var point := button.get_global_rect().get_center()
    pointer(point, true)
    for frame in 4:
        app.hud.refresh()
        await process_frame
    pointer(point, false)
    await settle()

func tap(key: String) -> void:
    var button := node(key) as Button
    check(button != null, "Named action exists: " + key)
    if button != null: await click(button)

func reveal(key: String) -> Button:
    await settle()
    var button := node(key) as Button
    check(button != null, "Sheet action exists: " + key)
    if button == null: return null
    app.hud._scroll.ensure_control_visible(button)
    await settle()
    check(app.hud._scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Entire sheet action is reachable: " + key)
    return button

func readable(branch: Node, label: String) -> void:
    for child in branch.get_children(): readable(child, label)
    if not branch is Control or not branch.is_visible_in_tree(): return
    if branch is Label or branch is Button:
        check(branch.get_theme_font_size("font_size") >= 18, label + " font18 " + str(branch.name))
    if branch is Button and root.size.x < 1000:
        check(branch.size.x >= 56 and branch.size.y >= 56, label + " phone target56 " + str(branch.name))

func sheet(expected_tab: String, label: String) -> void:
    check(app.hud._sheet_kind == "jobs" and app.hud._release_tab == expected_tab, label + " preserves jobs/domain route " + expected_tab)
    check(node("CampaignTabs") == null, label + " has no redundant CampaignTabs")
    check(not app.viewport_container.visible, label + " suspends covered world")
    check(is_zero_approx(app.hud._scroll.position.y), label + " scroll starts directly below title")
    readable(app.hud._root, label)

func overview_geometry(dimensions: Vector2i, phase: String = "initial") -> void:
    var desktop := dimensions.x >= 1000 and dimensions.y >= 500
    var expected := Vector2(104, 84) if desktop else Vector2(140, 220)
    var world: Rect2 = app.viewport_container.get_global_rect()
    var display := Rect2(Vector2.ZERO, Vector2(dimensions))
    check(app.hud.world_insets() == expected, "Overview world insets " + str(dimensions))
    check(is_equal_approx(world.position.y, expected.x) and is_equal_approx(world.end.y, dimensions.y - expected.y), "Actual viewport uses overview insets " + str(dimensions))
    check(is_equal_approx(app.hud._header.size.y, 60 if desktop else 76), "Header height " + str(dimensions))
    check(is_equal_approx(app.hud._bottom.size.y, 72 if desktop else 136), "Bottom status height " + str(dimensions))
    check(app.hud._conditions.is_visible_in_tree() == desktop, "Results stays in desktop overview only " + str(dimensions))
    var actions: Array[Control] = [app.hud._back, app.hud._pause]
    for key in ["WorkChoice", "EquipmentChoice", "ChangeLayout"] + CAMERA_KEYS:
        var action := node(key)
        check(action != null and action.is_visible_in_tree(), "Overview exposes " + key + " " + str(dimensions))
        if action != null: actions.append(action)
    if desktop: actions.append(app.hud._conditions)
    for action in actions:
        check(display.grow(1).encloses(action.get_global_rect()), "Overview action onscreen " + str(action.name))
        check(not world.intersects(action.get_global_rect()), "Overview action does not cover world " + str(action.name))
    for first in actions.size():
        for second in range(first + 1, actions.size()):
            check(not actions[first].get_global_rect().intersects(actions[second].get_global_rect()), "Overview actions do not overlap %s/%s" % [actions[first].name, actions[second].name])
    readable(app.hud._root, "overview " + str(dimensions))
    geometries.append({"window": str(dimensions), "phase": phase, "viewport": str(world), "header_height": app.hud._header.size.y, "bottom_height": app.hud._bottom.size.y, "world_fraction": world.size.y / float(dimensions.y)})

func check_camera() -> void:
    app.world.camera_action("reset")
    await tap("CameraRight")
    check(app.world._camera_turn == 1, "Right camera action occurs exactly once")
    await tap("CameraLeft")
    check(app.world._camera_turn == 0, "Left camera action restores bearing")
    await tap("CameraIn")
    check(is_equal_approx(app.world._camera_zoom, 1.25), "Zoom in occurs exactly once")
    await tap("CameraOut")
    check(is_equal_approx(app.world._camera_zoom, 1.0), "Zoom out restores scale")
    await tap("CameraRight")
    await tap("CameraIn")
    await tap("CameraReset")
    check(app.world._camera_turn == 0 and app.world._camera_zoom == 1.0 and app.world._camera_pan == Vector2.ZERO, "Reset restores whole warehouse")

func routes(dimensions: Vector2i) -> void:
    var before: Dictionary = app.sim.export_release_state()
    for repeat in 2:
        await tap("EquipmentChoice")
        sheet("upgrades", "Direct equipment %s pass%d" % [dimensions, repeat])
        check(node("UpgradeWallet") != null and node("ContractSummary") == null, "Equipment opens equipment content directly")
        await click(app.hud._close)
        check(app.hud._sheet_kind.is_empty(), "Close equipment returns to overview")
        await tap("WorkChoice")
        sheet("contracts", "Work after equipment %s pass%d" % [dimensions, repeat])
        check(node("ContractSummary") != null and node("UpgradeWallet") == null, "Work always opens jobs after equipment")
        await click(app.hud._back)
        check(app.hud._sheet_kind.is_empty(), "Back from jobs returns to overview")
    await tap("WorkChoice")
    await click(await reveal("PrepareContract_growth_1"))
    check(app.hud._sheet_kind == "jobs" and app.hud._release_tab == "prepare", "Preparation keeps original guarded jobs route")
    await click(app.hud._close)
    sheet("contracts", "Preparation back")
    await click(app.hud._back)
    await tap("ChangeLayout")
    check(app.hud._sheet_kind == "editor" and app.hud._apply.is_visible_in_tree(), "Layout still opens with pinned apply action")
    await click(app.hud._close)
    check(app.hud._sheet_kind.is_empty(), "Cancel layout returns to overview")
    if dimensions.x >= 1000:
        await click(app.hud._conditions)
    else:
        await click(app.hud._back)
        check(app.hud._sheet_kind == "controls", "Phone controls menu opens")
        await click(await reveal("OpenRecords"))
    check(app.hud._sheet_kind == "records", "Results is reachable through correct overview route")
    readable(app.hud._root, "results " + str(dimensions))
    await click(app.hud._close)
    check(app.hud._sheet_kind.is_empty(), "Close results returns to overview")
    var focus_owner := root.gui_get_focus_owner()
    check(focus_owner != null and focus_owner.is_visible_in_tree(), "Closing results returns focus to a visible action")
    await check_camera()
    overview_geometry(dimensions, "after_modals")
    check(app.sim.export_release_state() == before, "Navigation, preparation cancel, layout cancel and camera preserve entire campaign " + str(dimensions))

func canceled_and_held_input() -> void:
    for dimensions in [Vector2i(1280, 720), Vector2i(375, 667)]:
        root.size = dimensions
        app.hud.show_play()
        await settle()
        for key in ["EquipmentChoice", "WorkChoice"]:
            for web in [false, true]:
                await guard()
                var button := node(key) as Button
                var point := button.get_global_rect().get_center()
                touch(point, true)
                await settle()
                if web: app._cancel_web_touch()
                touch(point, false, not web)
                await settle()
                check(app.hud._sheet_kind.is_empty(), "Canceled route stays closed %s web=%s at%s" % [key, web, dimensions])
            await guard()
            var button := node(key) as Button
            var point := button.get_global_rect().get_center()
            pointer(point, true)
            await settle()
            var epoch: int = app.hud._input_epoch
            root.size = dimensions + Vector2i(10, 10)
            await settle()
            check(app.hud._input_epoch > epoch, "Resize invalidates held navigation epoch " + key)
            pointer(point, false)
            await settle()
            check(app.hud._sheet_kind.is_empty(), "Held release after resize cannot navigate " + key)
            root.size = dimensions
            await settle()
            await tap(key)
            check(app.hud._sheet_kind == "jobs", "Fresh route recovers after cancel and resize " + key)
            await click(app.hud._close)
        # Dismissal while an enabled purchase is held must not activate a
        # replacement control or mutate the campaign on its late release.
        await tap("EquipmentChoice")
        var buy := await reveal("BuyUpgrade_wing_1")
        check(buy != null and not buy.disabled, "Earned fixture has an enabled purchase for dismissal test")
        if buy != null:
            var before: Dictionary = app.sim.export_release_state()
            var point := buy.get_global_rect().get_center()
            touch(point, true)
            await settle()
            app.hud.close_sheet()
            app.hud._open_upgrades()
            await settle()
            touch(point, false)
            await settle()
            check(app.sim.export_release_state() == before and purchases.is_empty(), "Held purchase dismissed and reopened cannot act " + str(dimensions))
            await click(app.hud._close)

func advance(seconds: float) -> void:
    clock.now += roundi(seconds * 1000000)
    app._process(seconds)

func running_and_pause_guards() -> void:
    root.size = Vector2i(1280, 720)
    app.hud.show_play()
    await settle()
    await tap("WorkChoice")
    await click(await reveal("AcceptContract_growth_1"))
    check(app.sim.campaign_status == "running" and app.running, "Actual job route still accepts through scene guard")
    app._set_preference("pause_on_menus", false)
    await tap("EquipmentChoice")
    var running_before: Dictionary = app.sim.export_release_state()
    advance(0.2)
    check(not app._menu_paused and app.running and app.sim.sim_time > running_before.sim.sim_time, "Menus keep progressing when auto-pause preference is off")
    check((node("BuyUpgrade_wing_1") as Button).disabled, "Purchases remain disabled while the menu's job advances")
    await click(app.hud._close)
    app._set_preference("pause_on_menus", true)
    for key in ["EquipmentChoice", "WorkChoice"]:
        await tap(key)
        var before: Dictionary = app.sim.export_release_state()
        advance(0.2)
        check(app._menu_paused and app.running and app.sim.export_release_state() == before, "Menu auto-pause retains run intent and exact cargo " + key)
        if key == "EquipmentChoice":
            var buy := await reveal("BuyUpgrade_wing_1")
            check(buy != null and buy.disabled, "Running job disables otherwise funded equipment")
            if buy != null: await click(buy)
            app.hud._request_upgrade("wing_1")
            check(app.sim.export_release_state() == before and purchases.is_empty(), "Running job rejects disabled and stale purchase request")
        await click(app.hud._close)
        advance(0.1)
        check(not app._menu_paused and app.running and app.sim.sim_time > before.sim.sim_time, "Closing menu resumes only previous run intent " + key)
    app._pause_trial(true)
    for key in ["EquipmentChoice", "WorkChoice"]:
        await tap(key)
        var before: Dictionary = app.sim.export_release_state()
        if key == "EquipmentChoice":
            var buy := await reveal("BuyUpgrade_wing_1")
            check(buy != null and buy.disabled, "Manually paused unfinished job still disables purchases")
            if buy != null: await click(buy)
            app.hud._request_upgrade("wing_1")
        await click(app.hud._back)
        advance(0.2)
        check(not app.running and app.sim.export_release_state() == before and purchases.is_empty(), "Back keeps manual pause and exact campaign " + key)
    check(app.sim.check_invariants().ok, "Navigation and pause preserve physical cargo invariants")

func protection_guards() -> void:
    # Only a UI protection fixture: persistence remains disabled throughout.
    var before: Dictionary = app.sim.export_release_state()
    for dimensions in DIMENSIONS:
        root.size = dimensions
        app.hud.show_save_protection("既存の保存データを確認できないため、保護しています")
        await settle()
        check(app.hud._close.disabled and app.hud._back.disabled and app.hud._pause.disabled, "Protection keeps close/back/pause disabled " + str(dimensions))
        for key in ["WorkChoice", "EquipmentChoice", "ChangeLayout", "SessionRecord"] + CAMERA_KEYS:
            var control := node(key) as Button
            check(control == null or not control.is_visible_in_tree() or control.disabled, "Protected navigation is unavailable " + key + " " + str(dimensions))
        app.hud.close_sheet()
        app.hud._go_back()
        check(app.hud._sheet_kind == "save_protection", "Protection cannot dismiss by close/back " + str(dimensions))
        check(app.hud._content.find_children("*", "Button", true, false).is_empty(), "Protection has no overwrite action " + str(dimensions))
        check(app.hud._scroll.get_global_rect().grow(1).encloses(node("SaveProtectionReason").get_global_rect()), "Actual protection reason visible above fold " + str(dimensions))
        readable(app.hud._root, "protected " + str(dimensions))
    check(app.sim.export_release_state() == before, "Protection checks leave entire campaign untouched")

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = DIMENSIONS[0]
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app = Main.new()
    app.persistence_enabled = false
    app.frame_clock = func() -> int: return int(clock.now)
    root.add_child(app)
    app.set_process(false)
    await settle()
    check(DisplayServer.get_name() == "headless", "Focused test is intentionally headless")
    # Fail cleanly against a pre-change checkout rather than dereferencing a
    # missing control throughout the input cases.
    check(node("EquipmentChoice") != null, "Separate equipment entry exists")
    if node("EquipmentChoice") == null:
        app.free()
        print("NAVIGATION_SPACE_INPUT ", JSON.stringify({"checks": checks, "failures": failures}))
        quit(1)
        return
    app.hud.upgrade_requested.connect(func(id: String): purchases.append(id))
    for dimensions in DIMENSIONS:
        root.size = dimensions
        app.hud.show_play()
        await settle()
        await guard()
        overview_geometry(dimensions)
        await routes(dimensions)
    check(app.sim.accept_contract("growth_1").ok, "Earn interrupted-purchase fixture by accepting real cargo")
    for tick in 5000:
        if app.sim.finished: break
        app.sim.step(0.25)
    check(app.sim.finished and app.sim.check_invariants().ok, "Earn interrupted-purchase funds by finishing real cargo")
    app.hud.refresh()
    await canceled_and_held_input()
    await running_and_pause_guards()
    await protection_guards()
    app.free()
    print("NAVIGATION_SPACE_INPUT ", JSON.stringify({"checks": checks, "failures": failures, "geometry": geometries, "scope": "Focused native/headless UI geometry and real engine input; no browser, rendered appearance, performance or physical-device claim."}))
    quit(0 if failures.is_empty() else 1)
