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

    if not hud.current_ftue_step().is_empty():
        _fail("v2 mobile path must not expose the legacy Management-first FTUE")
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
    if hud._rp == null or hud._rp.get_parent() == null or hud._rp.get_parent().get_parent() is not PanelContainer:
        _fail("v2 mobile HUD must retain a controllable RP metric container")
        return
    if (hud._rp.get_parent().get_parent() as PanelContainer).visible:
        _fail("RP must be hidden from the primary v2 HUD until it has a clear decision role")
        return

    if hud._bottleneck_panel == null or hud._bottleneck_panel.offset_bottom > 124.0:
        _fail("release bottleneck director must end before the compact status band")
        return
    if hud._ftue_coach == null:
        _fail("mobile HUD must retain the legacy FTUE node for compatibility until Rank 1 v2 replaces it")
        return
    if hud._ftue_coach.visible:
        _fail("v2 mobile path must keep the legacy Management-first FTUE hidden")
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

    var dock := hud._find_bottom_dock()
    if dock == null or dock.offset_bottom - dock.offset_top > 70.0:
        _fail("bottom command dock must stay compact so warehouse growth remains the visual hero")
        return
    if hud._measurement_panel == null or hud._measurement_panel.offset_bottom - hud._measurement_panel.offset_top > 56.0:
        _fail("measurement feedback must not consume excessive portrait height")
        return

    var feedback := hud.measurement_feedback({
        "before": {"shipments_per_min": 21.6, "packing_queue": 7.8},
        "after": {"shipments_per_min": 26.4, "packing_queue": 1.4},
        "verdict": {"state": "improved", "headline": "改善", "delta": 4.8, "threshold": 1.0},
    })
    var feedback_text := String(feedback.get("text", ""))
    if feedback_text.count("\n") != 2:
        _fail("measurement feedback must stay within three compact lines including investment identity")
        return
    if not feedback_text.contains("改善 ↑ +4.8/分"):
        _fail("measurement feedback must front-load the improvement result")
        return

    sim.facility_rank = 2
    var inline_wave := hud._inline_wave_summary()
    if inline_wave.is_empty():
        _fail("Rank 2 workload forecast must remain available in the compact bottleneck director")
        return
    hud._sync_release_overlay_visibility()
    if hud._wave_panel.visible:
        _fail("normal Rank 2/3 play must fold workload forecast into the bottleneck director instead of a second panel")
        return
    sim.facility_rank = 1

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
    if hud._v2_overview_panel == null or not hud._v2_overview_panel.visible:
        _fail("v2 Management must expose an executive Overview instead of an equipment-store landing page")
        return
    for legacy_button in hud._upgrade_buttons.values():
        if (legacy_button as Button).visible:
            _fail("normal legacy upgrades must not remain player-facing in v2 Management")
            return
    for facility_button in hud._facility_buttons.values():
        if (facility_button as Button).visible:
            _fail("Rank 2 Zone equipment must not be purchased from v2 Management")
            return
    if hud._reset_button == null or not hud._reset_button.text.contains("リセット"):
        _fail("management sheet must expose the confirmed test-data reset control")
        return
    if hud._reset_modal == null or hud._reset_modal_panel == null:
        _fail("test-data reset must use an in-HUD confirmation modal")
        return
    if hud._reset_modal.get_parent() != hud:
        _fail("reset confirmation must stay inside the HUD canvas instead of using a separate Window")
        return
    if hud._reset_modal.visible:
        _fail("reset confirmation modal must start hidden")
        return
    if hud._reset_modal.z_index < 100:
        _fail("reset confirmation modal must render above normal HUD surfaces")
        return
    if not is_equal_approx(hud._reset_modal_panel.offset_right - hud._reset_modal_panel.offset_left, 330.0):
        _fail("reset confirmation panel must stay within the 390px portrait reference width")
        return
    if not is_equal_approx(hud._reset_modal_panel.offset_bottom - hud._reset_modal_panel.offset_top, 264.0):
        _fail("reset confirmation panel must use the compact mobile height")
        return
    if not hud._reset_confirm_button.has_theme_font_override("font"):
        _fail("reset modal controls must inherit the embedded Japanese UI font")
        return
    if hud._reset_cancel_button.text != "キャンセル" or hud._reset_confirm_button.text != "リセット":
        _fail("reset modal actions must remain explicit and readable")
        return

    hud._queue_shipment_toast({"value": 500, "count": 1})
    hud._queue_shipment_toast({"value": 500, "count": 1})
    hud._queue_shipment_toast({"value": 500, "count": 1})
    if hud._shipment_toast_count != 3 or hud._shipment_toast_value != 1500:
        _fail("shipment toast batching must accumulate authoritative shipment count and value")
        return
    hud._shipment_toast_batch_elapsed = GameHud.SHIPMENT_TOAST_BATCH_SECONDS
    hud._flush_shipment_toast()
    if hud._earnings_caption.text != "資金  +¥1,500":
        _fail("shipment batching must present the exact cash-metric aggregate")
        return
    if hud._shipment_toast_count != 0 or hud._shipment_toast_value != 0:
        _fail("shipment toast batch must clear after display")
        return

    hud._show_toast("重要通知")
    hud._queue_shipment_toast({"value": 500, "count": 1})
    hud._shipment_toast_batch_elapsed = GameHud.SHIPMENT_TOAST_BATCH_SECONDS
    hud._flush_shipment_toast()
    if hud._toast.text != "重要通知" or hud._shipment_toast_count != 1:
        _fail("shipment toast must not overwrite higher-priority feedback")
        return
    hud._priority_toast_timer = 0.0
    hud._flush_shipment_toast()
    if hud._earnings_caption.text != "資金  +¥500" or hud._toast.text != "重要通知":
        _fail("deferred ordinary income goes to cash without overwriting important feedback")
        return

    hud._toast_panel.visible = false
    hud._toast_timer = 0.0

    hud._sheet.visible = true
    await process_frame
    if scroll.get_v_scroll_bar().max_value <= scroll.size.y:
        _fail("management content must exceed the viewport so scrolling is meaningful")
        return

    scroll.scroll_vertical = 0
    hud._request_reset_confirmation()
    if not hud._reset_modal.visible:
        _fail("reset button flow must open the in-HUD confirmation modal")
        return

    var blocked_touch := InputEventScreenTouch.new()
    blocked_touch.index = 6
    blocked_touch.position = scroll.get_global_rect().get_center()
    blocked_touch.pressed = true
    hud._input(blocked_touch)

    var blocked_drag := InputEventScreenDrag.new()
    blocked_drag.index = 6
    blocked_drag.position = blocked_touch.position + Vector2(0, -120)
    blocked_drag.relative = Vector2(0, -120)
    hud._input(blocked_drag)
    if scroll.scroll_vertical != 0:
        _fail("reset confirmation modal must block management scrolling behind it")
        return

    hud._cancel_reset_confirmation()
    if hud._reset_modal.visible:
        _fail("reset confirmation cancel must close the modal")
        return

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
    if contract_button.mouse_filter != Control.MOUSE_FILTER_STOP:
        _fail("management buttons must own taps; global mobile drag handling preserves scrolling")
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
    if String(analytics.latest_event().get("name", "")) == "ftue_step":
        _fail("v2 mobile path must not report the superseded Management-first FTUE as active")
        return

    sim.inbound_queue = 10
    hud._render()
    if not hud._bottleneck.text.contains("入荷") or not hud._bottleneck.text.contains("待機 10"):
        _fail("v2 Director must report the inbound symptom with concrete evidence")
        return
    if hud._bottleneck.text.contains("強化") or hud._bottleneck.text.contains("→"):
        _fail("v2 Director must not prescribe the equipment/action answer")
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
