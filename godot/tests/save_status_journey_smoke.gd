extends "res://tests/mobile_notification_clearance_smoke.gd"

const MainScene = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/save_preservation_fixtures.gd")
const Store = preload("res://persistence/save_store.gd")
var _checks := 0


func _expect(value: bool, message: String) -> void:
    _checks += 1
    super._expect(value, message)


func _run() -> void:
    if not Fixture.isolated():
        push_error("save_status_journey_smoke requires the isolated-profile runner")
        quit(1)
        return
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]:
        get_root().size = dimensions
        await _verify_protected_main("future")
        await _verify_protected_main("corrupt")
        await _verify_notice_lifecycle()
    Fixture.clear()
    print("Save status actual-main checks=%d failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _main_context(kind: String) -> Dictionary:
    Fixture.seed(kind)
    var app := MainScene.instantiate()
    get_root().add_child(app)
    app.set_process(false)
    var hud: MobileGameHud
    for child in app.get_children():
        if child is MobileGameHud:
            hud = child
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    # Markers are not relevant to save-status rendering and must not be written
    # by a synthetic tutorial completion in an unsaved test simulation.
    clarity.coach._persist_completion = false
    return {"app": app, "hud": hud, "clarity": clarity, "notice": clarity.save_notice}


func _verify_protected_main(kind: String) -> void:
    var c := _main_context(kind)
    var app: Node = c["app"]
    var hud: MobileGameHud = c["hud"]
    var clarity: MobileInteractionClarity = c["clarity"]
    var notice: LogisticsSaveStatusNotice = c["notice"]
    var store := app.get("save_store") as LogisticsSaveStore
    var sim := app.get("sim") as FlotraV2Sim
    sim.set_time_scale(0.0)
    var before := Fixture.snapshot()
    await _settle()
    _expect(store.write_protected and store.load_status == "failed", "%s actual main detects failed restore" % kind)
    _expect(notice.visible and notice.notice_kind == "protected" and notice.label.text.contains("保存されません"), "%s persistent notice discloses unsaved play" % kind)
    _verify_clearance_for_notice(hud, clarity, notice)
    for attempt in 3:
        app.call("_process", 10.1)
        app.call("_notification", Node.NOTIFICATION_APPLICATION_PAUSED)
        app.call("_notification", Node.NOTIFICATION_WM_CLOSE_REQUEST)
        _expect(not store.save_sim(sim), "%s direct save is protected after lifecycle attempt %d" % [kind, attempt])
        _expect(Fixture.snapshot() == before, "%s autosave/pause/close/direct-save preserve every byte" % kind)
    notice._process(90.0)
    _expect(notice.has_notice(), "%s protection notice has no expiring timer" % kind)
    _engine_tap(hud._manage_button)
    await _settle()
    _expect(hud._sheet.visible and not notice.visible, "Management remains reachable and warning yields to its controls")
    _engine_tap(hud._manage_button)
    await _settle()
    _expect(not hud._sheet.visible and notice.visible, "Returning to warehouse restores persistent protection notice")
    clarity.zone.open_zone("storage")
    await _settle()
    _expect(not notice.visible, "Zone inspection hides passive save warning")
    _engine_tap(clarity.zone._close_button)
    await _settle()
    _expect(not clarity.zone.is_open() and notice.visible, "Zone Close remains reachable and restores warning")
    hud._request_reset_confirmation()
    await _settle()
    _expect(not notice.visible, "Reset confirmation is unobscured")
    _engine_tap(hud._reset_cancel_button)
    await _settle()
    _expect(not hud._reset_modal.visible and notice.visible, "Reset Cancel returns without losing warning")
    _expect(Fixture.snapshot() == before, "Cancel never resets protected source files")
    _engine_tap(hud._v2_growth_goal)
    await _settle()
    _expect(hud._sheet.visible, "Growth goal remains engine-touch reachable below protection notice")
    app.queue_free()
    await _settle()
    # A genuinely new main/store must rediscover protection, not depend only on
    # an in-memory latch in the previous scene.
    var reentry := MainScene.instantiate()
    get_root().add_child(reentry)
    reentry.set_process(false)
    _expect(reentry.get("save_store").write_protected, "Scene reentry redetects unresolved files")
    reentry.call("_process", 20.0)
    _expect(Fixture.snapshot() == before, "Scene reentry cannot autosave fresh progress over source files")
    reentry.queue_free()
    await _settle()


func _verify_notice_lifecycle() -> void:
    var c := _main_context("backup")
    var app: Node = c["app"]
    var hud: MobileGameHud = c["hud"]
    var clarity: MobileInteractionClarity = c["clarity"]
    var notice: LogisticsSaveStatusNotice = c["notice"]
    var store := app.get("save_store") as LogisticsSaveStore
    var sim := app.get("sim") as FlotraV2Sim
    await _settle()
    _expect(sim.money == 43210 and not store.write_protected, "Actual main resumes usable backup without freezing normal saving")
    _expect(notice.visible and notice.notice_kind == "backup" and notice.label.text.contains("バックアップ"), "Backup restoration is disclosed without claiming newer progress")
    _verify_clearance_for_notice(hud, clarity, notice)
    clarity.open_section("field")
    await _settle()
    var remaining := notice._remaining
    notice._process(20.0)
    _expect(is_equal_approx(notice._remaining, remaining), "Hidden restore notice retains reading time")
    _engine_tap(hud._manage_button)
    await _settle()
    notice._process(20.0)
    clarity.refresh()
    _expect(not notice.has_notice() and not notice.visible, "Backup notice expires after visible reading time")
    _expect(store.save_sim(sim), "Recovered session performs a genuine ordinary save")
    clarity.refresh()
    _expect(not notice.has_notice(), "Ordinary autosave does not replay the recovery notice")
    var before := Fixture.snapshot()
    _expect(Fixture.set_writable(false) == OK, "Actual-main fixture directory becomes read-only")
    app.call("_process", 10.1)
    Fixture.set_writable(true)
    await _settle()
    _expect(store.save_status == "failed" and not store.write_protected, "Actual main reports real autosave failure")
    _expect(Fixture.snapshot() == before, "Actual autosave failure preserves committed files")
    _expect(notice.visible and notice.notice_kind == "failed" and notice.label.text.contains("未保存"), "Real write failure gets a clear persistent status")
    _verify_clearance_for_notice(hud, clarity, notice)
    notice._process(60.0)
    _expect(notice.has_notice(), "Save failure cannot expire into false reassurance")
    app.call("_process", 10.1)
    await _settle()
    _expect(store.save_status == "saved" and notice.notice_kind == "saved", "Next actual successful autosave clears the failure")
    _expect(notice.label.text.contains("保存できました"), "Recovery claim follows genuine committed save")
    _verify_clearance_for_notice(hud, clarity, notice)
    notice._process(10.0)
    clarity.refresh()
    _expect(not notice.visible and not notice.has_notice(), "Success confirmation expires once")
    app.call("_process", 10.1)
    _expect(not notice.has_notice(), "Repeated ordinary saves do not spam notifications")
    app.queue_free()
    await _settle()


func _verify_clearance_for_notice(hud: MobileGameHud, clarity: MobileInteractionClarity, notice: LogisticsSaveStatusNotice) -> void:
    var rect := notice.get_global_rect()
    _expect(rect.encloses(notice.label.get_global_rect()), "Save text is enclosed by its notice")
    _expect(not rect.intersects(hud._v2_growth_goal.get_global_rect()), "Notice leaves growth goal clear")
    for button in [hud._manage_button, hud._speed_button, hud._v2_growth_goal]:
        _expect(not rect.intersects(button.get_global_rect()), "Save notice leaves %s outside its bounds" % button.text)
        _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button, "%s center stays reachable" % button.text)
    _expect(notice.mouse_filter == Control.MOUSE_FILTER_IGNORE and notice.label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Passive save status never owns taps")
    _expect(not clarity.coach.visible and not clarity.resume_brief.visible, "Save status has exclusive use of its information band")
