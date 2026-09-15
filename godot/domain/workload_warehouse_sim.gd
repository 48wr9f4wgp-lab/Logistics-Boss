extends "res://domain/warehouse_sim.gd"
class_name WorkloadWarehouseSim

const WorkloadWaveModelScript = preload("res://domain/workload_wave_model.gd")
const SAVE_SCHEMA_WAVES := 4

var workload_clock: float = 0.0
var _dispatch_start_shipped: int = 0
var _last_workload_phase_id: String = ""
var _workload: WorkloadWaveModel = WorkloadWaveModelScript.new()


func step(real_dt: float) -> void:
    var scaled_dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    if facility_rank >= 2 and scaled_dt > 0.0:
        _advance_workload_clock(scaled_dt)
    super.step(real_dt)


func workload_wave() -> Dictionary:
    if facility_rank < 2:
        return {
            "enabled": false,
            "phase_id": "locked",
            "key": "locked",
            "label": "RANK 2で解禁",
            "description": "Warehouse昇格後に運用負荷が変動",
            "is_peak": false,
            "remaining": 0.0,
            "next_wave_key": "",
            "next_wave_label": "",
            "seconds_until_next_wave": 0.0,
            "dispatch_shipments": 0,
        }

    var state := _workload.state_at(workload_clock)
    state["dispatch_shipments"] = (
        maxi(0, shipped - _dispatch_start_shipped)
        if String(state.get("key", "")) == "dispatch_window"
        else 0
    )
    return state


func snapshot() -> Dictionary:
    var data: Dictionary = super.snapshot()
    data["schema_version"] = SAVE_SCHEMA_WAVES
    data["workload_clock"] = workload_clock
    data["workload_wave"] = workload_wave()
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_WAVES
    data["workload_clock"] = workload_clock
    data["dispatch_start_shipped"] = _dispatch_start_shipped
    return data


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA_WAVES:
        return false

    var base_data: Dictionary = data.duplicate(true)
    base_data["schema_version"] = mini(source_schema, 3)
    if not super.load_data(base_data):
        return false

    workload_clock = (
        _workload.normalized_clock(float(data.get("workload_clock", 0.0)))
        if source_schema >= SAVE_SCHEMA_WAVES
        else 0.0
    )
    _dispatch_start_shipped = (
        maxi(0, int(data.get("dispatch_start_shipped", shipped)))
        if source_schema >= SAVE_SCHEMA_WAVES
        else shipped
    )
    _last_workload_phase_id = _workload.phase_id_at(workload_clock) if facility_rank >= 2 else ""

    if source_schema < SAVE_SCHEMA_WAVES:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_WAVES})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_WAVES})
    return true


func _current_inbound_interval() -> float:
    var base_interval := super._current_inbound_interval()
    if facility_rank < 2:
        return base_interval
    return base_interval * _workload.inbound_interval_multiplier(workload_clock)


func _current_order_interval() -> float:
    var base_interval := super._current_order_interval()
    if facility_rank < 2:
        return base_interval
    return base_interval * _workload.order_interval_multiplier(workload_clock)


func _advance_workload_clock(dt: float) -> void:
    var before_id := _workload.phase_id_at(workload_clock)
    workload_clock = _workload.normalized_clock(workload_clock + dt)
    var after_id := _workload.phase_id_at(workload_clock)
    if _last_workload_phase_id.is_empty():
        _last_workload_phase_id = before_id

    if after_id == before_id:
        _last_workload_phase_id = after_id
        return

    var state := _workload.state_at(workload_clock)
    if String(state.get("key", "")) == "dispatch_window":
        _dispatch_start_shipped = shipped

    _last_workload_phase_id = after_id
    _emit("workload_wave_changed", {
        "phase_id": after_id,
        "key": String(state.get("key", "")),
        "label": String(state.get("label", "")),
        "description": String(state.get("description", "")),
        "remaining": float(state.get("remaining", 0.0)),
        "next_wave_key": String(state.get("next_wave_key", "")),
        "next_wave_label": String(state.get("next_wave_label", "")),
        "seconds_until_next_wave": float(state.get("seconds_until_next_wave", 0.0)),
    })
