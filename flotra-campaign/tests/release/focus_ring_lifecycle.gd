extends SceneTree
## Regression for stale modal focus paths during actual protection transitions.
const Main = preload("res://prototype/growth_main.gd")
var checks := 0
var failures: Array[String] = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)
        push_error(label)
func settle() -> void:
    for frame in 4: await process_frame
func key(code: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = code
    event.physical_keycode = code
    event.pressed = true
    root.push_input(event)
    event = event.duplicate()
    event.pressed = false
    root.push_input(event)
    await process_frame
func run() -> void:
    var app := Main.new()
    app.persistence_enabled = false
    root.add_child(app)
    app.set_process(false)
    await settle()
    var hud = app.hud
    check(not hud._focus_buttons(hud._sheet).is_empty(), "Intro owns an explicit focus ring")
    var old_ring: Array = hud._focus_buttons(hud._sheet)
    var before := var_to_bytes(app.sim.export_release_state())
    hud.show_save_protection("再読み込みが必要です")
    await settle()
    check(hud._sheet_kind == "save_protection", "Actual protection modal replaces intro")
    check(hud._focus_buttons(hud._sheet).is_empty(), "Disabled protection controls retain no focus ring")
    for button in old_ring:
        if is_instance_valid(button):
            check(button.focus_next.is_empty() and button.focus_previous.is_empty(), "Surviving old buttons have no paths into freed intro nodes")
    for button in [hud._back, hud._pause, hud._close]:
        check(button.disabled, "Protection control stays disabled")
        check(button.focus_next.is_empty() and button.focus_previous.is_empty(), "Disabled protection control has no stale focus links")
    for attempt in 6:
        await key(KEY_TAB)
        await key(KEY_ENTER)
    check(hud._sheet_kind == "save_protection", "Keyboard cannot reopen or activate the retired intro")
    check(before == var_to_bytes(app.sim.export_release_state()), "Keyboard and focus transition preserve complete campaign state")
    app.queue_free()
    await settle()
    print("FOCUS_RING_LIFECYCLE ", JSON.stringify({"checks": checks, "failures": failures}))
    quit(0 if failures.is_empty() else 1)
