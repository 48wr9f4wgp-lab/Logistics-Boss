extends Control
class_name WarehouseZonePanel

signal opened(zone_key: String)
signal closed

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")

var sim: WarehouseSim
var _selected_zone := ""

var _panel: PanelContainer
var _title: Label
var _state: Label
var _evidence: Label
var _equipment: Label
var _operations: Label
var _capital: Label
var _operations_action: Button
var _staffing_move_buttons: Array[Button] = []
var _capital_action: Button
var _rank2_capital_buttons: Array[Button] = []
var _action_message: Label
var _close_button: Button
var _preview_kind: StringName = &""


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 60
    _build_panel()


func bind_sim(next_sim: WarehouseSim) -> void:
    sim = next_sim
    _render()


func open_zone(zone_key: String) -> void:
    if zone_key not in ["inbound", "storage", "picking", "packing", "shipping"]:
        return
    if _selected_zone != zone_key:
        _preview_kind = &""
    _selected_zone = zone_key
    if _panel != null:
        _panel.visible = true
    _render()
    opened.emit(zone_key)


func close() -> void:
    if _panel == null or not _panel.visible:
        return
    _panel.visible = false
    _selected_zone = ""
    closed.emit()


func is_open() -> bool:
    return _panel != null and _panel.visible


func selected_zone() -> String:
    return _selected_zone


func _process(_delta: float) -> void:
    if is_open():
        _render()


func _build_panel() -> void:
    _panel = PanelContainer.new()
    _panel.name = "ZonePanel"
    _panel.anchor_left = 0.0
    _panel.anchor_right = 1.0
    _panel.anchor_top = 0.56
    _panel.anchor_bottom = 1.0
    _panel.offset_left = 10.0
    _panel.offset_right = -10.0
    _panel.offset_top = 0.0
    _panel.offset_bottom = -82.0
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _panel.add_theme_stylebox_override("panel", _panel_style())
    _panel.visible = false
    add_child(_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    _panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 6)
    margin.add_child(column)

    var head := HBoxContainer.new()
    head.add_theme_constant_override("separation", 8)
    column.add_child(head)

    var title_column := VBoxContainer.new()
    title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_column.add_theme_constant_override("separation", 0)
    head.add_child(title_column)

    _title = _label(18, Color(0.92, 0.98, 1.0))
    title_column.add_child(_title)

    _state = _label(11, Color(0.46, 0.86, 1.0))
    title_column.add_child(_state)

    _close_button = Button.new()
    _close_button.text = "閉じる"
    _close_button.custom_minimum_size = Vector2(72, 42)
    _close_button.add_theme_font_override("font", JAPANESE_UI_FONT)
    _close_button.add_theme_font_size_override("font_size", 11)
    _close_button.pressed.connect(close)
    head.add_child(_close_button)

    _evidence = _label(12, Color(0.84, 0.93, 0.97))
    _evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_evidence)

    _equipment = _label(11, Color(1.0, 0.78, 0.40))
    _equipment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_equipment)

    var split := HBoxContainer.new()
    split.add_theme_constant_override("separation", 8)
    column.add_child(split)

    var operations_panel := _section_panel(Color(0.20, 0.68, 0.92, 0.80))
    operations_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.add_child(operations_panel)
    var operations_box := VBoxContainer.new()
    operations_panel.add_child(operations_box)
    var operations_title := _label(10, Color(0.56, 0.88, 1.0))
    operations_title.text = "OPERATIONS"
    operations_box.add_child(operations_title)
    _operations = _label(10, Color(0.82, 0.91, 0.95))
    _operations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    operations_box.add_child(_operations)

    _operations_action = Button.new()
    _operations_action.custom_minimum_size = Vector2(0, 44)
    _operations_action.add_theme_font_override("font", JAPANESE_UI_FONT)
    _operations_action.add_theme_font_size_override("font_size", 10)
    _operations_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _operations_action.pressed.connect(_on_operations_action)
    operations_box.add_child(_operations_action)

    for _index in 2:
        var move_button := Button.new()
        move_button.custom_minimum_size = Vector2(0, 38)
        move_button.add_theme_font_override("font", JAPANESE_UI_FONT)
        move_button.add_theme_font_size_override("font_size", 9)
        move_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        move_button.pressed.connect(_on_staffing_move.bind(move_button))
        move_button.visible = false
        operations_box.add_child(move_button)
        _staffing_move_buttons.append(move_button)

    var capital_panel := _section_panel(Color(1.0, 0.62, 0.22, 0.82))
    capital_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.add_child(capital_panel)
    var capital_box := VBoxContainer.new()
    capital_panel.add_child(capital_box)
    var capital_title := _label(10, Color(1.0, 0.77, 0.43))
    capital_title.text = "CAPITAL"
    capital_box.add_child(capital_title)
    _capital = _label(10, Color(0.91, 0.88, 0.80))
    _capital.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    capital_box.add_child(_capital)

    _capital_action = Button.new()
    _capital_action.custom_minimum_size = Vector2(0, 56)
    _capital_action.add_theme_font_override("font", JAPANESE_UI_FONT)
    _capital_action.add_theme_font_size_override("font_size", 10)
    _capital_action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _capital_action.pressed.connect(_on_capital_action)
    capital_box.add_child(_capital_action)

    for _index in 2:
        var equipment_button := Button.new()
        equipment_button.custom_minimum_size = Vector2(0, 56)
        equipment_button.add_theme_font_override("font", JAPANESE_UI_FONT)
        equipment_button.add_theme_font_size_override("font_size", 9)
        equipment_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        equipment_button.pressed.connect(_on_rank2_capital_action.bind(equipment_button))
        equipment_button.visible = false
        capital_box.add_child(equipment_button)
        _rank2_capital_buttons.append(equipment_button)

    _action_message = _label(10, Color(1.0, 0.78, 0.46))
    _action_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(_action_message)


func _render() -> void:
    if sim == null or _selected_zone.is_empty() or _title == null:
        return

    _title.text = _zone_name(_selected_zone)
    _state.text = _zone_state_text(_selected_zone)
    _evidence.text = _zone_evidence(_selected_zone)
    _equipment.text = "現在設備｜%s" % _current_equipment(_selected_zone)
    _operations.text = _operations_text(_selected_zone)
    _capital.text = "設備判断はこのZoneで行う"
    _render_rank1_actions()
    _render_rank2_equipment_actions()
    _render_direct_staffing_actions()


func _render_rank1_actions() -> void:
    if _operations_action == null or _capital_action == null or _action_message == null:
        return

    _operations_action.visible = false
    _capital_action.visible = false
    _action_message.text = ""

    if sim == null or sim.facility_rank != 1 or not sim.has_method("rank1_project_info"):
        return

    var worker_info: Dictionary = sim.call("rank1_project_info", StringName("worker_hire"))
    if not worker_info.is_empty():
        var worker_owned := bool(worker_info.get("owned", false))
        _operations_action.visible = true
        _operations_action.disabled = worker_owned
        _operations_action.text = (
            "✓ Worker Hire｜採用済み"
            if worker_owned
            else "Worker Hire｜全体要員 +1｜¥%s" % _format_money(int(worker_info.get("cost", 0)))
        )

    if not sim.has_method("rank1_project_for_zone"):
        return
    var project_kind := StringName(sim.call("rank1_project_for_zone", _selected_zone))
    if project_kind == &"":
        return

    var info: Dictionary = sim.call("rank1_project_info", project_kind)
    if info.is_empty():
        return

    var owned := bool(info.get("owned", false))
    _capital_action.visible = true
    _capital_action.disabled = owned
    if owned:
        _capital_action.text = "✓ %s｜稼働中" % String(info.get("label", "Project"))
        if _preview_kind == project_kind:
            _preview_kind = &""
        return

    var cost := int(info.get("cost", 0))
    var affordable := sim.money >= cost
    _capital_action.disabled = not affordable
    if _preview_kind == project_kind:
        _capital_action.text = "建設する｜%s｜¥%s" % [
            String(info.get("label", "Project")),
            _format_money(cost),
        ]
        _action_message.text = "%s\n%s" % [
            String(info.get("strength", "")),
            String(info.get("effect", "")),
        ]
    else:
        _capital_action.text = "内容を見る｜%s｜¥%s" % [
            String(info.get("label", "Project")),
            _format_money(cost),
        ]


func _render_rank2_equipment_actions() -> void:
    for button in _rank2_capital_buttons:
        button.visible = false
        button.disabled = true
        button.remove_meta("kind")

    if sim == null or sim.facility_rank != 2:
        return
    if not sim.has_method("rank2_v2_equipment_kinds_for_zone") or not sim.has_method("rank2_v2_equipment_action_info"):
        return

    var kinds: Array = sim.call("rank2_v2_equipment_kinds_for_zone", _selected_zone)
    if kinds.is_empty():
        return

    _capital.text = "設備方式を選ぶ｜改装は新規価格の75%"
    for index in mini(_rank2_capital_buttons.size(), kinds.size()):
        var kind := StringName(kinds[index])
        var info: Dictionary = sim.call("rank2_v2_equipment_action_info", kind)
        if info.is_empty():
            continue

        var button := _rank2_capital_buttons[index]
        var active := bool(info.get("active", false))
        var renovating := bool(info.get("renovating", false))
        var cost := int(info.get("cost", 0))
        button.visible = true
        button.disabled = active
        button.set_meta("kind", String(kind))

        if active:
            button.text = "✓ %s｜稼働中" % String(info.get("label", String(kind)))
            if _preview_kind == kind:
                _preview_kind = &""
            continue

        if _preview_kind == kind:
            button.text = "%s｜%s｜¥%s" % [
                "改装する" if renovating else "建設する",
                String(info.get("label", String(kind))),
                _format_money(cost),
            ]
            _action_message.text = "強み｜%s\n弱み｜%s\n%s・返金なし" % [
                String(info.get("strength", "")),
                String(info.get("weakness", "")),
                "改装" if renovating else "新規建設",
            ]
        else:
            button.text = "%s｜%s｜¥%s" % [
                "改装内容を見る" if renovating else "内容を見る",
                String(info.get("label", String(kind))),
                _format_money(cost),
            ]


func _on_rank2_capital_action(button: Button) -> void:
    if sim == null or not sim.has_method("rank2_v2_equipment_action_info"):
        return
    var kind := StringName(String(button.get_meta("kind", "")))
    if kind == &"":
        return

    if _preview_kind != kind:
        _preview_kind = kind
        _render()
        return

    if not sim.has_method("purchase_facility"):
        return
    var result: Dictionary = sim.call("purchase_facility", kind)
    if bool(result.get("ok", false)):
        var action := String(result.get("action", "build"))
        _preview_kind = &""
        _render()
        _action_message.text = "%s完了｜25秒のBefore / After計測開始" % (
            "改装" if action == "renovate" else "建設"
        )
        return

    _render()
    _action_message.text = _purchase_failure_text(result)


func _render_direct_staffing_actions() -> void:
    for button in _staffing_move_buttons:
        button.visible = false
        button.disabled = true
        button.remove_meta("from_zone")
        button.remove_meta("to_zone")

    if sim == null or sim.facility_rank < 2:
        return
    if not sim.has_method("direct_staffing_summary") or not sim.has_method("staffing_zone_for_warehouse_zone"):
        return

    var target := String(sim.call("staffing_zone_for_warehouse_zone", _selected_zone))
    if target.is_empty():
        if _selected_zone == "packing" and _action_message.text.is_empty():
            _action_message.text = "PACKINGは設備処理｜Worker直接配置なし"
        return

    var summary: Dictionary = sim.call("direct_staffing_summary")
    if not bool(summary.get("enabled", false)):
        return

    var cooldown := float(summary.get("cooldown", 0.0))
    var sources: Array[String] = []
    for zone in ["inbound", "picking", "shipping"]:
        if zone != target:
            sources.append(zone)

    for index in mini(_staffing_move_buttons.size(), sources.size()):
        var source := sources[index]
        var button := _staffing_move_buttons[index]
        var source_count := int(summary.get(source, 0))
        button.visible = true
        button.disabled = cooldown > 0.0 or source_count <= 1
        button.set_meta("from_zone", source)
        button.set_meta("to_zone", target)
        button.text = "%sから1名移す" % _staffing_zone_label(source)

    if cooldown > 0.0 and _action_message.text.is_empty():
        _action_message.text = "配置変更後の観察中｜あと%d秒" % int(ceil(cooldown))


func _on_staffing_move(button: Button) -> void:
    if sim == null or not sim.has_method("reassign_zone_staffing"):
        return
    var from_zone := String(button.get_meta("from_zone", ""))
    var to_zone := String(button.get_meta("to_zone", ""))
    var result: Dictionary = sim.call("reassign_zone_staffing", from_zone, to_zone)
    _render()
    if bool(result.get("ok", false)):
        _action_message.text = "%s → %s｜1名再配置" % [
            _staffing_zone_label(from_zone),
            _staffing_zone_label(to_zone),
        ]
        return

    match String(result.get("reason", "")):
        "minimum":
            _action_message.text = "%sは最低1名必要" % _staffing_zone_label(from_zone)
        "cooldown":
            _action_message.text = "観察中｜あと%d秒" % int(ceil(float(result.get("remaining", 0.0))))
        _:
            _action_message.text = "この配置変更は実行できない"


func _staffing_zone_label(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "RECEIVING"
        "picking":
            return "PICKING"
        "shipping":
            return "SHIPPING"
    return zone_key.to_upper()


func _on_operations_action() -> void:
    if sim == null or not sim.has_method("purchase_rank1_project"):
        return
    var result: Dictionary = sim.call("purchase_rank1_project", StringName("worker_hire"))
    _render()
    if not bool(result.get("ok", false)):
        _action_message.text = _purchase_failure_text(result)


func _on_capital_action() -> void:
    if sim == null or not sim.has_method("rank1_project_for_zone"):
        return
    var project_kind := StringName(sim.call("rank1_project_for_zone", _selected_zone))
    if project_kind == &"":
        return

    if _preview_kind != project_kind:
        _preview_kind = project_kind
        _render()
        return

    if not sim.has_method("purchase_rank1_project"):
        return
    var result: Dictionary = sim.call("purchase_rank1_project", project_kind)
    if bool(result.get("ok", false)):
        _preview_kind = &""
    _render()
    if not bool(result.get("ok", false)):
        _action_message.text = _purchase_failure_text(result)


func _purchase_failure_text(result: Dictionary) -> String:
    match String(result.get("reason", "")):
        "funds":
            return "資金不足｜¥%s必要" % _format_money(int(result.get("cost", 0)))
        "owned":
            return "このProjectは導入済み"
        "rank":
            return "現在の施設Rankでは実行できない"
        _:
            return "このProjectは実行できない"


func _format_money(value: int) -> String:
    var raw := str(maxi(0, value))
    var out := ""
    var count := 0
    for index in range(raw.length() - 1, -1, -1):
        if count > 0 and count % 3 == 0:
            out = "," + out
        out = raw[index] + out
        count += 1
    return out


func _zone_name(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "INBOUND｜入荷"
        "storage":
            return "STORAGE｜保管"
        "picking":
            return "PICKING｜ピッキング"
        "packing":
            return "PACKING｜梱包"
        "shipping":
            return "SHIPPING｜出荷"
    return zone_key.to_upper()


func _zone_state_text(zone_key: String) -> String:
    var pressure := _zone_pressure(zone_key)
    if pressure >= 2:
        return "CONGESTED｜混雑"
    if pressure == 1:
        return "HIGH LOAD｜高負荷"
    return "NORMAL｜正常"


func _zone_pressure(zone_key: String) -> int:
    if sim == null:
        return 0
    match zone_key:
        "inbound":
            if sim.inbound_queue >= 8:
                return 2
            if sim.inbound_queue >= 4:
                return 1
        "storage":
            var fill := float(sim.rack_stock) / float(maxi(1, sim.rack_capacity))
            if fill >= 0.95:
                return 2
            if fill >= 0.70:
                return 1
        "picking":
            if sim.open_orders >= 10:
                return 2
            if sim.open_orders >= 6:
                return 1
        "packing":
            if sim.packing_queue >= 8:
                return 2
            if sim.packing_queue >= 3:
                return 1
        "shipping":
            if sim.packed_queue >= 8:
                return 2
            if sim.packed_queue >= 4:
                return 1
    return 0


func _zone_evidence(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "入荷待ち %d箱\n全体出荷 %.1f/分" % [sim.inbound_queue, sim.throughput_per_minute()]
        "storage":
            var percent := int(round(100.0 * float(sim.rack_stock) / float(maxi(1, sim.rack_capacity))))
            return "保管 %d / %d箱（%d%%）\n注文待ち %d件" % [
                sim.rack_stock,
                sim.rack_capacity,
                percent,
                sim.open_orders,
            ]
        "picking":
            return "注文待ち %d件\n保管在庫 %d箱" % [sim.open_orders, sim.rack_stock]
        "packing":
            return "梱包待ち %d箱\n出荷待ち %d箱" % [sim.packing_queue, sim.packed_queue]
        "shipping":
            return "出荷待ち %d箱\n全体出荷 %.1f/分" % [sim.packed_queue, sim.throughput_per_minute()]
    return ""


func _current_equipment(zone_key: String) -> String:
    if zone_key == "storage":
        var storage := _selected_facility_label("storage")
        if not storage.is_empty():
            return storage
        if sim.has_method("rank1_project_owned") and bool(sim.call("rank1_project_owned", StringName("rack_wing"))):
            return "Rack Wing"
        return "Small Rack"
    if zone_key == "packing":
        var packing := _selected_facility_label("packing")
        if not packing.is_empty():
            return packing
        if sim.has_method("rank1_project_owned") and bool(sim.call("rank1_project_owned", StringName("second_packing_bench"))):
            return "Dual Packing Bench"
        return "Standard Pack Bench"
    if zone_key == "inbound":
        if sim.has_method("rank1_project_owned") and bool(sim.call("rank1_project_owned", StringName("forklift_project"))):
            return "Forklift Automation"
        var intake := _selected_facility_label("intake")
        if not intake.is_empty():
            return intake
        return "Inbound Dock"
    if zone_key == "picking":
        return "Manual Picking"
    if zone_key == "shipping":
        if sim.has_method("routing_summary") and sim.facility_rank >= 3:
            var routing: Dictionary = sim.call("routing_summary")
            return String(routing.get("label", "Standard Dispatch"))
        return "Standard Dispatch"
    return "—"


func _selected_facility_label(group: String) -> String:
    if not sim.has_method("selected_facility_for_group"):
        return ""
    var kind := String(sim.call("selected_facility_for_group", group))
    if kind.is_empty() or not sim.has_method("facility_info"):
        return ""
    var info: Dictionary = sim.call("facility_info", StringName(kind))
    return String(info.get("label", kind))


func _operations_text(zone_key: String) -> String:
    if sim.has_method("direct_staffing_summary") and sim.facility_rank >= 2:
        var direct: Dictionary = sim.call("direct_staffing_summary")
        if bool(direct.get("enabled", false)):
            match zone_key:
                "inbound", "storage":
                    return "担当Worker %d人\nINBOUND→STORAGE" % int(direct.get("inbound", 0))
                "picking":
                    return "担当Worker %d人\n注文処理を担当" % int(direct.get("picking", 0))
                "packing":
                    return "設備処理\nWorker直接配置なし"
                "shipping":
                    return "担当Worker %d人\n出荷処理を担当" % int(direct.get("shipping", 0))

    if not sim.has_method("staffing_summary"):
        return "物流状態を観察"
    var summary: Dictionary = sim.call("staffing_summary")
    match zone_key:
        "inbound":
            return "関連Worker %d人\n入庫フローを観察" % int(summary.get("store", 0))
        "storage":
            return "関連Worker %d人\n保管率と取り出しを観察" % int(summary.get("store", 0))
        "picking":
            return "関連Worker %d人\n注文滞留を観察" % int(summary.get("pick", 0))
        "packing":
            return "PICK %d / SHIP %d\n梱包待ちを観察" % [
                int(summary.get("pick", 0)),
                int(summary.get("ship", 0)),
            ]
        "shipping":
            return "関連Worker %d人\n出荷待ちを観察" % int(summary.get("ship", 0))
    return "物流状態を観察"


func _label(font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.add_theme_font_override("font", JAPANESE_UI_FONT)
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label


func _section_panel(border: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _section_style(border))
    return panel


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.010, 0.031, 0.044, 0.985)
    style.border_color = Color(0.18, 0.72, 0.96, 0.92)
    style.set_border_width_all(1)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
    style.shadow_size = 6
    style.shadow_offset = Vector2(0.0, -2.0)
    return style


func _section_style(border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.020, 0.050, 0.066, 0.94)
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style
