extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")
const AnalyticsScript = preload("res://telemetry/analytics_service.gd")
const HealthScript = preload("res://telemetry/runtime_health.gd")
const GameFeelScript = preload("res://feedback/game_feel.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    if not _verify_release_preflight():
        return
    if not _verify_native_release_tooling():
        return

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

    var feedback_before := game_feel.feedback_count
    var flat_before := {"shipments_per_min": 50.0}
    var flat_after := {"shipments_per_min": 50.6}
    var flat_verdict: Dictionary = FlowMeasurementScript.classify_result(flat_before, flat_after)
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "before": flat_before,
        "after": flat_after,
        "verdict": flat_verdict,
    })
    if game_feel.last_measurement_state != "flat":
        _fail("game feel must use the domain verdict instead of a fixed +/-0.5 threshold")
        return
    if game_feel.feedback_count != feedback_before + 1:
        _fail("flat measurement must still receive subtle neutral audio/haptic feedback")
        return

    var improved_before := {"shipments_per_min": 20.0}
    var improved_after := {"shipments_per_min": 22.0}
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "before": improved_before,
        "after": improved_after,
        "verdict": FlowMeasurementScript.classify_result(improved_before, improved_after),
    })
    if game_feel.last_measurement_state != "improved":
        _fail("improved measurement must receive positive game feel")
        return

    var regressed_before := {"shipments_per_min": 20.0}
    var regressed_after := {"shipments_per_min": 18.0}
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "before": regressed_before,
        "after": regressed_after,
        "verdict": FlowMeasurementScript.classify_result(regressed_before, regressed_after),
    })
    if game_feel.last_measurement_state != "regressed":
        _fail("regressed measurement must receive cautionary game feel")
        return

    host.queue_free()
    await process_frame
    print("Godot release services smoke passed")
    quit(0)


func _verify_release_preflight() -> bool:
    if int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) != 390:
        _fail("release reference viewport width must remain 390")
        return false
    if int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) != 844:
        _fail("release reference viewport height must remain 844")
        return false
    if String(ProjectSettings.get_setting("display/window/stretch/mode", "")) != "canvas_items":
        _fail("mobile release must keep canvas_items stretch mode")
        return false
    if String(ProjectSettings.get_setting("display/window/stretch/aspect", "")) != "expand":
        _fail("mobile release must keep expand stretch aspect")
        return false
    if int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) != 1:
        _fail("mobile release must remain portrait")
        return false
    if String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")) != "gl_compatibility":
        _fail("release renderer must remain GL Compatibility")
        return false

    for required_path in [
        "res://icon.svg",
        "res://assets/fonts/MPLUS1p-Regular.ttf",
        "res://persistence/save_store.gd",
        "res://ui/game_hud_mobile.gd",
        "res://view/warehouse_view_mobile.gd",
    ]:
        if not FileAccess.file_exists(required_path):
            _fail("release asset/script missing: %s" % required_path)
            return false

    var presets := ConfigFile.new()
    var load_error := presets.load("res://export_presets.cfg")
    if load_error != OK:
        _fail("export presets must be readable")
        return false

    var release_presets: Array[String] = []
    for section_variant in presets.get_sections():
        var section := String(section_variant)
        if section.begins_with("preset.") and not section.ends_with(".options"):
            release_presets.append(section)
    if release_presets.size() != 1:
        _fail("before native identifiers are supplied, repository must contain only the Web engineering-preview preset")
        return false
    if String(presets.get_value("preset.0", "name", "")) != "Web":
        _fail("engineering-preview export preset must remain named Web")
        return false
    if String(presets.get_value("preset.0", "platform", "")) != "Web":
        _fail("engineering-preview preset must target Web")
        return false
    if not bool(presets.get_value("preset.0", "runnable", false)):
        _fail("Web engineering-preview preset must remain runnable")
        return false
    if bool(presets.get_value("preset.0.options", "progressive_web_app/enabled", true)):
        _fail("Web build is an engineering preview, not the production PWA target")
        return false

    return true


func _verify_native_release_tooling() -> bool:
    for required_path in [
        "res://tools/native_release_inputs.py",
        "res://native_release_inputs.example.env",
    ]:
        if not FileAccess.file_exists(required_path):
            _fail("native release tooling missing: %s" % required_path)
            return false

    # GitHub Actions executes this smoke on Linux with Python available. The
    # validator self-test uses only synthetic identifiers and never needs real
    # signing material or production secrets.
    if OS.has_feature("linux"):
        var validator_path := ProjectSettings.globalize_path("res://tools/native_release_inputs.py")
        var validator_output: Array = []
        var validator_exit := OS.execute(
            "python3",
            PackedStringArray([validator_path, "--self-test"]),
            validator_output,
            true
        )
        if validator_exit != 0:
            _fail("native release input validator self-test failed: %s" % str(validator_output))
            return false

    return true
