extends Node

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const WarehouseVisualPass2Script = preload("res://view/visual_pass_2.gd")
const WarehouseVisualPass3Script = preload("res://view/visual_pass_3.gd")
const WarehouseVisualCompositionFixScript = preload("res://view/visual_composition_fix.gd")
const ForkliftAutomationViewScript = preload("res://view/forklift_automation_view.gd")
const GameHudScript = preload("res://ui/game_hud_ja.gd")
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
