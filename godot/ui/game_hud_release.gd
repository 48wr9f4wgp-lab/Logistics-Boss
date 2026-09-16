extends "res://ui/game_hud_feedback.gd"
class_name ReleaseGameHud

const RELEASE_BRAND_TOP := 4.0
const RELEASE_BRAND_BOTTOM := 32.0
const RELEASE_METRICS_TOP := 34.0
const RELEASE_METRICS_BOTTOM := 86.0
const RELEASE_BOTTLENECK_TOP := 90.0
const RELEASE_BOTTLENECK_BOTTOM := 122.0
const RELEASE_STATUS_TOP := 128.0
const RELEASE_WAVE_BOTTOM := 174.0
const RELEASE_FTUE_BOTTOM := 190.0


func _ready() -> void:
    super._ready()
    _compact_command_hud()
    if _bottleneck != null:
        _bottleneck.add_theme_font_size_override("font_size", 11)


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
                label.add_theme_font_size_override("font_size", 16 if label.text == "LOGISTICS BOSS" else 8)

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


func _sync_release_overlay_visibility() -> void:
    if _wave_panel == null or _ftue_coach == null:
        return
    if _ftue_coach.visible:
        _wave_panel.visible = false


func _find_brand_strip() -> HBoxContainer:
    for child in get_children():
        if child is not HBoxContainer:
            continue
        var row := child as HBoxContainer
        for item in row.get_children():
            if item is Label and (item as Label).text == "LOGISTICS BOSS":
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


func _bottleneck_text(info: Dictionary) -> String:
    match String(info.get("key", "stable")):
        "inbound":
            return "搬入口混雑 → 受入を強化"
        "rack":
            return "棚不足 → 保管を見直す"
        "packing":
            return "梱包詰まり → 梱包を強化"
        "outbound":
            return "出荷滞留 → 出荷を強化"
        "orders":
            return "注文滞留 → ピックを強化"
        "stable":
            return "安定運転"
        _:
            return super._bottleneck_text(info)
