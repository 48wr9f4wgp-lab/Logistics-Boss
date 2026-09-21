extends "res://tests/mobile_notification_clearance_smoke.gd"

func _run() -> void:
    Input.emulate_mouse_from_touch = true
    Input.emulate_touch_from_mouse = false
    await _verify_current_work_after_reassignment()
    for dimensions in [Vector2i(390,844),Vector2i(375,667),Vector2i(430,932)]:
        get_root().size = dimensions
        var c: Dictionary = await _fresh()
        var sim: FlotraV2Sim = c["sim"]
        var hud: MobileGameHud = c["hud"]
        var zone: WarehouseZonePanel = c["zone"]
        var clarity: MobileInteractionClarity = c["clarity"]
        sim.purchase_rank1_project(&"rack_wing");sim.purchase_rank1_project(&"forklift_project")
        sim.shipped = 20;sim.purchase_warehouse_expansion()
        clarity.open_section("staffing")
        await _settle()
        var panel := clarity.staffing
        var original := sim.zone_staffing.duplicate()
        _engine_tap(panel.cards["inbound"]);await _settle()
        _engine_tap(panel.cards["picking"]);await _settle()
        _expect(panel.draft == {"inbound":1,"picking":3,"shipping":1} and sim.zone_staffing == original,"Draft transfers are visible and nonauthoritative")
        _engine_tap(panel.cards["picking"]);await _settle()
        var draft_before := panel.draft.duplicate(true)
        var selected_tab := clarity._tabs["staffing"] as Button
        var activations := {"count":0}
        selected_tab.pressed.connect(func(): activations["count"] += 1)
        _engine_tap(selected_tab);await _settle()
        _expect(activations["count"] == 1,"Same staffing tab receives the actual engine-parsed gesture once")
        _expect(panel.draft == draft_before and panel.expected == original and panel.selected == "picking","Reselecting staffing preserves edited draft and selected source")
        _expect(sim.zone_staffing == original and not panel.apply_button.disabled,"Same-tab gesture neither applies nor discards a valid edit")
        _engine_tap(hud._manage_button);await _settle()
        _expect(not hud._sheet.visible,"Closing the staffing sheet remains available during an edit")
        clarity.open_section("staffing");await _settle()
        _expect(panel.draft == original and panel.expected == original and panel.selected.is_empty(),"Explicitly reopening staffing begins from current assignments")
        _engine_tap(panel.cards["inbound"]);await _settle()
        _engine_tap(panel.cards["picking"]);await _settle()
        hud._mobile_scroll.scroll_vertical = 10000
        await _settle()
        _engine_tap(panel.cancel_button);await _settle()
        _expect(not hud._sheet.visible and sim.zone_staffing == original,"Cancel leaves actual staffing unchanged")
        clarity.open_section("staffing");await _settle()
        _engine_tap(panel.cards["inbound"]);await _settle()
        _engine_tap(panel.cards["picking"]);await _settle()
        hud._mobile_scroll.scroll_vertical = 10000;await _settle()
        _engine_tap(panel.apply_button);await _settle()
        _expect(sim.zone_staffing == {"inbound":1,"picking":3,"shipping":1} and sim.staffing_cooldown == 30 and not hud._sheet.visible,"One parsed finger gesture atomically commits without duplicates")
        for key in ["packing","shipping"]:
            zone.open_zone(key);await _settle()
            var before := sim.money
            var button := zone._capacity_action
            _expect(clarity.router.button_at(button.get_global_rect().get_center()) == button,"Primary addition button stays on screen")
            _engine_tap(button);await _settle()
            _expect(sim.money == before and zone.preview_kind() != &"","Preview doesn't spend")
            _engine_tap(button);await _settle()
            _expect(sim.money < before and not zone.is_open(),"Capacity commit spends once then reveals warehouse")
        _expect(sim.packing_cells == 1 and sim.dispatch_lanes == 1,"No synthetic-mouse duplicate purchase")
        zone.open_zone("packing");await _settle()
        var point := zone._capacity_action.get_global_rect().get_center()
        _touch(point,true);_drag(point+Vector2(0,-45),Vector2(0,-45));_touch(point+Vector2(0,-45),false)
        await _settle()
        _expect(zone.preview_kind() == &"" and sim.packing_cells == 1,"Button-origin drag scrolls without preview or purchase")
        hud.queue_free();await _settle()
    print("Staffing and capacity engine-touch checks finished; failures=%d" % _failures)
    quit(0 if _failures == 0 else 1)

func _verify_current_work_after_reassignment() -> void:
    # Explicit loaded-work fixture: run real reservation, reassignment and
    # completion APIs while observing the warehouse's actual role nodes.
    var sim := SimScript.new() as FlotraV2Sim
    sim.money = 100000
    sim.purchase_rank1_project(&"rack_wing")
    sim.purchase_rank1_project(&"forklift_project")
    sim.shipped = 20
    sim.purchase_warehouse_expansion()
    sim.inbound_queue = 10
    sim.rack_stock = 10
    sim.open_orders = 10
    var worker: Dictionary = sim.workers[1]
    _expect(worker["role"] == "store" and worker["task"] == WarehouseSim.Task.IDLE,"Fixture starts with an idle inbound worker")
    sim._start_task(worker, WarehouseSim.Task.STORE)
    sim._update_workers(float(worker["duration"]) * 0.4)
    var warehouse := preload("res://view/warehouse_view.gd").new() as WarehouseView
    warehouse.bind_sim(sim)
    get_root().add_child(warehouse)
    warehouse.set_process(false)
    warehouse._sync_workers()
    var node := warehouse._worker_nodes[1]
    var label := node.get_node("RoleLabel") as Label3D
    var vest := (node.get_node("RoleVest") as MeshInstance3D).material_override as StandardMaterial3D
    var active_tint := vest.albedo_color
    var active_position := node.position
    var job_before := worker.duplicate(true)
    var queues_before := [sim.inbound_queue,sim.rack_stock,sim.packing_queue,sim.packed_queue,sim.open_orders,sim.shipped,sim.money]
    _expect(label.text == "入庫" and node.get_node("Cargo").visible,"Active store job visibly carries its reserved parcel")
    var result := sim.apply_staffing_distribution({"inbound":1,"picking":3,"shipping":1},sim.zone_staffing.duplicate(true))
    _expect(bool(result.get("ok",false)) and worker["role"] == "pick","Real batch assigns this worker to future picking")
    job_before["role"] = "pick"
    _expect(worker == job_before,"Reassignment retains the complete in-flight job including cargo route and progress")
    warehouse._sync_workers()
    _expect(label.text == "入庫" and vest.albedo_color == active_tint,"Label and vest follow current store work until completion")
    _expect(node.position == active_position and node.get_node("Cargo").visible,"Reassignment does not teleport or hide active cargo")
    _expect(worker == job_before and queues_before == [sim.inbound_queue,sim.rack_stock,sim.packing_queue,sim.packed_queue,sim.open_orders,sim.shipped,sim.money],"Rendering and reassignment cannot mutate job, inventory or earnings")
    sim._update_workers(float(worker["remaining"]))
    warehouse._sync_workers()
    _expect(worker["task"] == WarehouseSim.Task.IDLE and sim.rack_stock == 11,"Original parcel completes into storage exactly once")
    _expect(label.text == "ピッキング・待機" and vest.albedo_color != active_tint and not node.get_node("Cargo").visible,"Completed worker visibly adopts assigned next role while waiting")
    var next_task := sim._choose_task_for_worker(worker)
    _expect(next_task == WarehouseSim.Task.PICK,"Next job comes from the new authoritative role")
    sim._start_task(worker,next_task)
    warehouse._sync_workers()
    _expect(label.text == "ピッキング" and sim.rack_stock == 10 and sim.open_orders == 9,"New picking work gets its own label and real parcel reservation")
    warehouse.queue_free()
    await _settle()

func _drag(position: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = 0
    event.position = position
    event.relative = relative
    get_root().push_input(event, true)
