extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const STEP_SECONDS := 0.1
const SCENARIO_SECONDS := 240.0
const STAFFING_PLANS := ["receiving", "balanced", "picking", "dock", "shipping"]
const INTAKE_CHOICES := [&"double_dock", &"buffer_yard"]
const STORAGE_CHOICES := [&"fast_pick_rack", &"high_density_rack"]
const PACKING_CHOICES := [&"parallel_pack", &"fast_pack_cell"]


func _init() -> void:
    var frontier: Array[Dictionary] = []
    var scenario_count := 0

    for intake in INTAKE_CHOICES:
        for storage in STORAGE_CHOICES:
            for packing in PACKING_CHOICES:
                var combination := {
                    "intake": String(intake),
                    "storage": String(storage),
                    "packing": String(packing),
                }
                var plan_results: Array[Dictionary] = []
                for plan in STAFFING_PLANS:
                    var result := _run_scenario(intake, storage, packing, plan)
                    plan_results.append(result)
                    scenario_count += 1
                    if not _require(
                        int(result.get("shipments", 0)) > 0,
                        "post-zone scenario stopped shipment flow: %s / %s" % [JSON.stringify(combination), plan]
                    ):
                        return

                var best := _best_plan(plan_results)
                if not _require(
                    float(best.get("shipments_per_min", 0.0)) >= 6.0,
                    "a completed three-zone Warehouse must remain above the Rank 3 readiness throughput floor"
                ):
                    return
                frontier.append({
                    "combination": combination,
                    "best": best,
                    "plans": plan_results,
                })

    var summary := _summarize(frontier)
    print("RANK2_POST_ZONE_FRONTIER %s" % JSON.stringify({
        "scenario_seconds": SCENARIO_SECONDS,
        "scenario_count": scenario_count,
        "frontier": frontier,
        "summary": summary,
    }))

    if not _require(scenario_count == 40, "all 8 facility combinations x 5 staffing plans must be measured"):
        return
    if not _require(int(summary.get("combination_count", 0)) == 8, "frontier must contain all eight facility combinations"):
        return

    print("Godot Rank 2 post-zone frontier passed")
    quit(0)


func _run_scenario(intake: StringName, storage: StringName, packing: StringName, plan: String) -> Dictionary:
    var sim := _prepared_rank2(plan)
    for kind in [intake, storage, packing]:
        var purchase := sim.purchase_facility(kind)
        assert(bool(purchase.get("ok", false)), "%s must purchase in frontier scenario" % String(kind))

    var start_shipped := sim.shipped
    var start_money := sim.money
    var samples := 0
    var inbound_sum := 0.0
    var rack_sum := 0.0
    var packing_sum := 0.0
    var outbound_sum := 0.0
    var orders_sum := 0.0
    var busy_worker_samples := 0
    var total_worker_samples := 0
    var store_task_samples := 0
    var pick_task_samples := 0
    var ship_task_samples := 0
    var bottlenecks := {}

    var steps := int(ceil(SCENARIO_SECONDS / STEP_SECONDS))
    for _i in steps:
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        rack_sum += float(sim.rack_stock)
        packing_sum += float(sim.packing_queue)
        outbound_sum += float(sim.packed_queue)
        orders_sum += float(sim.open_orders)
        var bottleneck_key := String(sim.bottleneck().get("key", "stable"))
        bottlenecks[bottleneck_key] = int(bottlenecks.get(bottleneck_key, 0)) + 1

        for worker in sim.workers:
            total_worker_samples += 1
            match int(worker.get("task", WarehouseSim.Task.IDLE)):
                WarehouseSim.Task.STORE:
                    busy_worker_samples += 1
                    store_task_samples += 1
                WarehouseSim.Task.PICK:
                    busy_worker_samples += 1
                    pick_task_samples += 1
                WarehouseSim.Task.SHIP:
                    busy_worker_samples += 1
                    ship_task_samples += 1
        samples += 1

    var shipments := sim.shipped - start_shipped
    var divisor := maxf(1.0, float(samples))
    var worker_divisor := maxf(1.0, float(total_worker_samples))
    var queue_pressure := (
        inbound_sum + packing_sum + outbound_sum + orders_sum
    ) / divisor

    return {
        "staffing": plan,
        "shipments": shipments,
        "shipments_per_min": snappedf(float(shipments) * 60.0 / SCENARIO_SECONDS, 0.1),
        "revenue": sim.money - start_money,
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "rack_avg": snappedf(rack_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / divisor, 0.01),
        "orders_avg": snappedf(orders_sum / divisor, 0.01),
        "queue_pressure": snappedf(queue_pressure, 0.01),
        "rack_capacity": sim.rack_capacity,
        "worker_busy_ratio": snappedf(float(busy_worker_samples) / worker_divisor, 0.001),
        "store_task_ratio": snappedf(float(store_task_samples) / worker_divisor, 0.001),
        "pick_task_ratio": snappedf(float(pick_task_samples) / worker_divisor, 0.001),
        "ship_task_ratio": snappedf(float(ship_task_samples) / worker_divisor, 0.001),
        "dominant_bottleneck": _dominant_key(bottlenecks),
        "bottleneck_distribution": bottlenecks,
    }


func _best_plan(results: Array[Dictionary]) -> Dictionary:
    var best: Dictionary = {}
    for candidate in results:
        if best.is_empty():
            best = candidate
            continue
        var candidate_rate := float(candidate.get("shipments_per_min", 0.0))
        var best_rate := float(best.get("shipments_per_min", 0.0))
        if candidate_rate > best_rate + 0.001:
            best = candidate
        elif is_equal_approx(candidate_rate, best_rate) and float(candidate.get("queue_pressure", INF)) < float(best.get("queue_pressure", INF)):
            best = candidate
    return best.duplicate(true)


func _summarize(frontier: Array[Dictionary]) -> Dictionary:
    var bottlenecks := {}
    var staffing_wins := {}
    var fastest_rate := 0.0
    var slowest_rate := INF
    var fastest_combo := {}
    var slowest_combo := {}

    for item in frontier:
        var best: Dictionary = item.get("best", {})
        var combination: Dictionary = item.get("combination", {})
        var bottleneck := String(best.get("dominant_bottleneck", "unknown"))
        var staffing := String(best.get("staffing", "unknown"))
        var rate := float(best.get("shipments_per_min", 0.0))
        bottlenecks[bottleneck] = int(bottlenecks.get(bottleneck, 0)) + 1
        staffing_wins[staffing] = int(staffing_wins.get(staffing, 0)) + 1
        if rate > fastest_rate:
            fastest_rate = rate
            fastest_combo = combination.duplicate(true)
        if rate < slowest_rate:
            slowest_rate = rate
            slowest_combo = combination.duplicate(true)

    return {
        "combination_count": frontier.size(),
        "best_plan_bottlenecks": bottlenecks,
        "best_plan_staffing_wins": staffing_wins,
        "fastest_shipments_per_min": snappedf(fastest_rate, 0.1),
        "slowest_shipments_per_min": snappedf(slowest_rate, 0.1),
        "fastest_combination": fastest_combo,
        "slowest_combination": slowest_combo,
    }


func _prepared_rank2(plan: String) -> WarehouseSim:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var data := sim.save_data()
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
    data["inbound_queue"] = 10
    data["rack_stock"] = 6
    data["packing_queue"] = 4
    data["packed_queue"] = 1
    data["open_orders"] = 8
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "post-zone frontier seed must load")
    return sim


func _dominant_key(counts: Dictionary) -> String:
    var best_key := "stable"
    var best_count := -1
    for key in counts:
        var count := int(counts[key])
        if count > best_count:
            best_count = count
            best_key = String(key)
    return best_key


func _require(condition: bool, message: String) -> bool:
    if condition:
        return true
    push_error(message)
    quit(1)
    return false
