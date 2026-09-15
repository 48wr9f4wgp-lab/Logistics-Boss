extends "res://ui/game_hud.gd"
class_name JapaneseGameHud

var _jp_system_font: SystemFont
var _measurement_panel: PanelContainer
var _measurement_label: Label
var _measurement_timer := 0.0


func _ready() -> void:
    super._ready()
    _append_forklift_upgrade()
    _build_measurement_banner()

    _jp_system_font = SystemFont.new()
    _jp_system_font.font_names = PackedStringArray([
        "Hiragino Sans",
        "Yu Gothic",
        "Noto Sans CJK JP",
        "sans-serif",
    ])
    _jp_system_font.allow_system_fallback = true
    _apply_japanese_font_recursive(self)
    _replace_static_copy_recursive(self)


func _process(delta: float) -> void:
    super._process(delta)
    if _measurement_timer > 0.0:
        _measurement_timer -= delta
        if _measurement_timer <= 0.0 and _measurement_panel != null:
            _measurement_panel.visible = false


func _copy(jp: String, _en: String) -> String:
    return jp


func _bottleneck_text(info: Dictionary) -> String:
    var label := String(info.get("label", ""))
    if not label.is_empty():
        return label

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
        _:
            return "安定運転"


func _is_maxed(kind: StringName) -> bool:
    if kind == &"forklift":
        return sim != null and sim.forklift_unlocked
    return super._is_maxed(kind)


func _on_sim_event(event: Dictionary) -> void:
    super._on_sim_event(event)
    match String(event.get("type", "")):
        "upgrade_purchased":
            _show_measurement_status("投資効果を計測中\n前25秒 → 後25秒", 30.0)
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


func _build_measurement_banner() -> void:
    _measurement_panel = PanelContainer.new()
    _measurement_panel.anchor_left = 0.08
    _measurement_panel.anchor_right = 0.92
    _measurement_panel.anchor_top = 1.0
    _measurement_panel.anchor_bottom = 1.0
    _measurement_panel.offset_top = -186.0
    _measurement_panel.offset_bottom = -102.0
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
        elif child is Button:
            var button := child as Button
            if button.text == "FLOW":
                button.text = "バランス"
        _replace_static_copy_recursive(child)


func _apply_japanese_font_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Control:
            (child as Control).add_theme_font_override("font", _jp_system_font)
        _apply_japanese_font_recursive(child)
