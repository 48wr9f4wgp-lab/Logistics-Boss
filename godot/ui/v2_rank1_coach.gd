extends PanelContainer
class_name V2Rank1Coach

signal step_changed(step_key: String)
signal completed(skipped: bool)

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const DONE_PATH := "user://flotra_v2_rank1_ftue_v1.done"

enum Step {
    OBSERVE,
    INSPECT,
    ACT,
    MEASURE,
    COMPLETE,
}

var sim: WarehouseSim
var _zone_interaction: WarehouseZoneInteractionView
var _step: int = Step.OBSERVE
var _observe_elapsed := 0.0
var _complete_elapsed := 0.0
var _measurement_kind := ""
var _inspect_zone := ""
var _persist_completion := true

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
    offset_top = 232.0
    offset_bottom = 302.0
    mouse_filter = Control.MOUSE_FILTER_STOP
    z_index = 55
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
    zone_interaction: WarehouseZoneInteractionView,
    persist_completion: bool = true
) -> void:
    _disconnect_context()
    sim = next_sim
    _zone_interaction = zone_interaction
    _persist_completion = persist_completion
    _step = Step.OBSERVE
    _observe_elapsed = 0.0
    _complete_elapsed = 0.0
    _measurement_kind = ""
    _inspect_zone = ""

    if sim == null or _zone_interaction == null or not _should_run():
        visible = false
        return

    if not sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.connect(_on_sim_event)
    if not _zone_interaction.zone_selected.is_connected(_on_zone_selected):
        _zone_interaction.zone_selected.connect(_on_zone_selected)

    visible = true
    _render_step()
    step_changed.emit(current_step_key())


func current_step_key() -> String:
    match _step:
        Step.OBSERVE:
            return "observe"
        Step.INSPECT:
            return "inspect"
        Step.ACT:
            return "act"
        Step.MEASURE:
            return "measure"
        Step.COMPLETE:
            return "complete"
    return ""


func body_text() -> String:
    return _body_label.text if _body_label != null else ""


func _process(delta: float) -> void:
    if not visible or sim == null:
        return

    if _step == Step.OBSERVE:
        _observe_elapsed += maxf(0.0, delta)
        var info: Dictionary = sim.bottleneck()
        if _observe_elapsed >= 5.0 or int(info.get("severity", 0)) > 0:
            _advance_to(Step.INSPECT)
    elif _step == Step.COMPLETE:
        _complete_elapsed += maxf(0.0, delta)
        if _complete_elapsed >= 4.0:
            visible = false


func _on_zone_selected(zone_key: String) -> void:
    if _step <= Step.INSPECT:
        _inspect_zone = zone_key
        if _zone_interaction != null:
            _zone_interaction.clear_guidance_zone()
        _advance_to(Step.ACT)


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    if event_type == "rank1_project_purchased" and _step <= Step.ACT:
        _measurement_kind = String(event.get("measurement_kind", ""))
        _advance_to(Step.MEASURE)
        return

    if event_type == "measurement_completed" and _step == Step.MEASURE:
        var kind := String(event.get("kind", ""))
        if _measurement_kind.is_empty() or kind != _measurement_kind:
            return
        _complete_ftue()


func _advance_to(next_step: int) -> void:
    if next_step <= _step:
        return
    _step = next_step
    if _step == Step.INSPECT:
        _refresh_inspect_guidance()
    elif _step > Step.INSPECT and _zone_interaction != null:
        _zone_interaction.clear_guidance_zone()
    _render_step()
    step_changed.emit(current_step_key())


func _refresh_inspect_guidance() -> void:
    _inspect_zone = _bottleneck_zone()
    if _zone_interaction == null:
        return
    if _inspect_zone.is_empty():
        _zone_interaction.clear_guidance_zone()
    else:
        _zone_interaction.set_guidance_zone(_inspect_zone)


func _bottleneck_zone() -> String:
    if sim == null:
        return ""
    var info: Dictionary = sim.bottleneck()
    match String(info.get("key", "stable")):
        "inbound":
            return "inbound"
        "rack":
            return "storage"
        "packing":
            return "packing"
        "outbound":
            return "shipping"
        "orders":
            return "picking"
    return ""


func guidance_zone() -> String:
    return _inspect_zone


func _complete_ftue() -> void:
    if _step == Step.COMPLETE:
        return
    if _zone_interaction != null:
        _zone_interaction.clear_guidance_zone()
    _step = Step.COMPLETE
    _complete_elapsed = 0.0
    _write_completion_marker()
    _render_step()
    step_changed.emit(current_step_key())
    completed.emit(false)


func _skip() -> void:
    if _zone_interaction != null:
        _zone_interaction.clear_guidance_zone()
    _write_completion_marker()
    completed.emit(true)
    visible = false


func _should_run() -> bool:
    if _persist_completion and FileAccess.file_exists(DONE_PATH):
        return false
    if sim.facility_rank > 1 or sim.logistics_rating > 0 or sim.shipped >= 3:
        return false
    if sim.has_method("rank1_projects_completed") and int(sim.call("rank1_projects_completed")) > 0:
        return false
    return true


func _write_completion_marker() -> void:
    if not _persist_completion:
        return
    var file := FileAccess.open(DONE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string("flotra_v2_rank1_ftue_v1\n")
    file.close()


func _render_step() -> void:
    if _step_label == null or _body_label == null:
        return

    match _step:
        Step.OBSERVE:
            _step_label.text = "START GUIDE  1/4  目的"
            _body_label.text = "出荷で稼ぎ、設備を好きな2種類導入して倉庫を拡張しよう。契約は任意。"
        Step.INSPECT:
            _step_label.text = "START GUIDE  2/4  現場確認"
            if _inspect_zone.is_empty():
                _body_label.text = "倉庫上のZone名には「タップ」と表示されます。気になるZoneを押して現場を確認。"
            else:
                _body_label.text = "倉庫上の「%s｜ここをタップ」を押して現場を確認。" % _zone_label(_inspect_zone)
        Step.ACT:
            _step_label.text = "START GUIDE  3/4  判断"
            _body_label.text = "現場で設備の姿と効果を見る。購入前に内容を確認できる。"
        Step.MEASURE:
            _step_label.text = "START GUIDE  4/4  結果"
            _body_label.text = "増えた設備の仕事を見よう。結果は自動計測。次の投資に進んでもOK。"
        Step.COMPLETE:
            _step_label.text = "CORE LOOP  習得"
            _body_label.text = "観察 → Zone確認 → 介入 → 結果。次に詰まる場所は倉庫から探す。"

    if _skip_button != null:
        _skip_button.visible = _step != Step.COMPLETE


func _zone_label(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "INBOUND"
        "storage":
            return "STORAGE"
        "picking":
            return "PICKING"
        "packing":
            return "PACKING"
        "shipping":
            return "SHIPPING"
    return zone_key.to_upper()


func _disconnect_context() -> void:
    if _zone_interaction != null:
        _zone_interaction.clear_guidance_zone()
    if sim != null and sim.event_emitted.is_connected(_on_sim_event):
        sim.event_emitted.disconnect(_on_sim_event)
    if _zone_interaction != null and _zone_interaction.zone_selected.is_connected(_on_zone_selected):
        _zone_interaction.zone_selected.disconnect(_on_zone_selected)


func _exit_tree() -> void:
    _disconnect_context()


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.045, 0.062, 0.95)
    style.border_color = Color(1.0, 0.58, 0.20, 0.76)
    style.set_border_width_all(1)
    style.set_corner_radius_all(11)
    return style
