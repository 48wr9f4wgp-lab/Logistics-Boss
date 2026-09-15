extends SceneTree

const WorkloadSimScript = preload("res://domain/workload_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const SCENARIO_SECONDS := 40.0
const STAFFING_PLANS := ["receiving", "balanced", "picking", "dock", "shipping"]
const PHASE_CLOCKS := {
    "inbound_surge": 35.1,
    "order_surge": 120.1,
    "dispatch_window": 205.1,
}


func _init() -> void:
    var report: Dictionary = {}
    var winners: Dictionary = {}

    for phase in ["inbound_surge", "order_surge", "dispatch_window"]:
        var results: Array[Dictionary] = []
        for plan in STAFFING_PLANS:
            results.append(_run_phase(phase, plan))
        var winner: Dictionary = _phase_winner(phase, results)
        report[phase] = {
            "winner": winner,
            "plans": results,
        }
        winners[phase] = String(winner.get("staffing", ""))

    print("RANK2_WORKLOAD_WAVE_REPORT %s" % JSON.stringify({
        "scenario_seconds": SCENARIO_SECONDS,
        "phases": report,
        "winners": winners,
    }))

    assert(String(winners.get("inbound_surge", "")).length() > 0, "inbound surge must produce a measurable staffing result")
    assert(String(winners.get("order_surge", "")).length() > 0, "order surge must produce a measurable staffing result")
    assert(String(winners.get("dispatch_window", "")).length() > 0, "dispatch window must produce a measurable staffing result")

    print("Godot Rank 2 workload wave pacing report passed")
    quit(0)


func _run_phase(phase: String, plan: String) -> Dictionary:
    var sim: WorkloadWarehouseSim = _prepared_rank2(plan, float(PHASE_CLOCKS[phase]))
    var start_shipped: int = sim.shipped
    var start_money: int = sim.money
    var inbound_sum: float = 0.0
    var orders_sum: float = 0.0
    var packing_sum: float = 0.0
    var outbound_sum: float = 0.0
    var samples: int = 0

    for _i in int(ceil(SCENARIO_SECONDS / STEP_SECONDS)):
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        orders_sum += float(sim.open_orders)
        packing_sum += float(sim.packing_queue)
        outbound_sum += float(sim.packed_queue)
        samples += 1

    var divisor: float = maxf(1.0, float(samples))
    return {
        "staffing": plan,
        "shipments": sim.shipped - start_shipped,
        "revenue": sim.money - start_money,
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "orders_avg": snappedf(orders_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / divisor, 0.01),
        "ending_inbound": sim.inbound_queue,
        "ending_orders": sim.open_orders,
        "ending_packed": sim.packed_queue,
    }


func _phase_winner(phase: String, results: Array[Dictionary]) -> Dictionary:
    var best: Dictionary = {}
    for candidate in results:
        if best.is_empty() or _better_for_phase(phase, candidate, best):
            best = candidate
    return best.duplicate(true)


func _better_for_phase(phase: String, candidate: Dictionary, current: Dictionary) -> bool:
    match phase:
        "inbound_surge":
            var candidate_pressure: float = float(candidate.get("inbound_avg", INF))
            var current_pressure: float = float(current.get("inbound_avg", INF))
            if candidate_pressure < current_pressure - 0.01:
                return true
            if is_equal_approx(candidate_pressure, current_pressure):
                return int(candidate.get("shipments", 0)) > int(current.get("shipments", 0))
        "order_surge":
            var candidate_pressure: float = float(candidate.get("orders_avg", INF))
            var current_pressure: float = float(current.get("orders_avg", INF))
            if candidate_pressure < current_pressure - 0.01:
                return true
            if is_equal_approx(candidate_pressure, current_pressure):
                return int(candidate.get("shipments", 0)) > int(current.get("shipments", 0))
        "dispatch_window":
            var candidate_shipments: int = int(candidate.get("shipments", 0))
            var current_shipments: int = int(current.get("shipments", 0))
            if candidate_shipments > current_shipments:
                return true
            if candidate_shipments == current_shipments:
                return int(candidate.get("ending_packed", 0)) < int(current.get("ending_packed", 0))
    return false


func _prepared_rank2(plan: String, clock: float) -> WorkloadWarehouseSim:
    var sim: WorkloadWarehouseSim = WorkloadSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 4
    data["facility_rank"] = 2
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 500000
    data["forklift_unlocked"] = true
    data["pack_level"] = 1
    data["pack_time_multiplier"] = 0.85
    data["staffing_plan"] = plan
    data["staffing_cooldown"] = 0.0
    data["workload_clock"] = clock
    data["dispatch_start_shipped"] = int(data.get("shipped", 0))
    data["inbound_queue"] = 6
    data["rack_stock"] = 6
    data["packing_queue"] = 3
    data["packed_queue"] = 4
    data["open_orders"] = 6
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "workload pacing seed must load")

    for kind in [&"double_dock", &"high_density_rack", &"fast_pack_cell"]:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in workload pacing scenario" % String(kind))

    sim.inbound_queue = 6
    sim.rack_stock = mini(sim.rack_capacity, 10)
    sim.packing_queue = 3
    sim.packed_queue = 4
    sim.open_orders = 6
    return sim
