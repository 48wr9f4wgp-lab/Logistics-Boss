extends Node

const WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const ForkliftAutomationViewScript = preload("res://view/forklift_automation_view.gd")
const Rank2FacilityViewScript = preload("res://view/rank2_facility_view.gd")
const Rank3ReceivingAnnexViewScript = preload("res://view/rank3_receiving_annex_view.gd")
const Rank3RoutingHubViewScript = preload("res://view/rank3_routing_hub_view.gd")
const GameHudScript = preload("res://ui/game_hud_rank3.gd")
const SaveStoreScript = preload("res://persistence/save_store.gd")

var sim: WarehouseSim
var save_store: LogisticsSaveStore
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

    var hud: GameHud = GameHudScript.new()
    add_child(hud)
    hud.bind_sim(sim)

    var visual_pass_3: WarehouseVisualPass3 = WarehouseVisualPass3Script.new()
    view.add_child(visual_pass_3)
    visual_pass_3.bind(view, hud)

    var composition_fix: WarehouseVisualCompositionFix = WarehouseVisualCompositionFixScript.new()
    view.add_child(composition_fix)
    composition_fix.bind(view)


func _process(delta: float) -> void:
    sim.step(delta)

    _autosave_timer += delta
    if _autosave_timer >= 10.0:
        _autosave_timer = 0.0
        save_store.save_sim(sim)


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        if sim != null and save_store != null:
            save_store.save_sim(sim)
