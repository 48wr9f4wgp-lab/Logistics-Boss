extends "res://prototype/layout_hud.gd"
## Read-only two-job phone interface. All changes remain scene-owned signals.
## The original layout HUD/snapshot stay untouched for the earlier prototype.

var _selected_mix := "balanced"
var _mix_buttons: Array[Button] = []
var _mix_apply: Button
var _comparison_mix := "bulk_heavy"
var _comparison_loading := false
var _has_started := false
var _entry_resume_running := false
var _background_guard_until := 0
var _background_guard_frame := -1
var _pause: Button
var _notice_title := "変更を受け付けました"

func _build() -> void:
    super._build()
    _root.name = "JobsHUD"
    _title.text = "仕事と配置"
    _safe_note.text = "保存なしの専用試作"
    _conditions.name = "SessionRecord"
    _conditions.reparent(_bottom)
    _conditions.text = "結果"
    _pause = _button(_header, "一時停止", _toggle_pause, false, false)
    _pause.name = "PauseResume"
    _pause.add_theme_font_size_override("font_size", 15)
    _compare.name = "WorkChoice"
    _primary.name = "ChangeLayout"
    _compare.text = "仕事選択"
    _shipped.add_theme_font_size_override("font_size", 19)
    _travel.add_theme_font_size_override("font_size", 13)
    _waiting.add_theme_font_size_override("font_size", 13)
    _observed_note.add_theme_font_size_override("font_size", 14)
    _layout()

func _button(parent: Node, value: String, action: Callable, primary: bool = false, light: bool = true) -> Button:
    var press_guard := {"blocked": false}
    var guarded_action := func():
        if press_guard.blocked or (_sheet_kind.is_empty() and _background_input_blocked()):
            return
        action.call()
    var button := super._button(parent, value, guarded_action, primary, light)
    # A native window-focus loss can leave BaseButton's internal held state
    # without a subsequent button_down. Capture the actual fresh GUI event,
    # while stale releases still fail the inherited epoch check.
    button.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            press_guard.blocked = _sheet_kind.is_empty() and _background_input_blocked()
            button.set_meta("press_epoch", _input_epoch)
        elif event is InputEventScreenTouch and event.pressed:
            press_guard.blocked = _sheet_kind.is_empty() and _background_input_blocked()
            button.set_meta("press_epoch", _input_epoch)
        elif event is InputEventKey and event.is_action_pressed("ui_accept") and not event.echo:
            press_guard.blocked = _sheet_kind.is_empty() and _background_input_blocked()
            button.set_meta("press_epoch", _input_epoch)
    )
    return button

func _background_input_blocked() -> bool:
    # A slow synchronous purchase/accept callback can exceed the wall-clock
    # interval before its queued input batch ends. Require a new frame too.
    return Time.get_ticks_msec() < _background_guard_until or Engine.get_process_frames() <= _background_guard_frame

func _layout() -> void:
    super._layout()
    if not _built:
        return
    var width := _root.size.x
    var height := _root.size.y
    _rect(_back, 10, 10, 76, 48)
    _back.text = "遊び方" if _sheet_kind.is_empty() else "戻る"
    _rect(_title, 96, 7, width - 200, 30)
    _title.add_theme_font_size_override("font_size", 18)
    _rect(_safe_note, 96, 36, width - 200, 22)
    if is_instance_valid(_pause):
        _rect(_pause, width - 94, 10, 84, 48)
    _rect(_bottom, 12, height - 178, width - 24, 166)
    _rect(_shipped, 14, 6, width - 52, 32)
    _rect(_travel, 14, 38, (width - 56) / 2, 23)
    _rect(_waiting, (width - 28) / 2, 38, (width - 56) / 2, 23)
    _rect(_observed_note, 14, 65, width - 52, 30)
    var tab_width := (width - 64) / 3
    _rect(_compare, 12, 106, tab_width, 48)
    _rect(_primary, 20 + tab_width, 106, tab_width, 48)
    _rect(_conditions, 28 + tab_width * 2, 106, tab_width, 48)
    for button in [_compare, _primary, _conditions]:
        button.add_theme_font_size_override("font_size", 16)

func world_insets() -> Vector2:
    return Vector2(76, _sheet_height + 24) if _sheet_kind == "editor" else Vector2(178, 190)

func _mix_options() -> Array:
    for method in ["mix_options", "job_mix_options", "workload_options"]:
        if is_instance_valid(sim) and sim.has_method(method):
            var data: Variant = sim.call(method)
            if data is Array and not data.is_empty():
                return data
    return [
        {"id":"bulk_heavy", "label":"まとめ保管中心", "bulk_share":0.8},
        {"id":"balanced", "label":"半分ずつ", "bulk_share":0.5},
        {"id":"pick_heavy", "label":"小口梱包中心", "bulk_share":0.2},
    ]

func _mix_id() -> String:
    return str(_snapshot.get("mix_id", _snapshot.get("job_mix_id", _snapshot.get("workload_id", "balanced"))))

func _mix_title(id: String) -> String:
    return {"bulk_heavy":"まとめ保管中心", "balanced":"半分ずつ", "pick_heavy":"小口梱包中心"}.get(id, "半分ずつ")

func _mix_share(id: String) -> float:
    for option in _mix_options():
        if str(option.get("id", "")) == id:
            return float(option.get("bulk_share", option.get("bulk_fraction", option.get("bulk_ratio", {"bulk_heavy":0.8,"balanced":0.5,"pick_heavy":0.2}.get(id, 0.5)))))
    return 0.5

func _type_metrics(kind: String) -> Dictionary:
    var by_type: Dictionary = _snapshot.get("jobs_by_type", _snapshot.get("job_metrics", {}))
    return by_type.get(kind, {})

func _shipped_units(kind: String) -> int:
    var data := _type_metrics(kind)
    return int(data.get("shipped_units", data.get("shipped", 0)))

func _queued_jobs(kind: String) -> int:
    var data := _type_metrics(kind)
    return int(data.get("queued_jobs", data.get("queued", data.get("open_jobs", 0))))

func refresh() -> void:
    super.refresh()
    if not _built:
        return
    _title.text = "仕事と配置"
    _conditions.text = "結果"
    _compare.text = "仕事選択"
    _primary.text = "配置変更"
    _primary.disabled = not str(_snapshot.get("pending_layout_id", "")).is_empty()
    _back.text = "遊び方" if _sheet_kind.is_empty() else "戻る"
    if is_instance_valid(_pause):
        _pause.text = "一時停止" if _trial_running else "再開"
        _pause.disabled = not _sheet_kind.is_empty()
        _pause.focus_mode = Control.FOCUS_ALL if _sheet_kind.is_empty() else Control.FOCUS_NONE
    _shipped.text = "出荷  まとめ %d箱  /  小口 %d箱" % [_shipped_units("bulk"), _shipped_units("small")]
    _travel.text = "残り：まとめ %d件" % _queued_jobs("bulk")
    _waiting.text = "小口 %d件" % _queued_jobs("small")
    _observed_note.text = "次の便から：" + _mix_title(_mix_id())
    var pending := not str(_snapshot.get("pending_layout_id", "")).is_empty()
    if not _notice.is_empty():
        _reason_title.text = _notice_title
        _reason_detail.text = _notice
    elif not _trial_running and _sheet_kind != "entry":
        _reason_title.text = "倉庫を一時停止中"
        _reason_detail.text = "「再開」で作業を続けます。停止中も配置を選べます"
    elif pending:
        if bool(_snapshot.get("relocating", false)):
            _reason_title.text = "設備と在庫を移動中"
            _reason_detail.text = "移動中は作業が止まります。あと%.1f秒（ゲーム内）" % float(_snapshot.get("relocation_remaining", 0))
        else:
            _reason_title.text = "設備を動かす準備中"
            _reason_detail.text = "運搬が終わり、移動先が空くと設備を動かします"
    else:
        _show_operational_reason()
    _compare.disabled = not _work_choices_enabled()
    if _sheet_kind == "jobs":
        _update_mix_choice()
    elif _sheet_kind == "records":
        _update_record()

# Decide availability once. A release can keep its menu open between contracts
# without briefly disabling/re-enabling BaseButton and cancelling a held finger.
func _work_choices_enabled() -> bool:
    return not bool(_snapshot.get("finished", false))

func _show_operational_reason() -> void:
    var reason := str(_snapshot.get("bottleneck", ""))
    if reason.contains("場の外") or reason.contains("場外"):
        _reason_title.text = "倉庫の外で入荷待ち"
        _reason_detail.text = "荷物は順番に入ります。保管床や棚が空くまでお待ちください"
    elif reason.contains("保管") and reason.contains("満杯"):
        _reason_title.text = "まとめ便の保管床が満杯"
        _reason_detail.text = "使える保管床は%d枠です。棚の位置を変えると枠数も変わります" % int(_snapshot.get("bulk_capacity", 0))
    elif reason.contains("棚") and reason.contains("満杯"):
        _reason_title.text = "小口便の棚が満杯"
        _reason_detail.text = "棚から梱包台へ運ぶ距離を見直してみよう"
    elif reason.contains("譲り"):
        _reason_title.text = "通路ですれ違い待ち"
        _reason_detail.text = "棚と梱包台の位置を変えると、通る道も変わります"
    else:
        _reason_title.text = "2種類の仕事が進行中"
        _reason_detail.text = "まとめ便は床で保管、小口は棚から梱包へ"

func show_entry() -> void:
    if not _built:
        return
    _entry_resume_running = _trial_running
    _open_sheet("entry", "遊び方", 444)
    _close.text = "倉庫へ"
    _label(_body, "受ける仕事で、倉庫を変える", 21).name = "EntryLead"
    _label(_body, "まとめ保管：置き場 → まとめて出荷\n小口梱包：棚 → ピック → 梱包 → 出荷", 16).name = "EntryDescription"
    _label(_body, "① 仕事を選ぶ → ② 配置を変える\n③ 結果を見る。右上で一時停止できます", 15).name = "EntryGoal"
    _label(_body, "本編のセーブ・お金・設備は変わりません", 14, Color("476266")).name = "EntrySafety"
    _button(_body, "試作の続きに戻る" if float(_snapshot.get("sim_time", 0.0)) > 0.0 else "倉庫を動かす", _start_trial, true).name = "StartTrial"
    _layout_body()


func _start_trial() -> void:
    _has_started = true
    super._start_trial()

func show_play() -> void:
    _background_guard_until = Time.get_ticks_msec() + 180
    _background_guard_frame = Engine.get_process_frames()
    _input_epoch += 1
    super.show_play()

func _primary_action() -> void:
    show_layout_editor()

func _go_back() -> void:
    if _sheet_kind in ["restart", "comparison", "loading"]:
        show_conditions()
    elif not _sheet_kind.is_empty():
        close_sheet()
    else:
        show_entry()

func show_layout_editor() -> void:
    super.show_layout_editor()
    _update_slot_tabs()

func _move_slot(direction: int) -> void:
    _slot_index = 0 if direction < 0 else mini(1, _slot_options.size() - 1)
    _choose_current_slot()
    _update_slot_tabs()

func _update_slot_tabs() -> void:
    if _sheet_kind != "editor" or _slot_options.is_empty():
        return
    _previous.text = ("● " if _slot_index == 0 else "") + "棚・保管床"
    _next.text = ("● " if _slot_index == 1 else "") + "梱包台"
    _previous.add_theme_stylebox_override("normal", _style(TEAL if _slot_index == 0 else Color("e3eae2"), LINE))
    _next.add_theme_stylebox_override("normal", _style(TEAL if _slot_index == 1 else Color("e3eae2"), LINE))
    _choice_title.hide()
    _layout_body()

func _request_comparison() -> void:
    # The second bottom button is now a direct choice, not a nested menu.
    show_job_choices()

func show_job_choices() -> void:
    _selected_mix = _mix_id()
    _mix_buttons.clear()
    _mix_apply = null
    _open_sheet("jobs", "これから受ける仕事", 538)
    _label(_body, "次の便から割合を変更\n受注済みの仕事は、そのまま進みます", 15).name = "MixScope"
    for id in ["bulk_heavy", "balanced", "pick_heavy"]:
        var button := _button(_body, "", _choose_mix.bind(id))
        button.add_theme_font_size_override("font_size", 16)
        button.name = "Mix_" + id
        _mix_buttons.append(button)
    _label(_body, "", 14).name = "MixRoute"
    _label(_body, "", 14, Color("476266")).name = "MixBacklog"
    _mix_apply = _button(_body, "次の便から変更", _apply_mix, true)
    _mix_apply.name = "MixApply"
    _update_mix_choice()
    _layout_body()

func _choose_mix(id: String) -> void:
    if _sheet_kind != "jobs":
        return
    _selected_mix = id
    _update_mix_choice()

func _update_mix_choice() -> void:
    if not is_instance_valid(_mix_apply) or _sheet_kind != "jobs":
        return
    var current := _mix_id()
    for i in _mix_buttons.size():
        var id: String = ["bulk_heavy", "balanced", "pick_heavy"][i]
        var percent := roundi(_mix_share(id) * 100)
        var selected := id == _selected_mix
        _mix_buttons[i].text = ("● " if selected else "") + _mix_title(id) + ("  受付中" if id == current else "") + "\nまとめ %d%% / 小口 %d%%" % [percent, 100 - percent]
        _mix_buttons[i].add_theme_stylebox_override("normal", _style(TEAL if selected else Color("e3eae2"), INK if selected else LINE))
    var timing: Dictionary = _snapshot.get("timing", {})
    var hold := int(timing.get("bulk_dwell_seconds", 60))
    var route := "まとめ：床で%d秒以上保管 → 直送\n小口：棚 → ピック → 梱包 → 出荷\n" % hold
    route += {"bulk_heavy":"床の置き場を多く残す配置が重要", "pick_heavy":"棚・梱包台と通路の位置が重要", "balanced":"床の広さと、小口の動線を両立"}.get(_selected_mix, "")
    _body.get_node("MixRoute").text = route
    _body.get_node("MixBacklog").text = "受注済み：まとめ %d件 / 小口 %d件\n割合を変えても、この仕事は続きます" % [_queued_jobs("bulk"), _queued_jobs("small")]
    _mix_apply.disabled = _selected_mix == current
    _mix_apply.text = "現在の割合です" if _mix_apply.disabled else "次の便から変更"
    _sync_focus.call_deferred()

func _apply_mix() -> void:
    if _sheet_kind != "jobs" or not is_instance_valid(_mix_apply) or _mix_apply.disabled:
        return
    var id := _selected_mix
    _mix_apply.disabled = true
    close_sheet()
    workload_requested.emit(id)

func show_job_mix_result(result: Dictionary) -> void:
    _notice_title = "仕事の割合を変更" if bool(result.get("ok", false)) else "仕事の割合を確認"
    _notice = "次の便から割合を変更。受注済みの仕事は継続" if bool(result.get("ok", false)) else "仕事の割合を変更できませんでした"
    if str(result.get("reason", "")) == "same":
        _notice = "現在の割合です。受注済みの仕事は継続"
    _notice_seconds = 5.0
    refresh()

func _update_choice() -> void:
    super._update_choice()
    if _sheet_kind == "editor" and is_instance_valid(_apply) and _apply.text == "今の配置です":
        _cost.text = "現在の配置です。移動費用はかかりません"

func show_action_result(result: Dictionary) -> void:
    if bool(result.get("ok", false)):
        _notice_title = "設備の移動を予約しました" if _trial_running else "再開すると設備を移動します"
    else:
        _notice_title = str({"busy":"前の配置変更が終わるまで待とう", "same":"すでにこの配置です", "finished":"次の仕事を選ぼう"}.get(str(result.get("reason", "")), "配置を変更できませんでした"))
    super.show_action_result(result)

func close_sheet() -> void:
    var previous := _sheet_kind
    _background_guard_until = Time.get_ticks_msec() + 180
    _background_guard_frame = Engine.get_process_frames()
    if previous == "entry":
        _input_epoch += 1
        if _has_started:
            show_play()
            _trial_running = _entry_resume_running
            pause_requested.emit(not _trial_running)
            refresh()
        else:
            _start_trial()
        return
    # Bump the epoch so a release from a dismissed sheet cannot activate
    # a freshly exposed button at the same coordinates.
    _input_epoch += 1
    super.close_sheet()
    _update_world_region()
    if previous == "jobs" and _sheet_kind.is_empty() and not _compare.disabled:
        _compare.grab_focus()
    elif previous in ["records", "comparison", "loading"] and _sheet_kind.is_empty():
        _conditions.grab_focus()

func _open_sheet(kind: String, title: String, height: float) -> void:
    _input_epoch += 1
    super._open_sheet(kind, title, height)

func _notification(what: int) -> void:
    # Godot dispatches notifications through the inheritance chain itself.
    # Calling super here would handle hardware Back twice.
    if _built and what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _input_epoch += 1

func show_conditions() -> void:
    _open_sheet("records", "この倉庫の実測記録", 480)
    _label(_body, "", 15).name = "RecordScope"
    _label(_body, "", 19).name = "RecordShipments"
    _label(_body, "", 15).name = "RecordBacklog"
    _label(_body, "", 15).name = "RecordTravel"
    _label(_body, "", 14, Color("476266")).name = "RecordCost"
    _button(_body, "同じ条件で配置を比較", _request_job_comparison, true).name = "CompareJobs"
    _button(_body, "一時停止" if _trial_running else "観測を再開", _toggle_pause).name = "TogglePause"
    _button(_body, "最初から", _confirm_restart).name = "RestartTrial"
    _update_record()
    _layout_body()

func _update_record() -> void:
    if _sheet_kind != "records":
        return
    _body.get_node("RecordScope").text = "開始から %d秒 / 配置・割合の変更を含む" % int(_snapshot.get("sim_time", 0))
    _body.get_node("RecordShipments").text = "出荷：まとめ %d箱 / 小口 %d箱" % [_shipped_units("bulk"), _shipped_units("small")]
    _body.get_node("RecordBacklog").text = "残り：まとめ %d件 / 小口 %d件" % [_queued_jobs("bulk"), _queued_jobs("small")]
    _body.get_node("RecordTravel").text = "全員の歩行 %.0f秒 / 道待ち %.0f秒" % [float(_snapshot.get("travel_seconds", 0)), float(_snapshot.get("aisle_wait_seconds", 0))]
    _body.get_node("RecordCost").text = "設備移動で止まった時間：%.1f秒\n比較は別の倉庫を使い、この仕事は消しません" % float(_snapshot.get("relocation_seconds", 0))

func _confirm_restart() -> void:
    _open_sheet("restart", "この試作を最初から？", 322)
    _label(_body, "この倉庫の受注・荷物・実測記録をリセット\n今の仕事の割合と配置で始め直します", 16).name = "RestartWarning"
    _label(_body, "本編のセーブには影響しません", 14, Color("476266")).name = "RestartSafety"
    _button(_body, "キャンセル", show_conditions).name = "RestartCancel"
    _button(_body, "最初から始める", _reset, true).name = "RestartConfirm"
    _layout_body()

func _request_job_comparison() -> void:
    _comparison_loading = true
    _open_sheet("loading", "同じ条件で配置を比較", 272)
    _label(_body, "受注・人員・測定時間をそろえて比較", 17).name = "LoadingNote"
    _label(_body, "別の倉庫で計測中。今の受注は残ります", 15).name = "LoadingDetail"
    _layout_body()
    comparison_requested.emit()

func show_comparison_progress(done: int, total: int) -> void:
    if _sheet_kind == "loading":
        _body.get_node("LoadingDetail").text = "%d / %d案を計測済み。閉じると中止\n今の受注済みの仕事は残ります" % [done, total]

func show_comparison(data: Variant = {}) -> void:
    _comparison_data = data
    _comparison_loading = false
    # Do not resurrect a dismissed loading sheet when deferred results arrive.
    if _sheet_kind != "loading" and _sheet_kind != "comparison":
        return
    _open_sheet("comparison", "同じ条件での配置比較", 572)
    var seconds := 300
    if data is Dictionary:
        seconds = int(data.get("duration", data.get("seconds", 300)))
    _label(_body, "各配置 %d秒 / 同じ受注・人員\n出荷した箱数で比較。今の実測記録とは別" % seconds, 14).name = "ComparisonNote"
    _button(_body, "まとめ中心", _switch_job_comparison.bind("bulk_heavy"), _comparison_mix == "bulk_heavy").name = "CompareBulk"
    _button(_body, "小口中心", _switch_job_comparison.bind("pick_heavy"), _comparison_mix == "pick_heavy").name = "ComparePick"
    var rows := _comparison_rows(data, _comparison_mix)
    for i in mini(rows.size(), 4):
        var row: Dictionary = rows[i]
        var card := _panel(_body, Color("e0e8e1"), 12)
        card.name = "ComparisonRow%d" % i
        var label := str(row.get("label", row.get("layout_label", _layout_label(str(row.get("layout_id", ""))))))
        _label(card, label, 16).name = "RowName"
        _label(card, "%d箱（まとめ%d / 小口%d）" % [int(row.get("shipped_units", row.get("shipped", 0))), int(row.get("bulk_shipped", 0)), int(row.get("pick_shipped", 0))], 15).name = "RowMetrics"
    if rows.is_empty():
        _label(_body, "比較結果を準備しています", 16).name = "ComparisonEmpty"
    _label(_body, "%.0f分の試走。長期の結果は変わる場合あり\n移動の停止・受注残も実運営で確認" % (seconds / 60.0), 13, Color("476266")).name = "ComparisonHint"
    _button(_body, "倉庫へ戻る", close_sheet, true).name = "ComparisonBack"
    _layout_body()

func _comparison_rows(data: Variant, mix: String) -> Array:
    var rows: Array = []
    if data is Array:
        rows = data
    elif data is Dictionary:
        var raw: Variant = data.get("results", data.get("rows", []))
        if raw is Array:
            rows = raw
    return rows.filter(func(row): return str(row.get("mix_id", row.get("workload_id", mix))) == mix)

func _switch_job_comparison(id: String) -> void:
    _comparison_mix = id
    show_comparison(_comparison_data)

func _layout_body() -> void:
    if not _built:
        return
    var width := _body.size.x
    var height := _body.size.y
    match _sheet_kind:
        "entry":
            _place("EntryLead", 0, 0, width, 38)
            _place("EntryDescription", 0, 48, width, 60)
            _place("EntryGoal", 0, 126, width, 58)
            _place("EntrySafety", 0, 198, width, 48)
            _place("StartTrial", 0, height - 52, width, 52)
        "jobs":
            _place("MixScope", 0, 0, width, 44)
            for i in 3:
                _place("Mix_" + ["bulk_heavy", "balanced", "pick_heavy"][i], 0, 54 + i * 64, width, 58)
            _place("MixRoute", 0, 241, width, 75)
            _place("MixBacklog", 0, 323, width, 50)
            _place("MixApply", 0, height - 52, width, 52)
        "records":
            _place("RecordScope", 0, 0, width, 42)
            _place("RecordShipments", 0, 48, width, 38)
            _place("RecordBacklog", 0, 92, width, 34)
            _place("RecordTravel", 0, 132, width, 38)
            _place("RecordCost", 0, 184, width, 58)
            _place("CompareJobs", 0, height - 120, width, 52)
            _place("TogglePause", 0, height - 56, (width - 8) / 2, 52)
            _place("RestartTrial", (width + 8) / 2, height - 56, (width - 8) / 2, 52)
        "restart":
            _place("RestartWarning", 0, 0, width, 92)
            _place("RestartSafety", 0, 104, width, 35)
            _place("RestartCancel", 0, height - 52, (width - 8) / 2, 52)
            _place("RestartConfirm", (width + 8) / 2, height - 52, (width - 8) / 2, 52)
        "comparison":
            _place("ComparisonNote", 0, 0, width, 46)
            _place("CompareBulk", 0, 56, (width - 8) / 2, 48)
            _place("ComparePick", (width + 8) / 2, 56, (width - 8) / 2, 48)
            for i in 4:
                var card := _body.get_node_or_null("ComparisonRow%d" % i) as Panel
                if card != null:
                    _rect(card, 0, 116 + i * 63, width, 57)
                    _rect(card.get_node("RowName"), 10, 0, width - 20, 27)
                    _rect(card.get_node("RowMetrics"), 10, 26, width - 20, 28)
            _place("ComparisonEmpty", 0, 124, width, 130)
            _place("ComparisonHint", 0, 374, width, 44)
            _place("ComparisonBack", 0, height - 52, width, 52)
        "editor":
            super._layout_body()
            if not _slot_options.is_empty():
                _place("PreviousSlot", 0, 0, (width - 8) / 2, 48)
                _place("NextSlot", (width + 8) / 2, 0, (width - 8) / 2, 48)
                if is_instance_valid(_choice_title):
                    _choice_title.hide()
        _:
            super._layout_body()
    _sync_focus.call_deferred()

func debug_state() -> Dictionary:
    var result := super.debug_state()
    result["selected_mix"] = _selected_mix
    result["comparison_mix"] = _comparison_mix
    return result
