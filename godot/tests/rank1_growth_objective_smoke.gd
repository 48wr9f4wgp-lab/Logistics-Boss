extends SceneTree

const SimScript = preload("res://domain/flotra_v2_sim.gd")
const HudScript = preload("res://ui/game_hud_mobile.gd")


func _init() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error(message)
    quit(1)


func _run() -> void:
    var sim: FlotraV2Sim = SimScript.new()
    var hud: MobileGameHud = HudScript.new()
    hud.bind_sim(sim)
    get_root().add_child(hud)
    await process_frame
    hud._process(0.0)

    if hud._v2_growth_goal == null or not hud._v2_growth_goal.visible:
        _fail("fresh Rank 1 must expose the persistent growth objective")
        return
    if not hud._v2_growth_goal.text.contains("倉庫を育てる"):
        _fail("fresh Rank 1 objective must lead to warehouse growth rather than mandatory contracts")
        return
    if not hud._v2_growth_goal.text.contains("設備 0/2") or not hud._v2_growth_goal.text.contains("出荷 0/20"):
        _fail("growth objective must expose the two Rank 2 progression requirements")
        return

    hud._v2_growth_goal.emit_signal("pressed")
    await process_frame
    hud._process(0.0)

    if not hud._sheet.visible:
        _fail("tapping the growth objective must open Management")
        return
    var list := hud._find_upgrade_list(hud._sheet)
    if list == null or hud._progression_panel == null:
        _fail("growth objective smoke requires a Management progression panel")
        return
    if list.get_child_count() < 2 or list.get_child(0) != hud._progression_panel:
        _fail("Rank 1 Management must put contract/progression controls first")
        return
    if hud._v2_rank1_expansion_label == null or not hud._v2_rank1_expansion_label.text.contains("契約は任意"):
        _fail("Warehouse Expansion must explain that contracts are optional")
        return

    if hud._contract_buttons.is_empty() or sim.contract_offers.is_empty():
        _fail("fresh Rank 1 must expose contract choices")
        return
    var contract_button := hud._contract_buttons[0]
    contract_button.emit_signal("pressed")
    await process_frame

    if sim.active_contract.is_empty():
        _fail("contract CTA must start a real authoritative contract")
        return

    hud._sheet.visible = false
    hud._process(0.0)
    if sim.active_contract.is_empty() or not hud._v2_growth_goal.text.contains("出荷"):
        _fail("optional contract must not replace the fundamental shipment-growth objective")
        return

    var elapsed := 0.0
    while sim.completed_contracts < 1 and elapsed < 90.0:
        sim.step(0.1)
        elapsed += 0.1

    if sim.completed_contracts < 1:
        _fail("fresh Rank 1 shipment contract must be completable by authoritative simulation")
        return
    if sim.logistics_rating != 2:
        _fail("completed fresh Rank 1 contract must award the expected Logistics Rating")
        return

    hud._process(0.0)
    if not hud._v2_growth_goal.text.contains("出荷"):
        _fail("growth objective must immediately retain the ordinary shipment objective after an optional reward")
        return

    hud.queue_free()
    await process_frame
    print("Godot Rank 1 growth objective smoke passed")
    quit(0)
