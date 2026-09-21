extends "res://tests/mobile_notification_clearance_smoke.gd"

func _run() -> void:
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    for dimensions in [Vector2i(390,844), Vector2i(375,667), Vector2i(430,932)]:
        get_root().size = dimensions
        var c: Dictionary = await _fresh()
        var sim: FlotraV2Sim = c["sim"]
        var hud: MobileGameHud = c["hud"]
        var zone: WarehouseZonePanel = c["zone"]
        var clarity: MobileInteractionClarity = c["clarity"]
        _expect(hud._v2_growth_goal.text.contains("設備"), "Fresh objective leads to growth, not paperwork")
        _engine_tap(hud._v2_growth_goal)
        await _settle()
        _expect(hud._sheet.visible and clarity._section == "field", "Growth CTA opens real field tab")
        _engine_tap(hud._v2_zone_nav_buttons["inbound"])
        await _settle()
        var before := sim.money
        _engine_tap(zone._capital_action)
        await _settle()
        _expect(sim.money == before and zone.preview_kind() == &"forklift_project", "First fork preview doesn't spend")
        _engine_tap(zone._capital_action)
        await _settle()
        _expect(sim.forklift_unlocked and not zone.is_open(), "Paid fork action reveals the warehouse")
        sim.purchase_rank1_project(&"rack_wing")
        sim.shipped = sim.EXPANSION_SHIPMENTS # Explicit UI boundary fixture only.
        await _settle()
        _engine_tap(hud._v2_growth_goal)
        await _settle()
        _expect(clarity._section == "expansion" and not hud._v2_rank1_expansion_button.disabled, "Ready growth route exposes expansion without spending")
        before = sim.money
        _engine_tap(hud._v2_rank1_expansion_button)
        await _settle()
        _expect(sim.facility_rank == 2 and sim.money == before - sim.WAREHOUSE_EXPANSION_COST, "Touch expands exactly once")
        for key in ["inbound", "picking"]:
            zone.open_zone(key)
            await _settle()
            var kind := sim.growth_automation_for_zone(key)
            var button := zone._automation_action
            _expect(button.is_visible_in_tree() and not button.disabled, "Working automation has a visible action")
            _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button, "New machine action is actually on screen and clipped correctly")
            before = sim.money
            _engine_tap(button)
            await _settle()
            _expect(sim.money == before and zone.preview_kind() == kind, "Automation first touch is only preview")
            _engine_tap(button)
            await _settle()
            _expect(bool(sim.growth_automation_info(kind)["owned"]) and not zone.is_open(), "Automation commit changes ownership and reveals work")
        _expect(hud._v2_growth_goal.text.contains("2台"), "Actual fleet size becomes visible")
        var feedback: Dictionary = hud.measurement_feedback({"kind":"transfer_conveyor", "overlapping_changes":1, "before":{}, "after":{}})
        _expect(String(feedback["text"]).contains("搬送コンベア") and String(feedback["text"]).contains("複数変更"), "Result identifies equipment and overlapping investments")
        hud.queue_free()
        await _settle()
    print("Growth UI engine-touch checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)
