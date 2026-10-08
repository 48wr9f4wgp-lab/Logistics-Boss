extends SceneTree
## Independent scene journey. Every player action is native GUI mouse/touch/wheel
## dispatch; accelerated domain stepping is used only to avoid wall-clock waits.
## Headless geometry/input is not a screenshot or physical-device verification.
const Main = preload("res://prototype/growth_main.gd")
const Save = preload("res://prototype/dispatch_save.gd")
class TransientWriteFailure extends Save:
    func _write(_text: String) -> Dictionary:
        return {"ok":false, "reason":"write"}

var app
var checks := 0
var failures: Array[String] = []
var milestones: Array[String] = []

func _initialize() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> bool:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
    return value

func settle(frames: int = 4) -> void:
    for frame in frames: await process_frame

func refresh() -> void:
    app.hud.refresh()
    app.world.refresh()

func event_at(point: Vector2, down: bool, kind: String = "touch") -> InputEvent:
    if kind == "touch":
        var event := InputEventScreenTouch.new()
        event.index = 0
        event.position = point
        event.pressed = down
        return event
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.position = point
    event.global_position = point
    event.pressed = down
    return event

func point_input(point: Vector2, down: bool, kind: String = "touch") -> void:
    if kind == "mouse":
        var motion := InputEventMouseMotion.new()
        motion.position = point
        motion.global_position = point
        Input.parse_input_event(motion)
    Input.parse_input_event(event_at(point, down, kind))

func swipe(start: Vector2, distance: float) -> void:
    point_input(start, true)
    await process_frame
    var previous := start
    for step in range(1, 9):
        var position := start - Vector2(0, distance * step / 8.0)
        var event := InputEventScreenDrag.new()
        event.index = 0
        event.position = position
        event.relative = position - previous
        event.screen_relative = event.relative
        event.velocity = event.relative * 40.0
        event.screen_velocity = event.velocity
        Input.parse_input_event(event)
        previous = position
        await create_timer(.025).timeout
    await create_timer(.25).timeout
    point_input(previous, false)
    await settle()

func wheel(point: Vector2, down: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
    event.factor = 3.0
    event.pressed = true
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
    await settle()

func reach(control: Control) -> bool:
    if not is_instance_valid(control) or not control.is_visible_in_tree():
        return check(false, "Requested control exists and is visible")
    var scroll: ScrollContainer = app.hud._scroll
    if is_instance_valid(scroll) and scroll.is_ancestor_of(control):
        for attempt in 100:
            var area := scroll.get_global_rect()
            var rect := control.get_global_rect()
            if area.grow(1).encloses(rect): return true
            # Real wheel events bound runtime for the optional long roadmap on
            # 76px landscape scroll areas. Touch scrolling itself is exercised
            # from enabled buttons and throughout the primary portrait journey.
            if absf(rect.get_center().y - area.get_center().y) > area.size.y * 2:
                await wheel(area.get_center(), rect.get_center().y > area.get_center().y)
                continue
            var distance := minf(absf(rect.get_center().y - area.get_center().y), minf(area.size.y - 32, 260))
            distance = maxf(distance, 16)
            if rect.position.y < area.position.y:
                await swipe(Vector2(area.get_center().x, area.position.y + 16), -distance)
            else:
                await swipe(Vector2(area.get_center().x, area.end.y - 16), distance)
        return check(false, "Real swipes can fully reveal " + str(control.name) + " control=" + str(control.get_global_rect()) + " scroll=" + str(scroll.get_global_rect()) + " value=" + str(scroll.scroll_vertical))
    return check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(control.get_global_rect()), "Control inside viewport " + str(control.name))

func mark(label: String) -> void:
    milestones.append(label)
    print("JOURNEY_PASS ", label)

func tap(control: Control, kind: String = "touch", held: int = 5) -> void:
    if not await reach(control): return
    # Dismissal guards intentionally reject click-through for 180 ms.
    await create_timer(.20).timeout
    var point := control.get_global_rect().get_center()
    point_input(point, true, kind)
    for frame in held:
        app.hud.refresh()
        await process_frame
    point_input(point, false, kind)
    await settle()

func open_records() -> void:
    await tap(app.hud._back)
    check(app.hud._sheet_kind == "controls", "Phone records entry opens controls")
    await tap(node("OpenRecords"))
    check(app.hud._sheet_kind == "records", "Visible controls action opens records")

func node(name: String) -> Control:
    return app.hud._root.find_child(name, true, false) as Control

func process_elapsed(seconds: float) -> void:
    # The scene now uses foreground monotonic time. A manual process callback
    # cannot invent wall time on fast CI machines. SceneTreeTimer consumes frame
    # delta, including time accrued before creation, so await a real deadline.
    var deadline := Time.get_ticks_usec() + ceili(seconds * 1000000.0)
    while Time.get_ticks_usec() < deadline:
        await process_frame
    app._process(seconds)

func finish_job() -> void:
    for tick in 7200:
        if app.sim.finished: break
        app.sim.step(.25)
    refresh()
    check(app.sim.finished and app.sim.check_invariants().ok, "Paid job completes with conserved cargo")

func inspect_fonts(control: Node, label: String) -> void:
    if control is Button and control.is_visible_in_tree():
        check(control.get_theme_font_size("font_size") >= 18, label + " readable button " + str(control.name))
        check(control.size.x >= 56 and control.size.y >= 56, label + " 56px target " + str(control.name))
    elif control is Label and control.is_visible_in_tree():
        check(control.get_theme_font_size("font_size") >= 18, label + " readable label " + str(control.name))
        check(control.size.y + 1 >= control.get_minimum_size().y, label + " unclipped line height " + str(control.name))
    for child in control.get_children(): inspect_fonts(child, label)

func verify_reachability(label: String) -> void:
    await settle()
    inspect_fonts(app.hud._root, label)
    var scroll: ScrollContainer = app.hud._scroll
    if not is_instance_valid(scroll): return
    var pending: Array[Node] = [app.hud._content]
    var area := scroll.get_global_rect()
    var max_scroll := maxf(0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
    var previous := scroll.scroll_vertical
    while not pending.is_empty():
        var item: Node = pending.pop_back()
        for child in item.get_children(): pending.append(child)
        if not item is Control or not item.is_visible_in_tree(): continue
        if item is Button:
            var rect: Rect2 = item.get_global_rect()
            var top := rect.position.y + previous - area.position.y
            var desired := clampf(top, 0, max_scroll)
            var projected := Rect2(Vector2(rect.position.x, area.position.y + top - desired), rect.size)
            check(area.grow(1).encloses(projected), label + " fully reachable action " + str(item.name))
    check(Rect2(Vector2.ZERO, root.get_visible_rect().size).grow(1).encloses(area), label + " full scroll area inside screen")

func create_app(persistence: bool) -> void:
    app = Main.new()
    app.persistence_enabled = persistence
    root.add_child(app)
    app.set_process(false)
    await settle()

func run() -> void:
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    if sandbox.is_empty() or not OS.get_user_data_dir().begins_with(sandbox):
        push_error("Experience journey requires isolated FLOTRA_REVIEW_USER_ROOT")
        quit(2)
        return
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(375,567)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    await create_app(true)
    # Aggregate runners must allocate this suite its own empty profile. Fail
    # before any input or save if another suite left restored cargo here.
    if not check(app.hud._sheet_kind == "entry" and not app.running and app.sim.current_contract_id.is_empty() and app.sim.campaign_status == "ready", "Fresh open is readable and paused in an empty disposable profile"):
        finish()
        return
    var start := node("StartTrial")
    if not check(is_instance_valid(start) and start.is_visible_in_tree(), "Fresh introduction exposes its start control"):
        finish()
        return
    await verify_reachability("fresh 375x567")
    await tap(start)
    if not check(app.hud._sheet_kind == "jobs" and not app.running, "Real first-open CTA opens work without running"):
        finish()
        return
    var first := node("AcceptContract_growth_1")
    if not check(is_instance_valid(app.hud._scroll) and is_instance_valid(first) and first is Button and first.is_visible_in_tree() and not first.disabled, "First work selector exposes an enabled first-job control"):
        finish()
        return
    check(app.hud._scroll.get_global_rect().encloses(first.get_global_rect()), "First useful action above shortest-phone fold")
    await swipe(first.get_global_rect().get_center(), 160)
    check(app.sim.current_contract_id.is_empty() and app.hud._scroll.scroll_vertical > 50, "Scrolling from work button never accepts it")
    await tap(first)
    if not check(app.sim.current_contract_id == "growth_1" and app.running, "Held real touch starts first paid work exactly once"):
        finish()
        return
    mark("First-open, scroll cancellation and held work acceptance")
    await process_elapsed(.15)
    await tap(app.hud._back)
    check(app.hud._sheet_kind == "controls", "Top-left operation control opens settings")
    await tap(node("Speed4x"))
    check(app.speed == 4 and app.sim.preferences.preferred_speed == 4, "Held speed touch reaches scene and persisted preference")
    await tap(node("PauseMenusSetting"))
    var before: Dictionary = app.sim.export_release_state()
    await process_elapsed(.2)
    check(app._menu_paused and app.running and app.sim.export_release_state() == before, "Real auto-pause toggle freezes all logistics in menu")
    await tap(node("ReducedMotionSetting"))
    check(app.world.reduced_motion and app.sim.preferences.reduced_motion, "Real reduced-motion control updates view and persisted state")
    await tap(app.hud._close)
    await process_elapsed(.1)
    check(not app._menu_paused and app.sim.sim_time > before.sim.sim_time, "Closing menu resumes prior run intent")
    await tap(app.hud._pause, "mouse")
    before = app.sim.export_release_state()
    await tap(app.hud._back)
    await tap(app.hud._close)
    await process_elapsed(.2)
    check(not app.running and app.sim.export_release_state() == before, "Explicit pause survives menu open and close")
    await tap(app.hud._back)
    await tap(node("ControlsPause"))
    check(app.running and app.hud._sheet_kind.is_empty(), "Settings resume is reachable and dismisses the menu")
    mark("Actual speed, auto-pause, reduced-motion, pause and resume controls")

    await tap(app.hud._back)
    var speed1 := node("Speed1x")
    await reach(speed1)
    var point := speed1.get_global_rect().get_center()
    point_input(point,true)
    await settle()
    root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    point_input(point,false)
    await settle()
    check(app.speed == 4 and not app.running, "Focus loss cancels held control and pauses warehouse")
    root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
    before = app.sim.export_release_state()
    await process_elapsed(.2)
    check(app.sim.export_release_state() == before and not app.running, "Returning focus cannot silently resume")
    await tap(speed1,"mouse")
    check(app.speed == 1, "Fresh click remains usable after lost-focus release")
    await tap(node("ControlsPause"))

    # Queue using the visible editor, then cancel before any domain step moves it.
    await tap(app.hud._primary)
    check(app.hud._sheet_kind == "editor", "Real layout control opens editor")
    var candidate := node("Candidate_annex")
    await tap(candidate)
    await tap(node("ApplyChoice"))
    check(not app.sim.pending_layout_id.is_empty(), "Visible layout apply queues a real free relocation")
    before = app.sim.export_release_state()
    await tap(app.hud._back)
    await tap(node("CancelQueuedLayout"))
    check(app.sim.pending_layout_id.is_empty() and app.sim.layout_id == before.sim.layout_id, "Visible cancel removes only pending layout")
    check(app.sim.cargo == before.sim.cargo and app.sim.campaign_wallet == before.campaign.wallet, "Cancel preserves cargo and wallet")
    check(app.hud._notice_title.contains("取り消"), "Successful cancellation is visibly acknowledged")
    if not app.hud._sheet_kind.is_empty(): await tap(app.hud._close)
    mark("Focus interruption, free layout queue and safe cancellation")

    finish_job()
    var completed_wallet: int = app.sim.campaign_wallet
    for repeat in 10:
        await process_elapsed(.1)
        refresh()
    check(app.sim.campaign_wallet == completed_wallet, "Repeated completion refresh cannot double-award")
    await open_records()
    await verify_reachability("completed 375x567")
    await tap(node("GrowWarehouse"))
    await tap(node("BuyUpgrade_wing_1"))
    check(app.sim.purchased_upgrades.has("wing_1") and app.sim.campaign_wallet == completed_wallet - 150, "Actual first wing purchase deducts cost exactly once")
    check(app.hud._sheet_kind.is_empty(), "Wing purchase reveals its earned world reward")
    await open_records()
    await tap(node("StartNextJob"))
    check(app.sim.current_contract_id == "growth_2" and app.running, "Actual results next action starts next milestone")
    finish_job()
    await open_records()
    completed_wallet = app.sim.campaign_wallet
    await tap(node("ReplayCurrentJob"))
    check(app.sim.current_contract_id == "growth_2" and not app.sim.finished, "Actual replay action restarts completed paid job")
    finish_job()
    check(app.sim.campaign_wallet == completed_wallet + 200, "Replay pays exactly one recurring reward")
    mark("Paid completion, earned expansion, next milestone and paid replay")

    await tap(node("EquipmentChoice"))
    await tap(node("ToggleOperations"))
    var wallet: int = app.sim.campaign_wallet
    for id in ["parcel","pallet","balanced"]:
        await tap(node("ChooseOperation_" + id))
        check(app.sim.operation_mode == id and app.sim.campaign_wallet == wallet, "Actual free mode selection " + id)
    await tap(node("ChooseOperation_parcel"))
    await tap(app.hud._close)
    mark("All free work modes selected through visible real controls")

    # Check every sheet and all scroll-reachable button geometry in portrait and
    # short landscape. Navigation remains real input; no action signals emitted.
    for dimensions in [Vector2i(375,567),Vector2i(390,844),Vector2i(430,932),Vector2i(568,320)]:
        root.size = dimensions
        await settle()
        await tap(app.hud._back)
        await verify_reachability("controls " + str(dimensions))
        await tap(node("OpenHelp"))
        await verify_reachability("help " + str(dimensions))
        await tap(app.hud._close)
        await open_records()
        await verify_reachability("results " + str(dimensions))
        await tap(node("ToggleGrowthHistory"))
        await verify_reachability("expanded records " + str(dimensions))
        await tap(app.hud._close)
        await tap(app.hud._compare)
        await verify_reachability("work " + str(dimensions))
        await tap(app.hud._close)
        await tap(node("EquipmentChoice"))
        if not app.hud._future_upgrades_visible: await tap(node("ToggleFutureUpgrades"))
        if not app.hud._owned_upgrades_visible: await tap(node("ToggleOwnedUpgrades"))
        await verify_reachability("equipment " + str(dimensions))
        await tap(app.hud._close)
        await tap(app.hud._primary)
        await verify_reachability("layout " + str(dimensions))
        check(app.hud._body.get_global_rect().grow(1).encloses(app.hud._apply.get_global_rect()), "Pinned full layout action " + str(dimensions))
        await tap(app.hud._close)
    mark("18px text, 56px actions, full reachable sheets at 375/390/430 and 568x320")

    root.size = Vector2i(375,567)
    await settle()
    await open_records()
    await tap(node("StartNextJob"))
    await process_elapsed(.2)
    await tap(app.hud._pause)
    before = app.sim.export_release_state()
    app.queue_free()
    await settle()
    await create_app(true)
    check(app.sim.export_release_state() == before, "Real native save and scene reload preserve exact paused cargo and preferences")
    check(app.speed == 1 and app.world.reduced_motion and app.sim.operation_mode == "parcel", "Reload reapplies speed, reduced motion and selected free mode")
    await tap(node("StartTrial"))
    check(not app.running and app.hud._sheet_kind.is_empty(), "Closing restored help never resumes saved job")
    await tap(app.hud._back)
    await tap(node("ControlsPause"))
    await process_elapsed(.1)
    check(app.running and app.sim.sim_time > before.sim.sim_time, "Real explicit resume continues restored cargo")
    # Ordinary write warnings still remain readable through settings. A terminal
    # schema-5 protection stop is a separate state, tested below.
    var transient_store := TransientWriteFailure.new()
    transient_store._read_ready = true
    app.save_store = transient_store
    app._save_now()
    check(not app.save_store.blocked and app.save_store.status == "保存できませんでした。画面を閉じると未保存の進行が失われます", "Nonterminal write failure retains the ordinary unsaved warning")
    await tap(app.hud._back)
    var warning := node("ControlsSaveStatus")
    check(await reach(warning) and warning.text == app.save_store.status, "Full Japanese save warning is reachable via real settings scroll")
    mark("Exact isolated native reload, explicit resume and reachable save warning")
    await tap(app.hud._close)
    before = app.sim.export_release_state()
    app.save_store.blocked = true
    app.save_store.status = "別の画面の更新または書込み結果を確認できません。データを保護して進行を停止しました"
    app._save_now()
    await settle()
    check(app.hud._sheet_kind == "save_protection" and not app.running, "Terminal save protection immediately stops the scene")
    warning = node("SaveProtectionReason")
    check(await reach(warning) and warning.text == app.save_store.status, "Full Japanese protection reason is reachable in the stop screen")
    check(app.hud._close.disabled and app.hud._pause.disabled, "Protection disables dismissal and resume actions")
    check(app.hud._content.find_children("*", "Button", true, false).is_empty(), "Protected screen exposes no start, purchase or overwrite action")
    await tap(app.hud._back)
    await tap(app.hud._close)
    await tap(app.hud._pause)
    await process_elapsed(.2)
    check(app.hud._sheet_kind == "save_protection" and not app.running and app.sim.export_release_state() == before, "Real Back, close and resume input cannot escape protection or advance cargo")
    await verify_reachability("protected save 375x567")
    mark("Terminal save protection shows the full reason and blocks player actions")
    app.queue_free()
    await settle()
    finish()

func finish() -> void:
    print(JSON.stringify({"suite":"experience_player_input_journey","checks":checks,"failures":failures,"milestones":milestones,"scope":"Native Godot 4.7.2 GUI touch/mouse dispatch and geometry; accelerated domain time; not physical iPhone/Safari or rendered pixels"}))
    quit(0 if failures.is_empty() else 1)
