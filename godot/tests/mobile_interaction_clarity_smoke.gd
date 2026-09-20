extends SceneTree

const SimScript := preload("res://domain/flotra_v2_sim.gd")
const HudScript := preload("res://ui/game_hud_mobile.gd")
const ZoneScript := preload("res://ui/warehouse_zone_panel.gd")
const ClarityScript := preload("res://ui/mobile_interaction_clarity.gd")
const ResumeScript := preload("res://ui/session_resume_brief.gd")
const FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")

var _failures := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    get_root().size = Vector2i(390, 844)
    await _verify_goal_and_contract()
    await _verify_drag_cancel_and_clipping()
    await _verify_zone_purchase()
    await _verify_rank2_actions()
    print("Mobile interaction clarity checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)


func _expect(value: bool, message: String) -> void:
    if not value:
        _failures += 1
        push_error(message)


func _fresh() -> Dictionary:
    var sim: FlotraV2Sim = SimScript.new()
    # Deliberate UI fixture, not natural-progression evidence.
    sim.money = 100000
    for _index in 3:
        sim.step(1.0)
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    var zone: WarehouseZonePanel = ZoneScript.new()
    hud.add_child(zone)
    zone.bind_sim(sim)
    hud.zone_navigation_requested.connect(zone.open_zone)
    hud._manage_button.pressed.connect(zone.close)
    var clarity: MobileInteractionClarity = ClarityScript.new()
    hud.add_child(clarity)
    clarity.bind(hud, zone)
    await _settle()
    _expect(not hud.is_processing_input() and not zone.is_processing_input(), "Composed scene must have one raw UI router")
    return {"sim": sim, "hud": hud, "zone": zone, "clarity": clarity}


func _verify_goal_and_contract() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var zone: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    for kind in [&"rack_wing", &"second_packing_bench", &"worker_hire", &"forklift_project"]:
        var result: Dictionary = sim.purchase_rank1_project(kind)
        _expect(bool(result.get("ok", false)), "Completed-equipment fixture must use real purchase API")
    sim.logistics_rating = 0
    await _settle()
    _expect(hud._v2_growth_goal.text.contains("契約を選ぶ"), "Projects4/4 rating0 must lead to contracts")
    _expect(hud._v2_growth_goal.text.contains("導入済み"), "Goal must explain that equipment is already complete")

    var resume: LogisticsSessionResumeBrief = ResumeScript.new()
    hud.add_child(resume)
    resume.bind(sim, true)
    await _settle()
    _expect(resume._label.get_theme_font("font") == FONT, "Late-added resume Japanese must use bundled font")
    _expect(not resume.get_global_rect().intersects(hud._v2_growth_goal.get_global_rect()), "Resume and main action must not overlap")
    resume.visible = false

    var goal := hud._v2_growth_goal
    var point := goal.get_global_rect().get_center()
    _expect(clarity.router.button_at(point) == goal, "Goal must be visibly hittable")
    _touch(point, true)
    await _settle()
    _expect(clarity.router.is_pressing(goal), "ScreenTouch down must retain a visible pressed state")
    _expect(goal.get_theme_stylebox("normal") == goal.get_theme_stylebox("pressed"), "Raw touch must show pressed styling")
    _touch(point, false)
    await _settle()
    _expect(hud._sheet.visible and hud._progression_panel.visible, "Goal must open the contract section directly")
    _expect(not hud._v2_overview_panel.visible, "Contract section must not bury field navigation beneath offers")
    _expect((clarity._tabs["field"] as Button).is_visible_in_tree(), "Field tab must remain visible outside scroll")
    _tap(clarity._tabs["field"] as Button)
    await _settle()
    _expect(hud._v2_overview_panel.visible and not hud._progression_panel.visible, "Field tab touch must switch visible content")
    _tap(hud._v2_zone_nav_buttons["storage"] as Button)
    await _settle()
    _expect(zone.is_open() and zone.selected_zone() == "storage" and not hud._sheet.visible, "Field route must open actual Zone Panel")
    _expect(not zone._capital_action.visible and not zone._operations_action.visible, "Installed equipment/staff must not remain fake purchase buttons")
    _expect(zone._capital.text.contains("導入済み"), "Installed state must explain why there is no purchase")
    zone.close()
    clarity.open_section("contracts")
    await _settle()

    var first := hud._contract_buttons[0]
    _expect(first.text == "この契約を開始 ▶", "Contract descriptions and start action must be separate")
    _expect(clarity._descriptions[0].mouse_filter == Control.MOUSE_FILTER_IGNORE, "Contract description must not pretend to be an action")
    var count := {"value": 0}
    first.pressed.connect(func(): count["value"] = int(count["value"]) + 1)
    var contract_point := first.get_global_rect().get_center()
    _expect(clarity.router.button_at(contract_point) == first, "First contract action must be visible without scrolling")
    _touch(contract_point, true)
    await create_timer(0.55).timeout
    _mouse(contract_point, true)
    _mouse(contract_point, false)
    _expect(sim.active_contract.is_empty(), "Synthetic mouse during a long-held touch must not accept early")
    _touch(contract_point, false)
    _mouse(contract_point, true)
    _mouse(contract_point, false)
    await _settle()
    _expect(int(count["value"]) == 1, "Touch plus synthetic mouse must activate once")
    _expect(not sim.active_contract.is_empty(), "Contract button must change authoritative active contract")
    _expect(not hud._sheet.visible, "Accepted contract must return to warehouse observation")
    _expect(hud._v2_growth_goal.text.contains("進行中"), "Accepted contract must have persistent progress feedback")

    sim.active_contract.clear()
    sim.logistics_rating = 8
    await _settle()
    var before := sim.money
    _tap(hud._v2_growth_goal)
    await _settle()
    _expect(sim.money == before and sim.facility_rank == 1, "Ready CTA must open expansion, not spend silently")
    _expect(hud._v2_rank1_expansion_panel.visible, "Ready CTA must select the expansion section")
    hud.queue_free()
    await _settle()


func _verify_drag_cancel_and_clipping() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var clarity: MobileInteractionClarity = context["clarity"]
    clarity.open_section("contracts")
    await _settle()
    var button := hud._contract_buttons[0]
    var point := button.get_global_rect().get_center()
    _touch(point, true)
    _touch(point, false, true)
    await _settle()
    _expect(sim.active_contract.is_empty(), "Cancelled touch must not accept a contract")

    _touch(point, true, false, 0)
    _touch(point, true, false, 1)
    _touch(point, false, false, 0)
    _touch(point, false, false, 1)
    await _settle()
    _expect(sim.active_contract.is_empty(), "Multitouch must cancel a UI tap")

    var start_scroll := hud._mobile_scroll.scroll_vertical
    _touch(point, true)
    var drag := InputEventScreenDrag.new()
    drag.index = 0
    drag.position = point + Vector2(0, -12)
    drag.relative = Vector2(0, -12)
    get_root().push_input(drag, true)
    _touch(drag.position, false)
    await _settle()
    _expect(hud._mobile_scroll.scroll_vertical > start_scroll, "Dragging from a button must scroll")
    _expect(sim.active_contract.is_empty(), "A scroll-sized 12px gesture must never also activate")

    # The shortened contract cards can fit almost entirely in the viewport.
    # Add fixture-only overflow, then place the first button above the scroll
    # clip but still inside the viewport. Do not assume max-scroll hides it.
    var overflow := Control.new()
    overflow.custom_minimum_size.y = 400.0
    hud._find_upgrade_list(hud._sheet).add_child(overflow)
    await _settle()
    var scroll_top := hud._mobile_scroll.get_global_rect().position.y
    var needed := button.get_global_rect().get_center().y - scroll_top + 12.0
    hud._mobile_scroll.scroll_vertical += ceili(needed)
    await _settle()
    var clipped_point := button.get_global_rect().get_center()
    print("Clip fixture: point=%s scroll=%s offset=%d" % [str(clipped_point), str(hud._mobile_scroll.get_global_rect()), hud._mobile_scroll.scroll_vertical])
    _expect(get_root().get_visible_rect().has_point(clipped_point), "Clip fixture must remain inside viewport")
    _expect(not hud._mobile_scroll.get_global_rect().has_point(clipped_point), "Clip fixture must actually be clipped")
    _expect(clarity.router.button_at(clipped_point) != button, "Clipped buttons must not be raw-touch targets")
    overflow.queue_free()
    hud._mobile_scroll.scroll_vertical = 0
    await _settle()
    point = button.get_global_rect().get_center()
    _touch(point, true)
    sim.contract_offers.reverse()
    _touch(point, false)
    await _settle()
    _expect(sim.active_contract.is_empty(), "An offer changing under a held finger must cancel acceptance")
    hud.queue_free()
    await _settle()


func _verify_zone_purchase() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var zone: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    zone.open_zone("storage")
    await _settle()
    var button := zone._capital_action
    _expect(button.text.contains("配置を確認"), "Unowned equipment must offer preview, not ambiguous CAPITAL")
    _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button, "Zone purchase action must be on-screen and hittable")
    var before := sim.money
    _tap(button)
    await _settle()
    _expect(sim.money == before and zone.preview_kind() == &"rack_wing", "First equipment tap must preview without spending")
    _expect(button.text.contains("建設する"), "Preview must visibly become an explicit build action")
    _tap(button)
    await _settle()
    _expect(sim.money < before and sim.rank1_project_owned(&"rack_wing"), "Second gesture must perform authoritative construction")
    _expect(not button.visible and zone._capital.text.contains("導入済み"), "Successful construction must become installed status")
    hud.queue_free()
    await _settle()


func _verify_rank2_actions() -> void:
    var context: Dictionary = await _fresh()
    var sim: FlotraV2Sim = context["sim"]
    var hud: MobileGameHud = context["hud"]
    var zone: WarehouseZonePanel = context["zone"]
    var clarity: MobileInteractionClarity = context["clarity"]
    sim.money = 1000000
    for kind in [&"rack_wing", &"second_packing_bench", &"worker_hire", &"forklift_project"]:
        sim.purchase_rank1_project(kind)
    sim.logistics_rating = 8
    var expansion: Dictionary = sim.purchase_warehouse_expansion()
    _expect(bool(expansion.get("ok", false)), "Rank2 fixture expansion must succeed")
    for zone_key in ["storage", "packing"]:
        zone.open_zone(zone_key)
        await _settle()
        for button in zone._rank2_capital_buttons:
            var kind := StringName(button.get_meta("kind", ""))
            var money_before := sim.money
            _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button, "Rank2 equipment must be visibly hittable: %s" % String(kind))
            _tap(button)
            await _settle()
            _expect(sim.money == money_before and zone.preview_kind() == kind, "Rank2 first tap must preview without spend")
            _tap(button)
            await _settle()
            var info: Dictionary = sim.rank2_v2_equipment_action_info(kind)
            _expect(bool(info.get("active", false)) and sim.money < money_before, "Rank2 build/renovation must apply once")
    zone.open_zone("shipping")
    await _settle()
    var before: Dictionary = sim.direct_staffing_summary()
    _tap(zone._staffing_move_buttons[0])
    await _settle()
    var after: Dictionary = sim.direct_staffing_summary()
    _expect(int(after.get("shipping", 0)) == int(before.get("shipping", 0)) + 1, "Rank2 staffing touch must move one worker")
    hud.queue_free()
    await _settle()


func _tap(button: Button) -> void:
    var point := button.get_global_rect().get_center()
    _touch(point, true)
    _touch(point, false)


func _touch(position: Vector2, pressed: bool, cancelled: bool = false, index: int = 0) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = position
    event.pressed = pressed
    event.canceled = cancelled
    get_root().push_input(event, true)


func _mouse(position: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.position = position
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    get_root().push_input(event, true)


func _settle() -> void:
    for _index in 4:
        await process_frame
