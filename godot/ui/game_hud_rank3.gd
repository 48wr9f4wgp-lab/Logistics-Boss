extends "res://ui/game_hud_waves.gd"
class_name Rank3GameHud

var _rank3_panel: PanelContainer
var _rank3_status: Label
var _receiving_annex_button: Button


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

    _receiving_annex_button = Button.new()
    _receiving_annex_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _receiving_annex_button.custom_minimum_size = Vector2(0, 68)
    _receiving_annex_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _receiving_annex_button.add_theme_font_size_override("font_size", 11)
    _apply_button_style(_receiving_annex_button, false)
    _receiving_annex_button.pressed.connect(_purchase_receiving_annex)
    column.add_child(_receiving_annex_button)


func _render_rank3() -> void:
    if sim == null or _rank3_panel == null or _rank3_status == null or _receiving_annex_button == null:
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
        _rank3_status.text = "RANK 3 解禁条件\n拡張 %d/%d  ｜ 契約 %d/%d  ｜ 出荷 %.1f/%.1f分" % [
            int(readiness.get("zones", 0)),
            int(readiness.get("zones_required", 3)),
            int(readiness.get("contracts", 0)),
            int(readiness.get("contracts_required", 8)),
            float(readiness.get("throughput", 0.0)),
            float(readiness.get("throughput_required", 6.0)),
        ]
        _receiving_annex_button.visible = false
        return

    _progression_label.text = "RANK 3  FULFILLMENT CENTER  ｜ 評価 %d  ｜ 契約 %d件" % [
        sim.logistics_rating,
        sim.completed_contracts,
    ]
    _rank3_status.text = "FULFILLMENT CENTER  次の成長投資"
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
