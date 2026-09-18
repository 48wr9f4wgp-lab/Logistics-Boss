extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")
const AnalyticsScript = preload("res://telemetry/analytics_service.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = SimScript.new()
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame

    if hud.current_ftue_step() != "observe":
        _fail("fresh release HUD must expose current FTUE step")
        return

    var brand := hud._find_brand_strip()
    if brand == null or brand.offset_bottom > 34.0:
        _fail("release brand strip must stay compact so the warehouse remains the visual hero")
        return

    var metrics := hud._find_metric_row()
    if metrics == null or metrics.offset_bottom > 88.0:
        _fail("release metric row must stay within the compact top command area")
        return
    for metric in metrics.get_children():
        if metric is PanelContainer and (metric as PanelContainer).custom_minimum_size.y > 50.0:
            _fail("release metric cards must not force the top command area back to prototype height")
            return

    if hud._bottleneck_panel == null or hud._bottleneck_panel.offset_bottom > 124.0:
        _fail("release bottleneck director must end before the compact status band")
        return
    if hud._ftue_coach == null:
        _fail("fresh release HUD must build the FTUE coach")
        return
    if hud._ftue_coach.offset_top < hud._bottleneck_panel.offset_bottom + 4.0:
        _fail("FTUE coach must not overlap the always-on bottleneck director")
        return
    if hud._ftue_coach.offset_bottom > 214.0:
        _fail("FTUE coach must remain above the mobile Management sheet start")
        return
    if hud._wave_panel == null or hud._wave_panel.offset_top < hud._bottleneck_panel.offset_bottom + 4.0:
        _fail("workload wave banner must use the compact status band below the permanent HUD")
        return
    if hud._wave_panel.visible:
        _fail("workload wave banner must yield to active fresh-save onboarding")
        return

    if hud._sheet.anchor_top > 0.27:
        _fail("mobile management sheet must use enough vertical screen area for touch navigation")
        return
    if not hud._sheet.clip_contents:
        _fail("mobile management sheet must clip descendants instead of overflowing the viewport")
        return

    var scroll := _find_scroll(hud._sheet)
    if scroll == null:
        _fail("mobile management sheet must contain a vertical ScrollContainer")
        return
    if hud._mobile_scroll != scroll:
        _fail("mobile HUD must retain the active management ScrollContainer for direct touch scrolling")
        return
    if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        _fail("mobile management sheet must never scroll or overflow horizontally")
        return
    if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
        _fail("mobile management sheet should use touch swipe without a narrow persistent scrollbar")
        return
    if scroll.scroll_hint_mode != ScrollContainer.SCROLL_HINT_MODE_ALL:
        _fail("mobile management sheet must hint that more content is available vertically")
        return
    if scroll.scroll_deadzone > int(MobileGameHud.MOBILE_SCROLL_DRAG_THRESHOLD):
        _fail("management touch deadzone must stay low enough to feel responsive")
        return

    var list := hud._find_upgrade_list(hud._sheet)
    if list == null or list.get_node_or_null("MobileBottomSpacer") == null:
        _fail("mobile management content must include bottom padding so the last action remains reachable")
        return
    if hud._reset_button == null or not hud._reset_button.text.contains("リセット"):
        _fail("management sheet must expose the confirmed test-data reset control")
        return
    if hud._reset_dialog == null:
        _fail("test-data reset must require a confirmation dialog")
        return

    hud._sheet.visible = true
    await process_frame
    if scroll.get_v_scroll_bar().max_value <= scroll.size.y:
        _fail("management content must exceed the viewport so scrolling is meaningful")
        return

    scroll.scroll_vertical = 0
    var touch := InputEventScreenTouch.new()
    touch.index = 7
    touch.position = scroll.get_global_rect().get_center()
    touch.pressed = true
    hud._input(touch)

    var drag := InputEventScreenDrag.new()
    drag.index = 7
    drag.position = touch.position + Vector2(0, -120)
    drag.relative = Vector2(0, -120)
    hud._input(drag)
    if scroll.scroll_vertical <= 0:
        _fail("upward touch drag must advance the management ScrollContainer")
        return

    var release := InputEventScreenTouch.new()
    release.index = 7
    release.position = drag.position
    release.pressed = false
    hud._input(release)
    if hud._mobile_scroll_touch_index != -1:
        _fail("management scroll touch state must reset on release")
        return

    if hud._contract_buttons.is_empty():
        _fail("release HUD must build contract controls")
        return
    var contract_button: Button = hud._contract_buttons[0]
    if contract_button.mouse_filter != Control.MOUSE_FILTER_PASS:
        _fail("management buttons must pass touch drags to the ScrollContainer")
        return
    if contract_button.autowrap_mode == TextServer.AUTOWRAP_OFF:
        _fail("management button copy must wrap within the available mobile width")
        return
    if contract_button.clip_text:
        _fail("wrapped management copy must remain fully readable instead of being clipped")
        return
    if contract_button.custom_minimum_size.y < 88.0:
        _fail("contract controls must reserve enough height for wrapped mobile copy")
        return

    if hud._receiving_annex_button == null or hud._receiving_annex_button.custom_minimum_size.y < 84.0:
        _fail("Rank 3 investment controls must reserve enough vertical space for multi-line copy")
        return

    var analytics: LogisticsAnalytics = AnalyticsScript.new()
    get_root().add_child(analytics)
    analytics.bind_sim(sim)
    analytics.clear_buffer()
    analytics.bind_hud(hud)
    if String(analytics.latest_event().get("name", "")) != "ftue_step":
        _fail("late analytics bind must capture active FTUE step")
        return
    var payload: Dictionary = analytics.latest_event().get("payload", {})
    if String(payload.get("step", "")) != "observe":
        _fail("FTUE telemetry must report observe step")
        return

    sim.inbound_queue = 10
    hud._render()
    if not hud._bottleneck.text.contains("受入"):
        _fail("release bottleneck director must include a concrete inbound action")
        return

    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0
    hud._render()
    if hud._bottleneck.text != "安定運転":
        _fail("stable flow must remain visually quiet")
        return

    analytics.queue_free()
    hud.queue_free()
    await process_frame
    print("Godot release HUD smoke passed")
    quit(0)


func _find_scroll(node: Node) -> ScrollContainer:
    if node is ScrollContainer:
        return node as ScrollContainer
    for child in node.get_children():
        var found := _find_scroll(child)
        if found != null:
            return found
    return null
