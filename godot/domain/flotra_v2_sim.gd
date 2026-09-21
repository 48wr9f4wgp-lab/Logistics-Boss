extends "res://domain/rank3_inbound_carrier_sim.gd"
class_name FlotraV2Sim

const SAVE_SCHEMA_RANK1_V2 := 8
const SAVE_SCHEMA_DIRECT_STAFFING := 9
const SAVE_SCHEMA_V2 := 10

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
const FORKLIFT_PROJECT_COST := 8000
const WAREHOUSE_EXPANSION_COST := 8000
const EXPANSION_SHIPMENTS := 20
const EXPANSION_PROJECTS := 2
const EXTRA_FORKLIFT_COST := 10000
const CONVEYOR_COST := 9000
const EXTRA_FORKLIFT_CYCLE := 4.8
const CONVEYOR_TRAVEL_SECONDS := 2.4
const CONVEYOR_CAPACITY := 4

var extra_forklift_owned := false
var conveyor_owned := false
var extra_forklift_moved := 0
var conveyor_moved := 0
var forklift_book_value := CapitalCatalog.FORKLIFT_COST
var expansion_book_value := 10000
var _extra_remaining := 0.0
var _extra_cargo := 0
var _conveyor_jobs: Array[float] = []

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

    _measurement.note_intervention("staffing", sim_time)
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


func rank2_v2_equipment_kinds_for_zone(zone_key: String) -> Array[StringName]:
    match zone_key:
        "storage":
            return [&"fast_pick_rack", &"high_density_rack"]
        "packing":
            return [&"parallel_pack", &"fast_pack_cell"]
    return []


func facility_renovation_cost(kind: StringName) -> int:
    if not _rank2_facilities.is_known(kind):
        return 0
    return _rank2_facilities.renovation_cost(kind)


func rank2_v2_equipment_action_info(kind: StringName) -> Dictionary:
    if not _rank2_facilities.is_known(kind):
        return {}
    var group := _rank2_facilities.group(kind)
    if group not in ["storage", "packing"]:
        return {}

    var current := selected_facility_for_group(group)
    var active := current == String(kind)
    var renovating := not current.is_empty() and not active
    var cost := facility_renovation_cost(kind) if renovating else facility_cost(kind)
    return {
        "kind": String(kind),
        "label": _rank2_facilities.label(kind),
        "group": group,
        "active": active,
        "current_kind": current,
        "renovating": renovating,
        "action": "active" if active else ("renovate" if renovating else "build"),
        "cost": cost,
        "fresh_cost": facility_cost(kind),
        "renovation_cost": facility_renovation_cost(kind),
        "strength": _rank2_facilities.strength(kind),
        "weakness": _rank2_facilities.weakness(kind),
        "effect": _rank2_facilities.effect(kind),
    }


func purchase_facility(kind: StringName) -> Dictionary:
    if not _rank2_facilities.is_known(kind):
        return {"ok": false, "reason": "unknown", "cost": 0}

    var group := _rank2_facilities.group(kind)
    if group not in ["storage", "packing"]:
        return super.purchase_facility(kind)
    if facility_rank < 2:
        return {"ok": false, "reason": "rank", "cost": facility_cost(kind)}

    var current := selected_facility_for_group(group)
    if current == String(kind):
        return {"ok": false, "reason": "owned", "cost": facility_cost(kind)}

    var renovating := not current.is_empty()
    var cost := facility_renovation_cost(kind) if renovating else facility_cost(kind)
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}

    var measurement_kind := StringName(
        "renovation_%s" % String(kind)
        if renovating
        else "facility_%s" % String(kind)
    )
    var before := _measurement.begin_investment(measurement_kind, cost, sim_time)

    money -= cost

    if group == "storage":
        var old_bonus := _storage_capacity_bonus(StringName(current)) if renovating else 0
        var new_bonus := _storage_capacity_bonus(kind)
        rack_capacity = maxi(1, rack_capacity - old_bonus + new_bonus)

    for candidate in _rank2_facilities.all_kinds():
        if _rank2_facilities.group(candidate) == group:
            facilities[String(candidate)] = false
    facilities[String(kind)] = true

    var event_type := "facility_renovated" if renovating else "facility_purchased"
    _emit(event_type, {
        "kind": String(kind),
        "from_kind": current,
        "to_kind": String(kind),
        "zone": _rank2_facilities.zone(kind),
        "group": group,
        "label": _rank2_facilities.label(kind),
        "cost": cost,
        "fresh_cost": facility_cost(kind),
        "renovation_cost": facility_renovation_cost(kind),
        "zones_completed": expansion_zones_completed(),
        "measurement_kind": String(measurement_kind),
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {
        "ok": true,
        "action": "renovate" if renovating else "build",
        "from_kind": current,
        "to_kind": String(kind),
        "cost": cost,
        "zones_completed": expansion_zones_completed(),
        "measurement_kind": String(measurement_kind),
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    }


func _storage_capacity_bonus(kind: StringName) -> int:
    match kind:
        &"fast_pick_rack":
            return 12
        &"high_density_rack":
            return 16
    return 0


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
    var projects_ready := projects >= EXPANSION_PROJECTS
    var shipments_ready := shipped >= EXPANSION_SHIPMENTS
    return {
        "ready": facility_rank >= 2 or (projects_ready and shipments_ready and money >= WAREHOUSE_EXPANSION_COST),
        "projects": projects, "projects_required": EXPANSION_PROJECTS,
        "projects_ready": projects_ready,
        "shipments": shipped, "shipments_required": EXPANSION_SHIPMENTS,
        "shipments_ready": shipments_ready,
        # Retained read-only fields for older integrations. Rating is no longer a gate.
        "rating": logistics_rating, "rating_required": 0, "rating_ready": true,
        "cash": money, "cost": WAREHOUSE_EXPANSION_COST,
        "funds_ready": money >= WAREHOUSE_EXPANSION_COST,
    }


func purchase_rank1_project(kind: StringName) -> Dictionary:
    if facility_rank > 2:
        return {"ok": false, "reason": "rank", "cost": rank1_project_cost(kind)}
    if kind not in rank1_project_kinds():
        return {"ok": false, "reason": "unknown", "cost": 0}
    if rank1_project_owned(kind):
        return {"ok": false, "reason": "owned", "cost": rank1_project_cost(kind)}

    var cost := rank1_project_cost(kind)
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}

    if kind == PROJECT_SECOND_PACKING_BENCH and not selected_facility_for_group("packing").is_empty():
        return {"ok": false, "reason": "superseded", "cost": cost}
    if kind == PROJECT_WORKER_HIRE and worker_count >= 4:
        return {"ok": false, "reason": "owned", "cost": cost}
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
            forklift_book_value = cost

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
    for requirement in ["projects", "shipments", "funds"]:
        if not bool(readiness.get("%s_ready" % requirement, false)):
            return {"ok": false, "reason": requirement, "cost": WAREHOUSE_EXPANSION_COST, "readiness": readiness}
    money -= WAREHOUSE_EXPANSION_COST
    rack_capacity += 4
    expansion_book_value = WAREHOUSE_EXPANSION_COST
    rank1_projects[String(PROJECT_WAREHOUSE_EXPANSION)] = true
    _measurement.note_intervention("warehouse_expansion", sim_time)
    super._rank_up_to_warehouse()
    # The expanded facility includes a five-person crew. Never sell a no-op hire.
    rank1_projects[String(PROJECT_WORKER_HIRE)] = true
    _activate_direct_staffing_from_current_roles()
    _emit("warehouse_expansion_purchased", {
        "kind": String(PROJECT_WAREHOUSE_EXPANSION), "label": "倉庫拡張",
        "cost": WAREHOUSE_EXPANSION_COST, "rack_capacity": rack_capacity,
    })
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
    # Rank 1's Second Packing Bench teaches parallelism. Once a Rank 2 PACKING
    # system is installed, that system replaces the Rank 1 bench behavior so
    # Fast Pack Cell retains its intended one-job weakness.
    if facility_rank >= 2 and not selected_facility_for_group("packing").is_empty():
        return super._packing_capacity()

    var capacity := super._packing_capacity()
    if rank1_project_owned(PROJECT_SECOND_PACKING_BENCH):
        capacity = maxi(capacity, 2)
    return capacity


func _rank_up_to_warehouse() -> void:
    # Core Experience v2 makes Rank 2 a deliberate facility project.
    # Contract ratings are optional; expansion always remains an explicit purchase.
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
        value += expansion_book_value
    if forklift_unlocked:
        value += forklift_book_value - CapitalCatalog.FORKLIFT_COST
    if extra_forklift_owned:
        value += EXTRA_FORKLIFT_COST
    if conveyor_owned:
        value += CONVEYOR_COST
    return value


func snapshot() -> Dictionary:
    var data: Dictionary = super.snapshot()
    data["schema_version"] = SAVE_SCHEMA_V2
    data["rank1_projects"] = rank1_projects.duplicate(true)
    data["rank1_projects_completed"] = rank1_projects_completed()
    data["rank1_expansion_readiness"] = rank1_expansion_readiness()
    data["direct_zone_staffing"] = direct_staffing_summary()
    data["growth_automation"] = growth_automation_state()
    return data


func save_data() -> Dictionary:
    var data: Dictionary = super.save_data()
    data["schema_version"] = SAVE_SCHEMA_V2
    data["rank1_projects"] = rank1_projects.duplicate(true)
    data["zone_staffing"] = zone_staffing.duplicate(true)
    data["growth_automation"] = {
        "extra_forklift": extra_forklift_owned, "conveyor": conveyor_owned,
        "extra_moved": extra_forklift_moved, "conveyor_moved": conveyor_moved,
        "forklift_book_value": forklift_book_value, "expansion_book_value": expansion_book_value,
    }
    # The legacy save resumes jobs from queues. Project in-flight inventory into
    # durable queues without changing live state, completing work or granting cash.
    for worker in workers:
        match int(worker.get("task", Task.IDLE)):
            Task.STORE:
                data["inbound_queue"] = int(data["inbound_queue"]) + 1
            Task.PICK:
                data["rack_stock"] = int(data["rack_stock"]) + 1
                data["open_orders"] = int(data["open_orders"]) + 1
            Task.SHIP:
                data["packed_queue"] = int(data["packed_queue"]) + maxi(1, int(worker.get("routing_batch", 1)))
    data["inbound_queue"] = int(data["inbound_queue"]) + (1 if forklift_active else 0) + _extra_cargo
    data["packing_queue"] = int(data["packing_queue"]) + _packing_jobs.size() + _conveyor_jobs.size()
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

        if source_schema >= SAVE_SCHEMA_DIRECT_STAFFING:
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

    var growth: Dictionary = data.get("growth_automation", {}) if data.get("growth_automation", {}) is Dictionary else {}
    extra_forklift_owned = source_schema >= 10 and facility_rank >= 2 and forklift_unlocked and bool(growth.get("extra_forklift", false))
    conveyor_owned = source_schema >= 10 and facility_rank >= 2 and bool(growth.get("conveyor", false))
    extra_forklift_moved = maxi(0, int(growth.get("extra_moved", 0)))
    conveyor_moved = maxi(0, int(growth.get("conveyor_moved", 0)))
    forklift_book_value = clampi(int(growth.get("forklift_book_value", CapitalCatalog.FORKLIFT_COST)), 0, CapitalCatalog.FORKLIFT_COST)
    expansion_book_value = clampi(int(growth.get("expansion_book_value", 10000)), 0, 10000)
    _extra_remaining = 0.0
    _extra_cargo = 0
    _conveyor_jobs.clear()
    if source_schema < SAVE_SCHEMA_V2:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA_V2})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA_V2})
    return true


func growth_automation_for_zone(zone_key: String) -> StringName:
    if zone_key == "inbound":
        return &"extra_forklift"
    if zone_key == "picking":
        return &"transfer_conveyor"
    return &""


func growth_automation_info(kind: StringName) -> Dictionary:
    if kind not in [&"extra_forklift", &"transfer_conveyor"]:
        return {}
    var extra := kind == &"extra_forklift"
    return {
        "kind": String(kind), "label": "フォークリフト2号車" if extra else "搬送コンベア",
        "zone": "inbound" if extra else "picking",
        "owned": extra_forklift_owned if extra else conveyor_owned,
        "unlocked": facility_rank >= 2 and (forklift_unlocked or not extra),
        "lock_reason": "倉庫拡張で解放" if facility_rank < 2 else "最初のフォークリフトを導入すると解放",
        "cost": EXTRA_FORKLIFT_COST if extra else CONVEYOR_COST,
        "effect": "もう1台が最大2箱ずつ入荷→棚へ搬送" if extra else "ピッキング後の歩行搬送をベルトに置換",
        "tradeoff": "棚や梱包が詰まると増車の効果は小さい" if extra else "梱包能力は増えない。次は梱包側の余力が必要",
    }


func purchase_growth_automation(kind: StringName) -> Dictionary:
    var info := growth_automation_info(kind)
    if info.is_empty():
        return {"ok": false, "reason": "unknown"}
    if bool(info["owned"]):
        return {"ok": false, "reason": "owned"}
    if not bool(info["unlocked"]):
        return {"ok": false, "reason": "rank"}
    var cost := int(info["cost"])
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}
    money -= cost
    if kind == &"extra_forklift":
        extra_forklift_owned = true
    else:
        conveyor_owned = true
    _measurement.begin_investment(kind, cost, sim_time)
    _emit("growth_automation_purchased", {"kind": String(kind), "label": info["label"], "zone": info["zone"], "cost": cost})
    return {"ok": true, "kind": String(kind), "cost": cost}


func growth_automation_state() -> Dictionary:
    return {
        "extra_owned": extra_forklift_owned, "extra_active": _extra_remaining > 0.0,
        "extra_progress": 1.0 - _extra_remaining / EXTRA_FORKLIFT_CYCLE if _extra_remaining > 0.0 else 0.0,
        "extra_cargo": _extra_cargo, "extra_moved": extra_forklift_moved,
        "conveyor_owned": conveyor_owned, "conveyor_jobs": _conveyor_jobs.duplicate(),
        "conveyor_duration": CONVEYOR_TRAVEL_SECONDS, "conveyor_moved": conveyor_moved,
    }


func _reserved_store_slots() -> int:
    return super._reserved_store_slots() + _extra_cargo


func _update_forklift(dt: float) -> void:
    # Dispatch the two-place vehicle first when available. Otherwise the old
    # single-place dispatch can consume every arrival before the second vehicle
    # is offered work. Both reserve real inventory and storage slots.
    _update_extra_forklift(dt)
    super._update_forklift(dt)


func _update_extra_forklift(dt: float) -> void:
    if not extra_forklift_owned:
        return
    if _extra_remaining > 0.0:
        _extra_remaining = maxf(0.0, _extra_remaining - dt)
        # Deliver at the end of the loaded outward leg, then return empty.
        if _extra_cargo > 0 and _extra_remaining <= EXTRA_FORKLIFT_CYCLE * 0.5:
            rack_stock += _extra_cargo
            extra_forklift_moved += _extra_cargo
            _emit("extra_forklift_stored", {"count": _extra_cargo, "rack_stock": rack_stock})
            _extra_cargo = 0
    if _extra_remaining > 0.0:
        return
    var available := mini(inbound_queue, rack_capacity - rack_stock - _reserved_store_slots())
    if available <= 0:
        return
    _extra_cargo = mini(2, available)
    inbound_queue -= _extra_cargo
    _extra_remaining = EXTRA_FORKLIFT_CYCLE
    _emit("extra_forklift_started", {"count": _extra_cargo})


func _update_packing(dt: float) -> void:
    for index in range(_conveyor_jobs.size() - 1, -1, -1):
        _conveyor_jobs[index] = maxf(0.0, _conveyor_jobs[index] - dt)
        if _conveyor_jobs[index] <= 0.0:
            _conveyor_jobs.remove_at(index)
            packing_queue += 1
            conveyor_moved += 1
            _emit("conveyor_delivered", {"packing_queue": packing_queue})
    super._update_packing(dt)


func _start_task(worker: Dictionary, task: int) -> void:
    super._start_task(worker, task)
    if conveyor_owned and task == Task.PICK and int(worker.get("task", Task.IDLE)) == Task.PICK:
        # Walking to packing is replaced by a powered handoff. Picking remains
        # real work; conveyor travel occurs independently after the pick finishes.
        worker["duration"] = float(worker["duration"]) * 0.50
        worker["remaining"] = worker["duration"]
        worker["target"] = "conveyor"


func _complete_task(worker: Dictionary) -> void:
    if not conveyor_owned or int(worker.get("task", Task.IDLE)) != Task.PICK:
        super._complete_task(worker)
        return
    if _conveyor_jobs.size() >= CONVEYOR_CAPACITY:
        return # Backpressure: the picker keeps the reserved parcel, never loses it.
    _conveyor_jobs.append(CONVEYOR_TRAVEL_SECONDS)
    _emit("conveyor_loaded", {"in_transit": _conveyor_jobs.size()})
    worker["task"] = int(Task.IDLE)
    worker["source"] = "center"
    worker["target"] = "center"
    worker["duration"] = 0.0
    worker["remaining"] = 0.0
    worker["progress"] = 0.0
