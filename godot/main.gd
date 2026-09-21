extends Node

const WarehouseSimScript = preload("res://domain/flotra_v2_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view_mobile.gd")
const WarehouseZoneInteractionScript = preload("res://view/zone_interaction_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseQueuePressureViewScript = preload("res://view/queue_pressure_view.gd")
const WarehouseInvestmentFeedbackViewScript = preload("res://view/investment_feedback_view.gd")
const WarehouseConstructionPreviewViewScript = preload("res://view/construction_preview_view.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const ForkliftAutomationViewScript = preload("res://view/forklift_automation_view.gd")
const WarehouseDomainLivenessViewScript = preload("res://view/domain_liveness_view.gd")
const GrowthAutomationViewScript = preload("res://view/growth_automation_view.gd")
const Rank1ProjectViewScript = preload("res://view/rank1_project_view.gd")
const Rank2FacilityViewScript = preload("res://view/rank2_facility_view.gd")
const Rank3ReceivingAnnexViewScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingHubViewScript = preload("res://view/rank3_routing_hub_view.gd")
const GameHudScript = preload("res://ui/game_hud_mobile.gd")
const WarehouseZonePanelScript = preload("res://ui/warehouse_zone_panel.gd")
const V2Rank1CoachScript = preload("res://ui/v2_rank1_coach.gd")
const SessionResumeBriefScript = preload("res://ui/session_resume_brief.gd")
const MobileInteractionClarityScript = preload("res://ui/mobile_interaction_clarity.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")
const GameFeelScript = preload("res://feedback/game_feel.gd")
const AnalyticsScript = preload("res://telemetry/analytics_service.gd")
const RuntimeHealthScript = preload("res://telemetry/runtime_health.gd")

var sim: WarehouseSim
var save_store: LogisticsSaveStore
var analytics: LogisticsAnalytics
var runtime_health: LogisticsRuntimeHealth
var game_feel: LogisticsGameFeel
var _autosave_timer := 0.0


func _ready() -> void:
    sim = WarehouseSimScript.new()
    save_store = SaveStoreScript.new()
    var resumed_session := save_store.load_into(sim)

    var view: WarehouseView = WarehouseViewScript.new()
    add_child(view)
    view.bind_sim(sim)

    var zone_interaction: WarehouseZoneInteractionView = WarehouseZoneInteractionScript.new()
    view.add_child(zone_interaction)
    zone_interaction.bind(view, sim)

    var construction_preview: WarehouseConstructionPreviewView = WarehouseConstructionPreviewViewScript.new()
    view.add_child(construction_preview)
    construction_preview.bind(view)

    var visual_pass_2: WarehouseVisualPass2 = WarehouseVisualPass2Script.new()
    view.add_child(visual_pass_2)
    visual_pass_2.bind_view(view)

    var forklift_automation: ForkliftAutomationView = ForkliftAutomationViewScript.new()
    view.add_child(forklift_automation)
    forklift_automation.bind(view, sim)

    # Presentation-only liveness follows the authoritative worker/forklift task state.
    # It adds no workers, vehicles, throughput or fake automation.
    var domain_liveness: WarehouseDomainLivenessView = WarehouseDomainLivenessViewScript.new()
    view.add_child(domain_liveness)
    domain_liveness.bind(view, sim)

    var growth_automation: GrowthAutomationView = GrowthAutomationViewScript.new()
    growth_automation.name = "GrowthAutomation"
    view.add_child(growth_automation)
    growth_automation.bind(view, sim as FlotraV2Sim)

    var rank1_projects: Rank1ProjectView = Rank1ProjectViewScript.new()
    view.add_child(rank1_projects)
    rank1_projects.bind(view, sim)

    var rank2_facilities: Rank2FacilityView = Rank2FacilityViewScript.new()
    view.add_child(rank2_facilities)
    rank2_facilities.bind(view, sim)

    var rank3_expansion: Rank3ReceivingAnnexView = Rank3ReceivingAnnexViewScript.new()
    view.add_child(rank3_expansion)
    rank3_expansion.bind(view, sim)

    var rank3_routing: Rank3RoutingHubView = Rank3RoutingHubViewScript.new()
    view.add_child(rank3_routing)
    rank3_routing.bind(view, sim)

    # Bind the authoritative simulation before the HUD enters the tree.
    # Optional presentation failures must never strand the visible shell on placeholders.
    var hud: GameHud = GameHudScript.new()
    hud.bind_sim(sim)
    hud.reset_progress_requested.connect(_reset_all_progress)
    add_child(hud)

    var zone_panel: WarehouseZonePanel = WarehouseZonePanelScript.new()
    hud.add_child(zone_panel)
    zone_panel.bind_sim(sim)

    zone_panel.construction_preview_changed.connect(construction_preview.show_preview)
    zone_panel.construction_preview_cleared.connect(construction_preview.clear_preview)
    zone_panel.construction_committed.connect(construction_preview.show_commit)

    zone_interaction.zone_selected.connect(func(zone_key: String):
        if hud._sheet != null and hud._sheet.visible:
            hud._toggle_sheet()
        zone_panel.open_zone(zone_key)
    )
    if hud.has_signal("zone_navigation_requested"):
        hud.connect("zone_navigation_requested", Callable(zone_panel, "open_zone"))
    if hud._manage_button != null:
        hud._manage_button.pressed.connect(zone_panel.close)

    var v2_rank1_coach: V2Rank1Coach = V2Rank1CoachScript.new()
    hud.add_child(v2_rank1_coach)
    v2_rank1_coach.bind_context(sim, zone_interaction)

    # Returning players get a five-second continuity brief built only from the
    # restored Domain state. Fresh saves and active FTUE keep the onboarding band.
    var resume_brief: LogisticsSessionResumeBrief = SessionResumeBriefScript.new()
    hud.add_child(resume_brief)
    var ftue_step := String(hud.call("current_ftue_step")) if hud.has_method("current_ftue_step") else ""
    var v2_ftue_step := v2_rank1_coach.current_step_key() if v2_rank1_coach.visible else ""
    var legacy_ftue_clear := ftue_step.is_empty() or ftue_step == "complete"
    var v2_ftue_clear := v2_ftue_step.is_empty() or v2_ftue_step == "complete"
    var should_show_resume := resumed_session and legacy_ftue_clear and v2_ftue_clear
    resume_brief.bind(sim, should_show_resume)

    # Compose the interaction presentation after every mobile surface exists.
    # It owns UI gestures only; simulation, saves and purchase handlers stay intact.
    var interaction_clarity: MobileInteractionClarity = MobileInteractionClarityScript.new()
    interaction_clarity.name = "MobileInteractionClarity"
    hud.add_child(interaction_clarity)
    interaction_clarity.bind(hud as MobileGameHud, zone_panel, v2_rank1_coach, resume_brief)

    var visual_pass_3: WarehouseVisualPass3 = WarehouseVisualPass3Script.new()
    view.add_child(visual_pass_3)
    visual_pass_3.bind(view, hud)

    # Queue pressure is presentation-only: it mirrors authoritative packing/open-order
    # counts as capped physical density so congestion can be read directly in 3D.
    var queue_pressure: WarehouseQueuePressureView = WarehouseQueuePressureViewScript.new()
    view.add_child(queue_pressure)
    queue_pressure.bind(view, sim)

    # Investment feedback mirrors authoritative Domain events as short-lived emissive
    # geometry. Audio/haptics remain owned by LogisticsGameFeel; this node only gives
    # purchases and rank promotion an in-world visual response.
    var investment_feedback: WarehouseInvestmentFeedbackView = WarehouseInvestmentFeedbackViewScript.new()
    view.add_child(investment_feedback)
    investment_feedback.bind(view, sim)

    var composition_fix: WarehouseVisualCompositionFix = WarehouseVisualCompositionFixScript.new()
    view.add_child(composition_fix)
    composition_fix.bind(view)

    # Release-readiness services are deliberately attached after the playable core.
    # If an optional service regresses, simulation + HUD + 3D are already live.
    runtime_health = RuntimeHealthScript.new()
    add_child(runtime_health)

    analytics = AnalyticsScript.new()
    add_child(analytics)
    analytics.bind_sim(sim)
    analytics.bind_hud(hud)
    if resumed_session:
        analytics.record("session_resume", {
            "facility_rank": sim.facility_rank,
            "active_contract": not sim.active_contract.is_empty(),
            "bottleneck": String(sim.bottleneck().get("key", "stable")),
        })

    game_feel = GameFeelScript.new()
    add_child(game_feel)
    game_feel.bind_sim(sim)


func _process(delta: float) -> void:
    if sim == null:
        return

    sim.step(delta)

    _autosave_timer += delta
    if _autosave_timer >= 10.0:
        _autosave_timer = 0.0
        if save_store != null:
            save_store.save_sim(sim)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        if sim != null and save_store != null:
            save_store.save_sim(sim)
        if analytics != null:
            analytics.record("session_suspend", {
                "facility_rank": sim.facility_rank if sim != null else 0,
                "total_shipped": sim.shipped if sim != null else 0,
                "health": runtime_health.snapshot() if runtime_health != null else {},
            })


func _reset_all_progress() -> void:
    if save_store == null:
        push_error("FLOTRA reset requested before save store initialization")
        return
    if not save_store.reset_user_progress():
        push_error("FLOTRA reset could not remove all local progress files")
        return

    _autosave_timer = 0.0
    call_deferred("_reload_after_progress_reset")


func _reload_after_progress_reset() -> void:
    var error := get_tree().reload_current_scene()
    if error != OK:
        push_error("FLOTRA reset could not reload the current scene: %s" % error)
