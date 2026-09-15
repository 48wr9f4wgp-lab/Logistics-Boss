extends SceneTree

const WorkloadSimScript = preload("res://domain/workload_warehouse_sim.gd")
const STEP_SECONDS := 0.1
const SCENARIO_SECONDS := 40.0
const REPLENISHMENT_SECONDS := 12.0
const CYCLE_SECONDS := 510.0
const STAFFING_PLANS := ["receiving", "balanced", "picking", "dock", "shipping"]
const PHASE_CLOCKS := {
    "inbound_surge": 35.1,
    "order_surge": 120.1,
    "dispatch_window": 205.1,
}
const PROFILES := {
    "flow": [&"double_dock", &"fast_pick_rack", &"fast_pack_cell"],
    "capacity": [&"buffer_yard", &"high_density_rack", &"parallel_pack"],
}


func _init() -> void:
    var profiles_report: Dictionary = {}
    var distinct_winners: Dictionary = {}

    for profile in PROFILES.keys():
        var report: Dictionary = {}
        var winners: Dictionary = {}
        for phase in ["inbound_surge", "order_surge", "dispatch_window"]:
            var results: Array[Dictionary] = []
            for plan in STAFFING_PLANS:
                results.append(_run_phase(String(profile), phase, plan))
            var winner: Dictionary = _phase_winner(phase, results)
            report[phase] = {
                "winner": winner,
                "plans": results,
            }
            var winner_plan := String(winner.get("staffing", ""))
            winners[phase] = winner_plan
            distinct_winners[winner_plan] = true
        profiles_report[String(profile)] = {
            "phases": report,
            "winners": winners,
        }

    var replenishment_results: Array[Dictionary] = []
    for plan in STAFFING_PLANS:
        replenishment_results.append(_run_replenishment(plan))
    var replenishment_winner: Dictionary = _phase_winner("inbound_surge", replenishment_results)
    distinct_winners[String(replenishment_winner.get("staffing", ""))] = true

    var strategy_report: Dictionary = {
        "fixed_balanced": _run_cycle_strategy("flow", "fixed_balanced"),
        "fixed_shipping": _run_cycle_strategy("flow", "fixed_shipping"),
        "adaptive": _run_cycle_strategy("flow", "adaptive"),
    }

    print("RANK2_WORKLOAD_WAVE_REPORT %s" % JSON.stringify({
        "scenario_seconds": SCENARIO_SECONDS,
        "replenishment_seconds": REPLENISHMENT_SECONDS,
        "cycle_seconds": CYCLE_SECONDS,
        "profiles": profiles_report,
        "replenishment": {
            "winner": replenishment_winner,
            "plans": replenishment_results,
        },
        "distinct_winners": distinct_winners.keys(),
        "strategy": strategy_report,
    }))

    if not _require(distinct_winners.size() >= 5, "every Rank 2 staffing preset must have at least one measured operating niche"):
        return
    var adaptive: Dictionary = strategy_report["adaptive"]
    var fixed_shipping: Dictionary = strategy_report["fixed_shipping"]
    var fixed_balanced: Dictionary = strategy_report["fixed_balanced"]
    if not _require(int(adaptive.get("shipments", 0)) > int(fixed_shipping.get("shipments", 0)), "forecast-driven staffing must beat always-shipping throughput across full workload cycles"):
        return
    if not _require(int(adaptive.get("revenue", 0)) > int(fixed_shipping.get("revenue", 0)), "forecast-driven staffing must beat always-shipping revenue across full workload cycles"):
        return
    if not _require(int(adaptive.get("shipments", 0)) >= int(fixed_balanced.get("shipments", 0)) + 10, "workload decisions must materially outperform leaving staffing balanced"):
        return
    if not _require(int(adaptive.get("ending_packed", 999)) <= 2, "adaptive strategy must clear staged outbound work by the end of the dispatch window"):
        return

    print("Godot Rank 2 workload wave pacing report passed")
    quit(0)


func _run_phase(profile: String, phase: String, plan: String) -> Dictionary:
    var sim: WorkloadWarehouseSim = _prepared_rank2(profile, plan, float(PHASE_CLOCKS[phase]))
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


func _run_replenishment(plan: String) -> Dictionary:
    var sim: WorkloadWarehouseSim = _prepared_rank2("capacity", plan, float(PHASE_CLOCKS["inbound_surge"]))
    sim.inbound_queue = 18
    sim.rack_stock = 0
    sim.open_orders = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    var inbound_sum: float = 0.0
    var samples: int = 0

    for _i in int(ceil(REPLENISHMENT_SECONDS / STEP_SECONDS)):
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        samples += 1

    return {
        "staffing": plan,
        "shipments": sim.shipped,
        "revenue": sim.money,
        "inbound_avg": snappedf(inbound_sum / maxf(1.0, float(samples)), 0.01),
        "orders_avg": 0.0,
        "packing_avg": 0.0,
        "outbound_avg": 0.0,
        "ending_inbound": sim.inbound_queue,
        "ending_orders": sim.open_orders,
        "ending_packed": sim.packed_queue,
        "rack_stock": sim.rack_stock,
    }


func _run_cycle_strategy(profile: String, strategy: String) -> Dictionary:
    var starting_plan := "balanced"
    if strategy == "fixed_shipping":
        starting_plan = "shipping"
    var sim: WorkloadWarehouseSim = _prepared_rank2(profile, starting_plan, 0.0)
    var start_shipped: int = sim.shipped
    var start_money: int = sim.money
    var inbound_sum: float = 0.0
    var orders_sum: float = 0.0
    var packing_sum: float = 0.0
    var outbound_sum: float = 0.0
    var samples: int = 0
    var last_phase_id := ""
    var switches: int = 0

    for _i in int(ceil(CYCLE_SECONDS / STEP_SECONDS)):
        if strategy == "adaptive":
            var wave: Dictionary = sim.workload_wave()
            var phase_id := String(wave.get("phase_id", ""))
            if phase_id != last_phase_id:
                last_phase_id = phase_id
                var target := _adaptive_plan_for_phase(phase_id)
                if not target.is_empty() and target != sim.staffing_plan and sim.staffing_cooldown <= 0.001:
                    var result: Dictionary = sim.set_staffing_plan(target)
                    if bool(result.get("ok", false)):
                        switches += 1
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        orders_sum += float(sim.open_orders)
        packing_sum += float(sim.packing_queue)
        outbound_sum += float(sim.packed_queue)
        samples += 1

    var divisor: float = maxf(1.0, float(samples))
    var queue_pressure := (inbound_sum + orders_sum + packing_sum + outbound_sum) / divisor
    return {
        "strategy": strategy,
        "shipments": sim.shipped - start_shipped,
        "revenue": sim.money - start_money,
        "queue_pressure": snappedf(queue_pressure, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "orders_avg": snappedf(orders_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / divisor, 0.01),
        "ending_inbound": sim.inbound_queue,
        "ending_orders": sim.open_orders,
        "ending_packing": sim.packing_queue,
        "ending_packed": sim.packed_queue,
        "switches": switches,
    }


func _adaptive_plan_for_phase(phase_id: String) -> String:
    match phase_id:
        "forecast_inbound":
            return "balanced"
        "forecast_orders":
            return "picking"
        "forecast_dispatch":
            return "shipping"
    return ""


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


func _prepared_rank2(profile: String, plan: String, clock: float) -> WorkloadWarehouseSim:
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

    var facilities: Array = PROFILES[profile]
    for kind in facilities:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in workload pacing scenario" % String(kind))

    sim.inbound_queue = 6
    sim.rack_stock = mini(sim.rack_capacity, 10)
    sim.packing_queue = 3
    sim.packed_queue = 4
    sim.open_orders = 6
    return sim


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
