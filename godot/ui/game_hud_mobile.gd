extends "res://ui/game_hud_release.gd"
class_name MobileGameHud

const MOBILE_SHEET_TOP := 0.30
const MOBILE_SHEET_SIDE_MARGIN := 12.0
const MOBILE_SHEET_BOTTOM := -108.0

var _mobile_layout_width := -1.0


func _ready() -> void:
    super._ready()
    _apply_mobile_management_layout(true)
    _apply_mobile_progression_copy()
    _apply_mobile_rank3_compaction()


func _process(delta: float) -> void:
    super._process(delta)
    _apply_mobile_management_layout(false)
    _apply_mobile_progression_copy()
    _apply_mobile_rank3_compaction()


func _apply_mobile_management_layout(force: bool) -> void:
    if _sheet == null:
        return

    var viewport_width := get_viewport().get_visible_rect().size.x
    if not force and absf(viewport_width - _mobile_layout_width) < 0.5:
        return
    _mobile_layout_width = viewport_width

    _sheet.anchor_top = MOBILE_SHEET_TOP
    _sheet.offset_left = MOBILE_SHEET_SIDE_MARGIN
    _sheet.offset_right = -MOBILE_SHEET_SIDE_MARGIN
    _sheet.offset_bottom = MOBILE_SHEET_BOTTOM
    _sheet.clip_contents = true
    _sheet.mouse_filter = Control.MOUSE_FILTER_STOP

    _configure_scroll_containers(_sheet)
    _configure_known_mobile_controls()
    _tune_section_spacing(_progression_panel, 12)
    _tune_section_spacing(_rank3_panel, 10)


func _configure_scroll_containers(node: Node) -> void:
    if node is ScrollContainer:
        var scroll := node as ScrollContainer
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
        scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
        scroll.follow_focus = true
        scroll.clip_contents = true
        scroll.scroll_vertical_custom_step = 96.0
        _configure_scroll_content(scroll)
        return

    for child in node.get_children():
        _configure_scroll_containers(child)


func _configure_scroll_content(node: Node) -> void:
    if node is Control:
        var control := node as Control
        control.custom_minimum_size.x = 0.0
        control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    if node is Label:
        var label := node as Label
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.clip_text = false
    elif node is Button:
        var button := node as Button
        button.clip_text = false
        button.mouse_filter = Control.MOUSE_FILTER_PASS
        button.focus_mode = Control.FOCUS_NONE
        if button is not OptionButton:
            button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    for child in node.get_children():
        _configure_scroll_content(child)


func _configure_known_mobile_controls() -> void:
    if _progression_label != null:
        _progression_label.custom_minimum_size = Vector2(0, 44)
    if _contract_status != null:
        _contract_status.custom_minimum_size = Vector2(0, 42)
    for button in _contract_buttons:
        button.custom_minimum_size = Vector2(0, 92)
    if _staffing_label != null:
        _staffing_label.custom_minimum_size = Vector2(0, 38)
    for button in _staffing_buttons.values():
        (button as Button).custom_minimum_size = Vector2(0, 54)
    if _facility_header != null:
        _facility_header.custom_minimum_size = Vector2(0, 32)
    for button in _facility_buttons.values():
        (button as Button).custom_minimum_size = Vector2(0, 82)

    if _rank3_status != null:
        _rank3_status.custom_minimum_size = Vector2(0, 42)
    if _routing_summary != null:
        _routing_summary.custom_minimum_size = Vector2(0, 42)
    if _routing_select != null:
        _routing_select.custom_minimum_size = Vector2(0, 50)
    if _receiving_annex_button != null:
        _receiving_annex_button.custom_minimum_size = Vector2(0, 88)
    if _inbound_carrier_button != null:
        _inbound_carrier_button.custom_minimum_size = Vector2(0, 88)


func _tune_section_spacing(panel: PanelContainer, separation: int) -> void:
    if panel == null or panel.get_child_count() == 0:
        return
    var child := panel.get_child(0)
    if child is VBoxContainer:
        (child as VBoxContainer).add_theme_constant_override("separation", separation)


func _apply_mobile_rank3_compaction() -> void:
    if sim == null or sim.facility_rank < 3:
        return

    # At Rank 3 the three Rank 2 facility choices are historical state, not active decisions.
    # Collapse them so the management sheet prioritizes contracts, staffing and current Rank 3 capital.
    if _facility_header != null:
        _facility_header.visible = true
        _facility_header.text = "拡張設備  3/3 導入済み"
    for zone_label in _facility_zone_labels.values():
        (zone_label as Label).visible = false
    for facility_button in _facility_buttons.values():
        (facility_button as Button).visible = false

    var list := _find_upgrade_list(_sheet)
    if list != null and _rank3_panel != null and _rank3_panel.get_parent() == list:
        list.move_child(_rank3_panel, 0)
        if _progression_panel != null and _progression_panel.get_parent() == list:
            list.move_child(_progression_panel, mini(1, list.get_child_count() - 1))


func _apply_mobile_progression_copy() -> void:
    if sim == null or _progression_label == null:
        return

    if sim.facility_rank >= 3:
        _progression_label.text = "RANK 3  FULFILLMENT CENTER\n評価 %d  ｜ 契約 %d件" % [
            sim.logistics_rating,
            sim.completed_contracts,
        ]
    elif sim.facility_rank >= 2:
        _progression_label.text = "RANK 2  WAREHOUSE\n評価 %d  ｜ 契約 %d件" % [
            sim.logistics_rating,
            sim.completed_contracts,
        ]
    else:
        _progression_label.text = "RANK 1  SMALL DEPOT\n物流評価 %d / 8" % sim.logistics_rating
