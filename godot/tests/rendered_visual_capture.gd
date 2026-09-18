extends SceneTree

const WarehouseSimScript = preload("res://domain/flotra_v2_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view_mobile.gd")
const ZoneInteractionScript = preload("res://view/zone_interaction_view.gd")
const VisualPass2Script = preload("res://view/visual_pass_2.gd")
const VisualPass3Script = preload("res://view/visual_pass_3.gd")
const ForkliftAutomationScript = preload("res://view/forklift_automation_view.gd")
const DomainLivenessScript = preload("res://view/domain_liveness_view.gd")
const Rank1ProjectScript = preload("res://view/rank1_project_view.gd")
const Rank2FacilityScript = preload("res://view/rank2_facility_view.gd")
const Rank3ExpansionScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingScript = preload("res://view/rank3_routing_hub_view.gd")
const QueuePressureScript = preload("res://view/queue_pressure_view.gd")
const InvestmentFeedbackScript = preload("res://view/investment_feedback_view.gd")
const ConstructionPreviewScript = preload("res://view/construction_preview_view.gd")
const CompositionFixScript = preload("res://view/visual_composition_fix.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")


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

    # Capture the actual Core Experience v2 preview state: Rank 2 warehouse,
    # Zone Panel open on STORAGE, existing Fast Pick Rack visible, and the
    # High Density Rack planned ghost shown before any renovation cash is spent.
    var preview_sim = _make_sim(2)
    var preview_stage := Node.new()
    preview_stage.name = "PreviewCaptureStage"
    get_root().add_child(preview_stage)
    var preview_context: Dictionary = _populate_stage(preview_stage, preview_sim)
    var preview_view = preview_context["view"]
    var preview_hud = preview_context["hud"]

    var construction_preview = ConstructionPreviewScript.new()
    preview_view.add_child(construction_preview)
    construction_preview.bind(preview_view)

    var zone_panel = ZonePanelScript.new()
    preview_hud.add_child(zone_panel)
    zone_panel.bind_sim(preview_sim)
    zone_panel.construction_preview_changed.connect(construction_preview.show_preview)
    zone_panel.construction_preview_cleared.connect(construction_preview.clear_preview)
    zone_panel.construction_committed.connect(construction_preview.show_commit)
    zone_panel.open_zone("storage")
    await process_frame

    var high_density_button: Button = null
    for button in zone_panel._rank2_capital_buttons:
        if String(button.get_meta("kind", "")) == "high_density_rack":
            high_density_button = button
            break
    assert(high_density_button != null, "visual preview capture must expose High Density Rack")
    var preview_cash := preview_sim.money
    high_density_button.emit_signal("pressed")
    assert(preview_sim.money == preview_cash, "visual preview capture must not spend cash on first tap")

    await process_frame
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw

    var preview_image := get_root().get_texture().get_image()
    assert(not preview_image.is_empty(), "construction preview capture must produce a non-empty viewport image")
    assert(preview_image.get_width() == 390 and preview_image.get_height() == 844, "construction preview capture must preserve portrait viewport")
    var preview_output := capture_dir.path_join("rank2_preview.png")
    var preview_error := preview_image.save_png(preview_output)
    assert(preview_error == OK, "construction preview PNG must save successfully: %s" % preview_output)
    print("saved visual capture: %s" % preview_output)

    preview_stage.queue_free()
    await process_frame

    quit(0)


func _populate_stage(stage: Node, sim) -> Dictionary:
    # Keep this script independent from the editor-generated global class cache.
    # Each runtime class is created from its explicit preload, which lets the same
    # capture run from a clean CI checkout after import or as a standalone script.
    var view = WarehouseViewScript.new()
    stage.add_child(view)
    view.bind_sim(sim)

    var zone_interaction = ZoneInteractionScript.new()
    view.add_child(zone_interaction)
    zone_interaction.bind(view)

    var pass2 = VisualPass2Script.new()
    view.add_child(pass2)
    pass2.bind_view(view)

    var forklift = ForkliftAutomationScript.new()
    view.add_child(forklift)
    forklift.bind(view, sim)

    var liveness = DomainLivenessScript.new()
    view.add_child(liveness)
    liveness.bind(view, sim)

    var rank1_projects = Rank1ProjectScript.new()
    view.add_child(rank1_projects)
    rank1_projects.bind(view, sim)

    var rank2 = Rank2FacilityScript.new()
    view.add_child(rank2)
    rank2.bind(view, sim)

    var rank3 = Rank3ExpansionScript.new()
    view.add_child(rank3)
    rank3.bind(view, sim)

    var routing = Rank3RoutingScript.new()
    view.add_child(routing)
    routing.bind(view, sim)

    var hud = HudScript.new()
    hud.bind_sim(sim)
    stage.add_child(hud)

    var pass3 = VisualPass3Script.new()
    view.add_child(pass3)
    pass3.bind(view, hud)

    var queue_pressure = QueuePressureScript.new()
    view.add_child(queue_pressure)
    queue_pressure.bind(view, sim)

    var investment_feedback = InvestmentFeedbackScript.new()
    view.add_child(investment_feedback)
    investment_feedback.bind(view, sim)

    var composition = CompositionFixScript.new()
    view.add_child(composition)
    composition.bind(view)
    assert(
        is_equal_approx(view._camera_distance, CompositionFixScript.HERO_CAMERA_DISTANCE),
        "visual capture must use the warehouse-hero portrait camera distance"
    )
    return {
        "view": view,
        "hud": hud,
    }


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
    data["rank1_projects"] = {
        "rack_wing": true,
        "second_packing_bench": true,
        "worker_hire": true,
        "forklift_project": true,
        "warehouse_expansion": rank >= 2,
    }
    data["rack_level"] = 1
    data["worker_count"] = 4 if rank == 1 else int(data.get("worker_count", 3))
    data["forklift_unlocked"] = true

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
