extends Node
class_name MobileInteractionClarity

# Presentation adapter for existing v2 surfaces, explicitly composed in main.
# Domain rules/handlers are unchanged; this is not another HUD subclass.
const RouterScript := preload("res://ui/mobile_ui_gesture_router.gd")
const FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")
const ZONES := {"inbound": "入荷", "storage": "保管", "picking": "ピッキング", "packing": "梱包", "shipping": "出荷"}
const PROJECTS := {"rack_wing": "棚の増設", "second_packing_bench": "梱包台の増設", "worker_hire": "作業員を1人採用", "forklift_project": "フォークリフト"}

var hud: MobileGameHud
var zone: WarehouseZonePanel
var router: MobileUiGestureRouter
var coach: V2Rank1Coach
var resume_brief: Control
var _section := "contracts"
var _goal_section := "contracts"
var _tabs: Dictionary = {}
var _descriptions: Array[Label] = []
var _settings_labels: Array[Label] = []
var _normal: StyleBoxFlat
var _primary: StyleBoxFlat
var _pressed: StyleBoxFlat
var _disabled: StyleBoxFlat


func bind(next_hud: MobileGameHud, next_zone: WarehouseZonePanel, next_coach: V2Rank1Coach = null, next_resume: Control = null) -> void:
    hud = next_hud
    zone = next_zone
    coach = next_coach
    resume_brief = next_resume
    process_priority = 100
    # Runtime binding avoids project-theme font loading before a clean checkout
    # has imported its TTF. The theme also covers UI attached after this bind.
    hud.theme = load("res://ui/mobile_theme.tres") as Theme
    _normal = _style(Color(0.045, 0.12, 0.16), Color(0.28, 0.67, 0.82))
    _primary = _style(Color(0.055, 0.29, 0.25), Color(0.44, 0.95, 0.77))
    _pressed = _style(Color(0.32, 0.22, 0.075), Color(1.0, 0.76, 0.32))
    _disabled = _style(Color(0.035, 0.06, 0.075), Color(0.24, 0.32, 0.36))
    _build_sections()
    _separate_contract_actions()
    _style_buttons(hud)
    hud._apply_mobile_font_tree(hud)
    var goal := hud._v2_growth_goal
    if goal.pressed.is_connected(hud._open_growth_management):
        goal.pressed.disconnect(hud._open_growth_management)
    goal.pressed.connect(_open_goal)
    goal.offset_top = 196.0
    goal.offset_bottom = 264.0
    goal.add_theme_font_size_override("font_size", 13)
    goal.add_theme_stylebox_override("normal", _primary)
    if coach != null:
        coach.offset_top = 128.0
        coach.offset_bottom = 190.0
    router = RouterScript.new()
    add_child(router)
    router.bind(hud, zone)
    router.action_activated.connect(_after_action)
    refresh()


func _process(_delta: float) -> void:
    if hud != null and hud.sim != null:
        refresh()


func _build_sections() -> void:
    var scroll := hud._mobile_scroll
    var column := scroll.get_parent() as VBoxContainer
    var row := HBoxContainer.new()
    row.name = "ManagementSections"
    row.add_theme_constant_override("separation", 5)
    column.add_child(row)
    column.move_child(row, scroll.get_index())
    for item in [["contracts", "契約"], ["field", "現場"], ["expansion", "拡張"], ["settings", "設定"]]:
        var button := Button.new()
        button.text = String(item[1])
        button.custom_minimum_size = Vector2(0, 44)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.set_meta("section_title", String(item[1]))
        button.pressed.connect(_select_section.bind(String(item[0])))
        row.add_child(button)
        _tabs[String(item[0])] = button
    var list := hud._find_upgrade_list(hud._sheet)
    for child in list.get_children():
        if child is Label and (child as Label).text.contains("データ管理"):
            _settings_labels.append(child as Label)


func _separate_contract_actions() -> void:
    for button in hud._contract_buttons:
        var description := Label.new()
        description.name = "ContractDescription%d" % _descriptions.size()
        description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        description.mouse_filter = Control.MOUSE_FILTER_IGNORE
        description.add_theme_font_override("font", FONT)
        description.add_theme_font_size_override("font_size", 12)
        description.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
        var parent := button.get_parent()
        parent.add_child(description)
        parent.move_child(description, button.get_index())
        _descriptions.append(description)
        button.custom_minimum_size = Vector2(0, 44)
        button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func refresh() -> void:
    if hud == null or hud.sim == null:
        return
    var sim := hud.sim
    var rank := sim.facility_rank
    var sheet_open := hud._sheet.visible
    if sheet_open and zone != null and zone.is_open():
        zone.close()
    hud._management_hint.visible = false
    hud._management_title.text = "経営管理"
    hud._manage_button.text = "倉庫に戻る" if sheet_open else "経営管理"
    hud._mobile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    hud._progression_panel.visible = _section == "contracts"
    hud._v2_overview_panel.visible = _section == "field"
    hud._v2_rank1_expansion_panel.visible = _section == "expansion" and rank == 1
    hud._v2_staffing_panel.visible = _section == "field" and rank >= 2
    hud._rank3_panel.visible = _section == "expansion" and rank >= 3
    hud._reset_button.visible = _section == "settings"
    for label in _settings_labels:
        label.visible = _section == "settings"
    for key in _tabs:
        var button := _tabs[key] as Button
        var title := String(button.get_meta("section_title"))
        button.text = "【%s】" % title if key == _section else title
        button.add_theme_stylebox_override("normal", _primary if key == _section else _normal)
    (_tabs["expansion"] as Button).visible = rank != 2
    if rank == 2 and _section == "expansion":
        _select_section("field")
    _render_contracts()
    _render_goal()
    _render_field()
    _render_zone()
    _render_coach()
    if router != null:
        router.apply_pressed_visual()


func _render_contracts() -> void:
    var sim := hud.sim
    var active := not sim.active_contract.is_empty()
    if active:
        var contract: Dictionary = sim.active_contract
        hud._contract_status.text = "進行中：%s\n達成 %.0f / %.0f｜残り%d秒\n倉庫の流れを見ながら進めよう。" % [
            String(contract.get("title", "契約")), float(contract.get("progress", 0.0)),
            float(contract.get("target", 0.0)), ceili(float(contract.get("remaining", 0.0))) ]
    else:
        hud._contract_status.text = "達成条件を見て、引き受ける契約を1つ選ぼう。"
    for index in hud._contract_buttons.size():
        var button := hud._contract_buttons[index]
        var available := not active and index < sim.contract_offers.size()
        button.visible = available
        _descriptions[index].visible = available
        if not available:
            continue
        var offer: Dictionary = sim.contract_offers[index]
        _descriptions[index].text = "%s\n%s\n報酬 ¥%s｜物流評価 +%d" % [
            String(offer.get("title", "契約")), String(offer.get("description", "")),
            hud._format_number(int(offer.get("reward_cash", 0))), int(offer.get("reward_rating", 0)) ]
        button.text = "この契約を開始 ▶"
        button.custom_minimum_size.y = 44.0
        button.add_theme_stylebox_override("normal", _primary)


func _render_goal() -> void:
    var sim := hud.sim
    var goal := hud._v2_growth_goal
    goal.visible = sim.facility_rank == 1 and not hud._sheet.visible and not hud._reset_modal.visible
    if sim.facility_rank != 1:
        return
    var readiness: Dictionary = sim.call("rank1_expansion_readiness")
    var projects_left := maxi(0, int(readiness.get("projects_required", 4)) - int(readiness.get("projects", 0)))
    var rating_left := maxi(0, int(readiness.get("rating_required", 8)) - sim.logistics_rating)
    _goal_section = "contracts"
    if bool(readiness.get("ready", false)):
        _goal_section = "expansion"
        goal.text = "倉庫の拡張を確認する ▶\n条件達成！ 拡張費 ¥%s" % hud._format_number(int(readiness.get("cost", 10000)))
    elif not sim.active_contract.is_empty():
        var active: Dictionary = sim.active_contract
        goal.text = "進行中：%s ▶\n達成 %.0f / %.0f｜残り%d秒" % [
            String(active.get("title", "契約")), float(active.get("progress", 0.0)),
            float(active.get("target", 0.0)), ceili(float(active.get("remaining", 0.0))) ]
    elif rating_left > 0:
        goal.text = "契約を選ぶ ▶\n%s" % (
            "設備はすべて導入済み。拡張まであと評価%d" % rating_left if projects_left == 0
            else "契約で評価を上げ、倉庫を大きくしよう。")
    elif projects_left > 0:
        _goal_section = "field"
        goal.text = "現場・設備を確認する ▶\n拡張まで、未導入の設備があと%d件" % projects_left
    else:
        _goal_section = "expansion"
        goal.text = "倉庫の拡張条件を見る ▶\n設備・評価は達成。拡張費を確認しよう。"
    var status := "未導入設備 あと%d件｜評価 %d/%d" % [projects_left, sim.logistics_rating, int(readiness.get("rating_required", 8))]
    if projects_left == 0:
        status = "設備はすべて導入済み ✓\n拡張まであと物流評価 %d" % rating_left
    if bool(readiness.get("ready", false)):
        status = "設備・物流評価の条件を達成 ✓"
    hud._v2_rank1_expansion_label.text = "倉庫を大きくする\n%s\n拡張費 ¥%s" % [status, hud._format_number(int(readiness.get("cost", 10000)))]
    if bool(readiness.get("ready", false)):
        hud._v2_rank1_expansion_button.text = "倉庫を拡張する｜¥%s" % hud._format_number(int(readiness.get("cost", 10000)))
    goal.add_theme_stylebox_override("normal", _primary)


func _render_field() -> void:
    hud._v2_overview_label.text = "現場を見る → 設備の内容を確認 → 建設"
    for key in hud._v2_zone_nav_buttons:
        var button := hud._v2_zone_nav_buttons[key] as Button
        button.text = "%sを見る ▶\n%s" % [String(ZONES.get(key, key)), hud._v2_zone_status(String(key))]
        button.add_theme_font_size_override("font_size", 11)
        button.custom_minimum_size.y = 48.0
    for key in hud._v2_rank1_project_nav_buttons:
        var button := hud._v2_rank1_project_nav_buttons[key] as Button
        var info: Dictionary = hud.sim.call("rank1_project_info", StringName(key))
        button.text = "%s\n%s" % [String(PROJECTS.get(key, key)), "導入済み ✓" if bool(info.get("owned", false)) else "現場で内容を見る ▶"]
        button.custom_minimum_size.y = 48.0
        button.add_theme_font_size_override("font_size", 10)


func _render_zone() -> void:
    if zone == null or not zone.is_open() or hud.sim.facility_rank != 1:
        return
    var sim := hud.sim
    var worker: Dictionary = sim.call("rank1_project_info", &"worker_hire")
    if bool(worker.get("owned", false)):
        zone._operations_action.visible = false
        zone._operations.text = zone._operations.text.replace("全Worker", "作業員")
        if not zone._operations.text.ends_with("増員済み ✓"):
            zone._operations.text += "\n増員済み ✓"
    else:
        zone._operations_action.text = "作業員を1人採用\n¥%s" % hud._format_number(int(worker.get("cost", 0)))
    var kind := StringName(sim.call("rank1_project_for_zone", zone.selected_zone()))
    if kind == &"":
        zone._capital.text = "この現場の追加設備は現在ありません。"
        return
    var info: Dictionary = sim.call("rank1_project_info", kind)
    var title := String(PROJECTS.get(String(kind), info.get("label", "設備")))
    if bool(info.get("owned", false)):
        zone._capital_action.visible = false
        zone._capital.text = "%s\n導入済み ✓\n追加設備は倉庫拡張後に解放" % title
        return
    zone._capital.text = "配置を確認してから建設できます。"
    var cost := int(info.get("cost", 0))
    if sim.money < cost:
        zone._capital.text = "資金不足｜¥%s必要" % hud._format_number(cost)
    zone._capital_action.text = "%s\n%s｜¥%s" % [
        "この設備を建設する" if zone.preview_kind() == kind else "配置を確認する ▶",
        title, hud._format_number(cost) ]


func _render_coach() -> void:
    if coach == null or not coach.visible:
        return
    var texts := {
        "observe": "荷物の流れを見て、滞留している現場を探そう。",
        "inspect": "倉庫の「タップ」を押して、現場の状態を確認。",
        "act": "設備の配置を確認してから建設。最初のタップでは購入しません。",
        "measure": "建設後の倉庫を見よう。25秒後に効果を表示。",
        "complete": "流れがどう変わった？ 次の現場も確認してみよう。" }
    coach._body_label.text = String(texts.get(coach.current_step_key(), coach.body_text()))


func _open_goal() -> void:
    open_section(_goal_section)


func open_section(section: String) -> void:
    if zone != null:
        zone.close()
    if not hud._sheet.visible:
        hud._toggle_sheet()
    _select_section(section)


func _select_section(section: String) -> void:
    if not _tabs.has(section):
        return
    _section = section
    hud._mobile_scroll.scroll_vertical = 0
    refresh()


func _after_action(button: Button) -> void:
    if button in hud._contract_buttons and not hud.sim.active_contract.is_empty():
        hud._sheet.visible = false
    refresh()


func _style_buttons(node: Node) -> void:
    # Keep the reset dialog's destructive-action styling and confirmation UX.
    if node == hud._reset_modal or node == hud._reset_button:
        return
    if node is Button:
        var button := node as Button
        button.add_theme_font_override("font", FONT)
        button.add_theme_font_size_override("font_size", 12)
        button.add_theme_stylebox_override("normal", _normal)
        button.add_theme_stylebox_override("hover", _normal)
        button.add_theme_stylebox_override("pressed", _pressed)
        button.add_theme_stylebox_override("disabled", _disabled)
        button.add_theme_color_override("font_color", Color(0.94, 0.99, 1.0))
        button.add_theme_color_override("font_disabled_color", Color(0.67, 0.74, 0.77))
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.focus_mode = Control.FOCUS_NONE
    if node is Label:
        var label := node as Label
        if label.text == "OPERATIONS":
            label.text = "人員・運用"
        elif label.text == "CAPITAL":
            label.text = "設備の建設"
    for child in node.get_children():
        _style_buttons(child)


func _style(background: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style
