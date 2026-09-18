extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const LegacySimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const ZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")
const ViewScript = preload("res://view/warehouse_view_mobile.gd")
const Rank1ProjectViewScript = preload("res://view/rank1_project_view.gd")
const ZoneInteractionScript = preload("res://view/zone_interaction_view.gd")
const CoachScript = preload("res://ui/v2_rank1_coach.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    if FileAccess.file_exists(V2Rank1Coach.DONE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(V2Rank1Coach.DONE_PATH))
    push_error(message)
    quit(1)


func _run() -> void:
    if FileAccess.file_exists(V2Rank1Coach.DONE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(V2Rank1Coach.DONE_PATH))

    if not await _verify_domain_and_save():
        return
    if not await _verify_zone_panel_and_management():
        return
    if not await _verify_visible_projects():
        return
    if not await _verify_zone_first_ftue():
        return

    if FileAccess.file_exists(V2Rank1Coach.DONE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(V2Rank1Coach.DONE_PATH))
    print("Godot Rank 1 v2 structural project smoke passed")
    quit(0)


func _verify_domain_and_save() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    var events: Array[Dictionary] = []
    sim.event_emitted.connect(func(event: Dictionary) -> void:
        events.append(event.duplicate(true))
    )

    if int(sim.save_data().get("schema_version", -1)) != FlotraV2Sim.SAVE_SCHEMA_V2:
        _fail("Rank 1 v2 runtime must write save schema 9")
        return false
    if sim.facility_rank != 1 or sim.rank1_projects_completed() != 0:
        _fail("fresh Rank 1 v2 operation must begin as an undeveloped Small Depot")
        return false

    sim.money = 100000
    var rack_before := sim.rack_capacity
    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_RACK_WING).get("ok", false)):
        _fail("Rack Wing must be purchasable through the v2 project API")
        return false
    if sim.rack_capacity < rack_before + 4 or not sim.rank1_project_owned(FlotraV2Sim.PROJECT_RACK_WING):
        _fail("Rack Wing must authoritatively add storage capacity and ownership")
        return false

    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_SECOND_PACKING_BENCH).get("ok", false)):
        _fail("Second Packing Bench must be purchasable")
        return false
    if int(sim.call("_packing_capacity")) != 2:
        _fail("Second Packing Bench must authoritatively allow two concurrent packing jobs")
        return false

    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_WORKER_HIRE).get("ok", false)):
        _fail("Worker Hire must be purchasable once")
        return false
    if sim.worker_count != 4 or sim.workers.size() != 4:
        _fail("Worker Hire must add exactly one authoritative worker to fresh Rank 1")
        return false

    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_FORKLIFT).get("ok", false)):
        _fail("Forklift Project must be purchasable")
        return false
    if not sim.forklift_unlocked:
        _fail("Forklift Project must unlock authoritative inbound-to-storage automation")
        return false
    if sim.rank1_projects_completed() != 4:
        _fail("all four Rank 1 structural projects must be tracked explicitly")
        return false

    sim.logistics_rating = LogisticsProgression.RANK2_RATING
    sim.call("_rank_up_to_warehouse")
    if sim.facility_rank != 1:
        _fail("Logistics Rating alone must no longer auto-promote Rank 1 in Core Experience v2")
        return false

    var readiness := sim.rank1_expansion_readiness()
    if not bool(readiness.get("projects_ready", false)) or not bool(readiness.get("rating_ready", false)):
        _fail("four projects plus rating gate must make Warehouse Expansion structurally ready")
        return false

    var saved := sim.save_data()
    var round_trip: FlotraV2Sim = SimScript.new()
    if not round_trip.load_data(saved):
        _fail("schema 9 Rank 1 v2 save must round-trip")
        return false
    for kind in round_trip.rank1_project_kinds():
        if not round_trip.rank1_project_owned(kind):
            _fail("schema 9 save must preserve Rank 1 v2 project ownership: %s" % String(kind))
            return false
    if int(round_trip.call("_packing_capacity")) != 2:
        _fail("Second Packing Bench authoritative capacity must survive save/load")
        return false

    round_trip.money = maxi(round_trip.money, FlotraV2Sim.WAREHOUSE_EXPANSION_COST)
    round_trip.logistics_rating = LogisticsProgression.RANK2_RATING
    var expansion := round_trip.purchase_warehouse_expansion()
    if not bool(expansion.get("ok", false)) or round_trip.facility_rank != 2:
        _fail("Warehouse Expansion must be the explicit action that promotes Small Depot to Rank 2")
        return false
    if round_trip.worker_count < 5:
        _fail("Rank 2 promotion must retain the existing minimum five-person Warehouse crew")
        return false

    var legacy: Rank3InboundCarrierSim = LegacySimScript.new()
    legacy.rack_level = 1
    legacy.rack_capacity = 12
    legacy.pack_level = 1
    legacy.worker_count = 4
    legacy.forklift_unlocked = true
    var legacy_data := legacy.save_data()
    if int(legacy_data.get("schema_version", -1)) != Rank3InboundCarrierSim.SAVE_SCHEMA_INBOUND_CARRIER:
        _fail("migration smoke requires a canonical schema 7 legacy save")
        return false

    var migrated: FlotraV2Sim = SimScript.new()
    if not migrated.load_data(legacy_data):
        _fail("schema 7 save must migrate into schema 9")
        return false
    if not migrated.rank1_project_owned(FlotraV2Sim.PROJECT_RACK_WING):
        _fail("legacy rack investment must migrate into Rack Wing ownership")
        return false
    if not migrated.rank1_project_owned(FlotraV2Sim.PROJECT_SECOND_PACKING_BENCH):
        _fail("legacy packing investment must preserve progress as Second Packing Bench ownership")
        return false
    if not migrated.rank1_project_owned(FlotraV2Sim.PROJECT_WORKER_HIRE):
        _fail("legacy extra worker must migrate into Worker Hire ownership")
        return false
    if not migrated.rank1_project_owned(FlotraV2Sim.PROJECT_FORKLIFT):
        _fail("legacy forklift unlock must migrate into Forklift Project ownership")
        return false
    if int(migrated.save_data().get("schema_version", -1)) != FlotraV2Sim.SAVE_SCHEMA_V2:
        _fail("migrated save must write the new schema 9 baseline")
        return false

    if not _has_event(events, "rank1_project_purchased"):
        _fail("Rank 1 v2 purchases must emit authoritative project events")
        return false

    return true


func _verify_zone_panel_and_management() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000

    var panel: WarehouseZonePanel = ZonePanelScript.new()
    get_root().add_child(panel)
    panel.bind_sim(sim)
    panel.open_zone("storage")
    await process_frame

    if panel._capital_action == null or not panel._capital_action.visible:
        _fail("Rank 1 STORAGE Zone must expose its structural capital project")
        return false
    if not panel._capital_action.text.contains("Rack Wing"):
        _fail("STORAGE capital card must name Rack Wing")
        return false

    var money_before := sim.money
    panel._capital_action.emit_signal("pressed")
    await process_frame
    if sim.money != money_before:
        _fail("first capital tap must preview instead of silently spending cash")
        return false
    if not panel._capital_action.text.contains("建設する"):
        _fail("Rank 1 capital preview must require explicit second-step commitment")
        return false

    panel._capital_action.emit_signal("pressed")
    await process_frame
    if sim.money >= money_before or not sim.rank1_project_owned(FlotraV2Sim.PROJECT_RACK_WING):
        _fail("second capital confirmation must purchase the authoritative Rack Wing")
        return false
    if not panel._equipment.text.contains("Rack Wing"):
        _fail("Zone Panel current equipment must update after structural purchase")
        return false

    if panel._operations_action == null or not panel._operations_action.visible:
        _fail("Rank 1 Zone Panel must expose the one-time Worker Hire operations action")
        return false
    panel._operations_action.emit_signal("pressed")
    await process_frame
    if sim.worker_count != 4:
        _fail("Worker Hire UI action must update authoritative worker count")
        return false

    var management_sim: FlotraV2Sim = SimScript.new()
    management_sim.money = 100000
    management_sim.logistics_rating = LogisticsProgression.RANK2_RATING
    for kind in management_sim.rank1_project_kinds():
        if not bool(management_sim.purchase_rank1_project(kind).get("ok", false)):
            _fail("management smoke must seed all Rank 1 projects")
            return false

    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(management_sim)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._v2_rank1_expansion_panel == null or not hud._v2_rank1_expansion_panel.visible:
        _fail("Rank 1 Management must expose Warehouse Expansion as a strategic project")
        return false
    if hud._v2_rank1_expansion_button == null or hud._v2_rank1_expansion_button.disabled:
        _fail("Warehouse Expansion must become actionable after project/rating/funds gates")
        return false
    if not hud._v2_rank1_expansion_label.text.contains("4/4"):
        _fail("Warehouse Expansion must show structural project readiness")
        return false

    hud._v2_rank1_expansion_button.emit_signal("pressed")
    await process_frame
    if management_sim.facility_rank != 2:
        _fail("Management Warehouse Expansion action must authoritatively promote to Rank 2")
        return false

    hud.queue_free()
    panel.queue_free()
    await process_frame
    return true


func _verify_visible_projects() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000
    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_RACK_WING).get("ok", false)):
        _fail("visual smoke must seed Rack Wing")
        return false
    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_SECOND_PACKING_BENCH).get("ok", false)):
        _fail("visual smoke must seed Second Packing Bench")
        return false

    var view: MobileWarehouseView = ViewScript.new()
    get_root().add_child(view)
    view.bind_sim(sim)
    await process_frame

    var projects: Rank1ProjectView = Rank1ProjectViewScript.new()
    view.add_child(projects)
    projects.bind(view, sim)
    projects._process(0.0)
    await process_frame

    if projects._visual_root.get_node_or_null("Rank1Project_RackWing") == null:
        _fail("Rack Wing purchase must produce dedicated visible 3D geometry")
        return false
    if projects._visual_root.get_node_or_null("Rank1Project_SecondPackingBench") == null:
        _fail("Second Packing Bench purchase must produce dedicated visible 3D geometry")
        return false

    view.queue_free()
    await process_frame
    return true


func _verify_zone_first_ftue() -> bool:
    var sim: FlotraV2Sim = SimScript.new()
    sim.money = 100000

    var interaction: WarehouseZoneInteractionView = ZoneInteractionScript.new()
    get_root().add_child(interaction)

    var coach: V2Rank1Coach = CoachScript.new()
    get_root().add_child(coach)
    await process_frame
    coach.bind_context(sim, interaction, false)

    if not coach.visible or coach.current_step_key() != "observe":
        _fail("fresh Rank 1 v2 save must start with observation")
        return false

    coach._process(6.0)
    if coach.current_step_key() != "inspect":
        _fail("v2 onboarding must move from observation to physical Zone inspection")
        return false

    interaction.zone_selected.emit("storage")
    if coach.current_step_key() != "act":
        _fail("tapping a Zone must advance v2 onboarding to player judgment")
        return false
    if coach.body_text().contains("Rack Wing") or coach.body_text().contains("買"):
        _fail("v2 onboarding must not reveal the equipment answer")
        return false

    for _index in 300:
        sim.step(0.1)

    if not bool(sim.purchase_rank1_project(FlotraV2Sim.PROJECT_RACK_WING).get("ok", false)):
        _fail("v2 onboarding smoke must be able to make a real Zone project decision")
        return false
    if coach.current_step_key() != "measure":
        _fail("real project purchase must advance onboarding to observation/measurement")
        return false

    for _index in 270:
        sim.step(0.1)
    if coach.current_step_key() != "complete":
        _fail("v2 onboarding must complete only after the authoritative measurement result")
        return false
    if not coach.body_text().contains("観察") or not coach.body_text().contains("Zone"):
        _fail("v2 onboarding completion must reinforce the warehouse-first loop")
        return false

    coach.queue_free()
    interaction.queue_free()
    await process_frame
    return true


func _has_event(events: Array[Dictionary], event_type: String) -> bool:
    for event in events:
        if String(event.get("type", "")) == event_type:
            return true
    return false
