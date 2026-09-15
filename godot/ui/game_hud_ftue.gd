extends "res://ui/game_hud_rank3.gd"
class_name FtueGameHud

signal ftue_step_changed(step_key: String)
signal ftue_completed(skipped: bool)

const FtueCoachScript = preload("res://ui/ftue_coach.gd")

var _ftue_coach: LogisticsFtueCoach


func bind_sim(next_sim: WarehouseSim) -> void:
    super.bind_sim(next_sim)
    _bind_ftue_if_ready()


func _ready() -> void:
    super._ready()
    _ftue_coach = FtueCoachScript.new()
    _ftue_coach.step_changed.connect(_on_ftue_step_changed)
    _ftue_coach.completed.connect(_on_ftue_completed)
    add_child(_ftue_coach)
    _bind_ftue_if_ready()


func current_ftue_step() -> String:
    if _ftue_coach == null or not _ftue_coach.visible:
        return ""
    return _ftue_coach.current_step_key()


func _bind_ftue_if_ready() -> void:
    if _ftue_coach == null or sim == null or _manage_button == null or _sheet == null:
        return
    var policy_buttons: Array[Button] = [_flow_button, _inbound_button, _outbound_button]
    _ftue_coach.bind_context(sim, _manage_button, policy_buttons, _sheet)


func _on_ftue_step_changed(step_key: String) -> void:
    ftue_step_changed.emit(step_key)


func _on_ftue_completed(skipped: bool) -> void:
    ftue_completed.emit(skipped)
