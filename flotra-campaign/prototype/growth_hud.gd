extends "res://prototype/release_hud.gd"
## Growth-first copy and navigation over the repaired release interface.
## Every domain mutation still goes through the scene-owned release signals.
## Inherited buttons retain held-touch, dismissal-epoch and focus-loss guards;
## inherited layout keeps 18px text, 56px controls and the pinned editor action.

const MILESTONE_COUNT := 6
const WING_COUNT := 4
var _history_visible := false

func _init() -> void:
    _speed = 2.0

func _build() -> void:
    super._build()
    _root.name = "GrowthHUD"
    _root.theme.default_font_size = BODY_FONT_SIZE

func _button(parent: Node, value: String, action: Callable, primary: bool = false, light: bool = true) -> Button:
    var button := super._button(parent, value, action, primary, light)
    if is_instance_valid(_content) and _content.is_ancestor_of(button):
        # Allow a drag begun on a scroll-sheet action to reach ScrollContainer.
        # It cancels the held BaseButton on scroll-begin; normal taps still pass
        # through every inherited epoch, focus-loss and dismissal check.
        button.mouse_filter = Control.MOUSE_FILTER_PASS
    return button

func set_speed(value: float) -> void:
    # The scene is authoritative. Do not turn 4x into the old release's 2x.
    _speed = 4.0 if value >= 4.0 else (2.0 if value >= 2.0 else 1.0)
    refresh()

func _growth() -> Dictionary:
    return _release.get("growth", {})

func _complete() -> bool:
    return str(_release.get("status", "ready")) in ["contract_complete", "campaign_complete"]

func _milestones() -> int:
    return clampi(int(_growth().get("completed_milestones", 0)), 0, MILESTONE_COUNT)

func _next_goal() -> String:
    var goal := str(_growth().get("next_goal", ""))
    if not goal.is_empty():
        return goal
    for option in _contracts:
        if str(option.get("id", "")).begins_with("growth_") and not bool(option.get("completed", false)):
            return str(option.get("label", "次の仕事を届けよう"))
    return "好きな仕事で資金をため、倉庫を育てよう"

func _throughput() -> float:
    var elapsed := float(_release.get("elapsed", 0.0))
    var delivered := int(_release.get("progress", {}).get("shipped", 0))
    return float(delivered) * 60.0 / elapsed if elapsed > 0.0 else 0.0

func _growth_summary() -> String:
    var growth := _growth()
    return "増築 %d/%d棟 · 面積 %.0f㎡\nスタッフ %d人 · ロボット %d台" % [int(growth.get("wing_count", 0)), WING_COUNT, float(growth.get("area", 0.0)), int(growth.get("human_count", _release.get("worker_count", 0))), int(growth.get("robot_count", 0))]

func _next_improvement() -> Dictionary:
    # A genuinely available purchase comes first. A cheap but locked purchase
    # must never be advertised as something the player can buy right now.
    var available: Array = []
    var future: Array = []
    for option in _upgrades:
        if bool(option.get("owned", false)):
            continue
        if bool(option.get("available", false)):
            available.append(option)
        else:
            future.append(option)
    var choices: Array = available if not available.is_empty() else future
    if choices.is_empty():
        return {}
    choices.sort_custom(func(a, b): return int(a.get("cost", 0)) < int(b.get("cost", 0)))
    return choices[0]

func _improvement_summary() -> String:
    var option := _next_improvement()
    if option.is_empty():
        return "設備がそろいました。好きな仕事で出荷を続けよう"
    var name := str(option.get("label", "次の設備"))
    var cost := int(option.get("cost", 0))
    if bool(option.get("available", false)):
        return "今買える：%s（資金 %d）" % [name, cost]
    if str(_release.get("status", "")) == "running":
        return "仕事の合間に増築・採用・設備を選べます"
    var shortfall := maxi(0, cost - int(_release.get("wallet", 0)))
    var detail := _locked_text(str(option.get("locked_reason", "")))
    return "次の設備：%s\n%s" % [name, "あと資金 %d" % shortfall if shortfall > 0 else detail]

func refresh() -> void:
    super.refresh()
    if not _built:
        return
    var progress: Dictionary = _release.get("progress", {})
    var current: Dictionary = _release.get("current_contract", {})
    var total := int(progress.get("total", 0))
    var delivered := int(progress.get("shipped", 0))
    var wallet := int(_release.get("wallet", 0))
    _compare.text = "次の仕事" if _complete() else "仕事"
    _conditions.text = "成果"
    _shipped.text = "出荷 %d/%d個  資金 %s" % [delivered, total, _compact_funds(wallet)] if total > 0 else "出荷 0個  資金 %s" % _compact_funds(wallet)
    _travel.text = "出荷 %.1f個/分" % _throughput()
    _travel.tooltip_text = "今回の平均出荷数（倉庫内の1分あたり）。進行速度を変えても同じ基準です"
    _waiting.text = "%dx · 増築 %d/%d" % [int(_speed), int(_growth().get("wing_count", 0)), WING_COUNT]
    _waiting.tooltip_text = _growth_summary()
    _observed_note.text = "成長 %d/%d · %s" % [_milestones(), MILESTONE_COUNT, _next_goal()]
    if _notice.is_empty():
        if _complete():
            var result: Dictionary = _release.get("last_result", {})
            _reason_title.text = "出荷完了！ 報酬 +%d" % int(result.get("earnings", 0))
            _reason_detail.text = _next_goal() + "\n" + _improvement_summary()
        elif str(_release.get("status", "ready")) == "ready":
            _reason_title.text = "小さな仕事から、倉庫を育てよう"
            _reason_detail.text = _next_goal()
        elif _trial_running and str(_snapshot.get("pending_layout_id", "")).is_empty():
            _reason_detail.text += "\n次の成長：" + _next_goal()
    if _sheet_kind == "records":
        _update_record()

func _show_operational_reason() -> void:
    super._show_operational_reason()
    var progress: Dictionary = _release.get("progress", {})
    if _reason_title.text.begins_with("目標：") or _reason_title.text == "2種類の仕事が進行中":
        _reason_title.text = "お届け中 · あと%d個" % int(progress.get("remaining", maxi(0, int(progress.get("total", 0)) - int(progress.get("shipped", 0)))))
        _reason_detail.text = str(_release.get("current_contract", {}).get("label", "受けた仕事を出荷中"))
    elif _reason_title.text == "保管時間の終了待ち":
        _reason_title.text = "荷物を保管中 · 準備ができたら出荷"
        _reason_detail.text = "まとめ便は保管を終えると自動で出荷へ進みます"

func _live_target(_current: Dictionary, _elapsed: float) -> String:
    # Also used while the inherited refresh is running. No medal deadlines.
    return "%dx · 増築 %d/%d" % [int(_speed), int(_growth().get("wing_count", 0)), WING_COUNT]

func show_entry() -> void:
    if not _built:
        return
    _read_release()
    _entry_resume_running = _trial_running
    _open_sheet("entry", "FLOTRA の遊び方", 630)
    _close.text = "倉庫へ"
    _make_scroll()
    _text(_content, "届けるたびに、\n倉庫が大きくなる", 24).name = "EntryLead"
    _text(_content, "① 小さな仕事を届ける\n6つの成長ステップを、ひとつずつ", BODY_FONT_SIZE).name = "EntryGoal1"
    _text(_content, "② 報酬で倉庫を育てる\n4棟の増築、スタッフ、運搬ロボット、自動梱包", BODY_FONT_SIZE).name = "EntryGoal2"
    _text(_content, "③ 好きな仕事を繰り返す\nまとめ便・小口便・ミックス便で、毎回報酬を獲得", BODY_FONT_SIZE).name = "EntryGoal3"
    _text(_content, "制限時間なし。自分のペースで育てよう\n標準は2x。「成果」で1x / 2x / 4xに切替", BODY_FONT_SIZE, Color("476266")).name = "EntrySafety"
    if bool(_growth().get("legacy_profile", false)):
        _text(_content, "以前の資金・設備・記録は引き継がれています。進行中の仕事も、そのまま続けられます", BODY_FONT_SIZE, Color("476266")).name = "LegacyContinuity"
    _text(_content, _save_status, BODY_FONT_SIZE, Color("476266")).name = "EntrySaveStatus"
    _action(_content, "倉庫の続きへ" if _has_started or not _release.get("current_contract", {}).is_empty() else "最初の仕事を選ぶ", close_sheet, true).name = "StartTrial"
    _layout_body()

func _make_scroll(with_tabs: bool = false) -> void:
    # Two roomy sections replace the old contract/equipment/demand tab trio.
    # Layout editing calls this without tabs and keeps its inherited pinned UI.
    if with_tabs:
        _tabs = HBoxContainer.new()
        _tabs.name = "CampaignTabs"
        _tabs.add_theme_constant_override("separation", 8)
        _body.add_child(_tabs)
        for id in ["contracts", "upgrades"]:
            var title := "仕事" if id == "contracts" else "倉庫を育てる"
            var button := _button(_tabs, title, _switch_release_tab.bind(id), _release_tab == id)
            button.name = "Tab_" + id
            button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    super._make_scroll(false)

func _card(parent: Node) -> VBoxContainer:
    var box := super._card(parent)
    # Passive panels must pass pointer gestures to the ScrollContainer. A
    # default PanelContainer stops drags that begin on a card's text/padding.
    # Buttons still come from the inherited guarded factory unchanged.
    box.mouse_filter = Control.MOUSE_FILTER_PASS
    var margin := box.get_parent() as Control
    margin.mouse_filter = Control.MOUSE_FILTER_PASS
    var panel := margin.get_parent() as Control
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    return box

func show_job_choices() -> void:
    _read_release()
    if _release_tab not in ["contracts", "upgrades"]:
        _release_tab = "contracts"
    _open_sheet("jobs", "仕事と成長", 630)
    _make_scroll(true)
    _populate_release_tab()
    _layout_body()

func _signature() -> String:
    # No continuously changing counter here: rebuilding on shipment ticks would
    # invalidate a held finger. Purchases/completions alone refresh the cards.
    return super._signature() + ":" + str(_milestones()) + ":" + str(_growth().get("wing_count", 0))

func _campaign_summary() -> String:
    var summary := "成長 %d/%d · 資金 %d\n次の目標：%s" % [_milestones(), MILESTONE_COUNT, int(_release.get("wallet", 0)), _next_goal()]
    if str(_release.get("status", "")) == "running":
        var progress: Dictionary = _release.get("progress", {})
        summary += "\nお届け中 %d/%d個" % [int(progress.get("shipped", 0)), int(progress.get("total", 0))]
    return summary

func _option_rank(option: Dictionary) -> int:
    if bool(option.get("available", false)) and not bool(option.get("completed", false)):
        return 0
    return 1 if bool(option.get("available", false)) else 2

func _build_contracts() -> void:
    _sheet_summary = _text(_content, _campaign_summary(), 20)
    _sheet_summary.name = "ContractSummary"
    var milestones: Array = []
    var repeats: Array = []
    var previous: Array = []
    for option in _contracts:
        if str(option.get("id", "")).begins_with("growth_"):
            milestones.append(option)
        elif bool(option.get("repeatable", false)):
            repeats.append(option)
        else:
            previous.append(option)
    for group in [milestones, repeats, previous]:
        group.sort_custom(func(a, b): return _option_rank(a) < _option_rank(b))
    # Put the next step before the full roadmap so short phone screens reach
    # their first useful action without scrolling through locked future work.
    var next_milestone: Dictionary = {}
    for option in milestones:
        if not bool(option.get("completed", false)):
            next_milestone = option
            break
    if not next_milestone.is_empty():
        _text(_content, "次の成長ステップ", 22)
        _build_job_card(next_milestone, false, true)
    _text(_content, _improvement_summary(), BODY_FONT_SIZE, Color("476266")).name = "NextImprovement"
    _action(_content, "増築・スタッフ・設備を見る", _open_upgrades).name = "OpenGrowthUpgrades"
    if not repeats.is_empty():
        _text(_content, "いつもの仕事 · 毎回報酬", 22)
        _text(_content, "好きな種類を選んで、次の増築や設備の資金に", BODY_FONT_SIZE, Color("476266"))
        for option in repeats:
            _build_job_card(option)
    if not milestones.is_empty():
        _text(_content, "成長の道のり · 全6ステップ", 22)
        for option in milestones:
            if str(option.get("id", "")) != str(next_milestone.get("id", "")):
                _build_job_card(option)
    if not previous.is_empty():
        _text(_content, "以前の仕事", 22)
        for option in previous:
            _build_job_card(option, true)
    if _contracts.is_empty():
        _text(_content, "仕事を準備しています")
    _text(_content, "新しい仕事は、完了するたびに報酬を獲得。時間制限はありません", BODY_FONT_SIZE, Color("476266")).name = "ContractRules"

func _build_job_card(option: Dictionary, legacy: bool = false, featured: bool = false) -> void:
    var id := str(option.get("id", ""))
    var box := _card(_content)
    box.name = "ContractCard_" + id
    var completed := bool(option.get("completed", false))
    var suffix := " · 達成済み" if completed and id.begins_with("growth_") else ""
    _text(box, str(option.get("label", id)) + suffix, 22)
    var description := str(option.get("description", ""))
    if not featured and not description.is_empty():
        _text(box, description)
    var reward := int(option.get("reward", 0))
    var reward_copy := "毎回の報酬 %d" % reward
    if legacy:
        reward_copy = "初回報酬 %d" % reward if not completed else "保存済みの仕事・記録"
    _text(box, "%d個 · %s" % [int(option.get("total_units", 0)), reward_copy], 20)
    var available := bool(option.get("available", false))
    var label := "この仕事を受ける"
    if completed:
        label = "もう一度受ける" if legacy else "もう一度受ける · +%d" % reward
    var button := _action(box, label, _request_contract.bind(id), available)
    button.name = "AcceptContract_" + id
    button.disabled = not available
    _contract_buttons[id] = button
    _text(box, "まとめ%d便 · 小口%d便" % [int(option.get("bulk_manifests", 0)), int(option.get("pick_manifests", 0))], BODY_FONT_SIZE, Color("476266"))
    if not available:
        _text(box, _locked_text(str(option.get("locked_reason", ""))), BODY_FONT_SIZE, Color("476266"))

func _is_wing(option: Dictionary) -> bool:
    var id := str(option.get("id", ""))
    return id.begins_with("wing_") or str(option.get("category", "")) == "wing"

func _build_upgrades() -> void:
    _sheet_summary = _text(_content, "資金 %d" % int(_release.get("wallet", 0)), 20)
    _sheet_summary.name = "UpgradeWallet"
    _text(_content, _growth_summary(), 20).name = "GrowthWarehouseSummary"
    _text(_content, _improvement_summary(), BODY_FONT_SIZE, Color("476266")).name = "NextImprovement"
    _text(_content, "仕事の合間に購入。増築・人員・設備は次の仕事にも引き継ぎます", BODY_FONT_SIZE, Color("476266"))
    # Outward expansion is the first category, immediately reachable from the
    # completion screen. No new navigation tabs or automatic purchases.
    var wings: Array = []
    var equipment: Array = []
    for option in _upgrades:
        if _is_wing(option):
            wings.append(option)
        else:
            equipment.append(option)
    if not wings.is_empty():
        _text(_content, "外へ広がる4棟の増築", 22)
        _text(_content, "1棟につき、荷物を置ける保管床が8枠増えます")
        for option in wings:
            _build_upgrade_card(option)
    if not equipment.is_empty():
        _text(_content, "仲間と設備を増やす", 22)
        for option in equipment:
            _build_upgrade_card(option)
    if _upgrades.is_empty():
        _text(_content, "設備を準備しています")

func _build_upgrade_card(option: Dictionary) -> void:
    var id := str(option.get("id", ""))
    var box := _card(_content)
    box.name = "UpgradeCard_" + id
    var owned := bool(option.get("owned", false))
    _text(box, str(option.get("label", id)) + (" · 導入済み" if owned else ""), 22)
    _text(box, str(option.get("description", "")))
    var price := int(option.get("cost", 0))
    var label := "導入済み" if owned else "資金 %dで%s" % [price, "増築する" if _is_wing(option) else "導入する"]
    var button := _action(box, label, _request_upgrade.bind(id), not owned and bool(option.get("available", false)))
    button.name = "BuyUpgrade_" + id
    button.disabled = owned or not bool(option.get("available", false))
    _upgrade_buttons[id] = button
    if button.disabled and not owned:
        _text(box, _locked_text(str(option.get("locked_reason", ""))), BODY_FONT_SIZE, Color("476266"))

func _open_upgrades() -> void:
    _release_tab = "upgrades"
    show_job_choices()

func show_contract_result(result: Dictionary) -> void:
    _notice_title = "仕事を受けました" if bool(result.get("ok", false)) else "仕事を確認してください"
    _notice = "すべての荷物を届けると報酬を獲得。自分のペースで進めよう" if bool(result.get("ok", false)) else _locked_text(str(result.get("detail", result.get("reason", ""))))
    _notice_seconds = 4.0
    refresh()

func show_upgrade_result(result: Dictionary) -> void:
    _notice_title = "倉庫が成長しました！" if bool(result.get("ok", false)) else "設備を確認してください"
    _notice = "次の仕事から、新しい広さ・仲間・設備で出荷できます" if bool(result.get("ok", false)) else _locked_text(str(result.get("detail", result.get("reason", ""))))
    _notice_seconds = 4.0
    _release_signature = ""
    if bool(result.get("ok", false)) and str(result.get("upgrade_id", "")).begins_with("wing_"):
        # The new floor is the purchase reward. Reveal it immediately through
        # the inherited dismissal guard instead of hiding it behind this sheet.
        close_sheet()
    refresh()

func _locked_text(reason: String) -> String:
    var copy := super._locked_text(reason)
    return copy.replace("契約", "仕事").replace("再挑戦", "次の仕事")

func show_conditions() -> void:
    _read_release()
    _history_visible = false
    _open_sheet("records", "倉庫の成果", 630)
    _make_scroll()
    _text(_content, "", 24).name = "ReleaseRecordSummary"
    _text(_content, "", 20).name = "ReleaseRecordProgress"
    _text(_content, "", 20).name = "ReleaseRecordOutcome"
    _text(_content, "", 20).name = "GrowthRecordGoal"
    _action(_content, "次の仕事を選ぶ", _open_contracts, true).name = "NextContract"
    _action(_content, "増築・スタッフ・設備を見る", _open_upgrades).name = "GrowWarehouse"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "GrowthRecordImprovement"
    _text(_content, "", 20).name = "GrowthRecordWarehouse"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordMetrics"
    _text(_content, "倉庫の進行速度", 20)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    _content.add_child(row)
    for value in [1, 2, 4]:
        var button := _action(row, "%dx" % value, _choose_speed.bind(float(value)), int(_speed) == value)
        button.name = "Speed%dx" % value
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _speed_buttons[value] = button
    _text(_content, "標準は2x。制限時間はなく、いつでも変更できます", BODY_FONT_SIZE, Color("476266"))
    _action(_content, "一時停止" if _trial_running else "再開", _toggle_pause).name = "TogglePause"
    _text(_content, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordStatus"
    _action(_content, "参考の出荷記録を見る", _toggle_history).name = "ToggleGrowthHistory"
    var history := VBoxContainer.new()
    history.name = "GrowthHistory"
    history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    history.add_theme_constant_override("separation", 8)
    _content.add_child(history)
    _text(history, "", BODY_FONT_SIZE, Color("476266")).name = "ReleaseRecordBest"
    _text(history, "", BODY_FONT_SIZE, Color("476266")).name = "SavedJobRecords"
    _text(history, "時間はふり返り用です。報酬は新しい仕事を完了するたびに受け取れます", BODY_FONT_SIZE, Color("476266"))
    history.visible = _history_visible
    _text(_content, _save_status, BODY_FONT_SIZE, Color("476266")).name = "RecordSaveStatus"
    _update_record()
    _layout_body()

func _toggle_history() -> void:
    if _sheet_kind != "records" or not is_instance_valid(_content):
        return
    _history_visible = not _history_visible
    _content.get_node("GrowthHistory").visible = _history_visible
    _content.get_node("ToggleGrowthHistory").text = "参考の出荷記録を閉じる" if _history_visible else "参考の出荷記録を見る"
    _sync_focus.call_deferred()

func _update_record() -> void:
    if _sheet_kind != "records" or not is_instance_valid(_content) or not _content.has_node("GrowthRecordGoal"):
        return
    var progress: Dictionary = _release.get("progress", {})
    var current: Dictionary = _release.get("current_contract", {})
    var outcome: Dictionary = _release.get("last_result", {})
    var status := str(_release.get("status", "ready"))
    var complete := _complete()
    var heading := "仕事を届けています" if status == "running" else "最初の仕事を選ぼう"
    if complete:
        heading = "出荷完了！"
        if str(current.get("id", "")) == "growth_6" and bool(outcome.get("first_completion", false)):
            heading = "6つの成長ステップを達成！"
    _content.get_node("ReleaseRecordSummary").text = heading
    _content.get_node("ReleaseRecordProgress").text = "%s\n出荷 %d/%d個" % [str(current.get("label", "小さな仕事から始められます")), int(progress.get("shipped", 0)), int(progress.get("total", 0))]
    _content.get_node("ReleaseRecordOutcome").text = "今回の報酬 +%d · 資金 %d" % [int(outcome.get("earnings", 0)), int(_release.get("wallet", 0))] if complete else "資金 %d" % int(_release.get("wallet", 0))
    _content.get_node("GrowthRecordGoal").text = "成長 %d/%d\n次の目標：%s" % [_milestones(), MILESTONE_COUNT, _next_goal()]
    _content.get_node("NextContract").text = "仕事一覧を見る" if status == "running" else "次の仕事を選ぶ"
    _content.get_node("GrowthRecordImprovement").text = _improvement_summary()
    _content.get_node("GrowthRecordWarehouse").text = _growth_summary()
    _content.get_node("ReleaseRecordMetrics").text = "今回の平均 %.1f個/分\nこれまでの出荷 %d個\n平均は倉庫内の時間で計算しています" % [_throughput(), int(_growth().get("lifetime_units", 0))]
    _content.get_node("ReleaseRecordStatus").text = _reason_title.text + "\n" + _reason_detail.text
    _content.get_node("TogglePause").text = "一時停止" if _trial_running else "再開"
    _content.get_node("RecordSaveStatus").text = _save_status
    var best := float(_release.get("best_time", 0.0))
    var record := "今回の所要時間 %s" % _record_clock(float(_release.get("elapsed", 0.0)))
    if best > 0.0:
        record += "\nこの仕事の自己ベスト %s" % _record_clock(best)
    if bool(_growth().get("legacy_profile", false)):
        record += "\n以前の仕事の記録も引き継いでいます"
    _content.get_node("GrowthHistory/ReleaseRecordBest").text = record
    _content.get_node("GrowthHistory/SavedJobRecords").text = _saved_records_copy()
    for value in _speed_buttons:
        var button: Button = _speed_buttons[value]
        button.text = ("● " if int(_speed) == value else "") + "%dx" % value
        button.add_theme_stylebox_override("normal", _style(TEAL if int(_speed) == value else Color("e3eae2"), LINE))

func _saved_records_copy() -> String:
    var records: Dictionary = _release.get("results", {})
    if records.is_empty():
        return "完了した仕事の記録が、ここに残ります"
    var legacy_labels := {"first_shift":"01 はじめての出荷", "small_orders":"02 小さな注文ラッシュ", "pallet_wave":"03 パレットの波", "packing_rush":"04 梱包フル稼働", "storage_peak":"05 保管床の勝負", "final_dispatch":"06 最後の大型契約"}
    var lines: Array[String] = []
    var ids: Array = records.keys()
    ids.sort()
    for id in ids:
        var label := str(legacy_labels.get(id, id))
        for option in _contracts:
            if str(option.get("id", "")) == str(id):
                label = str(option.get("label", id))
                break
        var saved: Dictionary = records[id]
        var detail := "%s\n完了%d回 · 自己ベスト %s" % [label, int(saved.get("attempts", 1)), _record_clock(float(saved.get("best_time", 0.0)))]
        # Old medals remain inspectable with their old records. New jobs never
        # suggest a medal target or make the reward depend on a time threshold.
        if legacy_labels.has(id) and not str(saved.get("best_medal", "")).is_empty():
            detail += " · %s" % _medal(str(saved.get("best_medal", "")))
        lines.append(detail)
    return "これまでの仕事\n\n" + "\n\n".join(lines)

func debug_state() -> Dictionary:
    var state := super.debug_state()
    state["growth"] = _growth().duplicate(true)
    state["growth_goal"] = _next_goal()
    state["average_units_per_minute"] = _throughput()
    state["history_visible"] = _history_visible
    return state
