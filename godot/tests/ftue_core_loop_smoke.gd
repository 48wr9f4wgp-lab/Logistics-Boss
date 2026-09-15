extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const FtueCoachScript = preload("res://ui/ftue_coach.gd")
const FeedbackHudScript = preload("res://ui/game_hud_feedback.gd")


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
    if coach.current_step_key() != "complete":
        _fail("first investment must complete the core-loop FTUE")
        return
    if not coach.body_text().contains("観察") or not coach.body_text().contains("投資") or not coach.body_text().contains("測定"):
        _fail("completion copy must teach the canonical observe-decision-invest-measure loop")
        return

    sim.shipped = 5
    coach.bind_context(sim, manage, policy_buttons, sheet, false)
    if coach.visible:
        _fail("experienced saves must not be forced back through FTUE")
        return

    var hud: FeedbackGameHud = FeedbackHudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame

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
        _fail("measurement result must give a next action")
        return
    var result_lines := String(regressed_feedback.get("text", "")).split("\n")
    if result_lines.size() != 3:
        _fail("measurement feedback must use three-line mobile hierarchy")
        return
    if not String(result_lines[0]).contains("出荷") or not String(result_lines[0]).contains("-11.9"):
        _fail("first measurement line must prioritize the shipment outcome")
        return
    if not String(result_lines[2]).begins_with("次 →"):
        _fail("third measurement line must expose the next action")
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

    hud.queue_free()
    host.queue_free()
    await process_frame
    print("Godot FTUE core loop and investment feedback smoke passed")
    quit(0)
