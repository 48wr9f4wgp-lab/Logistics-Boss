extends "res://ui/game_hud_ja.gd"
class_name WorkloadGameHud

var _wave_panel: PanelContainer
var _wave_label: Label
var _last_wave_key := ""


func _ready() -> void:
    super._ready()
    _build_wave_banner()
    _render_wave_banner()


func _process(delta: float) -> void:
    super._process(delta)
    _render_wave_banner()


func _on_sim_event(event: Dictionary) -> void:
    super._on_sim_event(event)
    if String(event.get("type", "")) != "workload_wave_changed":
        return
    var key := String(event.get("key", ""))
    if key == "normal":
        return
    _show_toast("運用負荷  %s" % String(event.get("label", "")))
    _toast_timer = 2.6


func _build_wave_banner() -> void:
    _wave_panel = PanelContainer.new()
    _wave_panel.anchor_left = 0.0
    _wave_panel.anchor_right = 1.0
    _wave_panel.anchor_top = 0.0
    _wave_panel.anchor_bottom = 0.0
    _wave_panel.offset_left = 12.0
    _wave_panel.offset_right = -12.0
    _wave_panel.offset_top = 176.0
    _wave_panel.offset_bottom = 222.0
    _wave_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.045, 0.062, 0.94), Color(0.18, 0.56, 0.72, 0.86), 13)
    )
    _wave_panel.visible = false
    add_child(_wave_panel)

    _wave_label = Label.new()
    _wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _wave_label.add_theme_font_override("font", JAPANESE_UI_FONT)
    _wave_label.add_theme_font_size_override("font_size", 11)
    _wave_label.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
    _wave_panel.add_child(_wave_label)


func _render_wave_banner() -> void:
    if _wave_panel == null or _wave_label == null or sim == null:
        return
    if not sim.has_method("workload_wave"):
        _wave_panel.visible = false
        return

    var wave: Dictionary = sim.call("workload_wave")
    var enabled := bool(wave.get("enabled", false))
    _wave_panel.visible = enabled
    if not enabled:
        return

    var key := String(wave.get("key", "normal"))
    var remaining := ceili(float(wave.get("remaining", 0.0)))
    var label := String(wave.get("label", "通常運転"))
    var description := String(wave.get("description", ""))

    if key == "normal":
        var next_label := String(wave.get("next_wave_label", ""))
        var next_seconds := ceili(float(wave.get("seconds_until_next_wave", 0.0)))
        _wave_label.text = "予告｜次: %s  %d秒後\n%s" % [next_label, next_seconds, description]
    elif key == "dispatch_window":
        _wave_label.text = "%s  残%d秒｜この窓の出荷 %d件\n%s" % [
            label,
            remaining,
            int(wave.get("dispatch_shipments", 0)),
            description,
        ]
    else:
        _wave_label.text = "%s  残%d秒\n%s" % [label, remaining, description]

    if key != _last_wave_key:
        _last_wave_key = key
        _style_wave_banner(key)


func _style_wave_banner(key: String) -> void:
    var border := Color(0.18, 0.56, 0.72, 0.86)
    var text := Color(0.82, 0.95, 1.0)
    match key:
        "inbound_surge":
            border = Color(1.0, 0.62, 0.22, 0.95)
            text = Color(1.0, 0.86, 0.62)
        "order_surge":
            border = Color(0.43, 0.70, 1.0, 0.95)
            text = Color(0.76, 0.90, 1.0)
        "dispatch_window":
            border = Color(0.32, 0.90, 0.62, 0.95)
            text = Color(0.72, 1.0, 0.84)
    _wave_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.045, 0.062, 0.95), border, 13)
    )
    _wave_label.add_theme_color_override("font_color", text)
