extends "res://prototype/growth_hud.gd"
## The scene owns purchases, dispatch changes and saving. Keep the existing
## free operating modes and guarded input factory unchanged.

signal dispatch_window_requested(value: int)

func show_save_protection(reason: String) -> void:
    _open_sheet("save_protection", "保存データを保護中", 630)
    _make_scroll()
    _text(_content, "保存を確認できないため、進行を止めています", 22).name = "SaveProtectionTitle"
    _text(_content, reason, BODY_FONT_SIZE, Color("745026")).name = "SaveProtectionReason"
    _text(_content, "既存の保存データを保護しています。仕事の開始・設備の購入・変更はできません", BODY_FONT_SIZE)
    _close.text = "停止中"
    _close.disabled = true
    _layout_body()

func close_sheet() -> void:
    if _sheet_kind == "save_protection": return
    super.close_sheet()

func _layout_body() -> void:
    if _sheet_kind == "save_protection" and is_instance_valid(_scroll):
        _rect(_scroll, 0, 0, _body.size.x, maxf(48, _body.size.y))
        return
    super._layout_body()

func _dispatch() -> Dictionary:
    if is_instance_valid(sim) and sim.has_method("dispatch_state"):
        return sim.call("dispatch_state")
    return {}

func _signature() -> String:
    var state := _dispatch()
    # Never include live cargo counters: normal shipment ticks must not rebuild
    # a control beneath a held finger. A committed selection must rebuild it.
    return super._signature() + ":dispatch:" + str([
        state.get("owned", false), state.get("selected_window", 6),
        state.get("effective_window", 6), state.get("can_switch", false),
        state.get("blocked_reason", "")])

func _build_upgrade_card(option: Dictionary, parent: Node = null) -> void:
    super._build_upgrade_card(option, parent)
    if str(option.get("id", "")) != "pick_dispatch_board": return
    var container: Node = parent if parent != null else _content
    var box := container.find_child("UpgradeCard_pick_dispatch_board", true, false)
    if box != null:
        _text(box, "導入後も6枠から始まります。6 / 12枠の切替は、仕事の合間に無料でできます", BODY_FONT_SIZE, Color("476266")).name = "DispatchPurchaseHint"

func _build_operations() -> void:
    super._build_operations()
    var state := _dispatch()
    if not bool(state.get("owned", false)): return
    # This is a sibling of the existing operation controls, deliberately outside
    # OwnedUpgrades. Buying the board must not hide its controls in that fold.
    var box := _card(_content)
    box.name = "DispatchWindowControls"
    _text(box, "集品指示盤 · 次の仕事", 20)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    box.add_child(row)
    var selected := int(state.get("selected_window", 6))
    for value in [6, 12]:
        var chosen: bool = value == selected
        var button := _action(row, "%d枠%s" % [value, " · 選択中" if chosen else ""], _request_dispatch_window.bind(value), chosen)
        button.name = "ChooseDispatch%d" % value
        button.disabled = chosen or not bool(state.get("can_switch", false))
    _text(box, _dispatch_reason(state), BODY_FONT_SIZE, Color("476266")).name = "DispatchSwitchReason"
    _text(box, "6枠は先行指示を抑え、12枠はより先まで集品を指示します", BODY_FONT_SIZE)
    _text(box, "12枠にしても収納場所は増えません。通路待ちが増え、仕事によっては遅くなります", BODY_FONT_SIZE, Color("745026")).name = "DispatchTradeoff"
    _text(box, "枠は集品から梱包までの作業指示です。棚の予約・運搬中・梱包待ち・梱包中を含みます", BODY_FONT_SIZE, Color("476266")).name = "DispatchMeaning"

func _dispatch_reason(state: Dictionary) -> String:
    if str(_release.get("status", "")) == "running" or str(state.get("blocked_reason", "")) == "job_in_progress":
        return "仕事中は変更できません。一時停止中も同じです。すべて出荷したら無料で切り替えられます"
    if bool(state.get("can_switch", false)):
        return "次の仕事は%d枠 · 切替無料" % int(state.get("selected_window", 6))
    return str(state.get("blocked_reason", "今の仕事が終わると無料で変更できます"))

func _request_dispatch_window(value: int) -> void:
    if _sheet_kind != "jobs" or _release_tab != "upgrades" or value not in [6, 12]: return
    var state := _dispatch()
    if not bool(state.get("owned", false)) or not bool(state.get("can_switch", false)) or value == int(state.get("selected_window", 6)): return
    dispatch_window_requested.emit(value)

func show_dispatch_window_result(result: Dictionary) -> void:
    if bool(result.get("ok", false)):
        _notice_title = "次の仕事は%d枠にしました" % int(_dispatch().get("selected_window", 6))
        _notice = "切替は無料です。仕事の合間なら、6枠にも12枠にも戻せます"
    else:
        _notice_title = "指示量を変更できません"
        _notice = _dispatch_reason(_dispatch())
    _notice_seconds = 4.0
    _equipment_notice = _notice_title
    _release_signature = ""
    refresh()

func _comparison_copy() -> String:
    var text := super._comparison_copy()
    var comparison: Dictionary = sim.call("job_comparison") if sim.has_method("job_comparison") else {}
    var previous: Dictionary = comparison.get("previous", {})
    var current: Dictionary = comparison.get("current", {})
    # Earlier summaries never recorded this condition. Do not infer it from
    # current ownership or the selected window after the completed job.
    var before: Variant = previous.get("dispatch_window")
    var after: Variant = current.get("dispatch_window")
    if before is int and after is int and before in [6, 12] and after in [6, 12]:
        text += "\n集品指示量：%d枠 → %d枠" % [before, after]
    return text
