extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const FtueCoachScript = preload("res://ui/ftue_coach.gd")
const ReleaseHudScript = preload("res://ui/game_hud_release.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = WarehouseSimScript.new()
    var host := Control.new()
    get_root().add_child(host)

    var manage := Button.new()
    var flow := Button.new()
    var inbound := Button.new()
    var outbound := Button.new()
    var sheet := PanelContainer.new()
    sheet.visible = false
    host.add_child(manage)
    host.add_child(flow)
    host.add_child(inbound)
    host.add_child(outbound)
    host.add_child(sheet)

    var coach: LogisticsFtueCoach = FtueCoachScript.new()
    host.add_child(coach)
    await process_frame

    var policy_buttons: Array[Button] = [flow, inbound, outbound]
    coach.bind_context(sim, manage, policy_buttons, sheet, false)
    if not coach.visible or coach.current_step_key() != "observe":
        _fail("fresh save must start the observation FTUE")
        return
    if coach.offset_top > 170.0 or (coach.offset_bottom - coach.offset_top) > 68.0:
        _fail("FTUE coach must stay compact and below the always-on HUD so it does not cover the warehouse core")
        return
    if coach.offset_bottom > 218.0:
        _fail("FTUE coach must stay above the mobile Management sheet at the 390x844 reference viewport")
        return

    coach._process(8.0)
    if coach.current_step_key() != "policy":
        _fail("FTUE must progress from observation to operating policy")
        return

    sim.set_policy(WarehouseSim.Policy.INBOUND)
    if coach.current_step_key() != "manage":
        _fail("changing policy must advance FTUE to management")
        return

    sheet.visible = true
    manage.emit_signal("pressed")
    await process_frame
    if coach.current_step_key() != "invest":
        _fail("opening management must advance FTUE to investment")
        return

    var purchase: Dictionary = sim.purchase_upgrade(&"speed")
    if not bool(purchase.get("ok", false)):
        _fail("FTUE smoke must be able to purchase a starter upgrade")
        return
    if coach.current_step_key() != "invest":
        _fail("first investment must keep FTUE active until the measured result is visible")
        return
    if not coach.body_text().contains("計測中") or not coach.body_text().contains("改善"):
        _fail("post-investment FTUE must tell the player to observe and read the measurement verdict")
        return

    for _index in range(260):
        sim.step(0.1)
    if coach.current_step_key() != "complete":
        _fail("FTUE must complete only after the real 25-second measurement result arrives")
        return
    if not coach.body_text().contains("観察") or not coach.body_text().contains("投資") or not coach.body_text().contains("測定"):
        _fail("completion copy must teach the canonical observe-decision-invest-measure loop")
        return

    sim.shipped = 5
    coach.bind_context(sim, manage, policy_buttons, sheet, false)
    if coach.visible:
        _fail("experienced saves must not be forced back through FTUE")
        return

    var hud: ReleaseGameHud = ReleaseHudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame
    if hud._bottleneck_panel == null:
        _fail("release HUD must expose the bottleneck director panel")
        return
    if coach.offset_top < hud._bottleneck_panel.offset_bottom + 4.0:
        _fail("FTUE coach must not overlap the release bottleneck director panel")
        return

    var regressed := {
        "type": "measurement_completed",
        "before": {
            "shipments_per_min": 50.4,
            "inbound_queue": 0.3,
            "packing_queue": 2.6,
        },
        "after": {
            "shipments_per_min": 38.5,
            "inbound_queue": 0.2,
            "packing_queue": 2.4,
        },
    }
    var regressed_feedback: Dictionary = hud.measurement_feedback(regressed)
    if String(regressed_feedback.get("state", "")) != "regressed":
        _fail("material shipment decline must be classified as regressed")
        return
    if not String(regressed_feedback.get("text", "")).contains("要再判断"):
        _fail("regressed result must give the player an explicit judgment")
        return
    if not String(regressed_feedback.get("text", "")).contains("-11.9"):
        _fail("regressed result must show shipment delta")
        return
    if not String(regressed_feedback.get("next_action", "")).begins_with("次:"):
        _fail("measurement result must give the player a next action")
        return
    var result_lines := String(regressed_feedback.get("text", "")).split("\n")
    if result_lines.size() != 3:
        _fail("measurement feedback must name the investment then show result and context on three compact lines")
        return
    if not String(result_lines[1]).contains("-11.9/分") or not String(result_lines[1]).contains("50.4→38.5"):
        _fail("first measurement line must prioritize the shipment delta and before-to-after rate")
        return
    if not String(result_lines[2]).contains("次:"):
        _fail("second measurement line must expose compact context and the next action")
        return

    var improved := regressed.duplicate(true)
    improved["before"]["shipments_per_min"] = 20.0
    improved["after"]["shipments_per_min"] = 26.0
    if String(hud.measurement_feedback(improved).get("state", "")) != "improved":
        _fail("material shipment increase must be classified as improved")
        return

    var flat := regressed.duplicate(true)
    flat["before"]["shipments_per_min"] = 20.0
    flat["after"]["shipments_per_min"] = 20.4
    if String(hud.measurement_feedback(flat).get("state", "")) != "flat":
        _fail("small measurement noise must be classified as flat")
        return

    hud._on_sim_event(regressed)
    if hud._measurement_label == null or not hud._measurement_label.text.contains("要再判断"):
        _fail("completed measurement event must render actionable feedback in the HUD")
        return
    if hud._measurement_label.get_theme_font_size("font_size") < 12:
        _fail("completed measurement feedback must remain legible on mobile")
        return
    if not hud._measurement_followup_active or hud._manage_button.text != "次の判断":
        _fail("regressed measurement must promote Management into an explicit next-decision CTA")
        return

    hud._manage_button.emit_signal("pressed")
    await process_frame
    hud._process(0.0)
    if not hud._sheet.visible:
        _fail("measurement follow-up CTA must open Management")
        return
    if hud._measurement_followup_active or hud._manage_button.text != "閉じる":
        _fail("opening Management must consume the measurement follow-up CTA")
        return

    hud._manage_button.emit_signal("pressed")
    await process_frame
    hud._process(0.0)
    if hud._sheet.visible or hud._manage_button.text != "管理":
        _fail("closing Management after follow-up must restore the normal control label")
        return

    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0
    hud._on_sim_event(improved)
    hud._process(0.0)
    if hud._measurement_followup_active or hud._manage_button.text != "管理":
        _fail("improved stable flow should return the player to observation without forcing another decision")
        return

    sim.packing_queue = 3
    hud._on_sim_event(improved)
    hud._process(0.0)
    if not hud._measurement_followup_active or hud._manage_button.text != "次の判断":
        _fail("an improved result with a new bottleneck must still guide the player into the next decision")
        return

    # End-to-end regression: use a separate fresh simulation and only production
    # controls/events. This closes observe -> decide -> invest -> measure -> decide
    # through the real 25-second FlowMeasurement path rather than a synthetic event.
    var e2e_sim = WarehouseSimScript.new()
    var e2e_events: Array[Dictionary] = []
    e2e_sim.event_emitted.connect(func(event: Dictionary):
        e2e_events.append(event.duplicate(true))
    )
    e2e_sim.money += 100000
    for _index in range(300):
        e2e_sim.step(0.1)

    var e2e_hud: ReleaseGameHud = ReleaseHudScript.new()
    get_root().add_child(e2e_hud)
    await process_frame
    e2e_hud.bind_sim(e2e_sim)
    await process_frame

    _force_packing_bottleneck(e2e_sim)
    e2e_hud._render()
    if e2e_hud._bottleneck == null or not e2e_hud._bottleneck.text.contains("梱包"):
        _fail("E2E core loop must begin from a readable observed packing symptom")
        return
    if e2e_hud._bottleneck.text.contains("強化") or e2e_hud._bottleneck.text.contains("→"):
        _fail("v2 Director must not reveal the action answer during observation")
        return

    e2e_hud._sync_measurement_followup_cta()
    if e2e_hud._manage_button == null or e2e_hud._manage_button.text != "管理":
        _fail("E2E core loop must expose the normal Management decision control")
        return
    e2e_hud._manage_button.emit_signal("pressed")
    await process_frame
    if e2e_hud._sheet == null or not e2e_hud._sheet.visible:
        _fail("E2E Management control must open the real decision surface")
        return

    var speed_button := e2e_hud._upgrade_buttons.get(&"speed") as Button
    if speed_button == null or not speed_button.visible:
        _fail("E2E Rank 1 Management must expose the flow-training investment")
        return
    var money_before: int = int(e2e_sim.money)
    speed_button.emit_signal("pressed")
    await process_frame
    if e2e_sim.money >= money_before:
        _fail("E2E investment must spend authoritative Domain cash")
        return
    if not _has_event(e2e_events, "upgrade_purchased", "speed"):
        _fail("E2E investment must emit the authoritative upgrade event")
        return
    if e2e_hud._measurement_label == null or not e2e_hud._measurement_label.text.contains("計測中"):
        _fail("E2E investment must immediately enter the visible measurement phase")
        return

    e2e_hud._manage_button.emit_signal("pressed")
    await process_frame
    if e2e_hud._sheet.visible:
        _fail("E2E player must be able to return to warehouse observation while measuring")
        return

    for index in range(260):
        if index >= 235:
            _force_packing_bottleneck(e2e_sim)
        e2e_sim.step(0.1)
    await process_frame

    var measurement: Dictionary = _latest_measurement(e2e_events, "speed")
    if measurement.is_empty():
        _fail("E2E real investment must complete a 25-second measurement event")
        return
    if absf(float(measurement.get("window_seconds", 0.0)) - 25.0) > 0.01:
        _fail("E2E measurement must retain the canonical 25-second after-window")
        return

    var verdict: Dictionary = measurement.get("verdict", {})
    var verdict_state := String(verdict.get("state", ""))
    if verdict_state not in ["improved", "flat", "regressed"]:
        _fail("E2E completed measurement must carry an authoritative verdict")
        return
    var verdict_headline := String(verdict.get("headline", ""))
    if verdict_headline.is_empty():
        _fail("E2E completed measurement must expose a player-facing judgment")
        return

    _force_packing_bottleneck(e2e_sim)
    e2e_hud._render()
    var e2e_feedback: Dictionary = e2e_hud.measurement_feedback(measurement)
    if String(e2e_feedback.get("bottleneck_key", "")) != "packing":
        _fail("E2E result must read the current authoritative packing bottleneck")
        return
    if not bool(e2e_feedback.get("needs_followup", false)):
        _fail("E2E remaining bottleneck must request another operational decision")
        return
    if e2e_hud._measurement_panel == null or not e2e_hud._measurement_panel.visible:
        _fail("E2E completed measurement must remain visible long enough to be read")
        return
    if not e2e_hud._measurement_label.text.contains(verdict_headline):
        _fail("E2E HUD result must render the authoritative Domain verdict")
        return

    e2e_hud._sync_measurement_followup_cta()
    if not e2e_hud._measurement_followup_active or e2e_hud._manage_button.text != "次の判断":
        _fail("E2E measurement must close the canonical loop into the next decision CTA")
        return

    e2e_hud._manage_button.emit_signal("pressed")
    await process_frame
    e2e_hud._process(0.0)
    if not e2e_hud._sheet.visible:
        _fail("E2E next-decision CTA must reopen Management")
        return
    if e2e_hud._measurement_followup_active:
        _fail("E2E opening Management must consume the follow-up CTA state")
        return

    e2e_hud._manage_button.emit_signal("pressed")
    await process_frame
    e2e_hud._process(0.0)
    if e2e_hud._manage_button.text != "管理":
        _fail("E2E acknowledged decision must return the persistent control to normal")
        return

    e2e_hud.queue_free()
    hud.queue_free()
    host.queue_free()
    await process_frame
    print("Godot FTUE and canonical core loop E2E smoke passed")
    quit(0)


func _force_packing_bottleneck(sim) -> void:
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 40
    sim.packed_queue = 0
    sim.open_orders = 0


func _has_event(events: Array[Dictionary], event_type: String, kind: String) -> bool:
    for event in events:
        if String(event.get("type", "")) == event_type and String(event.get("kind", "")) == kind:
            return true
    return false


func _latest_measurement(events: Array[Dictionary], kind: String) -> Dictionary:
    for index in range(events.size() - 1, -1, -1):
        var event: Dictionary = events[index]
        if String(event.get("type", "")) == "measurement_completed" and String(event.get("kind", "")) == kind:
            return event
    return {}
