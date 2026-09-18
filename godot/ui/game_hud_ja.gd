extends "res://ui/game_hud.gd"
class_name JapaneseGameHud

const JAPANESE_UI_FONT := preload("res://assets/fonts/MPLUS1p-Regular.ttf")

var _measurement_panel: PanelContainer
var _measurement_label: Label
var _measurement_timer := 0.0
var _progression_panel: PanelContainer
var _progression_label: Label
var _contract_status: Label
var _contract_buttons: Array[Button] = []
var _staffing_label: Label
var _staffing_grid: GridContainer
var _staffing_buttons: Dictionary = {}
var _facility_header: Label
var _facility_zone_labels: Dictionary = {}
var _facility_buttons: Dictionary = {}
var _reset_button: Button
var _reset_modal: Control
var _reset_modal_panel: PanelContainer
var _reset_cancel_button: Button
var _reset_confirm_button: Button


func _ready() -> void:
    super._ready()
    _append_forklift_upgrade()
    _build_progression_section()
    _build_reset_control()
    _build_measurement_banner()
    _tune_mobile_hud()
    _apply_japanese_font_recursive(self)
    _replace_static_copy_recursive(self)
    _render_progression()


func _process(delta: float) -> void:
    super._process(delta)
    _sync_transient_overlay_positions()
    _render_progression()
    if _measurement_timer > 0.0:
        _measurement_timer -= delta
        if _measurement_timer <= 0.0 and _measurement_panel != null:
            _measurement_panel.visible = false


func _copy(jp: String, _en: String) -> String:
    return jp


func _bottleneck_text(info: Dictionary) -> String:
    match String(info.get("key", "stable")):
        "inbound":
            return "搬入口が混雑"
        "rack":
            return "棚がほぼ満杯"
        "packing":
            return "梱包が詰まり"
        "outbound":
            return "出荷待ちが滞留"
        "orders":
            return "注文が滞留"
        "stable":
            return "安定運転"
        _:
            var label := String(info.get("label", ""))
            return label if not label.is_empty() else "安定運転"


func _is_maxed(kind: StringName) -> bool:
    if kind == &"forklift":
        return sim != null and sim.forklift_unlocked
    return super._is_maxed(kind)


func _on_sim_event(event: Dictionary) -> void:
    super._on_sim_event(event)
    match String(event.get("type", "")):
        "upgrade_purchased":
            _show_measurement_status("投資効果を計測中\n前25秒 → 後25秒", 30.0)
        "facility_purchased":
            _show_measurement_status("拡張効果を計測中\n前25秒 → 後25秒", 30.0)
            _show_toast("ZONE %s  %s" % [
                String(event.get("zone", "")),
                String(event.get("label", "拡張完了")),
            ])
        "measurement_completed":
            var before: Dictionary = event.get("before", {})
            var after: Dictionary = event.get("after", {})
            var text := "投資効果  出荷 %.1f→%.1f/分\n入庫 %.1f→%.1f  梱包 %.1f→%.1f" % [
                float(before.get("shipments_per_min", 0.0)),
                float(after.get("shipments_per_min", 0.0)),
                float(before.get("inbound_queue", 0.0)),
                float(after.get("inbound_queue", 0.0)),
                float(before.get("packing_queue", 0.0)),
                float(after.get("packing_queue", 0.0)),
            ]
            _show_measurement_status(text, 8.0)
        "contract_completed":
            _show_toast("契約達成  +¥%s / 評価+%d" % [
                _format_number(int(event.get("cash", 0))),
                int(event.get("rating", 0)),
            ])
        "contract_failed":
            _show_toast("契約失敗  %s" % String(event.get("title", "")))
        "rank_up":
            _show_toast("RANK 2  WAREHOUSE 解禁")
            _toast_timer = 4.0
        "staffing_changed":
            _show_toast("人員配置  %s" % String(event.get("label", "")))


func _append_forklift_upgrade() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return

    var button := Button.new()
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.custom_minimum_size = Vector2(0, 78)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 14)
    button.set_meta("title", "フォークリフト自動化")
    button.set_meta("effect", "入庫→棚を自動搬送 / 作業員を他工程へ解放")
    _apply_button_style(button, false)
    button.pressed.connect(func(): _buy(&"forklift"))
    list.add_child(button)
    _upgrade_buttons[&"forklift"] = button


func _build_progression_section() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return

    _progression_panel = PanelContainer.new()
    _progression_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.020, 0.058, 0.075, 0.985), Color(0.22, 0.62, 0.78, 0.92), 14)
    )
    list.add_child(_progression_panel)
    list.move_child(_progression_panel, 0)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 8)
    _progression_panel.add_child(column)

    _progression_label = Label.new()
    _progression_label.add_theme_font_size_override("font_size", 14)
    _progression_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
    column.add_child(_progression_label)

    _contract_status = Label.new()
    _contract_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _contract_status.add_theme_font_size_override("font_size", 11)
    _contract_status.add_theme_color_override("font_color", Color(0.62, 0.76, 0.83))
    column.add_child(_contract_status)

    for index in 3:
        var contract_button := Button.new()
        contract_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        contract_button.custom_minimum_size = Vector2(0, 62)
        contract_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        contract_button.add_theme_font_size_override("font_size", 12)
        _apply_button_style(contract_button, false)
        contract_button.pressed.connect(_choose_contract_slot.bind(index))
        column.add_child(contract_button)
        _contract_buttons.append(contract_button)

    _staffing_label = Label.new()
    _staffing_label.add_theme_font_size_override("font_size", 12)
    _staffing_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.82))
    _staffing_label.visible = false
    column.add_child(_staffing_label)

    _staffing_grid = GridContainer.new()
    _staffing_grid.columns = 2
    _staffing_grid.add_theme_constant_override("h_separation", 6)
    _staffing_grid.add_theme_constant_override("v_separation", 6)
    _staffing_grid.visible = false
    column.add_child(_staffing_grid)

    var plans := [
        ["receiving", "受入強化 3/1/1"],
        ["balanced", "均衡 2/2/1"],
        ["picking", "ピック強化 1/3/1"],
        ["dock", "両端強化 2/1/2"],
        ["shipping", "出荷強化 1/2/2"],
    ]
    for entry in plans:
        var plan := String(entry[0])
        var button := Button.new()
        button.text = String(entry[1])
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size = Vector2(0, 48)
        button.add_theme_font_size_override("font_size", 10)
        _apply_button_style(button, false)
        button.pressed.connect(_select_staffing_plan.bind(plan))
        _staffing_grid.add_child(button)
        _staffing_buttons[plan] = button

    _facility_header = Label.new()
    _facility_header.visible = false
    _facility_header.add_theme_font_size_override("font_size", 13)
    _facility_header.add_theme_color_override("font_color", Color(1.0, 0.76, 0.34))
    column.add_child(_facility_header)

    _build_facility_zone(column, "intake", "ZONE A  入荷", [&"double_dock", &"buffer_yard"])
    _build_facility_zone(column, "storage", "ZONE B  保管", [&"fast_pick_rack", &"high_density_rack"])
    _build_facility_zone(column, "packing", "ZONE C  梱包", [&"parallel_pack", &"fast_pack_cell"])


func _build_facility_zone(parent: VBoxContainer, group: String, title: String, kinds: Array[StringName]) -> void:
    var label := Label.new()
    label.text = title
    label.visible = false
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color(0.66, 0.80, 0.86))
    parent.add_child(label)
    _facility_zone_labels[group] = label

    for kind in kinds:
        var button := Button.new()
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.custom_minimum_size = Vector2(0, 58)
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.add_theme_font_size_override("font_size", 11)
        _apply_button_style(button, false)
        button.pressed.connect(_purchase_facility.bind(kind))
        button.visible = false
        parent.add_child(button)
        _facility_buttons[String(kind)] = button


func _choose_contract_slot(index: int) -> void:
    if sim == null or index < 0 or index >= sim.contract_offers.size():
        return
    var offer: Dictionary = sim.contract_offers[index]
    var result := sim.choose_contract(int(offer.get("id", -1)))
    if bool(result.get("ok", false)):
        _show_toast("契約開始  %s" % String(offer.get("title", "")))
    else:
        _show_toast("契約を開始できない")


func _select_staffing_plan(plan: String) -> void:
    if sim == null:
        return
    var result := sim.set_staffing_plan(plan)
    if bool(result.get("ok", false)):
        return
    match String(result.get("reason", "")):
        "cooldown":
            _show_toast("配置替えまであと%d秒" % ceili(float(result.get("remaining", 0.0))))
        "same":
            _show_toast("現在の人員配置です")
        _:
            _show_toast("人員配置を変更できない")


func _purchase_facility(kind: StringName) -> void:
    if sim == null:
        return
    var result := sim.purchase_facility(kind)
    if bool(result.get("ok", false)):
        return
    match String(result.get("reason", "")):
        "funds":
            _show_toast("資金不足  ¥%s必要" % _format_number(int(result.get("cost", 0))))
        "exclusive":
            _show_toast("このゾーンは選択済み")
        "owned":
            _show_toast("採用済みの設備です")
        _:
            _show_toast("拡張できない")


func _render_progression() -> void:
    if sim == null or _progression_panel == null:
        return

    if _manage_button != null:
        _manage_button.text = "閉じる" if _sheet != null and _sheet.visible else "管理"

    var rank2 := sim.facility_rank >= 2
    _progression_label.text = (
        "RANK 2  WAREHOUSE  ｜ 評価 %d  ｜ 契約 %d件" % [sim.logistics_rating, sim.completed_contracts]
        if rank2
        else "RANK 1  SMALL DEPOT  ｜ 物流評価 %d / 8" % sim.logistics_rating
    )

    if not sim.active_contract.is_empty():
        var active: Dictionary = sim.active_contract
        _contract_status.text = "契約中｜%s\n%s  %.0f/%.0f  残%d秒" % [
            String(active.get("title", "契約")),
            String(active.get("description", "")),
            float(active.get("progress", 0.0)),
            float(active.get("target", 0.0)),
            ceili(float(active.get("remaining", 0.0))),
        ]
        for button in _contract_buttons:
            button.visible = false
    else:
        _contract_status.text = "契約を1つ選択。達成すると資金・RP・物流評価を獲得。"
        for index in _contract_buttons.size():
            var button := _contract_buttons[index]
            if index >= sim.contract_offers.size():
                button.visible = false
                continue
            var offer: Dictionary = sim.contract_offers[index]
            button.visible = true
            button.disabled = false
            button.text = "%s\n%s  ｜ +¥%s / +%dRP / 評価+%d" % [
                String(offer.get("title", "契約")),
                String(offer.get("description", "")),
                _format_number(int(offer.get("reward_cash", 0))),
                int(offer.get("reward_rp", 0)),
                int(offer.get("reward_rating", 0)),
            ]

    _staffing_label.visible = rank2
    _staffing_grid.visible = rank2
    if rank2:
        var summary := sim.staffing_summary()
        var cooldown := ceili(sim.staffing_cooldown)
        _staffing_label.text = "人員配置  入庫%d / ピック%d / 出荷%d%s" % [
            int(summary.get("store", 0)),
            int(summary.get("pick", 0)),
            int(summary.get("ship", 0)),
            "  ｜ 変更まで%d秒" % cooldown if cooldown > 0 else "  ｜ 変更可能",
        ]
        for plan in _staffing_buttons:
            var staffing_button: Button = _staffing_buttons[plan]
            _apply_button_style(staffing_button, String(plan) == sim.staffing_plan)
            staffing_button.disabled = sim.staffing_cooldown > 0.0

    _render_facility_choices(rank2)

    _flow_button.visible = not rank2
    _inbound_button.visible = not rank2
    _outbound_button.visible = not rank2

    for kind in [&"worker", &"rack", &"speed", &"packing"]:
        if _upgrade_buttons.has(kind):
            (_upgrade_buttons[kind] as Button).visible = not rank2
    if _upgrade_buttons.has(&"forklift"):
        (_upgrade_buttons[&"forklift"] as Button).visible = not sim.forklift_unlocked


func _render_facility_choices(rank2: bool) -> void:
    if _facility_header == null:
        return

    _facility_header.visible = rank2
    if not rank2:
        for zone_label in _facility_zone_labels.values():
            (zone_label as Label).visible = false
        for facility_button in _facility_buttons.values():
            (facility_button as Button).visible = false
        return

    _facility_header.text = "拡張ゾーン  %d / 3" % sim.expansion_zones_completed()
    var groups := {
        "intake": ["ZONE A  入荷", [&"double_dock", &"buffer_yard"]],
        "storage": ["ZONE B  保管", [&"fast_pick_rack", &"high_density_rack"]],
        "packing": ["ZONE C  梱包", [&"parallel_pack", &"fast_pack_cell"]],
    }
    for group in groups:
        var data: Array = groups[group]
        var selected := sim.selected_facility_for_group(String(group))
        var zone_label: Label = _facility_zone_labels[group]
        zone_label.visible = true
        zone_label.text = String(data[0]) + ("  ｜ 採用済み" if not selected.is_empty() else "  ｜ どちらか1つ")
        var kinds: Array = data[1]
        for kind_variant in kinds:
            var kind := StringName(kind_variant)
            var button: Button = _facility_buttons[String(kind)]
            var info := sim.facility_info(kind)
            var chosen := selected == String(kind)
            button.visible = true
            button.disabled = not selected.is_empty() or sim.money < sim.facility_cost(kind)
            button.text = "%s%s\n%s  ｜ ¥%s" % [
                "✓ " if chosen else "",
                String(info.get("label", String(kind))),
                String(info.get("effect", "")),
                _format_number(sim.facility_cost(kind)),
            ]
            _apply_button_style(button, chosen)


func _find_upgrade_list(node: Node) -> VBoxContainer:
    if node is ScrollContainer and node.get_child_count() > 0:
        var child := node.get_child(0)
        if child is VBoxContainer:
            return child as VBoxContainer

    for child in node.get_children():
        var found := _find_upgrade_list(child)
        if found != null:
            return found
    return null


func _build_reset_control() -> void:
    var list := _find_upgrade_list(_sheet)
    if list == null:
        return

    var label := Label.new()
    label.text = "テスト / データ管理"
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76))
    list.add_child(label)

    _reset_button = Button.new()
    _reset_button.text = "テストデータをリセット\n初期状態からやり直す"
    _reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _reset_button.custom_minimum_size = Vector2(0, 72)
    _reset_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _reset_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _reset_button.add_theme_font_size_override("font_size", 11)
    _apply_button_style(_reset_button, false)
    _reset_button.add_theme_stylebox_override(
        "normal",
        _panel_style(Color(0.075, 0.035, 0.035, 0.98), Color(0.78, 0.30, 0.28, 0.92), 12)
    )
    _reset_button.pressed.connect(_request_reset_confirmation)
    list.add_child(_reset_button)

    _reset_modal = Control.new()
    _reset_modal.name = "ResetProgressModal"
    _reset_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _reset_modal.mouse_filter = Control.MOUSE_FILTER_STOP
    _reset_modal.z_index = 100
    _reset_modal.visible = false
    add_child(_reset_modal)

    var scrim := ColorRect.new()
    scrim.name = "ResetProgressScrim"
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.color = Color(0.0, 0.0, 0.0, 0.72)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    _reset_modal.add_child(scrim)

    _reset_modal_panel = PanelContainer.new()
    _reset_modal_panel.name = "ResetProgressPanel"
    _reset_modal_panel.anchor_left = 0.5
    _reset_modal_panel.anchor_right = 0.5
    _reset_modal_panel.anchor_top = 0.5
    _reset_modal_panel.anchor_bottom = 0.5
    _reset_modal_panel.offset_left = -165.0
    _reset_modal_panel.offset_right = 165.0
    _reset_modal_panel.offset_top = -132.0
    _reset_modal_panel.offset_bottom = 132.0
    _reset_modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _reset_modal_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.012, 0.032, 0.045, 0.995), Color(0.78, 0.30, 0.28, 0.96), 18)
    )
    _reset_modal.add_child(_reset_modal_panel)

    var modal_margin := MarginContainer.new()
    modal_margin.add_theme_constant_override("margin_left", 18)
    modal_margin.add_theme_constant_override("margin_right", 18)
    modal_margin.add_theme_constant_override("margin_top", 18)
    modal_margin.add_theme_constant_override("margin_bottom", 16)
    _reset_modal_panel.add_child(modal_margin)

    var modal_column := VBoxContainer.new()
    modal_column.add_theme_constant_override("separation", 12)
    modal_margin.add_child(modal_column)

    var modal_title := Label.new()
    modal_title.text = "テストデータをリセット"
    modal_title.add_theme_font_size_override("font_size", 19)
    modal_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.86))
    modal_column.add_child(modal_title)

    var modal_body := Label.new()
    modal_body.text = "進行状況・セーブ・バックアップ・チュートリアル完了状態を削除し、RANK 1の初期状態からやり直します。\n\nこの操作は元に戻せません。"
    modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    modal_body.add_theme_font_size_override("font_size", 13)
    modal_body.add_theme_color_override("font_color", Color(0.88, 0.94, 0.97))
    modal_column.add_child(modal_body)

    var modal_actions := HBoxContainer.new()
    modal_actions.add_theme_constant_override("separation", 10)
    modal_column.add_child(modal_actions)

    _reset_cancel_button = Button.new()
    _reset_cancel_button.text = "キャンセル"
    _reset_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _reset_cancel_button.custom_minimum_size = Vector2(0, 52)
    _reset_cancel_button.add_theme_font_size_override("font_size", 13)
    _apply_button_style(_reset_cancel_button, false)
    _reset_cancel_button.pressed.connect(_cancel_reset_confirmation)
    modal_actions.add_child(_reset_cancel_button)

    _reset_confirm_button = Button.new()
    _reset_confirm_button.text = "リセット"
    _reset_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _reset_confirm_button.custom_minimum_size = Vector2(0, 52)
    _reset_confirm_button.add_theme_font_size_override("font_size", 13)
    _reset_confirm_button.add_theme_stylebox_override(
        "normal",
        _panel_style(Color(0.19, 0.045, 0.045, 0.99), Color(0.96, 0.34, 0.30, 1.0), 12)
    )
    _reset_confirm_button.add_theme_stylebox_override(
        "pressed",
        _panel_style(Color(0.29, 0.055, 0.055, 1.0), Color(1.0, 0.46, 0.40, 1.0), 12)
    )
    _reset_confirm_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.90))
    _reset_confirm_button.pressed.connect(_confirm_reset_progress)
    modal_actions.add_child(_reset_confirm_button)


func _request_reset_confirmation() -> void:
    if _reset_modal == null:
        return
    _reset_modal.visible = true


func _cancel_reset_confirmation() -> void:
    if _reset_modal != null:
        _reset_modal.visible = false


func _confirm_reset_progress() -> void:
    if _reset_modal != null:
        _reset_modal.visible = false
    reset_progress_requested.emit()


func _build_measurement_banner() -> void:
    _measurement_panel = PanelContainer.new()
    _measurement_panel.anchor_left = 0.08
    _measurement_panel.anchor_right = 0.92
    _measurement_panel.anchor_top = 1.0
    _measurement_panel.anchor_bottom = 1.0
    _measurement_panel.offset_top = -184.0
    _measurement_panel.offset_bottom = -116.0
    _measurement_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.055, 0.075, 0.97), Color(0.18, 0.72, 0.96, 0.92), 14)
    )
    _measurement_panel.visible = false
    add_child(_measurement_panel)

    _measurement_label = Label.new()
    _measurement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _measurement_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _measurement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _measurement_label.add_theme_font_size_override("font_size", 13)
    _measurement_label.add_theme_color_override("font_color", Color(0.90, 0.98, 1.0))
    _measurement_panel.add_child(_measurement_label)


func _tune_mobile_hud() -> void:
    var dock := _find_bottom_dock()
    if dock != null:
        dock.offset_top = -100.0
        dock.offset_bottom = -22.0

    if _sheet != null:
        _sheet.offset_bottom = -108.0
        _disable_horizontal_sheet_scroll(_sheet)

    if _toast_panel != null:
        _toast_panel.anchor_top = 0.58
        _toast_panel.anchor_bottom = 0.58
        _toast_panel.offset_left = -82.0
        _toast_panel.offset_right = 82.0
        _toast_panel.offset_top = -19.0
        _toast_panel.offset_bottom = 19.0

    if _toast != null:
        _toast.add_theme_font_size_override("font_size", 14)

    _sync_transient_overlay_positions()


func _disable_horizontal_sheet_scroll(node: Node) -> void:
    if node is ScrollContainer:
        (node as ScrollContainer).horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

    for child in node.get_children():
        _disable_horizontal_sheet_scroll(child)


func _sync_transient_overlay_positions() -> void:
    var sheet_open := _sheet != null and _sheet.visible

    if _toast_panel != null:
        var toast_anchor := 0.37 if sheet_open else 0.58
        _toast_panel.anchor_top = toast_anchor
        _toast_panel.anchor_bottom = toast_anchor
        _toast_panel.offset_top = -19.0
        _toast_panel.offset_bottom = 19.0

    if _measurement_panel != null:
        if sheet_open:
            _measurement_panel.anchor_top = 0.30
            _measurement_panel.anchor_bottom = 0.30
            _measurement_panel.offset_top = -28.0
            _measurement_panel.offset_bottom = 28.0
        else:
            _measurement_panel.anchor_top = 1.0
            _measurement_panel.anchor_bottom = 1.0
            _measurement_panel.offset_top = -184.0
            _measurement_panel.offset_bottom = -116.0


func _find_bottom_dock() -> PanelContainer:
    for child in get_children():
        if child is not PanelContainer:
            continue
        var panel := child as PanelContainer
        if panel == _sheet or panel == _toast_panel or panel == _measurement_panel:
            continue
        if panel.anchor_top >= 0.99 and panel.anchor_bottom >= 0.99 and panel.offset_bottom > -40.0:
            return panel
    return null


func _show_measurement_status(text: String, seconds: float) -> void:
    if _measurement_panel == null or _measurement_label == null:
        return
    _measurement_label.text = text
    _measurement_panel.visible = true
    _measurement_timer = seconds


func _replace_static_copy_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            var label := child as Label
            match label.text:
                "BUILD · OPERATE · GROW":
                    label.text = "物流を読み、育てる"
                "Bottleneck Director":
                    label.text = "詰まり分析"
                "事業投資":
                    label.text = "事業管理"
        elif child is Button:
            var button := child as Button
            if button.text == "FLOW":
                button.text = "バランス"
        _replace_static_copy_recursive(child)


func _apply_japanese_font_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Control:
            (child as Control).add_theme_font_override("font", JAPANESE_UI_FONT)
        _apply_japanese_font_recursive(child)
