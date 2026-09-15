extends "res://ui/game_hud_ftue.gd"
class_name FeedbackGameHud

const RESULT_IMPROVEMENT_RATIO := 0.05
const RESULT_MIN_DELTA := 0.5


func _on_sim_event(event: Dictionary) -> void:
    super._on_sim_event(event)
    var event_type := String(event.get("type", ""))
    if event_type == "measurement_completed":
        _show_measurement_feedback(event)
        return

    if event_type in [
        "upgrade_purchased",
        "facility_purchased",
        "receiving_annex_purchased",
        "routing_changed",
        "inbound_carrier_program_purchased",
    ]:
        _style_measurement_state("measuring")


func measurement_feedback(event: Dictionary) -> Dictionary:
    var before: Dictionary = event.get("before", {})
    var after: Dictionary = event.get("after", {})
    var before_rate := float(before.get("shipments_per_min", 0.0))
    var after_rate := float(after.get("shipments_per_min", 0.0))
    var delta := after_rate - before_rate
    var threshold := maxf(RESULT_MIN_DELTA, absf(before_rate) * RESULT_IMPROVEMENT_RATIO)

    var state := "flat"
    var headline := "横ばい"
    if delta >= threshold:
        state = "improved"
        headline = "改善"
    elif delta <= -threshold:
        state = "regressed"
        headline = "要再判断"

    var bottleneck_key := "stable"
    var bottleneck_label := "安定運転"
    if sim != null:
        var bottleneck: Dictionary = sim.bottleneck()
        bottleneck_key = String(bottleneck.get("key", "stable"))
        bottleneck_label = _bottleneck_text(bottleneck)

    var next_action := "次: 詰まり分析を確認して次の判断へ"
    if state == "improved":
        next_action = (
            "次: 少し観察して新しい詰まりを確認"
            if bottleneck_key == "stable"
            else "次: 「%s」への対策を検討" % bottleneck_label
        )
    elif state == "regressed":
        next_action = (
            "次: 少し観察して投資前後の流れを再確認"
            if bottleneck_key == "stable"
            else "次: 「%s」を優先して見直す" % bottleneck_label
        )
    elif bottleneck_key != "stable":
        next_action = "次: 「%s」と投資先が合っているか確認" % bottleneck_label

    var result_line := "%s｜出荷 %s/分（%.1f→%.1f）" % [
        headline,
        _signed_delta(delta),
        before_rate,
        after_rate,
    ]
    var context_line := "入庫 %.1f→%.1f｜梱包 %.1f→%.1f" % [
        float(before.get("inbound_queue", 0.0)),
        float(after.get("inbound_queue", 0.0)),
        float(before.get("packing_queue", 0.0)),
        float(after.get("packing_queue", 0.0)),
    ]
    var action_line := next_action.replace("次:", "次 →")
    var text := "%s\n%s\n%s" % [result_line, context_line, action_line]

    return {
        "state": state,
        "headline": headline,
        "delta": delta,
        "threshold": threshold,
        "text": text,
        "result_line": result_line,
        "context_line": context_line,
        "next_action": next_action,
    }


func _show_measurement_feedback(event: Dictionary) -> void:
    var feedback := measurement_feedback(event)
    _style_measurement_state(String(feedback.get("state", "flat")))
    _show_measurement_status(String(feedback.get("text", "")), 10.0)


func _style_measurement_state(state: String) -> void:
    if _measurement_panel == null or _measurement_label == null:
        return

    var border := Color(0.18, 0.72, 0.96, 0.92)
    var text_color := Color(0.90, 0.98, 1.0)
    var font_size := 13
    match state:
        "improved":
            border = Color(0.28, 0.90, 0.62, 0.96)
            text_color = Color(0.76, 1.0, 0.86)
            font_size = 12
        "regressed":
            border = Color(1.0, 0.58, 0.20, 0.96)
            text_color = Color(1.0, 0.86, 0.66)
            font_size = 12
        "flat":
            border = Color(0.40, 0.68, 0.92, 0.94)
            text_color = Color(0.84, 0.94, 1.0)
            font_size = 12

    _measurement_panel.add_theme_stylebox_override(
        "panel",
        _panel_style(Color(0.018, 0.055, 0.075, 0.97), border, 14)
    )
    _measurement_label.add_theme_color_override("font_color", text_color)
    _measurement_label.add_theme_font_size_override("font_size", font_size)


func _signed_delta(value: float) -> String:
    if value > 0.0:
        return "+%.1f" % value
    if value < 0.0:
        return "%.1f" % value
    return "±0.0"
