extends "res://domain/rank3_warehouse_sim.gd"
class_name Rank3InboundCarrierSim

const SAVE_SCHEMA_INBOUND_CARRIER := 7
const INBOUND_CARRIER_PROGRAM_COST := 30000
const INBOUND_CARRIER_INTERVAL_MULTIPLIER := 0.85

var inbound_carrier_program_unlocked: bool = false


func inbound_carrier_program_info() -> Dictionary:
    return {
        "kind": "inbound_carrier_program",
        "label": "高頻度入荷プログラム",
        "effect": "定期入荷 +18%｜入荷間隔 x%.2f｜受入混雑リスク増" % INBOUND_CARRIER_INTERVAL_MULTIPLIER,
        "cost": INBOUND_CARRIER_PROGRAM_COST,
        "owned": inbound_carrier_program_unlocked,
        "requires_annex": true,
        "annex_ready": receiving_annex_unlocked,
        "interval_multiplier": INBOUND_CARRIER_INTERVAL_MULTIPLIER,
    }


func inbound_carrier_program_cost() -> int:
    return INBOUND_CARRIER_PROGRAM_COST


func purchase_inbound_carrier_program() -> Dictionary:
    if facility_rank < 3:
        return {"ok": false, "reason": "rank", "cost": INBOUND_CARRIER_PROGRAM_COST}
    if not receiving_annex_unlocked:
        return {"ok": false, "reason": "annex", "cost": INBOUND_CARRIER_PROGRAM_COST}
    if inbound_carrier_program_unlocked:
        return {"ok": false, "reason": "owned", "cost": INBOUND_CARRIER_PROGRAM_COST}
    if money < INBOUND_CARRIER_PROGRAM_COST:
        return {"ok": false, "reason": "funds", "cost": INBOUND_CARRIER_PROGRAM_COST}

    money -= INBOUND_CARRIER_PROGRAM_COST
    inbound_carrier_program_unlocked = true
    var before := _measurement.begin_investment(&"inbound_carrier_program", INBOUND_CARRIER_PROGRAM_COST, sim_time)
    _emit("inbound_carrier_program_purchased", {
        "kind": "inbound_carrier_program",
        "label": "高頻度入荷プログラム",
        "cost": INBOUND_CARRIER_PROGRAM_COST,
        "interval_multiplier": INBOUND_CARRIER_INTERVAL_MULTIPLIER,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {
        "ok": true,
        "cost": INBOUND_CARRIER_PROGRAM_COST,
        "interval_multiplier": INBOUND_CARRIER_INTERVAL_MULTIPLIER,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
    }


func equipment_asset_value() -> int:
    var value := super.equipment_asset_value()
    if inbound_carrier_program_unlocked:
        value += INBOUND_CARRIER_PROGRAM_COST
    return value


func snapshot() -> Dictionary:
    var data: Dictionary = super.snapshot()
    data["schema_version"] = SAVE_SCHEMA_INBOUND_CARRIER
    data["inbound_carrier_program_unlocked"] = inbound_carrier_program_unlocked
    data["inbound_carrier_interval_multiplier"] = (
        INBOUND_CARRIER_INTERVAL_MULTIPLIER if inbound_carrier_program_unlocked else 1.0
    )
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_INBOUND_CARRIER
    data["inbound_carrier_program_unlocked"] = inbound_carrier_program_unlocked
    return data


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA_INBOUND_CARRIER:
        return false

    var base_data: Dictionary = data.duplicate(true)
    base_data["schema_version"] = mini(source_schema, Rank3WarehouseSim.SAVE_SCHEMA_RANK3)
    if not super.load_data(base_data):
        return false

    inbound_carrier_program_unlocked = false
    if source_schema >= SAVE_SCHEMA_INBOUND_CARRIER and facility_rank >= 3 and receiving_annex_unlocked:
        inbound_carrier_program_unlocked = bool(data.get("inbound_carrier_program_unlocked", false))

    if source_schema < SAVE_SCHEMA_INBOUND_CARRIER:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_INBOUND_CARRIER})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_INBOUND_CARRIER})
    return true


func _current_inbound_interval() -> float:
    var base_interval := super._current_inbound_interval()
    if facility_rank >= 3 and inbound_carrier_program_unlocked:
        return base_interval * INBOUND_CARRIER_INTERVAL_MULTIPLIER
    return base_interval
