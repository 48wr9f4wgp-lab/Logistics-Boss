extends "res://domain/rank3_warehouse_sim.gd"

var inbound_supply_multiplier: float = 1.0
var holding_capacity: int = 0
var holding_queue: int = 0
var potential_inbound_arrivals: int = 0
var direct_inbound_entries: int = 0
var held_inbound_arrivals: int = 0
var released_inbound_arrivals: int = 0
var lost_inbound_arrivals: int = 0
var max_holding_queue: int = 0


func configure_inbound_supply(multiplier: float, next_holding_capacity: int) -> void:
    inbound_supply_multiplier = clampf(multiplier, 0.50, 1.0)
    holding_capacity = maxi(0, next_holding_capacity)
    holding_queue = 0
    potential_inbound_arrivals = 0
    direct_inbound_entries = 0
    held_inbound_arrivals = 0
    released_inbound_arrivals = 0
    lost_inbound_arrivals = 0
    max_holding_queue = 0


func _current_inbound_interval() -> float:
    return super._current_inbound_interval() * inbound_supply_multiplier


func _spawn_flow(dt: float) -> void:
    _release_holding_queue()

    _inbound_timer -= dt
    while _inbound_timer <= 0.0:
        _inbound_timer += _current_inbound_interval()
        potential_inbound_arrivals += 1
        if inbound_queue < _current_inbound_limit():
            inbound_queue += 1
            direct_inbound_entries += 1
            _emit("inbound_arrival", {"count": inbound_queue, "source": "scheduled"})
        elif holding_queue < holding_capacity:
            holding_queue += 1
            held_inbound_arrivals += 1
            max_holding_queue = maxi(max_holding_queue, holding_queue)
            _emit("rank3_inbound_held", {
                "holding_queue": holding_queue,
                "holding_capacity": holding_capacity,
            })
        else:
            lost_inbound_arrivals += 1
            _emit("rank3_inbound_lost", {
                "lost": lost_inbound_arrivals,
                "holding_queue": holding_queue,
            })

    _order_timer -= dt
    while _order_timer <= 0.0:
        _order_timer += _current_order_interval()
        if open_orders < ORDER_LIMIT:
            open_orders += 1
            _emit("order_arrival", {"count": open_orders})

    _release_holding_queue()


func _release_holding_queue() -> void:
    while holding_queue > 0 and inbound_queue < _current_inbound_limit():
        holding_queue -= 1
        inbound_queue += 1
        released_inbound_arrivals += 1
        _emit("inbound_arrival", {"count": inbound_queue, "source": "holding"})
        _emit("rank3_inbound_released", {
            "holding_queue": holding_queue,
            "inbound_queue": inbound_queue,
        })
