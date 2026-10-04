extends SceneTree
## A finger spans frames. Refresh must never transiently disable an enabled
## campaign action, even when the inherited prototype simulation is finished.

const RealSim = preload("res://prototype/release_sim.gd")
class ObservedHud extends "res://prototype/release_hud.gd":
    var work_choice_activations := 0
    func show_job_choices() -> void:
        work_choice_activations += 1
        super.show_job_choices()

var checks := 0
var failures := 0

func _init() -> void:
    run.call_deferred()

func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)

func settle() -> void:
    for i in 4:
        await process_frame

func guard() -> void:
    await settle()
    await create_timer(0.22).timeout

func pointer(point: Vector2, pressed: bool, kind: String) -> InputEvent:
    if kind == "touch":
        var touch := InputEventScreenTouch.new()
        touch.index = 0
        touch.position = point
        touch.pressed = pressed
        return touch
    var mouse := InputEventMouseButton.new()
    mouse.button_index = MOUSE_BUTTON_LEFT
    mouse.position = point
    mouse.global_position = point
    mouse.pressed = pressed
    return mouse

func press_at(point: Vector2, kind: String) -> void:
    if kind == "mouse":
        var motion := InputEventMouseMotion.new()
        motion.position = point
        motion.global_position = point
        root.push_input(motion)
    root.push_input(pointer(point, true, kind))

func refresh_while_held(hud: Node) -> void:
    # Deliberately put refreshes between down and up; same-frame synthetic taps
    # cannot detect BaseButton canceling its press during a transient disable.
    for i in 5:
        hud.refresh()
        await process_frame

func verify_state(sim: Object, label: String) -> void:
    for kind in ["mouse", "touch"]:
        var hud := ObservedHud.new()
        hud.bind_sim(sim)
        root.add_child(hud)
        await settle()
        hud.show_play()
        await guard()
        var button: Button = hud._compare
        var point := button.get_global_rect().get_center()
        var before := hud.work_choice_activations
        var epoch: int = hud._input_epoch
        press_at(point, kind)
        check(button.is_pressed(), "%s/%s: physical down starts a held action" % [label, kind])
        await refresh_while_held(hud)
        check(not button.disabled and button.is_pressed(), "%s/%s: refresh preserves enabled held action" % [label, kind])
        check(hud._input_epoch == epoch, "%s/%s: refresh does not alter dismissal epoch" % [label, kind])
        root.push_input(pointer(point, false, kind))
        await settle()
        check(hud._sheet_kind == "jobs" and hud.work_choice_activations == before + 1, "%s/%s: held release opens work choices exactly once" % [label, kind])
        root.push_input(pointer(point, false, kind))
        await settle()
        check(hud.work_choice_activations == before + 1, "%s/%s: duplicate release never repeats action" % [label, kind])
        hud.show_play()
        await guard()

        # A sheet opened and dismissed while an older background press is held
        # must still invalidate that press, even after the cooldown has elapsed.
        before = hud.work_choice_activations
        press_at(point, kind)
        hud.show_conditions()
        hud.close_sheet()
        await guard()
        await refresh_while_held(hud)
        root.push_input(pointer(point, false, kind))
        await settle()
        check(hud._sheet_kind.is_empty() and hud.work_choice_activations == before, "%s/%s: stale pre-dismissal release stays blocked" % [label, kind])
        await guard()

        for notification in [Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_PAUSED]:
            before = hud.work_choice_activations
            press_at(point, kind)
            root.propagate_notification(notification)
            await refresh_while_held(hud)
            root.push_input(pointer(point, false, kind))
            await settle()
            check(hud._sheet_kind.is_empty() and hud.work_choice_activations == before, "%s/%s: focus interruption %d blocks stale release" % [label, kind, notification])
            root.propagate_notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
            root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
            root.propagate_notification(Node.NOTIFICATION_APPLICATION_RESUMED)
            await guard()
        before = hud.work_choice_activations
        press_at(point, kind)
        await refresh_while_held(hud)
        root.push_input(pointer(point, false, kind))
        await settle()
        check(hud._sheet_kind == "jobs" and hud.work_choice_activations == before + 1, "%s/%s: fresh held action works after interruptions" % [label, kind])
        hud.queue_free()
        await settle()

func finish_contract(sim: Object, id: String) -> void:
    var accepted: Dictionary = sim.accept_contract(id)
    check(bool(accepted.get("ok", false)), "Real campaign accepts " + id)
    var ticks := 0
    while sim.campaign_status == "running" and ticks < 16000:
        sim.step(0.25)
        ticks += 1
    check(sim.campaign_status in ["contract_complete", "campaign_complete"], "Real campaign completes " + id)

func run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(375, 567)
    var sim = RealSim.new()
    await verify_state(sim, "ready")
    finish_contract(sim, "first_shift")
    await verify_state(sim, "contract_complete")
    for id in ["small_orders", "pallet_wave", "packing_rush", "storage_peak", "final_dispatch"]:
        finish_contract(sim, id)
    check(sim.campaign_status == "campaign_complete", "All six real contracts complete")
    await verify_state(sim, "campaign_complete")
    var accepted: Dictionary = sim.accept_contract("first_shift")
    check(bool(accepted.get("ok", false)), "Completed campaign can replay")
    await verify_state(sim, "replay_running")
    var ticks := 0
    while sim.campaign_status == "running" and ticks < 16000:
        sim.step(0.25)
        ticks += 1
    check(sim.campaign_status == "campaign_complete", "Replay preserves full campaign completion")
    await verify_state(sim, "replay_complete")
    print("HOLD_ACROSS_REFRESH %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
