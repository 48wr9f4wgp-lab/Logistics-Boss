extends "res://domain/rank3_inbound_carrier_sim.gd"
class_name FlotraV2Sim

const SAVE_SCHEMA_V2 := 8

const PROJECT_RACK_WING := &"rack_wing"
const PROJECT_SECOND_PACKING_BENCH := &"second_packing_bench"
const PROJECT_WORKER_HIRE := &"worker_hire"
const PROJECT_FORKLIFT := &"forklift_project"
const PROJECT_WAREHOUSE_EXPANSION := &"warehouse_expansion"

const RACK_WING_COST := 2500
const SECOND_PACKING_BENCH_COST := 4500
const WORKER_HIRE_COST := 3500
const FORKLIFT_PROJECT_COST := 20000
const WAREHOUSE_EXPANSION_COST := 10000

var rank1_projects: Dictionary = {
    "rack_wing": false,
    "second_packing_bench": false,
    "worker_hire": false,
    "forklift_project": false,
    "warehouse_expansion": false,
}


func rank1_project_kinds() -> Array[StringName]:
    return [
        PROJECT_RACK_WING,
        PROJECT_SECOND_PACKING_BENCH,
        PROJECT_WORKER_HIRE,
        PROJECT_FORKLIFT,
    ]


func rank1_project_info(kind: StringName) -> Dictionary:
    match kind:
        PROJECT_RACK_WING:
            return {
                "kind": String(kind),
                "label": "Rack Wing",
                "zone": "storage",
                "strength": "保管容量 +4",
                "effect": "STORAGEに新しいRack Wingを増設",
                "cost": RACK_WING_COST,
                "owned": rank1_project_owned(kind),
            }
        PROJECT_SECOND_PACKING_BENCH:
            return {
                "kind": String(kind),
                "label": "Second Packing Bench",
                "zone": "packing",
                "strength": "梱包を2箱同時処理",
                "effect": "PACKINGに2台目の作業台を増設",
                "cost": SECOND_PACKING_BENCH_COST,
                "owned": rank1_project_owned(kind),
            }
        PROJECT_WORKER_HIRE:
            return {
                "kind": String(kind),
                "label": "Worker Hire",
                "zone": "operations",
                "strength": "全体要員 +1",
                "effect": "追加Workerを1名採用",
                "cost": WORKER_HIRE_COST,
                "owned": rank1_project_owned(kind),
            }
        PROJECT_FORKLIFT:
            return {
                "kind": String(kind),
                "label": "Forklift Project",
                "zone": "inbound",
                "strength": "入荷→保管を自動搬送",
                "effect": "Workerを搬送から解放",
                "cost": FORKLIFT_PROJECT_COST,
                "owned": rank1_project_owned(kind),
            }
        PROJECT_WAREHOUSE_EXPANSION:
            return {
                "kind": String(kind),
                "label": "Warehouse Expansion",
                "zone": "management",
                "strength": "RANK 2 WAREHOUSEへ拡張",
                "effect": "Small Depotを物理的に拡張",
                "cost": WAREHOUSE_EXPANSION_COST,
                "owned": facility_rank >= 2 or rank1_project_owned(kind),
            }
    return {}


func rank1_project_owned(kind: StringName) -> bool:
    if kind == PROJECT_WAREHOUSE_EXPANSION and facility_rank >= 2:
        return true
    return bool(rank1_projects.get(String(kind), false))


func rank1_projects_completed() -> int:
    var count := 0
    for kind in rank1_project_kinds():
        if rank1_project_owned(kind):
            count += 1
    return count


func rank1_project_for_zone(zone_key: String) -> StringName:
    match zone_key:
        "inbound":
            return PROJECT_FORKLIFT
        "storage":
            return PROJECT_RACK_WING
        "packing":
            return PROJECT_SECOND_PACKING_BENCH
    return &""


func rank1_expansion_readiness() -> Dictionary:
    var projects := rank1_projects_completed()
    var rating_ready := logistics_rating >= LogisticsProgression.RANK2_RATING
    var projects_ready := projects >= rank1_project_kinds().size()
    var funds_ready := money >= WAREHOUSE_EXPANSION_COST
    return {
        "ready": facility_rank >= 2 or (projects_ready and rating_ready and funds_ready),
        "projects": projects,
        "projects_required": rank1_project_kinds().size(),
        "rating": logistics_rating,
        "rating_required": LogisticsProgression.RANK2_RATING,
        "cash": money,
        "cost": WAREHOUSE_EXPANSION_COST,
        "projects_ready": projects_ready,
        "rating_ready": rating_ready,
        "funds_ready": funds_ready,
    }


func purchase_rank1_project(kind: StringName) -> Dictionary:
    if facility_rank != 1:
        return {"ok": false, "reason": "rank", "cost": rank1_project_cost(kind)}
    if kind not in rank1_project_kinds():
        return {"ok": false, "reason": "unknown", "cost": 0}
    if rank1_project_owned(kind):
        return {"ok": false, "reason": "owned", "cost": rank1_project_cost(kind)}

    var cost := rank1_project_cost(kind)
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}

    money -= cost
    rank1_projects[String(kind)] = true

    match kind:
        PROJECT_RACK_WING:
            rack_level = maxi(rack_level, 1)
            rack_capacity = maxi(rack_capacity, 12)
        PROJECT_SECOND_PACKING_BENCH:
            pass
        PROJECT_WORKER_HIRE:
            worker_count = maxi(worker_count, 4)
            _sync_worker_roster()
        PROJECT_FORKLIFT:
            forklift_unlocked = true

    var measurement_kind := StringName("rank1_%s" % String(kind))
    var before := _measurement.begin_investment(measurement_kind, cost, sim_time)
    var info := rank1_project_info(kind)
    _emit("rank1_project_purchased", {
        "kind": String(kind),
        "measurement_kind": String(measurement_kind),
        "label": String(info.get("label", String(kind))),
        "zone": String(info.get("zone", "")),
        "cost": cost,
        "projects_completed": rank1_projects_completed(),
        "projects_required": rank1_project_kinds().size(),
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {
        "ok": true,
        "kind": String(kind),
        "cost": cost,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    }


func purchase_warehouse_expansion() -> Dictionary:
    if facility_rank >= 2:
        return {"ok": false, "reason": "owned", "cost": WAREHOUSE_EXPANSION_COST}
    var readiness := rank1_expansion_readiness()
    if not bool(readiness.get("projects_ready", false)):
        return {"ok": false, "reason": "projects", "cost": WAREHOUSE_EXPANSION_COST, "readiness": readiness}
    if not bool(readiness.get("rating_ready", false)):
        return {"ok": false, "reason": "rating", "cost": WAREHOUSE_EXPANSION_COST, "readiness": readiness}
    if money < WAREHOUSE_EXPANSION_COST:
        return {"ok": false, "reason": "funds", "cost": WAREHOUSE_EXPANSION_COST, "readiness": readiness}

    money -= WAREHOUSE_EXPANSION_COST
    rank1_projects[String(PROJECT_WAREHOUSE_EXPANSION)] = true
    _emit("warehouse_expansion_purchased", {
        "kind": String(PROJECT_WAREHOUSE_EXPANSION),
        "label": "Warehouse Expansion",
        "cost": WAREHOUSE_EXPANSION_COST,
    })
    super._rank_up_to_warehouse()
    return {"ok": true, "cost": WAREHOUSE_EXPANSION_COST, "rank": facility_rank}


func rank1_project_cost(kind: StringName) -> int:
    match kind:
        PROJECT_RACK_WING:
            return RACK_WING_COST
        PROJECT_SECOND_PACKING_BENCH:
            return SECOND_PACKING_BENCH_COST
        PROJECT_WORKER_HIRE:
            return WORKER_HIRE_COST
        PROJECT_FORKLIFT:
            return FORKLIFT_PROJECT_COST
        PROJECT_WAREHOUSE_EXPANSION:
            return WAREHOUSE_EXPANSION_COST
    return 0


func _packing_capacity() -> int:
    var capacity := super._packing_capacity()
    if rank1_project_owned(PROJECT_SECOND_PACKING_BENCH):
        capacity = maxi(capacity, 2)
    return capacity


func _rank_up_to_warehouse() -> void:
    # Core Experience v2 makes Rank 2 a deliberate facility project.
    # Rating still matters, but it no longer silently promotes from a contract.
    if not rank1_project_owned(PROJECT_WAREHOUSE_EXPANSION):
        _emit("warehouse_expansion_readiness_changed", rank1_expansion_readiness())
        return
    super._rank_up_to_warehouse()


func equipment_asset_value() -> int:
    var value := super.equipment_asset_value()
    # Rack Wing / Worker Hire / Forklift are already represented by legacy
    # authoritative asset fields counted by super.
    if rank1_project_owned(PROJECT_SECOND_PACKING_BENCH):
        value += SECOND_PACKING_BENCH_COST
    if rank1_project_owned(PROJECT_WAREHOUSE_EXPANSION):
        value += WAREHOUSE_EXPANSION_COST
    return value


func snapshot() -> Dictionary:
    var data: Dictionary = super.snapshot()
    data["schema_version"] = SAVE_SCHEMA_V2
    data["rank1_projects"] = rank1_projects.duplicate(true)
    data["rank1_projects_completed"] = rank1_projects_completed()
    data["rank1_expansion_readiness"] = rank1_expansion_readiness()
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_V2
    data["rank1_projects"] = rank1_projects.duplicate(true)
    return data


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA_V2:
        return false

    var base_data: Dictionary = data.duplicate(true)
    base_data["schema_version"] = mini(source_schema, Rank3InboundCarrierSim.SAVE_SCHEMA_INBOUND_CARRIER)
    if not super.load_data(base_data):
        return false

    rank1_projects = {
        "rack_wing": false,
        "second_packing_bench": false,
        "worker_hire": false,
        "forklift_project": false,
        "warehouse_expansion": false,
    }

    if source_schema >= SAVE_SCHEMA_V2:
        var saved_projects: Variant = data.get("rank1_projects", {})
        if saved_projects is Dictionary:
            for key in rank1_projects.keys():
                rank1_projects[key] = bool((saved_projects as Dictionary).get(key, false))
    else:
        # Migration preserves prior player investment instead of removing it.
        rank1_projects["rack_wing"] = rack_level > 0
        rank1_projects["second_packing_bench"] = pack_level > 0
        rank1_projects["worker_hire"] = worker_count > 3
        rank1_projects["forklift_project"] = forklift_unlocked
        rank1_projects["warehouse_expansion"] = facility_rank >= 2

    if facility_rank >= 2:
        rank1_projects["warehouse_expansion"] = true
        rank1_projects["worker_hire"] = true
    if bool(rank1_projects.get("rack_wing", false)):
        rack_level = maxi(rack_level, 1)
        rack_capacity = maxi(rack_capacity, 12)
    if bool(rank1_projects.get("worker_hire", false)):
        worker_count = maxi(worker_count, 4)
        _sync_worker_roster()
    if bool(rank1_projects.get("forklift_project", false)):
        forklift_unlocked = true

    if source_schema < SAVE_SCHEMA_V2:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_V2})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_V2})
    return true
