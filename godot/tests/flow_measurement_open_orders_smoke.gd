extends SceneTree

const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")


func _init() -> void:
    var measurement = FlowMeasurementScript.new()
    var at := 0.0

    for _index in range(25):
        at += 1.0
        measurement.record_state(at, 1.0, 2, 1, 3)
        measurement.record_orders(at, 1.0, 7)

    var before: Dictionary = measurement.begin_investment(&"routing_test", 0, at)
    assert(bool(before.get("baseline_complete", false)), "open-order measurement requires a complete baseline")
    assert(absf(float(before.get("open_orders", 0.0)) - 7.0) < 0.01, "authoritative backlog baseline must be non-zero")
    assert(float(before.get("open_orders_sampled_seconds", 0.0)) >= 24.9, "dedicated order samples must cover the measurement window")

    for _index in range(25):
        at += 1.0
        measurement.record_state(at, 1.0, 2, 1, 3)
        measurement.record_orders(at, 1.0, 3)

    var completed: Array[Dictionary] = measurement.collect_completed(at)
    assert(completed.size() == 1, "measurement must complete after the 25 second after-window")
    var result: Dictionary = completed[0]
    var after: Dictionary = result.get("after", {})
    var delta: Dictionary = result.get("delta", {})
    assert(absf(float(after.get("open_orders", 0.0)) - 3.0) < 0.01, "after-window must use authoritative open-order samples")
    assert(absf(float(delta.get("open_orders", 0.0)) + 4.0) < 0.01, "open-order delta must reflect backlog reduction")

    var legacy = FlowMeasurementScript.new()
    at = 0.0
    for _index in range(25):
        at += 1.0
        legacy.record_state(at, 1.0, 0, 0, 0, 5)
    var legacy_before: Dictionary = legacy.begin_investment(&"legacy_state_orders", 0, at)
    assert(absf(float(legacy_before.get("open_orders", 0.0)) - 5.0) < 0.01, "record_state orders argument must remain backward compatible")

    print("Godot flow measurement open-orders smoke passed")
    quit(0)
