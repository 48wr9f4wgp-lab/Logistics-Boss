extends SceneTree

const MainScript = preload("res://main.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var main = MainScript.new()
    get_root().add_child(main)
    await process_frame
    await process_frame

    if main.sim == null:
        _fail("runtime startup must create an authoritative simulation")
        return

    var hud = null
    for child in main.get_children():
        if child is GameHud:
            hud = child
            break
    if hud == null:
        _fail("runtime startup must attach the gameplay HUD")
        return
    if hud.sim == null:
        _fail("runtime startup must bind simulation to HUD")
        return
    if hud._money == null or hud._money.text == "—":
        _fail("runtime HUD must render live money instead of placeholder")
        return

    var before_time := float(main.sim.sim_time)
    await create_timer(0.25).timeout
    if float(main.sim.sim_time) <= before_time:
        _fail("runtime simulation clock must advance after startup")
        return

    main.queue_free()
    await process_frame
    print("Godot runtime startup smoke passed")
    quit(0)
