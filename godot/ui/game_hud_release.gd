extends "res://ui/game_hud_feedback.gd"
class_name ReleaseGameHud

const RELEASE_BRAND_TOP := 4.0
const RELEASE_BRAND_BOTTOM := 32.0
const RELEASE_METRICS_TOP := 34.0
const RELEASE_METRICS_BOTTOM := 86.0
const RELEASE_BOTTLENECK_TOP := 90.0
const RELEASE_BOTTLENECK_BOTTOM := 122.0
const RELEASE_STATUS_TOP := 128.0
const RELEASE_WAVE_BOTTOM := 158.0
const RELEASE_FTUE_BOTTOM := 190.0

const HUD_SURFACE := Color(0.012, 0.034, 0.048, 0.955)
const HUD_SURFACE_STRONG := Color(0.009, 0.027, 0.039, 0.985)
const HUD_SHADOW := Color(0.0, 0.0, 0.0, 0.44)
const HUD_ACCENT_CYAN := Color(0.18, 0.72, 0.96, 0.86)


func _ready() -> void:
    super._ready()
    _compact_command_hud()
    _apply_premium_hud_finish()
    if _bottleneck != null:
        _bottleneck.add_theme_font_size_override("font_size", 11)
        _bottleneck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _bottleneck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _bottleneck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        # The symptom and wave each own a line; a separate title stole text width.
        for sibling in _bottleneck.get_parent().get_children():
            if sibling is Label and sibling != _bottleneck:
                sibling.hide()


func _process(delta: float) -> void:
    super._process(delta)
    _sync_release_overlay_visibility()


func _compact_command_hud() -> void:
    # Keep the warehouse as the visual hero. The release HUD retains all live
    # information but spends less of the portrait viewport on permanent chrome.
    var brand := _find_brand_strip()
    if brand != null:
        brand.offset_top = RELEASE_BRAND_TOP
        brand.offset_bottom = RELEASE_BRAND_BOTTOM
        for child in brand.get_children():
            if child is Label:
                var label := child as Label
                label.add_theme_font_size_override("font_size", 16 if label.text == "FLOTRA" else 8)

    var metrics := _find_metric_row()
    if metrics != null:
        metrics.offset_top = RELEASE_METRICS_TOP
        metrics.offset_bottom = RELEASE_METRICS_BOTTOM
        for child in metrics.get_children():
            if child is PanelContainer:
                (child as PanelContainer).custom_minimum_size.y = 48.0

    if _bottleneck_panel != null:
        _bottleneck_panel.offset_top = RELEASE_BOTTLENECK_TOP
        _bottleneck_panel.offset_bottom = RELEASE_BOTTLENECK_BOTTOM

    # Rank 2+ workload waves and fresh-save onboarding share the same compact
    # status band. FTUE wins while it is active; waves resume on the next frame.
    if _wave_panel != null:
        _wave_panel.offset_top = RELEASE_STATUS_TOP
        _wave_panel.offset_bottom = RELEASE_WAVE_BOTTOM
    if _ftue_coach != null:
        _ftue_coach.offset_top = RELEASE_STATUS_TOP
        _ftue_coach.offset_bottom = RELEASE_FTUE_BOTTOM


func _apply_premium_hud_finish() -> void:
    # The rendered capture showed a clean but very flat outline-only HUD. Add a
    # small amount of depth while preserving the restrained command-center look.
    # No blur, animated shader or full-screen overlay is used on the mobile path.
    var metrics := _find_metric_row()
    if metrics != null:
        var accents := [
            Color(1.0, 0.69, 0.25, 0.82),
            Color(0.42, 0.64, 1.0, 0.82),
            Color(0.35, 0.91, 0.73, 0.82),
            Color(1.0, 0.66, 0.32, 0.82),
        ]
        var accent_index := 0
        for child in metrics.get_children():
            if child is not PanelContainer:
                continue
            var accent: Color = accents[mini(accent_index, accents.size() - 1)]
            (child as PanelContainer).add_theme_stylebox_override(
                "panel",
                _premium_panel_style(HUD_SURFACE, accent, 12, 4)
            )
            accent_index += 1

    if _bottleneck_panel != null:
        _bottleneck_panel.add_theme_stylebox_override(
            "panel",
            _premium_panel_style(HUD_SURFACE, Color(0.18, 0.56, 0.72, 0.86), 14, 4)
        )

    var dock := _find_bottom_dock()
    if dock != null:
        dock.add_theme_stylebox_override(
            "panel",
            _premium_panel_style(HUD_SURFACE_STRONG, HUD_ACCENT_CYAN, 18, 6)
        )


func _premium_panel_style(background: Color, border: Color, radius: int, shadow_size: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.border_blend = true
    style.shadow_color = HUD_SHADOW
    style.shadow_size = shadow_size
    style.shadow_offset = Vector2(0.0, 2.0)
    return style


func _sync_release_overlay_visibility() -> void:
    # Keep workload information, but fold it into the bottleneck director so
    # normal Rank 2/3 play gives the warehouse one continuous visual field.
    if _wave_panel != null:
        _wave_panel.visible = false


func _find_brand_strip() -> HBoxContainer:
    for child in get_children():
        if child is not HBoxContainer:
            continue
        var row := child as HBoxContainer
        for item in row.get_children():
            if item is Label and (item as Label).text == "FLOTRA":
                return row
    return null


func _find_metric_row() -> HBoxContainer:
    for child in get_children():
        if child is not HBoxContainer:
            continue
        var row := child as HBoxContainer
        var metric_panels := 0
        for item in row.get_children():
            if item is PanelContainer:
                metric_panels += 1
        if metric_panels >= 4:
            return row
    return null


func _find_bottom_dock() -> PanelContainer:
    for child in get_children():
        if child is not PanelContainer:
            continue
        var panel := child as PanelContainer
        if is_equal_approx(panel.anchor_top, 1.0) and is_equal_approx(panel.anchor_bottom, 1.0):
            return panel
    return null


func _bottleneck_text(info: Dictionary) -> String:
    # Core Experience v2: the Director reports symptoms and evidence, never
    # the equipment/action answer. The player must inspect the physical Zone.
    var text := ""
    match String(info.get("key", "stable")):
        "inbound":
            text = "入荷 高負荷｜待機 %d" % (sim.inbound_queue if sim != null else 0)
        "rack":
            text = "保管 高負荷｜%d/%d" % [
                sim.rack_stock if sim != null else 0,
                sim.rack_capacity if sim != null else 0,
            ]
        "packing":
            text = "梱包 高負荷｜待機 %d" % (sim.packing_queue if sim != null else 0)
        "outbound":
            text = "出荷 高負荷｜待機 %d" % (sim.packed_queue if sim != null else 0)
        "orders":
            text = "ピッキング 高負荷｜注文 %d" % (sim.open_orders if sim != null else 0)
        "stable":
            text = "安定運転"
        _:
            text = super._bottleneck_text(info)

    var wave := _inline_wave_summary()
    return text if wave.is_empty() else "%s\n%s" % [text, wave]


func _inline_wave_summary() -> String:
    if sim == null or not sim.has_method("workload_wave"):
        return ""
    var wave: Dictionary = sim.call("workload_wave")
    if not bool(wave.get("enabled", false)):
        return ""

    var key := String(wave.get("key", "normal"))
    if key == "normal":
        var next_label := String(wave.get("next_wave_label", ""))
        var next_seconds := ceili(float(wave.get("seconds_until_next_wave", 0.0)))
        return "" if next_label.is_empty() else "次:%s %d秒" % [next_label, next_seconds]

    var label := String(wave.get("label", "運用負荷"))
    var remaining := ceili(float(wave.get("remaining", 0.0)))
    return "%s 残%d秒" % [label, remaining]
