extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const AnalyticsScript = preload("res://telemetry/analytics_service.gd")
const HealthScript = preload("res://telemetry/runtime_health.gd")
const GameFeelScript = preload("res://feedback/game_feel.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var host := Node.new()
    get_root().add_child(host)
    var sim = SimScript.new()

    var analytics: LogisticsAnalytics = AnalyticsScript.new()
    host.add_child(analytics)
    analytics.bind_sim(sim)

    var health: LogisticsRuntimeHealth = HealthScript.new()
    host.add_child(health)
    health.record_sample(60.0)
    health.record_sample(20.0)
    var health_snapshot := health.snapshot()
    if int(health_snapshot.get("samples", 0)) != 2:
        _fail("runtime health must record samples")
        return
    if float(health_snapshot.get("minimum_fps", 0.0)) != 20.0:
        _fail("runtime health must retain minimum FPS")
        return
    if float(health_snapshot.get("low_fps_ratio", 0.0)) < 0.49:
        _fail("runtime health must track sustained low-FPS samples")
        return

    var game_feel: LogisticsGameFeel = GameFeelScript.new()
    host.add_child(game_feel)
    await process_frame
    game_feel.bind_sim(sim)

    sim.set_policy(WarehouseSim.Policy.INBOUND)
    if String(analytics.latest_event().get("name", "")) != "operation_policy_changed":
        _fail("analytics must translate authoritative simulation events")
        return
    if game_feel.feedback_count <= 0:
        _fail("game feel must react to authoritative simulation events")
        return

    var tone: AudioStreamWAV = game_feel._build_tone([440.0, 660.0], 0.03, 0.10)
    if tone == null or tone.data.is_empty():
        _fail("procedural feedback audio must produce a valid stream")
        return

    host.queue_free()
    await process_frame
    print("Godot release services smoke passed")
    quit(0)
