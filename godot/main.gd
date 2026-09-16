extends Node

const WarehouseSimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view_mobile.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseQueuePressureViewScript = preload("res://view/queue_pressure_view.gd")
const WarehouseInvestmentFeedbackViewScript = preload("res://view/investment_feedback_view.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const ForkliftAutomationViewScript = preload("res://view/forklift_automation_view.gd")
const Rank2FacilityViewScript = preload("res://view/rank2_facility_view.gd")
const Rank3ReceivingAnnexViewScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingHubViewScript = preload("res://view/rank3_routing_hub_view.gd")
const GameHudScript = preload("res://ui/game_hud_mobile.gd")
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
    save_store.load_into(sim)

    var view: WarehouseView = WarehouseViewScript.new()
    add_child(view)
    view.bind_sim(sim)

    var visual_pass_2: WarehouseVisualPass2 = WarehouseVisualPass2Script.new()
    view.add_child(visual_pass_2)
    visual_pass_2.bind_view(view)

    var forklift_automation: ForkliftAutomationView = ForkliftAutomationViewScript.new()
    view.add_child(forklift_automation)
    forklift_automation.bind(view, sim)

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
    add_child(hud)

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
