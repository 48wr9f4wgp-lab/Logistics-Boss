extends "res://ui/game_hud_release.gd"
class_name MobileGameHud

const MOBILE_SHEET_TOP := 0.26
const MOBILE_SHEET_SIDE_MARGIN := 12.0
const MOBILE_SHEET_BOTTOM := -108.0
const MOBILE_SCROLL_DRAG_THRESHOLD := 6.0
const MOBILE_SCROLL_SPEED := 1.15
const MOBILE_SCROLL_BOTTOM_PADDING := 40.0

var _mobile_layout_width := -1.0
var _mobile_scroll: ScrollContainer
var _mobile_scroll_touch_index := -1
var _mobile_scroll_drag_distance := 0.0
var _mobile_mouse_scroll_active := false
var _mobile_mouse_drag_distance := 0.0


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


func _input(event: InputEvent) -> void:
    if _sheet == null or not _sheet.visible or _mobile_scroll == null:
        _reset_mobile_scroll_gesture()
        return

    var scroll_rect := _mobile_scroll.get_global_rect()

    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if _mobile_scroll_touch_index < 0 and scroll_rect.has_point(touch.position):
                _mobile_scroll_touch_index = touch.index
                _mobile_scroll_drag_distance = 0.0
        elif touch.index == _mobile_scroll_touch_index:
            _mobile_scroll_touch_index = -1
            _mobile_scroll_drag_distance = 0.0
        return

    if event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index != _mobile_scroll_touch_index:
            return
        _mobile_scroll_drag_distance += absf(drag.relative.y)
        if _mobile_scroll_drag_distance >= MOBILE_SCROLL_DRAG_THRESHOLD:
            _scroll_management_by(drag.relative.y)
        return

    # Web exports can present touch as emulated mouse input depending on browser/runtime settings.
    # Keep an independent mouse-drag fallback so the management sheet remains usable on iOS Safari.
    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index != MOUSE_BUTTON_LEFT or _mobile_scroll_touch_index >= 0:
            return
        if mouse_button.pressed:
            _mobile_mouse_scroll_active = scroll_rect.has_point(mouse_button.position)
            _mobile_mouse_drag_distance = 0.0
        else:
            _mobile_mouse_scroll_active = false
            _mobile_mouse_drag_distance = 0.0
        return

    if event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if not _mobile_mouse_scroll_active or _mobile_scroll_touch_index >= 0:
            return
        if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
            _mobile_mouse_scroll_active = false
            _mobile_mouse_drag_distance = 0.0
            return
        _mobile_mouse_drag_distance += absf(motion.relative.y)
        if _mobile_mouse_drag_distance >= MOBILE_SCROLL_DRAG_THRESHOLD:
            _scroll_management_by(motion.relative.y)


func _scroll_management_by(pointer_delta_y: float) -> void:
    if _mobile_scroll == null:
        return
    var next_scroll := _mobile_scroll.scroll_vertical - int(round(pointer_delta_y * MOBILE_SCROLL_SPEED))
    _mobile_scroll.scroll_vertical = maxi(0, next_scroll)


func _reset_mobile_scroll_gesture() -> void:
    _mobile_scroll_touch_index = -1
    _mobile_scroll_drag_distance = 0.0
    _mobile_mouse_scroll_active = false
    _mobile_mouse_drag_distance = 0.0


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

    _mobile_scroll = null
    _configure_scroll_containers(_sheet)
    _configure_known_mobile_controls()
    _tune_section_spacing(_progression_panel, 12)
    _tune_section_spacing(_rank3_panel, 10)
    _ensure_scroll_bottom_padding()


func _configure_scroll_containers(node: Node) -> void:
    if node is ScrollContainer:
        var scroll := node as ScrollContainer
        if _mobile_scroll == null:
            _mobile_scroll = scroll
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
        scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
        scroll.follow_focus = true
        scroll.clip_contents = true
        scroll.scroll_deadzone = int(MOBILE_SCROLL_DRAG_THRESHOLD)
        scroll.scroll_vertical_custom_step = 96.0
        scroll.mouse_filter = Control.MOUSE_FILTER_STOP
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
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
        _routing_select.custom_minimum_size = Vector2(0, 54)
        _routing_select.mouse_filter = Control.MOUSE_FILTER_PASS
    if _receiving_annex_button != null:
        _receiving_annex_button.custom_minimum_size = Vector2(0, 88)
    if _inbound_carrier_button != null:
        _inbound_carrier_button.custom_minimum_size = Vector2(0, 88)


func _ensure_scroll_bottom_padding() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return
    var spacer := list.get_node_or_null("MobileBottomSpacer") as Control
    if spacer == null:
        spacer = Control.new()
        spacer.name = "MobileBottomSpacer"
        spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        list.add_child(spacer)
    spacer.custom_minimum_size = Vector2(0, MOBILE_SCROLL_BOTTOM_PADDING)


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
    # Collapse them so the management sheet prioritizes current Rank 3 capital and live operations.
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
