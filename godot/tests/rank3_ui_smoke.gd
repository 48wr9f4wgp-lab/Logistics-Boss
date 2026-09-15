extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
const Rank3GameHudScript = preload("res://ui/game_hud_rank3.gd")


func _init() -> void:
    var sim = _rank3_sim()
    var hud: Rank3GameHud = Rank3GameHudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame
    hud._render_rank3()

    assert(hud._rank3_panel != null and hud._rank3_panel.visible, "Rank 3 management panel must be visible")
    assert(hud._progression_label.text.contains("RANK 3"), "Rank 3 HUD must identify Fulfillment Center progression")
    assert(hud._receiving_annex_button.visible, "Rank 3 must expose Receiving Annex capital action")
    assert(not hud._receiving_annex_button.disabled, "funded unowned Receiving Annex must be actionable")
    assert(hud._receiving_annex_button.text.contains("受入増設棟"), "Receiving Annex card must use Japanese player-facing copy")

    assert(bool(sim.purchase_receiving_annex().get("ok", false)), "UI smoke must be able to purchase Receiving Annex")
    hud._render_rank3()
    assert(hud._receiving_annex_button.disabled, "owned Receiving Annex action must lock")
    assert(hud._receiving_annex_button.text.begins_with("✓"), "owned Receiving Annex must remain visibly identifiable")

    var rank2 = _rank2_sim()
    hud.bind_sim(rank2)
    hud._render_progression()
    hud._render_rank3()
    assert(hud._rank3_panel.visible, "late Rank 2 must show the Rank 3 readiness target")
    assert(not hud._receiving_annex_button.visible, "Rank 2 must not expose the Rank 3 purchase before promotion")
    assert(hud._rank3_status.text.contains("解禁条件"), "Rank 2 readiness panel must explain the Rank 3 gate")
    assert(not hud._rank3_status.text.contains("契約"), "Rank 3 readiness must not show contracts as mandatory")
    assert(hud._rank3_status.text.contains("設備資産"), "Rank 3 readiness must show equipment asset progress")
    assert(hud._rank3_status.text.contains("200,000"), "Rank 3 readiness must show the canonical asset target")
    assert(hud._rank3_status.text.contains("出荷ペース"), "Rank 3 readiness must show live throughput progress")

    hud.bind_sim(sim)
    hud._render_progression()
    hud._render_rank3()
    assert(hud._rank3_panel.visible, "Rank 3 panel must remain visible after promotion")
    assert(hud._rank3_status.text.contains("次の成長投資"), "Rank 3 promoted UI must remain intact")

    print("Godot Rank 3 UI smoke passed")
    quit(0)


func _rank3_sim():
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 5
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 100000
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["receiving_annex_unlocked"] = false
    data["rack_capacity"] = 12
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic Rank 3 UI state must load")
    return sim


func _rank2_sim():
    var sim = Rank3WarehouseSimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 4
    data["facility_rank"] = 2
    data["logistics_rating"] = 16
    data["completed_contracts"] = 8
    data["worker_count"] = 5
    data["money"] = 100000
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["rack_capacity"] = 12
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic Rank 2 readiness UI state must load")
    return sim
