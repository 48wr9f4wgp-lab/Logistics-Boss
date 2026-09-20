extends "res://ui/game_hud_release.gd"
class_name MobileGameHud

signal zone_navigation_requested(zone_key: String)

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
var _v2_growth_goal: Button
var _v2_overview_panel: PanelContainer
var _v2_overview_label: Label
var _v2_zone_nav_buttons: Dictionary = {}
var _v2_rank1_project_nav_buttons: Dictionary = {}
var _v2_rank1_expansion_panel: PanelContainer
var _v2_rank1_expansion_label: Label
var _v2_rank1_expansion_button: Button
var _v2_staffing_panel: PanelContainer
var _v2_staffing_label: Label


func _ready() -> void:
    super._ready()
    _build_v2_growth_goal()
    _build_v2_management_overview()
    _apply_mobile_management_layout(true)
    _apply_mobile_progression_copy()
    _apply_mobile_rank3_compaction()
    _apply_v2_primary_hud()
    _apply_v2_management_scope()


func _process(delta: float) -> void:
    super._process(delta)
    _apply_mobile_management_layout(false)
    _apply_mobile_progression_copy()
    _apply_mobile_rank3_compaction()
    _apply_v2_primary_hud()
    _apply_v2_management_scope()
    _render_v2_growth_goal()
    _render_v2_management_overview()
    _render_v2_rank1_expansion()
    _render_v2_staffing_overview()


func _input(event: InputEvent) -> void:
    if _reset_modal != null and _reset_modal.visible:
        _reset_mobile_scroll_gesture()
        return

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


func _build_v2_growth_goal() -> void:
    _v2_growth_goal = Button.new()
    _v2_growth_goal.name = "V2GrowthGoal"
    _v2_growth_goal.anchor_left = 0.0
    _v2_growth_goal.anchor_right = 1.0
    _v2_growth_goal.anchor_top = 0.0
    _v2_growth_goal.anchor_bottom = 0.0
    _v2_growth_goal.offset_left = 12.0
    _v2_growth_goal.offset_right = -12.0
    _v2_growth_goal.offset_top = 174.0
    _v2_growth_goal.offset_bottom = 226.0
    _v2_growth_goal.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _v2_growth_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _v2_growth_goal.add_theme_font_override("font", JAPANESE_UI_FONT)
    _v2_growth_goal.add_theme_font_size_override("font_size", 10)
    _v2_growth_goal.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
    _v2_growth_goal.add_theme_stylebox_override(
        "normal",
        _panel_style(Color(0.018, 0.050, 0.068, 0.96), Color(0.30, 0.84, 0.72, 0.92), 12)
    )
    _v2_growth_goal.add_theme_stylebox_override(
        "hover",
        _panel_style(Color(0.025, 0.070, 0.090, 0.98), Color(0.38, 0.94, 0.78, 0.98), 12)
    )
    _v2_growth_goal.add_theme_stylebox_override(
        "pressed",
        _panel_style(Color(0.012, 0.042, 0.058, 0.99), Color(1.0, 0.66, 0.24, 0.98), 12)
    )
    _v2_growth_goal.pressed.connect(_open_growth_management)
    add_child(_v2_growth_goal)
    _render_v2_growth_goal()


func _render_v2_growth_goal() -> void:
    if _v2_growth_goal == null:
        return
    if sim == null or sim.facility_rank != 1:
        _v2_growth_goal.visible = false
        return

    _v2_growth_goal.visible = _sheet == null or not _sheet.visible
    if not _v2_growth_goal.visible:
        return

    var projects := 0
    var projects_required := 4
    var rating := sim.logistics_rating
    var rating_required := LogisticsProgression.RANK2_RATING
    var expansion_cost := 10000
    var ready := false
    if sim.has_method("rank1_expansion_readiness"):
        var readiness: Dictionary = sim.call("rank1_expansion_readiness")
        projects = int(readiness.get("projects", 0))
        projects_required = int(readiness.get("projects_required", 4))
        rating = int(readiness.get("rating", rating))
        rating_required = int(readiness.get("rating_required", rating_required))
        expansion_cost = int(readiness.get("cost", expansion_cost))
        ready = bool(readiness.get("ready", false))

    if ready:
        _v2_growth_goal.text = "NEXT｜RANK 2へ拡張可能 → 経営管理を開く\n設備 %d/%d｜評価 %d/%d｜拡張費 ¥%s" % [
            projects,
            projects_required,
            rating,
            rating_required,
            _format_number(expansion_cost),
        ]
        return

    var objective := (
        "契約を選ぶ → 物流評価を上げる"
        if not sim.contract_offers.is_empty()
        else "次の契約を準備中"
    )
    if not sim.active_contract.is_empty():
        var active: Dictionary = sim.active_contract
        objective = "契約｜%s  %.0f/%.0f  残%d秒" % [
            String(active.get("title", "契約")),
            float(active.get("progress", 0.0)),
            float(active.get("target", 0.0)),
            ceili(float(active.get("remaining", 0.0))),
        ]

    _v2_growth_goal.text = "NEXT｜%s\nRANK 2条件｜設備 %d/%d｜評価 %d/%d｜拡張費 ¥%s" % [
        objective,
        projects,
        projects_required,
        rating,
        rating_required,
        _format_number(expansion_cost),
    ]


func _open_growth_management() -> void:
    if _sheet == null:
        return
    if not _sheet.visible:
        _toggle_sheet()
    if _mobile_scroll != null:
        _mobile_scroll.scroll_vertical = 0
    _apply_v2_management_scope()


func _build_v2_management_overview() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return

    _v2_overview_panel = PanelContainer.new()
    _v2_overview_panel.name = "V2ManagementOverview"
    _v2_overview_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.052, 0.070, 0.985), Color(0.18, 0.72, 0.96, 0.90), 14)
    )
    list.add_child(_v2_overview_panel)
    list.move_child(_v2_overview_panel, 0)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_bottom", 8)
    _v2_overview_panel.add_child(margin)

    var overview_column := VBoxContainer.new()
    overview_column.add_theme_constant_override("separation", 6)
    margin.add_child(overview_column)

    _v2_overview_label = Label.new()
    _v2_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _v2_overview_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _v2_overview_label.add_theme_font_size_override("font_size", 11)
    _v2_overview_label.add_theme_color_override("font_color", Color(0.86, 0.96, 1.0))
    overview_column.add_child(_v2_overview_label)

    var zone_grid := GridContainer.new()
    zone_grid.columns = 3
    zone_grid.add_theme_constant_override("h_separation", 6)
    zone_grid.add_theme_constant_override("v_separation", 6)
    overview_column.add_child(zone_grid)

    for zone_key in ["inbound", "storage", "picking", "packing", "shipping"]:
        var zone_button := Button.new()
        zone_button.custom_minimum_size = Vector2(0, 44)
        zone_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        zone_button.add_theme_font_override("font", JAPANESE_UI_FONT)
        zone_button.add_theme_font_size_override("font_size", 8)
        zone_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        zone_button.pressed.connect(_request_zone_from_management.bind(zone_key))
        zone_grid.add_child(zone_button)
        _v2_zone_nav_buttons[zone_key] = zone_button

    _v2_rank1_expansion_panel = PanelContainer.new()
    _v2_rank1_expansion_panel.name = "V2Rank1Expansion"
    _v2_rank1_expansion_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.020, 0.058, 0.075, 0.985), Color(1.0, 0.62, 0.22, 0.92), 14)
    )
    list.add_child(_v2_rank1_expansion_panel)
    list.move_child(_v2_rank1_expansion_panel, mini(1, list.get_child_count() - 1))

    var expansion_margin := MarginContainer.new()
    expansion_margin.add_theme_constant_override("margin_left", 10)
    expansion_margin.add_theme_constant_override("margin_right", 10)
    expansion_margin.add_theme_constant_override("margin_top", 8)
    expansion_margin.add_theme_constant_override("margin_bottom", 8)
    _v2_rank1_expansion_panel.add_child(expansion_margin)

    var expansion_column := VBoxContainer.new()
    expansion_column.add_theme_constant_override("separation", 6)
    expansion_margin.add_child(expansion_column)

    _v2_rank1_expansion_label = Label.new()
    _v2_rank1_expansion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _v2_rank1_expansion_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _v2_rank1_expansion_label.add_theme_font_size_override("font_size", 11)
    _v2_rank1_expansion_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.64))
    expansion_column.add_child(_v2_rank1_expansion_label)

    var project_hint := Label.new()
    project_hint.text = "未完了Project → 該当Zoneを開く"
    project_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    project_hint.add_theme_font_override("font", JAPANESE_UI_FONT)
    project_hint.add_theme_font_size_override("font_size", 9)
    project_hint.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
    expansion_column.add_child(project_hint)

    var project_grid := GridContainer.new()
    project_grid.columns = 2
    project_grid.add_theme_constant_override("h_separation", 6)
    project_grid.add_theme_constant_override("v_separation", 6)
    expansion_column.add_child(project_grid)

    for project_kind in ["rack_wing", "second_packing_bench", "worker_hire", "forklift_project"]:
        var project_button := Button.new()
        project_button.custom_minimum_size = Vector2(0, 38)
        project_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        project_button.add_theme_font_override("font", JAPANESE_UI_FONT)
        project_button.add_theme_font_size_override("font_size", 8)
        project_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        project_button.pressed.connect(_request_rank1_project_zone.bind(project_kind))
        project_grid.add_child(project_button)
        _v2_rank1_project_nav_buttons[project_kind] = project_button

    _v2_rank1_expansion_button = Button.new()
    _v2_rank1_expansion_button.custom_minimum_size = Vector2(0, 48)
    _v2_rank1_expansion_button.add_theme_font_override("font", JAPANESE_UI_FONT)
    _v2_rank1_expansion_button.add_theme_font_size_override("font_size", 9)
    _v2_rank1_expansion_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _v2_rank1_expansion_button.pressed.connect(_purchase_v2_warehouse_expansion)
    expansion_column.add_child(_v2_rank1_expansion_button)

    _v2_staffing_panel = PanelContainer.new()
    _v2_staffing_panel.name = "V2StaffingOverview"
    _v2_staffing_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.052, 0.070, 0.985), Color(0.28, 0.86, 0.72, 0.90), 14)
    )
    list.add_child(_v2_staffing_panel)

    var staffing_margin := MarginContainer.new()
    staffing_margin.add_theme_constant_override("margin_left", 10)
    staffing_margin.add_theme_constant_override("margin_right", 10)
    staffing_margin.add_theme_constant_override("margin_top", 8)
    staffing_margin.add_theme_constant_override("margin_bottom", 8)
    _v2_staffing_panel.add_child(staffing_margin)

    _v2_staffing_label = Label.new()
    _v2_staffing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _v2_staffing_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _v2_staffing_label.add_theme_font_size_override("font_size", 11)
    _v2_staffing_label.add_theme_color_override("font_color", Color(0.82, 1.0, 0.92))
    staffing_margin.add_child(_v2_staffing_label)

    _render_v2_management_overview()
    _render_v2_rank1_expansion()


func _render_v2_management_overview() -> void:
    if _v2_overview_label == null or sim == null:
        return
    _v2_overview_label.text = "OVERVIEW｜Zoneをタップして現場を開く"

    for zone_key in _v2_zone_nav_buttons:
        var button := _v2_zone_nav_buttons[zone_key] as Button
        if button == null:
            continue
        var status := _v2_zone_status(String(zone_key))
        button.text = "%s｜%s\nタップして確認" % [
            _v2_zone_short_label(String(zone_key)),
            status,
        ]


func _render_v2_rank1_expansion() -> void:
    if _v2_rank1_expansion_panel == null or _v2_rank1_expansion_label == null or _v2_rank1_expansion_button == null:
        return
    if sim == null or sim.facility_rank != 1 or not sim.has_method("rank1_expansion_readiness"):
        _v2_rank1_expansion_panel.visible = false
        return

    _v2_rank1_expansion_panel.visible = true
    var readiness: Dictionary = sim.call("rank1_expansion_readiness")
    var projects := int(readiness.get("projects", 0))
    var projects_required := int(readiness.get("projects_required", 4))
    var rating := int(readiness.get("rating", 0))
    var rating_required := int(readiness.get("rating_required", 8))
    var cost := int(readiness.get("cost", 0))

    _v2_rank1_expansion_label.text = "WAREHOUSE EXPANSION\n設備Project %d/%d｜物流評価 %d/%d\n物流評価は契約達成で上昇｜Small Depot → RANK 2" % [
        projects,
        projects_required,
        rating,
        rating_required,
    ]

    var ready_except_funds := bool(readiness.get("projects_ready", false)) and bool(readiness.get("rating_ready", false))
    _v2_rank1_expansion_button.disabled = not ready_except_funds or sim.money < cost
    if not bool(readiness.get("projects_ready", false)):
        _v2_rank1_expansion_button.text = "拡張条件未達｜下の未完了Projectを先に実施"
    elif not bool(readiness.get("rating_ready", false)):
        _v2_rank1_expansion_button.text = "拡張条件未達｜物流評価 %d/%d" % [rating, rating_required]
    elif sim.money < cost:
        _v2_rank1_expansion_button.text = "資金不足｜Warehouse拡張 ¥%s" % _format_number(cost)
    else:
        _v2_rank1_expansion_button.text = "Warehouseへ拡張｜¥%s" % _format_number(cost)

    _render_rank1_project_navigation()


func _render_rank1_project_navigation() -> void:
    if sim == null:
        return
    for project_kind in _v2_rank1_project_nav_buttons:
        var button := _v2_rank1_project_nav_buttons[project_kind] as Button
        if button == null:
            continue
        var info: Dictionary = sim.call("rank1_project_info", StringName(project_kind)) if sim.has_method("rank1_project_info") else {}
        var owned := bool(info.get("owned", false))
        var label := String(info.get("label", project_kind))
        var zone_key := _rank1_project_navigation_zone(String(project_kind))
        button.visible = sim.facility_rank == 1
        button.disabled = owned
        button.text = (
            "✓ %s\n完了" % label
            if owned
            else "%s\n→ %s" % [label, _v2_zone_short_label(zone_key)]
        )


func _rank1_project_navigation_zone(project_kind: String) -> String:
    match project_kind:
        "rack_wing":
            return "storage"
        "second_packing_bench":
            return "packing"
        "forklift_project":
            return "inbound"
        "worker_hire":
            return _current_problem_zone()
    return "inbound"


func _request_rank1_project_zone(project_kind: String) -> void:
    _request_zone_from_management(_rank1_project_navigation_zone(project_kind))


func _request_zone_from_management(zone_key: String) -> void:
    if zone_key.is_empty():
        return
    if _sheet != null:
        _sheet.visible = false
    if _manage_button != null:
        _manage_button.text = "経営管理"
    zone_navigation_requested.emit(zone_key)


func _current_problem_zone() -> String:
    if sim == null:
        return "inbound"
    var info: Dictionary = sim.bottleneck()
    match String(info.get("key", "stable")):
        "inbound":
            return "inbound"
        "rack":
            return "storage"
        "packing":
            return "packing"
        "outbound":
            return "shipping"
        "orders":
            return "picking"
    return "inbound"


func _v2_zone_short_label(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "INBOUND"
        "storage":
            return "STORAGE"
        "picking":
            return "PICKING"
        "packing":
            return "PACKING"
        "shipping":
            return "SHIPPING"
    return zone_key.to_upper()


func _purchase_v2_warehouse_expansion() -> void:
    if sim == null or not sim.has_method("purchase_warehouse_expansion"):
        return
    var result: Dictionary = sim.call("purchase_warehouse_expansion")
    if bool(result.get("ok", false)):
        _show_toast("WAREHOUSE EXPANSION  RANK 2")
        _sheet.visible = false
    else:
        match String(result.get("reason", "")):
            "projects":
                _show_toast("設備Projectが未完了")
            "rating":
                _show_toast("物流評価が不足")
            "funds":
                _show_toast("資金不足  ¥%s必要" % _format_number(int(result.get("cost", 0))))
            _:
                _show_toast("Warehouse Expansionを実行できない")
    _render_v2_rank1_expansion()


func _render_v2_staffing_overview() -> void:
    if _v2_staffing_panel == null or _v2_staffing_label == null:
        return
    if sim == null or sim.facility_rank < 2 or not sim.has_method("direct_staffing_summary"):
        _v2_staffing_panel.visible = false
        return

    var summary: Dictionary = sim.call("direct_staffing_summary")
    if not bool(summary.get("enabled", false)):
        _v2_staffing_panel.visible = false
        return

    _v2_staffing_panel.visible = true
    var cooldown := float(summary.get("cooldown", 0.0))
    var lock_text := "変更可" if cooldown <= 0.0 else "観察中 %d秒" % int(ceil(cooldown))
    _v2_staffing_label.text = "STAFFING｜現在配置\nRECEIVING/STORAGE %d人｜PICKING %d人｜SHIPPING %d人\n%s｜変更は各ZoneのOPERATIONSから" % [
        int(summary.get("inbound", 0)),
        int(summary.get("picking", 0)),
        int(summary.get("shipping", 0)),
        lock_text,
    ]


func _v2_zone_status(zone_key: String) -> String:
    match zone_key:
        "inbound":
            return "混雑" if sim.inbound_queue >= 8 else ("高負荷" if sim.inbound_queue >= 4 else "正常")
        "storage":
            var fill := float(sim.rack_stock) / float(maxi(1, sim.rack_capacity))
            return "混雑" if fill >= 0.95 else ("高負荷" if fill >= 0.70 else "正常")
        "picking":
            return "混雑" if sim.open_orders >= 10 else ("高負荷" if sim.open_orders >= 6 else "正常")
        "packing":
            return "混雑" if sim.packing_queue >= 8 else ("高負荷" if sim.packing_queue >= 3 else "正常")
        "shipping":
            return "混雑" if sim.packed_queue >= 8 else ("高負荷" if sim.packed_queue >= 4 else "正常")
    return "正常"


func _apply_v2_primary_hud() -> void:
    # RP currently has no clear v2 player decision attached to it, so do not
    # spend permanent portrait HUD space on it.
    if _rp != null:
        var metric_box := _rp.get_parent()
        if metric_box != null and metric_box.get_parent() is PanelContainer:
            (metric_box.get_parent() as PanelContainer).visible = false

    # Legacy BALANCED / INBOUND / SHIP policy only affects Rank 1 dynamic
    # task choice. Rank 2+ uses direct Zone staffing, so showing these controls
    # there would advertise an action that no longer changes authoritative work.
    # Keep the compatibility API, but hide the controls on the v2 player path.
    if _flow_button != null:
        _flow_button.visible = false
    if _inbound_button != null:
        _inbound_button.visible = false
    if _outbound_button != null:
        _outbound_button.visible = false

    if _manage_button != null:
        _manage_button.text = "閉じる" if _sheet != null and _sheet.visible else "経営管理"

    # The old FTUE teaches Management-first purchasing, which is explicitly
    # superseded by the v2 Zone-first loop.
    if _ftue_coach != null:
        _ftue_coach.visible = false


func _apply_v2_management_scope() -> void:
    # Production mobile path: Management is an executive dashboard. Keep the
    # legacy Domain/buttons alive underneath for regression safety, but remove
    # them from the player-facing purchase surface.
    if _management_title != null:
        _management_title.text = "経営管理"
    if _management_hint != null:
        _management_hint.text = "Zoneをタップ → 現場。設備はZoneのCAPITAL。"

    for button in _upgrade_buttons.values():
        (button as Button).visible = false

    if _facility_header != null:
        _facility_header.visible = false
    for zone_label in _facility_zone_labels.values():
        (zone_label as Label).visible = false
    for facility_button in _facility_buttons.values():
        (facility_button as Button).visible = false

    if _staffing_label != null:
        _staffing_label.visible = false
    if _staffing_grid != null:
        _staffing_grid.visible = false

    if _v2_overview_panel != null:
        _v2_overview_panel.visible = true
        var list := _find_upgrade_list(_sheet)
        if list != null:
            if sim != null and sim.facility_rank == 1:
                if _progression_panel != null and _progression_panel.get_parent() == list:
                    list.move_child(_progression_panel, 0)
                if _v2_overview_panel.get_parent() == list:
                    list.move_child(_v2_overview_panel, mini(1, list.get_child_count() - 1))
                if (
                    _v2_rank1_expansion_panel != null
                    and _v2_rank1_expansion_panel.get_parent() == list
                ):
                    list.move_child(_v2_rank1_expansion_panel, mini(2, list.get_child_count() - 1))
            elif _v2_overview_panel.get_parent() == list:
                list.move_child(_v2_overview_panel, 0)

    _replace_v2_management_copy(_sheet)


func _replace_v2_management_copy(node: Node) -> void:
    if node == null:
        return
    if node is Label:
        var label := node as Label
        if label.text == "事業投資":
            label.text = "経営管理"
        elif label.text.contains("詰まりを見て"):
            label.text = "Zoneをタップ → 現場。設備はZoneのCAPITAL。"
    for child in node.get_children():
        _replace_v2_management_copy(child)
