extends "res://domain/rank3_warehouse_sim.gd"

var store_cycle_multiplier: float = 1.0
var replenishment_cycle: float = 0.0
var demand_buffer_capacity: int = 0

var pending_orders: int = 0
var captured_order_arrivals: int = 0
var released_order_arrivals: int = 0
var lost_order_arrivals: int = 0
var replenishment_starts: int = 0
var replenishment_completions: int = 0

var _replenishment_active: bool = false
var _replenishment_remaining: float = 0.0


func configure_supply_candidate(
    store_multiplier: float,
    reserve_replenishment_cycle: float,
    order_buffer_capacity: int
) -> void:
    store_cycle_multiplier = clampf(store_multiplier, 0.35, 1.0)
    replenishment_cycle = maxf(0.0, reserve_replenishment_cycle)
    demand_buffer_capacity = maxi(0, order_buffer_capacity)
    pending_orders = 0
    captured_order_arrivals = 0
    released_order_arrivals = 0
    lost_order_arrivals = 0
    replenishment_starts = 0
    replenishment_completions = 0
    _replenishment_active = false
    _replenishment_remaining = 0.0


func step(real_dt: float) -> void:
    super.step(real_dt)
    var dt := maxf(0.0, real_dt) * maxf(0.0, time_scale)
    if dt <= 0.0:
        return
    _update_replenishment_lane(dt)
    _release_pending_orders()


func _spawn_flow(dt: float) -> void:
    _release_pending_orders()

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
        elif demand_buffer_capacity > 0 and pending_orders < demand_buffer_capacity:
            pending_orders += 1
            captured_order_arrivals += 1
            _emit("rank3_order_buffered", {
                "pending_orders": pending_orders,
                "capacity": demand_buffer_capacity,
            })
        else:
            lost_order_arrivals += 1
            _emit("rank3_order_lost", {"lost": lost_order_arrivals})


func _start_task(worker: Dictionary, task: int) -> void:
    super._start_task(worker, task)
    if task != Task.STORE or store_cycle_multiplier >= 0.999:
        return

    var adjusted_duration := maxf(0.05, float(worker.get("duration", 0.0)) * store_cycle_multiplier)
    worker["duration"] = adjusted_duration
    worker["remaining"] = adjusted_duration
    worker["progress"] = 0.0


func _reserved_store_slots() -> int:
    var reserved := super._reserved_store_slots()
    if _replenishment_active:
        reserved += 1
    return reserved


func _update_replenishment_lane(dt: float) -> void:
    if replenishment_cycle <= 0.0:
        return

    if _replenishment_active:
        _replenishment_remaining = maxf(0.0, _replenishment_remaining - dt)
        if _replenishment_remaining <= 0.0:
            _replenishment_active = false
            rack_stock = mini(rack_capacity, rack_stock + 1)
            replenishment_completions += 1
            _emit("rank3_replenishment_completed", {
                "rack_stock": rack_stock,
                "completions": replenishment_completions,
            })

    if _replenishment_active:
        return
    if inbound_queue <= 0:
        return
    if rack_stock + _reserved_store_slots() >= rack_capacity:
        return

    inbound_queue -= 1
    _replenishment_active = true
    _replenishment_remaining = replenishment_cycle
    replenishment_starts += 1
    _emit("rank3_replenishment_started", {
        "duration": replenishment_cycle,
        "starts": replenishment_starts,
    })


func _release_pending_orders() -> void:
    while pending_orders > 0 and open_orders < ORDER_LIMIT:
        pending_orders -= 1
        open_orders += 1
        released_order_arrivals += 1
        _emit("rank3_order_released", {
            "open_orders": open_orders,
            "pending_orders": pending_orders,
        })
