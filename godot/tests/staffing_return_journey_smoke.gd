extends "res://tests/mobile_notification_clearance_smoke.gd"

# Actual-main session boundaries with Input's synthetic-mouse stage enabled.
# Fixture rank/money are explicit; this is not natural pacing or device evidence.
const MainScene = preload("res://scenes/main.tscn")
const Fixture = preload("res://tests/save_preservation_fixtures.gd")
var _checks := 0


func _expect(value: bool, message: String) -> void:
    _checks += 1
    super._expect(value, message)


func _run() -> void:
    if not Fixture.isolated():
        push_error("staffing_return_journey_smoke requires the isolated-profile runner")
        quit(1)
        return
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    var capture_dir := OS.get_environment("FLOTRA_STAFFING_CAPTURE_DIR")
    if not capture_dir.is_empty():
        await _capture_return_comparison(capture_dir)
    else:
        for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]:
            get_root().size = dimensions
            print("Staffing return actual-main viewport=%s" % str(dimensions))
            await _verify_return_journey()
    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    Fixture.clear()
    print("Staffing return actual-main checks=%d; failures=%d" % [_checks, _failures])
    quit(0 if _failures == 0 else 1)


func _verify_return_journey() -> void:
    Fixture.clear()
    var app := MainScene.instantiate()
    get_root().add_child(app)
    # Freeze real-time simulation/autosave while the actual composed UI runs.
    app.set_process(false)
    var sim := app.get("sim") as FlotraV2Sim
    var hud: MobileGameHud
    for child in app.get_children():
        if child is MobileGameHud:
            hud = child
    _expect(hud != null, "Main includes the production mobile HUD")
    if hud == null:
        app.queue_free()
        await _settle()
        return
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.coach._persist_completion = false
    hud._ftue_coach._persist_completion = false
    sim.money = 100000
    sim.purchase_rank1_project(&"rack_wing")
    sim.purchase_rank1_project(&"forklift_project")
    sim.shipped = sim.EXPANSION_SHIPMENTS
    _expect(bool(sim.purchase_warehouse_expansion().get("ok", false)), "Rank 2 fixture uses authoritative expansion")
    _expect(sim.zone_staffing == {"inbound": 2, "picking": 2, "shipping": 1}, "Fixture begins at authoritative 2/2/1")
    var panel := clarity.staffing
    var store := app.get("save_store") as LogisticsSaveStore
    _expect(store.save_sim(sim), "Fixture writes its authoritative baseline into the disposable profile")
    var baseline := sim.save_data().duplicate(true)
    var files := Fixture.snapshot()
    var header_close := hud._management_title.get_parent().get_child(1) as Button
    await _settle()

    await _tap_checked(hud._manage_button, clarity)
    await _tap_checked(clarity._tabs["staffing"] as Button, clarity)
    _expect_fresh(clarity, "First ordinary Management entry")
    await _edit(clarity)
    await _tap_checked(panel.cards["picking"] as Button, clarity)
    var draft := panel.draft.duplicate(true)
    var selected := panel.selected
    hud._mobile_scroll.scroll_vertical = 18
    await _settle()
    var scroll := hud._mobile_scroll.scroll_vertical
    var retaps := {"count": 0}
    (clarity._tabs["staffing"] as Button).pressed.connect(func(): retaps["count"] += 1)
    for attempt in 3:
        await _tap_checked(clarity._tabs["staffing"] as Button, clarity)
        _expect(retaps["count"] == attempt + 1, "Same-session selected-tab gesture activates exactly once")
        _expect(panel.draft == draft and panel.selected == selected and panel.expected == sim.zone_staffing, "Same-session selected-tab retap preserves draft, source and expectation")
        _expect(hud._mobile_scroll.scroll_vertical == scroll and not panel.apply_button.disabled, "Same-session selected-tab retap retains scroll and available Apply")
        _expect_unchanged(sim, baseline, files, "Selected-tab retap %d" % attempt)

    for mode in ["dock", "header", "cancel"]:
        for attempt in 3:
            # Establish each case independently using the pre-existing explicit
            # navigation path, so baseline failures cannot mask later cases.
            hud._sheet.visible = false
            clarity.open_section("staffing")
            await _settle()
            await _edit(clarity)
            var close := hud._manage_button if mode == "dock" else (header_close if mode == "header" else panel.cancel_button)
            await _tap_checked(close, clarity)
            _expect(not hud._sheet.visible, "%s close returns to the warehouse" % mode)
            _expect_unchanged(sim, baseline, files, "%s close %d" % [mode, attempt])
            await _tap_checked(hud._manage_button, clarity)
            _expect_fresh(clarity, "%s close/dock reopen %d" % [mode, attempt])
            _expect_unchanged(sim, baseline, files, "%s reopen %d" % [mode, attempt])

    for section in ["field", "expansion", "contracts", "settings"]:
        hud._sheet.visible = false
        clarity.open_section("staffing")
        await _settle()
        await _edit(clarity)
        await _tap_checked(clarity._tabs[section] as Button, clarity)
        _expect(clarity._section == section and hud._sheet.visible, "Changing section keeps Management open")
        await _tap_checked(clarity._tabs["staffing"] as Button, clarity)
        _expect_fresh(clarity, "Return from %s" % section)
        _expect_unchanged(sim, baseline, files, "Section round trip %s" % section)

    await _edit(clarity)
    await _tap_checked(header_close, clarity)
    clarity.open_section("staffing")
    await _settle()
    _expect_fresh(clarity, "Explicit closed-sheet navigation")
    await _edit(clarity)
    await _tap_checked(hud._manage_button, clarity)
    clarity.zone.open_zone("inbound")
    await _settle()
    await _tap_checked(clarity.zone._staffing_open, clarity)
    _expect(not clarity.zone.is_open(), "Zone staffing shortcut yields to Management")
    _expect_fresh(clarity, "Zone staffing shortcut")
    _expect_unchanged(sim, baseline, files, "Explicit and Zone entry")

    await _verify_interrupted_input(clarity, sim, baseline, files)

    # Changing the authoritative assignments while closed invalidates a cached
    # draft. Reopening must read the new state, not a retained 2/2/1 expectation.
    await _edit(clarity)
    await _tap_checked(header_close, clarity)
    var external := {"inbound": 2, "picking": 1, "shipping": 2}
    _expect(bool(sim.apply_staffing_distribution(external, sim.zone_staffing.duplicate(true)).get("ok", false)), "External closed-sheet fixture uses real staffing API")
    baseline = sim.save_data().duplicate(true)
    _expect(Fixture.snapshot() == files, "External Domain change does not bypass the ordinary save path")
    await _tap_checked(hud._manage_button, clarity)
    _expect_fresh(clarity, "Closed-sheet authoritative assignment change")
    _expect(panel.status.text.contains("反映まであと"), "New session truthfully reflects authoritative staffing cooldown")
    _expect_unchanged(sim, baseline, files, "External-change reopening")

    # Clear the real cooldown through simulation time before an intentional Apply.
    # This is explicit test setup, not a presentation-side rule exception.
    sim.step(30.1)
    await _settle()
    baseline = sim.save_data().duplicate(true)
    await _edit(clarity)
    var target := panel.draft.duplicate(true)
    var applied := {"count": 0}
    panel.applied.connect(func(): applied["count"] += 1)
    _expect_unchanged(sim, baseline, files, "Final draft before explicit Apply")
    await _tap_checked(panel.apply_button, clarity)
    _expect(applied["count"] == 1 and sim.zone_staffing == target, "One engine-parsed Apply commits the exact draft once")
    _expect(sim.staffing_cooldown == 30.0 and not hud._sheet.visible, "Explicit Apply keeps existing cooldown and returns to warehouse")
    _expect(Fixture.snapshot() == files, "Apply does not invent an immediate save outside the existing save path")
    var applied_state := sim.save_data().duplicate(true)
    await _tap_checked(hud._manage_button, clarity)
    _expect_fresh(clarity, "Post-Apply reopening")
    _expect(sim.save_data() == applied_state, "Post-Apply reopening never reapplies the assignment")
    _expect(store.save_sim(sim), "Ordinary save persists the explicitly applied staffing")
    var restored := SimScript.new() as FlotraV2Sim
    var reader := LogisticsSaveStore.new()
    _expect(reader.load_into(restored) and restored.zone_staffing == target, "Saved/reloaded assignments match only the explicit Apply")
    app.queue_free()
    await _settle()


func _verify_interrupted_input(clarity: MobileInteractionClarity, sim: FlotraV2Sim, baseline: Dictionary, files: Dictionary) -> void:
    var panel := clarity.staffing
    var hud := clarity.hud
    await _edit(clarity)
    var draft := panel.draft.duplicate(true)
    var selected := panel.selected
    var header_close := hud._management_title.get_parent().get_child(1) as Button
    for target in [panel.apply_button, panel.cancel_button, hud._manage_button, header_close, panel.cards["picking"]]:
        var point: Vector2 = target.get_global_rect().get_center()
        _engine_touch(point, true)
        _engine_touch(point, false, true)
        await _settle()
        _expect(hud._sheet.visible and panel.draft == draft and panel.selected == selected, "Cancelled touch neither closes nor applies nor changes the current draft/source")
        _expect(clarity.router._pointer == -1, "Cancelled touch releases router ownership")
        _expect_unchanged(sim, baseline, files, "Cancelled touch")
    var apply_point := panel.apply_button.get_global_rect().get_center()
    _engine_touch(apply_point, true)
    clarity.router.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    _engine_touch(apply_point, false)
    await _settle()
    _expect(hud._sheet.visible and panel.draft == draft and clarity.router._pointer == -1, "Focus interruption preserves the session without committing held Apply")
    _expect_unchanged(sim, baseline, files, "Focus interruption")

    _engine_touch(apply_point, true)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = apply_point + Vector2(0, -12)
    drag.relative = Vector2(0, -12)
    Input.parse_input_event(drag)
    Input.flush_buffered_events()
    _engine_touch(drag.position, false)
    await _settle()
    _expect(hud._sheet.visible and panel.draft == draft and clarity.router._pointer == -1, "An Apply-origin drag never turns into a commit")
    _expect_unchanged(sim, baseline, files, "Apply-origin drag")

    # An old held Apply cannot commit after a new session starts, even with no
    # process frame between close and reopen (visibility signal, not polling).
    _engine_touch(apply_point, true)
    hud._sheet.visible = false
    hud._toggle_sheet()
    _engine_touch(apply_point, false)
    await _settle()
    _expect_fresh(clarity, "Interrupted Apply across immediate close/reopen")
    _expect_unchanged(sim, baseline, files, "Interrupted Apply across sessions")


func _tap_checked(button: Button, clarity: MobileInteractionClarity) -> void:
    _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button, "Actual touch target is reachable: %s" % button.text)
    _engine_tap(button)
    await _settle()


func _edit(clarity: MobileInteractionClarity) -> void:
    clarity.hud._mobile_scroll.scroll_vertical = 0
    await _settle()
    var before := clarity.staffing.draft.duplicate(true)
    await _tap_checked(clarity.staffing.cards["inbound"] as Button, clarity)
    await _tap_checked(clarity.staffing.cards["picking"] as Button, clarity)
    _expect(clarity.staffing.draft != before and not clarity.staffing.apply_button.disabled, "Engine-touch transfer produces an enabled uncommitted draft")


func _expect_fresh(clarity: MobileInteractionClarity, context: String) -> void:
    var panel := clarity.staffing
    _expect(clarity.hud._sheet.visible and clarity._section == "staffing", "%s shows staffing" % context)
    _expect(panel.draft == clarity.hud.sim.zone_staffing and panel.expected == clarity.hud.sim.zone_staffing, "%s resets to current authoritative assignments" % context)
    _expect(panel.selected.is_empty() and panel.apply_button.disabled, "%s has no selected source or pending Apply" % context)


func _expect_unchanged(sim: FlotraV2Sim, baseline: Dictionary, files: Dictionary, context: String) -> void:
    _expect(sim.save_data() == baseline, "%s leaves the entire authoritative save payload unchanged" % context)
    _expect(Fixture.snapshot() == files, "%s leaves save, backup, temporary and tutorial-marker bytes unchanged" % context)


func _capture_return_comparison(directory: String) -> void:
    # Opt-in rendered evidence only. The same file can be copied into an archive
    # of the baseline, so comparison uses identical fixtures and real gestures.
    if DisplayServer.get_name() == "headless" or not directory.is_absolute_path():
        _expect(false, "Capture requires a rendered display and an absolute output directory")
        return
    _expect(DirAccess.make_dir_recursive_absolute(directory) == OK, "Capture output directory is writable")
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    var results: Array[Dictionary] = []
    for dimensions in [Vector2i(375, 667), Vector2i(390, 844), Vector2i(430, 932)]:
        Fixture.clear()
        get_root().size = dimensions
        var app := MainScene.instantiate()
        get_root().add_child(app)
        app.set_process(false)
        var sim := app.get("sim") as FlotraV2Sim
        var hud: MobileGameHud
        for child in app.get_children():
            if child is MobileGameHud:
                hud = child
        _expect(hud != null, "Capture composes the actual-main mobile HUD")
        if hud == null:
            app.queue_free()
            await _settle()
            continue
        var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
        clarity.coach._persist_completion = false
        hud._ftue_coach._persist_completion = false
        sim.money = 100000
        sim.purchase_rank1_project(&"rack_wing")
        sim.purchase_rank1_project(&"forklift_project")
        sim.shipped = sim.EXPANSION_SHIPMENTS
        _expect(bool(sim.purchase_warehouse_expansion().get("ok", false)), "Capture fixture reaches Rank 2 through real expansion")
        _expect(sim.zone_staffing == {"inbound": 2, "picking": 2, "shipping": 1}, "Capture starts from authoritative 2/2/1")
        var store := app.get("save_store") as LogisticsSaveStore
        _expect(store.save_sim(sim), "Capture baseline save uses its disposable profile")
        var baseline := sim.save_data().duplicate(true)
        var files := Fixture.snapshot()
        await _settle()
        await _tap_checked(hud._manage_button, clarity)
        await _tap_checked(clarity._tabs["staffing"] as Button, clarity)
        await _edit(clarity)
        _expect(clarity.staffing.draft == {"inbound": 1, "picking": 3, "shipping": 1}, "Capture shows the same uncommitted 1/3/1 draft")
        results.append(await _capture_staffing_frame(directory, dimensions.x, "draft", clarity))
        await _tap_checked(hud._manage_button, clarity)
        _expect(not hud._sheet.visible, "Capture closes through the ordinary Management dock")
        await _tap_checked(hud._manage_button, clarity)
        _expect(hud._sheet.visible and clarity._section == "staffing", "Capture reopens staffing through the same ordinary dock")
        # Deliberately record rather than assert draft contents: the unchanged
        # baseline should reveal its stale draft and enabled Apply here.
        results.append(await _capture_staffing_frame(directory, dimensions.x, "reopened", clarity))
        _expect_unchanged(sim, baseline, files, "Captured draft and ordinary dock return")
        app.queue_free()
        await _settle()
    var report := {
        "engine": Engine.get_version_info(),
        "device": RenderingServer.get_video_adapter_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "scope": "Actual-main synthetic Rank 2 fixture, parsed touch with mouse emulation, isolated profile; native Linux render, not iPhone QA",
        "checks": _checks,
        "failures": _failures,
        "results": results,
    }
    var file := FileAccess.open(directory.path_join("staffing-return-capture.json"), FileAccess.WRITE)
    _expect(file != null, "Capture report is writable")
    if file != null:
        file.store_string(JSON.stringify(report, "  "))
        file.close()
    print("STAFFING_RETURN_CAPTURE_FINISHED frames=%d failures=%d" % [results.size(), _failures])


func _capture_staffing_frame(directory: String, width: int, phase: String, clarity: MobileInteractionClarity) -> Dictionary:
    await _settle()
    await RenderingServer.frame_post_draw
    var filename := "staffing-%d-%s.png" % [width, phase]
    _expect(get_root().get_texture().get_image().save_png(directory.path_join(filename)) == OK, "Save actual-main staffing frame %s" % filename)
    return {
        "file": filename,
        "width": width,
        "phase": phase,
        "draft": clarity.staffing.draft.duplicate(true),
        "expected": clarity.staffing.expected.duplicate(true),
        "authoritative": clarity.hud.sim.zone_staffing.duplicate(true),
        "selected": clarity.staffing.selected,
        "apply_disabled": clarity.staffing.apply_button.disabled,
    }
