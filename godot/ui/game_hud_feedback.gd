extends "res://ui/game_hud_ftue.gd"
class_name FeedbackGameHud

const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")
const MEASUREMENT_START_EVENTS := [
    "rank1_project_purchased", "growth_automation_purchased", "capacity_purchased",
    "upgrade_purchased", "facility_purchased", "facility_renovated",
    "receiving_annex_purchased", "routing_changed", "inbound_carrier_program_purchased",
]

# Presentation state only. Investment events start these watches; the Domain's
# matching completion event ends them. Wall-clock animation never predicts a result.
var _pending_measurements: Array[Dictionary] = []
var _measurement_result_active := false
var _measurement_followup_active := false
var _toast_is_priority := false
var _earnings_timer := 0.0
var _earnings_caption: Label


func bind_sim(next_sim: WarehouseSim) -> void:
    if sim != next_sim:
        _pending_measurements.clear()
        _measurement_result_active = false
        _measurement_timer = 0.0
    super.bind_sim(next_sim)


func _ready() -> void:
    super._ready()
    # These surfaces report outcomes; they must never consume a player's tap.
    for control in [_toast_panel, _toast, _measurement_panel, _measurement_label]:
        if control != null:
            control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _sheet.visibility_changed.connect(_sync_feedback_visibility)
    _reset_modal.visibility_changed.connect(_sync_feedback_visibility)
    if _money != null and _money.get_parent().get_child_count() > 0:
        _earnings_caption = _money.get_parent().get_child(0) as Label


func _process(delta: float) -> void:
    _earnings_timer = maxf(0.0, _earnings_timer - delta)
    if _earnings_timer <= 0.0 and _earnings_caption != null:
        _earnings_caption.text = "資金"
    var obscured := _feedback_is_obscured()
    if obscured:
        _discard_shipment_feedback()
    # Only inherited HUD display clocks wait. Domain.step(), cash rendering,
    # worker tasks and the separately owned onboarding nodes keep running.
    super._process(0.0 if obscured else delta)
    _refresh_pending_measurements()
    _sync_measurement_followup_cta()
    _sync_feedback_visibility()


func _feedback_is_obscured() -> bool:
    if _sheet != null and _sheet.visible:
        return true
    if _reset_modal != null and _reset_modal.visible:
        return true
    # Main attaches its Zone Panel after the HUD's _ready(), so do not cache a
    # missing panel at startup. All these surfaces belong to this HUD instance.
    for child in get_children():
        if child is WarehouseZonePanel and (child as WarehouseZonePanel).is_open():
            return true
    return false


func _discard_shipment_feedback() -> void:
    # These counters are notification-only, never Domain inventory or money.
    _shipment_toast_count = 0
    _shipment_toast_value = 0
    _shipment_toast_batch_elapsed = 0.0
    if not _toast_is_priority:
        _toast_timer = 0.0


func _queue_shipment_toast(event: Dictionary) -> void:
    if _feedback_is_obscured():
        _discard_shipment_feedback()
        return
    super._queue_shipment_toast(event)


func _flush_shipment_toast() -> void:
    if _feedback_is_obscured():
        _discard_shipment_feedback()
        return
    super._flush_shipment_toast()


func _show_toast(text: String, priority: bool = true) -> void:
    if not priority:
        if _earnings_caption != null:
            var amount := text.find("+¥")
            _earnings_caption.text = "資金  %s" % text.substr(amount) if amount >= 0 else "資金"
            _earnings_timer = 1.5
        return
    _toast_is_priority = priority
    super._show_toast(text, priority)
    _sync_feedback_visibility()


func _show_measurement_status(text: String, seconds: float) -> void:
    super._show_measurement_status(text, seconds)
    _sync_feedback_visibility()


func _sync_feedback_visibility() -> void:
    var obscured := _feedback_is_obscured()
    if obscured:
        _discard_shipment_feedback()
    if _toast_panel != null:
        _toast_panel.visible = not obscured and _toast_timer > 0.0
        if _toast_is_priority:
            _toast_panel.anchor_top = 0.0
            _toast_panel.anchor_bottom = 0.0
            _toast_panel.anchor_left = 0.0
            _toast_panel.anchor_right = 1.0
            _toast_panel.offset_left = 12.0
            _toast_panel.offset_right = -12.0
            var lower_edge := 200.0
            for child in get_children():
                if child is Button and child.name == "V2GrowthGoal" and (child as Button).visible:
                    lower_edge = maxf(lower_edge, (child as Button).get_global_rect().end.y + 6.0)
            _toast_panel.offset_top = lower_edge
            _toast_panel.offset_bottom = lower_edge + 30.0
            _toast.add_theme_font_size_override("font_size", 11)
    if _measurement_panel != null:
        _measurement_panel.visible = not obscured and _measurement_timer > 0.0
        if _measurement_panel.visible:
            # Three-line/wrapped observations can grow beyond the inherited
            # fixed-height box. Grow upward so the speed/management dock stays clear.
            _measurement_panel.anchor_top = 1.0
            _measurement_panel.anchor_bottom = 1.0
            _measurement_panel.offset_bottom = -104.0
            _measurement_panel.offset_top = -104.0 - maxf(54.0, _measurement_panel.get_combined_minimum_size().y)


func _on_sim_event(event: Dictionary) -> void:
    var event_type := String(event.get("type", ""))
    # Legacy handlers also write "measuring" copy. Keep unread result content
    # and its remaining reading time across a new investment through either API.
    var preserve_result := event_type in MEASUREMENT_START_EVENTS and _measurement_result_active and _measurement_timer > 0.0 and _measurement_label != null
    var result_text := _measurement_label.text if preserve_result else ""
    var result_time := _measurement_timer
    super._on_sim_event(event)
    if preserve_result:
        _show_measurement_status(result_text, result_time)
    if event_type == "capacity_purchased":
        _show_toast("%s %d台目を増設" % [event.get("label", "設備"), int(event.get("count", 1))])
    if event_type == "measurement_completed":
        _finish_pending_measurement(String(event.get("kind", "")))
        _measurement_result_active = true
        _show_measurement_feedback(event)
        return

    if event_type in MEASUREMENT_START_EVENTS:
        _begin_pending_measurement(event)
        if not _measurement_result_active:
            _measurement_followup_active = false
        _sync_measurement_followup_cta()


func _begin_pending_measurement(event: Dictionary) -> void:
    if sim == null:
        return
    var kind := String(event.get("measurement_kind", event.get("kind", "")))
    var event_type := String(event.get("type", ""))
    if not event.has("measurement_kind"):
        if event_type == "facility_purchased":
            kind = "facility_%s" % kind
        elif event_type == "facility_renovated":
            kind = "renovation_%s" % kind
        elif event_type == "routing_changed":
            kind = "routing_%s" % String(event.get("mode", ""))
    _pending_measurements.append({
        "kind": kind,
        "label": _measurement_name(kind, String(event.get("label", "設備変更"))),
        "started_at": float(event.get("at", sim.sim_time)),
        "window": float(event.get("measurement_window", FlowMeasurement.WINDOW_SECONDS)),
    })
    if not (_measurement_result_active and _measurement_timer > 0.0):
        _measurement_result_active = false
        _style_measurement_state("measuring")
    _refresh_pending_measurements()


func _finish_pending_measurement(kind: String) -> void:
    # Capacity purchases may repeat the same kind: complete only the oldest one.
    for index in _pending_measurements.size():
        if String(_pending_measurements[index]["kind"]) == kind:
            _pending_measurements.remove_at(index)
            return


func _refresh_pending_measurements() -> void:
    if sim == null or _pending_measurements.is_empty():
        return
    # Let completed results keep their reading time, including behind panels.
    if _measurement_result_active and _measurement_timer > 0.0:
        return
    if _measurement_result_active:
        _style_measurement_state("measuring")
    _measurement_result_active = false
    var latest: Dictionary = _pending_measurements.back()
    var remaining := maxi(0, ceili(float(latest["started_at"]) + float(latest["window"]) - sim.sim_time))
    var detail := "前後の観測値を比較｜続けて投資できます"
    if _pending_measurements.size() > 1:
        detail = "ほか%d件も計測中｜複数変更を含む参考値" % (_pending_measurements.size() - 1)
    if sim.time_scale <= 0.0:
        detail = "一時停止中｜再開すると計測が進みます"
    var text := "%s｜効果を計測中\n残り%d秒（ゲーム内時間）\n%s" % [latest["label"], remaining, detail]
    if _measurement_label != null and _measurement_label.text != text:
        _show_measurement_status(text, 1.0)
    else:
        _measurement_timer = 1.0


func _measurement_name(kind: String, fallback: String = "設備変更") -> String:
    var names := {
        "rank1_rack_wing": "棚の増設", "rank1_second_packing_bench": "梱包台の増設",
        "rank1_worker_hire": "作業員採用", "rank1_forklift_project": "フォークリフト",
        "extra_forklift": "フォークリフト2号車", "transfer_conveyor": "搬送コンベア", "packing_cell": "梱包セル増設", "dispatch_lane": "自動出荷レーン増設",
        "facility_fast_pick_rack": "高速棚", "facility_high_density_rack": "高密度棚",
        "facility_parallel_pack": "並列梱包", "facility_fast_pack_cell": "高速梱包",
        "renovation_fast_pick_rack": "高速棚へ改装", "renovation_high_density_rack": "高密度棚へ改装",
        "renovation_parallel_pack": "並列梱包へ改装", "renovation_fast_pack_cell": "高速梱包へ改装",
        "worker": "作業員増員", "rack": "棚の増設", "speed": "搬送訓練", "packing": "梱包強化", "forklift": "フォークリフト",
    }
    return String(names.get(kind, fallback))


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
    var basis := String(verdict.get("basis", "出荷ペース"))
    var basis_key := String(verdict.get("basis_key", "shipments_per_min"))
    var result_line := ""
    if basis_key == "shipments_per_min":
        var direction := "→"
        if state == "improved":
            direction = "↑"
        elif state == "regressed":
            direction = "↓"
        result_line = "%s %s %s/分｜%.1f→%.1f" % [
            headline,
            direction,
            _signed_delta(delta),
            before_rate,
            after_rate,
        ]
    else:
        result_line = "%s｜%s %s→%s｜出荷 %s/分" % [
            headline,
            basis,
            _format_basis_value(verdict, "basis_before"),
            _format_basis_value(verdict, "basis_after"),
            _signed_delta(delta),
        ]
    var action_short := _short_bottleneck_action(bottleneck_key)
    var context_line := "%s｜次:%s" % [
        _compact_context_metric(bottleneck_key, before, after),
        action_short,
    ]
    var action_line := "次: %s" % action_short
    var equipment := _measurement_name(String(event.get("kind", "")))
    var attribution := "複数変更を含む参考値" if int(event.get("overlapping_changes", 0)) > 0 else "前後の観測値"
    var text := "%s後｜%s\n%s\n%s" % [equipment, attribution, result_line, context_line]
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


func _format_basis_value(verdict: Dictionary, field: String) -> String:
    var value := float(verdict.get(field, 0.0))
    var unit := String(verdict.get("basis_unit", ""))
    if unit == "%":
        return "%.0f%%" % (value * 100.0)
    if unit.is_empty():
        return "%.1f" % value
    return "%.1f%s" % [value, unit]


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
