extends SceneTree
var main: Node
var sim: FlotraV2Sim
var hud: MobileGameHud
var view: MobileWarehouseView
var clarity: MobileInteractionClarity
var directory: String
func _init() -> void: call_deferred("run")
func run() -> void:
    directory = OS.get_environment("FLOTRA_CAPACITY_CAPTURE_DIR")
    assert(not directory.is_empty())
    DirAccess.make_dir_recursive_absolute(directory)
    get_root().size = Vector2i(390,844)
    main = load("res://scenes/main.tscn").instantiate()
    get_root().add_child(main)
    main.set_process(false)
    sim = main.get("sim")
    for child in main.get_children():
        if child is MobileGameHud: hud = child
        if child is MobileWarehouseView: view = child
    clarity = hud.get_node("MobileInteractionClarity")
    # Matched-view mature diagnostic fixture, not a natural-progression time claim.
    sim.money = 250000
    sim.purchase_rank1_project(&"rack_wing");sim.purchase_rank1_project(&"forklift_project")
    sim.shipped = 20;sim.purchase_warehouse_expansion()
    sim.purchase_growth_automation(&"extra_forklift");sim.purchase_growth_automation(&"transfer_conveyor")
    sim.inbound_queue = 30;sim.open_orders = 35;sim.packing_queue = 20;sim.packed_queue = 12
    view.reset_work_overview()
    for i in 50: sim.step(0.1)
    if clarity.coach != null: clarity.coach.visible = false;clarity.coach.set_process(false)
    hud._show_toast("");hud._toast_timer = 0;hud._measurement_timer = 0
    await capture("capacity_00_before")
    sim.purchase_capacity(&"packing_cell",0)
    sim.step(0.1)
    await capture("capacity_01_first_cell")
    sim.purchase_capacity(&"dispatch_lane",0)
    sim.purchase_capacity(&"packing_cell",1)
    sim.purchase_capacity(&"dispatch_lane",1)
    sim.purchase_capacity(&"packing_cell",2)
    sim.step(0.1)
    await capture("capacity_02_five_additions")
    await physics_frame
    await physics_frame
    var picker: WarehouseZoneInteractionView
    for child in view.get_children():
        if child is WarehouseZoneInteractionView: picker = child
    assert(picker != null)
    for point in CapacityGrowthView.CELL_POS:
        assert(picker.pick_zone_from_ray(point + Vector3(0,8,0), point + Vector3(0,-1,0)) == "packing", "New packing equipment must route to its real Zone")
    for point in CapacityGrowthView.LANE_POS:
        assert(picker.pick_zone_from_ray(point + Vector3(0,8,0), point + Vector3(0,-1,0)) == "shipping", "New dispatch equipment must route to its real Zone")
    clarity.open_section("staffing")
    await capture("capacity_03_staffing")
    clarity.staffing._choose("inbound");clarity.staffing._choose("picking")
    await capture("capacity_04_staffing_draft")
    hud._sheet.visible = false
    clarity.zone.open_zone("packing")
    await capture("capacity_05_zone")
    clarity.zone.close()
    clarity.zone.open_zone("picking");clarity.zone.close()
    await capture("capacity_06_selected_route")
    # Real runtime motion on a fixed timestep; output only on explicit capture flag.
    if OS.get_environment("FLOTRA_CAPACITY_MOTION") == "1":
        for i in 120:
            sim.step(1.0/20.0)
            await process_frame
            await RenderingServer.frame_post_draw
            assert(get_root().get_texture().get_image().save_png(directory.path_join("motion_%04d.png" % i)) == OK)
    print("Capacity actual-main capture PASS; matched camera; diagnostic fixture only")
    main.queue_free();await process_frame;quit()
func capture(name: String) -> void:
    for i in 15: await process_frame
    await RenderingServer.frame_post_draw
    assert(get_root().get_texture().get_image().save_png(directory.path_join(name+".png")) == OK)
