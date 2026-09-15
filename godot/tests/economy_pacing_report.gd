extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const STEP_SECONDS := 0.1
const COMPARISON_SECONDS := 120.0
const WARMUP_SECONDS := 180.0
const BASE_SHIPMENT_VALUE := 500


func _init() -> void:
    var report := {
        "baseline_5m": _baseline_run(300.0),
        "forklift_affordability": _forklift_affordability(),
        "starting_capital": _starting_capital_snapshot(),
    }

    var warm: WarehouseSim = WarehouseSimScript.new()
    _run_for(warm, WARMUP_SECONDS)
    var seed := warm.save_data()

    var effects := {}
    for kind in [&"worker", &"rack", &"speed", &"packing", &"forklift"]:
        effects[String(kind)] = _compare_upgrade(seed, kind)
    report["upgrade_effects_120s"] = effects
    report["progression_chain"] = _progression_chain(seed)

    print("ECONOMY_PACING_REPORT " + JSON.stringify(report))

    var baseline: Dictionary = report["baseline_5m"]
    assert(int(baseline.get("shipments", 0)) > 0, "baseline economy must produce shipments")
    assert(int(baseline.get("revenue", 0)) > 0, "baseline economy must produce revenue")
    assert(
        float(baseline.get("shipments_per_min", 0.0)) >= 14.0
        and float(baseline.get("shipments_per_min", 0.0)) <= 18.0,
        "opening throughput must leave meaningful headroom without feeling stalled"
    )
    assert(
        String(baseline.get("ending_bottleneck", "")) == "inbound",
        "opening economy should expose inbound handling as the first major bottleneck"
    )

    var affordability: Dictionary = report["forklift_affordability"]
    var forklift_seconds := float(affordability.get("seconds", -1.0))
    assert(forklift_seconds >= 90.0, "first large automation must not be immediately affordable")
    assert(forklift_seconds <= 150.0, "first large automation must remain an early-session target")

    var starting_capital: Dictionary = report["starting_capital"]
    for kind in ["worker", "rack", "speed", "packing"]:
        assert(bool((starting_capital[kind] as Dictionary).get("affordable", false)), "%s should be an opening choice" % kind)
    assert(not bool((starting_capital["forklift"] as Dictionary).get("affordable", true)), "forklift must begin as an aspirational capital target")

    var worker_effect: Dictionary = effects["worker"]
    var speed_effect: Dictionary = effects["speed"]
    var rack_effect: Dictionary = effects["rack"]
    var forklift_effect: Dictionary = effects["forklift"]
    assert(int(worker_effect.get("shipment_delta", 0)) >= 5, "extra labor must materially improve the opening bottleneck")
    assert(int(speed_effect.get("shipment_delta", 0)) >= 3, "worker speed must materially improve the opening bottleneck")
    assert(
        float(rack_effect.get("variant_inbound_avg", 999.0)) < float(rack_effect.get("control_inbound_avg", 0.0)),
        "rack capacity must reduce inbound pressure even when it is not a direct revenue upgrade"
    )
    assert(int(forklift_effect.get("shipment_delta", 0)) >= 5, "forklift must create a material real-throughput gain")
    assert(
        float(forklift_effect.get("variant_inbound_avg", 999.0)) < float(forklift_effect.get("control_inbound_avg", 0.0)),
        "forklift must reduce inbound queue pressure"
    )
    assert(
        String(forklift_effect.get("variant_bottleneck", "")) == "packing",
        "solving inbound with forklift should expose packing as the next bottleneck"
    )

    var chain: Dictionary = report["progression_chain"]
    assert(int(chain.get("forklift_shipment_delta", 0)) >= 5, "progression chain must show forklift payoff")
    assert(String(chain.get("after_forklift_bottleneck", "")) == "packing", "forklift must hand off pressure to packing")
    assert(int(chain.get("packing_shipment_delta", 0)) >= 3, "packing investment must pay off after forklift creates packing pressure")

    print("Godot economy pacing report passed")
    quit(0)


func _baseline_run(seconds: float) -> Dictionary:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var start_money := sim.money
    var metrics := _sample_window(sim, seconds)
    metrics["revenue"] = sim.money - start_money
    metrics["ending_money"] = sim.money
    metrics["ending_rp"] = sim.research_rp
    metrics["ending_bottleneck"] = String(sim.bottleneck().get("key", "unknown"))
    return metrics


func _forklift_affordability() -> Dictionary:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var cost := sim.upgrade_cost(&"forklift")
    var max_seconds := 600.0
    var elapsed := 0.0
    var shipments_at_unlock := 0

    while sim.money < cost and elapsed < max_seconds:
        sim.step(STEP_SECONDS)
        elapsed += STEP_SECONDS
        shipments_at_unlock = sim.shipped

    return {
        "cost": cost,
        "seconds": snappedf(elapsed, 0.1),
        "shipments_needed": shipments_at_unlock,
        "money": sim.money,
        "bottleneck": String(sim.bottleneck().get("key", "unknown")),
    }


func _starting_capital_snapshot() -> Dictionary:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var result := {}
    for kind in [&"worker", &"rack", &"speed", &"packing", &"forklift"]:
        var cost := sim.upgrade_cost(kind)
        result[String(kind)] = {
            "cost": cost,
            "affordable": sim.money >= cost,
            "share_of_starting_cash": snappedf(float(cost) / float(maxi(1, sim.money)), 0.001),
        }
    return result


func _compare_upgrade(seed: Dictionary, kind: StringName) -> Dictionary:
    var control: WarehouseSim = WarehouseSimScript.new()
    var variant: WarehouseSim = WarehouseSimScript.new()
    assert(control.load_data(seed), "control seed must load")
    assert(variant.load_data(seed), "variant seed must load")

    control.money = 1000000
    variant.money = 1000000

    var cost := variant.upgrade_cost(kind)
    var purchase := variant.purchase_upgrade(kind)
    var control_metrics := _sample_window(control, COMPARISON_SECONDS)
    var variant_metrics := _sample_window(variant, COMPARISON_SECONDS)

    var control_shipments := int(control_metrics.get("shipments", 0))
    var variant_shipments := int(variant_metrics.get("shipments", 0))

    return {
        "purchased": bool(purchase.get("ok", false)),
        "cost": cost,
        "control_shipments": control_shipments,
        "variant_shipments": variant_shipments,
        "shipment_delta": variant_shipments - control_shipments,
        "revenue_delta": (variant_shipments - control_shipments) * BASE_SHIPMENT_VALUE,
        "control_inbound_avg": control_metrics.get("inbound_avg", 0.0),
        "variant_inbound_avg": variant_metrics.get("inbound_avg", 0.0),
        "control_packing_avg": control_metrics.get("packing_avg", 0.0),
        "variant_packing_avg": variant_metrics.get("packing_avg", 0.0),
        "control_outbound_avg": control_metrics.get("outbound_avg", 0.0),
        "variant_outbound_avg": variant_metrics.get("outbound_avg", 0.0),
        "control_bottleneck": control_metrics.get("ending_bottleneck", "unknown"),
        "variant_bottleneck": variant_metrics.get("ending_bottleneck", "unknown"),
    }


func _progression_chain(seed: Dictionary) -> Dictionary:
    var control: WarehouseSim = WarehouseSimScript.new()
    var forklift: WarehouseSim = WarehouseSimScript.new()
    assert(control.load_data(seed), "progression control seed must load")
    assert(forklift.load_data(seed), "progression forklift seed must load")
    control.money = 1000000
    forklift.money = 1000000
    assert(bool(forklift.purchase_upgrade(&"forklift").get("ok", false)), "progression forklift purchase must succeed")

    var control_metrics := _sample_window(control, COMPARISON_SECONDS)
    var forklift_metrics := _sample_window(forklift, COMPARISON_SECONDS)
    var post_forklift_seed := forklift.save_data()

    var packing_control: WarehouseSim = WarehouseSimScript.new()
    var packing_variant: WarehouseSim = WarehouseSimScript.new()
    assert(packing_control.load_data(post_forklift_seed), "post-forklift control seed must load")
    assert(packing_variant.load_data(post_forklift_seed), "post-forklift packing seed must load")
    packing_control.money = 1000000
    packing_variant.money = 1000000
    assert(bool(packing_variant.purchase_upgrade(&"packing").get("ok", false)), "post-forklift packing purchase must succeed")

    var packing_control_metrics := _sample_window(packing_control, COMPARISON_SECONDS)
    var packing_variant_metrics := _sample_window(packing_variant, COMPARISON_SECONDS)

    return {
        "before_bottleneck": String(control_metrics.get("ending_bottleneck", "unknown")),
        "forklift_control_shipments": int(control_metrics.get("shipments", 0)),
        "forklift_variant_shipments": int(forklift_metrics.get("shipments", 0)),
        "forklift_shipment_delta": int(forklift_metrics.get("shipments", 0)) - int(control_metrics.get("shipments", 0)),
        "after_forklift_bottleneck": String(forklift_metrics.get("ending_bottleneck", "unknown")),
        "post_forklift_packing_control_shipments": int(packing_control_metrics.get("shipments", 0)),
        "post_forklift_packing_variant_shipments": int(packing_variant_metrics.get("shipments", 0)),
        "packing_shipment_delta": int(packing_variant_metrics.get("shipments", 0)) - int(packing_control_metrics.get("shipments", 0)),
        "after_packing_bottleneck": String(packing_variant_metrics.get("ending_bottleneck", "unknown")),
    }


func _sample_window(sim: WarehouseSim, seconds: float) -> Dictionary:
    var start_shipped := sim.shipped
    var inbound_sum := 0.0
    var packing_sum := 0.0
    var outbound_sum := 0.0
    var samples := 0
    var steps := int(ceil(seconds / STEP_SECONDS))

    for _i in steps:
        sim.step(STEP_SECONDS)
        inbound_sum += float(sim.inbound_queue)
        packing_sum += float(sim.packing_queue)
        outbound_sum += float(sim.packed_queue)
        samples += 1

    var divisor := float(maxi(1, samples))
    return {
        "seconds": seconds,
        "shipments": sim.shipped - start_shipped,
        "shipments_per_min": snappedf(float(sim.shipped - start_shipped) * 60.0 / maxf(0.1, seconds), 0.1),
        "inbound_avg": snappedf(inbound_sum / divisor, 0.01),
        "packing_avg": snappedf(packing_sum / divisor, 0.01),
        "outbound_avg": snappedf(outbound_sum / divisor, 0.01),
        "ending_bottleneck": String(sim.bottleneck().get("key", "unknown")),
    }


func _run_for(sim: WarehouseSim, seconds: float) -> void:
    var steps := int(ceil(seconds / STEP_SECONDS))
    for _i in steps:
        sim.step(STEP_SECONDS)
