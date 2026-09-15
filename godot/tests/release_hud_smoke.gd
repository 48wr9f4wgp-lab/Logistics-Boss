extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const HudScript = preload("res://ui/game_hud_release.gd")
const AnalyticsScript = preload("res://telemetry/analytics_service.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = SimScript.new()
    var hud: ReleaseGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame

    if hud.current_ftue_step() != "observe":
        _fail("fresh release HUD must expose current FTUE step")
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
