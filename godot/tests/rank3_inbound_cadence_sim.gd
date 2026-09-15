extends "res://tests/rank3_receiving_orchestration_sim.gd"

var inbound_supply_multiplier: float = 1.0


func configure_inbound_supply(multiplier: float, holding_capacity: int) -> void:
    inbound_supply_multiplier = clampf(multiplier, 0.50, 1.0)
    configure_receiving_orchestration(holding_capacity)


func _current_inbound_interval() -> float:
    return super._current_inbound_interval() * inbound_supply_multiplier
