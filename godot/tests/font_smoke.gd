extends SceneTree

const FONT_PATH := "res://assets/fonts/MPLUS1p-Regular.ttf"
const REQUIRED_GLYPHS := "物流詰分析搬入口混雑棚満杯梱包出荷待滞留注文安定運転投資効果計測前後秒分入庫自動化作業員工程解放円速度容量設備管理優先停止再開"


func _init() -> void:
    var font := load(FONT_PATH) as Font
    assert(font != null, "embedded Japanese UI font must load")

    for index in REQUIRED_GLYPHS.length():
        var codepoint := REQUIRED_GLYPHS.unicode_at(index)
        assert(
            font.has_char(codepoint),
            "embedded Japanese UI font is missing glyph U+%04X" % codepoint
        )

    print("Godot Japanese font smoke passed")
    quit(0)
