extends PanelContainer
class_name LogisticsFtueCoach

signal step_changed(step_key: String)
signal completed(skipped: bool)

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const DONE_PATH := "user://logistics_boss_ftue_v1.done"
const COACH_TOP := 156.0
const COACH_BOTTOM := 214.0

enum Step {
    OBSERVE,
    POLICY,
    MANAGE,
    INVEST,
    COMPLETE,
}

var sim: WarehouseSim
var _step: int = Step.OBSERVE
var _observe_elapsed := 0.0
var _complete_elapsed := 0.0
var _investment_started := false
var _persist_completion := true
var _bound := false

var _manage_button: Button
var _policy_buttons: Array[Button] = []
var _sheet: PanelContainer
var _step_label: Label
var _body_label: Label
var _skip_button: Button


func _ready() -> void:
    anchor_left = 0.0
    anchor_right = 1.0
    anchor_top = 0.0
    anchor_bottom = 0.0
    offset_left = 12.0
    offset_right = -12.0
    # At the 390x844 reference viewport the compact release bottleneck chip ends
    # at y=150 and the Management sheet begins around y=219. Keep onboarding in
    # the protected gap so neither surface overlaps the warehouse core or each other.
    offset_top = COACH_TOP
    offset_bottom = COACH_BOTTOM
    mouse_filter = Control.MOUSE_FILTER_STOP
    add_theme_stylebox_override("panel", _panel_style())

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 8)
    margin.add_theme_constant_override("margin_top", 6)
    margin.add_theme_constant_override("margin_bottom", 6)
    add_child(margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    margin.add_child(row)

    var copy := VBoxContainer.new()
    copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    copy.add_theme_constant_override("separation", 1)
    row.add_child(copy)

    _step_label = Label.new()
    _step_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _step_label.add_theme_font_size_override("font_size", 9)
    _step_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.28))
    copy.add_child(_step_label)

    _body_label = Label.new()
    _body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _body_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _body_label.add_theme_font_size_override("font_size", 11)
    _body_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
    copy.add_child(_body_label)

    _skip_button = Button.new()
    _skip_button.text = "スキップ"
    _skip_button.custom_minimum_size = Vector2(56, 36)
    _skip_button.add_theme_font_override("font", JAPANESE_UI_FONT)
    _skip_button.add_theme_font_size_override("font_size", 9)
    _skip_button.pressed.connect(_skip)
    row.add_child(_skip_button)

    visible = false
    _render_step()


func bind_context(
    next_sim: WarehouseSim,
    manage_button: Button,
    policy_buttons: Array[Button],
    sheet: PanelContainer,
    persist_completion: bool = true
) -> void:
    _disconnect_context()
    sim = next_sim
    _manage_button = manage_button
    _policy_buttons = policy_buttons
    _sheet = sheet
    _persist_completion = persist_completion
    _step = Step.OBSERVE
    _observe_elapsed = 0.0
    _complete_elapsed = 0.0
    _investment_started = false

    if sim == null or _manage_button == null or _sheet == null:
        visible = false
        return
    if not _should_run():
        visible = false
        return

    if not sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.connect(_on_sim_event)
    if not _manage_button.pressed.is_connected(_on_manage_pressed):
        _manage_button.pressed.connect(_on_manage_pressed)

    _bound = true
    visible = true
    _render_step()
    step_changed.emit(current_step_key())


func current_step_key() -> String:
    match _step:
        Step.OBSERVE:
            return "observe"
        Step.POLICY:
            return "policy"
        Step.MANAGE:
            return "manage"
        Step.INVEST:
            return "invest"
        Step.COMPLETE:
            return "complete"
    return "unknown"


func body_text() -> String:
    return _body_label.text if _body_label != null else ""


func _process(delta: float) -> void:
    if not visible or sim == null:
        return

    if _step == Step.OBSERVE:
        _observe_elapsed += maxf(0.0, delta)
        var bottleneck: Dictionary = sim.bottleneck()
        if _observe_elapsed >= 7.0 or int(bottleneck.get("severity", 0)) > 0:
            _advance_to(Step.POLICY)
    elif _step == Step.COMPLETE:
        _complete_elapsed += maxf(0.0, delta)
        if _complete_elapsed >= 5.0:
            visible = false


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    if event_type == "policy_changed" and _step <= Step.POLICY:
        _advance_to(Step.MANAGE)
        return

    if event_type in [
        "upgrade_purchased",
        "facility_purchased",
        "receiving_annex_purchased",
        "inbound_carrier_program_purchased",
    ] and _step <= Step.INVEST:
        _investment_started = true
        if _step < Step.INVEST:
            _advance_to(Step.INVEST)
        else:
            _render_step()
        return

    if event_type == "measurement_completed" and _step == Step.INVEST and _investment_started:
        _complete_ftue()


func _on_manage_pressed() -> void:
    call_deferred("_check_manage_open")


func _check_manage_open() -> void:
    if not visible or _sheet == null:
        return
    if _sheet.visible and _step <= Step.MANAGE:
        _advance_to(Step.INVEST)


func _advance_to(next_step: int) -> void:
    if next_step <= _step:
        return
    _step = next_step
    _render_step()
    step_changed.emit(current_step_key())


func _complete_ftue() -> void:
    if _step == Step.COMPLETE:
        return
    _step = Step.COMPLETE
    _complete_elapsed = 0.0
    _write_completion_marker()
    _render_step()
    step_changed.emit(current_step_key())
    completed.emit(false)


func _skip() -> void:
    _write_completion_marker()
    completed.emit(true)
    visible = false


func _should_run() -> bool:
    if _persist_completion and FileAccess.file_exists(DONE_PATH):
        return false
    if sim.facility_rank > 1 or sim.logistics_rating > 0 or sim.shipped >= 3:
        return false
    if sim.worker_count > 3 or sim.rack_level > 0 or sim.speed_level > 0 or sim.pack_level > 0 or sim.forklift_unlocked:
        return false
    return true


func _write_completion_marker() -> void:
    if not _persist_completion:
        return
    var file := FileAccess.open(DONE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string("core_loop_ftue_v1\n")
    file.close()


func _render_step() -> void:
    if _step_label == null or _body_label == null:
        return

    _reset_button_emphasis()
    match _step:
        Step.OBSERVE:
            _step_label.text = "START GUIDE  1/4  観察"
            _body_label.text = "物流は自動で流れます。まず上の「詰まり分析」を見て、どこが滞るか観察。"
        Step.POLICY:
            _step_label.text = "START GUIDE  2/4  運用判断"
            _body_label.text = "詰まりに合わせて下の「入庫 / 出庫 / バランス」を切り替えて流れを整える。"
            _emphasize_policy_buttons()
        Step.MANAGE:
            _step_label.text = "START GUIDE  3/4  投資判断"
            _body_label.text = "次は「管理」を開く。詰まりの原因に効く投資だけを選ぶ。"
            if _manage_button != null:
                _manage_button.modulate = Color(1.0, 0.86, 0.60)
        Step.INVEST:
            _step_label.text = "START GUIDE  4/4  効果測定"
            _body_label.text = (
                "計測中。倉庫の流れを観察し、結果の「改善 / 横ばい / 要再判断」まで確認する。"
                if _investment_started
                else "投資を1つ実行。投資前の流れ→後25秒を自動計測し、結果まで確認する。"
            )
        Step.COMPLETE:
            _step_label.text = "CORE LOOP  習得"
            _body_label.text = "観察 → 判断 → 投資 → 測定。結果を見て次のボトルネックへ再投資しよう。"
            if _skip_button != null:
                _skip_button.visible = false


func _emphasize_policy_buttons() -> void:
    for button in _policy_buttons:
        if button != null:
            button.modulate = Color(1.0, 0.88, 0.70)


func _reset_button_emphasis() -> void:
    if _manage_button != null:
        _manage_button.modulate = Color.WHITE
    for button in _policy_buttons:
        if button != null:
            button.modulate = Color.WHITE
    if _skip_button != null:
        _skip_button.visible = _step != Step.COMPLETE


func _disconnect_context() -> void:
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
    if _manage_button != null and _manage_button.pressed.is_connected(_on_manage_pressed):
        _manage_button.pressed.disconnect(_on_manage_pressed)
    _bound = false


func _exit_tree() -> void:
    _disconnect_context()


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.062, 0.95)
    style.border_color = Color(1.0, 0.58, 0.20, 0.76)
    style.set_border_width_all(1)
    style.set_corner_radius_all(11)
    style.content_margin_left = 0.0
    style.content_margin_right = 0.0
    style.content_margin_top = 0.0
    style.content_margin_bottom = 0.0
    return style
