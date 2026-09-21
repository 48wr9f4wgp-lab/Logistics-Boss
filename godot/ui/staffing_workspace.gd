extends VBoxContainer
class_name StaffingWorkspace

signal applied
signal cancelled
const KEYS := ["inbound", "picking", "shipping"]
const TITLES := {"inbound": "入荷・保管", "picking": "ピッキング", "shipping": "出荷"}
var sim: FlotraV2Sim
var draft: Dictionary = {}
var expected: Dictionary = {}
var selected := ""
var cards: Dictionary = {}
var status: Label
var apply_button: Button
var cancel_button: Button
var actions: HBoxContainer

func bind(next_sim: FlotraV2Sim) -> void:
    sim = next_sim
    add_theme_constant_override("separation", 8)
    status = Label.new()
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status.add_theme_font_size_override("font_size", 12)
    add_child(status)
    for key in KEYS:
        var button := Button.new()
        button.custom_minimum_size = Vector2(0, 68)
        button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        button.pressed.connect(_choose.bind(key))
        add_child(button)
        cards[key] = button
    var note := Label.new()
    note.text = "梱包は設備が担当。人員の枠はありません。"
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 11)
    add_child(note)
    var row := HBoxContainer.new()
    actions = row
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    cancel_button = Button.new()
    cancel_button.text = "取り消して戻る"
    cancel_button.custom_minimum_size = Vector2(0, 48)
    cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cancel_button.pressed.connect(func(): reset_draft(); cancelled.emit())
    row.add_child(cancel_button)
    apply_button = Button.new()
    apply_button.text = "この配置にする"
    apply_button.custom_minimum_size = Vector2(0, 48)
    apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    apply_button.pressed.connect(_apply)
    row.add_child(apply_button)
    reset_draft()

func reset_draft() -> void:
    if sim == null:
        return
    expected = sim.zone_staffing.duplicate(true)
    draft = expected.duplicate(true)
    selected = ""
    refresh()

func _process(_delta: float) -> void:
    if is_visible_in_tree():
        refresh()

func refresh() -> void:
    if sim == null or status == null or draft.is_empty():
        return
    var stale := expected != sim.zone_staffing
    var cooling := sim.staffing_cooldown > 0.0
    status.text = "減らす現場 → 増やす現場をタップ。\n人数を組み替え、最後に一括で反映。"
    if stale:
        status.text = "元の配置が変わりました。取り消して開き直してください。"
    elif cooling:
        status.text = "配置案は作れます。反映まであと%d秒\n作業中の荷物は引き継いでから担当を変更。" % ceili(sim.staffing_cooldown)
    for key in KEYS:
        var n := int(draft[key])
        var markers := "●".repeat(n)
        var action := "ここから1人選ぶ" if selected.is_empty() else ("選択を解除" if selected == key else "ここへ1人移す")
        (cards[key] as Button).text = "%s　%d人 → %d人\n%s　%s" % [TITLES[key], int(expected[key]), n, markers, action]
        (cards[key] as Button).disabled = stale or (selected.is_empty() and n <= 1)
        (cards[key] as Button).set_meta("action_identity", "%s:%s:%s" % [key, selected, str(draft)])
    apply_button.disabled = stale or cooling or draft == expected
    apply_button.set_meta("action_identity", str(draft) + str(expected))

func _choose(key: String) -> void:
    if expected != sim.zone_staffing:
        return
    if selected.is_empty():
        if int(draft[key]) > 1:
            selected = key
    elif key == selected:
        selected = ""
    elif int(draft[selected]) > 1:
        draft[selected] = int(draft[selected]) - 1
        draft[key] = int(draft[key]) + 1
        selected = ""
    refresh()

func _apply() -> void:
    var result := sim.apply_staffing_distribution(draft, expected)
    if bool(result.get("ok", false)):
        reset_draft()
        applied.emit()
    else:
        refresh()
        status.text = "反映できませんでした。現在の人数と観察待ちを確認してください。"
