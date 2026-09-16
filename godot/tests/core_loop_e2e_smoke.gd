extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const ReleaseHudScript = preload("res://ui/game_hud_release.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim = SimScript.new()
    var events: Array[Dictionary] = []
    sim.event_emitted.connect(func(event: Dictionary):
        events.append(event.duplicate(true))
    )

    # Build a complete 25-second baseline before the player invests so this
    # exercises the production Before/After path rather than a synthetic event.
    sim.money += 100000
    for _index in range(300):
        sim.step(0.1)

    var hud: ReleaseGameHud = ReleaseHudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame

    # OBSERVE: expose a concrete physical-flow problem through the shipped HUD.
    _force_packing_bottleneck(sim)
    hud._render()
    if hud._bottleneck == null or not hud._bottleneck.text.contains("梱包"):
        _fail("core loop must begin with a readable observed bottleneck")
        return

    # DECIDE: the player opens the real Management sheet through the persistent
    # release control rather than invoking an internal purchase method directly.
    hud._sync_measurement_followup_cta()
    if hud._manage_button == null or hud._manage_button.text != "管理":
        _fail("stable pre-investment state must expose the normal Management decision control")
        return
    hud._manage_button.emit_signal("pressed")
    await process_frame
    if hud._sheet == null or not hud._sheet.visible:
        _fail("Management control must open the real decision surface")
        return

    # INVEST: trigger a real Rank 1 capital button so Domain mutation, event
    # emission, measurement startup and HUD measuring state all run together.
    var speed_button := hud._upgrade_buttons.get(&"speed") as Button
    if speed_button == null or not speed_button.visible:
        _fail("Rank 1 Management must expose the flow-training investment")
        return
    var money_before := sim.money
    speed_button.emit_signal("pressed")
    await process_frame
    if sim.money >= money_before:
        _fail("real investment must spend authoritative Domain cash")
        return
    if not _has_event(events, "upgrade_purchased", "speed"):
        _fail("real investment must emit the authoritative upgrade event")
        return
    if hud._measurement_label == null or not hud._measurement_label.text.contains("計測中"):
        _fail("investment must immediately enter the visible measurement phase")
        return

    # Return to the warehouse while the after-window runs, matching the intended
    # observe -> invest -> observe flow instead of leaving Management forced open.
    hud._manage_button.emit_signal("pressed")
    await process_frame
    if hud._sheet.visible:
        _fail("player must be able to close Management and observe the live operation")
        return

    # MEASURE: advance the actual simulation beyond the canonical 25-second
    # after-window. Keep a strong packing queue near completion so the result has
    # a concrete next operational decision regardless of throughput verdict.
    for index in range(260):
        if index >= 235:
            _force_packing_bottleneck(sim)
        sim.step(0.1)

    await process_frame

    var measurement := _latest_measurement(events, "speed")
    if measurement.is_empty():
        _fail("real investment must complete a 25-second measurement event")
        return
    if absf(float(measurement.get("window_seconds", 0.0)) - 25.0) > 0.01:
        _fail("core loop measurement must retain the canonical 25-second window")
        return

    var verdict: Dictionary = measurement.get("verdict", {})
    var state := String(verdict.get("state", ""))
    if state not in ["improved", "flat", "regressed"]:
        _fail("completed measurement must carry an authoritative verdict")
        return
    var headline := String(verdict.get("headline", ""))
    if headline.is_empty():
        _fail("completed measurement verdict must provide a player-facing judgment")
        return

    # RESULT -> NEXT DECISION: the same real event must render its judgment and
    # promote the existing Management control when a live bottleneck remains.
    _force_packing_bottleneck(sim)
    hud._render()
    var feedback: Dictionary = hud.measurement_feedback(measurement)
    if String(feedback.get("bottleneck_key", "")) != "packing":
        _fail("measurement result must read the current authoritative packing bottleneck")
        return
    if not bool(feedback.get("needs_followup", false)):
        _fail("live post-measurement bottleneck must request another operational decision")
        return
    if hud._measurement_panel == null or not hud._measurement_panel.visible:
        _fail("completed measurement must remain visible long enough to be read")
        return
    if not hud._measurement_label.text.contains(headline):
        _fail("HUD result must render the authoritative Domain verdict")
        return

    hud._sync_measurement_followup_cta()
    if not hud._measurement_followup_active or hud._manage_button.text != "次の判断":
        _fail("measurement with a remaining bottleneck must close the loop into the next decision CTA")
        return

    hud._manage_button.emit_signal("pressed")
    await process_frame
    if not hud._sheet.visible:
        _fail("next-decision CTA must reopen Management")
        return
    if hud._measurement_followup_active:
        _fail("opening Management must consume the follow-up CTA state")
        return

    hud._manage_button.emit_signal("pressed")
    await process_frame
    hud._sync_measurement_followup_cta()
    if hud._manage_button.text != "管理":
        _fail("after the next decision is acknowledged, the persistent control must return to normal")
        return

    hud.queue_free()
    await process_frame
    print("Godot canonical core loop E2E smoke passed")
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
