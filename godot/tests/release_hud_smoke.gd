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

    if hud._sheet.anchor_top > 0.34:
        _fail("mobile management sheet must use more vertical screen area to reduce excessive scrolling")
        return
    if not hud._sheet.clip_contents:
        _fail("mobile management sheet must clip descendants instead of overflowing the viewport")
        return

    var scroll := _find_scroll(hud._sheet)
    if scroll == null:
        _fail("mobile management sheet must contain a vertical ScrollContainer")
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

    if hud._contract_buttons.is_empty():
        _fail("release HUD must build contract controls")
        return
    var contract_button: Button = hud._contract_buttons[0]
    if contract_button.mouse_filter != Control.MOUSE_FILTER_PASS:
        _fail("management buttons must pass touch drags to the ScrollContainer")
        return
    if contract_button.autowrap_mode == TextServer.AUTOWRAP_OFF or not contract_button.clip_text:
        _fail("management button copy must wrap within the available mobile width")
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
