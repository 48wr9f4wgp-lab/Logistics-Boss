extends "res://domain/rank3_inbound_carrier_sim.gd"
class_name FlotraV2Sim

const SAVE_SCHEMA_RANK1_V2 := 8
const SAVE_SCHEMA_V2 := 9

const STAFF_ZONE_INBOUND := "inbound"
const STAFF_ZONE_PICKING := "picking"
const STAFF_ZONE_SHIPPING := "shipping"
const DIRECT_STAFFING_MIN_PER_ZONE := 1

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

var zone_staffing: Dictionary = {
    STAFF_ZONE_INBOUND: 2,
    STAFF_ZONE_PICKING: 2,
    STAFF_ZONE_SHIPPING: 1,
}
var _direct_staffing_active := false


func direct_staffing_zone_keys() -> Array[String]:
    return [STAFF_ZONE_INBOUND, STAFF_ZONE_PICKING, STAFF_ZONE_SHIPPING]


func staffing_zone_for_warehouse_zone(zone_key: String) -> String:
    match zone_key:
        "inbound", "storage":
            return STAFF_ZONE_INBOUND
        "picking":
            return STAFF_ZONE_PICKING
        "shipping":
            return STAFF_ZONE_SHIPPING
    return ""


func direct_staffing_summary() -> Dictionary:
    _normalize_zone_staffing()
    return {
        "enabled": facility_rank >= 2 and _direct_staffing_active,
        STAFF_ZONE_INBOUND: int(zone_staffing.get(STAFF_ZONE_INBOUND, 0)),
        STAFF_ZONE_PICKING: int(zone_staffing.get(STAFF_ZONE_PICKING, 0)),
        STAFF_ZONE_SHIPPING: int(zone_staffing.get(STAFF_ZONE_SHIPPING, 0)),
        "total": worker_count,
        "cooldown": staffing_cooldown,
        "minimum_per_zone": DIRECT_STAFFING_MIN_PER_ZONE,
    }


func reassign_zone_staffing(from_zone: String, to_zone: String) -> Dictionary:
    if facility_rank < 2:
        return {"ok": false, "reason": "rank"}
    if not _direct_staffing_active:
        _activate_direct_staffing_from_current_roles()
    if from_zone not in direct_staffing_zone_keys() or to_zone not in direct_staffing_zone_keys():
        return {"ok": false, "reason": "unknown"}
    if from_zone == to_zone:
        return {"ok": false, "reason": "same"}
    if staffing_cooldown > 0.0:
        return {"ok": false, "reason": "cooldown", "remaining": staffing_cooldown}

    _normalize_zone_staffing()
    var from_count := int(zone_staffing.get(from_zone, 0))
    if from_count <= DIRECT_STAFFING_MIN_PER_ZONE:
        return {
            "ok": false,
            "reason": "minimum",
            "zone": from_zone,
            "minimum": DIRECT_STAFFING_MIN_PER_ZONE,
        }

    zone_staffing[from_zone] = from_count - 1
    zone_staffing[to_zone] = int(zone_staffing.get(to_zone, 0)) + 1
    staffing_plan = "direct"
    staffing_cooldown = LogisticsProgression.STAFFING_COOLDOWN_SECONDS
    _apply_staffing_plan()

    var summary := direct_staffing_summary()
    _emit("staffing_changed", {
        "mode": "direct",
        "from_zone": from_zone,
        "to_zone": to_zone,
        "inbound": int(summary.get(STAFF_ZONE_INBOUND, 0)),
        "picking": int(summary.get(STAFF_ZONE_PICKING, 0)),
        "shipping": int(summary.get(STAFF_ZONE_SHIPPING, 0)),
        "cooldown": staffing_cooldown,
    })
    return {
        "ok": true,
        "from_zone": from_zone,
        "to_zone": to_zone,
        "cooldown": staffing_cooldown,
        "staffing": summary,
    }


func set_staffing_plan(next_plan: String) -> Dictionary:
    # Compatibility path for old saves/tests. Player-facing v2 UI never shows
    # these presets; converting one simply seeds the equivalent direct counts.
    if facility_rank < 2:
        return {"ok": false, "reason": "rank"}
    if next_plan not in ["receiving", "balanced", "picking", "dock", "shipping"]:
        return {"ok": false, "reason": "unknown"}
    if staffing_cooldown > 0.0:
        return {"ok": false, "reason": "cooldown", "remaining": staffing_cooldown}

    var next_staffing := _legacy_plan_to_zone_staffing(next_plan)
    _normalize_staffing_dictionary(next_staffing)
    if _same_zone_staffing(next_staffing):
        return {"ok": false, "reason": "same"}

    zone_staffing = next_staffing
    _direct_staffing_active = true
    staffing_plan = "direct"
    staffing_cooldown = LogisticsProgression.STAFFING_COOLDOWN_SECONDS
    _apply_staffing_plan()
    return {
        "ok": true,
        "deprecated_preset": next_plan,
        "cooldown": staffing_cooldown,
        "staffing": direct_staffing_summary(),
    }


func _legacy_plan_to_zone_staffing(plan: String) -> Dictionary:
    var roles := _progression.staffing_roles(plan)
    var result := {
        STAFF_ZONE_INBOUND: 0,
        STAFF_ZONE_PICKING: 0,
        STAFF_ZONE_SHIPPING: 0,
    }
    for role in roles:
        match role:
            "store":
                result[STAFF_ZONE_INBOUND] = int(result[STAFF_ZONE_INBOUND]) + 1
            "pick":
                result[STAFF_ZONE_PICKING] = int(result[STAFF_ZONE_PICKING]) + 1
            "ship":
                result[STAFF_ZONE_SHIPPING] = int(result[STAFF_ZONE_SHIPPING]) + 1
    return result


func _activate_direct_staffing_from_current_roles() -> void:
    var current := super.staffing_summary()
    zone_staffing = {
        STAFF_ZONE_INBOUND: maxi(DIRECT_STAFFING_MIN_PER_ZONE, int(current.get("store", 0))),
        STAFF_ZONE_PICKING: maxi(DIRECT_STAFFING_MIN_PER_ZONE, int(current.get("pick", 0))),
        STAFF_ZONE_SHIPPING: maxi(DIRECT_STAFFING_MIN_PER_ZONE, int(current.get("ship", 0))),
    }
    _direct_staffing_active = true
    staffing_plan = "direct"
    _normalize_zone_staffing()
    _apply_staffing_plan()


func _apply_staffing_plan() -> void:
    if facility_rank < 2:
        return
    if not _direct_staffing_active:
        super._apply_staffing_plan()
        return

    _normalize_zone_staffing()
    var roles: Array[String] = []
    for _index in int(zone_staffing.get(STAFF_ZONE_INBOUND, 0)):
        roles.append("store")
    for _index in int(zone_staffing.get(STAFF_ZONE_PICKING, 0)):
        roles.append("pick")
    for _index in int(zone_staffing.get(STAFF_ZONE_SHIPPING, 0)):
        roles.append("ship")

    for index in mini(workers.size(), roles.size()):
        workers[index]["role"] = roles[index]


func _normalize_zone_staffing() -> void:
    _normalize_staffing_dictionary(zone_staffing)


func _normalize_staffing_dictionary(staffing: Dictionary) -> void:
    if facility_rank < 2:
        return

    for zone in direct_staffing_zone_keys():
        staffing[zone] = maxi(
            DIRECT_STAFFING_MIN_PER_ZONE,
            int(staffing.get(zone, DIRECT_STAFFING_MIN_PER_ZONE))
        )

    var total := 0
    for zone in direct_staffing_zone_keys():
        total += int(staffing.get(zone, 0))

    while total < worker_count:
        staffing[STAFF_ZONE_PICKING] = int(staffing[STAFF_ZONE_PICKING]) + 1
        total += 1

    while total > worker_count:
        var reducible_zone := ""
        var reducible_count := DIRECT_STAFFING_MIN_PER_ZONE
        for zone in direct_staffing_zone_keys():
            var count := int(staffing.get(zone, 0))
            if count > reducible_count:
                reducible_zone = zone
                reducible_count = count
        if reducible_zone.is_empty():
            break
        staffing[reducible_zone] = int(staffing[reducible_zone]) - 1
        total -= 1


func _same_zone_staffing(other: Dictionary) -> bool:
    _normalize_zone_staffing()
    for zone in direct_staffing_zone_keys():
        if int(zone_staffing.get(zone, 0)) != int(other.get(zone, 0)):
            return false
    return true


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
    _activate_direct_staffing_from_current_roles()
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
    _activate_direct_staffing_from_current_roles()


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
    data["direct_zone_staffing"] = direct_staffing_summary()
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_V2
    data["rank1_projects"] = rank1_projects.duplicate(true)
    data["zone_staffing"] = zone_staffing.duplicate(true)
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

    if source_schema >= SAVE_SCHEMA_RANK1_V2:
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

        if source_schema >= SAVE_SCHEMA_V2:
            var saved_staffing: Variant = data.get("zone_staffing", {})
            if saved_staffing is Dictionary:
                zone_staffing = {
                    STAFF_ZONE_INBOUND: int((saved_staffing as Dictionary).get(STAFF_ZONE_INBOUND, 2)),
                    STAFF_ZONE_PICKING: int((saved_staffing as Dictionary).get(STAFF_ZONE_PICKING, 2)),
                    STAFF_ZONE_SHIPPING: int((saved_staffing as Dictionary).get(STAFF_ZONE_SHIPPING, 1)),
                }
            else:
                zone_staffing = _legacy_plan_to_zone_staffing(staffing_plan)
        else:
            # Schema 8 and earlier stored named presets. Convert the effective
            # legacy role allocation into direct Zone counts without changing it.
            var legacy_plan := String(data.get("staffing_plan", staffing_plan))
            zone_staffing = _legacy_plan_to_zone_staffing(legacy_plan)

        _direct_staffing_active = true
        staffing_plan = "direct"
        _normalize_zone_staffing()
    if bool(rank1_projects.get("rack_wing", false)):
        rack_level = maxi(rack_level, 1)
        rack_capacity = maxi(rack_capacity, 12)
    if bool(rank1_projects.get("worker_hire", false)):
        worker_count = maxi(worker_count, 4)
        _sync_worker_roster()
    if bool(rank1_projects.get("forklift_project", false)):
        forklift_unlocked = true
    if facility_rank >= 2 and _direct_staffing_active:
        _apply_staffing_plan()

    if source_schema < SAVE_SCHEMA_V2:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_V2})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_V2})
    return true
