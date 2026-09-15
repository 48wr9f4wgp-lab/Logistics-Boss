extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const FtueCoachScript = preload("res://ui/ftue_coach.gd")


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

    host.queue_free()
    await process_frame
    print("Godot FTUE core loop smoke passed")
    quit(0)
