extends SceneTree

var failures := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func settle() -> void:
    for i in 6:
        await process_frame

func run() -> void:
    for dimensions in [Vector2i(375,667), Vector2i(390,844), Vector2i(430,932)]:
        get_root().size = dimensions
        var main := load("res://scenes/main.tscn").instantiate() as Node
        get_root().add_child(main)
        main.set_process(false)
        var sim: FlotraV2Sim = main.get("sim")
        var hud: MobileGameHud
        var view: MobileWarehouseView
        for child in main.get_children():
            if child is MobileGameHud: hud = child
            if child is MobileWarehouseView: view = child
        var routes := view.get_node("SelectedWorkRoutes") as SelectedWorkRoutes
        var clarity := hud.get_node("MobileInteractionClarity") as MobileInteractionClarity
        await settle()
        sim.money = 250000
        sim.purchase_rank1_project(&"rack_wing")
        sim.purchase_rank1_project(&"forklift_project")
        sim.shipped = 20
        sim.purchase_warehouse_expansion()
        for i in 3: sim.purchase_capacity(&"packing_cell", i)
        for i in 2: sim.purchase_capacity(&"dispatch_lane", i)
        sim.inbound_queue = 999
        sim.open_orders = 999
        view.reset_work_overview()
        view._camera_pose_initialized = false
        await settle()
        # Geometry and text-layout checks, not a substitute for rendered review.
        var banner := hud._bottleneck_panel.get_global_rect()
        check(banner.encloses(hud._bottleneck.get_global_rect()), "Pressure text stays within its panel")
        check(hud._bottleneck.get_line_count() <= 2, "Symptom and workload remain two readable lines")
        check(hud._bottleneck.text.contains("次:"), "Wave timing remains available")
        var size := view.get_viewport().get_visible_rect().size
        var safe := Rect2(Vector2(12, 255), Vector2(size.x - 24, size.y - 255 - 200))
        for point in [Vector3(-5.25,0.5,0.15), Vector3(-2.2,0.5,0.15), Vector3(0.25,0.5,0.15), Vector3(2.65,0.5,0.15), Vector3(5.3,0.5,0.15), Vector3(0,0.5,4.5), Vector3(4.6,0.5,4.5), Vector3(7.35,0.5,-1), Vector3(7.35,0.5,1.6), Vector3(-6.5,0,-3.3), Vector3(-6.5,0,3.3), Vector3(-3,3.5,-2.5), Vector3(5.6,1.5,5.5), Vector3(8.55,1.5,-2)]:
            var projected := view._camera.unproject_position(point)
            check(safe.has_point(projected), "Operational target stays inside portrait working area: %s" % point)
        clarity.zone.open_zone("picking")
        clarity.zone.close()
        hud._show_measurement_status("搬送コンベア後｜前後の観測値\n要再判断｜出荷14.4→12.0/分\n入庫6.9→13.9｜次: 入荷確認", 10.0)
        await settle()
        var result := hud._measurement_panel.get_global_rect()
        for button in [routes.overview, routes.toggle]:
            check(button.is_visible_in_tree(), "Camera and route controls remain available with results")
            check(not result.intersects(button.get_global_rect()), "Feedback must not overlap camera/route controls")
            check(hud.get_viewport().get_visible_rect().encloses(button.get_global_rect()), "Displaced controls stay on screen")
        clarity.open_section("staffing")
        await settle()
        check(not routes.overview.visible and not routes.toggle.visible, "Warehouse controls do not cover management")
        hud._sheet.hide()
        clarity.zone.open_zone("packing")
        await settle()
        check(not routes.overview.visible and not routes.toggle.visible, "Warehouse controls do not cover zone actions")
        clarity.zone.close()
        view._camera_distance = 15.0
        await settle()
        for worker in view._worker_nodes:
            check(worker.get_node("RoleLabel").visible, "Close inspection reveals worker role text")
        view.reset_work_overview()
        await settle()
        for worker in view._worker_nodes:
            check(not worker.get_node("RoleLabel").visible, "Overview hides competing worker text")
        main.queue_free()
        await settle()
    print("Portrait readability regression failures=%d" % failures)
    quit(0 if failures == 0 else 1)
