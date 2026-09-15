extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const HudScript = preload("res://ui/game_hud_rank3.gd")


func _init() -> void:
    var sim = _rank3_sim()
    var hud: Rank3GameHud = HudScript.new()
    get_root().add_child(hud)
    await process_frame
    hud.bind_sim(sim)
    await process_frame
    hud._render_rank3()

    assert(hud._inbound_carrier_button != null and hud._inbound_carrier_button.visible, "Rank 3 management sheet must expose inbound carrier program")
    assert(hud._inbound_carrier_button.disabled, "inbound carrier program must lock before Receiving Annex")
    assert(hud._inbound_carrier_button.text.contains("先に受入増設棟"), "locked carrier action must explain the dependency")

    assert(bool(sim.purchase_receiving_annex().get("ok", false)), "UI smoke must purchase Receiving Annex")
    hud._render_rank3()
    assert(not hud._inbound_carrier_button.disabled, "funded carrier program must unlock after Receiving Annex")
    assert(hud._inbound_carrier_button.text.contains("高頻度入荷プログラム"), "carrier program must use Japanese player-facing copy")

    hud._purchase_inbound_carrier_program()
    hud._render_rank3()
    assert(sim.inbound_carrier_program_unlocked, "carrier UI action must update authoritative Domain state")
    assert(hud._inbound_carrier_button.disabled, "owned carrier program action must lock")
    assert(hud._inbound_carrier_button.text.begins_with("✓"), "owned carrier program must remain visibly identifiable")

    print("Godot Rank 3 inbound carrier UI smoke passed")
    quit(0)


func _rank3_sim():
    var sim = SimScript.new()
    var data: Dictionary = sim.save_data()
    data["schema_version"] = 7
    data["facility_rank"] = 3
    data["logistics_rating"] = 16
    data["completed_contracts"] = 0
    data["worker_count"] = 5
    data["money"] = 120000
    data["receiving_annex_unlocked"] = false
    data["active_routing_mode"] = "balanced"
    data["inbound_carrier_program_unlocked"] = false
    data["staffing_plan"] = "balanced"
    data["staffing_cooldown"] = 0.0
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic inbound carrier UI state must load")
    return sim
