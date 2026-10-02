extends PanelContainer
class_name LogisticsSaveStatusNotice

const HudPalette := preload("res://ui/hud_palette.gd")
const RECOVERY_SECONDS := 8.0
const SAVED_SECONDS := 5.0

var store: LogisticsSaveStore
var label: Label
var notice_kind := ""
var _remaining := 0.0
var _saw_save_failure := false
var _announced_backup := false


func _ready() -> void:
    name = "SaveStatusNotice"
    anchor_right = 1.0
    offset_left = 12.0
    offset_right = -12.0
    offset_top = 128.0
    offset_bottom = 196.0
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 60
    var style := StyleBoxFlat.new()
    style.bg_color = HudPalette.SURFACE_DEEP
    style.border_color = HudPalette.AMBER
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 10.0
    style.content_margin_right = 10.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    add_theme_stylebox_override("panel", style)
    label = Label.new()
    label.name = "SaveStatusText"
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", HudPalette.TEXT)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(label)
    hide()


func bind(next_store: LogisticsSaveStore) -> void:
    if store != null and store.status_changed.is_connected(_refresh_status):
        store.status_changed.disconnect(_refresh_status)
    store = next_store
    store.status_changed.connect(_refresh_status)
    _refresh_status()


func has_notice() -> bool:
    return not notice_kind.is_empty()


func _process(delta: float) -> void:
    # Hidden management, zone and confirmation surfaces do not consume reading
    # time. Persistent failures stay until the actual store reports success.
    if not visible or _remaining <= 0.0:
        return
    _remaining = maxf(0.0, _remaining - maxf(0.0, delta))
    if _remaining <= 0.0:
        notice_kind = ""
        hide()


func _refresh_status() -> void:
    if store == null or label == null:
        return
    if store.write_protected:
        notice_kind = "protected"
        _remaining = 0.0
        label.text = "保存データを保護しています\n%s\nこの画面で進めた内容は保存されません。" % (
            "この版で読み込めないデータがあるため、保存を停止中。"
            if store.protection_reason == "newer_version" else
            "既存データを読み込めないため、上書きを停止中。")
    elif store.save_status == "failed":
        notice_kind = "failed"
        _saw_save_failure = true
        _remaining = 0.0
        label.text = "保存できていません\n現在の進行は未保存です。次の自動保存で再試行します。"
    elif store.save_status == "saved" and _saw_save_failure:
        notice_kind = "saved"
        _saw_save_failure = false
        _remaining = SAVED_SECONDS
        label.text = "保存できました\n現在の進行状況を保存しました。"
    elif store.load_status == "backup" and not _announced_backup:
        notice_kind = "backup"
        _announced_backup = true
        _remaining = RECOVERY_SECONDS
        label.text = "バックアップから再開しました\n直前の保存を読み込めなかったため、前回分を使っています。"
    elif notice_kind in ["protected", "failed"]:
        notice_kind = ""
    visible = has_notice()
