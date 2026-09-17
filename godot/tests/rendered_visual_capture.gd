extends SceneTree

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view_mobile.gd")
const VisualPass2Script = preload("res://view/visual_pass_2.gd")
const VisualPass3Script = preload("res://view/visual_pass_3.gd")
const ForkliftAutomationScript = preload("res://view/forklift_automation_view.gd")
const DomainLivenessScript = preload("res://view/domain_liveness_view.gd")
const Rank2FacilityScript = preload("res://view/rank2_facility_view.gd")
const Rank3ExpansionScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingScript = preload("res://view/rank3_routing_hub_view.gd")
const QueuePressureScript = preload("res://view/queue_pressure_view.gd")
const InvestmentFeedbackScript = preload("res://view/investment_feedback_view.gd")
const CompositionFixScript = preload("res://view/visual_composition_fix.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    get_root().size = Vector2i(390, 844)
    var capture_dir := OS.get_environment("LOGISTICS_BOSS_CAPTURE_DIR")
    if capture_dir.is_empty():
        capture_dir = ProjectSettings.globalize_path("user://visual-captures")
    DirAccess.make_dir_recursive_absolute(capture_dir)

    for rank in [1, 2, 3]:
        var sim = _make_sim(rank)
        var stage := Node.new()
        stage.name = "CaptureStage"
        get_root().add_child(stage)
        _populate_stage(stage, sim)

        # Give the full visual stack enough frames to build geometry, apply the
        # portrait composition pass and upload its first GL frame before capture.
        await process_frame
        await process_frame
        await process_frame
        await RenderingServer.frame_post_draw

        var image := get_root().get_texture().get_image()
        assert(not image.is_empty(), "render capture must produce a non-empty viewport image")
        assert(image.get_width() == 390 and image.get_height() == 844, "visual capture must preserve the canonical portrait viewport")
        var output_path := capture_dir.path_join("rank%d.png" % rank)
        var error := image.save_png(output_path)
        assert(error == OK, "visual capture PNG must save successfully: %s" % output_path)
        print("saved visual capture: %s" % output_path)

        stage.queue_free()
        await process_frame

    quit(0)


func _populate_stage(stage: Node, sim) -> void:
    # Match main.gd ordering: WarehouseView enters the live tree first so its
    # _ready() builds the base facility before presentation layers bind to it.
    var view: WarehouseView = WarehouseViewScript.new()
    stage.add_child(view)
    view.bind_sim(sim)

    var pass2: WarehouseVisualPass2 = VisualPass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)

    var forklift: ForkliftAutomationView = ForkliftAutomationScript.new()
    view.add_child(forklift)
    forklift.bind(view, sim)

    var liveness: WarehouseDomainLivenessView = DomainLivenessScript.new()
    view.add_child(liveness)
    liveness.bind(view, sim)

    var rank2: Rank2FacilityView = Rank2FacilityScript.new()
    view.add_child(rank2)
    rank2.bind(view, sim)

    var rank3: Rank3ReceivingAnnexView = Rank3ExpansionScript.new()
    view.add_child(rank3)
    rank3.bind(view, sim)

    var routing: Rank3RoutingHubView = Rank3RoutingScript.new()
    view.add_child(routing)
    routing.bind(view, sim)

    var hud: GameHud = HudScript.new()
    hud.bind_sim(sim)
    stage.add_child(hud)

    var pass3: WarehouseVisualPass3 = VisualPass3Script.new()
    view.add_child(pass3)
    pass3.bind(view, hud)

    var queue_pressure: WarehouseQueuePressureView = QueuePressureScript.new()
    view.add_child(queue_pressure)
    queue_pressure.bind(view, sim)

    var investment_feedback: WarehouseInvestmentFeedbackView = InvestmentFeedbackScript.new()
    view.add_child(investment_feedback)
    investment_feedback.bind(view, sim)

    var composition: WarehouseVisualCompositionFix = CompositionFixScript.new()
    view.add_child(composition)
    composition.bind(view)


func _make_sim(rank: int):
    var sim = WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()

    data["money"] = 120000
    data["inbound_queue"] = 7
    data["rack_stock"] = 7
    data["packing_queue"] = 5
    data["packed_queue"] = 5
    data["open_orders"] = 6
    data["rack_capacity"] = 12

    if rank >= 2:
        data["facility_rank"] = 2
        data["logistics_rating"] = 8
        data["completed_contracts"] = 4
        data["worker_count"] = 5
        data["staffing_plan"] = "balanced"
        data["facilities"] = {
            "double_dock": false,
            "buffer_yard": true,
            "fast_pick_rack": true,
            "high_density_rack": false,
            "parallel_pack": true,
            "fast_pack_cell": false,
        }

    if rank >= 3:
        data["facility_rank"] = 3
        data["logistics_rating"] = 16
        data["completed_contracts"] = 8
        data["worker_count"] = 7
        data["receiving_annex_unlocked"] = true
        data["active_routing_mode"] = "consolidated"
        data["inbound_carrier_program_unlocked"] = true

    assert(sim.load_data(data), "visual capture synthetic Rank %d state must load" % rank)

    # Let authoritative tasks start and advance to a readable mid-operation pose.
    sim.step(0.2)
    sim.step(0.6)
    return sim
