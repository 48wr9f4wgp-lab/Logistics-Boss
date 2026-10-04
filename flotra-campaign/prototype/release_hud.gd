extends "res://prototype/jobs_hud.gd"
## Campaign presentation. The scene owns every domain mutation and save write.
## Keep the repaired jobs HUD's dismissal epochs, touch handling and layout editor.

signal contract_requested(contract_id: String)
signal upgrade_requested(upgrade_id: String)
signal speed_requested(value: float)

var _release: Dictionary = {}
var _contracts: Array = []
var _upgrades: Array = []
var _release_tab := "contracts"
var _save_status := "保存を確認中"
var _speed := 1.0
var _scroll: ScrollContainer
var _content: VBoxContainer
var _tabs: HBoxContainer
var _sheet_summary: Label
var _release_signature := ""
var _contract_buttons: Dictionary = {}
var _upgrade_buttons: Dictionary = {}
var _speed_buttons: Dictionary = {}
var _editor_candidates: VBoxContainer

# These are logical/CSS pixels. Device pixel ratio is handled by the release
# viewport, never by making phone text or touch controls smaller.
const BODY_FONT_SIZE := 18
const CONTROL_HEIGHT := 56.0

func _label(parent: Node, value: String, font_size: int, color: Color = INK) -> Label:
    return super._label(parent, value, maxi(BODY_FONT_SIZE, font_size), color)

func _button(parent: Node, value: String, action: Callable, primary: bool = false, light: bool = true) -> Button:
    # Retain all inherited epoch, focus-loss and dismissal guards.
    var button := super._button(parent, value, action, primary, light)
    button.custom_minimum_size = Vector2(CONTROL_HEIGHT, CONTROL_HEIGHT)
    button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    return button

func _build() -> void:
    super._build()
    _root.name = "ReleaseHUD"
    _title.text = "FLOTRA"
    _safe_note.autowrap_mode = TextServer.AUTOWRAP_OFF
    _safe_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _observed_note.autowrap_mode = TextServer.AUTOWRAP_OFF
    _observed_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _reason_title.add_theme_font_size_override("font_size", 20)
    _shipped.add_theme_font_size_override("font_size", 20)
    _layout()

func _work_choices_enabled() -> bool:
    # Contracts and upgrades remain available before/after a finite contract.
    # Override the inherited decision itself, not the resulting button state.
    return true

func set_save_status(value: String) -> void:
    _save_status = value
    refresh()

func set_speed(value: float) -> void:
    _speed = clampf(value, 1.0, 2.0)
    refresh()

func _read_release() -> void:
    if not is_instance_valid(sim):
        return
    if sim.has_method("release_state"):
        var state: Variant = sim.call("release_state")
        if state is Dictionary:
            _release = state
    if sim.has_method("contract_options"):
        var options: Variant = sim.call("contract_options")
        if options is Array:
            _contracts = options
    if sim.has_method("upgrade_options"):
        var options: Variant = sim.call("upgrade_options")
        if options is Array:
            _upgrades = options

func refresh() -> void:
    _read_release()
    super.refresh()
    if not _built:
        return
    _title.text = "FLOTRA"
    _safe_note.text = _short_save_status()
    _safe_note.tooltip_text = _save_status
    if _sheet_kind == "entry" and is_instance_valid(_content):
        var save_label := _content.get_node_or_null("EntrySaveStatus") as Label
        if save_label != null:
            save_label.text = _save_status
    _compare.text = "受注・設備"
    _conditions.text = "結果"
    var progress: Dictionary = _release.get("progress", {})
    var current: Dictionary = _release.get("current_contract", {})
    var total := int(progress.get("total", 0))
    _shipped.text = "出荷 %d / %d個   資金 %s" % [int(progress.get("shipped", 0)), total, _compact_funds(int(_release.get("wallet", 0)))]
    var elapsed := float(_release.get("elapsed", 0.0))
    _travel.text = "経過 %s  /  %dx" % [_clock(elapsed), int(_speed)]
    _waiting.text = _live_target(current, elapsed)
    var completed := int(_release.get("completed_count", 0))
    var count := int(_release.get("total_contracts", 6))
    _observed_note.text = "契約 %d/%d達成  ·  %s" % [completed, count, str(current.get("label", "受注・設備から最初の契約へ"))]
    _observed_note.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    _pause.text = "停止" if _trial_running else "再開"
    if _notice.is_empty():
        var status := str(_release.get("status", "ready"))
        if status in ["contract_complete", "campaign_complete"]:
            var result: Dictionary = _release.get("last_result", {})
            if not result.is_empty() and not bool(result.get("first_completion", false)):
                _reason_title.text = "記録更新！" if bool(result.get("new_best", false)) else "再挑戦を完走！"
                _reason_detail.text = "結果で、今回のメダルと自己ベストを確認"
            else:
                _reason_title.text = "全契約を達成！" if status == "campaign_complete" else "契約を達成！"
                _reason_detail.text = "受注・設備で、記録更新に挑戦できます" if status == "campaign_complete" else "受注・設備で、設備を整えて次の契約へ"
        elif status == "ready":
            _reason_title.text = "6つの契約で倉庫を育てよう"
            _reason_detail.text = "下の「受注・設備」から契約を選びます"
    if _sheet_kind == "jobs":
        _refresh_contract_content()
    elif _sheet_kind == "records":
        _update_record()

func _show_operational_reason() -> void:
    super._show_operational_reason()
    var held := 0
    var ready := 0
    var next_release := INF
    for bay in _snapshot.get("bulk_bays", []):
        if not bool(bay.get("occupied", false)): continue
        var remaining := float(bay.get("remaining_hold", 0))
        if remaining > 0:
            held += 1
            next_release = minf(next_release, remaining)
        else: ready += 1
    var all_idle := true
    for worker in _snapshot.get("workers", []):
        if str(worker.get("phase", "idle")) != "idle": all_idle = false
    if held > 0 and ready == 0 and (all_idle or _reason_title.text.contains("床が満杯")):
        _reason_title.text = "保管時間の終了待ち"
        _reason_detail.text = "契約の保管条件。出荷可能まであと%d秒" % ceili(next_release)
        return
    if _reason_title.text == "2種類の仕事が進行中":
        var current: Dictionary = _release.get("current_contract", {})
        _reason_title.text = "目標：" + str(current.get("label", "最初の契約を受注"))
        _reason_detail.text = str(_release.get("objective", "受注・設備から契約を選ぼう"))

func _open_sheet(kind: String, title: String, height: float) -> void:
    _scroll = null
    _content = null
    _tabs = null
    _sheet_summary = null
    _contract_buttons.clear()
    _upgrade_buttons.clear()
    _speed_buttons.clear()
    _editor_candidates = null
    super._open_sheet(kind, title, height)
    if is_instance_valid(_pause):
        _pause.disabled = true
        _pause.focus_mode = Control.FOCUS_NONE

func _make_scroll(with_tabs: bool = false) -> void:
    if with_tabs:
        _tabs = HBoxContainer.new()
        _tabs.name = "CampaignTabs"
        _tabs.add_theme_constant_override("separation", 6)
        _body.add_child(_tabs)
        for id in ["contracts", "upgrades", "demand"]:
            var title: String = {"contracts":"契約", "upgrades":"設備", "demand":"契約内訳"}[id]
            var button := _button(_tabs, title, _switch_release_tab.bind(id), _release_tab == id)
            button.name = "Tab_" + id
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    _scroll = ScrollContainer.new()
    _scroll.name = "CampaignScroll"
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.follow_focus = true
    _scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _body.add_child(_scroll)
    _content = VBoxContainer.new()
    _content.name = "CampaignContent"
    _content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _content.add_theme_constant_override("separation", 12)
    _scroll.add_child(_content)
    _layout_body()

func _text(parent: Node, value: String, font_size: int = BODY_FONT_SIZE, color: Color = INK) -> Label:
    var label := _label(parent, value, font_size, color)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    return label

func _action(parent: Node, value: String, action: Callable, primary: bool = false) -> Button:
    var button := _button(parent, value, action, primary)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size.y = CONTROL_HEIGHT
    button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    return button

func _card(parent: Node) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(Color("e0e8e1"), LINE))
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(panel)
    var margin := MarginContainer.new()
    for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
        margin.add_theme_constant_override(key, 12)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)
    return box

func show_entry() -> void:
    if not _built:
        return
    _entry_resume_running = _trial_running
    _open_sheet("entry", "FLOTRA の遊び方", 532)
    _close.text = "倉庫へ"
    _make_scroll()
    _text(_content, "小さな倉庫を、\n頼られる倉庫へ", 24).name = "EntryLead"
    _text(_content, "① 契約を受ける\n決まった荷物を最後まで出荷しよう", 16).name = "EntryGoal1"
    _text(_content, "② 配置を工夫する\n棚・保管床と梱包台を動かして流れを改善", 16).name = "EntryGoal2"
    _text(_content, "③ 報酬で設備を育てる\n6契約を達成。その後は最速記録に挑戦", 16).name = "EntryGoal3"
    _text(_content, "早い出荷で金メダルへ。時間を超えても続行できます。\n右上で一時停止。結果で1x / 2xを切替", 14, Color("476266")).name = "EntrySafety"
    _text(_content, _save_status, 15, Color("476266")).name = "EntrySaveStatus"
    _action(_content, "倉庫の続きへ" if _has_started or not _release.get("current_contract", {}).is_empty() else "契約を選んで始める", close_sheet, true).name = "StartTrial"
    _layout_body()

func _start_trial() -> void:
    super._start_trial()
    if str(_release.get("status", "ready")) == "ready":
        _release_tab = "contracts"
        show_job_choices()

func show_job_choices() -> void:
    _read_release()
    _open_sheet("jobs", "受注・設備", 630)
    _make_scroll(true)
    _populate_release_tab()
    _layout_body()

func _switch_release_tab(id: String) -> void:
    if _sheet_kind != "jobs" or id == _release_tab:
        return
    _release_tab = id
    show_job_choices()
    var tab := _tabs.get_node_or_null("Tab_" + id) as Button
    if tab != null:
        tab.grab_focus()

func _signature() -> String:
    var current: Dictionary = _release.get("current_contract", {})
    return "%s:%s:%s:%s:%s" % [_release.get("status", "ready"), current.get("id", ""), _release.get("completed_count", 0), _release.get("wallet", 0), str(_release.get("upgrades", []))]

func _populate_release_tab() -> void:
    if not is_instance_valid(_content):
        return
    _release_signature = _signature()
    match _release_tab:
        "contracts":
            _build_contracts()
        "upgrades":
            _build_upgrades()
        "demand":
            _build_demand()
    _sync_focus.call_deferred()

func _build_contracts() -> void:
    _sheet_summary = _text(_content, _campaign_summary(), 20)
    _sheet_summary.name = "ContractSummary"
    var ordered := _contracts.duplicate()
    ordered.sort_custom(func(a, b):
        var a_rank := 0 if bool(a.get("available", false)) and not bool(a.get("completed", false)) else (1 if bool(a.get("completed", false)) else 2)
        var b_rank := 0 if bool(b.get("available", false)) and not bool(b.get("completed", false)) else (1 if bool(b.get("completed", false)) else 2)
        return a_rank < b_rank
    )
    for option in ordered:
        var id := str(option.get("id", ""))
        var box := _card(_content)
        box.name = "ContractCard_" + id
        _text(box, str(option.get("label", id)) + ("  達成済み" if bool(option.get("completed", false)) else ""), 22)
        _text(box, str(option.get("description", "")), 15)
        _text(box, "%d個 · 初回報酬 %d" % [int(option.get("total_units", 0)), int(option.get("reward", 0))], 20)
        var best := float(option.get("best_time", 0.0))
        if best > 0:
            _text(box, "自己ベスト %s  %s" % [_record_clock(best), _medal(str(option.get("best_medal", "")))], 14)
        var button := _action(box, "記録に再挑戦" if bool(option.get("completed", false)) else "この契約を受ける", _request_contract.bind(id), bool(option.get("available", false)) and not bool(option.get("completed", false)))
        button.name = "AcceptContract_" + id
        button.disabled = not bool(option.get("available", false))
        if button.disabled:
            _text(box, _locked_text(str(option.get("locked_reason", ""))), 14, Color("476266"))
        _contract_buttons[id] = button
        _text(box, "まとめ%d便・小口%d便\n金 %s / 銀 %s以内" % [int(option.get("bulk_manifests", 0)), int(option.get("pick_manifests", 0)), _clock(float(option.get("gold_seconds", 0))), _clock(float(option.get("silver_seconds", 0)))], BODY_FONT_SIZE, Color("476266"))
        _text(box, "まとめ便は荷下ろし後%d秒保管" % int(option.get("dwell", 0)), BODY_FONT_SIZE, Color("476266"))
    _text(_content, "達成で報酬と次の契約が解放。再挑戦は記録更新用で、報酬は初回だけ。", BODY_FONT_SIZE, Color("476266")).name = "ContractRules"
    if _contracts.is_empty():
        _text(_content, "契約を準備しています", 16)

func _campaign_summary() -> String:
    var progress: Dictionary = _release.get("progress", {})
    var current: Dictionary = _release.get("current_contract", {})
    var summary := "達成 %d / %d契約  ·  資金 %d" % [int(_release.get("completed_count", 0)), int(_release.get("total_contracts", 6)), int(_release.get("wallet", 0))]
    if not current.is_empty():
        summary += "\n%s  %d/%d個" % [str(current.get("label", "")), int(progress.get("shipped", 0)), int(progress.get("total", 0))]
    return summary

func _build_upgrades() -> void:
    _sheet_summary = _text(_content, "資金 %d" % int(_release.get("wallet", 0)), 20)
    _sheet_summary.name = "UpgradeWallet"
    _text(_content, "設備は契約の合間に購入。効果は以後の契約と再挑戦に引き継がれます。", 15, Color("476266"))
    for option in _upgrades:
        var id := str(option.get("id", ""))
        var box := _card(_content)
        box.name = "UpgradeCard_" + id
        var owned := bool(option.get("owned", false))
        _text(box, str(option.get("label", id)) + ("  導入済み" if owned else ""), 22)
        _text(box, str(option.get("description", "")), 15)
        var button := _action(box, "導入済み" if owned else "資金 %dで導入" % int(option.get("cost", 0)), _request_upgrade.bind(id), not owned and bool(option.get("available", false)))
        button.name = "BuyUpgrade_" + id
        button.disabled = owned or not bool(option.get("available", false))
        _upgrade_buttons[id] = button
        if button.disabled and not owned:
            _text(box, _locked_text(str(option.get("locked_reason", ""))), 14, Color("476266"))

func _build_demand() -> void:
    var current: Dictionary = _release.get("current_contract", {})
    _text(_content, "契約ごとの決まった荷物", 20)
    _text(_content, "この契約の内訳は固定です。荷物を減らさず、配置と設備で出荷を早めよう。", 16)
    if not current.is_empty():
        _text(_content, str(current.get("label", "")), 18)
        _text(_content, "まとめ保管 %d便 / 小口梱包 %d便\n合計 %d個" % [int(current.get("bulk_manifests", 0)), int(current.get("pick_manifests", 0)), int(_release.get("progress", {}).get("total", current.get("total_units", 0)))], 16)
    else:
        _text(_content, "まず「契約」から最初の仕事を選びます", 16)
    _text(_content, "まとめ保管：床に置く → 保管 → 出荷\n小口梱包：棚 → ピック → 梱包 → 出荷", 15)
    if not current.is_empty():
        _text(_content, "この契約のまとめ便は、荷下ろし後%d秒の保管が必要です。設備を増やしても、この時間は変わりません。" % int(current.get("dwell", 0)), 15).name = "BulkHoldingRule"
    _text(_content, "保管床を広く残すか、棚と梱包台の動線を短くするか。下の「配置変更」で工夫できます。", 15, Color("476266"))

func _refresh_contract_content() -> void:
    if not is_instance_valid(_content):
        return
    if _signature() != _release_signature:
        # A completion or purchase changes availability. Rebuild atomically and
        # invalidate held controls, but keep the user's current section and scroll.
        var position := _scroll.scroll_vertical
        _input_epoch += 1
        for child in _content.get_children():
            _content.remove_child(child)
            child.queue_free()
        _contract_buttons.clear()
        _upgrade_buttons.clear()
        _populate_release_tab()
        _scroll.set_deferred("scroll_vertical", position)
    elif is_instance_valid(_sheet_summary):
        if _release_tab == "contracts":
            _sheet_summary.text = _campaign_summary()
        elif _release_tab == "upgrades":
            _sheet_summary.text = "資金 %d" % int(_release.get("wallet", 0))

func _request_contract(id: String) -> void:
    if _sheet_kind != "jobs" or _release_tab != "contracts":
        return
    var button := _contract_buttons.get(id) as Button
    if not is_instance_valid(button) or button.disabled:
        return
    button.disabled = true
    close_sheet()
    contract_requested.emit(id)

func _request_upgrade(id: String) -> void:
    if _sheet_kind != "jobs" or _release_tab != "upgrades":
        return
    var button := _upgrade_buttons.get(id) as Button
    if not is_instance_valid(button) or button.disabled:
        return
    button.disabled = true
    upgrade_requested.emit(id)

func show_contract_result(result: Dictionary) -> void:
    _notice_title = "契約を受注しました" if bool(result.get("ok", false)) else "契約を確認してください"
    _notice = "荷物をすべて出荷すると達成。配置を工夫しよう" if bool(result.get("ok", false)) else _locked_text(str(result.get("detail", result.get("reason", ""))))
    _notice_seconds = 4.0
    refresh()

func show_upgrade_result(result: Dictionary) -> void:
    _notice_title = "設備を導入しました" if bool(result.get("ok", false)) else "設備を確認してください"
    _notice = "次の契約と再挑戦で、新しい設備を使えます" if bool(result.get("ok", false)) else _locked_text(str(result.get("detail", result.get("reason", ""))))
    _notice_seconds = 4.0
    _release_signature = ""
    refresh()

func _locked_text(reason: String) -> String:
    return str({"contract_in_progress":"進行中の契約を終えると選べます", "locked_contract":"前の契約を達成すると解放されます", "unshipped_cargo":"今の荷物と設備の移動が終わるまでお待ちください", "unknown_contract":"この契約は見つかりません", "unknown_upgrade":"この設備は見つかりません", "busy":"進行中の契約を終えると選べます", "contract_running":"進行中の契約を終えると選べます", "active_contract":"進行中の契約を終えると選べます", "locked":"前の契約を達成すると解放されます", "insufficient_funds":"資金が足りません。次の契約で報酬を獲得", "funds":"資金が足りません。次の契約で報酬を獲得", "owned":"すでに導入済みです", "already_owned":"すでに導入済みです", "contract_mix_fixed":"契約の荷物の内訳は固定です"}.get(reason, reason if not reason.is_empty() else "前の契約を達成すると選べます"))

func _compact_funds(value: int) -> String:
    if value >= 100000000:
        return "%.1f億" % (float(value) / 100000000.0)
    return "%.1f万" % (float(value) / 10000.0) if value >= 10000 else str(value)

func _medal(value: String) -> String:
    return str({"gold":"金", "silver":"銀", "bronze":"銅"}.get(value, ""))

func _clock(seconds: float) -> String:
    var whole := maxi(0, roundi(seconds * 100.0) / 100)
    return "%d:%02d" % [whole / 60, whole % 60]

func _record_clock(seconds: float) -> String:
    var centiseconds := maxi(0, roundi(seconds * 100.0))
    return "%d:%02d.%02d" % [centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100]

func _live_target(current: Dictionary, elapsed: float) -> String:
    if current.is_empty(): return "契約を選ぼう"
    var outcome: Dictionary = _release.get("last_result", {})
    if str(_release.get("status", "")) in ["contract_complete", "campaign_complete"]:
        return "%sメダルで達成" % _medal(str(outcome.get("medal", "bronze")))
    var gold := float(current.get("gold_seconds", 0))
    var silver := float(current.get("silver_seconds", 0))
    var elapsed_cs := roundi(elapsed * 100.0)
    if elapsed_cs <= roundi(gold * 100.0): return "金目標 %s" % _clock(gold)
    if elapsed_cs <= roundi(silver * 100.0): return "銀目標 %s" % _clock(silver)
    return "完走で銅メダル"

func show_conditions() -> void:
    _read_release()
    _open_sheet("records", "契約の結果", 630)
    _make_scroll()
    _text(_content, "", 24).name = "ReleaseRecordSummary"
    _text(_content, "", 20).name = "ReleaseRecordProgress"
    _text(_content, "", 20).name = "ReleaseRecordOutcome"
    _action(_content, "次の契約・設備を見る", _open_contracts, true).name = "NextContract"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordMetrics"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordBest"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordStatus"
    _text(_content, "倉庫の進行速度", 15)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    _content.add_child(row)
    for value in [1, 2]:
        var button := _action(row, "%dx" % value, _choose_speed.bind(float(value)), int(_speed) == value)
        button.name = "Speed%dx" % value
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _speed_buttons[value] = button
    _action(_content, "一時停止" if _trial_running else "再開", _toggle_pause).name = "TogglePause"
    _text(_content, _save_status, 14, Color("476266")).name = "RecordSaveStatus"
    _update_record()
    _layout_body()

func _update_record() -> void:
    if _sheet_kind != "records" or not is_instance_valid(_content) or not _content.has_node("ReleaseRecordSummary"):
        return
    var progress: Dictionary = _release.get("progress", {})
    var current: Dictionary = _release.get("current_contract", {})
    var outcome: Dictionary = _release.get("last_result", {})
    var status := str(_release.get("status", "ready"))
    var complete := status in ["contract_complete", "campaign_complete"]
    var elapsed := float(_release.get("elapsed", 0.0))
    var best := float(_release.get("best_time", 0.0))
    var heading := "契約は進行中" if status == "running" else "最初の契約を選ぼう"
    if complete:
        heading = "契約達成 · %sメダル" % _medal(str(outcome.get("medal", "bronze")))
    if complete and not outcome.is_empty() and not bool(outcome.get("first_completion", false)):
        heading = "再挑戦達成 · %sメダル" % _medal(str(outcome.get("medal", "bronze")))
    if status == "campaign_complete" and bool(outcome.get("first_completion", false)):
        heading = "全6契約を達成！\n%sメダル" % _medal(str(outcome.get("medal", "bronze")))
    _content.get_node("ReleaseRecordSummary").text = heading
    _content.get_node("ReleaseRecordProgress").text = "%s\n出荷 %d / %d個  ·  %s" % [str(current.get("label", "受注・設備から始められます")), int(progress.get("shipped", 0)), int(progress.get("total", 0)), _record_clock(elapsed)]
    _content.get_node("ReleaseRecordMetrics").text = "金 %s以内 / 銀 %s以内\n道待ち %.0f秒（全員合計）・配置移動 %.1f秒" % [_clock(float(current.get("gold_seconds", 0))), _clock(float(current.get("silver_seconds", 0))), float(_snapshot.get("aisle_wait_seconds", 0)), float(_snapshot.get("relocation_seconds", 0))] if not current.is_empty() else "まとめ便は保管床、小口便は集品・梱包が要です"
    _content.get_node("ReleaseRecordBest").text = "自己ベスト %s%s" % [_record_clock(best), "  新記録！" if bool(outcome.get("new_best", false)) else ""] if best > 0 else "完了すると自己ベストが残ります"
    _content.get_node("ReleaseRecordOutcome").text = ("報酬 %d（初回のみ）\n資金 %d · 設備は次の契約へ引き継ぎ" % [int(outcome.get("earnings", 0)), int(_release.get("wallet", 0))]) if bool(outcome.get("first_completion", false)) else ("再挑戦は記録更新用。資金と設備は引き継ぎます" if complete else "")
    _content.get_node("NextContract").text = "再挑戦・設備を見る" if bool(_release.get("campaign_complete", false)) else ("次の契約・設備を見る" if status in ["ready", "contract_complete"] else "契約・設備を見る")
    _content.get_node("ReleaseRecordStatus").text = _reason_title.text + "\n" + _reason_detail.text
    _content.get_node("TogglePause").text = "一時停止" if _trial_running else "再開"
    _content.get_node("RecordSaveStatus").text = _save_status
    for value in _speed_buttons:
        var button: Button = _speed_buttons[value]
        button.text = ("● " if int(_speed) == value else "") + "%dx" % value
        button.add_theme_stylebox_override("normal", _style(TEAL if int(_speed) == value else Color("e3eae2"), LINE))

func _open_contracts() -> void:
    _release_tab = "contracts"
    show_job_choices()

func _choose_speed(value: float) -> void:
    if _sheet_kind != "records" or is_equal_approx(value, _speed):
        return
    set_speed(value)
    speed_requested.emit(value)

func _update_choice() -> void:
    super._update_choice()
    for button in _choice_buttons:
        button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
        button.text = button.text.replace("現在の配置", "使用中")
    if _sheet_kind == "editor" and is_instance_valid(_apply) and str(_release.get("status", "ready")) != "running" and not _apply.disabled:
        _cost.text = "契約の合間の配置変更・作業停止なし"

func show_action_result(result: Dictionary) -> void:
    if bool(result.get("ok", false)) and not bool(result.get("pending", true)) and str(_release.get("status", "ready")) != "running":
        _notice_title = "配置を変更しました"
        _notice = "次の契約で、新しい動線を確認しよう"
        _notice_seconds = 4.0
        refresh()
        return
    super.show_action_result(result)

func _confirm_restart() -> void:
    # A release never exposes the prototype's destructive reset path.
    _open_contracts()

func _reset() -> void:
    _open_contracts()

func _update_mix_choice() -> void:
    # Contracts expose their demand read-only; no prototype mix controls exist.
    pass

func _short_save_status() -> String:
    if _save_status.contains("テスト"):
        return "テスト・保存なし"
    if _save_status.contains("できません") or _save_status.contains("失敗") or _save_status.contains("保護") or _save_status.contains("保存されません"):
        return "保存に注意 · 結果へ"
    return _save_status

func _layout() -> void:
    if not _built:
        return
    var width := _root.size.x
    var height := _root.size.y
    _rect(_header, 0, 0, width, 76)
    _rect(_back, 10, 10, 84, CONTROL_HEIGHT)
    _back.text = "遊び方" if _sheet_kind.is_empty() else "戻る"
    if is_instance_valid(_pause):
        _rect(_pause, width - 82, 10, 72, CONTROL_HEIGHT)
        _pause.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    _rect(_title, 104, 5, width - 196, 35)
    _title.add_theme_font_size_override("font_size", 24)
    _rect(_safe_note, 104, 40, width - 196, 28)
    _safe_note.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    _rect(_reason_panel, 12, 80, width - 24, 52)
    _rect(_reason_title, 12, 6, width - 48, 40)
    _reason_title.add_theme_font_size_override("font_size", 20)
    _reason_title.autowrap_mode = TextServer.AUTOWRAP_OFF
    _reason_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    # Keep the operational explanation available in Results. One clear live
    # status is more useful than stacking three paragraphs above the warehouse.
    _reason_detail.hide()
    _reason_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
    _reason_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _rect(_reason_detail, 12, 0, width - 48, 52)
    _observed_note.hide()
    _rect(_bottom, 12, height - 148, width - 24, 136)
    _rect(_shipped, 12, 4, width - 48, 32)
    _shipped.add_theme_font_size_override("font_size", 20)
    _rect(_travel, 12, 37, (width - 52) / 2, 28)
    _rect(_waiting, (width - 28) / 2, 37, (width - 52) / 2, 28)
    _rect(_observed_note, 12, 0, width - 48, 32)
    for label in [_travel, _waiting]:
        label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    var tab_width := (width - 64) / 3
    _rect(_compare, 12, 72, tab_width, CONTROL_HEIGHT)
    _rect(_primary, 20 + tab_width, 72, tab_width, CONTROL_HEIGHT)
    _rect(_conditions, 28 + tab_width * 2, 72, tab_width, CONTROL_HEIGHT)
    for button in [_back, _compare, _primary, _conditions]:
        button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
    for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
        var nav_style := _compare.get_theme_stylebox(style_name).duplicate() as StyleBoxFlat
        nav_style.content_margin_left = 4
        nav_style.content_margin_right = 4
        _compare.add_theme_stylebox_override(style_name, nav_style)
    _rect(_mask, 0, 76, width, height - 76)
    # Reading screens use all available height. Only layout editing shares the
    # display with an unobscured, tightly framed view of the selected equipment.
    var sheet_top := 80.0
    if _sheet_kind == "editor":
        # A short landscape viewport cannot share vertical space with a useful
        # preview. Keep every control usable in a full-height reading sheet;
        # portrait restores the dedicated world preview automatically.
        _sheet_height = minf(height - 88, roundf(clampf(height * 0.57, 320, 510)))
        sheet_top = height - _sheet_height - 8
    else:
        _sheet_height = height - sheet_top - 8
    _rect(_sheet, 8, sheet_top, width - 16, _sheet_height)
    _rect(_sheet_title, 16, 10, width - 144, CONTROL_HEIGHT)
    _sheet_title.add_theme_font_size_override("font_size", 24)
    _rect(_close, width - 120, 10, 88, CONTROL_HEIGHT)
    _rect(_body, 16, 76, width - 48, _sheet_height - 88)
    if not _sheet_kind.is_empty():
        _layout_body()
    _update_world_region()

func world_insets() -> Vector2:
    return Vector2(76, _sheet_height + 16) if _sheet_kind == "editor" else Vector2(140, 156)

func show_layout_editor() -> void:
    _slot_options = _read_slots()
    _slot_index = clampi(_slot_index, 0, maxi(0, _slot_options.size() - 1))
    _open_sheet("editor", "配置変更", 440)
    _make_scroll()
    if _slot_options.is_empty():
        _text(_content, "配置データを準備しています", 22)
        _text(_content, "倉庫の準備ができたら、ここから区画を選べます")
        _action(_content, "倉庫へ戻る", close_sheet, true)
        return
    _tabs = HBoxContainer.new()
    _tabs.add_theme_constant_override("separation", 8)
    _body.add_child(_tabs)
    _previous = _action(_tabs, "棚・保管床", _move_slot.bind(-1))
    _previous.name = "PreviousSlot"
    _next = _action(_tabs, "梱包台", _move_slot.bind(1))
    _next.name = "NextSlot"
    _choice_title = _text(_content, "", 20)
    _choice_title.name = "SelectedSlot"
    _choice_title.hide()
    _editor_candidates = VBoxContainer.new()
    _editor_candidates.add_theme_constant_override("separation", 8)
    _content.add_child(_editor_candidates)
    _benefit = _text(_content, "")
    _benefit.name = "Benefit"
    _tradeoff = _text(_content, "")
    _tradeoff.name = "Tradeoff"
    _cost = _text(_content, "", BODY_FONT_SIZE, Color("476266"))
    _cost.name = "Cost"
    _apply = _action(_body, "この場所に動かす", _apply_choice, true)
    _apply.name = "ApplyChoice"
    _choose_current_slot()
    _update_slot_tabs()
    _layout_body()

func _choose_current_slot() -> void:
    if not is_instance_valid(_editor_candidates):
        super._choose_current_slot()
        return
    for button in _choice_buttons:
        button.get_parent().remove_child(button)
        button.queue_free()
    _choice_buttons.clear()
    var slot := _current_slot()
    _choice_id = str(slot.get("current_choice_id", slot.get("choice_id", slot.get("current", ""))))
    var choices: Array = slot.get("choices", [])
    if _choice_id.is_empty() and not choices.is_empty():
        _choice_id = str(choices[0].get("id", ""))
    for choice in choices:
        var id := str(choice.get("id", ""))
        var button := _action(_editor_candidates, str(choice.get("label", id)), _choose.bind(id))
        button.name = "Candidate_" + id
        _choice_buttons.append(button)
    _update_choice()
    _layout_body()
    selected_slot_changed.emit(str(slot.get("id", "")))
    candidate_changed.emit(str(slot.get("id", "")), _choice_id)
    slot_candidate_changed.emit(str(slot.get("id", "")), _choice_id)

func _layout_body() -> void:
    if _sheet_kind in ["entry", "jobs", "records", "editor"]:
        if not _built or not is_instance_valid(_scroll):
            return
        # Safari chrome can leave only ~320px in landscape. Once three fixed
        # rows would squeeze out a complete 56px choice, let the equipment tabs
        # scroll with the choices instead; Apply remains pinned in either mode.
        var scrolling_tabs := _sheet_kind == "editor" and _body.size.y < CONTROL_HEIGHT * 3 + 24
        var offset := 0.0
        if is_instance_valid(_tabs):
            var tabs_parent: Node = _content if scrolling_tabs else _body
            if _tabs.get_parent() != tabs_parent:
                _tabs.reparent(tabs_parent, false)
            if scrolling_tabs:
                _tabs.custom_minimum_size.y = CONTROL_HEIGHT
                _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                _content.move_child(_tabs, 0)
            else:
                offset = CONTROL_HEIGHT + 12
                _rect(_tabs, 0, 0, _body.size.x, CONTROL_HEIGHT)
        var footer := 0.0
        if _sheet_kind == "editor" and is_instance_valid(_apply):
            footer = CONTROL_HEIGHT + 12
            _rect(_apply, 0, _body.size.y - CONTROL_HEIGHT, _body.size.x, CONTROL_HEIGHT)
        _rect(_scroll, 0, offset, _body.size.x, maxf(48, _body.size.y - offset - footer))
        _sync_focus.call_deferred()
        return
    super._layout_body()

func debug_state() -> Dictionary:
    var state := super.debug_state()
    state["release"] = _release.duplicate(true)
    state["release_tab"] = _release_tab
    state["save_status"] = _save_status
    state["speed"] = _speed
    return state
