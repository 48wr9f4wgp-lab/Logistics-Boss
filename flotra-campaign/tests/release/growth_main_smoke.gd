extends SceneTree
const Main=preload("res://prototype/growth_main.gd")
func _initialize():
    run.call_deferred()
func run():
    var main=Main.new()
    main.persistence_enabled=false
    root.add_child(main)
    await process_frame
    main._accept_contract("growth_1")
    assert(main.speed==2.0 and main.running)
    main._set_speed(4.0)
    assert(main.speed==4.0 and main.hud._speed==4.0)
    main._pause_trial(true)
    main.sim.time_scale=0.0
    var before=main.sim.sim_time
    main._pause_trial(false)
    main._process(.1)
    assert(main.sim.sim_time>before and main.sim.time_scale==1.0)
    main._pause_trial(true)
    var state=main.sim.export_release_state()
    main._process(.1)
    assert(state==main.sim.export_release_state())
    main.queue_free()
    await process_frame
    print("GROWTH_MAIN_SMOKE passed default speed, 4x, imported-domain Resume and pause preservation")
    quit()
