extends SceneTree

const Rank3WarehouseSimScript = preload("res://domain/rank3_warehouse_sim.gd")
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

    var rank_mark := rank3_view.find_child("Rank3_FulfillmentCenterMark", true, false)
    assert(rank_mark is Node3D, "Rank 3 promotion must create visible Fulfillment Center evolution")
    assert(rank_mark.get_child_count() > 0, "Rank 3 facility mark must contain geometry")
    assert(rank3_view.find_child("Rank3_ReceivingAnnex", true, false) == null, "unowned Receiving Annex must not render as if purchased")

    assert(bool(sim.purchase_receiving_annex().get("ok", false)), "visual smoke must purchase Receiving Annex")
    await process_frame
    await process_frame

    var annex := rank3_view.find_child("Rank3_ReceivingAnnex", true, false)
    assert(annex is Node3D, "purchased Receiving Annex must create visible 3D expansion")
    assert(annex.get_child_count() >= 10, "Receiving Annex visible expansion must contain substantial geometry")

    holder.queue_free()
    await process_frame
    print("Godot Rank 3 visual smoke passed")
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
    data["receiving_annex_unlocked"] = false
    data["staffing_plan"] = "balanced"
    data["rack_capacity"] = 12
    data["facilities"] = {
        "double_dock": false,
        "buffer_yard": true,
        "fast_pick_rack": true,
        "high_density_rack": false,
        "parallel_pack": false,
        "fast_pack_cell": true,
    }
    assert(sim.load_data(data), "synthetic Rank 3 visual state must load")
    return sim
