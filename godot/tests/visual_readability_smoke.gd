extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const FlowMeasurementScript = preload("res://domain/flow_measurement.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseQueuePressureViewScript = preload("res://view/queue_pressure_view.gd")
const WarehouseInvestmentFeedbackViewScript = preload("res://view/investment_feedback_view.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const MobileHudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var root := Node3D.new()
    get_root().add_child(root)

    var sim = WarehouseSimScript.new()

    var view: WarehouseView = WarehouseViewScript.new()
    root.add_child(view)
    view.bind_sim(sim)

    var pass2: WarehouseVisualPass2 = WarehouseVisualPass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)

    var hud: MobileGameHud = MobileHudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)

    var pass3: WarehouseVisualPass3 = WarehouseVisualPass3Script.new()
    view.add_child(pass3)
    pass3.bind(view, hud)

    var queue_pressure: WarehouseQueuePressureView = WarehouseQueuePressureViewScript.new()
    view.add_child(queue_pressure)
    queue_pressure.bind(view, sim)

    var investment_feedback: WarehouseInvestmentFeedbackView = WarehouseInvestmentFeedbackViewScript.new()
    view.add_child(investment_feedback)
    investment_feedback.bind(view, sim)

    var composition: WarehouseVisualCompositionFix = WarehouseVisualCompositionFixScript.new()
    view.add_child(composition)
    composition.bind(view)

    await process_frame
    await process_frame

    var roof_nodes := view.find_children("Roof*", "Node3D", true, false)
    assert(roof_nodes.is_empty(), "open-top warehouse must not generate roof trusses or roof lights")

    var utility_nodes := view.find_children("Utility*", "Node3D", true, false)
    assert(utility_nodes.is_empty(), "open-top warehouse must not generate overhead utility bars")

    var left_wall := view.get_node_or_null("LeftWall") as Node3D
    assert(left_wall != null, "readability smoke expects the base facility left wall")
    assert(not left_wall.visible, "foreground side wall must not block the portrait cutaway view")

    # Full runtime composition guard: visual passes must not overwrite the compact
    # shipped HUD after its responsive layout has been applied.
    assert(hud._bottleneck_panel != null, "mobile release HUD must build the bottleneck director")
    assert(hud._bottleneck_panel.offset_bottom <= 123.0, "3D visual passes must not expand the permanent command HUD")
    var money_panel := hud._money.get_parent().get_parent() as Control
    var top_row := money_panel.get_parent() as Control
    assert(top_row.offset_bottom <= 87.0, "live metric row must retain the compact release layout in full runtime composition")

    # Physical queue density must mirror Domain counts rather than decorative state.
    _set_stable(sim)
    queue_pressure._sync_queues()
    var stable_counts: Dictionary = queue_pressure.visible_backlog_counts()
    assert(int(stable_counts.get("packing", -1)) == 0, "stable packing must not show a fake parcel backlog")
    assert(int(stable_counts.get("orders", -1)) == 0, "stable order flow must not show fake pick totes")

    sim.packing_queue = 7
    sim.open_orders = 6
    queue_pressure._sync_queues()
    var live_counts: Dictionary = queue_pressure.visible_backlog_counts()
    assert(int(live_counts.get("packing", -1)) == 7, "packing queue density must mirror authoritative packing backlog")
    assert(int(live_counts.get("orders", -1)) == 6, "order tote density must mirror authoritative open orders")

    sim.packing_queue = 99
    sim.open_orders = 99
    queue_pressure._sync_queues()
    var capped_counts: Dictionary = queue_pressure.visible_backlog_counts()
    assert(int(capped_counts.get("packing", -1)) == WarehouseQueuePressureView.PACKING_VISUAL_CAP, "packing density must stay capped for mobile performance")
    assert(int(capped_counts.get("orders", -1)) == WarehouseQueuePressureView.ORDER_VISUAL_CAP, "order density must stay capped for mobile performance")

    # Investment feedback must react to authoritative Domain events at the affected
    # physical zone. Rank promotion is intentionally broader than ordinary capital.
    assert(investment_feedback.feedback_count == 0, "fresh runtime must not fabricate investment feedback")

    sim.emit_signal("event_emitted", {
        "type": "upgrade_purchased",
        "kind": "packing",
    })
    await process_frame
    assert(investment_feedback.feedback_count == 1, "capital purchase must create in-world visual feedback")
    assert(investment_feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.PACKING_CENTER) < 0.01, "packing investment must pulse the packing cell")
    assert(investment_feedback.last_half_extents.x < 3.0, "ordinary capital feedback must remain local")

    sim.emit_signal("event_emitted", {
        "type": "facility_purchased",
        "group": "storage",
        "kind": "fast_pick_rack",
    })
    await process_frame
    assert(investment_feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.STORAGE_CENTER) < 0.01, "storage facility purchase must pulse storage")

    sim.emit_signal("event_emitted", {
        "type": "receiving_annex_purchased",
        "kind": "receiving_annex",
    })
    await process_frame
    assert(investment_feedback.last_center.z > 5.0, "Receiving Annex purchase must pulse the physical annex area")

    sim.emit_signal("event_emitted", {
        "type": "rank_up",
        "rank": 3,
        "name": "Fulfillment Center",
    })
    await process_frame
    assert(investment_feedback.last_event_type == "rank_up", "rank promotion must use dedicated promotion feedback")
    assert(investment_feedback.last_half_extents.x >= 7.0 and investment_feedback.last_half_extents.y >= 4.5, "rank promotion must outline the whole facility footprint")
    assert(investment_feedback.last_lifetime > WarehouseInvestmentFeedbackView.INVESTMENT_LIFETIME, "rank promotion must feel more substantial than an ordinary purchase")

    # Completed investment measurement must return to the affected physical zone,
    # with semantic result colors shared with the HUD verdict.
    var improved_before := {"shipments_per_min": 20.0}
    var improved_after := {"shipments_per_min": 22.0}
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "kind": "packing",
        "before": improved_before,
        "after": improved_after,
        "verdict": FlowMeasurementScript.classify_result(improved_before, improved_after),
    })
    await process_frame
    assert(investment_feedback.last_result_state == "improved", "improved measurement must create positive in-world result feedback")
    assert(investment_feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.PACKING_CENTER) < 0.01, "packing measurement result must return to the packing zone")
    var improved_color: Color = investment_feedback.last_color

    var flat_before := {"shipments_per_min": 50.0}
    var flat_after := {"shipments_per_min": 50.6}
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "kind": "facility_fast_pick_rack",
        "before": flat_before,
        "after": flat_after,
        "verdict": FlowMeasurementScript.classify_result(flat_before, flat_after),
    })
    await process_frame
    assert(investment_feedback.last_result_state == "flat", "flat measurement must create neutral in-world result feedback")
    assert(investment_feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.STORAGE_CENTER) < 0.01, "storage measurement result must return to storage")
    var flat_color: Color = investment_feedback.last_color

    var regressed_before := {"shipments_per_min": 20.0}
    var regressed_after := {"shipments_per_min": 18.0}
    sim.emit_signal("event_emitted", {
        "type": "measurement_completed",
        "kind": "routing_express",
        "before": regressed_before,
        "after": regressed_after,
        "verdict": FlowMeasurementScript.classify_result(regressed_before, regressed_after),
    })
    await process_frame
    assert(investment_feedback.last_result_state == "regressed", "regressed measurement must create cautionary in-world result feedback")
    assert(investment_feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.OUTBOUND_CENTER) < 0.01, "routing measurement result must return to outbound")
    var regressed_color: Color = investment_feedback.last_color
    assert(improved_color != flat_color and flat_color != regressed_color and improved_color != regressed_color, "improved, flat and regressed results must remain visually distinct")

    for index in range(10):
        sim.emit_signal("event_emitted", {
            "type": "upgrade_purchased",
            "kind": "worker" if index % 2 == 0 else "speed",
        })
    await process_frame
    assert(investment_feedback.active_pulse_count() <= WarehouseInvestmentFeedbackView.MAX_ACTIVE_PULSES, "rapid purchases must keep feedback node cost bounded")

    # The in-world status layer must mirror the authoritative domain bottleneck.
    assert(pass3._flow_signals.size() == 5, "warehouse must expose one operational signal for each bottleneck family")

    _set_stable(sim)
    sim.inbound_queue = 8
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "inbound") > _signal_energy(pass3, "rack"), "inbound congestion must highlight the inbound zone in 3D")

    _set_stable(sim)
    sim.rack_stock = sim.rack_capacity
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "rack") > _signal_energy(pass3, "packing"), "storage pressure must highlight the rack zone in 3D")

    _set_stable(sim)
    sim.packing_queue = 3
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "packing") > _signal_energy(pass3, "outbound"), "packing congestion must highlight the packing zone in 3D")

    _set_stable(sim)
    sim.packed_queue = 4
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "outbound") > _signal_energy(pass3, "orders"), "outbound backlog must highlight the shipping zone in 3D")

    _set_stable(sim)
    sim.open_orders = 6
    pass3._sync_domain_bottleneck_signals()
    assert(_signal_energy(pass3, "orders") > _signal_energy(pass3, "inbound"), "open-order backlog must highlight the pick/order handoff in 3D")

    _set_stable(sim)
    queue_pressure._sync_queues()
    pass3._sync_domain_bottleneck_signals()
    for key_variant in pass3._flow_signals.keys():
        var key := String(key_variant)
        assert(_signal_energy(pass3, key) <= WarehouseVisualPass3.SIGNAL_IDLE_ENERGY + 0.01, "stable operation must keep all in-world signals visually quiet")
    var cleared_counts: Dictionary = queue_pressure.visible_backlog_counts()
    assert(int(cleared_counts.get("packing", -1)) == 0 and int(cleared_counts.get("orders", -1)) == 0, "cleared queues must remove physical backlog density")

    view._camera_distance = 25.0
    await process_frame
    var camera: Camera3D = root.get_viewport().get_camera_3d()
    assert(camera != null, "overview smoke requires an active camera")
    assert(camera.fov > 38.0, "max pinch distance must widen into a true warehouse overview")

    hud.queue_free()
    root.queue_free()
    await process_frame
    print("Godot warehouse visual readability smoke passed")
    quit(0)


func _set_stable(sim) -> void:
    sim.inbound_queue = 0
    sim.rack_stock = 0
    sim.packing_queue = 0
    sim.packed_queue = 0
    sim.open_orders = 0


func _signal_energy(pass3: WarehouseVisualPass3, key: String) -> float:
    var meshes: Array = pass3._flow_signals.get(key, [])
    assert(not meshes.is_empty(), "missing flow signal for %s" % key)
    var mesh := meshes[0] as MeshInstance3D
    assert(mesh != null, "flow signal must be a mesh for %s" % key)
    var material := mesh.material_override as StandardMaterial3D
    assert(material != null and material.emission_enabled, "flow signal must use emissive material for %s" % key)
    return material.emission_energy_multiplier
