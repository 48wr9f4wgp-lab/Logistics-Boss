extends "res://tests/mobile_engine_touch_smoke.gd"

# UI fixtures exercise the real composed HUD and Input's emulation stage.
# Captures use main.tscn, not a design mockup. No human-device PASS is implied.
func _run() -> void:
    if not OS.get_environment("FLOTRA_NOTICE_CAPTURE_DIR").is_empty():
        await _capture_main()
        return
    var old_mouse := Input.emulate_mouse_from_touch
    var old_touch := Input.emulate_touch_from_mouse
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    for viewport_size in [Vector2i(390, 844), Vector2i(375, 667), Vector2i(430, 932)]:
        get_root().size = viewport_size
        await _verify_clearance()
    Input.emulate_mouse_from_touch = old_mouse
    Input.emulate_touch_from_mouse = old_touch
    print("Notification clearance checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)


func _verify_clearance() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var zone: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    hud._on_sim_event({"type": "shipment", "value": 500})
    hud._flush_shipment_toast()
    _expect(hud._toast_panel.visible, "Warehouse still shows ordinary shipment feedback")

    clarity.open_section("expansion")
    await _settle()
    _expect(not hud._toast_panel.visible, "Opening Management must clear an already visible shipment toast")
    hud._on_sim_event({"type": "shipment", "value": 500})
    hud._flush_shipment_toast()
    hud._process(2.0)
    _expect(not hud._toast_panel.visible, "Shipment popup must not cover the Management tabs")
    _expect(hud._shipment_toast_count == 0 and hud._shipment_toast_value == 0, "Hidden shipments must not accumulate a replay backlog")

    # Timers below are presentation time only. Domain must continue to earn cash.
    var reference: FlotraV2Sim = SimScript.new()
    reference.money = 100000
    for _index in 3:
        reference.step(1.0)
    var initial_shipped := sim.shipped
    for _index in 240:
        sim.step(0.25)
        reference.step(0.25)
        hud._process(0.25)
    _expect(sim.shipped > initial_shipped, "Suppressing popups must not stop shipments")
    _expect(sim.money == reference.money and sim.shipped == reference.shipped, "Popup policy must not alter earned money or logistics")
    _expect(hud._money.text == "¥%s" % hud._format_number(sim.money), "Cash HUD must still update while Management is open")

    # Reported obstruction must remain absent during genuine repeated tab taps.
    for section in ["contracts", "field", "expansion"]:
        var tab := clarity._tabs[section] as Button
        _engine_tap(tab)
        await _settle()
        _expect(clarity._section == section, "Engine-parsed tab tap remains usable during shipments")
        _expect(not hud._toast_panel.visible, "No popup may reappear over a selected tab")

    hud._show_toast("契約達成  +¥2,500 / 評価+2")
    hud._show_measurement_status("投資効果  出荷5→8/分", 10.0)
    var toast_time := hud._toast_timer
    var measure_time := hud._measurement_timer
    hud._process(4.0)
    _expect(not hud._toast_panel.visible and not hud._measurement_panel.visible, "Important feedback must wait rather than cover controls")
    _expect(is_equal_approx(hud._toast_timer, toast_time), "Deferred result must retain its visible reading time")
    _expect(is_equal_approx(hud._measurement_timer, measure_time), "Deferred measurement must retain its visible reading time")
    _engine_tap(hud._manage_button)
    await _settle()
    _expect(not hud._sheet.visible, "Closing Management must still work with deferred feedback")
    _expect(hud._toast_panel.visible and hud._toast.text.begins_with("契約達成"), "Closing Management must show the actual important result, not shipment spam")
    _expect(hud._measurement_panel.visible, "Deferred measurement returns to warehouse observation")
    hud._process(12.0)
    _expect(not hud._toast_panel.visible and not hud._measurement_panel.visible, "Feedback expires once; no hidden shipment replay")

    zone.open_zone("storage")
    await _settle()
    hud._show_toast("出荷 +¥500", false)
    hud._process(2.0)
    _expect(not hud._toast_panel.visible, "Zone purchase controls must remain unobstructed")
    hud._show_toast("設備の購入完了")
    hud._show_measurement_status("拡張効果を計測中", 10.0)
    hud._process(4.0)
    _expect(not hud._toast_panel.visible and not hud._measurement_panel.visible, "Zone panel must also defer important overlays")
    _engine_tap(zone._close_button)
    await _settle()
    _expect(not zone.is_open() and hud._toast_panel.visible, "Zone close restores deferred feedback without changing input ownership")

    # Confirmation is displayed and cancelled only; never emit a reset action.
    hud._request_reset_confirmation()
    hud._show_toast("契約達成")
    hud._process(3.0)
    _expect(not hud._toast_panel.visible and not hud._measurement_panel.visible, "Reset confirmation must not be covered by feedback")
    hud._cancel_reset_confirmation()
    hud._process(0.0)
    _expect(hud._toast_panel.visible, "Cancelling reset restores the pending important result")
    for control in [hud._toast_panel, hud._toast, hud._measurement_panel, hud._measurement_label]:
        _expect(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Passive feedback must never intercept taps")
    hud.queue_free()
    await _settle()


func _capture_main() -> void:
    get_root().size = Vector2i(390, 844)
    var main := load("res://scenes/main.tscn").instantiate() as Node
    get_root().add_child(main)
    # Keep this diagnostic capture independent of autosave or elapsed wall time.
    main.set_process(false)
    var sim: FlotraV2Sim = main.get("sim")
    sim.money = 7500
    var hud: MobileGameHud
    for child in main.get_children():
        if child is MobileGameHud:
            hud = child as MobileGameHud
            break
    if hud == null:
        _expect(false, "Actual main must contain the mobile HUD")
        quit(1)
        return
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.open_section("expansion")
    await _settle()
    hud._on_sim_event({"type": "shipment", "value": 500})
    hud._flush_shipment_toast()
    hud._process(0.0)
    await _settle()
    _expect(not hud._toast_panel.visible, "Actual main expansion tabs must be clear during shipment")
    var directory := OS.get_environment("FLOTRA_NOTICE_CAPTURE_DIR")
    DirAccess.make_dir_recursive_absolute(directory)
    await RenderingServer.frame_post_draw
    var result := get_root().get_texture().get_image().save_png(directory.path_join("notification_management_clear.png"))
    _expect(result == OK, "Save actual-main notification clearance capture")
    main.queue_free()
    await _settle()
    print("Actual-main notification capture finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)
