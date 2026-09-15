extends SceneTree

const SimScript = preload("res://domain/rank3_inbound_carrier_sim.gd")
const WarehouseViewScript = preload("res://view/warehouse_view.gd")
const Rank3ReceivingAnnexViewScript = preload("res://view/rank3_receiving_annex_view.gd")


func _init() -> void:
    var holder := Node3D.new()
    get_root().add_child(holder)

    var sim = _rank3_sim()
    var warehouse: WarehouseView = WarehouseViewScript.new()
    warehouse.bind_sim(sim)
    holder.add_child(warehouse)

    var rank3_view: Rank3ReceivingAnnexView = Rank3ReceivingAnnexViewScript.new()
    warehouse.add_child(rank3_view)
    rank3_view.bind(warehouse, sim)
    await process_frame
    await process_frame

    assert(rank3_view.find_child("Rank3_ReceivingAnnex", true, false) is Node3D, "owned Receiving Annex must render before carrier program")
    assert(rank3_view.find_child("Rank3_InboundCarrierProgram", true, false) == null, "unowned carrier program must not render")

    assert(bool(sim.purchase_inbound_carrier_program().get("ok", false)), "visual smoke must purchase inbound carrier program")
    await process_frame
    await process_frame

    var carrier := rank3_view.find_child("Rank3_InboundCarrierProgram", true, false)
    assert(carrier is Node3D, "owned inbound carrier program must create visible 3D change")
    assert(carrier.get_child_count() >= 15, "carrier program must contain substantial schedule/lane/trailer geometry")
    assert(rank3_view.find_child("CarrierScheduleBoard", true, false) is MeshInstance3D, "carrier program must show a visible schedule board")
    assert(rank3_view.find_child("CarrierTrailerBody_0", true, false) is MeshInstance3D, "carrier program must visibly add inbound carrier traffic")

    holder.queue_free()
    await process_frame
    print("Godot Rank 3 inbound carrier visual smoke passed")
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
    data["receiving_annex_unlocked"] = true
    data["active_routing_mode"] = "balanced"
    data["inbound_carrier_program_unlocked"] = false
    data["staffing_plan"] = "balanced"
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic inbound carrier visual state must load")
    return sim
