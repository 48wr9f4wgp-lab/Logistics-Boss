extends "res://ui/game_hud_ftue.gd"
class_name FeedbackGameHud

const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")

var _measurement_followup_active := false


func _process(delta: float) -> void:
    super._process(delta)
    _sync_measurement_followup_cta()


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
        _measurement_followup_active = false
        _style_measurement_state("measuring")
        _sync_measurement_followup_cta()


func measurement_feedback(event: Dictionary) -> Dictionary:
    var before: Dictionary = event.get("before", {})
    var after: Dictionary = event.get("after", {})
    var verdict: Dictionary = event.get("verdict", {})
    if verdict.is_empty():
        verdict = FlowMeasurementScript.classify_result(before, after)

    var state := String(verdict.get("state", "flat"))
    var headline := String(verdict.get("headline", "横ばい"))
    var delta := float(verdict.get("delta", 0.0))
    var threshold := float(verdict.get("threshold", FlowMeasurement.RESULT_MIN_DELTA))

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

    var before_rate := float(before.get("shipments_per_min", 0.0))
    var after_rate := float(after.get("shipments_per_min", 0.0))
    var direction := "→"
    if state == "improved":
        direction = "↑"
    elif state == "regressed":
        direction = "↓"

    var result_line := "%s %s %s/分｜%.1f→%.1f" % [
        headline,
        direction,
        _signed_delta(delta),
        before_rate,
        after_rate,
    ]
    var action_short := _short_bottleneck_action(bottleneck_key)
    var context_line := "%s｜次:%s" % [
        _compact_context_metric(bottleneck_key, before, after),
        action_short,
    ]
    var action_line := "次: %s" % action_short
    var text := "%s\n%s" % [result_line, context_line]
    var needs_followup := state != "improved" or bottleneck_key != "stable"

    return {
        "state": state,
        "headline": headline,
        "delta": delta,
        "threshold": threshold,
        "text": text,
        "result_line": result_line,
        "context_line": context_line,
        "next_action": next_action,
        "bottleneck_key": bottleneck_key,
        "needs_followup": needs_followup,
    }


func _show_measurement_feedback(event: Dictionary) -> void:
    var feedback := measurement_feedback(event)
    _measurement_followup_active = bool(feedback.get("needs_followup", true))
    _style_measurement_state(String(feedback.get("state", "flat")))
    _show_measurement_status(String(feedback.get("text", "")), 10.0)
    _sync_measurement_followup_cta()


func _sync_measurement_followup_cta() -> void:
    if _manage_button == null:
        return

    var sheet_open := _sheet != null and _sheet.visible
    if sheet_open and _measurement_followup_active:
        _measurement_followup_active = false

    if sheet_open:
        _manage_button.text = "閉じる"
        _apply_button_style(_manage_button, false)
    elif _measurement_followup_active:
        _manage_button.text = "次の判断"
        _apply_button_style(_manage_button, true)
    else:
        _manage_button.text = "管理"
        _apply_button_style(_manage_button, false)


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


func _short_bottleneck_action(key: String) -> String:
    match key:
        "inbound":
            return "INBOUND確認"
        "rack":
            return "STORAGE確認"
        "packing":
            return "PACKING確認"
        "outbound":
            return "SHIPPING確認"
        "orders":
            return "PICKING確認"
        _:
            return "観察継続"


func _compact_context_metric(key: String, before: Dictionary, after: Dictionary) -> String:
    match key:
        "inbound":
            return "入庫 %.1f→%.1f" % [
                float(before.get("inbound_queue", 0.0)),
                float(after.get("inbound_queue", 0.0)),
            ]
        "outbound":
            return "出荷待ち %.1f→%.1f" % [
                float(before.get("outbound_queue", 0.0)),
                float(after.get("outbound_queue", 0.0)),
            ]
        "orders":
            return "注文 %.1f→%.1f" % [
                float(before.get("open_orders", 0.0)),
                float(after.get("open_orders", 0.0)),
            ]
        _:
            return "梱包 %.1f→%.1f" % [
                float(before.get("packing_queue", 0.0)),
                float(after.get("packing_queue", 0.0)),
            ]
