extends "res://ui/game_hud.gd"
class_name JapaneseGameHud

var _jp_system_font: SystemFont


func _ready() -> void:
    super._ready()
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
