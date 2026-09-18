extends SceneTree

const WorkloadSimScript = preload("res://domain/workload_warehouse_sim.gd")

const STEP_SECONDS := 0.25
const CYCLE_SECONDS := 510.0
const MATERIAL_SHIPMENT_GAP := 10
const STAFFING_PLANS := ["receiving", "balanced", "picking", "dock", "shipping"]
const FLOW_FACILITIES := [&"double_dock", &"fast_pick_rack", &"fast_pack_cell"]


func _init() -> void:
    var fixed_results: Array[Dictionary] = []
    for plan in STAFFING_PLANS:
        fixed_results.append(_run_fixed(plan))
    var best_fixed := _best_result(fixed_results)

    var best_adaptive: Dictionary = {}
    var adaptive_count := 0
    for inbound_plan in STAFFING_PLANS:
        for order_plan in STAFFING_PLANS:
            for dispatch_plan in STAFFING_PLANS:
                var distinct := {}
                distinct[inbound_plan] = true
                distinct[order_plan] = true
                distinct[dispatch_plan] = true
                if distinct.size() < 2:
                    continue
                var mapping := {
                    "forecast_inbound": inbound_plan,
                    "forecast_orders": order_plan,
                    "forecast_dispatch": dispatch_plan,
                }
                var result := _run_mapping(mapping)
                adaptive_count += 1
                if best_adaptive.is_empty() or _is_better(result, best_adaptive):
                    best_adaptive = result

    var report := {
        "cycle_seconds": CYCLE_SECONDS,
        "session_target_minutes": "5-15",
        "fixed_results": fixed_results,
        "best_fixed": best_fixed,
        "adaptive_strategies_tested": adaptive_count,
        "best_adaptive": best_adaptive,
        "shipment_gap": int(best_adaptive.get("shipments", 0)) - int(best_fixed.get("shipments", 0)),
        "revenue_gap": int(best_adaptive.get("revenue", 0)) - int(best_fixed.get("revenue", 0)),
    }
    print("ECONOMY_PROGRESSION_PACING_AUDIT %s" % JSON.stringify(report))

    if not _require(
        int(best_adaptive.get("shipments", 0)) >= int(best_fixed.get("shipments", 0)) + MATERIAL_SHIPMENT_GAP,
        "within one 8.5-minute workload cycle, anticipatory staffing must materially outperform the best no-decision fixed staffing plan"
    ):
        return
    if not _require(
        int(best_adaptive.get("revenue", 0)) > int(best_fixed.get("revenue", 0)),
        "anticipatory staffing must produce a real revenue advantage over the best fixed plan"
    ):
        return
    if not _require(
        int(best_adaptive.get("switches", 0)) >= 2,
        "the best adaptive result must actually use repeated staffing decisions"
    ):
        return

    print("Godot economy/progression pacing audit passed")
    quit(0)


func _run_fixed(plan: String) -> Dictionary:
    var sim = _prepared_rank2(plan)
    return _run_cycle(sim, {}, "fixed:%s" % plan)


func _run_mapping(mapping: Dictionary) -> Dictionary:
    var start_plan := String(mapping.get("forecast_inbound", "balanced"))
    var sim = _prepared_rank2(start_plan)
    return _run_cycle(sim, mapping, "adaptive")


func _run_cycle(sim, mapping: Dictionary, strategy: String) -> Dictionary:
    var start_shipped: int = sim.shipped
    var start_money: int = sim.money
    var inbound_sum := 0.0
    var orders_sum := 0.0
    var packing_sum := 0.0
    var outbound_sum := 0.0
    var samples := 0
    var last_phase_id := ""
    var switches := 0

    for _i in int(ceil(CYCLE_SECONDS / STEP_SECONDS)):
        if not mapping.is_empty():
            var wave: Dictionary = sim.workload_wave()
            var phase_id := String(wave.get("phase_id", ""))
            if phase_id != last_phase_id:
                last_phase_id = phase_id
                var target := String(mapping.get(phase_id, ""))
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

    var divisor := maxf(1.0, float(samples))
    return {
        "strategy": strategy,
        "mapping": mapping.duplicate(true),
        "shipments": sim.shipped - start_shipped,
        "revenue": sim.money - start_money,
        "queue_pressure": snappedf((inbound_sum + orders_sum + packing_sum + outbound_sum) / divisor, 0.01),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "orders_avg": snappedf(orders_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / divisor, 0.01),
        "switches": switches,
    }


func _prepared_rank2(plan: String):
    var sim = WorkloadSimScript.new()
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
    data["workload_clock"] = 0.0
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
    assert(sim.load_data(data), "economy pacing audit seed must load")

    for kind in FLOW_FACILITIES:
        var purchase: Dictionary = sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in economy pacing audit" % String(kind))

    sim.inbound_queue = 6
    sim.rack_stock = mini(sim.rack_capacity, 10)
    sim.packing_queue = 3
    sim.packed_queue = 4
    sim.open_orders = 6
    return sim


func _best_result(results: Array[Dictionary]) -> Dictionary:
    var best: Dictionary = {}
    for candidate in results:
        if best.is_empty() or _is_better(candidate, best):
            best = candidate
    return best.duplicate(true)


func _is_better(candidate: Dictionary, current: Dictionary) -> bool:
    var candidate_shipments := int(candidate.get("shipments", 0))
    var current_shipments := int(current.get("shipments", 0))
    if candidate_shipments != current_shipments:
        return candidate_shipments > current_shipments

    var candidate_revenue := int(candidate.get("revenue", 0))
    var current_revenue := int(current.get("revenue", 0))
    if candidate_revenue != current_revenue:
        return candidate_revenue > current_revenue

    return float(candidate.get("queue_pressure", INF)) < float(current.get("queue_pressure", INF))


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
