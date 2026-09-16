extends "res://ui/game_hud_feedback.gd"
class_name ReleaseGameHud


func _ready() -> void:
    super._ready()
    if _bottleneck_panel != null:
        # The release HUD is portrait-first. Keep the single-line director chip
        # compact so onboarding can sit between it and the Management sheet.
        _bottleneck_panel.offset_top = 116.0
        _bottleneck_panel.offset_bottom = 150.0
    if _bottleneck != null:
        _bottleneck.add_theme_font_size_override("font_size", 11)


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
