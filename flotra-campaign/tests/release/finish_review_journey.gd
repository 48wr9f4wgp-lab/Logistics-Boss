extends SceneTree
const Main = preload("res://prototype/release_main.gd")
const Sim = preload("res://prototype/release_sim.gd")
const Save = preload("res://prototype/release_save.gd")
var app
var log: Array = []
var failures: Array = []
var checks := 0
var observed_holding_countdown := false
func _init() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
    checks += 1
    if not value: failures.append(label)
func settle() -> void:
    for i in 4: await process_frame
func tap(button: Control, count: int = 1) -> void:
    while Time.get_ticks_msec() <= app.hud._background_guard_until:
        await process_frame
    if app.hud._scroll != null and app.hud._scroll.is_ancestor_of(button):
        app.hud._scroll.ensure_control_visible(button)
        await settle()
    var motion := InputEventMouseMotion.new()
    motion.position = button.get_global_rect().get_center()
    motion.global_position = motion.position
    root.push_input(motion)
    for i in count:
        var press := InputEventMouseButton.new()
        press.position = button.get_global_rect().get_center()
        press.global_position = press.position
        press.button_index = MOUSE_BUTTON_LEFT
        press.pressed = true
        root.push_input(press)
        var release := press.duplicate()
        release.pressed = false
        root.push_input(release)
    await create_timer(.21).timeout
    await settle()
func texts(node: Node) -> Array:
    var out: Array = []
    for child in node.get_children():
        if child is Label or child is Button: out.append(child.text)
        out.append_array(texts(child))
    return out
func record(label: String) -> void:
    app.hud.refresh()
    print("AT ",label," status ",app.sim.campaign_status," sheet ",app.hud._sheet_kind," running ",app.running," elapsed ",app.sim.sim_time)
    log.append({"label":label,"status":app.sim.campaign_status,"time":app.sim.sim_time,"title":app.hud._reason_title.text,"detail":app.hud._reason_detail.text,"totals":app.hud._shipped.text,"queues":[app.hud._travel.text,app.hud._waiting.text],"sheet":app.hud._sheet_kind,"text":texts(app.hud._content) if app.hud._content != null else [],"layout":app.sim.layout_id,"workers":app.sim.workers.size()})
func advance(seconds: int, sample_every: int = 0) -> void:
    for second in seconds:
        if not app.sim.finished: app.sim.step(1)
        app.hud._process(1)
        if app.hud._reason_title.text == "保管時間の終了待ち":
            observed_holding_countdown = true
            check(app.hud._reason_detail.text.contains("秒"), "holding countdown explains real wait")
        if sample_every > 0 and second % sample_every == 0: record("tick")
func finish() -> void:
    var start: float = app.sim.sim_time
    while not app.sim.finished and app.sim.sim_time < start+2500:
        advance(1)
    check(app.sim.finished,"contract finished "+app.sim.current_contract_id)
    app.hud.refresh()
func open_contracts() -> void:
    if not app.hud._sheet_kind.is_empty():
        await tap(app.hud._close)
    await tap(app.hud._compare)
    if app.hud._release_tab != "contracts": await tap(app.hud._tabs.get_node("Tab_contracts"))
func accept(id: String) -> void:
    await open_contracts()
    await tap(app.hud._contract_buttons[id],5)
    check(app.sim.current_contract_id == id and app.sim.campaign_status == "running","click accepts "+id)
    record("accepted "+id)
    await tap(app.hud._compare)
    await tap(app.hud._tabs.get_node("Tab_demand"))
    var rule := app.hud._content.get_node_or_null("BulkHoldingRule") as Label
    check(rule != null and rule.text.contains("%d秒" % int(app.sim.bulk_dwell)), "demand shows actual holding condition for "+id)
    await tap(app.hud._close)
func layout(shelf: String) -> void:
    if not app.hud._sheet_kind.is_empty(): await tap(app.hud._close)
    await tap(app.hud._primary)
    await tap(app.hud._previous)
    if app.hud._choice_id != shelf:
        for button in app.hud._choice_buttons:
            if str(button.name) == "Candidate_"+shelf: await tap(button)
        record("layout-preview "+shelf)
        await tap(app.hud._apply,5)
    else: await tap(app.hud._close)
func buy(id: String) -> void:
    await open_contracts()
    await tap(app.hud._tabs.get_node("Tab_upgrades"))
    var wallet: int = app.sim.campaign_wallet
    await tap(app.hud._upgrade_buttons[id],5)
    check(id in app.sim.purchased_upgrades,"buy once "+id)
    record("bought "+id)
    await tap(app.hud._close)
func result(label: String) -> void:
    await tap(app.hud._conditions)
    record(label)
    var medal: String = {"gold":"金", "silver":"銀", "bronze":"銅"}[str(app.sim.last_result.medal)]
    var summary := "\n".join(texts(app.hud._content))
    check(summary.contains(medal+"メダル") or summary.contains("今回 "+medal), "results expose awarded medal: "+label)
    if label == "replay result":
        check(not app.hud._content.get_node("ReleaseRecordSummary").text.begins_with("全6契約"), "replay heading celebrates this contract's outcome")
    await tap(app.hud._close)
func run() -> void:
    # This journey performs real native persistence. Never let a direct/manual
    # script invocation touch a player's normal campaign save.
    var sandbox := OS.get_environment("FLOTRA_REVIEW_USER_ROOT")
    var native_path := ProjectSettings.globalize_path(Save.PATH)
    if not sandbox.is_empty(): sandbox = sandbox.trim_suffix("/") + "/"
    if sandbox.is_empty() or sandbox.length() < 8 or not native_path.begins_with(sandbox):
        push_error("Native journey requires FLOTRA_REVIEW_USER_ROOT containing isolated user storage")
        quit(2)
        return
    # Earlier aggregate suites intentionally leave malformed fake data here.
    # Only these disposable sandbox fixtures are cleared, never a real profile.
    for path in [Save.PATH, Save.BACKUP, Save.PATH+".tmp"]:
        if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    root.size = Vector2i(375,667)
    app = Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    await settle()
    record("entry")
    await tap(app.hud._content.get_node("StartTrial"),5)
    check(app.hud._sheet_kind == "jobs","start enters contract menu")
    await tap(app.hud._contract_buttons.first_shift,5)
    advance(2)
    record("first at2")
    advance(48)
    record("first at50")
    await tap(app.hud._pause)
    check(not app.running,"actual scene pauses")
    await tap(app.hud._primary)
    record("before cancelled preview")
    if app.hud._choice_buttons.is_empty():
        print("FAIL_NO_EDITOR ", texts(app.hud._root))
        quit(3)
        return
    await tap(app.hud._choice_buttons[1])
    record("paused preview cancelled")
    await tap(app.hud._close,5)
    check(not app.running and app.sim.layout_id=="compact","cancel preserves pause and layout")
    await tap(app.hud._pause)
    finish()
    await result("first result")
    await open_contracts()
    record("branch choices after first")
    await tap(app.hud._close)
    await buy("rack_24")
    await layout("annex")
    await accept("small_orders")
    advance(60)
    var saved: Dictionary = app.sim.export_release_state()
    var store = Save.new()
    var decoded: Dictionary = store.decode(store.encode(saved))
    var restored = Sim.new()
    check(decoded.ok and restored.import_release_state(decoded.data).ok,"mid-contract encoded save restores")
    check(restored.export_release_state() == saved,"exact restore at decision point")
    app.persistence_enabled = true
    app._save_now()
    check(app.save_store.status == "自動保存済み", "actual scene writes dedicated native save")
    app.queue_free()
    await settle()
    app = Main.new()
    root.add_child(app)
    app.set_process(false)
    await settle()
    check(not app.running and app.hud._sheet_kind == "entry", "fresh scene resumes paused behind intro")
    check(app.sim.export_release_state() == saved, "actual scene reload restores exact in-flight state")
    check(not app.save_store.blocked, "scene reload retains writable isolated save")
    check(app.hud._content.get_node("StartTrial").text == "倉庫の続きへ", "restored scene identifies continuation")
    await tap(app.hud._content.get_node("StartTrial"),5)
    check(app.running and app.hud._sheet_kind.is_empty(), "explicit continue resumes existing contract once")
    for i in 75:
        advance(1)
        restored.step(1)
    check(restored.export_release_state() == app.sim.export_release_state(),"restored branch deterministic continuation")
    record("small orders midrun")
    finish()
    await result("small result")
    await open_contracts()
    record("locked text after first branch")
    for option in app.sim.contract_options():
        if option.id in ["packing_rush", "storage_peak"]:
            check(not option.available and option.locked_reason.contains("03 パレットの波") and not option.locked_reason.contains("02 小さな注文ラッシュ"), "locked advanced card names only remaining branch")
    await tap(app.hud._close)
    await buy("packing_2")
    await layout("core")
    await accept("pallet_wave")
    advance(35)
    record("bulk backlog")
    finish()
    await result("pallet result")
    await buy("worker_4")
    await accept("storage_peak")
    advance(50)
    record("storage hold")
    finish()
    await result("storage result")
    await buy("floor_2")
    await layout("annex")
    await accept("packing_rush")
    advance(80)
    record("packing backlog")
    finish()
    await result("packing result")
    await buy("worker_5")
    await layout("core")
    await accept("final_dispatch")
    finish()
    record("ending main")
    await result("ending result")
    var end_wallet: int = app.sim.campaign_wallet
    check(app.sim.completed_count==6,"all six contracts completed via actual main signals")
    await layout("annex")
    await accept("small_orders")
    finish()
    await result("replay result")
    check(app.sim.campaign_wallet==end_wallet,"replay preserves wallet")
    check(app.sim.contract_results.small_orders.attempts==2,"replay increments attempt once")
    var output := OS.get_environment("FLOTRA_FINISH_REVIEW_OUTPUT")
    if not output.is_empty():
        var file := FileAccess.open(output,FileAccess.WRITE)
        check(file != null, "report output writable")
        if file != null:
            file.store_string(JSON.stringify({"checks":checks,"failures":failures,"observed_holding_countdown":observed_holding_countdown,"journey":log,"final_state":app.sim.release_state()},"  "))
    print("FINISH_REVIEW_JOURNEY ",JSON.stringify({"checks":checks,"failures":failures,"observed_holding_countdown":observed_holding_countdown,"results":app.sim.contract_results,"wallet":app.sim.campaign_wallet}))
    app.queue_free()
    await settle()
    quit(0 if failures.is_empty() else 1)
