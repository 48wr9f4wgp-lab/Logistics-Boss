extends Node
class_name LogisticsAnalytics

signal event_recorded(event: Dictionary)

const MAX_BUFFERED_EVENTS := 256

var sim: WarehouseSim
var provider: Callable
var enabled := true

var _events: Array[Dictionary] = []
var _session_id := ""
var _started_msec := 0
var _shipment_counter := 0
var _hud: Node


func _ready() -> void:
    _ensure_session()


func bind_sim(next_sim: WarehouseSim) -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
    sim = next_sim
    _ensure_session()
    if sim != null and not sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.connect(_on_sim_event)
    record("session_start", {
        "facility_rank": sim.facility_rank if sim != null else 0,
        "platform": _platform_key(),
    })


func bind_hud(next_hud: Node) -> void:
    _disconnect_hud()
    _hud = next_hud
    if _hud == null:
        return
    var step_callable := Callable(self, "_on_ftue_step_changed")
    var completion_callable := Callable(self, "_on_ftue_completed")
    if _hud.has_signal("ftue_step_changed") and not _hud.is_connected("ftue_step_changed", step_callable):
        _hud.connect("ftue_step_changed", step_callable)
    if _hud.has_signal("ftue_completed") and not _hud.is_connected("ftue_completed", completion_callable):
        _hud.connect("ftue_completed", completion_callable)
    if _hud.has_method("current_ftue_step"):
        var current_step := String(_hud.call("current_ftue_step"))
        if not current_step.is_empty():
            record("ftue_step", {"step": current_step})


func set_provider(next_provider: Callable) -> void:
    provider = next_provider


func record(event_name: String, payload: Dictionary = {}) -> void:
    if not enabled or event_name.is_empty():
        return
    _ensure_session()
    var event := {
        "name": event_name,
        "session_id": _session_id,
        "elapsed_seconds": snappedf(float(Time.get_ticks_msec() - _started_msec) / 1000.0, 0.1),
        "payload": payload.duplicate(true),
    }
    _events.append(event)
    while _events.size() > MAX_BUFFERED_EVENTS:
        _events.pop_front()
    event_recorded.emit(event)
    if provider.is_valid():
        provider.call(event)


func events() -> Array[Dictionary]:
    return _events.duplicate(true)


func latest_event() -> Dictionary:
    return _events.back().duplicate(true) if not _events.is_empty() else {}


func clear_buffer() -> void:
    _events.clear()


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    match event_type:
        "policy_changed":
            record("operation_policy_changed", {"policy": int(event.get("policy", 0))})
        "staffing_changed":
            record("staffing_changed", {
                "plan": String(event.get("plan", "")),
                "cooldown": float(event.get("cooldown", 0.0)),
            })
        "contract_started":
            record("contract_started", {"id": int(event.get("id", -1)), "title": String(event.get("title", ""))})
        "contract_completed":
            record("contract_completed", {
                "cash": int(event.get("cash", 0)),
                "rating": int(event.get("rating", 0)),
            })
        "contract_failed":
            record("contract_failed", {"title": String(event.get("title", ""))})
        "upgrade_purchased", "facility_purchased", "receiving_annex_purchased", "inbound_carrier_program_purchased":
            record("investment_purchased", {
                "type": event_type,
                "kind": String(event.get("kind", "")),
                "cost": int(event.get("cost", 0)),
                "facility_rank": sim.facility_rank if sim != null else 0,
            })
        "routing_changed":
            record("routing_changed", {"mode": String(event.get("mode", event.get("routing_mode", "")))})
        "rank_up":
            record("facility_rank_up", {"rank": sim.facility_rank if sim != null else int(event.get("rank", 0))})
        "measurement_completed":
            var before: Dictionary = event.get("before", {})
            var after: Dictionary = event.get("after", {})
            var before_rate := float(before.get("shipments_per_min", 0.0))
            var after_rate := float(after.get("shipments_per_min", 0.0))
            record("investment_measurement_completed", {
                "kind": String(event.get("kind", event.get("investment_kind", ""))),
                "shipments_before": before_rate,
                "shipments_after": after_rate,
                "shipments_delta": after_rate - before_rate,
                "inbound_before": float(before.get("inbound_queue", 0.0)),
                "inbound_after": float(after.get("inbound_queue", 0.0)),
                "packing_before": float(before.get("packing_queue", 0.0)),
                "packing_after": float(after.get("packing_queue", 0.0)),
            })
        "shipment":
            _shipment_counter += 1
            if _shipment_counter % 10 == 0:
                record("shipment_milestone", {
                    "session_shipments": _shipment_counter,
                    "total_shipped": sim.shipped if sim != null else 0,
                    "throughput_per_minute": sim.throughput_per_minute() if sim != null else 0.0,
                })


func _on_ftue_step_changed(step_key: String) -> void:
    record("ftue_step", {"step": step_key})


func _on_ftue_completed(skipped: bool) -> void:
    record("ftue_completed", {"skipped": skipped})


func _ensure_session() -> void:
    if not _session_id.is_empty():
        return
    _started_msec = Time.get_ticks_msec()
    _session_id = "%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]


func _platform_key() -> String:
    if OS.has_feature("ios"):
        return "ios"
    if OS.has_feature("android"):
        return "android"
    if OS.has_feature("web"):
        return "web"
    return OS.get_name().to_lower()


func _disconnect_hud() -> void:
    if _hud == null:
        return
    var step_callable := Callable(self, "_on_ftue_step_changed")
    var completion_callable := Callable(self, "_on_ftue_completed")
    if _hud.has_signal("ftue_step_changed") and _hud.is_connected("ftue_step_changed", step_callable):
        _hud.disconnect("ftue_step_changed", step_callable)
    if _hud.has_signal("ftue_completed") and _hud.is_connected("ftue_completed", completion_callable):
        _hud.disconnect("ftue_completed", completion_callable)
    _hud = null


func _exit_tree() -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
    _disconnect_hud()
