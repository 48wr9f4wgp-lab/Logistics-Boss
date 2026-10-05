extends SceneTree
## Selected-job preparation and same-job replay. Actions use native GUI input;
## only shipment time is accelerated. No real player profile is read or written.
const Main = preload("res://prototype/growth_main.gd")
const Sim = preload("res://prototype/growth_sim.gd")
var app
var prepared_starts := 0
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
    run.call_deferred()

func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)

func settle(frames: int = 4) -> void:
    for frame in frames: await process_frame

func node(key: String) -> Control:
    return app.hud._root.find_child(key, true, false) as Control

func pointer(point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.position = point
    event.index = 0
    event.pressed = pressed
    Input.parse_input_event(event)

func tap(key: String) -> void:
    var button := node(key) as Button
    if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
        check(false, "Enabled visible button " + key)
        return
    var scroll: ScrollContainer = app.hud._scroll
    if is_instance_valid(scroll) and scroll.is_ancestor_of(button):
        scroll.ensure_control_visible(button)
        await settle()
        check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "Complete target reachable " + key)
    await create_timer(0.20).timeout
    var point := button.get_global_rect().get_center()
    pointer(point, true)
    for frame in 3:
        app.hud.refresh()
        await process_frame
    pointer(point, false)
    await settle()

func finish_job(sim) -> void:
    for tick in 16000:
        if sim.finished: break
        sim.step(0.25)
    check(sim.finished and sim.check_invariants().ok, "Real cargo completes and conserves " + sim.current_contract_id)

func compare_geometry(context: String) -> void:
    var pending: Array[Node] = [app.hud._root]
    while not pending.is_empty():
        var child: Node = pending.pop_back()
        for item in child.get_children(): pending.append(item)
        if not child is Control or not child.is_visible_in_tree(): continue
        if child is Button:
            check(child.get_theme_font_size("font_size") >= 18, context + " button type " + str(child.name))
            check(child.size.x >= 56 and child.size.y >= 56, context + " touch target " + str(child.name))
        elif child is Label:
            check(child.get_theme_font_size("font_size") >= 18, context + " readable label " + str(child.name))
            check(child.size.y + 1 >= child.get_minimum_size().y, context + " full label " + str(child.name))
    var scroll: ScrollContainer = app.hud._scroll
    check(root.get_visible_rect().grow(1).encloses(scroll.get_global_rect()), context + " scroll inside viewport")
    var area := scroll.get_global_rect()
    var previous := scroll.scroll_vertical
    var max_scroll := maxf(0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
    pending = [app.hud._content]
    while not pending.is_empty():
        var child: Node = pending.pop_back()
        for item in child.get_children(): pending.append(item)
        if child is Button and child.is_visible_in_tree():
            var rect: Rect2 = child.get_global_rect()
            var top: float = rect.position.y + previous - area.position.y
            var desired := clampf(top, 0, max_scroll)
            var projected := Rect2(Vector2(rect.position.x, area.position.y + top - desired), rect.size)
            check(area.grow(1).encloses(projected), context + " action scroll reachable " + str(child.name))

func compact_geometry(context: String, above_fold: bool = true) -> void:
    var scroll: ScrollContainer = app.hud._scroll
    var start := node("StartPreparedJob")
    check(start.get_parent() == app.hud._body and not scroll.is_ancestor_of(start), context + " start is outside scroll")
    check(root.get_visible_rect().encloses(start.get_global_rect()), context + " pinned start inside viewport")
    check(start.position.y >= scroll.position.y + scroll.size.y, context + " start cannot cover scroll content")
    if above_fold:
        check(scroll.scroll_vertical == 0, context + " starts at top")
        for id in ["balanced", "parcel", "pallet"]:
            check(scroll.get_global_rect().encloses(node("ChooseOperation_" + id).get_global_rect()), context + " complete mode above fold " + id)

func domain_checks() -> void:
    var sim = Sim.new()
    var initial: Dictionary = sim.export_release_state()
    var plan: Dictionary = sim.job_preparation("growth_1")
    check(plan.available and plan.total_units == 12 and plan.reward == 140, "Preparation reports authoritative manifest and unchanged reward")
    check(sim.job_preparation("unknown").is_empty(), "Unknown job has no preparation")
    check(not sim.job_preparation("growth_6").available, "Locked job cannot be prepared for acceptance")
    check(sim.export_release_state() == initial, "Preparation helpers are read-only")
    check(sim.accept_contract("growth_1").ok, "Domain quickstart still works")
    finish_job(sim)
    var first_elapsed: float = sim.sim_time
    var first_wait: float = sim.aisle_wait_seconds
    check(sim.job_comparison().is_empty(), "First completion never invents a previous run")
    check(sim.set_operation("parcel").ok and sim.apply_layout("clear_aisle").ok, "Free mode and layout changes remain valid")
    var wallet: int = sim.campaign_wallet
    check(sim.accept_contract("growth_1").ok, "Adjusted same-job replay starts")
    check(sim.job_comparison().is_empty(), "Running replay never compares an unfinished result")
    finish_job(sim)
    var comparison: Dictionary = sim.job_comparison()
    check(not comparison.is_empty(), "Repeated job exposes real previous completion")
    if not comparison.is_empty():
        check(comparison.previous.elapsed == first_elapsed and comparison.previous.aisle_wait_seconds == first_wait, "Previous metrics are frozen before mode/layout edits")
        check(comparison.previous.operation_id == "balanced" and comparison.current.operation_id == "parcel", "Comparison names the modes actually used")
        check(comparison.previous.layout_id == "compact" and comparison.current.layout_id == "clear_aisle", "Comparison names actual completion layouts")
        check(is_equal_approx(float(comparison.current.units_per_minute), 12.0*60.0/sim.sim_time), "Throughput uses actual cargo and game clock")
        comparison.previous.elapsed = -1.0
        check(sim.job_comparison().previous.elapsed == first_elapsed, "Comparison dictionaries cannot mutate the baseline")
    check(sim.campaign_wallet == wallet + 140, "Replay pays original reward exactly once")
    var saved: Dictionary = sim.export_release_state()
    check(saved.schema == 4 and saved.keys().size() == 6 and saved.hall == {"owned":false,"plan":"storage"}, "Schema 4 adds only hall state, never comparison fields")
    check(not saved.campaign.has("comparison") and not saved.experience.has("preparation"), "Selection and comparison remain outside durable profile")
    var restored = Sim.new()
    check(restored.import_release_state(saved).ok, "New result still loads through existing schema validation")
    check(restored.export_release_state() == saved, "Reload preserves exact gameplay and results")
    check(restored.job_comparison().is_empty(), "Reload cannot invent absent previous-run data")
    check(restored.release_state().best_time == sim.release_state().best_time, "Reload retains saved best time")
    check(sim.accept_contract("growth_2").ok, "Different selected job starts")
    finish_job(sim)
    check(sim.job_comparison().is_empty(), "Different jobs are never cross-compared")
    check(sim.accept_contract("growth_1").ok, "Return to earlier same job starts")
    finish_job(sim)
    check(sim.job_comparison().previous.operation_id == "parcel", "Same-job baseline survives intervening job")
    check(sim.import_release_state(saved).ok and sim.job_comparison().is_empty(), "Import into existing object clears transient observations")

    # Earn every milestone and each purchase. No modified wallet or cargo fixture.
    for number in range(2, 7):
        check(sim.accept_contract("growth_%d" % number).ok, "Earn mature milestone %d" % number)
        finish_job(sim)
    check(not sim.growth_catalog_complete(), "Six milestones do not imply all growth equipment is owned")
    for option in sim.GROWTH_UPGRADES:
        if option.id in ["rack_48", "crew_6"]: continue
        while sim.campaign_wallet < int(option.cost):
            check(sim.accept_contract("route_bulk").ok, "Earn upgrade funds")
            finish_job(sim)
        check(sim.buy_upgrade(str(option.id)).ok, "Earned mature purchase " + str(option.id))
    check(not sim.growth_catalog_complete(), "Four wings and robots do not hide missing staff/shelves")
    check(not sim._next_goal().contains("完成"), "Missing improvements do not claim max growth completion")
    for id in ["rack_48", "crew_6"]:
        while sim.campaign_wallet < int(sim._upgrade(id).cost):
            check(sim.accept_contract("route_bulk").ok, "Earn remaining upgrade funds")
            finish_job(sim)
        check(sim.buy_upgrade(id).ok, "Earn final " + id)
    check(not sim.growth_catalog_complete(), "The former four-wing ceiling leaves the earned regional hall available")
    check(sim.accept_contract("route_hub").ok, "Complete the actual hall-qualifying hub")
    finish_job(sim)
    while sim.campaign_wallet < int(sim._upgrade("regional_hall").cost):
        check(sim.accept_contract("route_hub").ok,"Earn the hall through an existing paid hub")
        finish_job(sim)
    check(sim.buy_upgrade("regional_hall").ok,"Earn the final hall purchase")
    check(sim.growth_catalog_complete(), "Catalog complete requires every current improvement")
    check(sim._next_goal().contains("広域便") and not sim._next_goal().contains("資金をため"), "Completed-hall next goal describes its actual work")
    check(sim.release_state().growth.catalog_complete, "Presentation receives derived complete state")

func run() -> void:
    domain_checks()
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(375, 567)
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = true
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    await settle()
    check(app.hud._preparation_reward_copy({"repeatable":true,"reward":140,"completed":true}) == "毎回の報酬 140", "Growth replay preparation shows recurring reward")
    check(app.hud._preparation_reward_copy({"reward":180,"completed":false}) == "初回の報酬 180", "Legacy first completion preparation shows first-only reward")
    check(app.hud._preparation_reward_copy({"reward":180,"completed":true}) == "再挑戦の報酬 0", "Legacy replay preparation never promises recurring reward")
    await tap("StartTrial")
    var original: Dictionary = app.sim.export_release_state()
    var quickstart := node("AcceptContract_growth_1")
    check(app.hud._scroll.get_global_rect().encloses(quickstart.get_global_rect()), "Direct first-job quickstart remains above short-phone fold")
    await tap("PrepareContract_growth_1")
    check(app.hud._prepared_contract_id == "growth_1" and app.hud._release_tab == "prepare", "Optional preparation selects the requested job")
    check(app.sim.export_release_state() == original and not app.running, "Opening preparation does not accept, charge or run")
    compact_geometry("initial short phone")
    check(not node("PreparationDetails").visible, "Long explanations begin folded")
    await tap("TogglePreparationDetails")
    var pinned := node("StartPreparedJob").get_global_rect()
    check(node("PreparationDetails").visible and app.sim.export_release_state() == original, "Expand details is read-only")
    app.hud._scroll.scroll_vertical = 10000
    await settle()
    check(node("StartPreparedJob").get_global_rect() == pinned, "Start remains pinned at end of details")
    compact_geometry("expanded details", false)
    await tap("TogglePreparationDetails")
    check(not node("PreparationDetails").visible and app.sim.export_release_state() == original, "Collapse details is read-only")
    await tap("CloseSheet")
    check(app.hud._release_tab == "contracts" and app.sim.export_release_state() == original, "Closing untouched preparation returns to jobs without mutation")
    await tap("PrepareContract_growth_1")
    for mode in ["parcel", "pallet", "balanced"]:
        await tap("ChooseOperation_" + mode)
        check(app.sim.operation_mode == mode and app.sim.current_contract_id.is_empty(), "Preparation commits existing free mode without starting " + mode)
        check(app.sim.campaign_wallet == 100 and app.hud._prepared_contract_id == "growth_1", "Mode change preserves selected job and wallet " + mode)
    await tap("TogglePreparationDetails")
    await tap("PrepareLayout")
    await tap("Candidate_annex")
    await tap("CloseSheet")
    check(app.sim.layout_id == "compact" and app.hud._release_tab == "prepare", "Unapplied layout cancel returns to same preparation")
    check(app.hud._prepared_contract_id == "growth_1", "Canceled editor retains exact selected job")
    await tap("PrepareLayout")
    await tap("Candidate_annex")
    await tap("ApplyChoice")
    check(app.sim.layout_id == "clear_aisle" and app.hud._release_tab == "prepare", "Applied free layout returns to preparation")
    check(node("PreparedLayout").text.contains(app.sim._option("clear_aisle").label), "Preparation reflects committed layout after returning")
    for size in [Vector2i(375,567), Vector2i(390,844), Vector2i(430,932), Vector2i(568,320)]:
        root.size = size
        await settle()
        compare_geometry("preparation " + str(size))
        compact_geometry("prepared resized " + str(size), false)
    root.size = Vector2i(375,567)
    await settle()
    app.hud.contract_requested.connect(func(_id: String): prepared_starts += 1)
    var start_point := node("StartPreparedJob").get_global_rect().get_center()
    pointer(start_point, true)
    await settle()
    app._cancel_web_touch()
    pointer(start_point, false)
    await settle()
    check(prepared_starts == 0 and not app.running and app.hud._release_tab == "prepare", "Canceled pinned Start never accepts job")
    await tap("StartPreparedJob")
    check(prepared_starts == 1, "Fresh pinned Start emits exactly once after canceled press")
    check(app.sim.current_contract_id == "growth_1" and app.running and app.hud._sheet_kind.is_empty(), "Held prepared-start dispatch starts selected job exactly once")
    check(app.sim.campaign_wallet == 100 and app.sim.operation_mode == "balanced" and app.sim.layout_id == "clear_aisle", "Prepared start preserves chosen setup and costs nothing")
    app.hud._start_prepared_contract()
    check(app.sim.current_contract_id == "growth_1" and app.sim.sim_time == 0, "Repeated stale prepared-start cannot restart or double-accept")
    finish_job(app.sim)
    app.hud.refresh()
    app.hud.show_conditions()
    await settle()
    check(node("SameJobComparison").text.contains("この起動中"), "First completion explains session comparison boundary")
    await tap("AdjustReplayJob")
    check(app.hud._prepared_contract_id == "growth_1", "Adjust-and-replay returns exact completed job")
    await tap("ChooseOperation_parcel")
    await tap("StartPreparedJob")
    finish_job(app.sim)
    app.hud.refresh()
    app.hud.show_conditions()
    await settle()
    check(node("SameJobComparison").text.contains("前回 → 今回") and node("SameJobComparison").text.contains("平均出荷"), "Visible results compare same-job actual performance")
    check(node("SameJobComparison").text.contains("バランス重視") and node("SameJobComparison").text.contains("小口をまとめて運ぶ"), "Visible comparison explains both operating modes")
    check(node("CurrentJobBest").text.contains("自己ベスト") and node("CurrentJobBest").is_visible_in_tree(), "Same-job best is visible without expanding history")
    check(node("ReplayCurrentJob") != null and node("StartNextJob") != null, "Direct replay and next-job quick actions remain")
    for size in [Vector2i(375,567), Vector2i(390,844), Vector2i(430,932), Vector2i(568,320)]:
        root.size = size
        await settle()
        compare_geometry("comparison " + str(size))
    var saved: Dictionary = app.sim.export_release_state()
    check(app.sim.import_release_state(saved).ok, "Reload final scene domain safely")
    app.hud.refresh()
    check(node("SameJobComparison").text.contains("この起動中") and not node("SameJobComparison").text.contains("前回 → 今回"), "Restored results disclose no prior-session comparison")
    check(node("SameJobComparison").text.contains("2回"), "Restored results do not promise comparison after only one current-session replay")
    app.hud._toggle_history()
    check(node("ReleaseRecordBest").text.contains("自己ベスト"), "Saved best remains accessible after detailed comparison clears")
    app.queue_free()
    await settle()
    print(JSON.stringify({"suite":"preparation_player_flow","checks":checks,"failures":failures,"scope":"Godot native GUI input and geometry; real cargo with accelerated time; no browser or physical iPhone claim"}))
    quit(0 if failures.is_empty() else 1)
