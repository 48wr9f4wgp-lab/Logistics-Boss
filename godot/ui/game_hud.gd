extends CanvasLayer
class_name GameHud

var sim: WarehouseSim

var _money: Label
var _rp: Label
var _throughput: Label
var _orders: Label
var _bottleneck: Label
var _bottleneck_panel: PanelContainer
var _speed_button: Button
var _manage_button: Button
var _flow_button: Button
var _inbound_button: Button
var _outbound_button: Button
var _sheet: PanelContainer
var _upgrade_buttons: Dictionary = {}
var _toast_panel: PanelContainer
var _toast: Label
var _toast_timer := 0.0
var _speed_index := 1
var _speeds := [0.0, 1.0, 2.0, 4.0]


func bind_sim(next_sim: WarehouseSim) -> void:
    sim = next_sim
    sim.event_emitted.connect(_on_sim_event)
    _render()


func _ready() -> void:
    _build_brand_strip()
    _build_top_hud()
    _build_bottleneck_chip()
    _build_bottom_dock()
    _build_management_sheet()
    _build_toast()


func _process(delta: float) -> void:
    if sim == null:
        return

    _render()

    if _toast_timer > 0.0:
        _toast_timer -= delta
        if _toast_timer <= 0.0:
            _toast_panel.visible = false


func _build_brand_strip() -> void:
    var brand := HBoxContainer.new()
    brand.anchor_left = 0.0
    brand.anchor_right = 1.0
    brand.anchor_top = 0.0
    brand.anchor_bottom = 0.0
    brand.offset_left = 16.0
    brand.offset_right = -16.0
    brand.offset_top = 8.0
    brand.offset_bottom = 42.0
    add_child(brand)

    var title := Label.new()
    title.text = "LOGISTICS BOSS"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 18)
    title.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
    brand.add_child(title)

    var tag := Label.new()
    tag.text = "BUILD · OPERATE · GROW"
    tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tag.add_theme_font_size_override("font_size", 9)
    tag.add_theme_color_override("font_color", Color(0.35, 0.70, 0.88))
    brand.add_child(tag)


func _build_top_hud() -> void:
    var top := HBoxContainer.new()
    top.anchor_left = 0.0
    top.anchor_right = 1.0
    top.anchor_top = 0.0
    top.anchor_bottom = 0.0
    top.offset_left = 12.0
    top.offset_right = -12.0
    top.offset_top = 48.0
    top.offset_bottom = 112.0
    top.add_theme_constant_override("separation", 6)
    add_child(top)

    _money = _metric(top, _copy("資金", "FUNDS"), Color(1.0, 0.69, 0.25))
    _rp = _metric(top, _copy("研究RP", "RESEARCH RP"), Color(0.42, 0.64, 1.0))
    _throughput = _metric(top, _copy("出荷ペース", "SHIP RATE"), Color(0.35, 0.91, 0.73))
    _orders = _metric(top, _copy("注文待ち", "ORDERS"), Color(1.0, 0.66, 0.32))


func _build_bottleneck_chip() -> void:
    _bottleneck_panel = PanelContainer.new()
    _bottleneck_panel.anchor_left = 0.0
    _bottleneck_panel.anchor_right = 1.0
    _bottleneck_panel.anchor_top = 0.0
    _bottleneck_panel.anchor_bottom = 0.0
    _bottleneck_panel.offset_left = 12.0
    _bottleneck_panel.offset_right = -12.0
    _bottleneck_panel.offset_top = 120.0
    _bottleneck_panel.offset_bottom = 168.0
    _bottleneck_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.042, 0.058, 0.96), Color(0.18, 0.56, 0.72, 0.82), 14))
    add_child(_bottleneck_panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    _bottleneck_panel.add_child(row)

    var label := Label.new()
    label.text = "Bottleneck Director"
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", Color(0.67, 0.79, 0.86))
    row.add_child(label)

    _bottleneck = Label.new()
    _bottleneck.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _bottleneck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _bottleneck.add_theme_font_size_override("font_size", 13)
    _bottleneck.add_theme_color_override("font_color", Color(0.55, 1.0, 0.73))
    row.add_child(_bottleneck)


func _build_bottom_dock() -> void:
    var dock := PanelContainer.new()
    dock.anchor_left = 0.0
    dock.anchor_right = 1.0
    dock.anchor_top = 1.0
    dock.anchor_bottom = 1.0
    dock.offset_left = 10.0
    dock.offset_right = -10.0
    dock.offset_top = -88.0
    dock.offset_bottom = -10.0
    dock.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.036, 0.050, 0.985), Color(0.12, 0.33, 0.46, 0.96), 18))
    add_child(dock)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    dock.add_child(row)

    _flow_button = _dock_button(row, "FLOW")
    _flow_button.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.BALANCED))

    _inbound_button = _dock_button(row, _copy("入庫", "IN"))
    _inbound_button.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.INBOUND))

    _outbound_button = _dock_button(row, _copy("出庫", "OUT"))
    _outbound_button.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.SHIP))

    _speed_button = _dock_button(row, "1×")
    _speed_button.pressed.connect(_cycle_speed)

    _manage_button = _dock_button(row, _copy("投資", "CAPITAL"))
    _manage_button.pressed.connect(_toggle_sheet)


func _build_management_sheet() -> void:
    _sheet = PanelContainer.new()
    _sheet.anchor_left = 0.0
    _sheet.anchor_right = 1.0
    _sheet.anchor_top = 0.42
    _sheet.anchor_bottom = 1.0
    _sheet.offset_left = 10.0
    _sheet.offset_right = -10.0
    _sheet.offset_top = 0.0
    _sheet.offset_bottom = -96.0
    _sheet.visible = false
    _sheet.add_theme_stylebox_override("panel", _panel_style(Color(0.016, 0.035, 0.050, 0.995), Color(0.16, 0.55, 0.76, 0.92), 20))
    add_child(_sheet)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    _sheet.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var head := HBoxContainer.new()
    column.add_child(head)

    var title := Label.new()
    title.text = _copy("事業投資", "CAPITAL EXPANSION")
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 21)
    title.add_theme_color_override("font_color", Color(0.91, 0.98, 1.0))
    head.add_child(title)

    var close := Button.new()
    close.text = _copy("閉じる", "CLOSE")
    close.custom_minimum_size = Vector2(82, 44)
    close.add_theme_font_size_override("font_size", 13)
    _apply_button_style(close, false)
    close.pressed.connect(_toggle_sheet)
    head.add_child(close)

    var hint := Label.new()
    hint.text = _copy("詰まりを見て、原因に効く投資だけを選ぶ。", "Read the bottleneck. Invest only where flow improves.")
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 11)
    hint.add_theme_color_override("font_color", Color(0.56, 0.69, 0.76))
    column.add_child(hint)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)

    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)

    _upgrade_buttons[&"worker"] = _upgrade_button(list, _copy("現場チーム増員", "WORKFORCE"), _copy("実働スタッフ +1", "Active worker +1"))
    _upgrade_buttons[&"rack"] = _upgrade_button(list, _copy("ラック棟増設", "RACK EXPANSION"), _copy("棚容量 +4箱 / 3Dラック増設", "Storage +4 / visible rack expansion"))
    _upgrade_buttons[&"speed"] = _upgrade_button(list, _copy("搬送トレーニング", "FLOW TRAINING"), _copy("作業員の移動・処理速度 +15%", "Worker handling speed +15%"))
    _upgrade_buttons[&"packing"] = _upgrade_button(list, _copy("梱包モジュール", "PACK MODULE"), _copy("梱包時間 約15%短縮", "Packing time ~15% faster"))


func _build_toast() -> void:
    _toast_panel = PanelContainer.new()
    _toast_panel.anchor_left = 0.5
    _toast_panel.anchor_right = 0.5
    _toast_panel.anchor_top = 0.56
    _toast_panel.anchor_bottom = 0.56
    _toast_panel.offset_left = -104.0
    _toast_panel.offset_right = 104.0
    _toast_panel.offset_top = -25.0
    _toast_panel.offset_bottom = 25.0
    _toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.12, 0.10, 0.96), Color(0.24, 0.85, 0.56, 0.90), 16))
    _toast_panel.visible = false
    add_child(_toast_panel)

    _toast = Label.new()
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _toast.add_theme_font_size_override("font_size", 17)
    _toast.add_theme_color_override("font_color", Color(0.66, 1.0, 0.79))
    _toast_panel.add_child(_toast)


func _metric(parent: Container, caption: String, accent: Color) -> Label:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(0, 60)
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.045, 0.062, 0.96), Color(accent.r, accent.g, accent.b, 0.78), 12))
    parent.add_child(panel)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(box)

    var small := Label.new()
    small.text = caption
    small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    small.add_theme_font_size_override("font_size", 9)
    small.add_theme_color_override("font_color", Color(0.62, 0.74, 0.80))
    box.add_child(small)

    var value := Label.new()
    value.text = "—"
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", 16)
    value.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
    box.add_child(value)
    return value


func _dock_button(parent: Container, text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0, 58)
    button.add_theme_font_size_override("font_size", 12)
    _apply_button_style(button, false)
    parent.add_child(button)
    return button


func _upgrade_button(parent: Container, title: String, effect: String) -> Button:
    var button := Button.new()
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0, 78)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 14)
    button.set_meta("title", title)
    button.set_meta("effect", effect)
    _apply_button_style(button, false)
    parent.add_child(button)

    var kind: StringName = &"worker"
    if title.contains("RACK") or title.begins_with("ラック"):
        kind = &"rack"
    elif title.contains("FLOW") or title.begins_with("搬送"):
        kind = &"speed"
    elif title.contains("PACK") or title.begins_with("梱包"):
        kind = &"packing"

    button.pressed.connect(func(): _buy(kind))
    return button


func _buy(kind: StringName) -> void:
    var result := sim.purchase_upgrade(kind)
    if not bool(result.get("ok", false)):
        _show_toast(_copy("購入できない", "PURCHASE BLOCKED"))
        return
    _show_toast(_copy("投資完了", "UPGRADE COMPLETE") + "  -¥%s" % _format_number(int(result["cost"])))


func _cycle_speed() -> void:
    _speed_index = (_speed_index + 1) % _speeds.size()
    var scale := float(_speeds[_speed_index])
    sim.set_time_scale(scale)
    _speed_button.text = "Ⅱ" if scale <= 0.0 else "%s×" % int(scale)


func _toggle_sheet() -> void:
    _sheet.visible = not _sheet.visible
    _manage_button.text = _copy("閉じる", "CLOSE") if _sheet.visible else _copy("投資", "CAPITAL")


func _render() -> void:
    if sim == null or _money == null:
        return

    _money.text = "¥%s" % _format_number(sim.money)
    _rp.text = "%d RP" % sim.research_rp
    _throughput.text = "%.0f/" % sim.throughput_per_minute() + _copy("分", "MIN")
    _orders.text = str(sim.open_orders)

    var bottleneck := sim.bottleneck()
    _bottleneck.text = _bottleneck_text(bottleneck)
    _style_bottleneck(int(bottleneck.get("severity", 0)))
    _style_policy_buttons()

    for kind in _upgrade_buttons:
        var button: Button = _upgrade_buttons[kind]
        var cost := sim.upgrade_cost(kind)
        var title := String(button.get_meta("title"))
        var effect := String(button.get_meta("effect"))
        button.text = "%s\n%s   ¥%s" % [title, effect, _format_number(cost)]
        button.disabled = sim.money < cost or _is_maxed(kind)


func _bottleneck_text(info: Dictionary) -> String:
    if not OS.has_feature("web"):
        return String(info.get("label", ""))
    match String(info.get("key", "stable")):
        "inbound":
            return "INBOUND CONGESTED"
        "rack":
            return "STORAGE FULL"
        "packing":
            return "PACKING QUEUE"
        "outbound":
            return "OUTBOUND QUEUE"
        "orders":
            return "ORDER BACKLOG"
        _:
            return "STABLE FLOW"


func _style_bottleneck(severity: int) -> void:
    var color := Color(0.34, 0.92, 0.66)
    if severity >= 2:
        color = Color(1.0, 0.40, 0.32)
    elif severity == 1:
        color = Color(1.0, 0.72, 0.28)
    _bottleneck.add_theme_color_override("font_color", color)


func _style_policy_buttons() -> void:
    _apply_button_style(_flow_button, sim.policy == WarehouseSim.Policy.BALANCED)
    _apply_button_style(_inbound_button, sim.policy == WarehouseSim.Policy.INBOUND)
    _apply_button_style(_outbound_button, sim.policy == WarehouseSim.Policy.SHIP)


func _apply_button_style(button: Button, selected: bool) -> void:
    if button == null:
        return
    var bg := Color(0.025, 0.055, 0.075, 0.96)
    var border := Color(0.14, 0.30, 0.38, 0.95)
    if selected:
        bg = Color(0.025, 0.16, 0.24, 0.99)
        border = Color(0.20, 0.72, 1.0, 1.0)
    button.add_theme_stylebox_override("normal", _panel_style(bg, border, 12))
    button.add_theme_stylebox_override("hover", _panel_style(Color(0.035, 0.10, 0.14, 0.99), Color(0.24, 0.64, 0.84, 1.0), 12))
    button.add_theme_stylebox_override("pressed", _panel_style(Color(0.03, 0.18, 0.25, 1.0), Color(0.30, 0.80, 1.0, 1.0), 12))
    button.add_theme_stylebox_override("disabled", _panel_style(Color(0.025, 0.042, 0.052, 0.80), Color(0.12, 0.19, 0.22, 0.72), 12))
    button.add_theme_color_override("font_color", Color(0.89, 0.96, 0.99))
    button.add_theme_color_override("font_disabled_color", Color(0.42, 0.52, 0.56))


func _is_maxed(kind: StringName) -> bool:
    match kind:
        &"worker":
            return sim.worker_count >= 7
        &"rack":
            return sim.rack_level >= 4
        &"speed":
            return sim.speed_level >= 4
        &"packing":
            return sim.pack_level >= 4
    return true


func _on_sim_event(event: Dictionary) -> void:
    match String(event.get("type", "")):
        "shipment":
            _show_toast(_copy("出荷", "SHIPPED") + " +¥%s" % _format_number(int(event.get("value", 0))))
        "upgrade_purchased":
            _render()


func _show_toast(text: String) -> void:
    _toast.text = text
    _toast_panel.visible = true
    _toast_timer = 1.5


func _copy(jp: String, en: String) -> String:
    return en if OS.has_feature("web") else jp


func _format_number(value: int) -> String:
    var raw := str(maxi(0, value))
    var result := ""
    while raw.length() > 3:
        result = "," + raw.right(3) + result
        raw = raw.left(raw.length() - 3)
    return raw + result


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 9.0
    style.content_margin_right = 9.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style
