extends "res://domain/workload_warehouse_sim.gd"
class_name Rank3WarehouseSim

const SAVE_SCHEMA_RANK3 := 6
const RANK3_ZONES_REQUIRED := 3
const RANK3_MIN_ASSETS := 200000
const RANK3_MIN_THROUGHPUT := 6.0

const ROUTE_BALANCED := "balanced"
const ROUTE_EXPRESS := "express"
const ROUTE_CONSOLIDATED := "consolidated"

const BALANCED_SHIPMENT_VALUE := BASE_SHIPMENT_VALUE
const EXPRESS_SHIPMENT_VALUE := 410
const CONSOLIDATED_SHIPMENT_VALUE := 620
const BALANCED_DISPATCH_DURATION := 3.0
const EXPRESS_DISPATCH_DURATION := 1.65
const CONSOLIDATED_DISPATCH_DURATION := 6.8
const CONSOLIDATED_BATCH_SIZE := 4

# Provisional first Rank 3 capital step. The capacity value comes from the
# deterministic intake-growth scout; price remains subject to pacing review.
const RECEIVING_ANNEX_COST := 24000
const RECEIVING_ANNEX_CAPACITY_BONUS := 14

var receiving_annex_unlocked: bool = false
var active_routing_mode: String = ROUTE_BALANCED


func step(real_dt: float) -> void:
    var measurement_dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    super.step(real_dt)
    if measurement_dt > 0.0:
        _measurement.record_orders(sim_time, measurement_dt, open_orders)
    if facility_rank == 2 and _rank3_gate_satisfied():
        _rank_up_to_fulfillment_center()


func routing_modes() -> Array[String]:
    return [ROUTE_BALANCED, ROUTE_EXPRESS, ROUTE_CONSOLIDATED]


func routing_profile(mode: String = "") -> Dictionary:
    var route := active_routing_mode if mode.is_empty() else mode
    match route:
        ROUTE_EXPRESS:
            return {
                "mode": ROUTE_EXPRESS,
                "label": "Express Dispatch",
                "summary": "出荷を高速化｜1個 ¥%d｜利益率低下" % EXPRESS_SHIPMENT_VALUE,
                "batch_size": 1,
                "dispatch_duration": EXPRESS_DISPATCH_DURATION,
                "unit_value": EXPRESS_SHIPMENT_VALUE,
            }
        ROUTE_CONSOLIDATED:
            return {
                "mode": ROUTE_CONSOLIDATED,
                "label": "Consolidated Linehaul",
                "summary": "%d個まとめ出荷｜1個 ¥%d｜梱包済み在庫が溜まりやすい" % [CONSOLIDATED_BATCH_SIZE, CONSOLIDATED_SHIPMENT_VALUE],
                "batch_size": CONSOLIDATED_BATCH_SIZE,
                "dispatch_duration": CONSOLIDATED_DISPATCH_DURATION,
                "unit_value": CONSOLIDATED_SHIPMENT_VALUE,
            }
        _:
            return {
                "mode": ROUTE_BALANCED,
                "label": "Balanced Parcel",
                "summary": "標準出荷｜1個 ¥%d｜基準ルート" % BALANCED_SHIPMENT_VALUE,
                "batch_size": 1,
                "dispatch_duration": BALANCED_DISPATCH_DURATION,
                "unit_value": BALANCED_SHIPMENT_VALUE,
            }


func routing_summary() -> Dictionary:
    var profile := routing_profile()
    profile["can_dispatch"] = _routing_can_dispatch()
    profile["packed_queue"] = packed_queue
    return profile


func set_routing_mode(next_mode: String) -> Dictionary:
    if facility_rank < 3:
        return {"ok": false, "reason": "rank"}
    if next_mode not in routing_modes():
        return {"ok": false, "reason": "unknown"}
    if active_routing_mode == next_mode:
        return {"ok": false, "reason": "same"}

    var before := _measurement.begin_investment(StringName("routing_%s" % next_mode), 0, sim_time)
    active_routing_mode = next_mode
    var profile := routing_profile()
    _emit("routing_changed", {
        "mode": active_routing_mode,
        "label": String(profile.get("label", active_routing_mode)),
        "summary": String(profile.get("summary", "")),
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {
        "ok": true,
        "mode": active_routing_mode,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    }


func equipment_asset_value() -> int:
    var value := 0

    # Value the currently owned operating asset base rather than contract
    # history. Rank 2's granted crew is still an owned labor-capacity asset.
    for worker_index in range(maxi(0, worker_count - 3)):
        value += int(3500 * pow(2.0, worker_index))
    for level in range(rack_level):
        value += int(2500 * pow(2.0, level))
    for level in range(speed_level):
        value += int(4000 * pow(2.0, level))
    for level in range(pack_level):
        value += int(4500 * pow(2.0, level))
    if forklift_unlocked:
        value += CapitalCatalog.FORKLIFT_COST

    for kind in _rank2_facilities.all_kinds():
        if bool(facilities.get(String(kind), false)):
            value += _rank2_facilities.cost(kind)

    if receiving_annex_unlocked:
        value += RECEIVING_ANNEX_COST
    return value


func rank3_readiness() -> Dictionary:
    var zones := expansion_zones_completed()
    var assets := equipment_asset_value()
    var throughput := throughput_per_minute()
    var ready := facility_rank >= 3 or (
        zones >= RANK3_ZONES_REQUIRED
        and assets >= RANK3_MIN_ASSETS
        and throughput >= RANK3_MIN_THROUGHPUT
    )
    return {
        "ready": ready,
        "rank": facility_rank,
        "zones": zones,
        "zones_required": RANK3_ZONES_REQUIRED,
        "assets": assets,
        "assets_required": RANK3_MIN_ASSETS,
        "throughput": throughput,
        "throughput_required": RANK3_MIN_THROUGHPUT,
    }


func receiving_annex_info() -> Dictionary:
    return {
        "kind": "receiving_annex",
        "label": "受入増設棟",
        "effect": "入荷受入上限 +%d｜ピーク時の取りこぼしを削減" % RECEIVING_ANNEX_CAPACITY_BONUS,
        "cost": RECEIVING_ANNEX_COST,
        "owned": receiving_annex_unlocked,
    }


func receiving_annex_cost() -> int:
    return RECEIVING_ANNEX_COST


func purchase_receiving_annex() -> Dictionary:
    if facility_rank < 3:
        return {"ok": false, "reason": "rank", "cost": RECEIVING_ANNEX_COST}
    if receiving_annex_unlocked:
        return {"ok": false, "reason": "owned", "cost": RECEIVING_ANNEX_COST}
    if money < RECEIVING_ANNEX_COST:
        return {"ok": false, "reason": "funds", "cost": RECEIVING_ANNEX_COST}

    money -= RECEIVING_ANNEX_COST
    receiving_annex_unlocked = true
    var before := _measurement.begin_investment(&"receiving_annex", RECEIVING_ANNEX_COST, sim_time)
    _emit("receiving_annex_purchased", {
        "kind": "receiving_annex",
        "label": "受入増設棟",
        "cost": RECEIVING_ANNEX_COST,
        "capacity_bonus": RECEIVING_ANNEX_CAPACITY_BONUS,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {
        "ok": true,
        "cost": RECEIVING_ANNEX_COST,
        "capacity_bonus": RECEIVING_ANNEX_CAPACITY_BONUS,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
    }


func snapshot() -> Dictionary:
    var data: Dictionary = super.snapshot()
    data["schema_version"] = SAVE_SCHEMA_RANK3
    data["receiving_annex_unlocked"] = receiving_annex_unlocked
    data["receiving_annex_capacity_bonus"] = RECEIVING_ANNEX_CAPACITY_BONUS if receiving_annex_unlocked else 0
    data["equipment_asset_value"] = equipment_asset_value()
    data["rank3_readiness"] = rank3_readiness()
    data["active_routing_mode"] = active_routing_mode
    data["routing"] = routing_summary()
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_RANK3
    data["receiving_annex_unlocked"] = receiving_annex_unlocked
    data["active_routing_mode"] = active_routing_mode
    return data


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA_RANK3:
        return false

    var base_data: Dictionary = data.duplicate(true)
    base_data["schema_version"] = mini(source_schema, 4)
    if not super.load_data(base_data):
        return false

    if source_schema >= 5:
        facility_rank = clampi(int(data.get("facility_rank", facility_rank)), 1, 3)
        receiving_annex_unlocked = bool(data.get("receiving_annex_unlocked", false)) and facility_rank >= 3
    else:
        receiving_annex_unlocked = false

    active_routing_mode = ROUTE_BALANCED
    if source_schema >= SAVE_SCHEMA_RANK3 and facility_rank >= 3:
        var saved_route := String(data.get("active_routing_mode", ROUTE_BALANCED))
        if saved_route in routing_modes():
            active_routing_mode = saved_route

    if source_schema < SAVE_SCHEMA_RANK3:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_RANK3})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_RANK3})
    return true


func _current_inbound_limit() -> int:
    var base_limit := super._current_inbound_limit()
    if receiving_annex_unlocked:
        return base_limit + RECEIVING_ANNEX_CAPACITY_BONUS
    return base_limit


func _choose_task_for_worker(worker: Dictionary) -> int:
    if facility_rank >= 3 and String(worker.get("role", "")) == "ship":
        return Task.SHIP if _routing_can_dispatch() else Task.IDLE
    return super._choose_task_for_worker(worker)


func _start_task(worker: Dictionary, task: int) -> void:
    if task != Task.SHIP or facility_rank < 3:
        super._start_task(worker, task)
        return

    var profile := routing_profile()
    var batch_size := maxi(1, int(profile.get("batch_size", 1)))
    if packed_queue < batch_size:
        return

    packed_queue -= batch_size
    var duration := maxf(0.25, float(profile.get("dispatch_duration", BALANCED_DISPATCH_DURATION))) / maxf(0.2, worker_speed)
    worker["task"] = int(Task.SHIP)
    worker["source"] = "packing"
    worker["target"] = "outbound"
    worker["duration"] = duration
    worker["remaining"] = duration
    worker["progress"] = 0.0
    worker["routing_mode"] = String(profile.get("mode", ROUTE_BALANCED))
    worker["routing_batch"] = batch_size
    worker["routing_unit_value"] = int(profile.get("unit_value", BASE_SHIPMENT_VALUE))

    _emit("worker_task_started", {
        "worker_id": int(worker["id"]),
        "task": int(task),
        "source": "packing",
        "target": "outbound",
        "duration": duration,
        "routing_mode": String(worker["routing_mode"]),
        "batch": batch_size,
    })


func _complete_task(worker: Dictionary) -> void:
    var task := int(worker.get("task", Task.IDLE))
    if task != Task.SHIP or not worker.has("routing_batch"):
        super._complete_task(worker)
        return

    var batch_size := maxi(1, int(worker.get("routing_batch", 1)))
    var unit_value := maxi(0, int(worker.get("routing_unit_value", BASE_SHIPMENT_VALUE)))
    var total_value := unit_value * batch_size
    var shipped_before := shipped

    shipped += batch_size
    money += total_value
    for _index in range(batch_size):
        _shipment_times.append(sim_time)
    var rp_before := floori(float(shipped_before) / 5.0)
    var rp_after := floori(float(shipped) / 5.0)
    research_rp += maxi(0, rp_after - rp_before)

    _emit("shipment", {
        "value": total_value,
        "unit_value": unit_value,
        "count": batch_size,
        "shipped": shipped,
        "money": money,
        "routing_mode": String(worker.get("routing_mode", ROUTE_BALANCED)),
    })
    if batch_size > 1:
        for _index in range(batch_size - 1):
            _measurement.record_shipment(sim_time, 0)

    worker["task"] = int(Task.IDLE)
    worker["source"] = "center"
    worker["target"] = "center"
    worker["duration"] = 0.0
    worker["remaining"] = 0.0
    worker["progress"] = 0.0
    worker.erase("routing_mode")
    worker.erase("routing_batch")
    worker.erase("routing_unit_value")


func _routing_can_dispatch() -> bool:
    if facility_rank < 3:
        return packed_queue > 0
    var required := maxi(1, int(routing_profile().get("batch_size", 1)))
    return packed_queue >= required


func _rank3_gate_satisfied() -> bool:
    var readiness := rank3_readiness()
    return bool(readiness.get("ready", false))


func _rank_up_to_fulfillment_center() -> void:
    if facility_rank >= 3:
        return
    facility_rank = 3
    active_routing_mode = ROUTE_BALANCED
    _emit("rank_up", {
        "rank": facility_rank,
        "name": "Fulfillment Center",
        "worker_count": worker_count,
    })
