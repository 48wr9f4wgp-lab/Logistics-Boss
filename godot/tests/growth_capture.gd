extends SceneTree
var main: Node
var sim: FlotraV2Sim
var hud: MobileGameHud
var output: String
func _init() -> void:
    call_deferred("run")
func run() -> void:
    output = OS.get_environment("FLOTRA_GROWTH_CAPTURE_DIR")
    assert(not output.is_empty())
    DirAccess.make_dir_recursive_absolute(output)
    get_root().size = Vector2i(390,844)
    main = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(main)
    main.set_process(false) # Drive normal Domain steps; no user save writes.
    sim = main.get("sim") as FlotraV2Sim
    for child in main.get_children():
        if child is MobileGameHud:
            hud = child
    assert(hud != null and sim.money == 5000)
    await capture("growth_00_fresh")
    var milestones := {}
    var captured_work := false
    for i in 3600:
        if not sim.forklift_unlocked and sim.money >= sim.FORKLIFT_PROJECT_COST:
            sim.purchase_rank1_project(&"forklift_project")
            milestones["forklift"] = sim.sim_time
            await capture("growth_01_forklift")
        elif sim.forklift_unlocked and not sim.rank1_project_owned(&"rack_wing") and sim.money >= sim.RACK_WING_COST:
            sim.purchase_rank1_project(&"rack_wing")
        elif sim.facility_rank == 1 and bool(sim.rank1_expansion_readiness()["ready"]):
            sim.purchase_warehouse_expansion()
            milestones["expansion"] = sim.sim_time
            await capture("growth_02_expansion")
        elif sim.facility_rank >= 2 and not sim.conveyor_owned and sim.money >= sim.CONVEYOR_COST:
            sim.purchase_growth_automation(&"transfer_conveyor")
            milestones["conveyor"] = sim.sim_time
        elif sim.conveyor_owned and not sim.extra_forklift_owned and sim.money >= sim.EXTRA_FORKLIFT_COST:
            sim.purchase_growth_automation(&"extra_forklift")
            milestones["extra_forklift"] = sim.sim_time
        sim.step(0.1)
        if sim.extra_forklift_moved >= 1 and sim.conveyor_moved >= 2 and sim._extra_cargo > 0 and sim._conveyor_jobs.size() > 0:
            await capture("growth_03_working_automation")
            captured_work = true
            break
    print("NATURAL_CAPTURE_MILESTONES %s" % str(milestones))
    print("NATURAL_WORK at=%.1fs extra=%d belt=%d" % [sim.sim_time, sim.extra_forklift_moved, sim.conveyor_moved])
    assert(sim.extra_forklift_owned and sim.conveyor_owned and captured_work, "Both working machines must be captured from natural play")
    var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
    clarity.open_section("field")
    await capture("growth_04_field")
    hud._sheet.visible = false
    clarity.zone.open_zone("picking")
    await capture("growth_05_rank2_ui")
    print("Growth actual-main capture PASS; no injected cash or contracts")
    main.queue_free()
    await process_frame
    quit()
func capture(name: String) -> void:
    for i in 30:
        await process_frame
    await RenderingServer.frame_post_draw
    var error := get_root().get_texture().get_image().save_png(output.path_join(name + ".png"))
    assert(error == OK)
