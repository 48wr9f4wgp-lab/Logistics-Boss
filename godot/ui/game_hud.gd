extends CanvasLayer
class_name GameHud

var sim: WarehouseSim

var _money: Label
var _rp: Label
var _throughput: Label
var _orders: Label
var _bottleneck: Label
var _speed_button: Button
var _manage_button: Button
var _sheet: PanelContainer
var _upgrade_buttons: Dictionary = {}
var _toast: Label
var _toast_timer := 0.0
var _speed_index := 1
var _speeds := [0.0, 1.0, 2.0, 4.0]


func bind_sim(next_sim: WarehouseSim) -> void:
    sim = next_sim
    sim.event_emitted.connect(_on_sim_event)
    _render()


func _ready() -> void:
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
            _toast.visible = false


func _build_top_hud() -> void:
    var top := HBoxContainer.new()
    top.anchor_left = 0.0
    top.anchor_right = 1.0
    top.anchor_top = 0.0
    top.anchor_bottom = 0.0
    top.offset_left = 12.0
    top.offset_right = -12.0
    top.offset_top = 14.0
    top.offset_bottom = 78.0
    top.add_theme_constant_override("separation", 6)
    add_child(top)

    _money = _metric(top, "資金")
    _rp = _metric(top, "研究RP")
    _throughput = _metric(top, "出荷/分")
    _orders = _metric(top, "注文待ち")


func _build_bottleneck_chip() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -118.0
    panel.offset_right = 118.0
    panel.offset_top = 86.0
    panel.offset_bottom = 128.0
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.055, 0.072, 0.94), Color(0.24, 0.63, 0.73, 0.55), 14))
    add_child(panel)

    _bottleneck = Label.new()
    _bottleneck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _bottleneck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _bottleneck.add_theme_font_size_override("font_size", 14)
    _bottleneck.add_theme_color_override("font_color", Color(0.88, 0.96, 0.99))
    panel.add_child(_bottleneck)


func _build_bottom_dock() -> void:
    var dock := PanelContainer.new()
    dock.anchor_left = 0.0
    dock.anchor_right = 1.0
    dock.anchor_top = 1.0
    dock.anchor_bottom = 1.0
    dock.offset_left = 12.0
    dock.offset_right = -12.0
    dock.offset_top = -82.0
    dock.offset_bottom = -12.0
    dock.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.058, 0.96), Color(0.20, 0.34, 0.40, 0.9), 16))
    add_child(dock)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    dock.add_child(row)

    var balanced := _dock_button(row, "均衡")
    balanced.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.BALANCED))

    var inbound := _dock_button(row, "入庫")
    inbound.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.INBOUND))

    var ship := _dock_button(row, "出庫")
    ship.pressed.connect(func(): sim.set_policy(WarehouseSim.Policy.SHIP))

    _speed_button = _dock_button(row, "1×")
    _speed_button.pressed.connect(_cycle_speed)

    _manage_button = _dock_button(row, "投資")
    _manage_button.pressed.connect(_toggle_sheet)


func _build_management_sheet() -> void:
    _sheet = PanelContainer.new()
    _sheet.anchor_left = 0.0
    _sheet.anchor_right = 1.0
    _sheet.anchor_top = 0.40
    _sheet.anchor_bottom = 1.0
    _sheet.offset_left = 10.0
    _sheet.offset_right = -10.0
    _sheet.offset_top = 0.0
    _sheet.offset_bottom = -92.0
    _sheet.visible = false
    _sheet.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.045, 0.058, 0.985), Color(0.22, 0.62, 0.74, 0.75), 18))
    add_child(_sheet)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    _sheet.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    margin.add_child(column)

    var head := HBoxContainer.new()
    column.add_child(head)

    var title := Label.new()
    title.text = "事業投資"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", Color(0.91, 0.98, 1.0))
    head.add_child(title)

    var close := Button.new()
    close.text = "閉じる"
    close.custom_minimum_size = Vector2(82, 46)
    close.add_theme_font_size_override("font_size", 14)
    close.pressed.connect(_toggle_sheet)
    head.add_child(close)

    var hint := Label.new()
    hint.text = "詰まりを見て、原因に効く投資だけを選ぶ。"
    hint.add_theme_font_size_override("font_size", 12)
    hint.add_theme_color_override("font_color", Color(0.59, 0.70, 0.75))
    column.add_child(hint)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)

    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 8)
    scroll.add_child(list)

    _upgrade_buttons[&"worker"] = _upgrade_button(list, "現場チーム増員", "実働スタッフ +1")
    _upgrade_buttons[&"rack"] = _upgrade_button(list, "ラック棟増設", "棚容量 +4箱 / 3Dラック増設")
    _upgrade_buttons[&"speed"] = _upgrade_button(list, "搬送トレーニング", "作業員の移動・処理速度 +15%")
    _upgrade_buttons[&"packing"] = _upgrade_button(list, "梱包モジュール", "梱包時間 約15%短縮")


func _build_toast() -> void:
    _toast = Label.new()
    _toast.anchor_left = 0.5
    _toast.anchor_right = 0.5
    _toast.anchor_top = 0.5
    _toast.anchor_bottom = 0.5
    _toast.offset_left = -95.0
    _toast.offset_right = 95.0
    _toast.offset_top = -24.0
    _toast.offset_bottom = 24.0
    _toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _toast.add_theme_font_size_override("font_size", 18)
    _toast.add_theme_color_override("font_color", Color(0.64, 1.0, 0.78))
    _toast.visible = false
    add_child(_toast)


func _metric(parent: Container, caption: String) -> Label:
    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(0, 58)
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.055, 0.072, 0.90), Color(0.20, 0.42, 0.50, 0.85), 12))
    parent.add_child(panel)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    panel.add_child(box)

    var small := Label.new()
    small.text = caption
    small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    small.add_theme_font_size_override("font_size", 10)
    small.add_theme_color_override("font_color", Color(0.57, 0.68, 0.73))
    box.add_child(small)

    var value := Label.new()
    value.text = "—"
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value.add_theme_font_size_override("font_size", 16)
    value.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
    box.add_child(value)
    return value


func _dock_button(parent: Container, text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0, 52)
    button.add_theme_font_size_override("font_size", 14)
    parent.add_child(button)
    return button


func _upgrade_button(parent: Container, title: String, effect: String) -> Button:
    var button := Button.new()
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0, 68)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 15)
    button.set_meta("title", title)
    button.set_meta("effect", effect)
    parent.add_child(button)

    var kind: StringName = &"worker"
    if title.begins_with("ラック"):
        kind = &"rack"
    elif title.begins_with("搬送"):
        kind = &"speed"
    elif title.begins_with("梱包"):
        kind = &"packing"

    button.pressed.connect(func(): _buy(kind))
    return button


func _buy(kind: StringName) -> void:
    var result := sim.purchase_upgrade(kind)
    if not bool(result.get("ok", false)):
        _show_toast("購入できない")
        return
    _show_toast("投資完了  -¥%s" % _format_number(int(result["cost"])))


func _cycle_speed() -> void:
    _speed_index = (_speed_index + 1) % _speeds.size()
    var scale := float(_speeds[_speed_index])
    sim.set_time_scale(scale)
    _speed_button.text = "Ⅱ" if scale <= 0.0 else "%s×" % int(scale)


func _toggle_sheet() -> void:
    _sheet.visible = not _sheet.visible
    _manage_button.text = "閉じる" if _sheet.visible else "投資"


func _render() -> void:
    if sim == null or _money == null:
        return

    _money.text = "¥%s" % _format_number(sim.money)
    _rp.text = "%d RP" % sim.research_rp
    _throughput.text = "%.0f/分" % sim.throughput_per_minute()
    _orders.text = str(sim.open_orders)

    var bottleneck := sim.bottleneck()
    _bottleneck.text = String(bottleneck["label"])

    for kind in _upgrade_buttons:
        var button: Button = _upgrade_buttons[kind]
        var cost := sim.upgrade_cost(kind)
        var title := String(button.get_meta("title"))
        var effect := String(button.get_meta("effect"))
        button.text = "%s\n%s   ¥%s" % [title, effect, _format_number(cost)]
        button.disabled = sim.money < cost or _is_maxed(kind)


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
            _show_toast("出荷 +¥%s" % _format_number(int(event.get("value", 0))))
        "upgrade_purchased":
            _render()


func _show_toast(text: String) -> void:
    _toast.text = text
    _toast.visible = true
    _toast_timer = 1.5


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
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    return style
