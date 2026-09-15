extends SceneTree

const WarehouseSimScript = preload("res://domain/warehouse_sim.gd")
const JapaneseGameHudScript = preload("res://ui/game_hud_ja.gd")


func _init() -> void:
    var sim := _rank2_sim()
    var hud: JapaneseGameHud = JapaneseGameHudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame

    assert(hud._facility_header != null, "Rank 2 management must build an expansion-zone header")
    assert(hud._facility_header.visible, "Rank 2 expansion-zone header must be visible")
    assert(hud._facility_header.text.contains("0 / 3"), "fresh Rank 2 UI must show Expansion Zones 0/3")
    assert(hud._facility_buttons.size() == 6, "Rank 2 management must expose six structural choices")

    var double_dock: Button = hud._facility_buttons["double_dock"]
    var buffer_yard: Button = hud._facility_buttons["buffer_yard"]
    assert(double_dock.visible and buffer_yard.visible, "Zone A must show both choices before commitment")
    assert(not double_dock.disabled and not buffer_yard.disabled, "affordable Zone A choices must be actionable")

    assert(bool(sim.purchase_facility(&"double_dock").get("ok", false)), "UI smoke must be able to commit Zone A")
    hud._render_progression()
    assert(hud._facility_header.text.contains("1 / 3"), "management UI must update to Expansion Zones 1/3")
    assert(double_dock.disabled and buffer_yard.disabled, "committing one Zone A choice must lock both alternatives")
    assert(double_dock.text.begins_with("✓"), "selected structural choice must remain visibly identifiable")

    var rank1 := WarehouseSimScript.new()
    hud.bind_sim(rank1)
    hud._render_progression()
    assert(not hud._facility_header.visible, "Rank 1 must not expose Rank 2 expansion choices")

    print("Godot Rank 2 facility UI smoke passed")
    quit(0)


func _rank2_sim() -> WarehouseSim:
    var sim: WarehouseSim = WarehouseSimScript.new()
    var data := sim.save_data()
    data["facility_rank"] = 2
    data["logistics_rating"] = 8
    data["worker_count"] = 5
    data["money"] = 200000
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": false,
        "fast_pick_rack": false,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": false,
    }
    assert(sim.load_data(data), "synthetic Rank 2 UI state must load")
    return sim
