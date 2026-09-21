extends PanelContainer
class_name LogisticsSessionResumeBrief

const DISPLAY_SECONDS := 5.0
const PANEL_TOP := 128.0
const PANEL_BOTTOM := 188.0

var sim: WarehouseSim
var _remaining := 0.0
var _label: Label


func _ready() -> void:
    anchor_left = 0.0
    anchor_right = 1.0
    anchor_top = 0.0
    anchor_bottom = 0.0
    offset_left = 12.0
    offset_right = -12.0
    offset_top = PANEL_TOP
    offset_bottom = PANEL_BOTTOM
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 120

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.052, 0.070, 0.985)
    style.border_color = Color(0.20, 0.68, 0.82, 0.92)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 12.0
    style.content_margin_right = 12.0
    style.content_margin_top = 7.0
    style.content_margin_bottom = 7.0
    add_theme_stylebox_override("panel", style)

    _label = Label.new()
    _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _label.add_theme_font_size_override("font_size", 11)
    _label.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0))
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_label)

    visible = false
    set_process(false)


func bind(next_sim: WarehouseSim, should_show: bool) -> void:
    sim = next_sim
    if sim == null or not should_show:
        visible = false
        set_process(false)
        return
    show_resume_brief()


func show_resume_brief() -> void:
    if sim == null or _label == null:
        return
    var text := brief_text()
    if text.is_empty():
        visible = false
        set_process(false)
        return
    _label.text = text
    _remaining = DISPLAY_SECONDS
    visible = true
    set_process(true)


func _process(delta: float) -> void:
    _remaining = maxf(0.0, _remaining - maxf(0.0, delta))
    if _remaining <= 0.0:
        visible = false
        set_process(false)


func brief_text() -> String:
    if sim == null:
        return ""

    var rank := int(sim.facility_rank)
    if sim.has_method("rank1_expansion_readiness") and rank == 1:
        var growth: Dictionary = sim.call("rank1_expansion_readiness")
        var detail := "設備 %d/%d｜出荷 %d/%d｜拡張費 ¥%s" % [
            int(growth.get("projects", 0)), int(growth.get("projects_required", 2)),
            int(growth.get("shipments", 0)), int(growth.get("shipments_required", 20)),
            _format_amount(int(growth.get("cost", 8000)))]
        return "再開｜%s\n%s" % ["倉庫を拡張できます" if bool(growth.get("ready", false)) else "出荷と設備投資で倉庫を広げよう", detail]
    if sim.has_method("growth_automation_state") and rank == 2:
        var automation: Dictionary = sim.call("growth_automation_state")
        return "再開｜倉庫の自動化を育てよう\nフォーク %d台｜コンベア %s" % [
            (1 if sim.forklift_unlocked else 0) + (1 if bool(automation["extra_owned"]) else 0),
            "稼働中" if bool(automation["conveyor_owned"]) else "未導入"]
    if rank <= 1:
        if not sim.active_contract.is_empty():
            var active: Dictionary = sim.active_contract
            return "再開｜%s  %.0f/%.0f\n次の節目: 物流評価 %d/8 → WAREHOUSE" % [
                String(active.get("title", "契約")),
                float(active.get("progress", 0.0)),
                float(active.get("target", 0.0)),
                sim.logistics_rating,
            ]
        return "再開｜次は契約を選択\n物流評価 %d/8 → RANK 2 WAREHOUSE" % sim.logistics_rating

    if rank == 2 and sim.has_method("rank3_readiness"):
        var readiness: Dictionary = sim.call("rank3_readiness")
        return "再開｜RANK 3まで  拡張 %d/%d\n設備 ¥%s/¥%s ｜ 出荷 %.1f/%.1f分" % [
            int(readiness.get("zones", 0)),
            int(readiness.get("zones_required", 3)),
            _format_amount(int(readiness.get("assets", 0))),
            _format_amount(int(readiness.get("assets_required", 200000))),
            float(readiness.get("throughput", 0.0)),
            float(readiness.get("throughput_required", 6.0)),
        ]

    var bottleneck_info: Dictionary = sim.bottleneck()
    return "再開｜%s\n成長候補: %s" % [
        String(bottleneck_info.get("label", "安定運転")),
        _rank3_growth_candidate(),
    ]


func _rank3_growth_candidate() -> String:
    if sim == null:
        return "現場を再評価"
    if sim.has_method("receiving_annex_info"):
        var annex: Dictionary = sim.call("receiving_annex_info")
        if not bool(annex.get("owned", false)):
            return String(annex.get("label", "受入増設棟"))
    if sim.has_method("inbound_carrier_program_info"):
        var carrier: Dictionary = sim.call("inbound_carrier_program_info")
        if not bool(carrier.get("owned", false)):
            return String(carrier.get("label", "高頻度入荷プログラム"))
    return "配送ルートと人員配置を再評価"


func _format_amount(value: int) -> String:
    var source := str(maxi(0, value))
    var grouped := ""
    while source.length() > 3:
        grouped = "," + source.right(3) + grouped
        source = source.left(source.length() - 3)
    return source + grouped
