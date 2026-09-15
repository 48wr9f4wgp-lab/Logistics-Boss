extends "res://ui/game_hud_waves.gd"
class_name Rank3GameHud

var _rank3_panel: PanelContainer
var _rank3_status: Label
var _routing_summary: Label
var _routing_select: OptionButton
var _receiving_annex_button: Button
var _inbound_carrier_button: Button


func _ready() -> void:
    super._ready()
    _build_rank3_section()
    _apply_japanese_font_recursive(_rank3_panel)
    _render_rank3()


func _process(delta: float) -> void:
    super._process(delta)
    _render_rank3()


func _on_sim_event(event: Dictionary) -> void:
    super._on_sim_event(event)
    match String(event.get("type", "")):
        "rank_up":
            if int(event.get("rank", 0)) >= 3:
                _show_toast("RANK 3  FULFILLMENT CENTER 解禁")
                _toast_timer = 4.0
        "receiving_annex_purchased":
            _show_measurement_status("受入増設棟の効果を計測中\n前25秒 → 後25秒", 30.0)
            _show_toast("受入増設棟  稼働開始")
        "routing_changed":
            _show_measurement_status("配送ルートの効果を計測中\n前25秒 → 後25秒", 30.0)
            _show_toast("配送変更  %s" % String(event.get("label", "")))
        "inbound_carrier_program_purchased":
            _show_measurement_status("高頻度入荷の効果を計測中\n前25秒 → 後25秒", 30.0)
            _show_toast("高頻度入荷プログラム  稼働開始")


func _build_rank3_section() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return

    _rank3_panel = PanelContainer.new()
    _rank3_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.052, 0.070, 0.985), Color(1.0, 0.62, 0.22, 0.94), 14)
    )
    list.add_child(_rank3_panel)
    list.move_child(_rank3_panel, mini(1, list.get_child_count() - 1))

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    _rank3_panel.add_child(column)

    _rank3_status = Label.new()
    _rank3_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _rank3_status.add_theme_font_size_override("font_size", 12)
    _rank3_status.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62))
    column.add_child(_rank3_status)

    _routing_summary = Label.new()
    _routing_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _routing_summary.add_theme_font_size_override("font_size", 11)
    _routing_summary.add_theme_color_override("font_color", Color(0.72, 0.91, 1.0))
    column.add_child(_routing_summary)

    _routing_select = OptionButton.new()
    _routing_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _routing_select.custom_minimum_size = Vector2(0, 44)
    _routing_select.add_theme_font_size_override("font_size", 11)
    _routing_select.add_item("Balanced Parcel")
    _routing_select.set_item_metadata(0, "balanced")
    _routing_select.add_item("Express Dispatch")
    _routing_select.set_item_metadata(1, "express")
    _routing_select.add_item("Consolidated Linehaul")
    _routing_select.set_item_metadata(2, "consolidated")
    _apply_button_style(_routing_select, false)
    _routing_select.item_selected.connect(_select_routing_mode)
    column.add_child(_routing_select)

    _receiving_annex_button = Button.new()
    _receiving_annex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _receiving_annex_button.custom_minimum_size = Vector2(0, 68)
    _receiving_annex_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _receiving_annex_button.add_theme_font_size_override("font_size", 11)
    _apply_button_style(_receiving_annex_button, false)
    _receiving_annex_button.pressed.connect(_purchase_receiving_annex)
    column.add_child(_receiving_annex_button)

    _inbound_carrier_button = Button.new()
    _inbound_carrier_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _inbound_carrier_button.custom_minimum_size = Vector2(0, 68)
    _inbound_carrier_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _inbound_carrier_button.add_theme_font_size_override("font_size", 11)
    _apply_button_style(_inbound_carrier_button, false)
    _inbound_carrier_button.pressed.connect(_purchase_inbound_carrier_program)
    column.add_child(_inbound_carrier_button)


func _render_rank3() -> void:
    if (
        sim == null
        or _rank3_panel == null
        or _rank3_status == null
        or _routing_summary == null
        or _routing_select == null
        or _receiving_annex_button == null
        or _inbound_carrier_button == null
    ):
        return
    if not sim.has_method("rank3_readiness"):
        _rank3_panel.visible = false
        return

    var rank := int(sim.facility_rank)
    _rank3_panel.visible = rank >= 2
    if rank < 2:
        return

    var readiness: Dictionary = sim.call("rank3_readiness")
    if rank < 3:
        _rank3_status.text = "RANK 3 解禁条件\n拡張ゾーン %d/%d  ｜ 設備資産 ¥%s/¥%s  ｜ 出荷ペース %.1f/%.1f分" % [
            int(readiness.get("zones", 0)),
            int(readiness.get("zones_required", 3)),
            _format_number(int(readiness.get("assets", 0))),
            _format_number(int(readiness.get("assets_required", 200000))),
            float(readiness.get("throughput", 0.0)),
            float(readiness.get("throughput_required", 6.0)),
        ]
        _routing_summary.visible = false
        _routing_select.visible = false
        _receiving_annex_button.visible = false
        _inbound_carrier_button.visible = false
        return

    _progression_label.text = "RANK 3  FULFILLMENT CENTER  ｜ 評価 %d  ｜ 契約 %d件" % [
        sim.logistics_rating,
        sim.completed_contracts,
    ]
    _rank3_status.text = "FULFILLMENT CENTER  次の成長投資"

    _routing_summary.visible = sim.has_method("routing_summary")
    _routing_select.visible = sim.has_method("routing_summary")
    if _routing_select.visible:
        var routing: Dictionary = sim.call("routing_summary")
        var mode := String(routing.get("mode", "balanced"))
        _routing_summary.text = "配送: %s  ｜ %d個 / ¥%s" % [
            String(routing.get("label", "Balanced Parcel")),
            int(routing.get("batch_size", 1)),
            _format_number(int(routing.get("unit_value", 500))),
        ]
        for index in range(_routing_select.item_count):
            if String(_routing_select.get_item_metadata(index)) == mode:
                _routing_select.select(index)
                break

    _receiving_annex_button.visible = true
    var info: Dictionary = sim.call("receiving_annex_info")
    var owned := bool(info.get("owned", false))
    var cost := int(info.get("cost", 0))
    _receiving_annex_button.disabled = owned or sim.money < cost
    _receiving_annex_button.text = "%s%s\n%s  ｜ ¥%s" % [
        "✓ " if owned else "",
        String(info.get("label", "受入増設棟")),
        String(info.get("effect", "入荷受入能力を拡張")),
        _format_number(cost),
    ]
    _apply_button_style(_receiving_annex_button, owned)

    _inbound_carrier_button.visible = sim.has_method("inbound_carrier_program_info")
    if _inbound_carrier_button.visible:
        var carrier_info: Dictionary = sim.call("inbound_carrier_program_info")
        var carrier_owned := bool(carrier_info.get("owned", false))
        var carrier_cost := int(carrier_info.get("cost", 0))
        var annex_ready := bool(carrier_info.get("annex_ready", false))
        _inbound_carrier_button.disabled = carrier_owned or not annex_ready or sim.money < carrier_cost
        var carrier_effect := String(carrier_info.get("effect", "定期入荷頻度を増加"))
        if not annex_ready and not carrier_owned:
            carrier_effect = "先に受入増設棟が必要"
        _inbound_carrier_button.text = "%s%s\n%s  ｜ ¥%s" % [
            "✓ " if carrier_owned else "",
            String(carrier_info.get("label", "高頻度入荷プログラム")),
            carrier_effect,
            _format_number(carrier_cost),
        ]
        _apply_button_style(_inbound_carrier_button, carrier_owned)


func _select_routing_mode(index: int) -> void:
    if sim == null or not sim.has_method("set_routing_mode"):
        return
    if index < 0 or index >= _routing_select.item_count:
        return
    var mode := String(_routing_select.get_item_metadata(index))
    var result: Dictionary = sim.call("set_routing_mode", mode)
    if bool(result.get("ok", false)) or String(result.get("reason", "")) == "same":
        return
    match String(result.get("reason", "")):
        "rank":
            _show_toast("RANK 3で配送ルート解禁")
        "unknown":
            _show_toast("選択できない配送ルート")
        _:
            _show_toast("配送ルートを変更できない")


func _purchase_receiving_annex() -> void:
    if sim == null or not sim.has_method("purchase_receiving_annex"):
        return
    var result: Dictionary = sim.call("purchase_receiving_annex")
    if bool(result.get("ok", false)):
        return
    match String(result.get("reason", "")):
        "funds":
            _show_toast("資金不足  ¥%s必要" % _format_number(int(result.get("cost", 0))))
        "owned":
            _show_toast("受入増設棟は稼働済み")
        "rank":
            _show_toast("RANK 3で解禁")
        _:
            _show_toast("増設できない")


func _purchase_inbound_carrier_program() -> void:
    if sim == null or not sim.has_method("purchase_inbound_carrier_program"):
        return
    var result: Dictionary = sim.call("purchase_inbound_carrier_program")
    if bool(result.get("ok", false)):
        return
    match String(result.get("reason", "")):
        "funds":
            _show_toast("資金不足  ¥%s必要" % _format_number(int(result.get("cost", 0))))
        "annex":
            _show_toast("先に受入増設棟が必要")
        "owned":
            _show_toast("高頻度入荷プログラムは稼働済み")
        "rank":
            _show_toast("RANK 3で解禁")
        _:
            _show_toast("高頻度入荷を開始できない")
