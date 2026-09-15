extends "res://domain/workload_warehouse_sim.gd"

var pick_cycle_multiplier: float = 1.0
var autonomous_retrieval_cycle: float = 0.0
var autonomous_retrieval_starts: int = 0
var autonomous_retrieval_completions: int = 0

var _autonomous_retrieval_active: bool = false
var _autonomous_retrieval_remaining: float = 0.0


func configure_candidate(pick_multiplier: float, retrieval_cycle: float) -> void:
    pick_cycle_multiplier = clampf(pick_multiplier, 0.35, 1.0)
    autonomous_retrieval_cycle = maxf(0.0, retrieval_cycle)
    autonomous_retrieval_starts = 0
    autonomous_retrieval_completions = 0
    _autonomous_retrieval_active = false
    _autonomous_retrieval_remaining = 0.0


func step(real_dt: float) -> void:
    super.step(real_dt)
    var dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    if dt > 0.0:
        _update_autonomous_retrieval(dt)


func _start_task(worker: Dictionary, task: int) -> void:
    super._start_task(worker, task)
    if task != Task.PICK or pick_cycle_multiplier >= 0.999:
        return

    var adjusted_duration := maxf(0.05, float(worker.get("duration", 0.0)) * pick_cycle_multiplier)
    worker["duration"] = adjusted_duration
    worker["remaining"] = adjusted_duration
    worker["progress"] = 0.0


func _update_autonomous_retrieval(dt: float) -> void:
    if autonomous_retrieval_cycle <= 0.0:
        return

    if _autonomous_retrieval_active:
        _autonomous_retrieval_remaining = maxf(0.0, _autonomous_retrieval_remaining - dt)
        if _autonomous_retrieval_remaining <= 0.0:
            _autonomous_retrieval_active = false
            packing_queue += 1
            autonomous_retrieval_completions += 1
            _emit("rank3_retrieval_completed", {
                "packing_queue": packing_queue,
                "completions": autonomous_retrieval_completions,
            })

    if _autonomous_retrieval_active:
        return
    if rack_stock <= 0 or open_orders <= 0:
        return

    rack_stock -= 1
    open_orders -= 1
    _autonomous_retrieval_active = true
    _autonomous_retrieval_remaining = autonomous_retrieval_cycle
    autonomous_retrieval_starts += 1
    _emit("rank3_retrieval_started", {
        "duration": autonomous_retrieval_cycle,
        "starts": autonomous_retrieval_starts,
    })
