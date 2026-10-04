extends SceneTree
## Scene-level preferences and rendering are tested separately from save-domain QA.
const Main = preload("res://prototype/growth_main.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)
        push_error(label)
func _initialize() -> void:
    run.call_deferred()
func settle() -> void:
    for frame in 3: await process_frame
func advance(main, clock: Dictionary, seconds: float) -> void:
    clock.now += roundi(seconds * 1000000.0)
    main._process(seconds)
func run() -> void:
    root.size = Vector2i(390,844)
    var clock := {"now":1000000}
    var main = Main.new()
    main.persistence_enabled = false
    main.frame_clock = func() -> int: return int(clock.now)
    root.add_child(main)
    await settle()
    main.set_process(false)
    main.hud.close_sheet()
    main.hud.close_sheet()
    check(not main.running, "Closing first-use guidance never advances an empty warehouse")
    main._accept_contract("growth_1")
    advance(main,clock,.1)
    check(main.running and main.sim.sim_time>0, "Actual scene starts an accepted paid job")
    main._set_speed(4.0)
    check(main.speed==4 and main.sim.preferences.preferred_speed==4, "Speed goes through scene and persistent preference")
    main._set_preference("pause_on_menus",true)
    main.hud.show_controls()
    var before: Dictionary = main.sim.export_release_state()
    advance(main,clock,.2)
    check(main._menu_paused and main.running, "Menu pause retains the explicit run intent")
    check(main.sim.export_release_state()==before, "Menu pause never changes cargo, clocks or reservations")
    check(not main.viewport_container.visible, "Full-height control sheet suspends hidden 3D drawing")
    main.hud.close_sheet()
    advance(main,clock,.1)
    check(main.sim.sim_time>before.sim.sim_time and not main._menu_paused, "Closing the menu resumes a previously running warehouse")
    main._pause_trial(true)
    main.hud.show_controls()
    main.hud.close_sheet()
    before=main.sim.export_release_state()
    advance(main,clock,.2)
    check(not main.running and main.sim.export_release_state()==before, "Closing a menu never undoes manual pause")
    main._set_preference("reduced_motion",true)
    check(main.world.reduced_motion, "Reduced-motion preference reaches the renderer")
    main._pause_trial(false)
    advance(main,clock,.3)
    for actor in main.world._actors.values():
        check(is_zero_approx(actor.get_node("LeftLeg").rotation.x) and is_zero_approx(actor.get_node("RightLeg").rotation.x), "Reduced motion removes decorative walking swing")
    var reduced_state: Dictionary = main.sim.export_release_state()
    main._set_preference("reduced_motion",false)
    check(main.sim.export_release_state().sim==reduced_state.sim, "Visual setting never changes logistics")
    main._notification(Main.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    before=main.sim.export_release_state()
    advance(main,clock,.2)
    check(not main.running and not main.hud._trial_running, "Backgrounding pauses both scene and visible playback state")
    check(main.sim.export_release_state()==before, "Backgrounded warehouse does not silently advance")
    main._notification(Main.NOTIFICATION_WM_WINDOW_FOCUS_IN)
    advance(main,clock,.2)
    check(main.sim.export_release_state()==before, "Foreground return requires explicit Resume")
    main._pause_trial(false)
    advance(main,clock,.1)
    check(main.sim.sim_time>before.sim.sim_time, "Explicit Resume continues preserved work")
    main._pause_trial(true)
    main.hud.show_controls()
    check(not main.viewport_container.visible or main.hud._sheet_kind=="controls", "Control sheet remains connected")
    main.queue_free()
    await settle()
    print(JSON.stringify({"suite":"experience_scene_regression","checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
