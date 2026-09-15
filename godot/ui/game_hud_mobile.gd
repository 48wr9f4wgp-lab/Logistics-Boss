extends "res://ui/game_hud_release.gd"
class_name MobileGameHud

const MOBILE_SHEET_TOP := 0.33
const MOBILE_SHEET_SIDE_MARGIN := 12.0
const MOBILE_SHEET_BOTTOM := -108.0
const MOBILE_CONTENT_SIDE_BUDGET := 86.0

var _mobile_layout_width := -1.0


func _ready() -> void:
    super._ready()
    _apply_mobile_management_layout(true)
    _apply_mobile_progression_copy()


func _process(delta: float) -> void:
    super._process(delta)
    _apply_mobile_management_layout(false)
    _apply_mobile_progression_copy()


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

    var content_width := maxf(220.0, viewport_width - MOBILE_CONTENT_SIDE_BUDGET)
    _configure_scroll_containers(_sheet, content_width)

    if _progression_label != null:
        _progression_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _progression_label.custom_minimum_size.x = 0.0
        _progression_label.custom_maximum_size = Vector2(content_width, 0.0)


func _configure_scroll_containers(node: Node, content_width: float) -> void:
    if node is ScrollContainer:
        var scroll := node as ScrollContainer
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
        scroll.scroll_hint_mode = ScrollContainer.SCROLL_HINT_MODE_ALL
        scroll.follow_focus = true
        scroll.clip_contents = true
        scroll.scroll_vertical_custom_step = 84.0
        _configure_scroll_content(scroll, content_width)
        return

    for child in node.get_children():
        _configure_scroll_containers(child, content_width)


func _configure_scroll_content(node: Node, content_width: float) -> void:
    if node is Control:
        var control := node as Control
        control.custom_minimum_size.x = 0.0
        control.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    if node is Label:
        var label := node as Label
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.clip_text = true
        label.custom_maximum_size = Vector2(content_width, 0.0)
    elif node is Button:
        var button := node as Button
        button.clip_text = true
        button.mouse_filter = Control.MOUSE_FILTER_PASS
        button.focus_mode = Control.FOCUS_NONE
        button.custom_maximum_size = Vector2(content_width, 0.0)
        if button is not OptionButton:
            button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    for child in node.get_children():
        _configure_scroll_content(child, content_width)


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
