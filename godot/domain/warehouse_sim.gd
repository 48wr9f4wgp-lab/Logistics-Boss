extends RefCounted
class_name WarehouseSim

signal event_emitted(event: Dictionary)

const CapitalCatalogScript = preload("res://domain/capital_catalog.gd")
const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")

const SAVE_SCHEMA := 2
const BASE_SHIPMENT_VALUE := 500
const INBOUND_INTERVAL := 3.0
const ORDER_INTERVAL := 3.0
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
var _packing_active: bool = false
var _packing_remaining: float = 0.0
var _packing_duration: float = 0.0
var _forklift_remaining: float = 0.0
var _shipment_times: Array[float] = []
var workers: Array[Dictionary] = []
var _capital: CapitalCatalog = CapitalCatalogScript.new()
var _measurement: FlowMeasurement = FlowMeasurementScript.new()


func _init() -> void:
    _sync_worker_roster()


func step(real_dt: float) -> void:
    var dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    if dt <= 0.0:
        return

    sim_time += dt
    _spawn_flow(dt)
    _update_packing(dt)
    _update_forklift(dt)
    _update_workers(dt)
    _assign_idle_workers()
    _prune_shipment_window()

    _measurement.record_state(sim_time, dt, inbound_queue, packing_queue, packed_queue)
    for result in _measurement.collect_completed(sim_time):
        last_measurement = result
        _emit("measurement_completed", result)


func set_policy(next_policy: int) -> void:
    if policy == next_policy:
        return
    policy = next_policy
    _emit("policy_changed", {"policy": int(policy)})


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
    if source_schema != 1 and source_schema != SAVE_SCHEMA:
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

    forklift_active = false
    forklift_progress = 0.0
    _forklift_remaining = 0.0
    _sync_worker_roster()
    if source_schema == 1:
        _emit("save_migrated", {"from_schema": 1, "to_schema": SAVE_SCHEMA})
    _emit("save_loaded", {"schema_version": SAVE_SCHEMA})
    return true


func _spawn_flow(dt: float) -> void:
    _inbound_timer -= dt
    while _inbound_timer <= 0.0:
        _inbound_timer += INBOUND_INTERVAL
        if inbound_queue < INBOUND_LIMIT:
            inbound_queue += 1
            _emit("inbound_arrival", {"count": inbound_queue})

    _order_timer -= dt
    while _order_timer <= 0.0:
        _order_timer += ORDER_INTERVAL
        if open_orders < ORDER_LIMIT:
            open_orders += 1
            _emit("order_arrival", {"count": open_orders})


func _update_packing(dt: float) -> void:
    if not _packing_active and packing_queue > 0:
        packing_queue -= 1
        _packing_active = true
        _packing_duration = 4.2 * pack_time_multiplier
        _packing_remaining = _packing_duration
        _emit("packing_started", {"duration": _packing_duration})

    if not _packing_active:
        return

    _packing_remaining -= dt
    if _packing_remaining <= 0.0:
        _packing_active = false
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
            rack_stock = mini(rack_capacity, rack_stock + 1)
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

        var task := _choose_task()
        if task == Task.IDLE:
            continue
        _start_task(worker, task)


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
            var inbound_pressure := float(inbound_queue) / float(INBOUND_LIMIT)
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
            rack_stock = mini(rack_capacity, rack_stock + 1)
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
        })

    while workers.size() > worker_count:
        workers.pop_back()


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
