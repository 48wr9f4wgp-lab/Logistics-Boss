extends CanvasLayer
## Isolated, read-only presentation for the layout experiment.
## Every state change is a signal owned by the prototype scene, never a save write.

signal slot_action_requested(slot_id: String, choice_id: String)
signal layout_action_requested(layout_id: String)
signal workload_requested(workload_id: String)
signal reset_requested
signal exit_requested
signal back_requested
signal comparison_requested
signal trial_started
signal pause_requested(paused: bool)
signal selected_layout_changed(layout_id: String)
signal selected_slot_changed(slot_id: String)
signal candidate_changed(slot_id: String, choice_id: String)
signal slot_candidate_changed(slot_id: String, choice_id: String)
signal world_rect_changed

const NAVY := Color("14232e")
const RAISED := Color("203641")
const TEAL := Color("83cbbb")
const AMBER := Color("edbd79")
const TEXT := Color("f4f5ed")
const MUTED := Color("c0ced0")
const PAPER := Color("f0f3e9")
const INK := Color("17343c")
const LINE := Color("b7c8c3")
const FONT = preload("res://assets/fonts/MPLUS1p-Regular.ttf")

var sim: Object
var _snapshot: Dictionary = {}
var _refresh_clock := 0.0
var _root: Control
var _header: Panel
var _reason_panel: Panel
var _bottom: Panel
var _back: Button
var _conditions: Button
var _title: Label
var _safe_note: Label
var _reason_title: Label
var _reason_detail: Label
var _shipped: Label
var _travel: Label
var _waiting: Label
var _observed_note: Label
var _primary: Button
var _compare: Button
var _mask: ColorRect
var _sheet: Panel
var _sheet_title: Label
var _close: Button
var _body: Control
var _sheet_kind := ""
var _sheet_height := 440.0
var _slot_index := 0
var _choice_id := ""
var _slot_options: Array = []
var _choice_buttons: Array[Button] = []
var _choice_title: Label
var _benefit: Label
var _tradeoff: Label
var _cost: Label
var _apply: Button
var _previous: Button
var _next: Button
var _trial_running := false
var _comparison_data: Variant = {}
var _comparison_workload := "inbound"
var _notice := ""
var _notice_seconds := 0.0
var _built := false
var _last_world_insets := Vector2(-1, -1)
var _input_epoch := 0

func _ready() -> void:
    layer = 20
    _build()
    refresh()
    show_entry()

func bind_sim(next_sim: Object) -> void:
    sim = next_sim
    if _built:
        refresh()

func _build() -> void:
    _root = Control.new()
    _root.name = "LayoutHUD"
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.theme = Theme.new()
    _root.theme.default_font = FONT
    _root.theme.default_font_size = 16
    add_child(_root)
    _header = _panel(_root, NAVY, 0)
    _back = _button(_header, "戻る", _go_back, false, false)
    _back.name = "Back"
    _conditions = _button(_header, "条件", show_conditions, false, false)
    _conditions.name = "Conditions"
    _title = _label(_header, "配置ラボ", 20, TEXT)
    _safe_note = _label(_header, "保存なしの専用試作", 12, MUTED)
    _reason_panel = _panel(_root, NAVY, 14)
    _reason_title = _label(_reason_panel, "流れを観測しています", 20, AMBER)
    _reason_detail = _label(_reason_panel, "同じ設備でも、置く場所で流れが変わります", 14, MUTED)
    _bottom = _panel(_root, NAVY, 16)
    _shipped = _label(_bottom, "出荷  —箱", 21, TEXT)
    _travel = _label(_bottom, "運搬 —秒", 16, MUTED)
    _waiting = _label(_bottom, "道の待ち —秒", 16, MUTED)
    _observed_note = _label(_bottom, "開始後の実測値", 13, MUTED)
    _primary = _button(_bottom, "配置を変える", _primary_action, true, false)
    _primary.name = "ChangeLayout"
    _compare = _button(_bottom, "比較", _request_comparison, false, false)
    _compare.name = "Compare"
    _mask = ColorRect.new()
    _mask.name = "SheetScrim"
    _mask.color = Color(0.025, 0.06, 0.08, 0.52)
    _mask.mouse_filter = Control.MOUSE_FILTER_STOP
    _root.add_child(_mask)
    _sheet = _panel(_root, PAPER, 22)
    _sheet.name = "ChoiceSheet"
    _sheet.mouse_filter = Control.MOUSE_FILTER_STOP
    _sheet_title = _label(_sheet, "配置を変える", 21, INK)
    _close = _button(_sheet, "閉じる", close_sheet, false, true)
    _close.name = "CloseSheet"
    _body = Control.new()
    _body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sheet.add_child(_body)
    _root.resized.connect(_layout)
    _built = true
    _layout()

func _panel(parent: Node, fill: Color, radius: int) -> Panel:
    var panel := Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _style(fill, fill, radius))
    parent.add_child(panel)
    return panel

func _style(fill: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 10
    style.content_margin_right = 10
    return style

func _label(parent: Node, value: String, font_size: int, color: Color = INK) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    parent.add_child(label)
    return label

func _button(parent: Node, value: String, action: Callable, primary: bool = false, light: bool = true) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(48, 48)
    button.add_theme_font_size_override("font_size", 17)
    button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    var fill := TEAL if primary else (Color("e3eae2") if light else RAISED)
    var foreground := INK if (light or primary) else TEXT
    button.add_theme_stylebox_override("normal", _style(fill, LINE if light and not primary else fill))
    button.add_theme_stylebox_override("hover", _style(fill.lightened(0.08), TEAL))
    button.add_theme_stylebox_override("pressed", _style(AMBER, AMBER))
    button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("bd741e")))
    button.add_theme_stylebox_override("disabled", _style(Color("dce3dc") if light else RAISED, LINE if light else RAISED))
    button.add_theme_color_override("font_color", foreground)
    button.add_theme_color_override("font_hover_color", foreground)
    button.add_theme_color_override("font_focus_color", foreground)
    button.add_theme_color_override("font_pressed_color", INK)
    button.add_theme_color_override("font_disabled_color", Color("526c71") if light else MUTED)
    button.set_meta("press_epoch", _input_epoch)
    button.button_down.connect(func(): button.set_meta("press_epoch", _input_epoch))
    button.pressed.connect(func():
        if int(button.get_meta("press_epoch", -1)) == _input_epoch:
            action.call()
    )
    parent.add_child(button)
    return button

func _rect(control: Control, x: float, y: float, width: float, height: float) -> void:
    control.position = Vector2(x, y)
    control.size = Vector2(maxf(0, width), maxf(0, height))
    # Wrapped text first reflows at the new width, then yields its true minimum height.
    control.set_deferred("size", Vector2(maxf(0, width), maxf(0, height)))

func _layout() -> void:
    if not _built:
        return
    var width := _root.size.x
    var height := _root.size.y
    _rect(_header, 0, 0, width, 68)
    _rect(_back, 10, 10, 56, 48)
    _rect(_conditions, width - 66, 10, 56, 48)
    _rect(_title, 78, 7, width - 156, 30)
    _rect(_safe_note, 78, 36, width - 156, 22)
    _rect(_reason_panel, 12, 80, width - 24, 86)
    _rect(_reason_title, 14, 9, width - 52, 30)
    _rect(_reason_detail, 14, 40, width - 52, 38)
    _rect(_bottom, 12, height - 162, width - 24, 150)
    _rect(_shipped, 14, 9, 118, 34)
    _rect(_travel, 136, 7, width - 174, 27)
    _rect(_waiting, 136, 31, width - 174, 27)
    _rect(_observed_note, 14, 55, width - 52, 28)
    _rect(_primary, 12, 90, width - 132, 48)
    _rect(_compare, width - 108, 90, 72, 48)
    _rect(_mask, 0, 68, width, height - 68)
    if _sheet_kind == "editor":
        _sheet_height = 368.0 if height < 740 else 456.0
    var actual_height := minf(_sheet_height, height - 92)
    _rect(_sheet, 12, height - actual_height - 12, width - 24, actual_height)
    _rect(_sheet_title, 18, 14, width - 158, 48)
    _rect(_close, width - 118, 14, 76, 48)
    _rect(_body, 18, 76, width - 60, actual_height - 94)
    if not _sheet_kind.is_empty():
        _layout_body()
    _update_world_region()

func _process(delta: float) -> void:
    _refresh_clock += delta
    if _notice_seconds > 0:
        _notice_seconds -= delta
        if _notice_seconds <= 0:
            _notice = ""
    if _refresh_clock >= 0.2:
        _refresh_clock = 0.0
        refresh()

func refresh() -> void:
    if not _built:
        return
    if is_instance_valid(sim) and sim.has_method("snapshot"):
        var data: Variant = sim.call("snapshot")
        if data is Dictionary:
            _snapshot = data
    var elapsed := float(_snapshot.get("sim_time", 0.0))
    var duration := float(_snapshot.get("duration", 120.0))
    _shipped.text = "出荷  %d箱" % int(_snapshot.get("shipped", 0))
    _travel.text = "歩行の合計  %.0f秒" % float(_snapshot.get("travel_seconds", 0.0))
    _waiting.text = "道待ちの合計  %.0f秒" % float(_snapshot.get("aisle_wait_seconds", 0.0))
    var wave: Dictionary = _snapshot.get("workload_wave", {})
    var phase := str(wave.get("label", _snapshot.get("phase_label", _snapshot.get("wave_label", ""))))
    if duration <= 0:
        _observed_note.text = "通常の波・%s・%d秒経過" % [phase, int(elapsed)] if not phase.is_empty() else "通常の波・%d秒経過の実測" % int(elapsed)
    else:
        _observed_note.text = "比較用：%s・%d / %d秒" % ["入荷集中" if str(_snapshot.get("workload_id", "")) == "inbound" else "注文集中", mini(int(elapsed), int(duration)), int(duration)]
    var pending := str(_snapshot.get("pending_layout_id", ""))
    var queued: Dictionary = _snapshot.get("queues", {})
    var waiting_workers := 0
    for worker in _snapshot.get("workers", []):
        if bool(worker.get("waiting", false)):
            waiting_workers += 1
    if not _notice.is_empty():
        _reason_title.text = "配置ラボ"
        _reason_detail.text = _notice
    elif not _trial_running and _sheet_kind != "entry":
        _reason_title.text = "観測を一時停止中"
        _reason_detail.text = "「観測を再開」で、荷物と設備の動きが再開します"
    elif not pending.is_empty():
        _reason_title.text = "配置を切り替えています"
        _reason_detail.text = "運搬中の荷物を完了してから設備を動かします"
    elif bool(_snapshot.get("finished", false)):
        _reason_title.text = "今回の観測が終わりました"
        _reason_detail.text = "「比較」で同じ条件の配置差を確認できます"
    elif waiting_workers > 0:
        _reason_title.text = "通路で %d人が譲り合い" % waiting_workers
        _reason_detail.text = "どの道で止まるかを見て、配置を比べよう"
    elif _count(queued.get("packing", 0)) > 1:
        _reason_title.text = "梱包の手前で荷物待ち"
        _reason_detail.text = "梱包位置を変えて、運ぶ距離と待ちを比べよう"
    elif _count(queued.get("inbound", 0)) > 1:
        _reason_title.text = "入荷の置き場に荷物待ち"
        _reason_detail.text = "棚までの距離と、通路で止まる時間に注目"
    else:
        _reason_title.text = str(_snapshot.get("bottleneck", "今は流れを観測中"))
        _reason_detail.text = "設備は買い切り。次は置く場所を工夫しよう"
    _conditions.disabled = _sheet_kind == "entry"
    _primary.disabled = not pending.is_empty() and _trial_running and not bool(_snapshot.get("finished", false))
    _primary.text = "もう一度試す" if bool(_snapshot.get("finished", false)) else ("配置を変える" if _trial_running else "観測を再開")
    if _sheet_kind == "editor":
        _update_choice()

func _count(value: Variant) -> int:
    return value.size() if value is Array or value is Dictionary else int(value)

func _workload_label() -> String:
    var current := str(_snapshot.get("workload_id", "inbound"))
    for option in _workloads():
        if str(option.get("id", "")) == current:
            return str(option.get("label", current))
    return "入荷が多い日" if current == "inbound" else "注文が多い日"

func _open_sheet(kind: String, title: String, height: float) -> void:
    _sheet_kind = kind
    if kind != "editor":
        selected_slot_changed.emit("")
    _sheet_title.text = title
    _close.text = "終了" if kind == "entry" else "閉じる"
    _sheet_height = height
    _choice_buttons.clear()
    _apply = null
    for child in _body.get_children():
        _body.remove_child(child)
        child.queue_free()
    _mask.show()
    _sheet.show()
    _sync_focus.call_deferred()
    _back.text = "戻る"
    _layout()

func close_sheet() -> void:
    if _sheet_kind == "entry":
        exit_requested.emit()
        return
    _sheet_kind = ""
    _mask.hide()
    _sheet.hide()
    _choice_id = ""
    selected_slot_changed.emit("")
    _sync_focus()
    (_compare if _primary.disabled else _primary).grab_focus()
    refresh()

func _go_back() -> void:
    if not _sheet_kind.is_empty():
        close_sheet()
    else:
        back_requested.emit()

func _unhandled_key_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _go_back()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if _built and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
        # Invalidate every captured press, including a pointer/key still held
        # when the app sleeps. Only a fresh button-down may activate on resume.
        _input_epoch += 1
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and _built:
        _go_back()

func show_entry() -> void:
    if not _built:
        return
    _open_sheet("entry", "保存しない配置ラボ", 372)
    _label(_body, "設備を買い終えた、その先へ", 23).name = "EntryLead"
    _label(_body, "棚と梱包台を、決まった枠で動かします。\n通路が空く利点と、運ぶ距離を比べよう。", 16).name = "EntryDescription"
    _label(_body, "専用の倉庫で、入荷と注文の波を観測\n本編のセーブ・お金・設備は変わりません", 15).name = "EntrySafety"
    _button(_body, "試作の続きに戻る" if float(_snapshot.get("sim_time", 0.0)) > 0.0 else "試作を始める", _start_trial, true).name = "StartTrial"
    _layout_body()

func show_intro() -> void:
    show_entry()

func show_play() -> void:
    _sheet_kind = ""
    _sheet.hide()
    _mask.hide()
    _update_world_region()
    _sync_focus()
    _primary.grab_focus()
    refresh()

func _start_trial() -> void:
    _trial_running = true
    show_play()
    trial_started.emit()

func set_trial_running(running: bool) -> void:
    _trial_running = running

func _read_slots() -> Array:
    if is_instance_valid(sim) and sim.has_method("slot_options"):
        var options: Variant = sim.call("slot_options")
        if options is Array:
            return options
    var options: Variant = _snapshot.get("slot_options", _snapshot.get("slots", []))
    return options if options is Array else []

func _primary_action() -> void:
    if bool(_snapshot.get("finished", false)):
        reset_requested.emit()
    elif not _trial_running:
        _trial_running = true
        pause_requested.emit(false)
        refresh()
    else:
        show_layout_editor()

func show_layout_editor() -> void:
    _slot_options = _read_slots()
    _slot_index = clampi(_slot_index, 0, maxi(0, _slot_options.size() - 1))
    _open_sheet("editor", "配置を変える", 456)
    if _slot_options.is_empty():
        _label(_body, "配置データを準備しています", 20).name = "EmptyTitle"
        _label(_body, "倉庫の準備ができたら、ここから区画を選べます", 16).name = "EmptyDetail"
        _button(_body, "倉庫へ戻る", close_sheet, true).name = "EmptyBack"
        _layout_body()
        return
    _previous = _button(_body, "前", _move_slot.bind(-1))
    _previous.name = "PreviousSlot"
    _next = _button(_body, "次", _move_slot.bind(1))
    _next.name = "NextSlot"
    _choice_title = _label(_body, "", 18)
    _choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _choice_title.name = "SelectedSlot"
    _benefit = _label(_body, "", 16)
    _benefit.name = "Benefit"
    _tradeoff = _label(_body, "", 16)
    _tradeoff.name = "Tradeoff"
    _cost = _label(_body, "", 13, Color("476266"))
    _cost.name = "Cost"
    _apply = _button(_body, "この場所に動かす", _apply_choice, true)
    _apply.name = "ApplyChoice"
    _choose_current_slot()

func _current_slot() -> Dictionary:
    if _slot_options.is_empty():
        return {}
    return _slot_options[_slot_index]

func _choose_current_slot() -> void:
    for button in _choice_buttons:
        _body.remove_child(button)
        button.queue_free()
    _choice_buttons.clear()
    var slot := _current_slot()
    _choice_id = str(slot.get("current_choice_id", slot.get("choice_id", slot.get("current", ""))))
    var choices: Array = slot.get("choices", [])
    if _choice_id.is_empty() and not choices.is_empty():
        _choice_id = str(choices[0].get("id", ""))
    for choice in choices:
        var id := str(choice.get("id", ""))
        var button := _button(_body, str(choice.get("label", id)), _choose.bind(id))
        button.name = "Candidate_" + id
        _choice_buttons.append(button)
    _update_choice()
    _layout_body()
    selected_slot_changed.emit(str(slot.get("id", "")))
    candidate_changed.emit(str(slot.get("id", "")), _choice_id)
    slot_candidate_changed.emit(str(slot.get("id", "")), _choice_id)

func _move_slot(direction: int) -> void:
    if _slot_options.is_empty():
        return
    _slot_index = posmod(_slot_index + direction, _slot_options.size())
    _choose_current_slot()

func select_slot(slot_id: String) -> void:
    _slot_options = _read_slots()
    for i in _slot_options.size():
        if str(_slot_options[i].get("id", "")) == slot_id:
            _slot_index = i
            show_layout_editor()
            return

func select_layout(layout_id: String) -> void:
    selected_layout_changed.emit(layout_id)

func _choose(id: String) -> void:
    _choice_id = id
    _update_choice()
    selected_slot_changed.emit(str(_current_slot().get("id", "")))
    candidate_changed.emit(str(_current_slot().get("id", "")), id)
    slot_candidate_changed.emit(str(_current_slot().get("id", "")), id)

func _update_choice() -> void:
    if _slot_options.is_empty() or not is_instance_valid(_apply):
        return
    var slot := _current_slot()
    var options := _read_slots()
    for live_slot in options:
        if str(live_slot.get("id", "")) == str(slot.get("id", "")):
            slot = live_slot
            break
    var current := str(slot.get("current_choice_id", slot.get("choice_id", slot.get("current", ""))))
    _choice_title.text = "%s  %d/%d" % [str(slot.get("label", "区画")), _slot_index + 1, _slot_options.size()]
    var choices: Array = slot.get("choices", [])
    var selected: Dictionary = {}
    for i in choices.size():
        var choice: Dictionary = choices[i]
        var id := str(choice.get("id", ""))
        if id == _choice_id:
            selected = choice
        if i < _choice_buttons.size():
            var button := _choice_buttons[i]
            var is_selected := id == _choice_id
            button.text = ("● " if is_selected else "") + str(choice.get("label", id)) + ("\n現在の配置" if id == current else "")
            button.add_theme_stylebox_override("normal", _style(TEAL if is_selected else Color("e3eae2"), INK if is_selected else LINE))
            button.add_theme_font_size_override("font_size", 16)
    _benefit.text = "よい点  " + str(selected.get("benefit", "実際の運搬を観測して確かめます"))
    _tradeoff.text = "注意点  " + str(selected.get("tradeoff", "置く場所によって、通る道と距離が変わります"))
    _cost.text = str(selected.get("cost_label", "同じ設備を移動 ・ 追加購入なし"))
    var pending := not str(_snapshot.get("pending_layout_id", "")).is_empty()
    var unchanged := _choice_id == current
    _apply.disabled = unchanged or pending or not bool(selected.get("available", true))
    _apply.text = "今の配置です" if unchanged else ("切り替え中…" if pending else "この場所に動かす")
    _sync_focus.call_deferred()

func _apply_choice() -> void:
    if _apply == null or _apply.disabled:
        return
    var slot := _current_slot()
    var slot_id := str(slot.get("id", ""))
    var choice := _choice_id
    _apply.disabled = true
    close_sheet()
    slot_action_requested.emit(slot_id, choice)

func show_action_result(result: Dictionary) -> void:
    var ok := bool(result.get("ok", false))
    var reason := str(result.get("reason", ""))
    var reasons := {"draining":"運搬が終わり、移動先が空くと設備を動かします。移動費用はかかりません", "busy":"前の配置変更が終わるまでお待ちください", "too_late":"いまは配置を変更できません。作業の終了後にもう一度お試しください", "same":"すでにこの配置です", "finished":"作業が終了しています。次の仕事を選んでください", "unknown":"この配置には変更できません", "unknown_slot":"選んだ設備が見つかりません。配置画面を開き直してください", "unknown_choice":"この場所には変更できません。別の場所を選んでください"}
    _notice = str(reasons.get(reason, ""))
    if _notice.is_empty():
        _notice = "運搬が終わり、移動先が空くと設備を動かします" if ok else "配置を変更できませんでした。配置画面を開き直してください"
    _notice_seconds = 5.0
    refresh()

func _workloads() -> Array:
    if is_instance_valid(sim) and sim.has_method("workload_options"):
        var options: Variant = sim.call("workload_options")
        if options is Array:
            options.sort_custom(func(a, b): return str(a.get("id", "")) == "waves" and str(b.get("id", "")) != "waves")
            return options
    return [{"id": "inbound", "label": "入荷が多い日"}, {"id": "orders", "label": "注文が多い日"}]

func show_conditions() -> void:
    _open_sheet("conditions", "試す条件", 492)
    _label(_body, "条件を変えると、試作を最初から開始", 15).name = "ConditionsNote"
    var current := str(_snapshot.get("workload_id", "inbound"))
    for option in _workloads():
        var id := str(option.get("id", ""))
        var mode_label := str(option.get("label", id)) + (" / 比較用120秒" if id != "waves" else " / 時間制限なし")
        var button := _button(_body, ("選択中  " if id == current else "") + mode_label, _change_workload.bind(id))
        button.add_theme_font_size_override("font_size", 15)
        button.name = "Workload_" + id
        button.disabled = id == current
    _button(_body, "一時停止" if _trial_running else "観測を再開", _toggle_pause).name = "TogglePause"
    _button(_body, "最初から試す", _reset).name = "RestartTrial"
    _label(_body, "比較用は入荷・注文の間隔を固定した測定です。\n変更やリセットは、この試作の中だけ。", 14, Color("476266")).name = "ConditionsSafety"
    _layout_body()

func _change_workload(id: String) -> void:
    close_sheet()
    workload_requested.emit(id)

func _toggle_pause() -> void:
    _trial_running = not _trial_running
    close_sheet()
    pause_requested.emit(not _trial_running)

func _reset() -> void:
    close_sheet()
    reset_requested.emit()

func _request_comparison() -> void:
    _open_sheet("loading", "同じ条件で比べる", 244)
    _label(_body, "各配置で120秒ずつ、運搬を計測します", 17).name = "LoadingNote"
    _label(_body, "設備・人員・荷物の条件をそろえて比較", 15).name = "LoadingDetail"
    _layout_body()
    comparison_requested.emit()

func show_comparison(data: Variant = {}) -> void:
    _comparison_data = data
    _open_sheet("comparison", "固定条件での配置比較", 562)
    var initial := "入荷4・棚2・注文1" if _comparison_workload == "inbound" else "入荷4・棚12・注文12"
    _label(_body, "各配置120秒・同じ設備と人員\n初期荷物：" + initial, 14).name = "ComparisonNote"
    var inbound_button := _button(_body, "入荷集中", _switch_comparison.bind("inbound"), _comparison_workload == "inbound")
    inbound_button.name = "CompareInbound"
    var orders_button := _button(_body, "在庫から注文対応", _switch_comparison.bind("orders"), _comparison_workload == "orders")
    orders_button.name = "CompareOrders"
    orders_button.add_theme_font_size_override("font_size", 15)
    var rows: Array = []
    if data is Array:
        rows = data
    elif data is Dictionary:
        var raw: Variant = data.get("results", data.get("layouts", data.get("rows", [])))
        if raw is Array:
            rows = raw
        elif raw is Dictionary:
            for id in raw:
                var row: Dictionary = raw[id].duplicate()
                row["layout_id"] = id
                rows.append(row)
    var current_workload := _comparison_workload
    rows = rows.filter(func(row): return str(row.get("workload_id", current_workload)) == current_workload)
    for i in mini(4, rows.size()):
        var row: Dictionary = rows[i]
        var label := str(row.get("label", row.get("layout_label", _layout_label(str(row.get("layout_id", ""))))))
        var card := _panel(_body, Color("e0e8e1"), 12)
        card.name = "ComparisonRow%d" % i
        var name_label := _label(card, "%s  出荷%d箱" % [label, int(row.get("shipped", 0))], 17)
        name_label.name = "RowName"
        var metrics := _label(card, "運搬 %.0f秒  /  道の待ち %.0f秒" % [float(row.get("travel_seconds", 0.0)), float(row.get("aisle_wait_seconds", 0.0))], 16)
        metrics.name = "RowMetrics"
    if rows.is_empty():
        _label(_body, "比較データはまだありません。\n観測を始めてから、もう一度比べてください。", 16).name = "ComparisonEmpty"
    _label(_body, "固定した間隔での測定。通常の波とは異なります。\n運搬・道待ちは、全員の合計時間です。", 13).name = "ComparisonHint"
    _button(_body, "倉庫へ戻る", close_sheet, true).name = "ComparisonBack"
    _layout_body()

func _switch_comparison(id: String) -> void:
    _comparison_workload = id
    show_comparison(_comparison_data)

func _layout_label(id: String) -> String:
    if is_instance_valid(sim) and sim.has_method("layout_options"):
        for option in sim.call("layout_options"):
            if str(option.get("id", "")) == id:
                return str(option.get("label", id))
    return "配置案" if id.is_empty() else id

func _layout_body() -> void:
    _sync_focus.call_deferred()
    var width := _body.size.x
    var height := _body.size.y
    match _sheet_kind:
        "entry":
            _place("EntryLead", 0, 0, width, 36)
            _place("EntryDescription", 0, 44, width, 68)
            _place("EntrySafety", 0, 126, width, 56)
            _place("StartTrial", 0, height - 52, width, 52)
        "editor":
            if _slot_options.is_empty():
                _place("EmptyTitle", 0, 0, width, 48)
                _place("EmptyDetail", 0, 58, width, 72)
                _place("EmptyBack", 0, height - 52, width, 52)
                return
            _place("PreviousSlot", 0, 0, 48, 48)
            _place("NextSlot", width - 48, 0, 48, 48)
            _place("SelectedSlot", 56, 0, width - 112, 48)
            var count := maxi(1, _choice_buttons.size())
            var button_width := (width - 8.0 * (count - 1)) / count
            var compact := _root.size.y < 740
            for i in _choice_buttons.size():
                _rect(_choice_buttons[i], i * (button_width + 8), 52 if compact else 62, button_width, 56 if compact else 66)
            _place("Benefit", 0, 114 if compact else 142, width, 34 if compact else 48)
            _place("Tradeoff", 0, 150 if compact else 193, width, 34 if compact else 54)
            _place("Cost", 0, 188 if compact else 252, width, 30 if compact else 35)
            _place("ApplyChoice", 0, height - (48 if compact else 52), width, 48 if compact else 52)
        "conditions":
            _place("ConditionsNote", 0, 0, width, 38)
            var i := 0
            for child in _body.get_children():
                if str(child.name).begins_with("Workload_"):
                    _rect(child, 0, 48 + 56 * i, width, 50)
                    i += 1
            _place("TogglePause", 0, 224, (width - 8) / 2, 54)
            _place("RestartTrial", (width + 8) / 2, 224, (width - 8) / 2, 54)
            _place("ConditionsSafety", 0, 291, width, 60)
        "loading":
            _place("LoadingNote", 0, 0, width, 52)
            _place("LoadingDetail", 0, 60, width, 40)
        "comparison":
            _place("ComparisonNote", 0, 0, width, 44)
            _place("CompareInbound", 0, 54, (width - 8) / 2, 48)
            _place("CompareOrders", (width + 8) / 2, 54, (width - 8) / 2, 48)
            for i in 4:
                var card := _body.get_node_or_null("ComparisonRow%d" % i) as Panel
                if card != null:
                    _rect(card, 0, 114 + i * 62, width, 56)
                    _rect(card.get_node("RowName"), 12, 1, width - 24, 25)
                    _rect(card.get_node("RowMetrics"), 12, 25, width - 24, 27)
            _place("ComparisonEmpty", 0, 40, width, 130)
            _place("ComparisonHint", 0, 365, width, 44)
            _place("ComparisonBack", 0, height - 52, width, 52)

func _focus_buttons(node: Node) -> Array[Button]:
    var found: Array[Button] = []
    for child in node.get_children():
        if child is Button and child.is_visible_in_tree() and not child.disabled:
            found.append(child)
        found.append_array(_focus_buttons(child))
    return found

func _sync_focus() -> void:
    if not _built:
        return
    var modal := not _sheet_kind.is_empty()
    for button in [_back, _conditions, _primary, _compare]:
        button.focus_mode = Control.FOCUS_NONE if modal else Control.FOCUS_ALL
    if not modal:
        return
    var buttons := _focus_buttons(_sheet)
    if buttons.is_empty():
        return
    for i in buttons.size():
        buttons[i].focus_next = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
        buttons[i].focus_previous = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
    var owner := _root.get_viewport().gui_get_focus_owner()
    if owner == null or not _sheet.is_ancestor_of(owner):
        _close.grab_focus()

func _place(node_name: String, x: float, y: float, width: float, height: float) -> void:
    var node := _body.get_node_or_null(node_name) as Control
    if node != null:
        _rect(node, x, y, width, height)

func world_insets() -> Vector2:
    return Vector2(76, _sheet_height + 24) if _sheet_kind == "editor" else Vector2(178, 174)

func _update_world_region() -> void:
    _reason_panel.visible = _sheet_kind != "editor"
    # The editor previews the actual destination in a dedicated unobscured region.
    _mask.color.a = 0.08 if _sheet_kind == "editor" else 0.52
    var insets := world_insets()
    if insets != _last_world_insets:
        _last_world_insets = insets
        world_rect_changed.emit()

func debug_state() -> Dictionary:
    return {"sheet": _sheet_kind, "selected_slot": str(_current_slot().get("id", "")), "selected_choice": _choice_id, "viewport": _root.size, "snapshot": _snapshot.duplicate(true)}
