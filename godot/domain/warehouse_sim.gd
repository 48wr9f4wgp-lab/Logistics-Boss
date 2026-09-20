extends RefCounted
class_name WarehouseSim

signal event_emitted(event: Dictionary)

const CapitalCatalogScript = preload("res://domain/capital_catalog.gd")
const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")
const ProgressionSystemScript = preload("res://domain/progression_system.gd")
const Rank2FacilityCatalogScript = preload("res://domain/rank2_facility_catalog.gd")

const SAVE_SCHEMA := 3
const BASE_SHIPMENT_VALUE := 500
const INBOUND_INTERVAL := 2.8
const ORDER_INTERVAL := 3.0
const RANK2_ORDER_INTERVAL := 2.2
const INBOUND_LIMIT := 14
const ORDER_LIMIT := 18
const FORKLIFT_CYCLE := 3.2

enum Policy {
    BALANCED,
    INBOUND,
    SHIP,
}

enum Task {
    IDLE,
    STORE,
    PICK,
    SHIP,
}

var money: int = 5000
var research_rp: int = 0
var logistics_rating: int = 0
var facility_rank: int = 1
var completed_contracts: int = 0
var contract_offers: Array[Dictionary] = []
var active_contract: Dictionary = {}
var staffing_plan: String = "balanced"
var staffing_cooldown: float = 0.0
var facilities: Dictionary = {
    "double_dock": false,
    "buffer_yard": false,
    "fast_pick_rack": false,
    "high_density_rack": false,
    "parallel_pack": false,
    "fast_pack_cell": false,
}

var inbound_queue: int = 4
var rack_stock: int = 2
var packing_queue: int = 0
var packed_queue: int = 0
var open_orders: int = 1
var shipped: int = 0

var rack_capacity: int = 8
var worker_count: int = 3
var worker_speed: float = 1.0
var pack_time_multiplier: float = 1.0

var rack_level: int = 0
var speed_level: int = 0
var pack_level: int = 0
var forklift_unlocked: bool = false
var forklift_active: bool = false
var forklift_progress: float = 0.0

var policy: int = Policy.BALANCED
var time_scale: float = 1.0
var sim_time: float = 0.0
var last_measurement: Dictionary = {}

var _inbound_timer: float = 2.0
var _order_timer: float = 3.0
var _packing_jobs: Array[float] = []
var _forklift_remaining: float = 0.0
var _contract_offer_cooldown: float = 0.0
var _next_contract_id: int = 1
var _shipment_times: Array[float] = []
var workers: Array[Dictionary] = []
var _capital: CapitalCatalog = CapitalCatalogScript.new()
var _measurement: FlowMeasurement = FlowMeasurementScript.new()
var _progression: LogisticsProgression = ProgressionSystemScript.new()
var _rank2_facilities: Rank2FacilityCatalog = Rank2FacilityCatalogScript.new()


func _init() -> void:
    _sync_worker_roster()
    _refresh_contract_offers()


func step(real_dt: float) -> void:
    var dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    if dt <= 0.0:
        return

    sim_time += dt
    staffing_cooldown = maxf(0.0, staffing_cooldown - dt)
    _spawn_flow(dt)
    _update_packing(dt)
    _update_forklift(dt)
    _update_workers(dt)
    _assign_idle_workers()
    _prune_shipment_window()
    _update_progression(dt)

    _measurement.record_state(
        sim_time,
        dt,
        inbound_queue,
        packing_queue,
        packed_queue,
        open_orders,
        rack_stock,
        rack_capacity
    )
    for result in _measurement.collect_completed(sim_time):
        last_measurement = result
        _emit("measurement_completed", result)


func set_policy(next_policy: int) -> void:
    if policy == next_policy:
        return
    policy = next_policy
    _emit("policy_changed", {"policy": int(policy)})


func set_staffing_plan(next_plan: String) -> Dictionary:
    if facility_rank < 2:
        return {"ok": false, "reason": "rank"}
    if next_plan not in ["receiving", "balanced", "picking", "dock", "shipping"]:
        return {"ok": false, "reason": "unknown"}
    if staffing_cooldown > 0.0:
        return {"ok": false, "reason": "cooldown", "remaining": staffing_cooldown}
    if staffing_plan == next_plan:
        return {"ok": false, "reason": "same"}

    staffing_plan = next_plan
    staffing_cooldown = LogisticsProgression.STAFFING_COOLDOWN_SECONDS
    _apply_staffing_plan()
    _emit("staffing_changed", {
        "plan": staffing_plan,
        "label": _progression.staffing_label(staffing_plan),
        "cooldown": staffing_cooldown,
    })
    return {"ok": true, "cooldown": staffing_cooldown}


func staffing_summary() -> Dictionary:
    var summary := {"store": 0, "pick": 0, "ship": 0, "idle": 0, "total": workers.size()}
    for worker in workers:
        var role := String(worker.get("role", ""))
        if summary.has(role):
            summary[role] = int(summary[role]) + 1
        else:
            summary["idle"] = int(summary["idle"]) + 1
    return summary


func worker_activity_summary() -> Dictionary:
    var summary := {"store": 0, "pick": 0, "ship": 0, "idle": 0, "total": workers.size()}
    for worker in workers:
        match int(worker.get("task", Task.IDLE)):
            Task.STORE:
                summary["store"] = int(summary["store"]) + 1
            Task.PICK:
                summary["pick"] = int(summary["pick"]) + 1
            Task.SHIP:
                summary["ship"] = int(summary["ship"]) + 1
            _:
                summary["idle"] = int(summary["idle"]) + 1
    return summary


func choose_contract(contract_id: int) -> Dictionary:
    if not active_contract.is_empty():
        return {"ok": false, "reason": "active"}

    for offer in contract_offers:
        if int(offer.get("id", -1)) != contract_id:
            continue
        active_contract = _progression.start_contract(offer, shipped)
        contract_offers.clear()
        _emit("contract_started", {
            "id": contract_id,
            "title": String(active_contract.get("title", "契約")),
        })
        return {"ok": true}
    return {"ok": false, "reason": "missing"}


func facility_info(kind: StringName) -> Dictionary:
    return _rank2_facilities.info(kind)


func facility_cost(kind: StringName) -> int:
    return _rank2_facilities.cost(kind)


func expansion_zones_completed() -> int:
    var completed := 0
    for group in ["intake", "storage", "packing"]:
        if not selected_facility_for_group(group).is_empty():
            completed += 1
    return completed


func selected_facility_for_group(group: String) -> String:
    for kind in _rank2_facilities.all_kinds():
        if _rank2_facilities.group(kind) == group and bool(facilities.get(String(kind), false)):
            return String(kind)
    return ""


func purchase_facility(kind: StringName) -> Dictionary:
    if facility_rank < 2:
        return {"ok": false, "reason": "rank", "cost": facility_cost(kind)}
    if not _rank2_facilities.is_known(kind):
        return {"ok": false, "reason": "unknown", "cost": 0}
    if bool(facilities.get(String(kind), false)):
        return {"ok": false, "reason": "owned", "cost": facility_cost(kind)}

    var group := _rank2_facilities.group(kind)
    if not selected_facility_for_group(group).is_empty():
        return {"ok": false, "reason": "exclusive", "cost": facility_cost(kind)}

    var cost := facility_cost(kind)
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}

    money -= cost
    facilities[String(kind)] = true
    match kind:
        &"fast_pick_rack":
            # Preserve Fast Pick as the lower-capacity option, but give the
            # forecast cycle enough buffer for receiving/picking staffing
            # choices to create a measurable session-level payoff.
            rack_capacity += 12
        &"high_density_rack":
            rack_capacity += 16

    var measurement_kind := StringName("facility_%s" % String(kind))
    var before := _measurement.begin_investment(measurement_kind, cost, sim_time)
    _emit("facility_purchased", {
        "kind": String(kind),
        "zone": _rank2_facilities.zone(kind),
        "group": group,
        "label": _rank2_facilities.label(kind),
        "cost": cost,
        "zones_completed": expansion_zones_completed(),
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {"ok": true, "cost": cost, "zones_completed": expansion_zones_completed()}


func set_time_scale(next_scale: float) -> void:
    time_scale = clampf(next_scale, 0.0, 4.0)


func upgrade_cost(kind: StringName) -> int:
    return _capital.cost(kind, worker_count, rack_level, speed_level, pack_level, forklift_unlocked)


func purchase_upgrade(kind: StringName) -> Dictionary:
    if not _capital.is_known(kind):
        return {"ok": false, "reason": "unknown", "cost": 0}

    var cost := upgrade_cost(kind)
    if _capital.is_maxed(kind, worker_count, rack_level, speed_level, pack_level, forklift_unlocked):
        return {"ok": false, "reason": "max", "cost": cost}
    if money < cost:
        return {"ok": false, "reason": "funds", "cost": cost}

    money -= cost
    match kind:
        &"worker":
            worker_count += 1
            _sync_worker_roster()
        &"rack":
            rack_level += 1
            rack_capacity += 4
        &"speed":
            speed_level += 1
            worker_speed *= 1.15
        &"packing":
            pack_level += 1
            pack_time_multiplier *= 0.85
        &"forklift":
            forklift_unlocked = true

    var before := _measurement.begin_investment(kind, cost, sim_time)
    _emit("upgrade_purchased", {
        "kind": String(kind),
        "cost": cost,
        "measurement_window": FlowMeasurement.WINDOW_SECONDS,
        "before": before,
    })
    return {"ok": true, "cost": cost, "measurement_window": FlowMeasurement.WINDOW_SECONDS}


func bottleneck() -> Dictionary:
    if inbound_queue >= 8:
        return {"key": "inbound", "label": "搬入口が混雑", "severity": 2}
    if rack_stock >= rack_capacity:
        return {"key": "rack", "label": "棚が満杯", "severity": 2}
    if packing_queue >= 3:
        return {"key": "packing", "label": "梱包待ち", "severity": 2}
    if packed_queue >= 4:
        return {"key": "outbound", "label": "出荷待ち", "severity": 2}
    if open_orders >= 6:
        return {"key": "orders", "label": "注文待ち増加", "severity": 1}
    return {"key": "stable", "label": "安定運転", "severity": 0}


func throughput_per_minute() -> float:
    _prune_shipment_window()
    return snappedf(float(_shipment_times.size()), 0.1)


func snapshot() -> Dictionary:
    return {
        "schema_version": SAVE_SCHEMA,
        "money": money,
        "research_rp": research_rp,
        "logistics_rating": logistics_rating,
        "facility_rank": facility_rank,
        "completed_contracts": completed_contracts,
        "contract_offers": contract_offers.duplicate(true),
        "active_contract": active_contract.duplicate(true),
        "staffing_plan": staffing_plan,
        "staffing_cooldown": staffing_cooldown,
        "facilities": facilities.duplicate(true),
        "expansion_zones_completed": expansion_zones_completed(),
        "inbound_queue": inbound_queue,
        "rack_stock": rack_stock,
        "packing_queue": packing_queue,
        "packed_queue": packed_queue,
        "open_orders": open_orders,
        "shipped": shipped,
        "rack_capacity": rack_capacity,
        "worker_count": worker_count,
        "worker_speed": worker_speed,
        "pack_time_multiplier": pack_time_multiplier,
        "rack_level": rack_level,
        "speed_level": speed_level,
        "pack_level": pack_level,
        "forklift_unlocked": forklift_unlocked,
        "forklift_active": forklift_active,
        "forklift_progress": forklift_progress,
        "policy": int(policy),
        "time_scale": time_scale,
        "sim_time": sim_time,
        "bottleneck": bottleneck(),
        "throughput_per_minute": throughput_per_minute(),
        "last_measurement": last_measurement,
    }


func save_data() -> Dictionary:
    return {
        "schema_version": SAVE_SCHEMA,
        "money": money,
        "research_rp": research_rp,
        "logistics_rating": logistics_rating,
        "facility_rank": facility_rank,
        "completed_contracts": completed_contracts,
        "contract_offers": contract_offers.duplicate(true),
        "active_contract": active_contract.duplicate(true),
        "next_contract_id": _next_contract_id,
        "staffing_plan": staffing_plan,
        "staffing_cooldown": staffing_cooldown,
        "facilities": facilities.duplicate(true),
        "inbound_queue": inbound_queue,
        "rack_stock": rack_stock,
        "packing_queue": packing_queue,
        "packed_queue": packed_queue,
        "open_orders": open_orders,
        "shipped": shipped,
        "rack_capacity": rack_capacity,
        "worker_count": worker_count,
        "worker_speed": worker_speed,
        "pack_time_multiplier": pack_time_multiplier,
        "rack_level": rack_level,
        "speed_level": speed_level,
        "pack_level": pack_level,
        "forklift_unlocked": forklift_unlocked,
        "policy": int(policy),
    }


func load_data(data: Dictionary) -> bool:
    var source_schema := int(data.get("schema_version", -1))
    if source_schema < 1 or source_schema > SAVE_SCHEMA:
        return false

    money = maxi(0, int(data.get("money", money)))
    research_rp = maxi(0, int(data.get("research_rp", research_rp)))
    inbound_queue = maxi(0, int(data.get("inbound_queue", inbound_queue)))
    rack_stock = maxi(0, int(data.get("rack_stock", rack_stock)))
    packing_queue = maxi(0, int(data.get("packing_queue", packing_queue)))
    packed_queue = maxi(0, int(data.get("packed_queue", packed_queue)))
    open_orders = maxi(0, int(data.get("open_orders", open_orders)))
    shipped = maxi(0, int(data.get("shipped", shipped)))
    rack_capacity = maxi(4, int(data.get("rack_capacity", rack_capacity)))
    worker_count = clampi(int(data.get("worker_count", worker_count)), 3, 7)
    worker_speed = clampf(float(data.get("worker_speed", worker_speed)), 1.0, 3.0)
    pack_time_multiplier = clampf(float(data.get("pack_time_multiplier", pack_time_multiplier)), 0.35, 1.0)
    rack_level = clampi(int(data.get("rack_level", rack_level)), 0, 4)
    speed_level = clampi(int(data.get("speed_level", speed_level)), 0, 4)
    pack_level = clampi(int(data.get("pack_level", pack_level)), 0, 4)
    forklift_unlocked = bool(data.get("forklift_unlocked", false))
    policy = clampi(int(data.get("policy", policy)), Policy.BALANCED, Policy.SHIP)

    logistics_rating = maxi(0, int(data.get("logistics_rating", 0))) if source_schema >= 3 else 0
    facility_rank = clampi(int(data.get("facility_rank", 1)), 1, 2) if source_schema >= 3 else 1
    completed_contracts = maxi(0, int(data.get("completed_contracts", 0))) if source_schema >= 3 else 0
    staffing_plan = String(data.get("staffing_plan", "balanced")) if source_schema >= 3 else "balanced"
    staffing_cooldown = maxf(0.0, float(data.get("staffing_cooldown", 0.0))) if source_schema >= 3 else 0.0
    _next_contract_id = maxi(1, int(data.get("next_contract_id", 1))) if source_schema >= 3 else 1

    facilities = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    if source_schema >= 3:
        var saved_facilities: Variant = data.get("facilities", {})
        if saved_facilities is Dictionary:
            for kind in facilities.keys():
                facilities[kind] = bool((saved_facilities as Dictionary).get(kind, false))

    contract_offers.clear()
    if source_schema >= 3:
        var saved_offers: Variant = data.get("contract_offers", [])
        if saved_offers is Array:
            for item in saved_offers:
                if item is Dictionary:
                    contract_offers.append((item as Dictionary).duplicate(true))
        var saved_active: Variant = data.get("active_contract", {})
        active_contract = (saved_active as Dictionary).duplicate(true) if saved_active is Dictionary else {}
    else:
        active_contract = {}

    forklift_active = false
    forklift_progress = 0.0
    _forklift_remaining = 0.0
    _packing_jobs.clear()
    _contract_offer_cooldown = 0.0
    if facility_rank >= 2:
        worker_count = maxi(5, worker_count)
        policy = Policy.BALANCED
    _sync_worker_roster()
    if facility_rank >= 2:
        _apply_staffing_plan()
    if active_contract.is_empty() and contract_offers.is_empty():
        _refresh_contract_offers()

    if source_schema < SAVE_SCHEMA:
        _emit("save_migrated", {"from_schema": source_schema, "to_schema": SAVE_SCHEMA})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA})
    return true


func _spawn_flow(dt: float) -> void:
    _inbound_timer -= dt
    while _inbound_timer <= 0.0:
        _inbound_timer += _current_inbound_interval()
        if inbound_queue < _current_inbound_limit():
            inbound_queue += 1
            _emit("inbound_arrival", {"count": inbound_queue})

    _order_timer -= dt
    while _order_timer <= 0.0:
        _order_timer += _current_order_interval()
        if open_orders < ORDER_LIMIT:
            open_orders += 1
            _emit("order_arrival", {"count": open_orders})


func _current_inbound_interval() -> float:
    return INBOUND_INTERVAL * (0.78 if bool(facilities.get("double_dock", false)) else 1.0)


func _current_inbound_limit() -> int:
    if bool(facilities.get("buffer_yard", false)):
        return INBOUND_LIMIT + 14
    if bool(facilities.get("double_dock", false)):
        return INBOUND_LIMIT + 6
    return INBOUND_LIMIT


func _current_order_interval() -> float:
    return RANK2_ORDER_INTERVAL if facility_rank >= 2 else ORDER_INTERVAL


func _packing_capacity() -> int:
    return 2 if bool(facilities.get("parallel_pack", false)) else 1


func _packing_duration() -> float:
    var facility_factor := 1.0
    if bool(facilities.get("fast_pack_cell", false)):
        facility_factor = 0.58
    elif bool(facilities.get("parallel_pack", false)):
        facility_factor = 1.10
    return 3.0 * pack_time_multiplier * facility_factor


func _update_packing(dt: float) -> void:
    while packing_queue > 0 and _packing_jobs.size() < _packing_capacity():
        packing_queue -= 1
        var duration := _packing_duration()
        _packing_jobs.append(duration)
        _emit("packing_started", {"duration": duration, "parallel": _packing_jobs.size()})

    for index in range(_packing_jobs.size() - 1, -1, -1):
        _packing_jobs[index] = maxf(0.0, _packing_jobs[index] - dt)
        if _packing_jobs[index] > 0.0:
            continue
        _packing_jobs.remove_at(index)
        packed_queue += 1
        _emit("packing_complete", {"packed_queue": packed_queue})


func _update_forklift(dt: float) -> void:
    if not forklift_unlocked:
        forklift_active = false
        forklift_progress = 0.0
        _forklift_remaining = 0.0
        return

    if forklift_active:
        _forklift_remaining = maxf(0.0, _forklift_remaining - dt)
        forklift_progress = clampf(1.0 - _forklift_remaining / FORKLIFT_CYCLE, 0.0, 1.0)
        if _forklift_remaining <= 0.0:
            forklift_active = false
            forklift_progress = 0.0
            rack_stock += 1
            _emit("forklift_stored", {"rack_stock": rack_stock})

    if forklift_active:
        return

    if inbound_queue <= 0:
        return
    if rack_stock + _reserved_store_slots() >= rack_capacity:
        return

    inbound_queue -= 1
    forklift_active = true
    forklift_progress = 0.0
    _forklift_remaining = FORKLIFT_CYCLE
    _emit("forklift_task_started", {"duration": FORKLIFT_CYCLE})


func _update_workers(dt: float) -> void:
    for worker in workers:
        if int(worker["task"]) == Task.IDLE:
            continue

        worker["remaining"] = maxf(0.0, float(worker["remaining"]) - dt)
        var duration := maxf(0.001, float(worker["duration"]))
        worker["progress"] = clampf(1.0 - float(worker["remaining"]) / duration, 0.0, 1.0)

        if float(worker["remaining"]) <= 0.0:
            _complete_task(worker)


func _assign_idle_workers() -> void:
    for worker in workers:
        if int(worker["task"]) != Task.IDLE:
            continue

        var task := _choose_task_for_worker(worker)
        if task == Task.IDLE:
            continue
        _start_task(worker, task)


func _choose_task_for_worker(worker: Dictionary) -> int:
    if facility_rank < 2:
        return _choose_task()

    var can_store := inbound_queue > 0 and rack_stock + _reserved_store_slots() < rack_capacity
    var can_pick := rack_stock > 0 and open_orders > 0
    var can_ship := packed_queue > 0
    match String(worker.get("role", "")):
        "store":
            return Task.STORE if can_store else Task.IDLE
        "pick":
            return Task.PICK if can_pick else Task.IDLE
        "ship":
            return Task.SHIP if can_ship else Task.IDLE
    return Task.IDLE


func _choose_task() -> int:
    var can_store := inbound_queue > 0 and rack_stock + _reserved_store_slots() < rack_capacity
    var can_pick := rack_stock > 0 and open_orders > 0
    var can_ship := packed_queue > 0

    match policy:
        Policy.INBOUND:
            if can_store:
                return Task.STORE
            if can_pick:
                return Task.PICK
            if can_ship:
                return Task.SHIP
        Policy.SHIP:
            if can_ship:
                return Task.SHIP
            if can_pick:
                return Task.PICK
            if can_store:
                return Task.STORE
        _:
            var inbound_pressure := float(inbound_queue) / float(_current_inbound_limit())
            var rack_pressure := float(rack_stock) / float(maxi(1, rack_capacity))
            var order_pressure := float(open_orders) / float(ORDER_LIMIT)
            var outbound_pressure := float(packed_queue) / 8.0

            if can_store and inbound_pressure >= maxf(order_pressure, outbound_pressure):
                return Task.STORE
            if can_ship and outbound_pressure >= maxf(inbound_pressure, order_pressure):
                return Task.SHIP
            if can_pick and (order_pressure >= 0.2 or rack_pressure >= 0.7):
                return Task.PICK
            if can_store:
                return Task.STORE
            if can_pick:
                return Task.PICK
            if can_ship:
                return Task.SHIP

    return Task.IDLE


func _start_task(worker: Dictionary, task: int) -> void:
    var base_duration := 3.0
    var source := "center"
    var target := "center"

    match task:
        Task.STORE:
            inbound_queue -= 1
            base_duration = 3.4
            source = "inbound"
            target = "rack"
        Task.PICK:
            rack_stock -= 1
            open_orders -= 1
            base_duration = 3.8
            if bool(facilities.get("fast_pick_rack", false)):
                base_duration *= 0.75
            elif bool(facilities.get("high_density_rack", false)):
                base_duration *= 1.14
            source = "rack"
            target = "packing"
        Task.SHIP:
            packed_queue -= 1
            base_duration = 3.0
            source = "packing"
            target = "outbound"

    var duration := base_duration / maxf(0.2, worker_speed)
    worker["task"] = int(task)
    worker["source"] = source
    worker["target"] = target
    worker["duration"] = duration
    worker["remaining"] = duration
    worker["progress"] = 0.0

    _emit("worker_task_started", {
        "worker_id": int(worker["id"]),
        "task": int(task),
        "source": source,
        "target": target,
        "duration": duration,
    })


func _complete_task(worker: Dictionary) -> void:
    var task := int(worker["task"])

    match task:
        Task.STORE:
            # A task may have started before a capacity-down renovation.
            # Preserve already-owned + in-flight inventory even when the rack is
            # temporarily over nominal capacity; new STORE tasks remain blocked
            # until stock drains below capacity.
            rack_stock += 1
            _emit("stored", {"rack_stock": rack_stock})
        Task.PICK:
            packing_queue += 1
            _emit("picked", {"packing_queue": packing_queue})
        Task.SHIP:
            shipped += 1
            money += BASE_SHIPMENT_VALUE
            _shipment_times.append(sim_time)
            if shipped % 5 == 0:
                research_rp += 1
            _emit("shipment", {
                "value": BASE_SHIPMENT_VALUE,
                "shipped": shipped,
                "money": money,
            })

    worker["task"] = int(Task.IDLE)
    worker["source"] = "center"
    worker["target"] = "center"
    worker["duration"] = 0.0
    worker["remaining"] = 0.0
    worker["progress"] = 0.0


func _update_progression(dt: float) -> void:
    if active_contract.is_empty():
        if contract_offers.is_empty():
            _contract_offer_cooldown = maxf(0.0, _contract_offer_cooldown - dt)
            if _contract_offer_cooldown <= 0.0:
                _refresh_contract_offers()
        return

    var result := _progression.advance_contract(
        active_contract,
        dt,
        shipped,
        inbound_queue,
        throughput_per_minute()
    )
    active_contract = (result.get("contract", {}) as Dictionary).duplicate(true)
    if bool(result.get("success", false)):
        _finish_contract(true)
    elif bool(result.get("failed", false)):
        _finish_contract(false)


func _finish_contract(success: bool) -> void:
    var finished: Dictionary = active_contract.duplicate(true)
    if success:
        var reward_cash := maxi(0, int(finished.get("reward_cash", 0)))
        var reward_rp := maxi(0, int(finished.get("reward_rp", 0)))
        var reward_rating := maxi(0, int(finished.get("reward_rating", 0)))
        money += reward_cash
        research_rp += reward_rp
        logistics_rating += reward_rating
        completed_contracts += 1
        _emit("contract_completed", {
            "title": String(finished.get("title", "契約")),
            "cash": reward_cash,
            "rp": reward_rp,
            "rating": reward_rating,
            "logistics_rating": logistics_rating,
        })
        if facility_rank < 2 and logistics_rating >= LogisticsProgression.RANK2_RATING:
            _rank_up_to_warehouse()
    else:
        _emit("contract_failed", {"title": String(finished.get("title", "契約"))})

    active_contract.clear()
    contract_offers.clear()
    _contract_offer_cooldown = 4.0


func _rank_up_to_warehouse() -> void:
    facility_rank = 2
    worker_count = maxi(worker_count, 5)
    staffing_plan = "balanced"
    staffing_cooldown = 0.0
    policy = Policy.BALANCED
    _sync_worker_roster()
    _apply_staffing_plan()
    _emit("rank_up", {
        "rank": facility_rank,
        "name": "Warehouse",
        "worker_count": worker_count,
    })


func _refresh_contract_offers() -> void:
    contract_offers = _progression.generate_offers(_next_contract_id)
    _next_contract_id += contract_offers.size()
    _emit("contract_offers", {"count": contract_offers.size()})


func _apply_staffing_plan() -> void:
    if facility_rank < 2:
        return
    var roles := _progression.staffing_roles(staffing_plan)
    if roles.is_empty():
        return
    for index in workers.size():
        workers[index]["role"] = roles[index % roles.size()]


func _sync_worker_roster() -> void:
    while workers.size() < worker_count:
        workers.append({
            "id": workers.size(),
            "task": int(Task.IDLE),
            "source": "center",
            "target": "center",
            "duration": 0.0,
            "remaining": 0.0,
            "progress": 0.0,
            "role": "",
        })

    while workers.size() > worker_count:
        workers.pop_back()

    if facility_rank >= 2:
        _apply_staffing_plan()


func _active_task_count(task: int) -> int:
    var count := 0
    for worker in workers:
        if int(worker["task"]) == task:
            count += 1
    return count


func _reserved_store_slots() -> int:
    return _active_task_count(Task.STORE) + (1 if forklift_active else 0)


func _prune_shipment_window() -> void:
    while not _shipment_times.is_empty() and sim_time - _shipment_times[0] > 60.0:
        _shipment_times.pop_front()


func _emit(type: String, extra: Dictionary) -> void:
    var event := {
        "type": type,
        "at": sim_time,
    }
    event.merge(extra, true)
    if type == "shipment":
        _measurement.record_shipment(sim_time, int(event.get("value", 0)))
    event_emitted.emit(event)
