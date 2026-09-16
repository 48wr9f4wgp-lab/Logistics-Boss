extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const FeedbackViewScript = preload("res://view/investment_feedback_view.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var sim = WarehouseSimScript.new()
    var view: WarehouseView = WarehouseViewScript.new()
    holder.add_child(view)
    view.bind_sim(sim)

    var feedback: WarehouseInvestmentFeedbackView = FeedbackViewScript.new()
    view.add_child(feedback)
    feedback.bind(view, sim)

    await process_frame
    assert(feedback.feedback_count == 0, "fresh runtime must not fabricate investment feedback")

    sim.emit_signal("event_emitted", {
        "type": "upgrade_purchased",
        "kind": "packing",
    })
    await process_frame
    assert(feedback.feedback_count == 1, "capital purchase must create in-world visual feedback")
    assert(feedback.last_event_type == "upgrade_purchased", "feedback must retain authoritative event type")
    assert(feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.PACKING_CENTER) < 0.01, "packing investment must pulse the packing cell")
    assert(feedback.last_half_extents.x < 3.0, "ordinary capital feedback must stay local instead of masking the facility")

    sim.emit_signal("event_emitted", {
        "type": "facility_purchased",
        "group": "storage",
        "kind": "fast_pick_rack",
    })
    await process_frame
    assert(feedback.last_center.distance_to(WarehouseInvestmentFeedbackView.STORAGE_CENTER) < 0.01, "storage facility purchase must pulse storage")

    sim.emit_signal("event_emitted", {
        "type": "receiving_annex_purchased",
        "kind": "receiving_annex",
    })
    await process_frame
    assert(feedback.last_center.z > 5.0, "Receiving Annex purchase must pulse the physical annex area")

    sim.emit_signal("event_emitted", {
        "type": "rank_up",
        "rank": 3,
        "name": "Fulfillment Center",
    })
    await process_frame
    assert(feedback.last_event_type == "rank_up", "rank promotion must use the dedicated promotion feedback")
    assert(feedback.last_half_extents.x >= 7.0 and feedback.last_half_extents.y >= 4.5, "rank promotion must outline the whole facility footprint")
    assert(feedback.last_lifetime > WarehouseInvestmentFeedbackView.INVESTMENT_LIFETIME, "rank promotion must feel more substantial than an ordinary purchase")

    for index in range(10):
        sim.emit_signal("event_emitted", {
            "type": "upgrade_purchased",
            "kind": "worker" if index % 2 == 0 else "speed",
        })
    await process_frame
    assert(feedback.active_pulse_count() <= WarehouseInvestmentFeedbackView.MAX_ACTIVE_PULSES, "rapid purchases must keep visual feedback node cost bounded")

    holder.queue_free()
    await process_frame
    print("Godot investment feedback visual smoke passed")
    quit(0)
