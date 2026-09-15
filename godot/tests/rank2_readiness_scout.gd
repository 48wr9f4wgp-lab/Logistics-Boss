extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const STEP_SECONDS := 0.1
const WARMUP_SECONDS := 180.0
const FORKLIFT_OBSERVE_SECONDS := 120.0
const PACKING_OBSERVE_SECONDS := 120.0
const STABILITY_SCOUT_SECONDS := 300.0
const COMPARISON_SECONDS := 120.0


func _init() -> void:
    var sim: WarehouseSim = WarehouseSimScript.new()
    _run_for(sim, WARMUP_SECONDS)
    sim.money = 1000000

    var forklift_purchase := sim.purchase_upgrade(&"forklift")
    assert(bool(forklift_purchase.get("ok", false)), "rank2 scout requires forklift purchase")
    _run_for(sim, FORKLIFT_OBSERVE_SECONDS)

    var packing_purchase := sim.purchase_upgrade(&"packing")
    assert(bool(packing_purchase.get("ok", false)), "rank2 scout requires packing purchase")
    _run_for(sim, PACKING_OBSERVE_SECONDS)

    var post_core_seed := sim.save_data()
    var sustained := _sample_operation(sim, STABILITY_SCOUT_SECONDS)

    var marginal := {}
    for kind in [&"worker", &"rack", &"speed", &"packing"]:
        marginal[String(kind)] = _compare_upgrade(post_core_seed, kind)

    var report := {
        "post_forklift_packing_5m": sustained,
        "post_core_marginal_upgrades_120s": marginal,
    }
    print("RANK2_READINESS_REPORT " + JSON.stringify(report))

    assert(int(sustained.get("shipments", 0)) > 0, "post-core operation must continue shipping")
    assert(float(sustained.get("worker_busy_ratio", 0.0)) > 0.5, "workers should remain meaningfully engaged")
    assert(float(sustained.get("worker_busy_ratio", 1.0)) < 0.99, "Rank 1 should retain some dispatch slack before structural Rank 2")

    print("Godot Rank 2 readiness scout passed")
    quit(0)


func _compare_upgrade(seed: Dictionary, kind: StringName) -> Dictionary:
    var control: WarehouseSim = WarehouseSimScript.new()
    var variant: WarehouseSim = WarehouseSimScript.new()
    assert(control.load_data(seed), "Rank 2 control seed must load")
    assert(variant.load_data(seed), "Rank 2 variant seed must load")

    control.money = 1000000
    variant.money = 1000000
    var purchase := variant.purchase_upgrade(kind)
    assert(bool(purchase.get("ok", false)), "%s comparison purchase must succeed" % String(kind))

    var control_metrics := _sample_operation(control, COMPARISON_SECONDS)
    var variant_metrics := _sample_operation(variant, COMPARISON_SECONDS)
    return {
        "cost": int(purchase.get("cost", 0)),
        "control_shipments": int(control_metrics.get("shipments", 0)),
        "variant_shipments": int(variant_metrics.get("shipments", 0)),
        "shipment_delta": int(variant_metrics.get("shipments", 0)) - int(control_metrics.get("shipments", 0)),
        "control_bottleneck": String(control_metrics.get("dominant_bottleneck", "unknown")),
        "variant_bottleneck": String(variant_metrics.get("dominant_bottleneck", "unknown")),
        "control_busy_ratio": control_metrics.get("worker_busy_ratio", 0.0),
        "variant_busy_ratio": variant_metrics.get("worker_busy_ratio", 0.0),
        "control_inbound_avg": control_metrics.get("inbound_avg", 0.0),
        "variant_inbound_avg": variant_metrics.get("inbound_avg", 0.0),
        "control_packing_avg": control_metrics.get("packing_avg", 0.0),
        "variant_packing_avg": variant_metrics.get("packing_avg", 0.0),
        "control_outbound_avg": control_metrics.get("outbound_avg", 0.0),
        "variant_outbound_avg": variant_metrics.get("outbound_avg", 0.0),
    }


func _sample_operation(sim: WarehouseSim, seconds: float) -> Dictionary:
    var start_shipped := sim.shipped
    var inbound_sum := 0.0
    var packing_sum := 0.0
    var outbound_sum := 0.0
    var orders_sum := 0.0
    var rack_util_sum := 0.0
    var task_samples := {
        "idle": 0,
        "store": 0,
        "pick": 0,
        "ship": 0,
    }
    var bottleneck_samples := {
        "stable": 0,
        "inbound": 0,
        "rack": 0,
        "packing": 0,
        "outbound": 0,
        "orders": 0,
    }
    var samples := 0
    var steps := int(ceil(seconds / STEP_SECONDS))

    for _i in steps:
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        packing_sum += float(sim.packing_queue)
        outbound_sum += float(sim.packed_queue)
        orders_sum += float(sim.open_orders)
        rack_util_sum += float(sim.rack_stock) / float(maxi(1, sim.rack_capacity))

        for worker in sim.workers:
            match int(worker.get("task", WarehouseSim.Task.IDLE)):
                WarehouseSim.Task.STORE:
                    task_samples["store"] += 1
                WarehouseSim.Task.PICK:
                    task_samples["pick"] += 1
                WarehouseSim.Task.SHIP:
                    task_samples["ship"] += 1
                _:
                    task_samples["idle"] += 1

        var key := String(sim.bottleneck().get("key", "stable"))
        if not bottleneck_samples.has(key):
            bottleneck_samples[key] = 0
        bottleneck_samples[key] += 1
        samples += 1

    var sample_divisor := float(maxi(1, samples))
    var worker_sample_count := float(maxi(1, samples * maxi(1, sim.workers.size())))
    var busy_samples := int(task_samples["store"]) + int(task_samples["pick"]) + int(task_samples["ship"])

    var dominant_key := "stable"
    var dominant_count := -1
    for key in bottleneck_samples.keys():
        var count := int(bottleneck_samples[key])
        if count > dominant_count:
            dominant_count = count
            dominant_key = String(key)

    return {
        "seconds": seconds,
        "shipments": sim.shipped - start_shipped,
        "shipments_per_min": snappedf(float(sim.shipped - start_shipped) * 60.0 / maxf(seconds, 0.1), 0.1),
        "inbound_avg": snappedf(inbound_sum / sample_divisor, 0.01),
        "packing_avg": snappedf(packing_sum / sample_divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / sample_divisor, 0.01),
        "orders_avg": snappedf(orders_sum / sample_divisor, 0.01),
        "rack_utilization_avg": snappedf(rack_util_sum / sample_divisor, 0.001),
        "worker_busy_ratio": snappedf(float(busy_samples) / worker_sample_count, 0.001),
        "worker_store_ratio": snappedf(float(task_samples["store"]) / worker_sample_count, 0.001),
        "worker_pick_ratio": snappedf(float(task_samples["pick"]) / worker_sample_count, 0.001),
        "worker_ship_ratio": snappedf(float(task_samples["ship"]) / worker_sample_count, 0.001),
        "worker_idle_ratio": snappedf(float(task_samples["idle"]) / worker_sample_count, 0.001),
        "dominant_bottleneck": dominant_key,
        "bottleneck_distribution": bottleneck_samples,
        "ending_bottleneck": String(sim.bottleneck().get("key", "unknown")),
    }


func _run_for(sim: WarehouseSim, seconds: float) -> void:
    var steps := int(ceil(seconds / STEP_SECONDS))
    for _i in steps:
        sim.step(STEP_SECONDS)
