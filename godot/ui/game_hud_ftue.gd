extends "res://ui/game_hud_rank3.gd"
class_name FtueGameHud

const FtueCoachScript = preload("res://ui/ftue_coach.gd")

var _ftue_coach: LogisticsFtueCoach


func bind_sim(next_sim: WarehouseSim) -> void:
    super.bind_sim(next_sim)
    _bind_ftue_if_ready()


func _ready() -> void:
    super._ready()
    _ftue_coach = FtueCoachScript.new()
    add_child(_ftue_coach)
    _bind_ftue_if_ready()


func _bind_ftue_if_ready() -> void:
    if _ftue_coach == null or sim == null or _manage_button == null or _sheet == null:
        return
    var policy_buttons: Array[Button] = [_flow_button, _inbound_button, _outbound_button]
    _ftue_coach.bind_context(sim, _manage_button, policy_buttons, _sheet)
