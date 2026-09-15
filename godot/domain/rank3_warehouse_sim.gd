extends "res://domain/workload_warehouse_sim.gd"
class_name Rank3WarehouseSim

const SAVE_SCHEMA_RANK3 := 5
const RANK3_ZONES_REQUIRED := 3
const RANK3_MIN_ASSETS := 200000
const RANK3_MIN_THROUGHPUT := 6.0

# Provisional first Rank 3 capital step. The capacity value comes from the
# deterministic intake-growth scout; price remains subject to pacing review.
const RECEIVING_ANNEX_COST := 24000
const RECEIVING_ANNEX_CAPACITY_BONUS := 14

var receiving_annex_unlocked: bool = false


func step(real_dt: float) -> void:
    super.step(real_dt)
    if facility_rank == 2 and _rank3_gate_satisfied():
        _rank_up_to_fulfillment_center()


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
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_RANK3
    data["receiving_annex_unlocked"] = receiving_annex_unlocked
    return data


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA_RANK3:
        return false

    var base_data: Dictionary = data.duplicate(true)
    base_data["schema_version"] = mini(source_schema, 4)
    if not super.load_data(base_data):
        return false

    if source_schema >= SAVE_SCHEMA_RANK3:
        facility_rank = clampi(int(data.get("facility_rank", facility_rank)), 1, 3)
        receiving_annex_unlocked = bool(data.get("receiving_annex_unlocked", false)) and facility_rank >= 3
    else:
        receiving_annex_unlocked = false

    if source_schema < SAVE_SCHEMA_RANK3:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_RANK3})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_RANK3})
    return true


func _current_inbound_limit() -> int:
    var base_limit := super._current_inbound_limit()
    if receiving_annex_unlocked:
        return base_limit + RECEIVING_ANNEX_CAPACITY_BONUS
    return base_limit


func _rank3_gate_satisfied() -> bool:
    var readiness := rank3_readiness()
    return bool(readiness.get("ready", false))


func _rank_up_to_fulfillment_center() -> void:
    if facility_rank >= 3:
        return
    facility_rank = 3
    _emit("rank_up", {
        "rank": facility_rank,
        "name": "Fulfillment Center",
        "worker_count": worker_count,
    })
