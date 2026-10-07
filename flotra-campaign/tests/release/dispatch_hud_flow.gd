extends SceneTree
## Real candidate scene and domain actions. Earn the fixture; keep persistence
## disabled in this test only. Native screenshots are optional and UI-specific.
const Main = preload("res://prototype/growth_main.gd")
const Growth = preload("res://prototype/growth_sim.gd")
var app
var checks := 0
var failures: Array[String] = []
var purchases: Array[String] = []
var selections: Array[int] = []

func _initialize() -> void: run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func settle() -> void:
    if is_instance_valid(app): app._update_world_visibility()
    for frame in 4: await process_frame

func node(key: String) -> Control:
    return app.hud._root.find_child(key, true, false) as Control

func finish_job(id: String) -> void:
    check(app.sim.accept_contract(id).ok, "Earned fixture accepts " + id)
    for tick in 5000:
        if app.sim.finished: break
        app.sim.step(0.25)
    check(app.sim.finished and app.sim.check_invariants().ok, "Earned fixture finishes " + id)

func earn_fixture() -> void:
    for index in range(1, 7): finish_job("growth_%d" % index)
    for option in Growth.GROWTH_UPGRADES:
        while app.sim.campaign_wallet < int(option.cost): finish_job("growth_1")
        check(app.sim.buy_upgrade(str(option.id)).ok, "Earned fixture buys " + str(option.id))
    while app.sim.campaign_wallet < 300: finish_job("growth_1")
    app.hud.refresh()

func touch(point: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 0
    event.position = point
    event.pressed = down
    event.canceled = canceled
    Input.parse_input_event(event)

func reveal(key: String) -> Button:
    # A disclosure changes the VBox layout on the next frame. Resolve its
    # geometry before scrolling, just as a later human touch would.
    await settle()
    var button := node(key) as Button
    check(button != null, "Control exists " + key)
    if button == null: return null
    app.hud._scroll.ensure_control_visible(button)
    await settle()
    check(button.is_visible_in_tree() and app.hud._scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Whole control reachable %s at%d selected%d %s (scroll%s button%s)" % [key, root.size.x, app.sim.dispatch_state().selected_window, app.sim.campaign_status, app.hud._scroll.get_global_rect(), button.get_global_rect()])
    return button

func held_touch(key: String, canceled: bool = false, web_cancel: bool = false) -> void:
    var button := await reveal(key)
    if button == null: return
    await create_timer(0.22).timeout
    var point := button.get_global_rect().get_center()
    touch(point, true)
    for frame in 5:
        app.hud.refresh()
        await process_frame
    check(is_instance_valid(button) and button == node(key), "Ordinary refresh preserves held control " + key)
    if web_cancel: app._cancel_web_touch()
    touch(point, false, canceled)
    await settle()

func geometry(label: String) -> void:
    var pending: Array[Node] = [app.hud._content]
    while not pending.is_empty():
        var child: Node = pending.pop_back()
        for item in child.get_children(): pending.append(item)
        if not child is Control or not child.is_visible_in_tree(): continue
        if child is Label or child is Button:
            check(child.get_theme_font_size("font_size") >= 18, label + " font18 " + str(child.name))
            check(child.get_global_rect().position.x >= -1 and child.get_global_rect().end.x <= root.size.x + 1, label + " fits width " + str(child.name))
        if child is Button: check(child.size.y >= 56, label + " target56 " + str(child.name))
        if child is Label: check(child.size.y + 1 >= child.get_minimum_size().y, label + " wrapped text " + str(child.name))

func capture(label: String) -> void:
    var directory := OS.get_environment("FLOTRA_DISPATCH_HUD_EVIDENCE")
    if directory.is_empty() or DisplayServer.get_name() == "headless": return
    await settle()
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute(directory)
    check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Native screenshot " + label)

func reveal_dispatch_card() -> void:
    await settle()
    app.hud._scroll.ensure_control_visible(node("DispatchWindowControls").get_parent().get_parent())
    await settle()

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.mode = Window.MODE_WINDOWED
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    check(app.hud.has_signal("dispatch_window_requested") and app.sim.has_method("dispatch_state"), "Actual main uses dispatch HUD and model")
    if not app.hud.has_signal("dispatch_window_requested"):
        app.free()
        quit(1)
        return
    earn_fixture()
    var opening: Dictionary = app.sim.export_release_state()
    app.hud.upgrade_requested.connect(func(id: String): purchases.append(id))
    app.hud.dispatch_window_requested.connect(func(value: int): selections.append(value))
    for width in [375, 390]:
        root.size = Vector2i(width, 844)
        check(app.sim.import_release_state(opening).ok, "Restore independently earned opening at %d" % width)
        app.running = false
        app.hud.set_trial_running(false)
        app.hud._owned_upgrades_visible = false
        app.hud._equipment_notice = ""
        app.hud._open_upgrades()
        await settle()
        purchases.clear()
        selections.clear()
        var wallet: int = app.sim.campaign_wallet
        var buy := node("BuyUpgrade_pick_dispatch_board") as Button
        check(buy != null and not buy.disabled and buy.is_visible_in_tree(), "Board purchase exposed at %d" % width)
        check(node("OwnedUpgrades") != null and not node("OwnedUpgrades").visible, "Owned cards folded before purchase")
        check(node("DispatchPurchaseHint").text.contains("6枠から"), "Purchase explains default6")
        app.hud._scroll.scroll_vertical = 0
        await settle()
        check(app.hud._scroll.get_global_rect().encloses(buy.get_global_rect()), "Mature board purchase above fold at %d" % width)
        geometry("purchase%d" % width)
        await capture("dispatch-purchase-%d" % width)
        var before: Dictionary = app.sim.export_release_state()
        for web in [false, true]:
            await held_touch("BuyUpgrade_pick_dispatch_board", not web, web)
            check(app.sim.export_release_state() == before and purchases.is_empty(), "Canceled board purchase has no effect web=%s" % web)
        await held_touch("BuyUpgrade_pick_dispatch_board")
        check(purchases == ["pick_dispatch_board"] and app.sim.campaign_wallet == wallet - 300, "Held purchase charges300 once")
        check(app.sim.dispatch_state().owned and app.sim.dispatch_state().selected_window == 6, "Purchase retains6")
        check(not node("OwnedUpgrades").visible and node("DispatchWindowControls").is_visible_in_tree(), "Owned selector remains outside folded cards")
        check(not node("OwnedUpgrades").is_ancestor_of(node("ChooseDispatch12")), "Selector is not an owned-card descendant")
        app.hud._request_upgrade("pick_dispatch_board")
        check(purchases == ["pick_dispatch_board"] and app.sim.campaign_wallet == wallet - 300, "Owned purchase cannot charge twice")
        check(node("DispatchTradeoff").text.contains("収納場所は増えません") and node("DispatchTradeoff").text.contains("遅く"), "Admission is not capacity or guaranteed improvement")
        before = app.sim.export_release_state()
        for web in [false, true]:
            await held_touch("ChooseDispatch12", not web, web)
            check(app.sim.export_release_state() == before and selections.is_empty(), "Canceled window change has no effect web=%s" % web)
        var prior_control := node("ChooseDispatch12")
        await held_touch("ChooseDispatch12")
        check(selections == [12] and app.sim.dispatch_state().selected_window == 12, "Held free12 emits once")
        check(not is_instance_valid(prior_control) or prior_control != node("ChooseDispatch12"), "Committed cap change rebuilds controls")
        check(node("ChooseDispatch12").disabled and node("ChooseDispatch12").text.contains("選択中") and not node("ChooseDispatch6").disabled, "Selected and alternate states refresh")
        await held_touch("ChooseDispatch6")
        await held_touch("ChooseDispatch12")
        check(selections == [12, 6, 12] and app.sim.campaign_wallet == wallet - 300, "Free switch both directions leaves wallet unchanged")
        await reveal_dispatch_card()
        geometry("owned%d" % width)
        await capture("dispatch-owned-%d" % width)
        app.hud.close_sheet()
        app.hud._open_upgrades()
        await settle()
        check(app.sim.dispatch_state().selected_window == 12 and node("ChooseDispatch12").disabled, "Close and reopen retain12")
        await held_touch("ToggleOperations")
        for mode in ["balanced", "parcel", "pallet"]:
            check(node("ChooseOperation_" + mode).is_visible_in_tree(), "Existing free mode remains reachable " + mode)
        app.hud._toggle_operations()
        # A press begun in an old sheet may not select a window after dismissal.
        var stale := await reveal("ChooseDispatch6")
        var point := stale.get_global_rect().get_center()
        touch(point, true)
        await settle()
        app.hud.close_sheet()
        app.hud._open_upgrades()
        touch(point, false)
        await settle()
        check(selections == [12, 6, 12] and app.sim.dispatch_state().selected_window == 12, "Dismissed held selector cannot act after reopening")
        app._accept_contract("route_parcel_120")
        app.sim.step(1.0)
        app._pause_trial(true)
        app.hud._open_upgrades()
        await settle()
        check(app.sim.campaign_status == "running" and not app.running, "120 job is running in domain and paused in scene")
        check(node("ChooseDispatch6").disabled and node("ChooseDispatch12").disabled, "Paused job locks both controls")
        check(node("DispatchSwitchReason").text.contains("仕事中は変更できません") and node("DispatchSwitchReason").text.contains("一時停止中も同じ"), "Running reason includes pause restriction")
        before = app.sim.export_release_state()
        await held_touch("ChooseDispatch6")
        app.hud._request_dispatch_window(6)
        check(app.sim.export_release_state() == before and selections == [12, 6, 12], "Disabled touch and stale request cannot switch paused job")
        await reveal_dispatch_card()
        geometry("paused%d" % width)
        await capture("dispatch-paused-%d" % width)
        app.hud.close_sheet()
        app.hud._open_upgrades()
        await settle()
        check(app.sim.dispatch_state().selected_window == 12 and not app.running and node("ChooseDispatch6").disabled, "Reopening preserves paused12 lock")
        check(app.sim.check_invariants().ok, "UI flow preserves cargo invariants")
    for width in [375, 390]:
        root.size = Vector2i(width, 844)
        app.hud.show_save_protection("以前の保存を確認できません。既存のデータを守るため停止しました")
        await settle()
        app.hud.close_sheet()
        check(app.hud._sheet_kind == "save_protection" and app.hud._close.disabled, "Protected-save sheet cannot dismiss to fresh play")
        check(node("SaveProtectionReason").text.contains("以前の保存"), "Protected-save sheet shows actual store reason")
        check(app.hud._scroll.size.x >= 300 and app.hud._scroll.size.y >= 500 and app.hud._scroll.get_global_rect().encloses(node("SaveProtectionReason").get_global_rect()), "Protected-save reason is visibly laid out above fold")
        check(app.hud._content.find_children("*", "Button", true, false).is_empty(), "Protected-save sheet has no restore or overwrite action")
        geometry("protected%d" % width)
        await capture("dispatch-protected-%d" % width)
    app.free()
    var report := {"checks":checks, "failures":failures, "scope":"Actual scene purchase/free6-12/paused lock, inherited touch guards and native375/390 readability. No completion/performance/device claims."}
    var directory := OS.get_environment("FLOTRA_DISPATCH_HUD_EVIDENCE")
    if not directory.is_empty():
        DirAccess.make_dir_recursive_absolute(directory)
        var file := FileAccess.open(directory.path_join("dispatch-hud-flow.json"), FileAccess.WRITE)
        file.store_string(JSON.stringify(report, "  "))
    print("DISPATCH_HUD_FLOW ", JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)
